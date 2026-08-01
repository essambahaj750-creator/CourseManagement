using CourseManagement.Domain.Entities;
using CourseManagement.Domain.Enums;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;

namespace CourseManagement.Infrastructure.Data;

public static class DbSeeder
{
    /// <summary>
    /// يبذر حساب Admin أولياً إذا لم يوجد أي Admin في النظام.
    /// بدون هذا لا يمكن أبداً إنشاء مدربين — لأن التسجيل العام ينشئ طلاباً فقط.
    /// البيانات تُقرأ من قسم SeedAdmin في الإعدادات.
    /// </summary>
    public static async Task SeedAsync(ApplicationDbContext db, IConfiguration configuration, ILogger logger)
    {
        if (await db.Users.AnyAsync(u => u.Role == Role.Admin))
            return;

        var section = configuration.GetSection("SeedAdmin");
        var email = section["Email"];
        var password = section["Password"];

        if (string.IsNullOrWhiteSpace(email) || string.IsNullOrWhiteSpace(password))
        {
            logger.LogWarning(
                "No admin user exists and SeedAdmin:Email / SeedAdmin:Password are not configured — skipping admin seeding.");
            return;
        }

        db.Users.Add(new User
        {
            FullName = section["FullName"] ?? "System Administrator",
            Email = email.Trim(),
            PasswordHash = BCrypt.Net.BCrypt.HashPassword(password),
            Role = Role.Admin
        });

        await db.SaveChangesAsync();
        logger.LogInformation("Seeded initial admin user {Email}. Change this password after first login!", email);
    }
}
