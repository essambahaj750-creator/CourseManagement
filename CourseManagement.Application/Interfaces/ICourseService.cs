using CourseManagement.Application.DTOs;
using CourseManagement.Domain.Models;

namespace CourseManagement.Application.Interfaces;

public interface ICourseService
{
    Task<IEnumerable<CourseResponseDto>> GetAllCoursesAsync();
    Task<CourseCatalogDto> SearchCoursesAsync(CourseFilterDto filter);
    Task<IReadOnlyList<InstructorOptionDto>> GetInstructorOptionsAsync();
    Task<CourseResponseDto?> GetCourseByIdAsync(int id);
    Task<IEnumerable<CourseResponseDto>> GetCoursesByInstructorAsync(int instructorId);
    Task<CourseResponseDto> CreateCourseAsync(CourseDto dto, int instructorId);
    Task<CourseResponseDto> UpdateCourseAsync(int id, CourseDto dto, int requesterId, bool isAdmin);
    Task DeleteCourseAsync(int id, int requesterId, bool isAdmin);
}
