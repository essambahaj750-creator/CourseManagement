using CourseManagement.Domain.Entities;
using CourseManagement.Domain.Interfaces;
using CourseManagement.Domain.Models;
using CourseManagement.Infrastructure.Data;
using Microsoft.EntityFrameworkCore;

namespace CourseManagement.Infrastructure.Repositories;

public class CourseRepository(ApplicationDbContext context) : ICourseRepository
{
    public async Task<IEnumerable<Course>> GetAllAsync() =>
        await context.Courses.AsNoTracking().Include(c => c.Instructor).ToListAsync();

    public async Task<CourseSearchResult> SearchAsync(CourseSearchCriteria criteria)
    {
        criteria = criteria.Normalize();

        var query = context.Courses
            .AsNoTracking()
            .Include(c => c.Instructor)
            .AsQueryable();

        if (!string.IsNullOrWhiteSpace(criteria.Query))
        {
            var term = criteria.Query.Trim();
            query = query.Where(c =>
                c.Title.Contains(term) ||
                c.Description.Contains(term) ||
                c.Instructor.FullName.Contains(term));
        }

        if (criteria.InstructorId.HasValue)
            query = query.Where(c => c.InstructorId == criteria.InstructorId.Value);

        if (criteria.MinPrice.HasValue)
            query = query.Where(c => c.Price >= criteria.MinPrice.Value);

        if (criteria.MaxPrice.HasValue)
            query = query.Where(c => c.Price <= criteria.MaxPrice.Value);

        query = criteria.SortBy switch
        {
            CourseSortBy.PriceLowToHigh => query.OrderBy(c => c.Price).ThenByDescending(c => c.Id),
            CourseSortBy.PriceHighToLow => query.OrderByDescending(c => c.Price).ThenByDescending(c => c.Id),
            CourseSortBy.Title => query.OrderBy(c => c.Title).ThenByDescending(c => c.Id),
            CourseSortBy.Newest => query.OrderByDescending(c => c.Id),
            _ => query.OrderByDescending(c => c.Id)
        };

        var totalCount = await query.CountAsync();
        var skip = (criteria.Page - 1) * criteria.PageSize;
        var items = await query.Skip(skip).Take(criteria.PageSize).ToListAsync();

        return new CourseSearchResult(items, totalCount);
    }

    public async Task<IReadOnlyList<CourseInstructorOption>> GetInstructorOptionsAsync()
    {
        var rawOptions = await context.Courses
            .AsNoTracking()
            .Select(c => new { c.InstructorId, Name = c.Instructor.FullName })
            .ToListAsync();

        return rawOptions
            .GroupBy(option => option.InstructorId)
            .Select(group => new CourseInstructorOption(group.Key, group.First().Name))
            .OrderBy(option => option.Name)
            .ToList();
    }

    public async Task<Course?> GetByIdAsync(int id) =>
        await context.Courses.AsNoTracking()
            .Include(c => c.Instructor)
            .FirstOrDefaultAsync(c => c.Id == id);

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
        // Queries return AsNoTracking entities, but Create + cover upload can share
        // one DbContext and still have the original Course in the local tracker.
        // Update that tracked instance when present; otherwise attach only Course.
        var tracked = context.Courses.Local.FirstOrDefault(item => item.Id == course.Id);
        if (tracked is not null)
            context.Entry(tracked).CurrentValues.SetValues(course);
        else
            context.Entry(course).State = EntityState.Modified;

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
