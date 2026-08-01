using System.ComponentModel.DataAnnotations;

namespace CourseManagement.Application.DTOs;

public class CourseDto
{
    [Required, StringLength(200, MinimumLength = 3)]
    public string Title { get; set; } = string.Empty;

    [StringLength(2000)]
    public string Description { get; set; } = string.Empty;

    // السعر لا يمكن أن يكون سالباً
    [Range(0, 1_000_000)]
    public decimal Price { get; set; }
}
