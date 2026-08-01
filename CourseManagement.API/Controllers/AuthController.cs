using CourseManagement.Application.DTOs;
using CourseManagement.Application.Interfaces;
using Microsoft.AspNetCore.Mvc;

namespace CourseManagement.API.Controllers;

[Route("api/[controller]")]
[ApiController]
public class AuthController(IAuthService authService) : ControllerBase
{
    /// <summary>تسجيل حساب جديد (Student دائماً)</summary>
    [HttpPost("register")]
    [ProducesResponseType(typeof(AuthResponseDto), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status409Conflict)]
    public async Task<IActionResult> Register([FromBody] RegisterDto dto) =>
        Ok(await authService.RegisterAsync(dto));

    /// <summary>تسجيل الدخول</summary>
    [HttpPost("login")]
    [ProducesResponseType(typeof(AuthResponseDto), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    public async Task<IActionResult> Login([FromBody] LoginDto dto) =>
        Ok(await authService.LoginAsync(dto));
}
