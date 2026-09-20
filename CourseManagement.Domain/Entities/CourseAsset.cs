using CourseManagement.Domain.Enums;

namespace CourseManagement.Domain.Entities;

public class CourseAsset
{
    public int Id { get; set; }
    public int CourseId { get; set; }
    public Course Course { get; set; } = null!;

    public string OriginalFileName { get; set; } = string.Empty;
    public string StoredFileName { get; set; } = string.Empty;
    public string ContentType { get; set; } = "application/octet-stream";
    public long SizeBytes { get; set; }
    public CourseAssetType Type { get; set; }
    public DateTime CreatedAtUtc { get; set; } = DateTime.UtcNow;
}
