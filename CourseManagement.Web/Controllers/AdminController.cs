using System.Security.Claims;
using CourseManagement.Web.Security;
using CourseManagement.Web.ViewModels;
using CourseManagement.Application.DTOs;
using CourseManagement.Application.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace CourseManagement.Web.Controllers;

[Route("Admin")]
[Authorize(Roles = "Admin", AuthenticationSchemes = MvcAuthenticationDefaults.Scheme)]
public sealed class AdminController(IUserService userService, IEnrollmentService enrollmentService, IAuthService authService, ICourseService courseService) : Controller
{
    [HttpGet("Users")]
    public async Task<IActionResult> Users()
        => View(await userService.GetAllUsersAsync());

    [HttpGet("Enrollments")]
    public async Task<IActionResult> Enrollments()
        => View(await enrollmentService.GetAllEnrollmentsAsync());

    [HttpGet("CreateEnrollment")]
    public async Task<IActionResult> CreateEnrollment()
        => View(new EnrollmentCreateViewModel
        {
            Users = await userService.GetAllUsersAsync(),
            Courses = await courseService.GetAllCoursesAsync()
        });

    [HttpPost("CreateEnrollment")]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> CreateEnrollment(EnrollmentCreateViewModel model)
    {
        if (!ModelState.IsValid)
        {
            model = new EnrollmentCreateViewModel
            {
                UserId = model.UserId,
                CourseId = model.CourseId,
                Users = await userService.GetAllUsersAsync(),
                Courses = await courseService.GetAllCoursesAsync()
            };
            return View(model);
        }

        try
        {
            await enrollmentService.EnrollUserAsync(model.UserId, model.CourseId);
            TempData["Success"] = "تم إنشاء التسجيل.";
            return RedirectToAction(nameof(Enrollments));
        }
        catch (Exception ex)
        {
            ModelState.AddModelError(string.Empty, ex.Message);
            model = new EnrollmentCreateViewModel
            {
                UserId = model.UserId,
                CourseId = model.CourseId,
                Users = await userService.GetAllUsersAsync(),
                Courses = await courseService.GetAllCoursesAsync()
            };
            return View(model);
        }
    }

    [HttpGet("EnrollmentDetails/{id:int}")]
    public async Task<IActionResult> EnrollmentDetails(int id)
    {
        var enrollment = await enrollmentService.GetEnrollmentByIdAsync(id);
        return enrollment is null ? NotFound() : View(enrollment);
    }

    [HttpGet("EditEnrollment/{id:int}")]
    public async Task<IActionResult> EditEnrollment(int id)
    {
        var enrollment = await enrollmentService.GetEnrollmentByIdAsync(id);
        if (enrollment is null) return NotFound();
        return View(new EnrollmentEditViewModel
        {
            EnrollmentId = enrollment.Id,
            CurrentCourseId = enrollment.CourseId,
            CourseId = enrollment.CourseId,
            Courses = await courseService.GetAllCoursesAsync()
        });
    }

    [HttpPost("EditEnrollment/{id:int}")]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> EditEnrollment(int id, EnrollmentEditViewModel model)
    {
        if (id != model.EnrollmentId) return BadRequest();
        if (!ModelState.IsValid)
        {
            model = new EnrollmentEditViewModel
            {
                EnrollmentId = id,
                CurrentCourseId = model.CurrentCourseId,
                CourseId = model.CourseId,
                Courses = await courseService.GetAllCoursesAsync()
            };
            return View(model);
        }

        try
        {
            await enrollmentService.UpdateEnrollmentAsync(id, model.CourseId);
            TempData["Success"] = "تم تحديث التسجيل.";
            return RedirectToAction(nameof(EnrollmentDetails), new { id });
        }
        catch (Exception ex)
        {
            TempData["Error"] = ex.Message;
            return RedirectToAction(nameof(EnrollmentDetails), new { id });
        }
    }

    [HttpPost("DeleteEnrollment/{id:int}")]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> DeleteEnrollment(int id)
    {
        try
        {
            var enrollment = await enrollmentService.GetEnrollmentByIdAsync(id);
            if (enrollment is null) return NotFound();
            await enrollmentService.UnenrollUserAsync(enrollment.UserId, enrollment.CourseId);
            TempData["Success"] = "تم حذف التسجيل.";
        }
        catch (Exception ex)
        {
            TempData["Error"] = ex.Message;
        }
        return RedirectToAction(nameof(Enrollments));
    }

    [HttpGet("CreateUser")]
    public IActionResult CreateUser() => View(new RegisterViewModel());

    [HttpPost("CreateUser")]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> CreateUser(RegisterViewModel model)
    {
        if (!ModelState.IsValid) return View(model);
        try
        {
            await authService.RegisterAsync(model.ToDto());
            TempData["Success"] = "تم إنشاء المستخدم.";
            return RedirectToAction(nameof(Users));
        }
        catch (Exception ex)
        {
            ModelState.AddModelError(string.Empty, ex.Message);
            return View(model);
        }
    }

    [HttpGet("UserDetails/{id:int}")]
    public async Task<IActionResult> UserDetails(int id)
    {
        try { return View(await userService.GetUserByIdAsync(id)); }
        catch (KeyNotFoundException) { return NotFound(); }
    }

    [HttpGet("EditUser/{id:int}")]
    public async Task<IActionResult> EditUser(int id)
    {
        try
        {
            var user = await userService.GetUserByIdAsync(id);
            ViewData["UserId"] = id;
            return View(new UpdateUserDto { FullName = user.FullName, Email = user.Email });
        }
        catch (KeyNotFoundException) { return NotFound(); }
    }

    [HttpPost("EditUser/{id:int}")]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> EditUser(int id, UpdateUserDto model)
    {
        if (!ModelState.IsValid)
        {
            ViewData["UserId"] = id;
            return View(model);
        }
        try
        {
            await userService.UpdateProfileAsync(id, model);
            TempData["Success"] = "تم تحديث بيانات المستخدم.";
            return RedirectToAction(nameof(UserDetails), new { id });
        }
        catch (Exception ex)
        {
            ViewData["UserId"] = id;
            ModelState.AddModelError(string.Empty, ex.Message);
            return View(model);
        }
    }

    [HttpPost("ChangeRole")]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> ChangeRole(RoleFormViewModel model)
    {
        if (!ModelState.IsValid)
        {
            TempData["Error"] = "الدور المحدد غير صالح.";
            return RedirectToAction(nameof(Users));
        }

        try
        {
            await userService.ChangeRoleAsync(model.UserId, model.Role, GetUserId());
            TempData["Success"] = "تم تحديث دور المستخدم.";
        }
        catch (Exception ex)
        {
            TempData["Error"] = ex.Message;
        }

        return RedirectToAction(nameof(Users));
    }

    [HttpPost("DeleteUser/{id:int}")]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> DeleteUser(int id)
    {
        try
        {
            await userService.DeleteUserAsync(id, GetUserId());
            TempData["Success"] = "تم حذف المستخدم.";
        }
        catch (Exception ex)
        {
            TempData["Error"] = ex.Message;
        }

        return RedirectToAction(nameof(Users));
    }

    private int GetUserId()
        => int.TryParse(User.FindFirstValue(ClaimTypes.NameIdentifier), out var id) ? id : 0;
}
