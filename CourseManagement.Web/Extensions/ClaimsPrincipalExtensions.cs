using System.Security.Claims;
using CourseManagement.Domain.Enums;

namespace CourseManagement.Web.Extensions;

public static class ClaimsPrincipalExtensions
{
    /// <summary>
    /// يستخرج معرف المستخدم من التوكن بأمان.
    /// (كان الكود السابق يستخدم int.Parse مع null-forgiving مما قد يسبب انهياراً 500)
    /// </summary>
    public static int GetUserId(this ClaimsPrincipal user)
    {
        var value = user.FindFirstValue(ClaimTypes.NameIdentifier);
        return int.TryParse(value, out var id)
            ? id
            : throw new UnauthorizedAccessException("Invalid or missing user identifier claim.");
    }

    public static bool IsAdmin(this ClaimsPrincipal user) => user.IsInRole(nameof(Role.Admin));
}
