using CourseManagement.Application.DTOs;

namespace CourseManagement.Application.Interfaces;

public interface ICourseDiscoveryService
{
    Task EnrichSocialProofAsync(
        IEnumerable<CourseResponseDto> courses,
        CancellationToken cancellationToken = default);

    Task<IReadOnlyList<CourseResponseDto>> GetRelatedCoursesAsync(
        int courseId,
        int limit = 4,
        CancellationToken cancellationToken = default);
}
