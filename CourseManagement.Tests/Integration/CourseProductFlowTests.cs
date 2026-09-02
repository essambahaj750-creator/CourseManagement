using CourseManagement.Application.Interfaces;
using CourseManagement.Application.Options;
using CourseManagement.Domain.Entities;
using CourseManagement.Domain.Enums;
using CourseManagement.Domain.Interfaces;
using CourseManagement.Domain.Models;
using CourseManagement.Infrastructure.Services;
using Microsoft.Extensions.Logging.Abstractions;
using Microsoft.Extensions.Options;
using Xunit;

namespace CourseManagement.Tests.Integration;

public sealed class CourseProductFlowTests
{
    [Fact]
    public async Task AdminCanReassignCourseToRealInstructor()
    {
        var admin = new User { Id = 1, FullName = "Administrator" };
        var instructor = new User { Id = 9, FullName = "Real Instructor" };
        var course = new Course
        {
            Id = 7,
            Title = "Networks",
            Description = "Old description",
            Price = 20,
            InstructorId = admin.Id,
            Instructor = admin
        };
        var repository = new FakeCourseRepository(course, instructor);
        var service = new CourseService(
            repository,
            new FakeAssetRepository(),
            new FakeFileStorage(),
            NullLogger<CourseService>.Instance);

        var result = await service.UpdateCourseAsync(
            course.Id,
            new CourseManagement.Application.DTOs.CourseDto
            {
                Title = "Networks",
                Description = "Updated description",
                Price = 20
            },
            requesterId: admin.Id,
            isAdmin: true,
            instructorId: instructor.Id);

        Assert.Equal(instructor.Id, course.InstructorId);
        Assert.Equal("Real Instructor", result.InstructorName);
        Assert.Equal(instructor.Id, result.InstructorId);
    }

    [Fact]
    public async Task FirstVideoIsAvailableAsPreviewWithoutEnrollment()
    {
        var course = new Course { Id = 7, InstructorId = 9, Title = "Testing" };
        var assets = new FakeAssetRepository();
        assets.Items.Add(new CourseAsset
        {
            Id = 2,
            CourseId = course.Id,
            Course = course,
            OriginalFileName = "second.mp4",
            StoredFileName = "second.mp4",
            ContentType = "video/mp4",
            SizeBytes = 22,
            Type = CourseAssetType.Video,
            CreatedAtUtc = new DateTime(2026, 1, 2, 0, 0, 0, DateTimeKind.Utc)
        });
        assets.Items.Add(new CourseAsset
        {
            Id = 1,
            CourseId = course.Id,
            Course = course,
            OriginalFileName = "preview.mp4",
            StoredFileName = "preview.mp4",
            ContentType = "video/mp4",
            SizeBytes = 11,
            Type = CourseAssetType.Video,
            CreatedAtUtc = new DateTime(2026, 1, 1, 0, 0, 0, DateTimeKind.Utc)
        });
        assets.Items.Add(new CourseAsset
        {
            Id = 3,
            CourseId = course.Id,
            Course = course,
            OriginalFileName = "notes.pdf",
            StoredFileName = "notes.pdf",
            ContentType = "application/pdf",
            SizeBytes = 3,
            Type = CourseAssetType.Attachment,
            CreatedAtUtc = DateTime.UtcNow
        });

        var service = new CourseAssetService(
            assets,
            new FakeCourseRepository(course),
            new FakeEnrollmentRepository(),
            new FakeFileStorage(),
            new FakeUnitOfWork(),
            Options.Create(new FileUploadOptions()),
            NullLogger<CourseAssetService>.Instance);

        var metadata = await service.GetPreviewAsync(course.Id);
        var stream = await service.OpenPreviewAsync(course.Id);

        Assert.NotNull(metadata);
        Assert.Equal(1, metadata.Id);
        Assert.Equal("preview.mp4", metadata.OriginalFileName);
        Assert.NotNull(stream);
        Assert.Equal("video/mp4", stream.ContentType);
        Assert.Equal("preview.mp4", stream.DownloadName);
        await stream.Content.DisposeAsync();
    }

    private sealed class FakeCourseRepository(Course course, User? instructor = null) : ICourseRepository
    {
        public Task<IEnumerable<Course>> GetAllAsync() => Task.FromResult<IEnumerable<Course>>([course]);
        public Task<CourseSearchResult> SearchAsync(CourseSearchCriteria criteria) =>
            Task.FromResult(new CourseSearchResult([course], 1));
        public Task<IReadOnlyList<CourseInstructorOption>> GetInstructorOptionsAsync() =>
            Task.FromResult<IReadOnlyList<CourseInstructorOption>>([]);
        public Task<Course?> GetByIdAsync(int id)
        {
            if (id != course.Id) return Task.FromResult<Course?>(null);
            if (instructor is not null && course.InstructorId == instructor.Id)
                course.Instructor = instructor;
            return Task.FromResult<Course?>(course);
        }
        public Task<IEnumerable<Course>> GetByInstructorIdAsync(int instructorId) =>
            Task.FromResult<IEnumerable<Course>>(course.InstructorId == instructorId ? [course] : []);
        public Task<Course> AddAsync(Course value) => Task.FromResult(value);
        public Task UpdateAsync(Course value)
        {
            if (instructor is not null && value.InstructorId == instructor.Id)
                value.Instructor = instructor;
            return Task.CompletedTask;
        }
        public Task DeleteAsync(int id) => Task.CompletedTask;
        public Task<bool> ExistsAsync(int id) => Task.FromResult(id == course.Id);
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

    private sealed class FakeEnrollmentRepository : IEnrollmentRepository
    {
        public Task<IEnumerable<Enrollment>> GetAllAsync() => Task.FromResult<IEnumerable<Enrollment>>([]);
        public Task<(IReadOnlyList<Enrollment> Items, int TotalCount)> GetPageAsync(int page, int pageSize, CancellationToken cancellationToken = default) =>
            Task.FromResult<(IReadOnlyList<Enrollment>, int)>(([], 0));
        public Task<Enrollment?> GetByIdAsync(int id) => Task.FromResult<Enrollment?>(null);
        public Task<IEnumerable<Enrollment>> GetByUserIdAsync(int userId) => Task.FromResult<IEnumerable<Enrollment>>([]);
        public Task<IEnumerable<Enrollment>> GetByCourseIdAsync(int courseId) => Task.FromResult<IEnumerable<Enrollment>>([]);
        public Task<Enrollment?> GetByUserAndCourseAsync(int userId, int courseId) => Task.FromResult<Enrollment?>(null);
        public Task<Enrollment> AddAsync(Enrollment value) => Task.FromResult(value);
        public Task UpdateAsync(Enrollment value) => Task.CompletedTask;
        public Task DeleteAsync(int id) => Task.CompletedTask;
        public Task<bool> IsUserEnrolledAsync(int userId, int courseId) => Task.FromResult(false);
    }

    private sealed class FakeFileStorage : IFileStorage
    {
        public Task<StoredFile> SaveAsync(Stream content, string extension, long maxBytes, CancellationToken cancellationToken = default) =>
            Task.FromResult(new StoredFile($"stored{extension}", Path.Combine(Path.GetTempPath(), $"stored{extension}")));
        public Task<Stream> OpenReadAsync(string storedFileName, CancellationToken cancellationToken = default) =>
            Task.FromResult<Stream>(new MemoryStream([1, 2, 3]));
        public Task DeleteAsync(string storedFileName, CancellationToken cancellationToken = default) => Task.CompletedTask;
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
