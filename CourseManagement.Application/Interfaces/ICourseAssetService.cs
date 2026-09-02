using CourseManagement.Application.DTOs;
using CourseManagement.Domain.Enums;

namespace CourseManagement.Application.Interfaces;

public sealed record CourseAssetDownload(
    Stream Content,
    string ContentType,
    string DownloadName,
    long Length);

public interface ICourseAssetService
{
    Task<IReadOnlyList<CourseAssetDto>> GetByCourseIdAsync(
        int courseId,
        int requesterId,
        bool isAdmin,
        CancellationToken cancellationToken = default);

    Task<CourseAssetDto?> GetPreviewAsync(
        int courseId,
        CancellationToken cancellationToken = default);

    Task<CourseAssetDownload?> OpenPreviewAsync(
        int courseId,
        CancellationToken cancellationToken = default);

    /// <summary>
    /// Uploads a video or attachment. The client-declared content type is not a
    /// parameter by design: it is attacker-controlled, so the stored type is derived
    /// from the extension after the file signature has been verified.
    /// <paramref name="content"/> must be seekable, because the header is inspected
    /// before the bytes are written.
    /// </summary>
    Task<CourseAssetDto> UploadAsync(
        int courseId,
        string originalFileName,
        long length,
        CourseAssetType type,
        Stream content,
        int requesterId,
        bool isAdmin,
        CancellationToken cancellationToken = default);

    Task UploadCoverAsync(
        int courseId,
        string originalFileName,
        long length,
        Stream content,
        int requesterId,
        bool isAdmin,
        CancellationToken cancellationToken = default);

    Task DeleteCoverAsync(
        int courseId,
        int requesterId,
        bool isAdmin,
        CancellationToken cancellationToken = default);

    Task<CourseAssetDownload?> OpenCoverAsync(
        int courseId,
        CancellationToken cancellationToken = default);

    Task<CourseAssetDownload> OpenDownloadAsync(
        int courseId,
        int assetId,
        int requesterId,
        bool isAdmin,
        CancellationToken cancellationToken = default);

    Task DeleteAsync(
        int courseId,
        int assetId,
        int requesterId,
        bool isAdmin,
        CancellationToken cancellationToken = default);
}
