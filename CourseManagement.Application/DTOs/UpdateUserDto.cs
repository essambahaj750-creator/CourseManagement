using System.ComponentModel.DataAnnotations;

namespace CourseManagement.Application.DTOs;

public class UpdateUserDto
{
    [Required, StringLength(100, MinimumLength = 2)]
    public string FullName { get; set; } = string.Empty;

    [Required, EmailAddress, StringLength(256)]
    public string Email { get; set; } = string.Empty;
}
