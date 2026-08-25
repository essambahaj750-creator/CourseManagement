using CourseManagement.Application.Common;
using CourseManagement.Application.Interfaces;
using CourseManagement.Application.Options;
using CourseManagement.Domain.Entities;
using CourseManagement.Domain.Enums;
using CourseManagement.Domain.Interfaces;
using CourseManagement.Domain.Models;
using CourseManagement.Infrastructure.Services;
using Microsoft.Extensions.FileProviders;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging.Abstractions;
using Microsoft.Extensions.Options;
using Xunit;

namespace CourseManagement.Tests.Integration;

public sealed class CourseAssetsTests
{
    [Fact]
    public async Task LocalFileStorage_SavesReadsAndDeletesBytesWithoutAcceptingTraversal()
    {
        var root = CreateTempDirectory();
        try
        {
            var storage = new LocalFileStorage(
                new TestHostEnvironment(root),
                Options.Create(new FileUploadOptions { RootPath = "uploads" }));
            var bytes = new byte[] { 1, 2, 3, 4 };

            var stored = await storage.SaveAsync(new MemoryStream(bytes), ".pdf");

            Assert.DoesNotContain("/", stored.StoredFileName);
            Assert.DoesNotContain("\\", stored.StoredFileName);
            Assert.True(File.Exists(stored.AbsolutePath));
            await using (var opened = await storage.OpenReadAsync(stored.StoredFileName))
            {
                using var copy = new MemoryStream();
                await opened.CopyToAsync(copy);
                Assert.Equal(bytes, copy.ToArray());
            }

            await Assert.ThrowsAsync<InvalidOperationException>(() =>
                storage.OpenReadAsync("../outside.pdf"));
            await storage.DeleteAsync(stored.StoredFileName);
            Assert.False(File.Exists(stored.AbsolutePath));
        }
        finally
        {
            Directory.Delete(root, recursive: true);
        }
    }

    [Fact]
    public async Task Upload_StoresMetadataAndSanitizesOriginalFileName()
    {
        var course = new Course { Id = 7, InstructorId = 9, Title = "Testing" };
        var assets = new FakeAssetRepository();
        var files = new FakeFileStorage();
        var service = CreateService(course, assets, files, enrolled: false);

        var result = await service.UploadAsync(
            course.Id,
            "../lesson.mp4",
            "video/mp4",
            4,
            CourseAssetType.Video,
            new MemoryStream(new byte[] { 1, 2, 3, 4 }),
            requesterId: course.InstructorId,
            isAdmin: false);

        Assert.Equal("lesson.mp4", result.OriginalFileName);
        Assert.Equal(CourseAssetType.Video, result.Type);
        Assert.Single(assets.Items);
        Assert.Single(files.SavedNames);
    }

    [Theory]
    [InlineData("lesson.exe", "application/octet-stream", 1)]
    [InlineData("lesson.mp4", "application/pdf", 1)]
    [InlineData("notes.pdf", "text/plain", 2)]
    public async Task Upload_RejectsUnsupportedExtensionOrMime(string fileName, string contentType, int typeValue)
    {
        var course = new Course { Id = 7, InstructorId = 9, Title = "Testing" };
        var files = new FakeFileStorage();
        var service = CreateService(course, new FakeAssetRepository(), files, enrolled: false);

        await Assert.ThrowsAsync<ArgumentException>(() => service.UploadAsync(
            course.Id,
            fileName,
            contentType,
            8,
            (CourseAssetType)typeValue,
            new MemoryStream(new byte[8]),
            requesterId: course.InstructorId,
            isAdmin: false));
        Assert.Empty(files.SavedNames);
    }

