using CourseManagement.Domain.Entities;

namespace CourseManagement.Domain.Interfaces;

public interface ICourseAssetRepository
{
    Task<CourseAsset?> GetByIdAsync(int id, CancellationToken cancellationToken = default);
    Task<IReadOnlyList<CourseAsset>> GetByCourseIdAsync(int courseId, CancellationToken cancellationToken = default);
    Task<CourseAsset> AddAsync(CourseAsset asset, CancellationToken cancellationToken = default);
    Task DeleteAsync(CourseAsset asset, CancellationToken cancellationToken = default);
    Task SaveChangesAsync(CancellationToken cancellationToken = default);
}
