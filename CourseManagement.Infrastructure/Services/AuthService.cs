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
        var email = dto.Email.Trim();

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
        var user = await userRepository.GetByEmailAsync(dto.Email.Trim());

        if (user == null || !BCrypt.Net.BCrypt.Verify(dto.Password, user.PasswordHash))
            throw new UnauthorizedAccessException("Invalid email or password.");

        return GenerateToken(user);
    }

    private AuthResponseDto GenerateToken(User user)
    {
        var jwtSettings = configuration.GetSection("JwtSettings");
        var secret = jwtSettings["Secret"];

        if (string.IsNullOrWhiteSpace(secret))
            throw new InvalidOperationException("JwtSettings:Secret is not configured.");

        var expiryHours = double.TryParse(jwtSettings["ExpiryHours"], out var h) && h > 0 ? h : 2;
        var expiresAt = DateTime.UtcNow.AddHours(expiryHours);
        var key = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(secret));

        var descriptor = new SecurityTokenDescriptor
        {
            Subject = new ClaimsIdentity(
            [
                new Claim(ClaimTypes.NameIdentifier, user.Id.ToString()),
                new Claim(ClaimTypes.Email, user.Email),
                new Claim(ClaimTypes.Role, user.Role.ToString()),
                new Claim(ClaimTypes.Name, user.FullName)
            ]),
            Issuer = jwtSettings["Issuer"],
            Audience = jwtSettings["Audience"],
            Expires = expiresAt,
            SigningCredentials = new SigningCredentials(key, SecurityAlgorithms.HmacSha256)
        };

        return new AuthResponseDto
        {
            Token = new JsonWebTokenHandler().CreateToken(descriptor),
            UserId = user.Id,
            FullName = user.FullName,
            Email = user.Email,
            Role = user.Role.ToString(),
            ExpiresAtUtc = expiresAt
        };
    }
}
