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
    public async Task<IActionResult> GetAll() =>
        Ok(await userService.GetAllUsersAsync());

    /// <summary>بياناتي أنا</summary>
    [HttpGet("me")]
    public async Task<IActionResult> GetMe() =>
        Ok(await userService.GetUserByIdAsync(User.GetUserId()));

    /// <summary>تحديث ملفي الشخصي (يستخدم UpdateUserDto الذي كان كوداً ميتاً)</summary>
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

    /// <summary>ترقية/تغيير دور مستخدم — Admin فقط (الطريقة الوحيدة لإنشاء مدرب)</summary>
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
