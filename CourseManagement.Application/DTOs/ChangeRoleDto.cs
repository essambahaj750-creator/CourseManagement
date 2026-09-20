using System.ComponentModel.DataAnnotations;

namespace CourseManagement.Application.DTOs;

public class ChangeRoleDto
{
    /// <summary>Student أو Instructor أو Admin</summary>
    [Required]
    public string Role { get; set; } = string.Empty;
}
