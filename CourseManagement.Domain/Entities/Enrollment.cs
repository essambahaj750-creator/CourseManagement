namespace CourseManagement.Domain.Entities;

public class Enrollment
{
    public int Id { get; set; }
    public int UserId { get; set; }
    public User User { get; set; } = null!;

    public int CourseId { get; set; }
    public Course Course { get; set; } = null!;

    public DateTime EnrolledDate { get; set; } = DateTime.UtcNow;

    // Learning progress is stored on the enrollment so web and mobile share
    // the same state through the same database.
    public int? LastLessonAssetId { get; set; }
    public string CompletedLessonAssetIds { get; set; } = "[]";
    public DateTime? LastAccessedAtUtc { get; set; }
    public DateTime? CompletedAtUtc { get; set; }
}
