using CourseManagement.Application.DTOs;
using CourseManagement.Domain.Entities;
using CourseManagement.Domain.Enums;
using CourseManagement.Infrastructure.Data;
using CourseManagement.Infrastructure.Repositories;
using CourseManagement.Infrastructure.Services;
using Microsoft.Data.Sqlite;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Xunit;

namespace CourseManagement.Tests.Integration;

/// <summary>
/// Regression tests for the mixed-case email defect.
///
/// Lookups lowercased the incoming address (UserRepository) while writes stored the
/// original casing (AuthService/UserService/DbSeeder), and SQLite TEXT columns compare
/// with BINARY collation by default. Any user who typed a capital letter in their email
/// was therefore locked out of their own account permanently, and the unique-email
/// constraint could be bypassed by varying the case.
///
/// These tests run against a real SQLite database with the full migration chain applied,
/// because a faked repository cannot reproduce a collation bug. Each logical operation
/// uses its own DbContext over one shared connection, mirroring the scoped-per-request
/// lifetime the apps use in production.
/// </summary>
public sealed class UserEmailCaseInsensitivityTests : IDisposable
{
    private const string Password = "CorrectHorseBattery1!";

    private readonly SqliteConnection connection;

    public UserEmailCaseInsensitivityTests()
    {
        connection = new SqliteConnection("Data Source=:memory:");
        connection.Open();

        using var migrator = NewContext();
        migrator.Database.Migrate();
    }

    public void Dispose() => connection.Dispose();

    private ApplicationDbContext NewContext() =>
        new(new DbContextOptionsBuilder<ApplicationDbContext>()
            .UseSqlite(connection)
            .Options);

    // IssueToken=false keeps token generation out of these tests, so no JWT secret is needed.
    private static IConfiguration TokenlessConfiguration() =>
        new ConfigurationBuilder()
            .AddInMemoryCollection(new Dictionary<string, string?>
            {
                ["JwtSettings:IssueToken"] = "false"
            })
            .Build();

    private AuthService NewAuthService(ApplicationDbContext context) =>
        new(new UserRepository(context), TokenlessConfiguration());

    [Theory]
    [InlineData("  Ahmad@Example.COM  ", "ahmad@example.com")]
    [InlineData("already@lower.test", "already@lower.test")]
    [InlineData("   ", "")]
    [InlineData(null, "")]
    public void NormalizeEmail_TrimsAndLowercases(string? input, string expected) =>
        Assert.Equal(expected, User.NormalizeEmail(input));

    [Fact]
    public void Migration_GivesEmailACaseInsensitiveCollation()
    {
        using var seed = NewContext();
        seed.Users.Add(new User
        {
            FullName = "Seed",
            Email = "seed@example.com",
            PasswordHash = "not-a-real-hash",
            Role = Role.Student
        });
        seed.SaveChanges();

        // Under the previous BINARY collation this matched zero rows.
        using var read = NewContext();
        Assert.Equal(1, read.Users.Count(u => u.Email == "SEED@EXAMPLE.COM"));
    }

    [Fact]
    public async Task RegisterThenLogin_SucceedsWhenTheEmailWasTypedWithCapitals()
    {
        const string typed = "Ahmad@Example.COM";

        using (var registerScope = NewContext())
            await NewAuthService(registerScope).RegisterAsync(new RegisterDto
            {
                FullName = "Ahmad",
                Email = typed,
                Password = Password
            });

        // Stored in canonical form...
        using var assertScope = NewContext();
        var stored = Assert.Single(assertScope.Users.AsNoTracking().ToList());
        Assert.Equal("ahmad@example.com", stored.Email);

        // ...and still reachable with the exact casing the user originally typed.
        using (var loginScope = NewContext())
        {
            var session = await NewAuthService(loginScope).LoginAsync(
                new LoginDto { Email = typed, Password = Password });
            Assert.Equal(stored.Id, session.UserId);
        }

        // ...and with any other casing of the same address.
        using (var shoutingScope = NewContext())
        {
            var session = await NewAuthService(shoutingScope).LoginAsync(
                new LoginDto { Email = "  AHMAD@EXAMPLE.COM  ", Password = Password });
            Assert.Equal(stored.Id, session.UserId);
        }
    }

