namespace CourseManagement.Application.DTOs;

public class EnrollmentDto
{
    public int Id { get; set; }
    public int UserId { get; set; }
    public string UserName { get; set; } = string.Empty;
    public int CourseId { get; set; }
    public string CourseTitle { get; set; } = string.Empty;
    public DateTime EnrolledDate { get; set; }
    public int? LastLessonAssetId { get; set; }
    public int CompletedLessons { get; set; }
    public int TotalLessons { get; set; }
    public double ProgressPercent { get; set; }
    public DateTime? LastAccessedAtUtc { get; set; }
}