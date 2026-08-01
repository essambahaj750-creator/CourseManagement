using CourseManagement.Domain.Entities;
using CourseManagement.Domain.Interfaces;
using CourseManagement.Infrastructure.Data;
using Microsoft.EntityFrameworkCore;

namespace CourseManagement.Infrastructure.Repositories;

public class EnrollmentRepository(ApplicationDbContext context) : IEnrollmentRepository
{
    public async Task<IEnumerable<Enrollment>> GetAllAsync() =>
        await context.Enrollments.AsNoTracking()
            .Include(e => e.User)
            .Include(e => e.Course)
            .ToListAsync();

    public async Task<Enrollment?> GetByIdAsync(int id) =>
        await context.Enrollments
            .Include(e => e.User)
            .Include(e => e.Course)
            .FirstOrDefaultAsync(e => e.Id == id);

    // كانت تنقصها Include(User) فيظهر اسم الطالب فارغاً في النتائج
    public async Task<IEnumerable<Enrollment>> GetByUserIdAsync(int userId) =>
        await context.Enrollments.AsNoTracking()
            .Include(e => e.User)
            .Include(e => e.Course)
            .Where(e => e.UserId == userId)
            .ToListAsync();

    // كانت تنقصها Include(Course) فيظهر عنوان الكورس فارغاً في النتائج
    public async Task<IEnumerable<Enrollment>> GetByCourseIdAsync(int courseId) =>
        await context.Enrollments.AsNoTracking()
            .Include(e => e.User)
            .Include(e => e.Course)
            .Where(e => e.CourseId == courseId)
            .ToListAsync();

    public async Task<Enrollment?> GetByUserAndCourseAsync(int userId, int courseId) =>
        await context.Enrollments.FirstOrDefaultAsync(e => e.UserId == userId && e.CourseId == courseId);

    public async Task<Enrollment> AddAsync(Enrollment enrollment)
    {
        context.Enrollments.Add(enrollment);
        await context.SaveChangesAsync();
        return enrollment;
    }

    public async Task UpdateAsync(Enrollment enrollment)
    {
        context.Enrollments.Update(enrollment);
        await context.SaveChangesAsync();
    }

    public async Task DeleteAsync(int id)
    {
        var enrollment = await context.Enrollments.FindAsync(id);
        if (enrollment != null)
        {
            context.Enrollments.Remove(enrollment);
            await context.SaveChangesAsync();
        }
    }

    public async Task<bool> IsUserEnrolledAsync(int userId, int courseId) =>
        await context.Enrollments.AnyAsync(e => e.UserId == userId && e.CourseId == courseId);
}