    [Fact]
    public async Task Upload_RejectsNonOwnerAndStudentCannotReadBeforeEnrollment()
    {
        var course = new Course { Id = 7, InstructorId = 9, Title = "Testing" };
        var assets = new FakeAssetRepository();
        var service = CreateService(course, assets, new FakeFileStorage(), enrolled: false);

        await Assert.ThrowsAsync<ForbiddenAccessException>(() => service.UploadAsync(
            course.Id,
            "lesson.mp4",
            "video/mp4",
            8,
            CourseAssetType.Video,
            new MemoryStream(new byte[8]),
            requesterId: 10,
            isAdmin: false));

        assets.Items.Add(new CourseAsset
        {
            Id = 1,
            CourseId = course.Id,
            Course = course,
            OriginalFileName = "lesson.mp4",
            StoredFileName = "stored.mp4",
            ContentType = "video/mp4",
            SizeBytes = 8,
            Type = CourseAssetType.Video,
            CreatedAtUtc = DateTime.UtcNow
        });

        await Assert.ThrowsAsync<ForbiddenAccessException>(() => service.GetByCourseIdAsync(
            course.Id,
            requesterId: 10,
            isAdmin: false));
    }

    [Fact]
    public async Task DeletingCourse_CleansUpPhysicalAssetFiles()
    {
        var course = new Course { Id = 7, InstructorId = 9, Title = "Testing" };
        var assets = new FakeAssetRepository();
        assets.Items.Add(new CourseAsset
        {
            Id = 1,
            CourseId = course.Id,
            OriginalFileName = "lesson.mp4",
            StoredFileName = "stored.mp4",
            ContentType = "video/mp4",
            SizeBytes = 8,
            Type = CourseAssetType.Video,
            CreatedAtUtc = DateTime.UtcNow
        });
        var files = new FakeFileStorage();
        var repository = new FakeCourseRepository(course);
        var service = new CourseService(
            repository,
            assets,
            files,
            NullLogger<CourseService>.Instance);

        await service.DeleteCourseAsync(course.Id, course.InstructorId, isAdmin: false);

        Assert.True(repository.WasDeleted);
        Assert.Contains("stored.mp4", files.DeletedNames);
    }

    [Fact]
    public async Task EnrolledStudentCanListAndOpenAsset()
    {
        var course = new Course { Id = 7, InstructorId = 9, Title = "Testing" };
        var assets = new FakeAssetRepository();
        assets.Items.Add(new CourseAsset
        {
            Id = 1,
            CourseId = course.Id,
            Course = course,
            OriginalFileName = "notes.pdf",
            StoredFileName = "stored.pdf",
            ContentType = "application/pdf",
            SizeBytes = 3,
            Type = CourseAssetType.Attachment,
            CreatedAtUtc = DateTime.UtcNow
        });
        var files = new FakeFileStorage();
        var service = CreateService(course, assets, files, enrolled: true);

        var listed = await service.GetByCourseIdAsync(course.Id, requesterId: 10, isAdmin: false);
        var opened = await service.OpenDownloadAsync(course.Id, 1, requesterId: 10, isAdmin: false);

        Assert.Single(listed);
        Assert.Equal("notes.pdf", listed[0].OriginalFileName);
        Assert.Equal("application/pdf", opened.ContentType);
        Assert.Equal(3, opened.Length);
        await opened.Content.DisposeAsync();
    }

    private static CourseAssetService CreateService(
        Course course,
        FakeAssetRepository assets,
        FakeFileStorage files,
        bool enrolled)
    {
        return new CourseAssetService(
            assets,
            new FakeCourseRepository(course),
            new FakeEnrollmentRepository(enrolled),
            files,
            Options.Create(new FileUploadOptions()));
    }

    private static string CreateTempDirectory()
    {
        var path = Path.Combine(Path.GetTempPath(), "course-assets-tests", Guid.NewGuid().ToString("N"));
        Directory.CreateDirectory(path);
        return path;
    }

    private sealed class TestHostEnvironment(string root) : IHostEnvironment
    {
        public string EnvironmentName { get; set; } = Environments.Development;
        public string ApplicationName { get; set; } = "CourseManagement.Tests";
        public string ContentRootPath { get; set; } = root;
        public IFileProvider ContentRootFileProvider { get; set; } = new NullFileProvider();
    }

