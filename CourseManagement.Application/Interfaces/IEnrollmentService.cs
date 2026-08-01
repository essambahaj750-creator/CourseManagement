using CourseManagement.Application.DTOs;

namespace CourseManagement.Application.Interfaces;

public interface IEnrollmentService
{
    Task<IEnumerable<EnrollmentDto>> GetAllEnrollmentsAsync();
    Task<EnrollmentDto?> GetEnrollmentByIdAsync(int id);
    Task<IEnumerable<EnrollmentDto>> GetEnrollmentsByUserAsync(int userId);
    Task<IEnumerable<EnrollmentDto>> GetEnrollmentsByCourseAsync(int courseId);
    Task<EnrollmentDto> EnrollUserAsync(int userId, int courseId);
    Task<bool> UnenrollUserAsync(int userId, int courseId);
}