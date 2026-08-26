using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using CourseManagement.Application.DTOs;
using Xunit;

namespace CourseManagement.Tests.Integration;

/// <summary>
/// First HTTP-level coverage of CourseManagement.API. Before these, the API project
/// had no tests at all: JWT authentication, role authorization, CORS, rate limiting
/// and the exception middleware were exercised only by hand.
///
/// Each test drives the real pipeline through <see cref="ApiFactory"/>, against an
/// isolated temporary database and uploads directory.
/// </summary>
public sealed class ApiEndpointTests(ApiFactory factory) : IClassFixture<ApiFactory>
{
    // ---------- anonymous surface ----------

    [Fact]
    public async Task HealthCheck_IsReachableAnonymously()
    {
        var response = await factory.CreateClient().GetAsync("/health");

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
    }

    [Theory]
    [InlineData("/api/course")]
    [InlineData("/api/course/search?page=1&pageSize=9")]
    [InlineData("/api/course/instructors")]
    public async Task PublicCatalogEndpoints_AllowAnonymousAccess(string path)
    {
        var response = await factory.CreateClient().GetAsync(path);

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
    }

    // ---------- authentication ----------

    [Theory]
    [InlineData("/api/users/me")]
    [InlineData("/api/enrollment/my")]
    [InlineData("/api/course/1/assets")]
    public async Task ProtectedEndpoints_WithoutAToken_Return401(string path)
    {
        var response = await factory.CreateClient().GetAsync(path);

        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }

    [Fact]
    public async Task ProtectedEndpoint_WithAGarbageToken_Returns401()
    {
        var client = factory.CreateClient();
        client.UseBearer("not-a-real-token");

        var response = await client.GetAsync("/api/users/me");

        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }

    [Fact]
    public async Task Register_IssuesAJwtThatAuthenticatesSubsequentRequests()
    {
        var client = factory.CreateClient();
        var registered = await client.RegisterAsync("jwt.roundtrip@example.com", "Round Trip");

        Assert.False(string.IsNullOrWhiteSpace(registered.Token));
        Assert.Equal("Student", registered.Role);

        client.UseBearer(registered.Token);
        var me = await client.GetFromJsonAsync<UserResponseDto>("/api/users/me");

        Assert.NotNull(me);
        Assert.Equal("jwt.roundtrip@example.com", me.Email);
        Assert.Equal("Student", me.Role);
    }

    [Fact]
    public async Task Login_AcceptsAnyCasingOfTheRegisteredEmail()
    {
        // End-to-end guard over HTTP for the mixed-case lockout defect: registering
        // with capitals used to make the account permanently unreachable.
        var client = factory.CreateClient();
        await client.RegisterAsync("Mixed.Case@Example.COM", "Mixed Case");

        var exact = await client.PostLoginAsync("Mixed.Case@Example.COM");
        var shouting = await client.PostLoginAsync("  MIXED.CASE@EXAMPLE.COM  ");
        var lower = await client.PostLoginAsync("mixed.case@example.com");

        Assert.Equal(HttpStatusCode.OK, exact.StatusCode);
        Assert.Equal(HttpStatusCode.OK, shouting.StatusCode);
        Assert.Equal(HttpStatusCode.OK, lower.StatusCode);
    }

    [Fact]
    public async Task Login_WithTheWrongPassword_Returns401()
    {
        var client = factory.CreateClient();
        await client.RegisterAsync("wrong.password@example.com");

        var response = await client.PostLoginAsync("wrong.password@example.com", "NotThePassword9!");

        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }

    [Fact]
    public async Task Login_ForAnUnknownAccount_Returns401()
    {
        var response = await factory.CreateClient().PostLoginAsync("nobody.here@example.com");

        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }

    [Theory]
    [InlineData("not-an-email", "CorrectHorseBattery1!")]
    [InlineData("short.password@example.com", "abc")]
    public async Task Register_RejectsInvalidInputWith400(string email, string password)
    {
        var response = await factory.CreateClient().PostAsJsonAsync("/api/auth/register", new
        {
            fullName = "Someone",
            email,
            password
        });

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
    }

    // ---------- role authorization ----------

