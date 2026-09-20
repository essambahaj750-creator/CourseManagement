using System.Net.Http.Json;
using CourseManagement.Application.DTOs;

namespace CourseManagement.Tests.Integration;

internal static class ApiTestClientExtensions
{
    /// <summary>Satisfies the 8-character register minimum and the 12-character change minimum.</summary>
    internal const string ValidPassword = "CorrectHorseBattery1!";

    internal static async Task<AuthResponseDto> RegisterAsync(
        this HttpClient client,
        string email,
        string fullName = "Test User",
        string? password = null)
    {
        var response = await client.PostAsJsonAsync("/api/auth/register", new
        {
            fullName,
            email,
            password = password ?? ValidPassword
        });

        response.EnsureSuccessStatusCode();
        var body = await response.Content.ReadFromJsonAsync<AuthResponseDto>();
        return body ?? throw new InvalidOperationException("Register returned an empty body.");
    }

    internal static Task<HttpResponseMessage> PostLoginAsync(
        this HttpClient client,
        string email,
        string? password = null) =>
        client.PostAsJsonAsync("/api/auth/login", new
        {
            email,
            password = password ?? ValidPassword
        });

    internal static void UseBearer(this HttpClient client, string token) =>
        client.DefaultRequestHeaders.Authorization =
            new System.Net.Http.Headers.AuthenticationHeaderValue("Bearer", token);
}
