using CourseManagement.Domain.Entities;
using CourseManagement.Domain.Models;

namespace CourseManagement.Domain.Interfaces;

public interface ICourseRepository
{
    Task<IEnumerable<Course>> GetAllAsync();
    Task<CourseSearchResult> SearchAsync(CourseSearchCriteria criteria);
    Task<IReadOnlyList<CourseInstructorOption>> GetInstructorOptionsAsync();
    Task<Course?> GetByIdAsync(int id);
    Task<IEnumerable<Course>> GetByInstructorIdAsync(int instructorId);
    Task<Course> AddAsync(Course course);
    Task UpdateAsync(Course course);
    Task DeleteAsync(int id);
    Task<bool> ExistsAsync(int id);
}