    [Fact]
    public async Task Register_RejectsASecondAccountDifferingOnlyByEmailCase()
    {
        using (var first = NewContext())
            await NewAuthService(first).RegisterAsync(new RegisterDto
            {
                FullName = "First",
                Email = "dup@example.com",
                Password = Password
            });

        using (var second = NewContext())
        {
            var conflict = await Assert.ThrowsAsync<InvalidOperationException>(() =>
                NewAuthService(second).RegisterAsync(new RegisterDto
                {
                    FullName = "Second",
                    Email = "DUP@Example.COM",
                    Password = Password
                }));
            Assert.Contains("already exists", conflict.Message, StringComparison.OrdinalIgnoreCase);
        }

        using var assertScope = NewContext();
        Assert.Single(assertScope.Users.AsNoTracking().ToList());
    }

    [Fact]
    public async Task UpdateProfile_StoresCanonicalEmailAndRotatesTheSecurityStamp()
    {
        int userId;
        using (var registerScope = NewContext())
        {
            var created = await NewAuthService(registerScope).RegisterAsync(new RegisterDto
            {
                FullName = "Ahmad",
                Email = "before@example.com",
                Password = Password
            });
            userId = created.UserId;
        }

        Guid originalStamp;
        using (var read = NewContext())
            originalStamp = read.Users.AsNoTracking().Single().SecurityStamp;

        using (var updateScope = NewContext())
            await new UserService(
                new UserRepository(updateScope),
                new CourseRepository(updateScope))
                .UpdateProfileAsync(userId, new UpdateUserDto
                {
                    FullName = "Ahmad",
                    Email = "  After@Example.COM "
                });

        using var assertScope = NewContext();
        var stored = assertScope.Users.AsNoTracking().Single();
        Assert.Equal("after@example.com", stored.Email);
        Assert.NotEqual(originalStamp, stored.SecurityStamp);
    }

    [Fact]
    public async Task UpdateProfile_RejectsAnEmailAlreadyUsedByAnotherAccountInADifferentCase()
    {
        using (var scope = NewContext())
        {
            var auth = NewAuthService(scope);
            await auth.RegisterAsync(new RegisterDto
            {
                FullName = "Owner",
                Email = "taken@example.com",
                Password = Password
            });
        }

        int intruderId;
        using (var scope = NewContext())
        {
            var created = await NewAuthService(scope).RegisterAsync(new RegisterDto
            {
                FullName = "Intruder",
                Email = "intruder@example.com",
                Password = Password
            });
            intruderId = created.UserId;
        }

        using var updateScope = NewContext();
        var users = new UserService(
            new UserRepository(updateScope),
            new CourseRepository(updateScope));

        await Assert.ThrowsAsync<InvalidOperationException>(() =>
            users.UpdateProfileAsync(intruderId, new UpdateUserDto
            {
                FullName = "Intruder",
                Email = "TAKEN@Example.COM"
            }));
    }

    [Fact]
    public async Task Seeder_StoresTheAdminEmailInCanonicalFormSoTheAdminCanLogIn()
    {
        var configuration = new ConfigurationBuilder()
            .AddInMemoryCollection(new Dictionary<string, string?>
            {
                ["JwtSettings:IssueToken"] = "false",
                ["SeedAdmin:Enabled"] = "true",
                ["SeedAdmin:FullName"] = "System Administrator",
                ["SeedAdmin:Email"] = "Admin@Local.TEST",
                ["SeedAdmin:Password"] = Password
            })
            .Build();

        using (var seedScope = NewContext())
            await DbSeeder.SeedAsync(
                seedScope,
                configuration,
                Microsoft.Extensions.Logging.Abstractions.NullLogger.Instance);

        using var assertScope = NewContext();
        var admin = Assert.Single(assertScope.Users.AsNoTracking().ToList());
        Assert.Equal("admin@local.test", admin.Email);
        Assert.Equal(Role.Admin, admin.Role);

        // The seeded admin must be able to authenticate with the address as configured.
        using var loginScope = NewContext();
        var session = await new AuthService(new UserRepository(loginScope), configuration)
            .LoginAsync(new LoginDto { Email = "Admin@Local.TEST", Password = Password });
        Assert.Equal(admin.Id, session.UserId);
    }
}
