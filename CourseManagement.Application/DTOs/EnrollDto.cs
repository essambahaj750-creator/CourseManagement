using System.ComponentModel.DataAnnotations;

namespace CourseManagement.Application.DTOs;

public class EnrollDto
{
    [Range(1, int.MaxValue, ErrorMessage = "CourseId must be a positive number.")]
    public int CourseId { get; set; }
}
