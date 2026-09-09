using CourseManagement.Domain.Entities;
using CourseManagement.Domain.Interfaces;
using CourseManagement.Infrastructure.Data;
using Microsoft.EntityFrameworkCore;

namespace CourseManagement.Infrastructure.Repositories;

public sealed class CourseReviewRepository(ApplicationDbContext context)
    : ICourseReviewRepository
{
    public async Task<IReadOnlyList<CourseReview>> GetByCourseIdAsync(
        int courseId,
        CancellationToken cancellationToken = default) =>
        await context.CourseReviews
            .AsNoTracking()
            .Include(review => review.User)
            .Where(review => review.CourseId == courseId)
            .OrderByDescending(review => review.UpdatedAtUtc)
            .ToListAsync(cancellationToken);

    public async Task<CourseReview?> GetByUserAndCourseAsync(
        int userId,
        int courseId,
        CancellationToken cancellationToken = default) =>
        await context.CourseReviews
            .Include(review => review.User)
            .FirstOrDefaultAsync(
                review => review.UserId == userId && review.CourseId == courseId,
                cancellationToken);

    public async Task<CourseReview> AddAsync(
        CourseReview review,
        CancellationToken cancellationToken = default)
    {
        context.CourseReviews.Add(review);
        await context.SaveChangesAsync(cancellationToken);
        return review;
    }

    public async Task UpdateAsync(
        CourseReview review,
        CancellationToken cancellationToken = default)
    {
        context.CourseReviews.Update(review);
        await context.SaveChangesAsync(cancellationToken);
    }

    public async Task DeleteAsync(
        CourseReview review,
        CancellationToken cancellationToken = default)
    {
        context.CourseReviews.Remove(review);
        await context.SaveChangesAsync(cancellationToken);
    }
}
