using CourseManagement.Application.DTOs;
using CourseManagement.Application.Interfaces;
using CourseManagement.Domain.Entities;
using CourseManagement.Domain.Interfaces;

namespace CourseManagement.Infrastructure.Services;

public class EnrollmentService(IEnrollmentRepository enrollmentRepository) : IEnrollmentService
{
    public async Task<IEnumerable<EnrollmentDto>> GetAllEnrollmentsAsync()
    {
        var enrollments = await enrollmentRepository.GetAllAsync();
        return enrollments.Select(MapToDto);
    }

    public async Task<EnrollmentDto?> GetEnrollmentByIdAsync(int id)
    {
        var enrollment = await enrollmentRepository.GetByIdAsync(id);
        return enrollment == null ? null : MapToDto(enrollment);
    }

    public async Task<IEnumerable<EnrollmentDto>> GetEnrollmentsByUserAsync(int userId)
    {
        var enrollments = await enrollmentRepository.GetByUserIdAsync(userId);
        return enrollments.Select(MapToDto);
    }

    public async Task<IEnumerable<EnrollmentDto>> GetEnrollmentsByCourseAsync(int courseId)
    {
        var enrollments = await enrollmentRepository.GetByCourseIdAsync(courseId);
        return enrollments.Select(MapToDto);
    }

    public async Task<EnrollmentDto> EnrollUserAsync(int userId, int courseId)
    {
        var isEnrolled = await enrollmentRepository.IsUserEnrolledAsync(userId, courseId);
        if (isEnrolled)
            throw new InvalidOperationException("User is already enrolled in this course.");

        var enrollment = new Enrollment
        {
            UserId = userId,
            CourseId = courseId,
            EnrolledDate = DateTime.UtcNow
        };

        await enrollmentRepository.AddAsync(enrollment);
        return MapToDto(enrollment);
    }

    public async Task<bool> UnenrollUserAsync(int userId, int courseId)
    {
        var enrollment = await enrollmentRepository.GetByUserAndCourseAsync(userId, courseId);
        if (enrollment == null)
            return false;

        await enrollmentRepository.DeleteAsync(enrollment.Id);
        return true;
    }

    private static EnrollmentDto MapToDto(Enrollment enrollment) => new()
    {
        Id = enrollment.Id,
        UserId = enrollment.UserId,
        UserName = enrollment.User?.FullName ?? "Unknown",
        CourseId = enrollment.CourseId,
        CourseTitle = enrollment.Course?.Title ?? "Unknown",
        EnrolledDate = enrollment.EnrolledDate
    };
}