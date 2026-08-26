using System.Security.Cryptography;
using CourseManagement.API;
using CourseManagement.Infrastructure.Data;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;

namespace CourseManagement.Tests.Integration;

/// <summary>
/// Hosts CourseManagement.API in-process for HTTP-level tests.
///
/// Isolation guarantees, so a test run can never touch real developer data:
///  - the connection string points at a unique temporary SQLite file, created and
///    deleted by this factory, never the repository's coursemanagement.db;
///  - FileUploads:RootPath points at a unique temporary directory, never the
///    shared CourseManagement.Uploads folder;
///  - the JWT signing key is generated per run, so no secret lives in source;
///  - admin seeding is disabled.
///
/// The schema is built by running the real migration chain, so these tests also
/// prove the database can be created from a clean checkout.
/// </summary>
public sealed class ApiFactory : WebApplicationFactory<ApiAssemblyMarker>
{
    private readonly string databasePath;
    private readonly string uploadsRoot;

    /// <summary>
    /// Extra configuration applied on top of the isolated defaults. Populate this
    /// before the first <c>CreateClient</c> call, because startup-time values such
    /// as the rate limit are read once when the host is built.
    /// </summary>
    public Dictionary<string, string?> ConfigurationOverrides { get; } = [];

    public ApiFactory()
    {
        var id = Guid.NewGuid().ToString("N");
        var root = Path.Combine(Path.GetTempPath(), "cm-api-tests", id);
        Directory.CreateDirectory(root);

        databasePath = Path.Combine(root, "test.db");
        uploadsRoot = Path.Combine(root, "uploads");
        Directory.CreateDirectory(uploadsRoot);
    }

    protected override void ConfigureWebHost(IWebHostBuilder builder)
    {
        builder.UseEnvironment("Testing");

        // UseSetting, not ConfigureAppConfiguration. The API uses top-level
        // statements and reads JwtSettings:Secret from builder.Configuration
        // *before* builder.Build(), whereas ConfigureAppConfiguration callbacks
        // are only applied during Build under minimal hosting. UseSetting writes
        // into host configuration, which CreateBuilder picks up immediately.
        foreach (var pair in BuildSettings())
            builder.UseSetting(pair.Key, pair.Value);
    }

    private Dictionary<string, string?> BuildSettings()
    {
        var settings = new Dictionary<string, string?>
        {
            ["ConnectionStrings:DefaultConnection"] = $"Data Source={databasePath}",

            // Generated per run: no signing key is ever committed to source.
            ["JwtSettings:Secret"] = Convert.ToBase64String(RandomNumberGenerator.GetBytes(48)),
            ["JwtSettings:IssueToken"] = "true",
            ["JwtSettings:Issuer"] = "CourseManagementAPI",
            ["JwtSettings:Audience"] = "CourseManagementClient",
            ["JwtSettings:ExpiryHours"] = "2",

            // The factory applies migrations itself, once, in CreateHost.
            ["Database:ApplyMigrations"] = "false",
            ["SeedAdmin:Enabled"] = "false",
            ["Swagger:Enabled"] = "false",

            ["FileUploads:RootPath"] = uploadsRoot,

            // High ceiling so ordinary tests are never throttled. The
            // throttling test lowers this on its own factory instance.
            ["RateLimiting:Auth:PermitLimit"] = "10000",
            ["RateLimiting:Auth:WindowSeconds"] = "60",

            ["Cors:AllowedOrigins:0"] = "https://allowed.test"
        };

        foreach (var pair in ConfigurationOverrides)
            settings[pair.Key] = pair.Value;

        return settings;
    }

    protected override IHost CreateHost(IHostBuilder builder)
    {
        var host = base.CreateHost(builder);

        using var scope = host.Services.CreateScope();
        scope.ServiceProvider.GetRequiredService<ApplicationDbContext>().Database.Migrate();

        return host;
    }

    /// <summary>Registers a student and returns a client carrying its bearer token.</summary>
    public async Task<HttpClient> CreateStudentClientAsync(string email)
    {
        var client = CreateClient();
        var registered = await client.RegisterAsync(email);
        client.DefaultRequestHeaders.Authorization =
            new System.Net.Http.Headers.AuthenticationHeaderValue("Bearer", registered.Token);
        return client;
    }

    protected override void Dispose(bool disposing)
    {
        base.Dispose(disposing);
        if (!disposing) return;

        // Only ever the directory this instance created under the temp path.
        var root = Path.GetDirectoryName(databasePath);
        if (root is null || !Directory.Exists(root)) return;
        try
        {
            Directory.Delete(root, recursive: true);
        }
        catch (IOException)
        {
            // A held SQLite handle should not fail an otherwise passing test run.
        }
    }
}
