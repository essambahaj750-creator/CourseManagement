namespace CourseManagement.Application.DTOs;

public sealed class CourseReviewDto
{
    public int Id { get; init; }
    public int UserId { get; init; }
    public string UserName { get; init; } = string.Empty;
    public int Rating { get; init; }
    public string Comment { get; init; } = string.Empty;
    public DateTime CreatedAtUtc { get; init; }
    public DateTime UpdatedAtUtc { get; init; }
}

public sealed class CourseReviewSummaryDto
{
    public int CourseId { get; init; }
    public double AverageRating { get; init; }
    public int ReviewCount { get; init; }
    public IReadOnlyList<CourseReviewDto> Reviews { get; init; } = [];
}

public sealed class CourseReviewUpsertDto
{
    public int Rating { get; init; }
    public string Comment { get; init; } = string.Empty;
}
