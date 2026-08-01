using CourseManagement.Application.DTOs;
using CourseManagement.Application.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using System.Security.Claims;

namespace CourseManagement.API.Controllers;

[Route("api/[controller]")]
[ApiController]
public class CourseController(ICourseService courseService) : ControllerBase
{
    [HttpGet]
    public async Task<IActionResult> GetAll()
    {
        var courses = await courseService.GetAllCoursesAsync();
        return Ok(courses);
    }

    [HttpGet("{id}")]
    public async Task<IActionResult> GetById(int id)
    {
        var course = await courseService.GetCourseByIdAsync(id);
        if (course == null)
            return NotFound(new { message = "Course not found" });
        return Ok(course);
    }

    [HttpGet("instructor/{instructorId}")]
    [Authorize(Roles = "Instructor,Admin")]
    public async Task<IActionResult> GetByInstructor(int instructorId)
    {
        var courses = await courseService.GetCoursesByInstructorAsync(instructorId);
        return Ok(courses);
    }

    [HttpPost]
    [Authorize(Roles = "Instructor,Admin")]
    public async Task<IActionResult> Create([FromBody] CourseDto dto)
    {
        var instructorId = int.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);
        var course = await courseService.CreateCourseAsync(dto, instructorId);
        return CreatedAtAction(nameof(GetById), new { id = course.Id }, course);
    }

    [HttpPut("{id}")]
    [Authorize(Roles = "Instructor,Admin")]
    public async Task<IActionResult> Update(int id, [FromBody] CourseDto dto)
    {
        var instructorId = int.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);
        try
        {
            var course = await courseService.UpdateCourseAsync(id, dto, instructorId);
            return Ok(course);
        }
        catch (Exception ex)
        {
            return BadRequest(new { message = ex.Message });
        }
    }

    [HttpDelete("{id}")]
    [Authorize(Roles = "Instructor,Admin")]
    public async Task<IActionResult> Delete(int id)
    {
        var instructorId = int.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);
        var result = await courseService.DeleteCourseAsync(id, instructorId);
        if (!result)
            return NotFound(new { message = "Course not found or you are not the instructor" });
        return NoContent();
    }
}