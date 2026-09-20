using CourseManagement.Application.DTOs;
using CourseManagement.Application.Interfaces;
using CourseManagement.Infrastructure.Data;
using CourseManagement.Domain.Enums;
using CourseManagement.Domain.Interfaces;
using Microsoft.EntityFrameworkCore;

namespace CourseManagement.Infrastructure.Services;

public sealed class CourseDiscoveryService(
    ApplicationDbContext context,
    ICourseService courseService,
    IUserRepository userRepository) : ICourseDiscoveryService
{
    public async Task EnrichSocialProofAsync(
        IEnumerable<CourseResponseDto> courses,
        CancellationToken cancellationToken = default)
    {
        var items = courses.ToList();
        if (items.Count == 0) return;

        var ids = items.Select(course => course.Id).Distinct().ToArray();

        var reviewMetrics = await context.CourseReviews
            .AsNoTracking()
            .Where(review => ids.Contains(review.CourseId))
            .GroupBy(review => review.CourseId)
            .Select(group => new
            {
                CourseId = group.Key,
                Count = group.Count(),
                Average = group.Average(review => review.Rating)
            })
            .ToDictionaryAsync(item => item.CourseId, cancellationToken);

        var enrollmentMetrics = await context.Enrollments
            .AsNoTracking()
            .Where(enrollment => ids.Contains(enrollment.CourseId))
            .GroupBy(enrollment => enrollment.CourseId)
            .Select(group => new
            {
                CourseId = group.Key,
                Count = group.Count()
            })
            .ToDictionaryAsync(item => item.CourseId, cancellationToken);

        foreach (var course in items)
        {
            if (reviewMetrics.TryGetValue(course.Id, out var reviews))
            {
                course.ReviewCount = reviews.Count;
                course.AverageRating = Math.Round(reviews.Average, 1);
            }

            if (enrollmentMetrics.TryGetValue(course.Id, out var enrollments))
                course.EnrolledStudents = enrollments.Count;
        }
    }

    public async Task<IReadOnlyList<CourseResponseDto>> GetRelatedCoursesAsync(
        int courseId,
        int limit = 4,
        CancellationToken cancellationToken = default)
    {
        limit = Math.Clamp(limit, 1, 12);

        var current = await courseService.GetCourseByIdAsync(courseId)
            ?? throw new KeyNotFoundException("Course not found.");

        var candidates = (await courseService.GetAllCoursesAsync())
            .Where(course => course.Id != courseId)
            .ToList();

        await EnrichSocialProofAsync(candidates, cancellationToken);

        return candidates
            .OrderByDescending(course => course.InstructorId == current.InstructorId)
            .ThenBy(course => Math.Abs(course.Price - current.Price))
            .ThenByDescending(course => course.AverageRating)
            .ThenByDescending(course => course.EnrolledStudents)
            .Take(limit)
            .ToArray();
    }


    public async Task<InstructorPublicProfileDto?> GetInstructorProfileAsync(
        int instructorId,
        CancellationToken cancellationToken = default)
    {
        var user = await userRepository.GetByIdAsync(instructorId);
        if (user is null || user.Role != Role.Instructor)
            return null;

        var courses = (await courseService.GetCoursesByInstructorAsync(instructorId))
            .ToList();
        await EnrichSocialProofAsync(courses, cancellationToken);

        var reviewCount = courses.Sum(course => course.ReviewCount);
        var weightedRating = reviewCount == 0
            ? 0d
            : courses.Sum(course => course.AverageRating * course.ReviewCount) / reviewCount;

        return new InstructorPublicProfileDto
        {
            InstructorId = user.Id,
            FullName = user.FullName,
            CourseCount = courses.Count,
            TotalStudents = courses.Sum(course => course.EnrolledStudents),
            AverageRating = Math.Round(weightedRating, 1),
            ReviewCount = reviewCount,
            Courses = courses
                .OrderByDescending(course => course.AverageRating)
                .ThenByDescending(course => course.EnrolledStudents)
                .ToArray()
        };
    }

}