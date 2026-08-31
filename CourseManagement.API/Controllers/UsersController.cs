using CourseManagement.API.Extensions;
using CourseManagement.Application.DTOs;
using CourseManagement.Application.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace CourseManagement.API.Controllers;

[Route("api/[controller]")]
[ApiController]
[Authorize]
public class UsersController(IUserService userService, IAuthService authService) : ControllerBase
{
    [HttpGet]
    [Authorize(Roles = "Admin")]
    public async Task<IActionResult> GetAll(
        [FromQuery] int page = 1,
        [FromQuery] int pageSize = 50,
        CancellationToken cancellationToken = default) =>
        Ok(await userService.GetUsersPageAsync(page, pageSize, cancellationToken));

    [HttpGet("me")]
    public async Task<IActionResult> GetMe() =>
        Ok(await userService.GetUserByIdAsync(User.GetUserId()));

    [HttpPut("me")]
    public async Task<IActionResult> UpdateMe([FromBody] UpdateUserDto dto) =>
        Ok(await userService.UpdateProfileAsync(User.GetUserId(), dto));

    [HttpPut("me/password")]
    public async Task<IActionResult> ChangePassword([FromBody] ChangePasswordDto dto)
    {
        await authService.ChangePasswordAsync(User.GetUserId(), dto);
        return NoContent();
    }

    [HttpGet("{id:int}")]
    public async Task<IActionResult> GetById(int id)
    {
        if (!User.IsAdmin() && id != User.GetUserId())
            return Forbid();

        return Ok(await userService.GetUserByIdAsync(id));
    }

    [HttpPut("{id:int}/role")]
    [Authorize(Roles = "Admin")]
    public async Task<IActionResult> ChangeRole(int id, [FromBody] ChangeRoleDto dto) =>
        Ok(await userService.ChangeRoleAsync(id, dto.Role, User.GetUserId()));

    [HttpDelete("{id:int}")]
    [Authorize(Roles = "Admin")]
    public async Task<IActionResult> Delete(int id)
    {
        await userService.DeleteUserAsync(id, User.GetUserId());
        return NoContent();
    }
}
