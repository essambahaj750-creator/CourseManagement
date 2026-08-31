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
    IUnitOfWork unitOfWork,
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

        var contentType = await InspectUploadAsync(content, extension, cancellationToken);
        var stored = await fileStorage.SaveAsync(content, extension, maxBytes, cancellationToken);
        try
        {
            var asset = await assetRepository.AddAsync(new CourseAsset
            {
                CourseId = courseId,
                OriginalFileName = safeOriginalName,
                StoredFileName = stored.StoredFileName,
                ContentType = contentType,
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

        var contentType = await InspectUploadAsync(content, extension, cancellationToken);
        var stored = await fileStorage.SaveAsync(content, extension, options.MaxCoverImageBytes, cancellationToken);
        var existing = (await assetRepository.GetByCourseIdAsync(courseId, cancellationToken))
            .Where(asset => asset.Type == CourseAssetType.CoverImage)
            .OrderByDescending(asset => asset.CreatedAtUtc)
            .FirstOrDefault();

        try
        {
            await using var transaction = await unitOfWork.BeginTransactionAsync(cancellationToken);

            await assetRepository.AddAsync(new CourseAsset
            {
                CourseId = courseId,
                OriginalFileName = safeOriginalName,
                StoredFileName = stored.StoredFileName,
                ContentType = contentType,
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
            await transaction.CommitAsync(cancellationToken);

            if (existing is not null)
                await TryDeletePhysicalFileAsync(existing.StoredFileName, courseId, "replaced cover", cancellationToken);
        }
        catch
        {
            await fileStorage.DeleteAsync(stored.StoredFileName, cancellationToken);
            throw;
        }
    }

    public async Task DeleteCoverAsync(
        int courseId,
        int requesterId,
        bool isAdmin,
        CancellationToken cancellationToken = default)
    {
        var course = await courseRepository.GetByIdAsync(courseId)
            ?? throw new KeyNotFoundException("Course not found.");
        EnsureCanManage(course, requesterId, isAdmin);

        var covers = (await assetRepository.GetByCourseIdAsync(courseId, cancellationToken))
            .Where(asset => asset.Type == CourseAssetType.CoverImage)
            .ToArray();

        if (covers.Length == 0 && string.IsNullOrWhiteSpace(course.ImageUrl))
            return;

        await using (var transaction = await unitOfWork.BeginTransactionAsync(cancellationToken))
        {
            foreach (var cover in covers)
                await assetRepository.DeleteAsync(cover, cancellationToken);

            if (covers.Length > 0)
                await assetRepository.SaveChangesAsync(cancellationToken);

            course.ImageUrl = null;
            await courseRepository.UpdateAsync(course);
            await transaction.CommitAsync(cancellationToken);
        }

        foreach (var cover in covers)
            await TryDeletePhysicalFileAsync(cover.StoredFileName, courseId, "deleted cover", cancellationToken);
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

        if (asset.Type == CourseAssetType.CoverImage)
        {
            await DeleteCoverAsync(courseId, requesterId, isAdmin, cancellationToken);
            return;
        }

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

    private static async Task<string> InspectUploadAsync(
        Stream content,
        string extension,
        CancellationToken cancellationToken)
    {
        if (!content.CanSeek)
            throw new InvalidOperationException("Uploaded file streams must be seekable for signature validation.");

        content.Position = 0;
        var header = new byte[UploadContentInspector.HeaderLength];
        var totalRead = 0;
        while (totalRead < header.Length)
        {
            var read = await content.ReadAsync(header.AsMemory(totalRead, header.Length - totalRead), cancellationToken);
            if (read == 0)
                break;
            totalRead += read;
        }
        content.Position = 0;

        if (!UploadContentInspector.MatchesSignature(extension, header.AsSpan(0, totalRead)))
            throw new InvalidRequestException("The file contents do not match the selected file extension.");

        return UploadContentInspector.ResolveContentType(extension);
    }

    private async Task TryDeletePhysicalFileAsync(
        string storedFileName,
        int courseId,
        string operation,
        CancellationToken cancellationToken)
    {
        try
        {
            await fileStorage.DeleteAsync(storedFileName, cancellationToken);
        }
        catch (Exception exception)
        {
            logger.LogWarning(
                exception,
                "Could not delete {Operation} {StoredFileName} for course {CourseId}.",
                operation,
                storedFileName,
                courseId);
        }
    }
}
