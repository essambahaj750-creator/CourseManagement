using CourseManagement.Application.Common;
using CourseManagement.Application.DTOs;
using CourseManagement.Application.Interfaces;
using CourseManagement.Domain.Entities;
using CourseManagement.Domain.Interfaces;

namespace CourseManagement.Infrastructure.Services;

public class EnrollmentService(
    IEnrollmentRepository enrollmentRepository,
    ICourseRepository courseRepository) : IEnrollmentService
{
    public async Task<IEnumerable<EnrollmentDto>> GetAllEnrollmentsAsync()
    {
        var enrollments = await enrollmentRepository.GetAllAsync();
        return enrollments.Select(MapToDto);
    }

    public async Task<PagedResultDto<EnrollmentDto>> GetEnrollmentsPageAsync(
        int page,
        int pageSize,
        CancellationToken cancellationToken = default)
    {
        page = Math.Max(1, page);
        pageSize = Math.Clamp(pageSize, 1, 100);
        var result = await enrollmentRepository.GetPageAsync(page, pageSize, cancellationToken);
        return new PagedResultDto<EnrollmentDto>
        {
            Items = result.Items.Select(MapToDto).ToList(),
            TotalCount = result.TotalCount,
            Page = page,
            PageSize = pageSize
        };
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

    public async Task<IEnumerable<EnrollmentDto>> GetEnrollmentsByCourseAsync(int courseId, int requesterId, bool isAdmin)
    {
        var course = await courseRepository.GetByIdAsync(courseId)
            ?? throw new KeyNotFoundException("Course not found.");

        if (!isAdmin && course.InstructorId != requesterId)
            throw new ForbiddenAccessException("Only the course instructor or an admin can view course enrollments.");

        var enrollments = await enrollmentRepository.GetByCourseIdAsync(courseId);
        return enrollments.Select(MapToDto);
    }

    public async Task<EnrollmentDto> EnrollUserAsync(int userId, int courseId)
    {
        var course = await courseRepository.GetByIdAsync(courseId)
            ?? throw new KeyNotFoundException("Course not found.");

        if (course.InstructorId == userId)
            throw new ConflictException("You cannot enroll in your own course.");

        if (await enrollmentRepository.IsUserEnrolledAsync(userId, courseId))
            throw new ConflictException("User is already enrolled in this course.");

        var enrollment = new Enrollment
        {
            UserId = userId,
            CourseId = courseId,
            EnrolledDate = DateTime.UtcNow
        };

        await enrollmentRepository.AddAsync(enrollment);
        var created = await enrollmentRepository.GetByIdAsync(enrollment.Id);
        return MapToDto(created ?? enrollment);
    }

    public async Task<EnrollmentDto> UpdateEnrollmentAsync(int enrollmentId, int newCourseId)
    {
        var enrollment = await enrollmentRepository.GetByIdAsync(enrollmentId)
            ?? throw new KeyNotFoundException("Enrollment not found.");
        var course = await courseRepository.GetByIdAsync(newCourseId)
            ?? throw new KeyNotFoundException("Course not found.");

        if (course.InstructorId == enrollment.UserId)
            throw new ConflictException("You cannot enroll in your own course.");

        if (enrollment.CourseId != newCourseId && await enrollmentRepository.IsUserEnrolledAsync(enrollment.UserId, newCourseId))
            throw new ConflictException("User is already enrolled in this course.");

        enrollment.CourseId = newCourseId;
        await enrollmentRepository.UpdateAsync(enrollment);
        var updated = await enrollmentRepository.GetByIdAsync(enrollment.Id);
        return MapToDto(updated ?? enrollment);
    }

    public async Task UnenrollUserAsync(int userId, int courseId)
    {
        var enrollment = await enrollmentRepository.GetByUserAndCourseAsync(userId, courseId)
            ?? throw new KeyNotFoundException("You are not enrolled in this course.");

        await enrollmentRepository.DeleteAsync(enrollment.Id);
    }

    private static EnrollmentDto MapToDto(Enrollment enrollment) => new()
    {
        Id = enrollment.Id,
        UserId = enrollment.UserId,
        UserName = enrollment.User?.FullName ?? string.Empty,
        CourseId = enrollment.CourseId,
        CourseTitle = enrollment.Course?.Title ?? string.Empty,
        EnrolledDate = enrollment.EnrolledDate
    };
}
