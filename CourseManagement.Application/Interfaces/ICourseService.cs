using CourseManagement.Application.DTOs;

namespace CourseManagement.Application.Interfaces;

public interface ICourseService
{
    Task<IEnumerable<CourseResponseDto>> GetAllCoursesAsync();
    Task<CourseResponseDto?> GetCourseByIdAsync(int id);
    Task<IEnumerable<CourseResponseDto>> GetCoursesByInstructorAsync(int instructorId);
    Task<CourseResponseDto> CreateCourseAsync(CourseDto dto, int instructorId);
    Task<CourseResponseDto> UpdateCourseAsync(int id, CourseDto dto, int instructorId);
    Task<bool> DeleteCourseAsync(int id, int instructorId);
}