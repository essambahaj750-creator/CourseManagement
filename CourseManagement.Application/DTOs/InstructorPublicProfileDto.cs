namespace CourseManagement.Application.DTOs;

public sealed class InstructorPublicProfileDto
{
    public int InstructorId { get; init; }
    public string FullName { get; init; } = string.Empty;
    public int CourseCount { get; init; }
    public int TotalStudents { get; init; }
    public double AverageRating { get; init; }
    public int ReviewCount { get; init; }
    public IReadOnlyList<CourseResponseDto> Courses { get; init; } = [];
}
