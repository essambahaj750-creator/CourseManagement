using System.Security.Claims;
using CourseManagement.Domain.Interfaces;
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Authentication.Cookies;

namespace CourseManagement.Web.Security;

public sealed class MvcCookieSecurityEvents : CookieAuthenticationEvents
{
    private readonly IUserRepository userRepository;
    private readonly ILogger<MvcCookieSecurityEvents> logger;

    public MvcCookieSecurityEvents(
        IUserRepository userRepository,
        ILogger<MvcCookieSecurityEvents> logger)
    {
        this.userRepository = userRepository;
        this.logger = logger;
    }

    public override async Task ValidatePrincipal(CookieValidatePrincipalContext context)
    {
        if (!TryReadIdentity(context.Principal, out var userId, out var stamp))
        {
            await RejectAsync(context);
            return;
        }

        var user = await userRepository.GetByIdAsync(userId);
        if (user is null || !user.IsActive || !string.Equals(
                user.SecurityStamp.ToString("N"), stamp, StringComparison.OrdinalIgnoreCase))
        {
            logger.LogInformation("Rejected stale or inactive MVC cookie for user {UserId}.", userId);
            await RejectAsync(context);
        }
    }

    private static async Task RejectAsync(CookieValidatePrincipalContext context)
    {
        context.RejectPrincipal();
        await context.HttpContext.SignOutAsync(MvcAuthenticationDefaults.Scheme);
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