    private sealed class FakeCourseRepository(Course course) : ICourseRepository
    {
        public Task<IEnumerable<Course>> GetAllAsync() => Task.FromResult<IEnumerable<Course>>([course]);
        public Task<CourseSearchResult> SearchAsync(CourseSearchCriteria criteria) =>
            Task.FromResult(new CourseSearchResult([course], 1));
        public Task<IReadOnlyList<CourseInstructorOption>> GetInstructorOptionsAsync() =>
            Task.FromResult<IReadOnlyList<CourseInstructorOption>>([]);
        public Task<Course?> GetByIdAsync(int id) => Task.FromResult(id == course.Id ? course : null);
        public Task<IEnumerable<Course>> GetByInstructorIdAsync(int instructorId) =>
            Task.FromResult<IEnumerable<Course>>(instructorId == course.InstructorId ? [course] : []);
        public Task<Course> AddAsync(Course value) => Task.FromResult(value);
        public Task UpdateAsync(Course value) => Task.CompletedTask;
        public bool WasDeleted { get; private set; }
        public Task DeleteAsync(int id)
        {
            WasDeleted = id == course.Id;
            return Task.CompletedTask;
        }
        public Task<bool> ExistsAsync(int id) => Task.FromResult(id == course.Id);
    }

    private sealed class FakeEnrollmentRepository(bool enrolled) : IEnrollmentRepository
    {
        public Task<IEnumerable<Enrollment>> GetAllAsync() => Task.FromResult<IEnumerable<Enrollment>>([]);
        public Task<Enrollment?> GetByIdAsync(int id) => Task.FromResult<Enrollment?>(null);
        public Task<IEnumerable<Enrollment>> GetByUserIdAsync(int userId) =>
            Task.FromResult<IEnumerable<Enrollment>>([]);
        public Task<IEnumerable<Enrollment>> GetByCourseIdAsync(int courseId) =>
            Task.FromResult<IEnumerable<Enrollment>>([]);
        public Task<Enrollment?> GetByUserAndCourseAsync(int userId, int courseId) =>
            Task.FromResult<Enrollment?>(null);
        public Task<Enrollment> AddAsync(Enrollment value) => Task.FromResult(value);
        public Task UpdateAsync(Enrollment value) => Task.CompletedTask;
        public Task DeleteAsync(int id) => Task.CompletedTask;
        public Task<bool> IsUserEnrolledAsync(int userId, int courseId) => Task.FromResult(enrolled);
    }

    private sealed class FakeAssetRepository : ICourseAssetRepository
    {
        public List<CourseAsset> Items { get; } = [];
        public Task<CourseAsset?> GetByIdAsync(int id, CancellationToken cancellationToken = default) =>
            Task.FromResult(Items.SingleOrDefault(item => item.Id == id));
        public Task<IReadOnlyList<CourseAsset>> GetByCourseIdAsync(int courseId, CancellationToken cancellationToken = default) =>
            Task.FromResult<IReadOnlyList<CourseAsset>>(Items.Where(item => item.CourseId == courseId).ToList());
        public Task<CourseAsset> AddAsync(CourseAsset asset, CancellationToken cancellationToken = default)
        {
            asset.Id = Items.Count == 0 ? 1 : Items.Max(item => item.Id) + 1;
            Items.Add(asset);
            return Task.FromResult(asset);
        }
        public Task DeleteAsync(CourseAsset asset, CancellationToken cancellationToken = default)
        {
            Items.Remove(asset);
            return Task.CompletedTask;
        }
        public Task SaveChangesAsync(CancellationToken cancellationToken = default) => Task.CompletedTask;
    }

    private sealed class FakeFileStorage : IFileStorage
    {
        public List<string> SavedNames { get; } = [];
        public List<string> DeletedNames { get; } = [];
        public Task<StoredFile> SaveAsync(Stream content, string extension, CancellationToken cancellationToken = default)
        {
            var name = $"stored-{Guid.NewGuid():N}{extension}";
            SavedNames.Add(name);
            return Task.FromResult(new StoredFile(name, Path.Combine(Path.GetTempPath(), name)));
        }
        public Task<Stream> OpenReadAsync(string storedFileName, CancellationToken cancellationToken = default) =>
            Task.FromResult<Stream>(new MemoryStream(new byte[] { 1, 2, 3 }));
        public Task DeleteAsync(string storedFileName, CancellationToken cancellationToken = default)
        {
            DeletedNames.Add(storedFileName);
            return Task.CompletedTask;
        }
    }
}
