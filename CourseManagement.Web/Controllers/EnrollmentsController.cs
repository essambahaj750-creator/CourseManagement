using System.Security.Claims;
using CourseManagement.Web.Extensions;
using CourseManagement.Web.Security;
using CourseManagement.Application.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace CourseManagement.Web.Controllers;

[Route("Enrollments")]
[Authorize(AuthenticationSchemes = MvcAuthenticationDefaults.Scheme)]
public sealed class EnrollmentsController(IEnrollmentService enrollmentService) : Controller
{
    [HttpGet("")]
    public async Task<IActionResult> Index()
        => View(await enrollmentService.GetEnrollmentsByUserAsync(GetUserId()));

    [HttpGet("Details/{id:int}")]
    public async Task<IActionResult> Details(int id)
    {
        var enrollment = await enrollmentService.GetEnrollmentByIdAsync(id);
        if (enrollment is null) return NotFound();
        if (enrollment.UserId != GetUserId() && !User.IsInRole("Admin")) return Forbid();
        return View(enrollment);
    }

    [HttpPost("Enroll/{courseId:int}")]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> Enroll(int courseId)
    {
        try
        {
            await enrollmentService.EnrollUserAsync(GetUserId(), courseId);
            TempData["Success"] = "تم تسجيلك في الكورس بنجاح.";
        }
        catch (Exception ex) when (ex.IsUserFacing())
        {
            TempData["Error"] = ex.Message;
        }

        return RedirectToAction("Details", "Courses", new { id = courseId });
    }

    [HttpPost("Progress/{courseId:int}/{assetId:int}")]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> UpdateProgress(int courseId, int assetId, bool completed)
    {
        try
        {
            await enrollmentService.UpdateCourseProgressAsync(
                GetUserId(),
                courseId,
                assetId,
                completed);
            TempData["Success"] = completed
                ? "تم حفظ إكمال الدرس."
                : "تمت إعادة الدرس إلى غير مكتمل.";
        }
        catch (Exception ex) when (ex.IsUserFacing())
        {
            TempData["Error"] = ex.Message;
        }

        return Redirect($"{Url.Action("Details", "Courses", new { id = courseId })}#lesson-{assetId}");
    }

    [HttpPost("Unenroll/{courseId:int}")]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> Unenroll(int courseId)
    {
        try
        {
            await enrollmentService.UnenrollUserAsync(GetUserId(), courseId);
            TempData["Success"] = "تم إلغاء التسجيل.";
        }
        catch (Exception ex) when (ex.IsUserFacing())
        {
            TempData["Error"] = ex.Message;
        }

        return RedirectToAction(nameof(Index));
    }

    private int GetUserId()
        => int.TryParse(User.FindFirstValue(ClaimTypes.NameIdentifier), out var id) ? id : 0;
}
