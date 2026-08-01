using System.ComponentModel.DataAnnotations;

namespace CourseManagement.Application.DTOs;

public class RegisterDto
{
    [Required, StringLength(100, MinimumLength = 2)]
    public string FullName { get; set; } = string.Empty;

    [Required, EmailAddress, StringLength(256)]
    public string Email { get; set; } = string.Empty;

    // 72 هو الحد الأقصى الفعلي لخوارزمية BCrypt
    [Required, StringLength(72, MinimumLength = 8)]
    public string Password { get; set; } = string.Empty;

    // ملاحظة أمنية: تم حذف خاصية Role — التسجيل العام ينشئ طلاباً فقط،
    // والترقية إلى Instructor/Admin تتم حصراً عبر الـ Admin من خلال UsersController.
}
