using System.Security.Claims;
using CourseManagement.Application.Common;
using CourseManagement.Application.DTOs;
using CourseManagement.Domain.Enums;
using CourseManagement.Web.Extensions;
using CourseManagement.Web.Security;
using CourseManagement.Web.ViewModels;
using CourseManagement.Application.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace CourseManagement.Web.Controllers;

[Route("Courses")]
public sealed class CoursesController(
    ICourseService courseService,
    ICourseAssetService assetService,
    IUserService userService) : Controller
{
    [HttpGet("")]
    [AllowAnonymous]
    public async Task<IActionResult> Index([FromQuery] CourseFilterViewModel filter)
    {
        var catalog = await courseService.SearchCoursesAsync(filter.ToDto());
        var instructors = await courseService.GetInstructorOptionsAsync();

        foreach (var course in catalog.Items)
            UseMvcCoverUrl(course);

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
        UseMvcCoverUrl(course);

        var preview = await assetService.GetPreviewAsync(id, cancellationToken);
        var curriculum = await assetService.GetPublicCurriculumAsync(id, cancellationToken);
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
                // Public details and the dedicated preview clip remain available.
            }
        }

        return View(new CourseDetailsViewModel
        {
            Course = course,
            CanAccessAssets = canAccessAssets,
            PreviewAsset = preview,
            Curriculum = curriculum,
            PreviewSeconds = 60
        });
    }

    [HttpGet("Details/{id:int}/Preview")]
    [AllowAnonymous]
    public async Task<IActionResult> Preview(int id, CancellationToken cancellationToken)
    {
        var preview = await assetService.OpenPreviewAsync(id, cancellationToken);
        return preview is null
            ? NotFound()
            : File(preview.Content, preview.ContentType, enableRangeProcessing: true);
    }

    [HttpGet("Details/{id:int}/Cover")]
    [AllowAnonymous]
    public async Task<IActionResult> Cover(int id, CancellationToken cancellationToken)
    {
        var cover = await assetService.OpenCoverAsync(id, cancellationToken);
        return cover is null
            ? NotFound()
            : File(cover.Content, cover.ContentType, enableRangeProcessing: false);
    }

    [HttpPost("Details/{id:int}/Cover/Delete")]
    [Authorize(Roles = "Instructor,Admin", AuthenticationSchemes = MvcAuthenticationDefaults.Scheme)]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> DeleteCover(int id, CancellationToken cancellationToken)
    {
        await assetService.DeleteCoverAsync(
            id,
            GetUserId(),
            User.IsInRole("Admin"),
            cancellationToken);
        TempData["Success"] = "تم حذف غلاف الكورس بنجاح.";
        return RedirectToAction(nameof(Edit), new { id });
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
                file.Length,
                type,
                stream,
                GetUserId(),
                User.IsInRole("Admin"),
                cancellationToken);

            TempData["Success"] = type switch
            {
                CourseAssetType.PreviewVideo => "تم حفظ فيديو المعاينة. هذا المقطع فقط متاح للزوار قبل التسجيل.",
                CourseAssetType.Video => "تم رفع درس الفيديو بنجاح. الدرس الكامل متاح للمسجلين والمالك فقط.",
                CourseAssetType.Attachment => "تم رفع المرفق وربطه بالكورس بنجاح.",
                _ => "تم رفع الملف وربطه بالكورس بنجاح."
            };
        }
        catch (InvalidRequestException exception)
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

    [HttpGet("Details/{id:int}/Assets/{assetId:int}/Stream")]
    [Authorize(AuthenticationSchemes = MvcAuthenticationDefaults.Scheme)]
    public async Task<IActionResult> StreamAsset(
        int id,
        int assetId,
        CancellationToken cancellationToken)
    {
        var asset = await assetService.OpenDownloadAsync(
            id,
            assetId,
            GetUserId(),
            User.IsInRole("Admin"),
            cancellationToken);
        return File(asset.Content, asset.ContentType, enableRangeProcessing: true);
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
    public async Task<IActionResult> Create()
    {
        var model = new CourseFormViewModel();
        if (User.IsInRole("Admin"))
            model.Instructors = await LoadInstructorChoicesAsync();
        return View(model);
    }

    [HttpPost("Create")]
    [Authorize(Roles = "Instructor,Admin", AuthenticationSchemes = MvcAuthenticationDefaults.Scheme)]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> Create(CourseFormViewModel model, CancellationToken cancellationToken)
    {
        var instructorId = GetUserId();
        if (User.IsInRole("Admin"))
        {
            model.Instructors = await LoadInstructorChoicesAsync();
            if (!TryResolveInstructor(model, out instructorId))
                ModelState.AddModelError(nameof(model.InstructorId), "اختر حسابًا بدور مدرّس ليكون مسؤولًا عن الكورس.");
        }

        if (!ModelState.IsValid) return View(model);

        CourseResponseDto? course = null;
        try
        {
            course = await courseService.CreateCourseAsync(model.ToDto(), instructorId);
            if (model.CoverImage is not null)
            {
                await using var content = model.CoverImage.OpenReadStream();
                await assetService.UploadCoverAsync(
                    course.Id,
                    model.CoverImage.FileName,
                    model.CoverImage.Length,
                    content,
                    GetUserId(),
                    User.IsInRole("Admin"),
                    cancellationToken);
            }

            TempData["Success"] = "تم إنشاء الكورس وإسناده للمدرّس بنجاح.";
            return RedirectToAction(nameof(Details), new { id = course.Id });
        }
        catch (Exception exception)
        {
            if (course is not null)
            {
                try
                {
                    await courseService.DeleteCourseAsync(course.Id, GetUserId(), User.IsInRole("Admin"));
                }
                catch
                {
                    // Preserve the original failure rather than masking it with this one.
                }
            }

            if (!exception.IsUserFacing())
                throw;

            ModelState.AddModelError(string.Empty, exception.Message);
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
            InstructorId = course.InstructorId,
            Instructors = User.IsInRole("Admin")
                ? await LoadInstructorChoicesAsync(course.InstructorId)
                : [],
            CurrentCoverUrl = string.IsNullOrWhiteSpace(course.ImageUrl)
                ? null
                : Url.Action(nameof(Cover), new { id = course.Id })
        });
    }

    [HttpPost("Edit/{id:int}")]
    [Authorize(Roles = "Instructor,Admin", AuthenticationSchemes = MvcAuthenticationDefaults.Scheme)]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> Edit(int id, CourseFormViewModel model, CancellationToken cancellationToken)
    {
        if (id != model.Id) return BadRequest();

        int? targetInstructorId = null;
        if (User.IsInRole("Admin"))
        {
            model.Instructors = await LoadInstructorChoicesAsync(model.InstructorId);
            if (!TryResolveInstructor(model, out var resolvedInstructorId))
                ModelState.AddModelError(nameof(model.InstructorId), "يجب إسناد الكورس إلى حساب مدرّس فعّال.");
            else
                targetInstructorId = resolvedInstructorId;
        }

        if (!ModelState.IsValid) return View(model);

        try
        {
            var course = await courseService.UpdateCourseAsync(
                id,
                model.ToDto(),
                GetUserId(),
                User.IsInRole("Admin"),
                targetInstructorId);

            if (model.CoverImage is not null)
            {
                await using var content = model.CoverImage.OpenReadStream();
                await assetService.UploadCoverAsync(
                    id,
                    model.CoverImage.FileName,
                    model.CoverImage.Length,
                    content,
                    GetUserId(),
                    User.IsInRole("Admin"),
                    cancellationToken);
            }

            TempData["Success"] = "تم تحديث الكورس وبيانات المدرّس بنجاح.";
            return RedirectToAction(nameof(Details), new { id = course.Id });
        }
        catch (Exception ex) when (ex.IsUserFacing())
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
        catch (Exception ex) when (ex.IsUserFacing())
        {
            TempData["Error"] = ex.Message;
            return RedirectToAction(nameof(Details), new { id });
        }
    }

    private async Task<IReadOnlyList<UserResponseDto>> LoadInstructorChoicesAsync(int? includeUserId = null)
    {
        var users = await userService.GetAllUsersAsync();
        return users
            .Where(user =>
                string.Equals(user.Role, "Instructor", StringComparison.OrdinalIgnoreCase) ||
                (includeUserId.HasValue && user.Id == includeUserId.Value))
            .OrderBy(user => user.FullName)
            .ToList();
    }

    private static bool IsInstructor(UserResponseDto user)
        => string.Equals(user.Role, "Instructor", StringComparison.OrdinalIgnoreCase);

    private static bool TryResolveInstructor(CourseFormViewModel model, out int instructorId)
    {
        instructorId = 0;
        if (!model.InstructorId.HasValue)
            return false;

        var selected = model.Instructors.FirstOrDefault(item => item.Id == model.InstructorId.Value);
        if (selected is null || !IsInstructor(selected))
            return false;

        instructorId = selected.Id;
        return true;
    }

    private void UseMvcCoverUrl(CourseResponseDto course)
    {
        if (!string.IsNullOrWhiteSpace(course.ImageUrl))
            course.ImageUrl = Url.Action(nameof(Cover), new { id = course.Id });
    }

    private int GetUserId()
        => int.TryParse(User.FindFirstValue(ClaimTypes.NameIdentifier), out var id) ? id : 0;

    private bool CanManage(int instructorId) => User.IsInRole("Admin") || instructorId == GetUserId();
}
