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

    Task<CourseAssetDto> UploadAsync(
        int courseId,
        string originalFileName,
        string contentType,
        long length,
        CourseAssetType type,
        Stream content,
        int requesterId,
        bool isAdmin,
        CancellationToken cancellationToken = default);

    Task UploadCoverAsync(
        int courseId,
        string originalFileName,
        string contentType,
        long length,
        Stream content,
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
