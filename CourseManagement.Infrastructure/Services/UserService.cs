using CourseManagement.Application.DTOs;
using CourseManagement.Application.Interfaces;
using CourseManagement.Domain.Entities;
using CourseManagement.Domain.Enums;
using CourseManagement.Domain.Interfaces;

namespace CourseManagement.Infrastructure.Services;

public class UserService(
    IUserRepository userRepository,
    ICourseRepository courseRepository) : IUserService
{
    public async Task<IEnumerable<UserResponseDto>> GetAllUsersAsync()
    {
        var users = await userRepository.GetAllAsync();
        return users.Select(MapToDto);
    }

    public async Task<UserResponseDto> GetUserByIdAsync(int id)
    {
        var user = await userRepository.GetByIdAsync(id)
            ?? throw new KeyNotFoundException("User not found.");
        return MapToDto(user);
    }

    public async Task<UserResponseDto> UpdateProfileAsync(int userId, UpdateUserDto dto)
    {
        var user = await userRepository.GetByIdAsync(userId)
            ?? throw new KeyNotFoundException("User not found.");

        var newEmail = User.NormalizeEmail(dto.Email);
        var emailChanged = !string.Equals(user.Email, newEmail, StringComparison.OrdinalIgnoreCase);

        if (emailChanged && await userRepository.ExistsAsync(newEmail))
            throw new InvalidOperationException("Email is already in use by another account.");

        user.FullName = dto.FullName.Trim();
        user.Email = newEmail;
        if (emailChanged)
            user.SecurityStamp = Guid.NewGuid();

        await userRepository.UpdateAsync(user);
        return MapToDto(user);
    }

    public async Task<UserResponseDto> ChangeRoleAsync(int userId, string role, int requesterId)
    {
        // منع الـ Admin من تغيير دوره بنفسه (حماية من فقدان آخر Admin في النظام)
        if (userId == requesterId)
            throw new InvalidOperationException("You cannot change your own role.");

        if (!Enum.TryParse<Role>(role, true, out var newRole))
            throw new InvalidOperationException(
                $"Invalid role '{role}'. Valid roles: {string.Join(", ", Enum.GetNames<Role>())}.");

        var user = await userRepository.GetByIdAsync(userId)
            ?? throw new KeyNotFoundException("User not found.");

        // لا يمكن تنزيل مدرب إلى Student وهو ما زال يملك كورسات
        if (newRole == Role.Student)
        {
            var courses = await courseRepository.GetByInstructorIdAsync(userId);
            if (courses.Any())
                throw new InvalidOperationException(
                    "Cannot demote a user who is instructor of existing courses. Reassign or delete their courses first.");
        }

        user.Role = newRole;
        user.SecurityStamp = Guid.NewGuid();
        await userRepository.UpdateAsync(user);
        return MapToDto(user);
    }

    public async Task DeleteUserAsync(int userId, int requesterId)
    {
        if (userId == requesterId)
            throw new InvalidOperationException("You cannot delete your own account.");

        var user = await userRepository.GetByIdAsync(userId)
            ?? throw new KeyNotFoundException("User not found.");

        // حذف مدرب يملك كورسات سيفشل على قيد FK (Restrict) — نعطي رسالة واضحة بدلاً من خطأ SQL
        var courses = await courseRepository.GetByInstructorIdAsync(userId);
        if (courses.Any())
            throw new InvalidOperationException(
                "Cannot delete a user who is instructor of existing courses. Reassign or delete their courses first.");

        await userRepository.DeleteAsync(userId);
    }

    private static UserResponseDto MapToDto(User user) => new()
    {
        Id = user.Id,
        FullName = user.FullName,
        Email = user.Email,
        Role = user.Role.ToString()
    };
}
