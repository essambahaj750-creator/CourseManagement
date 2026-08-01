using CourseManagement.Application.DTOs;
using CourseManagement.Application.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using System.Security.Claims;

namespace CourseManagement.API.Controllers;

[Route("api/[controller]")]
[ApiController]
[Authorize]
public class EnrollmentController(IEnrollmentService enrollmentService) : ControllerBase
{
    [HttpGet]
    [Authorize(Roles = "Admin")]
    public async Task<IActionResult> GetAll()
    {
        var enrollments = await enrollmentService.GetAllEnrollmentsAsync();
        return Ok(enrollments);
    }

    [HttpGet("{id}")]
    public async Task<IActionResult> GetById(int id)
    {
        var enrollment = await enrollmentService.GetEnrollmentByIdAsync(id);
        if (enrollment == null)
            return NotFound(new { message = "Enrollment not found" });
        return Ok(enrollment);
    }

    [HttpGet("user/{userId}")]
    public async Task<IActionResult> GetByUser(int userId)
    {
        var enrollments = await enrollmentService.GetEnrollmentsByUserAsync(userId);
        return Ok(enrollments);
    }

    [HttpGet("course/{courseId}")]
    public async Task<IActionResult> GetByCourse(int courseId)
    {
        var enrollments = await enrollmentService.GetEnrollmentsByCourseAsync(courseId);
        return Ok(enrollments);
    }

    [HttpPost]
    public async Task<IActionResult> Enroll([FromBody] EnrollDto dto)
    {
        var userId = int.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);
        try
        {
            var enrollment = await enrollmentService.EnrollUserAsync(userId, dto.CourseId);
            return Ok(new { message = "Enrolled successfully", enrollment });
        }
        catch (Exception ex)
        {
            return BadRequest(new { message = ex.Message });
        }
    }

    [HttpDelete("{courseId}")]
    public async Task<IActionResult> Unenroll(int courseId)
    {
        var userId = int.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);
        var result = await enrollmentService.UnenrollUserAsync(userId, courseId);
        if (!result)
            return NotFound(new { message = "Enrollment not found" });
        return Ok(new { message = "Unenrolled successfully" });
    }
}