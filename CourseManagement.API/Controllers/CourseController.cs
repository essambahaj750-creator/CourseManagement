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
    ICourseAssetService assetService) : ControllerBase
{
    /// <summary>كتالوج الكورسات — عام</summary>
    [HttpGet]
    public async Task<IActionResult> GetAll() =>
        Ok(await courseService.GetAllCoursesAsync());

    /// <summary>بحث الكتالوج مع الفلاتر والترتيب والتقسيم الصفحي</summary>
    [HttpGet("search")]
    public async Task<IActionResult> Search([FromQuery] CourseFilterDto filter) =>
        Ok(await courseService.SearchCoursesAsync(filter));

    /// <summary>قائمة المدرّسين المتاحين للفلاتر</summary>
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

    [HttpGet("{id:int}/cover")]
    [AllowAnonymous]
    public async Task<IActionResult> GetCover(int id, CancellationToken cancellationToken)
    {
        var cover = await assetService.OpenCoverAsync(id, cancellationToken);
        return cover is null
            ? NotFound(new { message = "Course cover not found" })
            : File(cover.Content, cover.ContentType, enableRangeProcessing: false);
    }

    [HttpPost("{id:int}/cover")]
    [Authorize(Roles = "Instructor,Admin")]
    [Consumes("multipart/form-data")]
    [RequestSizeLimit(10L * 1024 * 1024)]
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

    // كانت مقيدة بـ Instructor,Admin رغم أن قائمة الكورسات كلها عامة أصلاً — تناقض منطقي
    [HttpGet("instructor/{instructorId:int}")]
    public async Task<IActionResult> GetByInstructor(int instructorId) =>
        Ok(await courseService.GetCoursesByInstructorAsync(instructorId));

    [HttpPost]
    [Authorize(Roles = "Instructor,Admin")]
    public async Task<IActionResult> Create([FromBody] CourseDto dto)
    {
        var course = await courseService.CreateCourseAsync(dto, User.GetUserId());
        return CreatedAtAction(nameof(GetById), new { id = course.Id }, course);
    }

    [HttpPut("{id:int}")]
    [Authorize(Roles = "Instructor,Admin")]
    public async Task<IActionResult> Update(int id, [FromBody] CourseDto dto) =>
        Ok(await courseService.UpdateCourseAsync(id, dto, User.GetUserId(), User.IsAdmin()));

    [HttpDelete("{id:int}")]
    [Authorize(Roles = "Instructor,Admin")]
    public async Task<IActionResult> Delete(int id)
    {
        await courseService.DeleteCourseAsync(id, User.GetUserId(), User.IsAdmin());
        return NoContent();
    }
}
