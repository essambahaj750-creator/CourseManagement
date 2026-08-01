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
    public async Task<IActionResult> GetAll() =>
        Ok(await enrollmentService.GetAllEnrollmentsAsync());

    // كان أي مستخدم مسجّل يستطيع قراءة تسجيل أي شخص آخر (IDOR) — الآن: صاحبه أو Admin فقط
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

    // كان أي مستخدم يستطيع عرض تسجيلات أي مستخدم آخر (IDOR) — الآن: نفسه أو Admin فقط
    [HttpGet("user/{userId:int}")]
    public async Task<IActionResult> GetByUser(int userId)
    {
        if (!User.IsAdmin() && userId != User.GetUserId())
            return Forbid();

        return Ok(await enrollmentService.GetEnrollmentsByUserAsync(userId));
    }

    /// <summary>تسجيلاتي أنا — اختصار مريح</summary>
    [HttpGet("my")]
    public async Task<IActionResult> GetMy() =>
        Ok(await enrollmentService.GetEnrollmentsByUserAsync(User.GetUserId()));

    // قائمة المسجّلين في كورس بيانات خاصة — مدرب الكورس أو Admin فقط (الملكية تُفحص في الخدمة)
    [HttpGet("course/{courseId:int}")]
    [Authorize(Roles = "Instructor,Admin")]
    public async Task<IActionResult> GetByCourse(int courseId) =>
        Ok(await enrollmentService.GetEnrollmentsByCourseAsync(courseId, User.GetUserId(), User.IsAdmin()));

    [HttpPost]
    public async Task<IActionResult> Enroll([FromBody] EnrollDto dto)
    {
        var enrollment = await enrollmentService.EnrollUserAsync(User.GetUserId(), dto.CourseId);
        // إنشاء مورد جديد يعيد 201 مع رابط المورد، وليس 200
        return CreatedAtAction(nameof(GetById), new { id = enrollment.Id }, enrollment);
    }

    // كان المسار DELETE api/enrollment/{courseId} يتصادم دلالياً مع GET api/enrollment/{id}
    // (نفس الشكل لكن الرقم يعني شيئاً مختلفاً!) — الآن المسار صريح
    [HttpDelete("course/{courseId:int}")]
    public async Task<IActionResult> Unenroll(int courseId)
    {
        await enrollmentService.UnenrollUserAsync(User.GetUserId(), courseId);
        return NoContent();
    }
}
