using System.Net;
using System.Net.Http.Json;
using System.Text;
using System.Text.Json;
using CourseManagement.API.Middleware;
using CourseManagement.Application.Common;
using CourseManagement.Application.DTOs;
using Microsoft.AspNetCore.Http;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging.Abstractions;
using Xunit;

namespace CourseManagement.Tests.Integration;

/// <summary>
/// Pins the error contract.
///
/// Two defects motivated these tests. Framework exception messages were returned
/// verbatim — <c>InvalidOperationException</c> mapped to 409 with its own text, so a
/// configuration failure such as "JwtSettings:Secret is not configured." reached
/// anonymous callers. And authored validation messages were thrown away —
/// <c>ArgumentException</c> mapped to 400 with a fixed generic string, so every
/// upload reason ("exceeds the 50 MB limit", "extension is not allowed") was
/// replaced by "One or more request values are invalid.", leaving users and tests
/// equally blind.
///
/// The rule now: only InvalidRequestException and ConflictException have their
/// messages returned, because only those are written for end users.
/// </summary>
public sealed class ErrorContractTests
{
    private static async Task<(int Status, string Body, string? ContentType)> RunAsync(Exception thrown)
    {
        var context = new DefaultHttpContext();
        context.Request.Method = "GET";
        context.Request.Path = "/api/probe";
        context.Response.Body = new MemoryStream();

        var middleware = new ExceptionHandlingMiddleware(
            _ => throw thrown,
            NullLogger<ExceptionHandlingMiddleware>.Instance);

        await middleware.InvokeAsync(context);

        context.Response.Body.Position = 0;
        using var reader = new StreamReader(context.Response.Body, Encoding.UTF8);
        var body = await reader.ReadToEndAsync();
        return (context.Response.StatusCode, body, context.Response.ContentType);
    }

    [Fact]
    public async Task InvalidRequest_Returns400AndKeepsTheAuthoredMessage()
    {
        const string authored = "The file exceeds the 50 MB limit.";
        var (status, body, contentType) = await RunAsync(new InvalidRequestException(authored));
        Assert.Equal(400, status);
        Assert.Contains(authored, body);
        Assert.StartsWith("application/problem+json", contentType);
    }

    [Fact]
    public async Task Conflict_Returns409AndKeepsTheAuthoredMessage()
    {
        const string authored = "User is already enrolled in this course.";
        var (status, body, _) = await RunAsync(new ConflictException(authored));
        Assert.Equal(409, status);
        Assert.Contains(authored, body);
    }

    [Fact]
    public async Task InvalidOperation_Returns500AndNeverLeaksItsMessage()
    {
        var (status, body, _) = await RunAsync(
            new InvalidOperationException("JwtSettings:Secret is not configured."));
        Assert.Equal(500, status);
        Assert.DoesNotContain("JwtSettings", body);
        Assert.DoesNotContain("Secret", body);
        Assert.DoesNotContain("configured", body);
    }

    [Fact]
    public async Task ArgumentException_Returns400AndNeverLeaksItsMessage()
    {
        var (status, body, _) = await RunAsync(
            new ArgumentException("Parameter 'internalOffset' was out of range."));
        Assert.Equal(400, status);
        Assert.DoesNotContain("internalOffset", body);
    }

    [Fact]
    public async Task UnexpectedException_Returns500AndNeverLeaksItsMessage()
    {
        var (status, body, _) = await RunAsync(
            new NullReferenceException("Object reference not set at StorageInternals.Resolve"));
        Assert.Equal(500, status);
        Assert.DoesNotContain("StorageInternals", body);
        Assert.DoesNotContain("Object reference", body);
    }

    [Fact]
    public async Task DbUpdateException_Returns409AndNeverLeaksTheSqlDetail()
    {
        var (status, body, _) = await RunAsync(
            new DbUpdateException("SQLite Error 19: 'UNIQUE constraint failed: Users.Email'."));
        Assert.Equal(409, status);
        Assert.DoesNotContain("SQLite", body);
        Assert.DoesNotContain("UNIQUE", body);
    }

    [Fact]
    public async Task ForbiddenAccess_Returns403() =>
        Assert.Equal(403, (await RunAsync(new ForbiddenAccessException("owner only"))).Status);

    [Fact]
    public async Task Unauthorized_Returns401() =>
        Assert.Equal(401, (await RunAsync(new UnauthorizedAccessException("nope"))).Status);

    [Fact]
    public async Task NotFound_Returns404() =>
        Assert.Equal(404, (await RunAsync(new KeyNotFoundException("missing"))).Status);

    [Fact]
    public async Task EveryResponse_CarriesATraceId()
    {
        var (_, body, _) = await RunAsync(new ConflictException("anything"));
        var problem = JsonSerializer.Deserialize<JsonElement>(body);
        Assert.True(problem.TryGetProperty("traceId", out var traceId));
        Assert.False(string.IsNullOrWhiteSpace(traceId.GetString()));
    }

    [Fact]
    public async Task ClientDisconnect_IsNotReportedAsAServerError()
    {
        var context = new DefaultHttpContext
        {
            RequestAborted = new CancellationToken(canceled: true)
        };
        context.Response.Body = new MemoryStream();

        var middleware = new ExceptionHandlingMiddleware(
            _ => throw new OperationCanceledException(),
            NullLogger<ExceptionHandlingMiddleware>.Instance);

        await middleware.InvokeAsync(context);
        Assert.Equal(499, context.Response.StatusCode);
    }
}

