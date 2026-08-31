using CourseManagement.Application.DTOs;

namespace CourseManagement.Application.Interfaces;

public interface IUserService
{
    Task<IEnumerable<UserResponseDto>> GetAllUsersAsync();
    Task<PagedResultDto<UserResponseDto>> GetUsersPageAsync(
        int page,
        int pageSize,
        CancellationToken cancellationToken = default);
    Task<UserResponseDto> GetUserByIdAsync(int id);
    Task<UserResponseDto> UpdateProfileAsync(int userId, UpdateUserDto dto);
    Task<UserResponseDto> ChangeRoleAsync(int userId, string role, int requesterId);
    Task DeleteUserAsync(int userId, int requesterId);
}
