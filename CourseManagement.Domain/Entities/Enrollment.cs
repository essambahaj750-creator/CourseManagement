namespace CourseManagement.Domain.Entities;

public class Enrollment
{
    public int Id { get; set; }
    public int UserId { get; set; }
    public User User { get; set; } = null!;

    public int CourseId { get; set; }
    public Course Course { get; set; } = null!;

    public DateTime EnrolledDate { get; set; } = DateTime.UtcNow;
}