    [Theory]
    [InlineData("/api/users")]
    [InlineData("/api/enrollment")]
    public async Task AdminOnlyEndpoints_AsAStudent_Return403(string path)
    {
        var client = await factory.CreateStudentClientAsync($"student.forbidden{path.GetHashCode():X}@example.com");

        var response = await client.GetAsync(path);

        Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);
    }

    [Fact]
    public async Task CreatingACourse_AsAStudent_Is403()
    {
        var client = await factory.CreateStudentClientAsync("student.author@example.com");

        var response = await client.PostAsJsonAsync("/api/course", new
        {
            title = "Unauthorized course",
            description = "Should never be created.",
            price = 0
        });

        Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);
    }

    [Fact]
    public async Task ReadingAnotherUsersProfile_Is403()
    {
        var first = await factory.CreateStudentClientAsync("idor.victim@example.com");
        var victim = await first.GetFromJsonAsync<UserResponseDto>("/api/users/me");

        var attacker = await factory.CreateStudentClientAsync("idor.attacker@example.com");
        var response = await attacker.GetAsync($"/api/users/{victim!.Id}");

        Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);
    }

    // ---------- error contract shape ----------

    [Fact]
    public async Task UnknownResource_RespondsWithProblemDetailsCarryingATraceId()
    {
        // Asserts the envelope only, not the wording: the messages themselves are
        // due to change when the error contract is tightened.
        var client = await factory.CreateStudentClientAsync("problem.shape@example.com");

        var response = await client.GetAsync("/api/course/999999/assets");

        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
        Assert.Equal("application/problem+json", response.Content.Headers.ContentType?.MediaType);

        var problem = await response.Content.ReadFromJsonAsync<JsonElement>();
        Assert.True(problem.TryGetProperty("traceId", out var traceId));
        Assert.False(string.IsNullOrWhiteSpace(traceId.GetString()));
        Assert.Equal(404, problem.GetProperty("status").GetInt32());
    }

    // ---------- CORS ----------

    [Fact]
    public async Task Cors_EchoesOnlyConfiguredOrigins()
    {
        var client = factory.CreateClient();

        var allowed = new HttpRequestMessage(HttpMethod.Get, "/api/course");
        allowed.Headers.Add("Origin", "https://allowed.test");
        var allowedResponse = await client.SendAsync(allowed);

        var denied = new HttpRequestMessage(HttpMethod.Get, "/api/course");
        denied.Headers.Add("Origin", "https://evil.test");
        var deniedResponse = await client.SendAsync(denied);

        Assert.True(allowedResponse.Headers.Contains("Access-Control-Allow-Origin"));
        Assert.False(deniedResponse.Headers.Contains("Access-Control-Allow-Origin"));
    }
}

/// <summary>
/// Throttling needs its own host because the limit is a startup-time configuration
/// value, and a low ceiling would break every other test sharing the fixture.
/// </summary>
public sealed class AuthRateLimitTests
{
    [Fact]
    public async Task AuthEndpoints_Return429_OnceTheConfiguredLimitIsExceeded()
    {
        const int permitLimit = 3;
        using var factory = new ApiFactory();
        factory.ConfigurationOverrides["RateLimiting:Auth:PermitLimit"] = permitLimit.ToString();
        factory.ConfigurationOverrides["RateLimiting:Auth:WindowSeconds"] = "60";

        var client = factory.CreateClient();
        var statuses = new List<HttpStatusCode>();
        for (var attempt = 0; attempt < permitLimit + 2; attempt++)
        {
            var response = await client.PostLoginAsync("throttled@example.com");
            statuses.Add(response.StatusCode);
        }

        // The first `permitLimit` requests reach the handler and fail
        // authentication; everything after is rejected by the limiter.
        Assert.All(statuses.Take(permitLimit), status =>
            Assert.Equal(HttpStatusCode.Unauthorized, status));
        Assert.All(statuses.Skip(permitLimit), status =>
            Assert.Equal(HttpStatusCode.TooManyRequests, status));
    }

    [Fact]
    public async Task PublicCatalog_IsNotThrottledByTheAuthPolicy()
    {
        using var factory = new ApiFactory();
        factory.ConfigurationOverrides["RateLimiting:Auth:PermitLimit"] = "1";
        factory.ConfigurationOverrides["RateLimiting:Auth:WindowSeconds"] = "60";

        var client = factory.CreateClient();
        for (var attempt = 0; attempt < 5; attempt++)
        {
            var response = await client.GetAsync("/api/course");
            Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        }
    }
}
