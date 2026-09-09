namespace CourseManagement.Application.DTOs;

public sealed class CourseCertificateDto
{
    public string CertificateCode { get; init; } = string.Empty;
    public int UserId { get; init; }
    public int CourseId { get; init; }
    public string StudentName { get; init; } = string.Empty;
    public string CourseTitle { get; init; } = string.Empty;
    public string InstructorName { get; init; } = string.Empty;
    public DateTime CompletedAtUtc { get; init; }
}
