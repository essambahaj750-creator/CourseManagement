using CourseManagement.API.Extensions;
using CourseManagement.Application.DTOs;
using CourseManagement.Application.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace CourseManagement.API.Controllers;

[Route("api/[controller]")]
[ApiController]
[Authorize]
public class EnrollmentController(IEnrollmentService enrollmentService) : ControllerBase
{
    [HttpGet]
    [Authorize(Roles = "Admin")]
    public async Task<IActionResult> GetAll(
        [FromQuery] int page = 1,
        [FromQuery] int pageSize = 50,
        CancellationToken cancellationToken = default) =>
        Ok(await enrollmentService.GetEnrollmentsPageAsync(page, pageSize, cancellationToken));

    [HttpGet("{id:int}")]
    public async Task<IActionResult> GetById(int id)
    {
        var enrollment = await enrollmentService.GetEnrollmentByIdAsync(id);
        if (enrollment == null)
            return NotFound(new { message = "Enrollment not found" });

        if (!User.IsAdmin() && enrollment.UserId != User.GetUserId())
            return Forbid();

        return Ok(enrollment);
    }

    [HttpGet("user/{userId:int}")]
    public async Task<IActionResult> GetByUser(int userId)
    {
        if (!User.IsAdmin() && userId != User.GetUserId())
            return Forbid();

        return Ok(await enrollmentService.GetEnrollmentsByUserAsync(userId));
    }

    [HttpGet("my")]
    public async Task<IActionResult> GetMy() =>
        Ok(await enrollmentService.GetEnrollmentsByUserAsync(User.GetUserId()));

    [HttpGet("course/{courseId:int}")]
    [Authorize(Roles = "Instructor,Admin")]
    public async Task<IActionResult> GetByCourse(int courseId) =>
        Ok(await enrollmentService.GetEnrollmentsByCourseAsync(courseId, User.GetUserId(), User.IsAdmin()));

    [HttpPost]
    public async Task<IActionResult> Enroll([FromBody] EnrollDto dto)
    {
        var enrollment = await enrollmentService.EnrollUserAsync(User.GetUserId(), dto.CourseId);
        return CreatedAtAction(nameof(GetById), new { id = enrollment.Id }, enrollment);
    }

    [HttpDelete("course/{courseId:int}")]
    public async Task<IActionResult> Unenroll(int courseId)
    {
        await enrollmentService.UnenrollUserAsync(User.GetUserId(), courseId);
        return NoContent();
    }
}