/// <summary>
/// The same contract observed over real HTTP, so the fix is proven end to end and
/// not only at the middleware boundary.
/// </summary>
public sealed class ErrorContractOverHttpTests(ApiFactory factory) : IClassFixture<ApiFactory>
{
    [Fact]
    public async Task DuplicateRegistration_Returns409WithTheAuthoredReason()
    {
        var client = factory.CreateClient();
        await client.RegisterAsync("duplicate.contract@example.com");

        var second = await client.PostAsJsonAsync("/api/auth/register", new
        {
            fullName = "Second Attempt",
            email = "duplicate.contract@example.com",
            password = ApiTestClientExtensions.ValidPassword
        });

        Assert.Equal(HttpStatusCode.Conflict, second.StatusCode);
        var problem = await second.Content.ReadFromJsonAsync<JsonElement>();
        Assert.Equal(
            "User with this email already exists.",
            problem.GetProperty("detail").GetString());
    }

    [Fact]
    public async Task RejectedUpload_ExplainsWhyInsteadOfAGenericMessage()
    {
        var admin = await factory.CreateAdminClientAsync();
        var instructorId = await CreateInstructorIdAsync("upload-contract");

        var created = await admin.PostAsJsonAsync("/api/course", new
        {
            title = "Error contract course",
            description = "Used to assert upload validation messages survive.",
            price = 0,
            instructorId
        });
        created.EnsureSuccessStatusCode();
        var course = await created.Content.ReadFromJsonAsync<CourseResponseDto>();

        using var form = new MultipartFormDataContent();
        var file = new ByteArrayContent([1, 2, 3, 4]);
        file.Headers.ContentType = new System.Net.Http.Headers.MediaTypeHeaderValue("video/mp4");
        form.Add(file, "file", "lesson.exe");
        form.Add(new StringContent("1"), "type");

        var response = await admin.PostAsync($"/api/course/{course!.Id}/assets", form);

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        var problem = await response.Content.ReadFromJsonAsync<JsonElement>();
        var detail = problem.GetProperty("detail").GetString();
        Assert.Equal("This video extension is not allowed.", detail);
        Assert.NotEqual("One or more request values are invalid.", detail);
    }

    [Fact]
    public async Task OversizedCover_ReportsTheActualLimit()
    {
        var admin = await factory.CreateAdminClientAsync();
        var instructorId = await CreateInstructorIdAsync("cover-contract");

        var created = await admin.PostAsJsonAsync("/api/course", new
        {
            title = "Cover limit course",
            description = "Used to assert the size limit reaches the client.",
            price = 0,
            instructorId
        });
        created.EnsureSuccessStatusCode();
        var course = await created.Content.ReadFromJsonAsync<CourseResponseDto>();

        using var form = new MultipartFormDataContent();
        var oversized = new ByteArrayContent(new byte[6 * 1024 * 1024]);
        oversized.Headers.ContentType = new System.Net.Http.Headers.MediaTypeHeaderValue("image/png");
        form.Add(oversized, "file", "huge.png");

        var response = await admin.PostAsync($"/api/course/{course!.Id}/cover", form);

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        var problem = await response.Content.ReadFromJsonAsync<JsonElement>();
        Assert.Contains("5 MB limit", problem.GetProperty("detail").GetString());
    }

    [Fact]
    public async Task SelfEnrollmentInAnOwnedCourse_Returns409WithTheAuthoredReason()
    {
        var instructor = await CreateInstructorClientAsync("self-enrollment");

        var created = await instructor.PostAsJsonAsync("/api/course", new
        {
            title = "Own course enrollment",
            description = "The owner must not be able to enroll.",
            price = 0
        });
        created.EnsureSuccessStatusCode();
        var course = await created.Content.ReadFromJsonAsync<CourseResponseDto>();

        var response = await instructor.PostAsJsonAsync(
            "/api/enrollment",
            new { courseId = course!.Id });

        Assert.Equal(HttpStatusCode.Conflict, response.StatusCode);
        var problem = await response.Content.ReadFromJsonAsync<JsonElement>();
        Assert.Equal(
            "You cannot enroll in your own course.",
            problem.GetProperty("detail").GetString());
    }

    private async Task<int> CreateInstructorIdAsync(string prefix)
    {
        var email = $"{prefix}.{Guid.NewGuid():N}@example.com";
        var registrationClient = factory.CreateClient();
        var registered = await registrationClient.RegisterAsync(email, "Contract Instructor");

        var admin = await factory.CreateAdminClientAsync();
        var promote = await admin.PutAsJsonAsync(
            $"/api/users/{registered.UserId}/role",
            new { role = "Instructor" });
        promote.EnsureSuccessStatusCode();
        return registered.UserId;
    }

    private async Task<HttpClient> CreateInstructorClientAsync(string prefix)
    {
        var email = $"{prefix}.{Guid.NewGuid():N}@example.com";
        var registrationClient = factory.CreateClient();
        var registered = await registrationClient.RegisterAsync(email, "Contract Instructor");

        var admin = await factory.CreateAdminClientAsync();
        var promote = await admin.PutAsJsonAsync(
            $"/api/users/{registered.UserId}/role",
            new { role = "Instructor" });
        promote.EnsureSuccessStatusCode();

        var login = await registrationClient.PostLoginAsync(email);
        login.EnsureSuccessStatusCode();
        var session = await login.Content.ReadFromJsonAsync<AuthResponseDto>()
            ?? throw new InvalidOperationException("Instructor login returned an empty body.");

        var instructorClient = factory.CreateClient();
        instructorClient.UseBearer(session.Token);
        return instructorClient;
    }
}
