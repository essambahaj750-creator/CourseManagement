using CourseManagement.Domain.Enums;

namespace CourseManagement.Domain.Entities;

public class User
{
    public int Id { get; set; }
    public string FullName { get; set; } = string.Empty;
    public string Email { get; set; } = string.Empty;
    public string PasswordHash { get; set; } = string.Empty;
    public Guid SecurityStamp { get; set; } = Guid.NewGuid();
    public bool IsActive { get; set; } = true;
    public Role Role { get; set; }

    /// <summary>
    /// Canonical form used for every read and write of <see cref="Email"/>.
    /// Emails are case-insensitive in practice, but SQLite TEXT columns compare with
    /// BINARY collation by default, so storing mixed case while querying lower case
    /// made the account unreachable at login. Normalise on both sides, and keep the
    /// NOCASE collation configured in ApplicationDbContext as the backstop.
    /// </summary>
    public static string NormalizeEmail(string? email) =>
        (email ?? string.Empty).Trim().ToLowerInvariant();
}