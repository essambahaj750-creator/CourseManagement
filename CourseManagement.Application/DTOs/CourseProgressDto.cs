namespace CourseManagement.Application.DTOs;

public sealed class CourseProgressDto
{
    public int CourseId { get; init; }
    public int? LastLessonAssetId { get; init; }
    public IReadOnlyList<int> CompletedLessonAssetIds { get; init; } = [];
    public int CompletedCount { get; init; }
    public int TotalLessons { get; init; }
    public double ProgressPercent { get; init; }
    public DateTime? LastAccessedAtUtc { get; init; }
}

public sealed class LessonProgressUpdateDto
{
    public int AssetId { get; init; }
    public bool Completed { get; init; }
}
