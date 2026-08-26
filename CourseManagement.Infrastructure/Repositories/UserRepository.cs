using CourseManagement.Domain.Entities;
using CourseManagement.Domain.Interfaces;
using CourseManagement.Infrastructure.Data;
using Microsoft.EntityFrameworkCore;

namespace CourseManagement.Infrastructure.Repositories;

public class UserRepository(ApplicationDbContext context) : IUserRepository
{
    public async Task<IEnumerable<User>> GetAllAsync() =>
        await context.Users.AsNoTracking().ToListAsync();

    public async Task<User?> GetByIdAsync(int id) =>
        await context.Users.AsNoTracking().FirstOrDefaultAsync(u => u.Id == id);

    public async Task<User?> GetByEmailAsync(string email)
    {
        var normalized = User.NormalizeEmail(email);
        return await context.Users.AsNoTracking()
            .FirstOrDefaultAsync(u => u.Email == normalized);
    }

    public async Task<User> AddAsync(User user)
    {
        context.Users.Add(user);
        await context.SaveChangesAsync();
        return user;
    }

    public async Task UpdateAsync(User user)
    {
        context.Users.Update(user);
        await context.SaveChangesAsync();
    }

    public async Task DeleteAsync(int id)
    {
        var user = await context.Users.FindAsync(id);
        if (user != null)
        {
            context.Users.Remove(user);
            await context.SaveChangesAsync();
        }
    }

    public async Task<bool> ExistsAsync(string email)
    {
        var normalized = User.NormalizeEmail(email);
        return await context.Users.AnyAsync(u => u.Email == normalized);
    }
}