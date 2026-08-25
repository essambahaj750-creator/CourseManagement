using CourseManagement.Domain.Enums;

namespace CourseManagement.Application.DTOs;

public sealed class CourseAssetDto
{
    public int Id { get; init; }
    public int CourseId { get; init; }
    public string OriginalFileName { get; init; } = string.Empty;
    public string ContentType { get; init; } = "application/octet-stream";
    public long SizeBytes { get; init; }
    public CourseAssetType Type { get; init; }
    public string TypeLabel => Type switch
    {
        CourseAssetType.Video => "Video",
        CourseAssetType.Attachment => "Attachment",
        CourseAssetType.CoverImage => "CoverImage",
        _ => "Unknown"
    };
    public DateTime CreatedAtUtc { get; init; }
    public string DownloadUrl => $"/api/course/{CourseId}/assets/{Id}/download";
}
