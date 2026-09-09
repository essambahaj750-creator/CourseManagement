using CourseManagement.Application.DTOs;

namespace CourseManagement.Application.Interfaces;

public interface ICourseReviewService
{
    Task<CourseReviewSummaryDto> GetSummaryAsync(
        int courseId,
        CancellationToken cancellationToken = default);

    Task<CourseReviewDto> UpsertAsync(
        int userId,
        int courseId,
        int rating,
        string comment,
        CancellationToken cancellationToken = default);

    Task DeleteOwnAsync(
        int userId,
        int courseId,
        CancellationToken cancellationToken = default);
}
