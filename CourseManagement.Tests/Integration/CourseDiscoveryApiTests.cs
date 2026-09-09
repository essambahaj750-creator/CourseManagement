using System.Net;
using System.Net.Http.Json;
using CourseManagement.Application.DTOs;
using Xunit;

namespace CourseManagement.Tests.Integration;

public sealed class CourseDiscoveryApiTests(ApiFactory factory) : IClassFixture<ApiFactory>
{
    [Fact]
    public async Task CatalogSocialProof_ReflectsRealEnrollmentsAndReviews()
    {
        var admin = await factory.CreateAdminClientAsync();
        var registration = factory.CreateClient();

        var instructor = await registration.RegisterAsync(
            $"discovery.instructor.{Guid.NewGuid():N}@example.com",
            "Discovery Instructor");

        var promote = await admin.PutAsJsonAsync($"/api/users/{instructor.UserId}/role", new
        {
            role = "Instructor"
        });
        promote.EnsureSuccessStatusCode();

        async Task<CourseResponseDto> CreateCourseAsync(string title, decimal price)
        {
            var response = await admin.PostAsJsonAsync("/api/course", new
            {
                title,
                description = "Discovery test course.",
                price,
                instructorId = instructor.UserId
            });
            response.EnsureSuccessStatusCode();
            return (await response.Content.ReadFromJsonAsync<CourseResponseDto>())!;
        }

        var primary = await CreateCourseAsync("Discovery Primary", 20m);
        var related = await CreateCourseAsync("Discovery Related", 25m);

        var student = await factory.CreateStudentClientAsync(
            $"discovery.student.{Guid.NewGuid():N}@example.com");

        var enroll = await student.PostAsJsonAsync("/api/enrollment", new
        {
            courseId = primary.Id
        });
        Assert.Equal(HttpStatusCode.Created, enroll.StatusCode);

        var review = await student.PutAsJsonAsync(
            $"/api/course/{primary.Id}/reviews",
            new
            {
                rating = 4,
                comment = "Useful course"
            });
        review.EnsureSuccessStatusCode();

        var catalog = await factory.CreateClient().GetFromJsonAsync<CourseCatalogDto>(
            "/api/course/search?q=Discovery%20Primary&page=1&pageSize=10");

        Assert.NotNull(catalog);
        var item = Assert.Single(catalog.Items);
        Assert.Equal(primary.Id, item.Id);
        Assert.Equal(1, item.EnrolledStudents);
        Assert.Equal(1, item.ReviewCount);
        Assert.Equal(4d, item.AverageRating);

        var recommendations = await factory.CreateClient()
            .GetFromJsonAsync<List<CourseResponseDto>>(
                $"/api/course/{primary.Id}/related?limit=4");

        Assert.NotNull(recommendations);
        Assert.Contains(recommendations, course => course.Id == related.Id);
    }
}
