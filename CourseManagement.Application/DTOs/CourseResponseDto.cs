namespace CourseManagement.Application.DTOs;

public class CourseResponseDto
{
    public int Id { get; set; }
    public string Title { get; set; } = string.Empty;
    public string Description { get; set; } = string.Empty;
    public decimal Price { get; set; }
    public string InstructorName { get; set; } = string.Empty;
}