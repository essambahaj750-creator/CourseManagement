using CourseManagement.Domain.Entities;

namespace CourseManagement.Domain.Interfaces;

public interface IEnrollmentRepository
{
    Task<IEnumerable<Enrollment>> GetAllAsync();
    Task<(IReadOnlyList<Enrollment> Items, int TotalCount)> GetPageAsync(
        int page,
        int pageSize,
        CancellationToken cancellationToken = default);
    Task<Enrollment?> GetByIdAsync(int id);
    Task<IEnumerable<Enrollment>> GetByUserIdAsync(int userId);
    Task<IEnumerable<Enrollment>> GetByCourseIdAsync(int courseId);
    Task<Enrollment?> GetByUserAndCourseAsync(int userId, int courseId);
    Task<Enrollment> AddAsync(Enrollment enrollment);
    Task UpdateAsync(Enrollment enrollment);
    Task DeleteAsync(int id);
    Task<bool> IsUserEnrolledAsync(int userId, int courseId);
}