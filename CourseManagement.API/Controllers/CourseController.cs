using CourseManagement.API.Extensions;
using CourseManagement.Application.DTOs;
using CourseManagement.Application.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace CourseManagement.API.Controllers;

[Route("api/[controller]")]
[ApiController]
public class CourseController(ICourseService courseService) : ControllerBase
{
    /// <summary>كتالوج الكورسات — عام</summary>
    [HttpGet]
    public async Task<IActionResult> GetAll() =>
        Ok(await courseService.GetAllCoursesAsync());

    [HttpGet("{id:int}")]
    public async Task<IActionResult> GetById(int id)
    {
        var course = await courseService.GetCourseByIdAsync(id);
        if (course == null)
            return NotFound(new { message = "Course not found" });
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
