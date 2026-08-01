using CourseManagement.Application.Common;
using CourseManagement.Application.DTOs;
using CourseManagement.Application.Interfaces;
using CourseManagement.Domain.Entities;
using CourseManagement.Domain.Interfaces;

namespace CourseManagement.Infrastructure.Services;

public class CourseService(ICourseRepository courseRepository) : ICourseService
{
    public async Task<IEnumerable<CourseResponseDto>> GetAllCoursesAsync()
    {
        var courses = await courseRepository.GetAllAsync();
        return courses.Select(MapToResponseDto);
    }

    public async Task<CourseResponseDto?> GetCourseByIdAsync(int id)
    {
        var course = await courseRepository.GetByIdAsync(id);
        return course == null ? null : MapToResponseDto(course);
    }

    public async Task<IEnumerable<CourseResponseDto>> GetCoursesByInstructorAsync(int instructorId)
    {
        var courses = await courseRepository.GetByInstructorIdAsync(instructorId);
        return courses.Select(MapToResponseDto);
    }

    public async Task<CourseResponseDto> CreateCourseAsync(CourseDto dto, int instructorId)
    {
        var course = new Course
        {
            Title = dto.Title.Trim(),
            Description = dto.Description.Trim(),
            Price = dto.Price,
            InstructorId = instructorId
        };

        await courseRepository.AddAsync(course);

        // إعادة الجلب بعد الحفظ حتى تُحمَّل بيانات المدرب (كانت تظهر "Unknown" سابقاً)
        var created = await courseRepository.GetByIdAsync(course.Id);
        return MapToResponseDto(created ?? course);
    }

    public async Task<CourseResponseDto> UpdateCourseAsync(int id, CourseDto dto, int requesterId, bool isAdmin)
    {
        var course = await courseRepository.GetByIdAsync(id)
            ?? throw new KeyNotFoundException("Course not found.");

        // الـ Admin يتجاوز شرط الملكية؛ المدرب يعدل كورساته فقط
        if (!isAdmin && course.InstructorId != requesterId)
            throw new ForbiddenAccessException("You can only modify your own courses.");

        course.Title = dto.Title.Trim();
        course.Description = dto.Description.Trim();
        course.Price = dto.Price;

        await courseRepository.UpdateAsync(course);
        return MapToResponseDto(course);
    }

    public async Task DeleteCourseAsync(int id, int requesterId, bool isAdmin)
    {
        var course = await courseRepository.GetByIdAsync(id)
            ?? throw new KeyNotFoundException("Course not found.");

        if (!isAdmin && course.InstructorId != requesterId)
            throw new ForbiddenAccessException("You can only delete your own courses.");

        await courseRepository.DeleteAsync(id);
    }

    private static CourseResponseDto MapToResponseDto(Course course) => new()
    {
        Id = course.Id,
        Title = course.Title,
        Description = course.Description,
        Price = course.Price,
        InstructorId = course.InstructorId,
        InstructorName = course.Instructor?.FullName ?? string.Empty
    };
}
