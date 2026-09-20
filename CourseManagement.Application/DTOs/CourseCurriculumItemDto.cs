namespace CourseManagement.Application.DTOs;

public sealed class CourseCurriculumItemDto
{
    public int Id { get; init; }
    public int Position { get; init; }
    public string Title { get; init; } = string.Empty;
    public string Type { get; init; } = "Video";
}
