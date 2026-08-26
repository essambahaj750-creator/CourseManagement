using CourseManagement.Application.Common;
using CourseManagement.Application.DTOs;
using CourseManagement.Application.Interfaces;
using CourseManagement.Application.Options;
using CourseManagement.Domain.Entities;
using CourseManagement.Domain.Enums;
using CourseManagement.Domain.Interfaces;
using Microsoft.Extensions.Options;
using Microsoft.Extensions.Logging;

namespace CourseManagement.Infrastructure.Services;

public sealed class CourseAssetService(
    ICourseAssetRepository assetRepository,
    ICourseRepository courseRepository,
    IEnrollmentRepository enrollmentRepository,
    IFileStorage fileStorage,
    IOptions<FileUploadOptions> uploadOptions,
    ILogger<CourseAssetService> logger) : ICourseAssetService
{
    public async Task<IReadOnlyList<CourseAssetDto>> GetByCourseIdAsync(
        int courseId,
        int requesterId,
        bool isAdmin,
        CancellationToken cancellationToken = default)
    {
        var course = await courseRepository.GetByIdAsync(courseId);
        if (course is null)
            throw new KeyNotFoundException("Course not found.");

        await EnsureCanReadAsync(course, requesterId, isAdmin, cancellationToken);
        var assets = await assetRepository.GetByCourseIdAsync(courseId, cancellationToken);
        return assets
            .Where(asset => asset.Type != CourseAssetType.CoverImage)
            .Select(Map)
            .ToArray();
    }

    public async Task<CourseAssetDto> UploadAsync(
        int courseId,
        string originalFileName,
        string contentType,
        long length,
        CourseAssetType type,
        Stream content,
        int requesterId,
        bool isAdmin,
        CancellationToken cancellationToken = default)
    {
        var course = await courseRepository.GetByIdAsync(courseId);
        if (course is null)
            throw new KeyNotFoundException("Course not found.");
        EnsureCanManage(course, requesterId, isAdmin);

        var safeOriginalName = Path.GetFileName(originalFileName ?? string.Empty).Trim();
        if (string.IsNullOrWhiteSpace(safeOriginalName) || safeOriginalName.Length > 255 || safeOriginalName.Contains('\0'))
            throw new InvalidRequestException("The file name is invalid.");
        if (length <= 0)
            throw new InvalidRequestException("The file cannot be empty.");

        var extension = Path.GetExtension(safeOriginalName).ToLowerInvariant();
        var options = uploadOptions.Value;
        if (type == CourseAssetType.CoverImage)
            throw new InvalidRequestException("Cover images must be uploaded through the cover endpoint.");
        var maxBytes = type == CourseAssetType.Video ? options.MaxVideoBytes : options.MaxAttachmentBytes;
        if (length > maxBytes)
            throw new InvalidRequestException($"The file exceeds the {maxBytes / (1024 * 1024)} MB limit.");

        if (type == CourseAssetType.Video && !options.IsVideoExtension(extension))
            throw new InvalidRequestException("This video extension is not allowed.");
        if (type == CourseAssetType.Attachment && !options.IsAttachmentExtension(extension))
            throw new InvalidRequestException("This attachment extension is not allowed.");
        if (!IsAllowedContentType(contentType, extension, type))
            throw new InvalidRequestException("The file content type is not allowed for this extension.");

        var stored = await fileStorage.SaveAsync(content, extension, cancellationToken);
        try
        {
            var asset = await assetRepository.AddAsync(new CourseAsset
            {
                CourseId = courseId,
                OriginalFileName = safeOriginalName,
                StoredFileName = stored.StoredFileName,
                ContentType = contentType.Trim().ToLowerInvariant(),
                SizeBytes = length,
                Type = type,
                CreatedAtUtc = DateTime.UtcNow
            }, cancellationToken);
            return Map(asset);
        }
        catch
        {
            await fileStorage.DeleteAsync(stored.StoredFileName, cancellationToken);
            throw;
        }
    }

    public async Task UploadCoverAsync(
        int courseId,
        string originalFileName,
        string contentType,
        long length,
        Stream content,
        int requesterId,
        bool isAdmin,
        CancellationToken cancellationToken = default)
    {
        var course = await courseRepository.GetByIdAsync(courseId)
            ?? throw new KeyNotFoundException("Course not found.");
        EnsureCanManage(course, requesterId, isAdmin);

        var safeOriginalName = Path.GetFileName(originalFileName ?? string.Empty).Trim();
        if (string.IsNullOrWhiteSpace(safeOriginalName) || safeOriginalName.Length > 255 || safeOriginalName.Contains('\0'))
            throw new InvalidRequestException("The cover image name is invalid.");
        if (length <= 0)
            throw new InvalidRequestException("The cover image cannot be empty.");

        var extension = Path.GetExtension(safeOriginalName).ToLowerInvariant();
        var options = uploadOptions.Value;
        if (length > options.MaxCoverImageBytes)
            throw new InvalidRequestException($"The cover image exceeds the {options.MaxCoverImageBytes / (1024 * 1024)} MB limit.");
        if (!options.IsCoverImageExtension(extension))
            throw new InvalidRequestException("This cover image extension is not allowed.");
        if (!IsAllowedCoverContentType(contentType, extension))
            throw new InvalidRequestException("The cover image content type is not allowed for this extension.");

        var stored = await fileStorage.SaveAsync(content, extension, cancellationToken);
        var existing = (await assetRepository.GetByCourseIdAsync(courseId, cancellationToken))
            .Where(asset => asset.Type == CourseAssetType.CoverImage)
            .OrderByDescending(asset => asset.CreatedAtUtc)
            .FirstOrDefault();

        try
        {
            await assetRepository.AddAsync(new CourseAsset
            {
                CourseId = courseId,
                OriginalFileName = safeOriginalName,
                StoredFileName = stored.StoredFileName,
                ContentType = contentType.Trim().ToLowerInvariant(),
                SizeBytes = length,
                Type = CourseAssetType.CoverImage,
                CreatedAtUtc = DateTime.UtcNow
            }, cancellationToken);

            if (existing is not null)
            {
                await assetRepository.DeleteAsync(existing, cancellationToken);
                await assetRepository.SaveChangesAsync(cancellationToken);
            }

            course.ImageUrl = $"/api/course/{courseId}/cover";
            await courseRepository.UpdateAsync(course);

            if (existing is not null)
            {
                try
                {
                    await fileStorage.DeleteAsync(existing.StoredFileName, cancellationToken);
                }
                catch (Exception exception)
                {
                    logger.LogWarning(
                        exception,
                        "Could not delete replaced cover {StoredFileName} for course {CourseId}.",
                        existing.StoredFileName,
                        courseId);
                }
            }
        }
        catch
        {
            await fileStorage.DeleteAsync(stored.StoredFileName, cancellationToken);
            throw;
        }
    }

    public async Task<CourseAssetDownload?> OpenCoverAsync(
        int courseId,
        CancellationToken cancellationToken = default)
    {
        var course = await courseRepository.GetByIdAsync(courseId)
            ?? throw new KeyNotFoundException("Course not found.");
        var cover = (await assetRepository.GetByCourseIdAsync(courseId, cancellationToken))
            .Where(asset => asset.Type == CourseAssetType.CoverImage)
            .OrderByDescending(asset => asset.CreatedAtUtc)
            .FirstOrDefault();
        if (cover is null)
            return null;

        try
        {
            var stream = await fileStorage.OpenReadAsync(cover.StoredFileName, cancellationToken);
            return new CourseAssetDownload(stream, cover.ContentType, cover.OriginalFileName, cover.SizeBytes);
        }
        catch (FileNotFoundException)
        {
            throw new KeyNotFoundException("The stored cover image is missing.");
        }
    }

    public async Task<CourseAssetDownload> OpenDownloadAsync(
        int courseId,
        int assetId,
        int requesterId,
        bool isAdmin,
        CancellationToken cancellationToken = default)
    {
        var asset = await assetRepository.GetByIdAsync(assetId);
        if (asset is null || asset.CourseId != courseId)
            throw new KeyNotFoundException("Asset not found.");

        await EnsureCanReadAsync(asset.Course, requesterId, isAdmin, cancellationToken);
        try
        {
            var stream = await fileStorage.OpenReadAsync(asset.StoredFileName, cancellationToken);
            return new CourseAssetDownload(stream, asset.ContentType, asset.OriginalFileName, asset.SizeBytes);
        }
        catch (FileNotFoundException)
        {
            throw new KeyNotFoundException("The stored file is missing.");
        }
    }

    public async Task DeleteAsync(
        int courseId,
        int assetId,
        int requesterId,
        bool isAdmin,
        CancellationToken cancellationToken = default)
    {
        var asset = await assetRepository.GetByIdAsync(assetId);
        if (asset is null || asset.CourseId != courseId)
            throw new KeyNotFoundException("Asset not found.");
        EnsureCanManage(asset.Course, requesterId, isAdmin);

        await assetRepository.DeleteAsync(asset, cancellationToken);
        await assetRepository.SaveChangesAsync(cancellationToken);
        await fileStorage.DeleteAsync(asset.StoredFileName, cancellationToken);
    }

    private async Task EnsureCanReadAsync(
        Course course,
        int requesterId,
        bool isAdmin,
        CancellationToken cancellationToken)
    {
        if (isAdmin || course.InstructorId == requesterId)
            return;
        if (!await enrollmentRepository.IsUserEnrolledAsync(requesterId, course.Id))
            throw new ForbiddenAccessException("Only the course owner, an Admin, or an enrolled student can access course files.");
    }

    private static void EnsureCanManage(Course course, int requesterId, bool isAdmin)
    {
        if (!isAdmin && course.InstructorId != requesterId)
            throw new ForbiddenAccessException("Only the course owner or an Admin can manage course files.");
    }

    private static CourseAssetDto Map(CourseAsset asset) => new()
    {
        Id = asset.Id,
        CourseId = asset.CourseId,
        OriginalFileName = asset.OriginalFileName,
        ContentType = asset.ContentType,
        SizeBytes = asset.SizeBytes,
        Type = asset.Type,
        CreatedAtUtc = asset.CreatedAtUtc
    };

    private static bool IsAllowedContentType(string contentType, string extension, CourseAssetType type)
    {
        var normalized = (contentType ?? string.Empty).Trim().ToLowerInvariant();
        if (normalized == "application/octet-stream")
            return true;
        if (type == CourseAssetType.Video)
            return extension == ".mov" ? normalized == "video/quicktime" : normalized.StartsWith("video/", StringComparison.Ordinal);

        return extension switch
        {
            ".pdf" => normalized == "application/pdf",
            ".doc" => normalized == "application/msword",
            ".docx" => normalized == "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
            ".ppt" => normalized == "application/vnd.ms-powerpoint",
            ".pptx" => normalized == "application/vnd.openxmlformats-officedocument.presentationml.presentation",
            ".xls" => normalized == "application/vnd.ms-excel",
            ".xlsx" => normalized == "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
            ".zip" => normalized == "application/zip" || normalized == "application/x-zip-compressed",
            ".txt" => normalized == "text/plain",
            _ => false
        };
    }

    private static bool IsAllowedCoverContentType(string contentType, string extension)
    {
        var normalized = (contentType ?? string.Empty).Trim().ToLowerInvariant();
        if (normalized == "application/octet-stream")
            return true;

        return extension switch
        {
            ".jpg" or ".jpeg" => normalized == "image/jpeg",
            ".png" => normalized == "image/png",
            ".webp" => normalized == "image/webp",
            _ => false
        };
    }
}
