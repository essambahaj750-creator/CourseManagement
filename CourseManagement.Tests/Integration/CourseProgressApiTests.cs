using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using CourseManagement.Application.DTOs;
using Xunit;

namespace CourseManagement.Tests.Integration;

public sealed class CourseProgressApiTests(ApiFactory factory) : IClassFixture<ApiFactory>
{
    [Fact]
    public async Task StudentProgress_PersistsAcrossApiReads()
    {
        var admin = await factory.CreateAdminClientAsync();

        var registration = factory.CreateClient();
        var instructor = await registration.RegisterAsync(
            $"progress.instructor.{Guid.NewGuid():N}@example.com",
            "Progress Instructor");

        var promote = await admin.PutAsJsonAsync($"/api/users/{instructor.UserId}/role", new
        {
            role = "Instructor"
        });
        promote.EnsureSuccessStatusCode();

        var createdCourse = await admin.PostAsJsonAsync("/api/course", new
        {
            title = "Progress course",
            description = "Course used to verify cross-device progress.",
            price = 0,
            instructorId = instructor.UserId
        });
        createdCourse.EnsureSuccessStatusCode();

        var course = await createdCourse.Content.ReadFromJsonAsync<CourseResponseDto>();
        Assert.NotNull(course);

        using var upload = new MultipartFormDataContent();
        var bytes = new byte[]
        {
            0x00, 0x00, 0x00, 0x18, 0x66, 0x74, 0x79, 0x70,
            0x69, 0x73, 0x6F, 0x6D, 0x00, 0x00, 0x00, 0x00
        };
        var video = new ByteArrayContent(bytes);
        video.Headers.ContentType = new MediaTypeHeaderValue("video/mp4");
        upload.Add(video, "file", "lesson-01.mp4");
        upload.Add(new StringContent("1"), "type");

        var uploaded = await admin.PostAsync($"/api/course/{course!.Id}/assets", upload);
        Assert.Equal(HttpStatusCode.Created, uploaded.StatusCode);
        var asset = await uploaded.Content.ReadFromJsonAsync<CourseAssetDto>();
        Assert.NotNull(asset);

        var student = await factory.CreateStudentClientAsync(
            $"progress.student.{Guid.NewGuid():N}@example.com");

        var enroll = await student.PostAsJsonAsync("/api/enrollment", new
        {
            courseId = course.Id
        });
        Assert.Equal(HttpStatusCode.Created, enroll.StatusCode);

        var before = await student.GetFromJsonAsync<CourseProgressDto>(
            $"/api/enrollment/course/{course.Id}/progress");
        Assert.NotNull(before);
        Assert.Equal(0, before.CompletedCount);
        Assert.Equal(1, before.TotalLessons);
        Assert.Equal(0d, before.ProgressPercent);

        var update = await student.PutAsJsonAsync(
            $"/api/enrollment/course/{course.Id}/progress",
            new
            {
                assetId = asset!.Id,
                completed = true
            });
        update.EnsureSuccessStatusCode();

        var after = await student.GetFromJsonAsync<CourseProgressDto>(
            $"/api/enrollment/course/{course.Id}/progress");
        Assert.NotNull(after);
        Assert.Equal(asset.Id, after.LastLessonAssetId);
        Assert.Contains(asset.Id, after.CompletedLessonAssetIds);
        Assert.Equal(1, after.CompletedCount);
        Assert.Equal(1, after.TotalLessons);
        Assert.Equal(100d, after.ProgressPercent);
        Assert.NotNull(after.LastAccessedAtUtc);
    }
}
