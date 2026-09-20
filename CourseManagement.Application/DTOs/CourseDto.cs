using System.ComponentModel.DataAnnotations;

namespace CourseManagement.Application.DTOs;

public class CourseDto
{
    [Required, StringLength(200, MinimumLength = 3)]
    public string Title { get; set; } = string.Empty;

    [StringLength(2000)]
    public string Description { get; set; } = string.Empty;

    [Range(0, 1_000_000)]
    public decimal Price { get; set; }

    /// <summary>
    /// Optional for instructors (their own identity is used). Admin callers must
    /// provide a real Instructor account so courses are never published under an
    /// administrator identity by accident.
    /// </summary>
    [Range(1, int.MaxValue)]
    public int? InstructorId { get; set; }
}
