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
            Title = dto.Title,
            Description = dto.Description,
            Price = dto.Price,
            InstructorId = instructorId
        };

        await courseRepository.AddAsync(course);
        return MapToResponseDto(course);
    }

    public async Task<CourseResponseDto> UpdateCourseAsync(int id, CourseDto dto, int instructorId)
    {
        var course = await courseRepository.GetByIdAsync(id);
        if (course == null || course.InstructorId != instructorId)
            throw new InvalidOperationException("Course not found or you are not the instructor.");

        course.Title = dto.Title;
        course.Description = dto.Description;
        course.Price = dto.Price;

        await courseRepository.UpdateAsync(course);
        return MapToResponseDto(course);
    }

    public async Task<bool> DeleteCourseAsync(int id, int instructorId)
    {
        var course = await courseRepository.GetByIdAsync(id);
        if (course == null || course.InstructorId != instructorId)
            return false;

        await courseRepository.DeleteAsync(id);
        return true;
    }

    private static CourseResponseDto MapToResponseDto(Course course) => new()
    {
        Id = course.Id,
        Title = course.Title,
        Description = course.Description,
        Price = course.Price,
        InstructorName = course.Instructor?.FullName ?? "Unknown"
    };
}