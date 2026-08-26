using System.Security.Claims;
using CourseManagement.Application.Common;
using CourseManagement.Web.Extensions;
using CourseManagement.Web.Security;
using CourseManagement.Web.ViewModels;
using CourseManagement.Application.Interfaces;
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;

namespace CourseManagement.Web.Controllers;

[Route("Account")]
[EnableRateLimiting("auth")]
public sealed class AccountController(IAuthService authService) : Controller
{
    [HttpGet("Login")]
    [AllowAnonymous]
    public IActionResult Login(string? returnUrl = null) => View(new LoginViewModel { ReturnUrl = returnUrl });

    [HttpPost("Login")]
    [AllowAnonymous]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> Login(LoginViewModel model)
    {
        if (!ModelState.IsValid) return View(model);

        try
        {
            var auth = await authService.LoginAsync(model.ToDto());
            await SignInAsync(auth.UserId, auth.FullName, auth.Email, auth.Role, auth.SecurityStamp, model.RememberMe, auth.ExpiresAtUtc);
            return RedirectToLocal(model.ReturnUrl);
        }
        catch (UnauthorizedAccessException)
        {
            ModelState.AddModelError(string.Empty, "البريد الإلكتروني أو كلمة المرور غير صحيحة.");
            return View(model);
        }
        catch (Exception)
        {
            ModelState.AddModelError(string.Empty, "تعذر تسجيل الدخول حاليًا. حاول مرة أخرى.");
            return View(model);
        }
    }

    [HttpGet("Register")]
    [AllowAnonymous]
    public IActionResult Register() => View(new RegisterViewModel());

    [HttpPost("Register")]
    [AllowAnonymous]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> Register(RegisterViewModel model)
    {
        if (!ModelState.IsValid) return View(model);

        try
        {
            var auth = await authService.RegisterAsync(model.ToDto());
            await SignInAsync(auth.UserId, auth.FullName, auth.Email, auth.Role, auth.SecurityStamp, false, auth.ExpiresAtUtc);
            TempData["Success"] = "تم إنشاء حسابك بنجاح.";
            return RedirectToAction("Index", "Home");
        }
        catch (ConflictException ex)
        {
            ModelState.AddModelError(string.Empty, ex.Message);
            return View(model);
        }
        catch (Exception)
        {
            ModelState.AddModelError(string.Empty, "تعذر إنشاء الحساب حاليًا. حاول مرة أخرى.");
            return View(model);
        }
    }

    [Authorize]
    [HttpGet("ChangePassword")]
    public IActionResult ChangePassword() => View(new ChangePasswordViewModel());

    [Authorize]
    [HttpPost("ChangePassword")]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> ChangePassword(ChangePasswordViewModel model)
    {
        if (!ModelState.IsValid) return View(model);

        try
        {
            await authService.ChangePasswordAsync(User.GetUserId(), model.ToDto());
            await HttpContext.SignOutAsync(MvcAuthenticationDefaults.Scheme);
            TempData["Success"] = "تم تغيير كلمة المرور. سجّل الدخول مرة أخرى.";
            return RedirectToAction(nameof(Login));
        }
        catch (UnauthorizedAccessException)
        {
            ModelState.AddModelError(nameof(model.CurrentPassword), "كلمة المرور الحالية غير صحيحة.");
            return View(model);
        }
        catch (ConflictException ex)
        {
            ModelState.AddModelError(string.Empty, ex.Message);
            return View(model);
        }
        catch (Exception)
        {
            ModelState.AddModelError(string.Empty, "تعذر تغيير كلمة المرور حاليًا. حاول مرة أخرى.");
            return View(model);
        }
    }

    [HttpPost("Logout")]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> Logout()
    {
        await HttpContext.SignOutAsync(MvcAuthenticationDefaults.Scheme);
        return RedirectToAction("Index", "Home");
    }

    [HttpGet("AccessDenied")]
    [AllowAnonymous]
    public IActionResult AccessDenied() => View();

    private async Task SignInAsync(int userId, string fullName, string email, string role, string securityStamp, bool isPersistent, DateTime expiresAtUtc)
    {
        var claims = new List<Claim>
        {
            new(ClaimTypes.NameIdentifier, userId.ToString()),
            new("security_stamp", securityStamp),
            new(ClaimTypes.Name, fullName),
            new(ClaimTypes.Email, email),
            new(ClaimTypes.Role, role)
        };

        var identity = new ClaimsIdentity(claims, MvcAuthenticationDefaults.Scheme);
        var properties = new AuthenticationProperties
        {
            IsPersistent = isPersistent,
            AllowRefresh = true,
            ExpiresUtc = expiresAtUtc
        };

        await HttpContext.SignInAsync(
            MvcAuthenticationDefaults.Scheme,
            new ClaimsPrincipal(identity),
            properties);
    }

    private IActionResult RedirectToLocal(string? returnUrl)
        => !string.IsNullOrWhiteSpace(returnUrl) && Url.IsLocalUrl(returnUrl)
            ? Redirect(returnUrl)
            : RedirectToAction("Index", "Home")!;
}
