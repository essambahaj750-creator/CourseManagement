using System.Security.Claims;
using System.Text;
using CourseManagement.Application.DTOs;
using CourseManagement.Application.Interfaces;
using CourseManagement.Domain.Entities;
using CourseManagement.Domain.Enums;
using CourseManagement.Domain.Interfaces;
using Microsoft.Extensions.Configuration;
using Microsoft.IdentityModel.JsonWebTokens;
using Microsoft.IdentityModel.Tokens;

namespace CourseManagement.Infrastructure.Services;

public class AuthService(IUserRepository userRepository, IConfiguration configuration) : IAuthService
{
    public async Task<AuthResponseDto> RegisterAsync(RegisterDto dto)
    {
        var email = User.NormalizeEmail(dto.Email);

        if (await userRepository.ExistsAsync(email))
            throw new InvalidOperationException("User with this email already exists.");

        var user = new User
        {
            FullName = dto.FullName.Trim(),
            Email = email,
            PasswordHash = BCrypt.Net.BCrypt.HashPassword(dto.Password),
            // أمان: التسجيل العام ينشئ Student دائماً — الترقية تتم عبر Admin فقط.
            // (كانت الثغرة السابقة تسمح لأي زائر بتسجيل نفسه Admin!)
            Role = Role.Student
        };

        await userRepository.AddAsync(user);
        return GenerateToken(user);
    }

    public async Task<AuthResponseDto> LoginAsync(LoginDto dto)
    {
        var user = await userRepository.GetByEmailAsync(User.NormalizeEmail(dto.Email));

        if (user == null || !user.IsActive || !BCrypt.Net.BCrypt.Verify(dto.Password, user.PasswordHash))
            throw new UnauthorizedAccessException("Invalid email or password.");

        return GenerateToken(user);
    }

    public async Task ChangePasswordAsync(int userId, ChangePasswordDto dto)
    {
        var user = await userRepository.GetByIdAsync(userId)
            ?? throw new UnauthorizedAccessException("User not found.");

        if (!user.IsActive || !BCrypt.Net.BCrypt.Verify(dto.CurrentPassword, user.PasswordHash))
            throw new UnauthorizedAccessException("Current password is incorrect.");

        user.PasswordHash = BCrypt.Net.BCrypt.HashPassword(dto.NewPassword);
        user.SecurityStamp = Guid.NewGuid();
        await userRepository.UpdateAsync(user);
    }

    private AuthResponseDto GenerateToken(User user)
    {
        var jwtSettings = configuration.GetSection("JwtSettings");
        var expiryHours = double.TryParse(jwtSettings["ExpiryHours"], out var h) && h > 0 ? h : 2;
        var expiresAt = DateTime.UtcNow.AddHours(expiryHours);
        var securityStamp = user.SecurityStamp.ToString("N");

        // The MVC Web project uses Cookie Authentication. It shares the domain
        // service with the API for registration/login, but it must not require or
        // manufacture a JWT that the Web application never consumes.
        var issueJwt = bool.TryParse(configuration["JwtSettings:IssueToken"], out var issueToken) && issueToken;
        if (!issueJwt)
        {
            return BuildAuthResponse(user, string.Empty, expiresAt, securityStamp);
        }

        var secret = jwtSettings["Secret"];
        if (string.IsNullOrWhiteSpace(secret))
            throw new InvalidOperationException("JwtSettings:Secret is not configured.");

        if (secret.Length < 32)
            throw new InvalidOperationException("JwtSettings:Secret must be at least 32 characters long for HMAC-SHA256.");

        var key = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(secret));
        var descriptor = new SecurityTokenDescriptor
        {
            Subject = new ClaimsIdentity(
            [
                new Claim(ClaimTypes.NameIdentifier, user.Id.ToString()),
                new Claim("jti", Guid.NewGuid().ToString("N")),
                new Claim("security_stamp", securityStamp),
                new Claim(ClaimTypes.Email, user.Email),
                new Claim(ClaimTypes.Role, user.Role.ToString()),
                new Claim(ClaimTypes.Name, user.FullName)
            ]),
            Issuer = jwtSettings["Issuer"],
            Audience = jwtSettings["Audience"],
            IssuedAt = DateTime.UtcNow,
            Expires = expiresAt,
            SigningCredentials = new SigningCredentials(key, SecurityAlgorithms.HmacSha256)
        };

        var token = new JsonWebTokenHandler().CreateToken(descriptor);
        return BuildAuthResponse(user, token, expiresAt, securityStamp);
    }

    private static AuthResponseDto BuildAuthResponse(User user, string token, DateTime expiresAt, string securityStamp)
        => new()
        {
            Token = token,
            UserId = user.Id,
            FullName = user.FullName,
            Email = user.Email,
            Role = user.Role.ToString(),
            ExpiresAtUtc = expiresAt,
            SecurityStamp = securityStamp
        };
}
