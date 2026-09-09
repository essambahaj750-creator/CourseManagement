using System.Net;
using System.Net.Http.Json;
using CourseManagement.Application.DTOs;
using Xunit;

namespace CourseManagement.Tests.Integration;

public sealed class CourseReviewsApiTests(ApiFactory factory) : IClassFixture<ApiFactory>
{
    [Fact]
    public async Task Reviews_ArePublicButWritingRequiresEnrollment()
    {
        var admin = await factory.CreateAdminClientAsync();

        var registration = factory.CreateClient();
        var instructor = await registration.RegisterAsync(
            $"review.instructor.{Guid.NewGuid():N}@example.com",
            "Review Instructor");

        var promote = await admin.PutAsJsonAsync($"/api/users/{instructor.UserId}/role", new
        {
            role = "Instructor"
        });
        promote.EnsureSuccessStatusCode();

        var create = await admin.PostAsJsonAsync("/api/course", new
        {
            title = "Reviewed course",
            description = "Course used to verify real student reviews.",
            price = 0,
            instructorId = instructor.UserId
        });
        create.EnsureSuccessStatusCode();

        var course = await create.Content.ReadFromJsonAsync<CourseResponseDto>();
        Assert.NotNull(course);

        var outsider = await factory.CreateStudentClientAsync(
            $"review.outsider.{Guid.NewGuid():N}@example.com");

        var forbidden = await outsider.PutAsJsonAsync(
            $"/api/course/{course!.Id}/reviews",
            new { rating = 5, comment = "Should be rejected" });
        Assert.Equal(HttpStatusCode.Forbidden, forbidden.StatusCode);

        var student = await factory.CreateStudentClientAsync(
            $"review.student.{Guid.NewGuid():N}@example.com");

        var enroll = await student.PostAsJsonAsync("/api/enrollment", new
        {
            courseId = course.Id
        });
        Assert.Equal(HttpStatusCode.Created, enroll.StatusCode);

        var save = await student.PutAsJsonAsync(
            $"/api/course/{course.Id}/reviews",
            new { rating = 5, comment = "شرح واضح ومفيد" });
        save.EnsureSuccessStatusCode();

        var publicClient = factory.CreateClient();
        var summary = await publicClient.GetFromJsonAsync<CourseReviewSummaryDto>(
            $"/api/course/{course.Id}/reviews");

        Assert.NotNull(summary);
        Assert.Equal(1, summary.ReviewCount);
        Assert.Equal(5d, summary.AverageRating);
        var review = Assert.Single(summary.Reviews);
        Assert.Equal(5, review.Rating);
        Assert.Equal("شرح واضح ومفيد", review.Comment);
    }
}
