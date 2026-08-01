using CourseManagement.Domain.Entities;
using CourseManagement.Domain.Interfaces;
using CourseManagement.Infrastructure.Data;
using Microsoft.EntityFrameworkCore;

namespace CourseManagement.Infrastructure.Repositories;

public class CourseRepository(ApplicationDbContext context) : ICourseRepository
{
    public async Task<IEnumerable<Course>> GetAllAsync() =>
        await context.Courses.AsNoTracking().Include(c => c.Instructor).ToListAsync();

    public async Task<Course?> GetByIdAsync(int id) =>
        await context.Courses.Include(c => c.Instructor).FirstOrDefaultAsync(c => c.Id == id);

    // كان ينقصها Include(Instructor) فتظهر أسماء المدربين فارغة في النتائج
    public async Task<IEnumerable<Course>> GetByInstructorIdAsync(int instructorId) =>
        await context.Courses.AsNoTracking()
            .Include(c => c.Instructor)
            .Where(c => c.InstructorId == instructorId)
            .ToListAsync();

    public async Task<Course> AddAsync(Course course)
    {
        context.Courses.Add(course);
        await context.SaveChangesAsync();
        return course;
    }

    public async Task UpdateAsync(Course course)
    {
        context.Courses.Update(course);
        await context.SaveChangesAsync();
    }

    public async Task DeleteAsync(int id)
    {
        var course = await context.Courses.FindAsync(id);
        if (course != null)
        {
            context.Courses.Remove(course);
            await context.SaveChangesAsync();
        }
    }

    public async Task<bool> ExistsAsync(int id) =>
        await context.Courses.AnyAsync(c => c.Id == id);
}
