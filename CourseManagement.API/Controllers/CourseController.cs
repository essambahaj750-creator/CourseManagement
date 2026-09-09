using CourseManagement.API.Extensions;
using CourseManagement.Application.DTOs;
using CourseManagement.Application.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace CourseManagement.API.Controllers;

[Route("api/[controller]")]
[ApiController]
public class CourseController(
    ICourseService courseService,
    ICourseAssetService assetService,
    IUserService userService,
    ICourseReviewService reviewService) : ControllerBase
{
    /// <summary>كتالوج الكورسات — عام</summary>
    [HttpGet]
    public async Task<IActionResult> GetAll() =>
        Ok(await courseService.GetAllCoursesAsync());

    /// <summary>بحث الكتالوج مع الفلاتر والترتيب والتقسيم الصفحي</summary>
    [HttpGet("search")]
    public async Task<IActionResult> Search([FromQuery] CourseFilterDto filter) =>
        Ok(await courseService.SearchCoursesAsync(filter));

    /// <summary>قائمة المدرّسين المتاحين للفلاتر والإسناد</summary>
    [HttpGet("instructors")]
    public async Task<IActionResult> GetInstructors() =>
        Ok(await courseService.GetInstructorOptionsAsync());

    [HttpGet("{id:int}")]
    public async Task<IActionResult> GetById(int id)
    {
        var course = await courseService.GetCourseByIdAsync(id);
        if (course == null)
            return NotFound(new { message = "Course not found" });
        return Ok(course);
    }

    /// <summary>عناوين دروس الكورس العامة بدون كشف روابط أو ملفات المحتوى المحمي.</summary>
    [HttpGet("{id:int}/curriculum")]
    [AllowAnonymous]
    public async Task<IActionResult> GetCurriculum(int id, CancellationToken cancellationToken) =>
        Ok(await assetService.GetPublicCurriculumAsync(id, cancellationToken));

    [HttpGet("{id:int}/reviews")]
    [AllowAnonymous]
    public async Task<IActionResult> GetReviews(
        int id,
        CancellationToken cancellationToken) =>
        Ok(await reviewService.GetSummaryAsync(id, cancellationToken));

    [HttpPut("{id:int}/reviews")]
    [Authorize]
    public async Task<IActionResult> UpsertReview(
        int id,
        [FromBody] CourseReviewUpsertDto dto,
        CancellationToken cancellationToken) =>
        Ok(await reviewService.UpsertAsync(
            User.GetUserId(),
            id,
            dto.Rating,
            dto.Comment,
            cancellationToken));

    [HttpDelete("{id:int}/reviews")]
    [Authorize]
    public async Task<IActionResult> DeleteReview(
        int id,
        CancellationToken cancellationToken)
    {
        await reviewService.DeleteOwnAsync(
            User.GetUserId(),
            id,
            cancellationToken);
        return NoContent();
    }

    [HttpGet("{id:int}/cover")]
    [AllowAnonymous]
    public async Task<IActionResult> GetCover(int id, CancellationToken cancellationToken)
    {
        var cover = await assetService.OpenCoverAsync(id, cancellationToken);
        return cover is null
            ? NotFound(new { message = "Course cover not found" })
            : File(cover.Content, cover.ContentType, enableRangeProcessing: false);
    }

    /// <summary>مقطع معاينة عام مستقل عن فيديوهات الدروس المحمية.</summary>
    [HttpGet("{id:int}/preview")]
    [AllowAnonymous]
    public async Task<IActionResult> GetPreview(int id, CancellationToken cancellationToken)
    {
        var preview = await assetService.OpenPreviewAsync(id, cancellationToken);
        return preview is null
            ? NotFound(new { message = "Course preview not found" })
            : File(preview.Content, preview.ContentType, enableRangeProcessing: true);
    }

    [HttpPost("{id:int}/cover")]
    [Authorize(Roles = "Instructor,Admin")]
    [Consumes("multipart/form-data")]
    public async Task<ActionResult<CourseResponseDto>> UploadCover(
        int id,
        IFormFile? file,
        CancellationToken cancellationToken)
    {
        if (file is null)
            return BadRequest(new { message = "A cover image is required." });

        await using var content = file.OpenReadStream();
        await assetService.UploadCoverAsync(
            id,
            file.FileName,
            file.Length,
            content,
            User.GetUserId(),
            User.IsAdmin(),
            cancellationToken);

        var course = await courseService.GetCourseByIdAsync(id);
        return Ok(course);
    }

    [HttpDelete("{id:int}/cover")]
    [Authorize(Roles = "Instructor,Admin")]
    public async Task<IActionResult> DeleteCover(int id, CancellationToken cancellationToken)
    {
        await assetService.DeleteCoverAsync(
            id,
            User.GetUserId(),
            User.IsAdmin(),
            cancellationToken);
        return NoContent();
    }

    [HttpGet("instructor/{instructorId:int}")]
    public async Task<IActionResult> GetByInstructor(int instructorId) =>
        Ok(await courseService.GetCoursesByInstructorAsync(instructorId));

    [HttpPost]
    [Authorize(Roles = "Instructor,Admin")]
    public async Task<IActionResult> Create([FromBody] CourseDto dto)
    {
        var instructorId = User.GetUserId();
        if (User.IsAdmin())
        {
            var resolved = await ResolveInstructorAsync(dto.InstructorId);
            if (resolved is null)
                return BadRequest(new { message = "Admin must assign the course to a valid Instructor account." });
            instructorId = resolved.Value;
        }

        var course = await courseService.CreateCourseAsync(dto, instructorId);
        return CreatedAtAction(nameof(GetById), new { id = course.Id }, course);
    }

    [HttpPut("{id:int}")]
    [Authorize(Roles = "Instructor,Admin")]
    public async Task<IActionResult> Update(int id, [FromBody] CourseDto dto)
    {
        int? instructorId = null;
        if (User.IsAdmin() && dto.InstructorId.HasValue)
        {
            instructorId = await ResolveInstructorAsync(dto.InstructorId);
            if (!instructorId.HasValue)
                return BadRequest(new { message = "The selected course owner must have the Instructor role." });
        }

        return Ok(await courseService.UpdateCourseAsync(
            id,
            dto,
            User.GetUserId(),
            User.IsAdmin(),
            instructorId));
    }

    [HttpDelete("{id:int}")]
    [Authorize(Roles = "Instructor,Admin")]
    public async Task<IActionResult> Delete(int id)
    {
        await courseService.DeleteCourseAsync(id, User.GetUserId(), User.IsAdmin());
        return NoContent();
    }

    private async Task<int?> ResolveInstructorAsync(int? instructorId)
    {
        if (!instructorId.HasValue || instructorId.Value <= 0)
            return null;

        try
        {
            var user = await userService.GetUserByIdAsync(instructorId.Value);
            return string.Equals(user.Role, "Instructor", StringComparison.OrdinalIgnoreCase)
                ? user.Id
                : null;
        }
        catch (KeyNotFoundException)
        {
            return null;
        }
    }
}
