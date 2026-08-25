using System.ComponentModel.DataAnnotations;
using CourseManagement.Application.DTOs;
using CourseManagement.Domain.Enums;
using Microsoft.AspNetCore.Http;

namespace CourseManagement.Web.ViewModels;

public sealed class LoginViewModel
{
    [Required, EmailAddress]
    [Display(Name = "البريد الإلكتروني")]
    public string Email { get; set; } = string.Empty;

    [Required, DataType(DataType.Password)]
    [Display(Name = "كلمة المرور")]
    public string Password { get; set; } = string.Empty;

    [Display(Name = "تذكرني")]
    public bool RememberMe { get; set; }

    public string? ReturnUrl { get; set; }

    public LoginDto ToDto() => new() { Email = Email, Password = Password };
}

public sealed class RegisterViewModel
{
    [Required, StringLength(100, MinimumLength = 2)]
    [Display(Name = "الاسم الكامل")]
    public string FullName { get; set; } = string.Empty;

    [Required, EmailAddress, StringLength(256)]
    [Display(Name = "البريد الإلكتروني")]
    public string Email { get; set; } = string.Empty;

    [Required, StringLength(72, MinimumLength = 8), DataType(DataType.Password)]
    [Display(Name = "كلمة المرور")]
    public string Password { get; set; } = string.Empty;

    [Required, DataType(DataType.Password), Compare(nameof(Password))]
    [Display(Name = "تأكيد كلمة المرور")]
    public string ConfirmPassword { get; set; } = string.Empty;

    public RegisterDto ToDto() => new() { FullName = FullName, Email = Email, Password = Password };
}

public sealed class ChangePasswordViewModel
{
    [Required, DataType(DataType.Password)]
    [Display(Name = "كلمة المرور الحالية")]
    public string CurrentPassword { get; set; } = string.Empty;

    [Required, StringLength(72, MinimumLength = 12), DataType(DataType.Password)]
    [Display(Name = "كلمة المرور الجديدة")]
    public string NewPassword { get; set; } = string.Empty;

    [Required, DataType(DataType.Password), Compare(nameof(NewPassword))]
    [Display(Name = "تأكيد كلمة المرور الجديدة")]
    public string ConfirmNewPassword { get; set; } = string.Empty;

    public ChangePasswordDto ToDto() => new()
    {
        CurrentPassword = CurrentPassword,
        NewPassword = NewPassword,
        ConfirmNewPassword = ConfirmNewPassword
    };
}

public sealed class CourseFormViewModel
{
    public int Id { get; set; }

    [Required, StringLength(200, MinimumLength = 3)]
    [Display(Name = "عنوان الكورس")]
    public string Title { get; set; } = string.Empty;

    [StringLength(2000)]
    [Display(Name = "الوصف")]
    public string Description { get; set; } = string.Empty;

    [Range(0, 1_000_000)]
    [Display(Name = "السعر")]
    public decimal Price { get; set; }

    [Display(Name = "صورة غلاف الكورس")]
    public IFormFile? CoverImage { get; set; }

    public CourseDto ToDto() => new() { Title = Title, Description = Description, Price = Price };
}

public sealed class CourseAssetUploadViewModel
{
    [Display(Name = "الملف")]
    public IFormFile? File { get; set; }

    [Display(Name = "نوع الملف")]
    public CourseAssetType Type { get; set; } = CourseAssetType.Attachment;
}

public sealed class CourseDetailsViewModel
{
    public CourseResponseDto Course { get; init; } = new();
    public CourseAssetUploadViewModel Upload { get; init; } = new();
    public bool CanAccessAssets { get; init; }
}

public sealed class CourseFilterViewModel
{
    [Display(Name = "البحث")]
    public string? Q { get; set; }

    [Display(Name = "المدرّس")]
    public int? InstructorId { get; set; }

    [Range(0, 1_000_000)]
    [Display(Name = "أقل سعر")]
    public decimal? MinPrice { get; set; }

    [Range(0, 1_000_000)]
    [Display(Name = "أعلى سعر")]
    public decimal? MaxPrice { get; set; }

    public string Sort { get; set; } = "featured";
    public int Page { get; set; } = 1;
    public int PageSize { get; set; } = 9;

    public bool HasActiveFilters =>
        !string.IsNullOrWhiteSpace(Q) || InstructorId.HasValue || MinPrice.HasValue || MaxPrice.HasValue ||
        (!string.IsNullOrWhiteSpace(Sort) && !string.Equals(Sort, "featured", StringComparison.OrdinalIgnoreCase));

    public CourseFilterDto ToDto() => new()
    {
        Q = Q,
        InstructorId = InstructorId,
        MinPrice = MinPrice,
        MaxPrice = MaxPrice,
        Sort = Sort,
        Page = Page,
        PageSize = PageSize
    };
}

public sealed class CoursesIndexViewModel
{
    public IReadOnlyList<CourseResponseDto> Courses { get; init; } = [];
    public IReadOnlyList<InstructorOptionDto> Instructors { get; init; } = [];
    public CourseFilterViewModel Filters { get; init; } = new();
    public int TotalCount { get; init; }
    public int TotalPages { get; init; }

    public bool HasResults => Courses.Count > 0;
}

public sealed class RoleFormViewModel
{
    public int UserId { get; set; }

    [Required]
    [Display(Name = "الدور")]
    public string Role { get; set; } = "Student";
}

public sealed class EnrollmentEditViewModel
{
    public int EnrollmentId { get; set; }
    public int CurrentCourseId { get; set; }

    [Required, Range(1, int.MaxValue)]
    [Display(Name = "الكورس الجديد")]
    public int CourseId { get; set; }

    public IEnumerable<CourseResponseDto> Courses { get; init; } = [];
}

public sealed class EnrollmentCreateViewModel
{
    [Required, Range(1, int.MaxValue)]
    [Display(Name = "المستخدم")]
    public int UserId { get; set; }

    [Required, Range(1, int.MaxValue)]
    [Display(Name = "الكورس")]
    public int CourseId { get; set; }

    public IEnumerable<UserResponseDto> Users { get; init; } = [];
    public IEnumerable<CourseResponseDto> Courses { get; init; } = [];
}

public sealed class DashboardViewModel
{
    public IEnumerable<CourseResponseDto> Courses { get; init; } = [];
    public IEnumerable<EnrollmentDto> MyEnrollments { get; init; } = [];
    public int UsersCount { get; init; }
    public int EnrollmentsCount { get; init; }
    public bool IsAuthenticated { get; init; }
    public string Role { get; init; } = string.Empty;
}

public sealed class ErrorViewModel
{
    public string? RequestId { get; init; }
    public bool ShowRequestId => !string.IsNullOrEmpty(RequestId);
}
