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

            var stored = await storage.SaveAsync(new MemoryStream(bytes), ".pdf", long.MaxValue);

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
        var bytes = ValidMp4();

        var result = await service.UploadAsync(
            course.Id,
            "../lesson.mp4",
            bytes.Length,
            CourseAssetType.Video,
            new MemoryStream(bytes),
            requesterId: course.InstructorId,
            isAdmin: false);

        Assert.Equal("lesson.mp4", result.OriginalFileName);
        Assert.Equal(CourseAssetType.Video, result.Type);
        Assert.Equal("video/mp4", result.ContentType);
        Assert.Single(assets.Items);
        Assert.Single(files.SavedNames);
    }

    [Fact]
    public async Task Upload_RejectsBytesThatDoNotMatchExtension()
    {
        var course = new Course { Id = 7, InstructorId = 9, Title = "Testing" };
        var files = new FakeFileStorage();
        var service = CreateService(course, new FakeAssetRepository(), files, enrolled: false);

        var error = await Assert.ThrowsAsync<InvalidRequestException>(() => service.UploadAsync(
            course.Id,
            "lesson.mp4",
            16,
            CourseAssetType.Video,
            new MemoryStream(new byte[16]),
            requesterId: course.InstructorId,
            isAdmin: false));

        Assert.Contains("contents", error.Message, StringComparison.OrdinalIgnoreCase);
        Assert.Empty(files.SavedNames);
    }

    [Fact]
    public async Task UploadCover_StoresMetadataUpdatesCoursePathAndCanOpenImage()
    {
        var course = new Course { Id = 7, InstructorId = 9, Title = "Testing" };
        var assets = new FakeAssetRepository();
        var files = new FakeFileStorage();
        var service = CreateService(course, assets, files, enrolled: false);
        var bytes = ValidPng();

        await service.UploadCoverAsync(
            course.Id,
            "../cover.png",
            bytes.Length,
            new MemoryStream(bytes),
            requesterId: course.InstructorId,
            isAdmin: false);

        Assert.Equal("/api/course/7/cover", course.ImageUrl);
        var cover = Assert.Single(assets.Items);
        Assert.Equal(CourseAssetType.CoverImage, cover.Type);
        Assert.Equal("cover.png", cover.OriginalFileName);
        Assert.Equal("image/png", cover.ContentType);
        Assert.Single(files.SavedNames);

        var opened = await service.OpenCoverAsync(course.Id);
        Assert.NotNull(opened);
        Assert.Equal("cover.png", opened.DownloadName);
        await opened.Content.DisposeAsync();
    }

    [Fact]
    public async Task DeleteCover_RemovesMetadataClearsCoursePathAndDeletesFile()
    {
        var course = new Course { Id = 7, InstructorId = 9, Title = "Testing", ImageUrl = "/api/course/7/cover" };
        var assets = new FakeAssetRepository();
        assets.Items.Add(new CourseAsset
        {
            Id = 1,
            CourseId = course.Id,
            Course = course,
            OriginalFileName = "cover.png",
            StoredFileName = "stored.png",
            ContentType = "image/png",
            SizeBytes = 16,
            Type = CourseAssetType.CoverImage,
            CreatedAtUtc = DateTime.UtcNow
        });
        var files = new FakeFileStorage();
        var service = CreateService(course, assets, files, enrolled: false);

        await service.DeleteCoverAsync(course.Id, course.InstructorId, isAdmin: false);

        Assert.Null(course.ImageUrl);
        Assert.Empty(assets.Items);
        Assert.Contains("stored.png", files.DeletedNames);
    }

    [Fact]
    public async Task UploadCover_RejectsUnsupportedImageExtension()
    {
        var course = new Course { Id = 7, InstructorId = 9, Title = "Testing" };
        var files = new FakeFileStorage();
        var service = CreateService(course, new FakeAssetRepository(), files, enrolled: false);

        await Assert.ThrowsAsync<InvalidRequestException>(() => service.UploadCoverAsync(
            course.Id,
            "cover.gif",
            8,
            new MemoryStream(new byte[8]),
            requesterId: course.InstructorId,
            isAdmin: false));
        Assert.Empty(files.SavedNames);
    }

    [Theory]
    [InlineData("lesson.exe", 1)]
    [InlineData("notes.bat", 2)]
    public async Task Upload_RejectsUnsupportedExtension(string fileName, int typeValue)
    {
        var course = new Course { Id = 7, InstructorId = 9, Title = "Testing" };
        var files = new FakeFileStorage();
        var service = CreateService(course, new FakeAssetRepository(), files, enrolled: false);

        await Assert.ThrowsAsync<InvalidRequestException>(() => service.UploadAsync(
            course.Id,
            fileName,
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
    public async Task PublicCurriculum_ShowsLessonTitlesWithoutRequiringEnrollment()
    {
        var course = new Course { Id = 7, InstructorId = 9, Title = "Testing" };
        var assets = new FakeAssetRepository();
        assets.Items.AddRange(
        [
            new CourseAsset
            {
                Id = 1,
                CourseId = course.Id,
                Course = course,
                OriginalFileName = "01-introduction.mp4",
                StoredFileName = "lesson.mp4",
                ContentType = "video/mp4",
                SizeBytes = 10,
                Type = CourseAssetType.Video,
                CreatedAtUtc = DateTime.UtcNow.AddMinutes(-3)
            },
            new CourseAsset
            {
                Id = 2,
                CourseId = course.Id,
                Course = course,
                OriginalFileName = "private-notes.pdf",
                StoredFileName = "notes.pdf",
                ContentType = "application/pdf",
                SizeBytes = 10,
                Type = CourseAssetType.Attachment,
                CreatedAtUtc = DateTime.UtcNow.AddMinutes(-2)
            },
            new CourseAsset
            {
                Id = 3,
                CourseId = course.Id,
                Course = course,
                OriginalFileName = "02-next-step.mp4",
                StoredFileName = "lesson-2.mp4",
                ContentType = "video/mp4",
                SizeBytes = 10,
                Type = CourseAssetType.Video,
                CreatedAtUtc = DateTime.UtcNow.AddMinutes(-1)
            }
        ]);
        var service = CreateService(course, assets, new FakeFileStorage(), enrolled: false);

        var curriculum = await service.GetPublicCurriculumAsync(course.Id);

        Assert.Collection(
            curriculum,
            first =>
            {
                Assert.Equal(1, first.Position);
                Assert.Equal("01-introduction", first.Title);
            },
            second =>
            {
                Assert.Equal(2, second.Position);
                Assert.Equal("02-next-step", second.Title);
            });
        Assert.DoesNotContain(curriculum, item => item.Title.Contains("private-notes", StringComparison.Ordinal));
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
            new FakeUnitOfWork(),
            Options.Create(new FileUploadOptions()),
            NullLogger<CourseAssetService>.Instance);
    }

    private static byte[] ValidMp4() =>
        [0x00, 0x00, 0x00, 0x18, 0x66, 0x74, 0x79, 0x70, 0x69, 0x73, 0x6F, 0x6D, 0x00, 0x00, 0x00, 0x00];

    private static byte[] ValidPng() =>
        [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52];

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
        public Task<(IReadOnlyList<Enrollment> Items, int TotalCount)> GetPageAsync(
            int page,
            int pageSize,
            CancellationToken cancellationToken = default) =>
            Task.FromResult<(IReadOnlyList<Enrollment>, int)>(([], 0));
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
        public Task<StoredFile> SaveAsync(Stream content, string extension, long maxBytes, CancellationToken cancellationToken = default)
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

    private sealed class FakeUnitOfWork : IUnitOfWork
    {
        public Task<IUnitOfWorkTransaction> BeginTransactionAsync(CancellationToken cancellationToken = default) =>
            Task.FromResult<IUnitOfWorkTransaction>(new FakeTransaction());

        private sealed class FakeTransaction : IUnitOfWorkTransaction
        {
            public Task CommitAsync(CancellationToken cancellationToken = default) => Task.CompletedTask;
            public ValueTask DisposeAsync() => ValueTask.CompletedTask;
        }
    }
}
