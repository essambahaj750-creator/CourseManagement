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

        var email = User.NormalizeEmail(section["Email"]);
        var password = section["Password"];
        if (string.IsNullOrWhiteSpace(email) || string.IsNullOrWhiteSpace(password))
            throw new InvalidOperationException(
                "SeedAdmin is enabled, but SeedAdmin:Email and SeedAdmin:Password are missing.");

        if (password.Length < 12)
            throw new InvalidOperationException(
                "SeedAdmin:Password must contain at least 12 characters.");

        if (!new System.ComponentModel.DataAnnotations.EmailAddressAttribute().IsValid(email))
            throw new InvalidOperationException("SeedAdmin:Email is not a valid email address.");

        var fullName = section["FullName"]?.Trim();
        if (string.IsNullOrWhiteSpace(fullName))
            fullName = "System Administrator";

        var resetExisting = bool.TryParse(section["ResetExisting"], out var reset) && reset;
        var existingAdmin = await db.Users
            .OrderBy(u => u.Id)
            .FirstOrDefaultAsync(u => u.Role == Role.Admin);

        if (existingAdmin is not null)
        {
            if (!resetExisting)
                return;

            var emailUsedByAnotherUser = await db.Users.AnyAsync(
                u => u.Id != existingAdmin.Id && u.Email == email);

            if (emailUsedByAnotherUser)
                throw new InvalidOperationException(
                    "SeedAdmin:Email is already used by another account.");

            existingAdmin.FullName = fullName;
            existingAdmin.Email = email;
            existingAdmin.PasswordHash = BCrypt.Net.BCrypt.HashPassword(password);
            existingAdmin.SecurityStamp = Guid.NewGuid();
            existingAdmin.IsActive = true;
            existingAdmin.Role = Role.Admin;

            await db.SaveChangesAsync();
            logger.LogWarning(
                "Reset existing admin account {AdminId} to {Email}. Disable SeedAdmin:ResetExisting immediately after recovery.",
                existingAdmin.Id,
                email);
            return;
        }

        db.Users.Add(new User
        {
            FullName = fullName,
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
