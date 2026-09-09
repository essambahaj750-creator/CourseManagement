using System.Text.Json;
using CourseManagement.Application.Common;
using CourseManagement.Application.DTOs;
using CourseManagement.Application.Interfaces;
using CourseManagement.Domain.Entities;
using CourseManagement.Domain.Enums;
using CourseManagement.Domain.Interfaces;

namespace CourseManagement.Infrastructure.Services;

public class EnrollmentService(
    IEnrollmentRepository enrollmentRepository,
    ICourseRepository courseRepository,
    ICourseAssetRepository assetRepository) : IEnrollmentService
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

    public async Task<CourseProgressDto> GetCourseProgressAsync(int userId, int courseId)
    {
        var enrollment = await enrollmentRepository.GetByUserAndCourseAsync(userId, courseId)
            ?? throw new KeyNotFoundException("You are not enrolled in this course.");

        var assets = await assetRepository.GetByCourseIdAsync(courseId);
        return BuildProgress(enrollment, assets);
    }

    public async Task<CourseProgressDto> UpdateCourseProgressAsync(
        int userId,
        int courseId,
        int assetId,
        bool completed)
    {
        var enrollment = await enrollmentRepository.GetByUserAndCourseAsync(userId, courseId)
            ?? throw new KeyNotFoundException("You are not enrolled in this course.");

        var asset = await assetRepository.GetByIdAsync(assetId);
        if (asset is null || asset.CourseId != courseId || asset.Type != CourseAssetType.Video)
            throw new InvalidRequestException("The selected lesson does not belong to this course.");

        var completedIds = ParseCompletedIds(enrollment.CompletedLessonAssetIds);
        if (completed)
            completedIds.Add(assetId);
        else
            completedIds.Remove(assetId);

        enrollment.CompletedLessonAssetIds = JsonSerializer.Serialize(completedIds.OrderBy(id => id));
        enrollment.LastLessonAssetId = assetId;
        enrollment.LastAccessedAtUtc = DateTime.UtcNow;
        await enrollmentRepository.UpdateAsync(enrollment);

        var assets = await assetRepository.GetByCourseIdAsync(courseId);
        return BuildProgress(enrollment, assets);
    }

    public async Task UnenrollUserAsync(int userId, int courseId)
    {
        var enrollment = await enrollmentRepository.GetByUserAndCourseAsync(userId, courseId)
            ?? throw new KeyNotFoundException("You are not enrolled in this course.");

        await enrollmentRepository.DeleteAsync(enrollment.Id);
    }

    private static CourseProgressDto BuildProgress(
        Enrollment enrollment,
        IReadOnlyList<CourseAsset> assets)
    {
        var lessonIds = assets
            .Where(asset => asset.Type == CourseAssetType.Video)
            .Select(asset => asset.Id)
            .ToHashSet();

        var completed = ParseCompletedIds(enrollment.CompletedLessonAssetIds)
            .Where(lessonIds.Contains)
            .OrderBy(id => id)
            .ToArray();

        var total = lessonIds.Count;
        var percent = total == 0 ? 0d : Math.Round(completed.Length * 100d / total, 1);

        return new CourseProgressDto
        {
            CourseId = enrollment.CourseId,
            LastLessonAssetId = enrollment.LastLessonAssetId.HasValue &&
                                lessonIds.Contains(enrollment.LastLessonAssetId.Value)
                ? enrollment.LastLessonAssetId
                : null,
            CompletedLessonAssetIds = completed,
            CompletedCount = completed.Length,
            TotalLessons = total,
            ProgressPercent = percent,
            LastAccessedAtUtc = enrollment.LastAccessedAtUtc
        };
    }

    private static HashSet<int> ParseCompletedIds(string? json)
    {
        if (string.IsNullOrWhiteSpace(json))
            return [];

        try
        {
            return (JsonSerializer.Deserialize<int[]>(json) ?? [])
                .Where(id => id > 0)
                .ToHashSet();
        }
        catch (JsonException)
        {
            return [];
        }
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
