using System.Security.Claims;
using CourseManagement.Application.Common;
using CourseManagement.Domain.Enums;
using CourseManagement.Web.Security;
using CourseManagement.Web.ViewModels;
using CourseManagement.Application.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace CourseManagement.Web.Controllers;

[Route("Courses")]
public sealed class CoursesController(
    ICourseService courseService,
    ICourseAssetService assetService) : Controller
{
    [HttpGet("")]
    [AllowAnonymous]
    public async Task<IActionResult> Index([FromQuery] CourseFilterViewModel filter)
    {
        var catalog = await courseService.SearchCoursesAsync(filter.ToDto());
        var instructors = await courseService.GetInstructorOptionsAsync();

        filter.Page = catalog.Page;
        filter.PageSize = catalog.PageSize;

        return View(new CoursesIndexViewModel
        {
            Courses = catalog.Items,
            Instructors = instructors,
            Filters = filter,
            TotalCount = catalog.TotalCount,
            TotalPages = catalog.TotalPages
        });
    }

    [HttpGet("Details/{id:int}")]
    [AllowAnonymous]
    public async Task<IActionResult> Details(int id, CancellationToken cancellationToken)
    {
        var course = await courseService.GetCourseByIdAsync(id);
        if (course is null) return NotFound();

        var canAccessAssets = false;
        if (User.Identity?.IsAuthenticated == true)
        {
            try
            {
                course.Assets = await assetService.GetByCourseIdAsync(
                    id,
                    GetUserId(),
                    User.IsInRole("Admin"),
                    cancellationToken);
                canAccessAssets = true;
            }
            catch (ForbiddenAccessException)
            {
                // غير المسجل يرى تفاصيل الكورس، لكن لا يرى الملفات الخاصة به.
            }
        }

        return View(new CourseDetailsViewModel { Course = course, CanAccessAssets = canAccessAssets });
    }

    [HttpPost("Details/{id:int}/Assets")]
    [Authorize(Roles = "Instructor,Admin", AuthenticationSchemes = MvcAuthenticationDefaults.Scheme)]
    [ValidateAntiForgeryToken]
    [RequestSizeLimit(512L * 1024 * 1024)]
    public async Task<IActionResult> UploadAsset(
        int id,
        IFormFile? file,
        CourseAssetType type,
        CancellationToken cancellationToken)
    {
        if (file is null)
        {
            TempData["Error"] = "اختر ملفًا قبل الرفع.";
            return RedirectToAction(nameof(Details), new { id });
        }

        try
        {
            await using var stream = file.OpenReadStream();
            await assetService.UploadAsync(
                id,
                file.FileName,
                file.ContentType,
                file.Length,
                type,
                stream,
                GetUserId(),
                User.IsInRole("Admin"),
                cancellationToken);
            TempData["Success"] = "تم رفع الملف وربطه بالكورس بنجاح.";
        }
        catch (ArgumentException exception)
        {
            TempData["Error"] = exception.Message;
        }
        catch (ForbiddenAccessException)
        {
            return Forbid();
        }
        catch (KeyNotFoundException)
        {
            return NotFound();
        }

        return RedirectToAction(nameof(Details), new { id });
    }

    [HttpGet("Details/{id:int}/Assets/{assetId:int}/Download")]
    [Authorize(AuthenticationSchemes = MvcAuthenticationDefaults.Scheme)]
    public async Task<IActionResult> DownloadAsset(
        int id,
        int assetId,
        CancellationToken cancellationToken)
    {
        var download = await assetService.OpenDownloadAsync(
            id,
            assetId,
            GetUserId(),
            User.IsInRole("Admin"),
            cancellationToken);
        return File(download.Content, download.ContentType, download.DownloadName, enableRangeProcessing: true);
    }

    [HttpPost("Details/{id:int}/Assets/{assetId:int}/Delete")]
    [Authorize(Roles = "Instructor,Admin", AuthenticationSchemes = MvcAuthenticationDefaults.Scheme)]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> DeleteAsset(
        int id,
        int assetId,
        CancellationToken cancellationToken)
    {
        await assetService.DeleteAsync(
            id,
            assetId,
            GetUserId(),
            User.IsInRole("Admin"),
            cancellationToken);
        TempData["Success"] = "تم حذف الملف بنجاح.";
        return RedirectToAction(nameof(Details), new { id });
    }

    [HttpGet("Create")]
    [Authorize(Roles = "Instructor,Admin", AuthenticationSchemes = MvcAuthenticationDefaults.Scheme)]
    public IActionResult Create() => View(new CourseFormViewModel());

    [HttpPost("Create")]
    [Authorize(Roles = "Instructor,Admin", AuthenticationSchemes = MvcAuthenticationDefaults.Scheme)]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> Create(CourseFormViewModel model)
    {
        if (!ModelState.IsValid) return View(model);

        try
        {
            var course = await courseService.CreateCourseAsync(model.ToDto(), GetUserId());
            TempData["Success"] = "تم إنشاء الكورس بنجاح.";
            return RedirectToAction(nameof(Details), new { id = course.Id });
        }
        catch (Exception ex)
        {
            ModelState.AddModelError(string.Empty, ex.Message);
            return View(model);
        }
    }

    [HttpGet("Edit/{id:int}")]
    [Authorize(Roles = "Instructor,Admin", AuthenticationSchemes = MvcAuthenticationDefaults.Scheme)]
    public async Task<IActionResult> Edit(int id)
    {
        var course = await courseService.GetCourseByIdAsync(id);
        if (course is null) return NotFound();
        if (!CanManage(course.InstructorId)) return Forbid();

        return View(new CourseFormViewModel
        {
            Id = course.Id,
            Title = course.Title,
            Description = course.Description,
            Price = course.Price,
            ImageUrl = course.ImageUrl
        });
    }

    [HttpPost("Edit/{id:int}")]
    [Authorize(Roles = "Instructor,Admin", AuthenticationSchemes = MvcAuthenticationDefaults.Scheme)]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> Edit(int id, CourseFormViewModel model)
    {
        if (id != model.Id) return BadRequest();
        if (!ModelState.IsValid) return View(model);

        try
        {
            var course = await courseService.UpdateCourseAsync(id, model.ToDto(), GetUserId(), User.IsInRole("Admin"));
            TempData["Success"] = "تم تحديث الكورس بنجاح.";
            return RedirectToAction(nameof(Details), new { id = course.Id });
        }
        catch (Exception ex)
        {
            ModelState.AddModelError(string.Empty, ex.Message);
            return View(model);
        }
    }

    [HttpGet("Delete/{id:int}")]
    [Authorize(Roles = "Instructor,Admin", AuthenticationSchemes = MvcAuthenticationDefaults.Scheme)]
    public async Task<IActionResult> Delete(int id)
    {
        var course = await courseService.GetCourseByIdAsync(id);
        if (course is null) return NotFound();
        if (!CanManage(course.InstructorId)) return Forbid();
        return View(course);
    }

    [HttpPost("Delete/{id:int}")]
    [Authorize(Roles = "Instructor,Admin", AuthenticationSchemes = MvcAuthenticationDefaults.Scheme)]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> DeleteConfirmed(int id)
    {
        try
        {
            await courseService.DeleteCourseAsync(id, GetUserId(), User.IsInRole("Admin"));
            TempData["Success"] = "تم حذف الكورس بنجاح.";
            return RedirectToAction(nameof(Index));
        }
        catch (Exception ex)
        {
            TempData["Error"] = ex.Message;
            return RedirectToAction(nameof(Details), new { id });
        }
    }

    private int GetUserId()
        => int.TryParse(User.FindFirstValue(ClaimTypes.NameIdentifier), out var id) ? id : 0;

    private bool CanManage(int instructorId) => User.IsInRole("Admin") || instructorId == GetUserId();
}
