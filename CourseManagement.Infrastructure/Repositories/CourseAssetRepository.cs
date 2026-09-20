using CourseManagement.Domain.Entities;
using CourseManagement.Domain.Interfaces;
using CourseManagement.Infrastructure.Data;
using Microsoft.EntityFrameworkCore;

namespace CourseManagement.Infrastructure.Repositories;

public sealed class CourseAssetRepository(ApplicationDbContext context) : ICourseAssetRepository
{
    public Task<CourseAsset?> GetByIdAsync(int id, CancellationToken cancellationToken = default) =>
        context.CourseAssets
            .Include(asset => asset.Course)
            .ThenInclude(course => course.Instructor)
            .AsNoTracking()
            .SingleOrDefaultAsync(asset => asset.Id == id, cancellationToken);

    public async Task<IReadOnlyList<CourseAsset>> GetByCourseIdAsync(int courseId, CancellationToken cancellationToken = default) =>
        await context.CourseAssets
            .Where(asset => asset.CourseId == courseId)
            .OrderBy(asset => asset.Type)
            .ThenBy(asset => asset.CreatedAtUtc)
            .AsNoTracking()
            .ToListAsync(cancellationToken);

    public async Task<CourseAsset> AddAsync(CourseAsset asset, CancellationToken cancellationToken = default)
    {
        await context.CourseAssets.AddAsync(asset, cancellationToken);
        await context.SaveChangesAsync(cancellationToken);
        return asset;
    }

    public Task DeleteAsync(CourseAsset asset, CancellationToken cancellationToken = default)
    {
        context.CourseAssets.Remove(asset);
        return Task.CompletedTask;
    }

    public Task SaveChangesAsync(CancellationToken cancellationToken = default) =>
        context.SaveChangesAsync(cancellationToken);
}
