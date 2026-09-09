using CourseManagement.Domain.Entities;

namespace CourseManagement.Domain.Interfaces;

public interface ICourseReviewRepository
{
    Task<IReadOnlyList<CourseReview>> GetByCourseIdAsync(
        int courseId,
        CancellationToken cancellationToken = default);

    Task<CourseReview?> GetByUserAndCourseAsync(
        int userId,
        int courseId,
        CancellationToken cancellationToken = default);

    Task<CourseReview> AddAsync(
        CourseReview review,
        CancellationToken cancellationToken = default);

    Task UpdateAsync(
        CourseReview review,
        CancellationToken cancellationToken = default);

    Task DeleteAsync(
        CourseReview review,
        CancellationToken cancellationToken = default);
}
