using CourseManagement.Application.Common;
using CourseManagement.Application.DTOs;
using CourseManagement.Application.Interfaces;
using CourseManagement.Domain.Entities;
using CourseManagement.Domain.Interfaces;

namespace CourseManagement.Infrastructure.Services;

public sealed class CourseReviewService(
    ICourseReviewRepository reviewRepository,
    ICourseRepository courseRepository,
    IEnrollmentRepository enrollmentRepository) : ICourseReviewService
{
    public async Task<CourseReviewSummaryDto> GetSummaryAsync(
        int courseId,
        CancellationToken cancellationToken = default)
    {
        if (!await courseRepository.ExistsAsync(courseId))
            throw new KeyNotFoundException("Course not found.");

        var reviews = await reviewRepository.GetByCourseIdAsync(courseId, cancellationToken);
        return new CourseReviewSummaryDto
        {
            CourseId = courseId,
            ReviewCount = reviews.Count,
            AverageRating = reviews.Count == 0
                ? 0
                : Math.Round(reviews.Average(review => review.Rating), 1),
            Reviews = reviews.Select(Map).ToArray()
        };
    }

    public async Task<CourseReviewDto> UpsertAsync(
        int userId,
        int courseId,
        int rating,
        string comment,
        CancellationToken cancellationToken = default)
    {
        if (rating is < 1 or > 5)
            throw new InvalidRequestException("Rating must be between 1 and 5.");

        comment = (comment ?? string.Empty).Trim();
        if (comment.Length > 1000)
            throw new InvalidRequestException("Review comment cannot exceed 1000 characters.");

        var course = await courseRepository.GetByIdAsync(courseId)
            ?? throw new KeyNotFoundException("Course not found.");

        if (course.InstructorId == userId)
            throw new ConflictException("You cannot review your own course.");

        if (!await enrollmentRepository.IsUserEnrolledAsync(userId, courseId))
            throw new ForbiddenAccessException("Only enrolled students can review this course.");

        var existing = await reviewRepository.GetByUserAndCourseAsync(
            userId,
            courseId,
            cancellationToken);

        if (existing is null)
        {
            existing = new CourseReview
            {
                UserId = userId,
                CourseId = courseId,
                Rating = rating,
                Comment = comment,
                CreatedAtUtc = DateTime.UtcNow,
                UpdatedAtUtc = DateTime.UtcNow
            };
            await reviewRepository.AddAsync(existing, cancellationToken);
        }
        else
        {
            existing.Rating = rating;
            existing.Comment = comment;
            existing.UpdatedAtUtc = DateTime.UtcNow;
            await reviewRepository.UpdateAsync(existing, cancellationToken);
        }

        var refreshed = await reviewRepository.GetByUserAndCourseAsync(
            userId,
            courseId,
            cancellationToken);

        return Map(refreshed ?? existing);
    }

    public async Task DeleteOwnAsync(
        int userId,
        int courseId,
        CancellationToken cancellationToken = default)
    {
        var review = await reviewRepository.GetByUserAndCourseAsync(
            userId,
            courseId,
            cancellationToken)
            ?? throw new KeyNotFoundException("Review not found.");

        await reviewRepository.DeleteAsync(review, cancellationToken);
    }

    private static CourseReviewDto Map(CourseReview review) => new()
    {
        Id = review.Id,
        UserId = review.UserId,
        UserName = review.User?.FullName ?? string.Empty,
        Rating = review.Rating,
        Comment = review.Comment,
        CreatedAtUtc = review.CreatedAtUtc,
        UpdatedAtUtc = review.UpdatedAtUtc
    };
}
