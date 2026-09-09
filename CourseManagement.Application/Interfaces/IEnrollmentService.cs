using CourseManagement.Application.DTOs;

namespace CourseManagement.Application.Interfaces;

public interface IEnrollmentService
{
    Task<IEnumerable<EnrollmentDto>> GetAllEnrollmentsAsync();
    Task<PagedResultDto<EnrollmentDto>> GetEnrollmentsPageAsync(
        int page,
        int pageSize,
        CancellationToken cancellationToken = default);
    Task<EnrollmentDto?> GetEnrollmentByIdAsync(int id);
    Task<IEnumerable<EnrollmentDto>> GetEnrollmentsByUserAsync(int userId);
    Task<IEnumerable<EnrollmentDto>> GetEnrollmentsByCourseAsync(int courseId, int requesterId, bool isAdmin);
    Task<EnrollmentDto> EnrollUserAsync(int userId, int courseId);
    Task<EnrollmentDto> UpdateEnrollmentAsync(int enrollmentId, int newCourseId);
    Task<CourseProgressDto> GetCourseProgressAsync(int userId, int courseId);
    Task<CourseProgressDto> UpdateCourseProgressAsync(
        int userId,
        int courseId,
        int assetId,
        bool completed);
    Task UnenrollUserAsync(int userId, int courseId);
}
