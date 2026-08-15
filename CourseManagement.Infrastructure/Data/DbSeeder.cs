using CourseManagement.Domain.Entities;
using CourseManagement.Domain.Enums;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;

namespace CourseManagement.Infrastructure.Data;

public static class DbSeeder
{
    public static async Task SeedAsync(ApplicationDbContext db, IConfiguration configuration, ILogger logger)
    {
        var section = configuration.GetSection("SeedAdmin");
        if (!bool.TryParse(section["Enabled"], out var seedingEnabled) || !seedingEnabled)
            return;

        if (await db.Users.AnyAsync(u => u.Role == Role.Admin))
            return;

        var email = section["Email"]?.Trim();
        var password = section["Password"];
        if (string.IsNullOrWhiteSpace(email) || string.IsNullOrWhiteSpace(password))
            throw new InvalidOperationException(
                "SeedAdmin is enabled, but SeedAdmin:Email and SeedAdmin:Password are missing.");

        if (password.Length < 12)
            throw new InvalidOperationException(
                "SeedAdmin:Password must contain at least 12 characters.");

        if (!new System.ComponentModel.DataAnnotations.EmailAddressAttribute().IsValid(email))
            throw new InvalidOperationException("SeedAdmin:Email is not a valid email address.");

        db.Users.Add(new User
        {
            FullName = section["FullName"]?.Trim() ?? "System Administrator",
            Email = email,
            PasswordHash = BCrypt.Net.BCrypt.HashPassword(password),
            SecurityStamp = Guid.NewGuid(),
            IsActive = true,
            Role = Role.Admin
        });

        await db.SaveChangesAsync();
        logger.LogInformation("Seeded initial admin user {Email}. Disable SeedAdmin after first setup.", email);
    }
}
