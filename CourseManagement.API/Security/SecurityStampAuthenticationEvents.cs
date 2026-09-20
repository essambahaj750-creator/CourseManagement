using System.Security.Claims;
using CourseManagement.Domain.Interfaces;
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Authentication.JwtBearer;

namespace CourseManagement.API.Security;

public sealed class JwtSecurityStampEvents : JwtBearerEvents
{
    private readonly IUserRepository userRepository;
    private readonly ILogger<JwtSecurityStampEvents> logger;

    public JwtSecurityStampEvents(
        IUserRepository userRepository,
        ILogger<JwtSecurityStampEvents> logger)
    {
        this.userRepository = userRepository;
        this.logger = logger;
        OnTokenValidated = ValidateTokenAsync;
    }

    private async Task ValidateTokenAsync(TokenValidatedContext context)
    {
        if (!TryReadIdentity(context.Principal, out var userId, out var stamp))
        {
            context.Fail("The token does not contain a valid identity.");
            return;
        }

        var user = await userRepository.GetByIdAsync(userId);
        if (user is null || !user.IsActive || !string.Equals(
                user.SecurityStamp.ToString("N"), stamp, StringComparison.OrdinalIgnoreCase))
        {
            context.Fail("The account is inactive or the token has been revoked.");
            return;
        }

        logger.LogDebug("Validated JWT security stamp for user {UserId}.", userId);
    }

    private static bool TryReadIdentity(ClaimsPrincipal? principal, out int userId, out string stamp)
    {
        userId = 0;
        stamp = string.Empty;

        var userIdValue = principal?.FindFirstValue(ClaimTypes.NameIdentifier);
        var stampValue = principal?.FindFirstValue("security_stamp");
        if (!int.TryParse(userIdValue, out userId) || string.IsNullOrWhiteSpace(stampValue))
            return false;

        stamp = stampValue;
        return true;
    }
}
