using System.Net;
using System.Net.Http.Json;
using CourseManagement.Application.DTOs;
using Xunit;

namespace CourseManagement.Tests.Integration;

public sealed class CourseOwnershipApiTests(ApiFactory factory) : IClassFixture<ApiFactory>
{
    [Fact]
    public async Task AdminMustAssignARealInstructorWhenCreatingCourse()
    {
        var admin = await factory.CreateAdminClientAsync();

        var missingInstructor = await admin.PostAsJsonAsync("/api/course", new
        {
            title = "Admin ownership guard",
            description = "Must not be owned by the admin account.",
            price = 10
        });

        Assert.Equal(HttpStatusCode.BadRequest, missingInstructor.StatusCode);

        var registrationClient = factory.CreateClient();
        var candidate = await registrationClient.RegisterAsync(
            $"course.instructor.{Guid.NewGuid():N}@example.com",
            "Assigned Instructor");

        var promote = await admin.PutAsJsonAsync($"/api/users/{candidate.UserId}/role", new
        {
            role = "Instructor"
        });
        promote.EnsureSuccessStatusCode();

        var create = await admin.PostAsJsonAsync("/api/course", new
        {
            title = "Correctly assigned course",
            description = "Owned by a real instructor.",
            price = 25,
            instructorId = candidate.UserId
        });

        Assert.Equal(HttpStatusCode.Created, create.StatusCode);
        var course = await create.Content.ReadFromJsonAsync<CourseResponseDto>();
        Assert.NotNull(course);
        Assert.Equal(candidate.UserId, course.InstructorId);
        Assert.Equal("Assigned Instructor", course.InstructorName);
    }

    [Fact]
    public async Task AdminCannotAssignAStudentAsCourseInstructor()
    {
        var admin = await factory.CreateAdminClientAsync();
        var registrationClient = factory.CreateClient();
        var student = await registrationClient.RegisterAsync(
            $"course.student.{Guid.NewGuid():N}@example.com",
            "Still A Student");

        var response = await admin.PostAsJsonAsync("/api/course", new
        {
            title = "Invalid owner course",
            description = "A student cannot own an instructor course.",
            price = 0,
            instructorId = student.UserId
        });

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
    }
}
