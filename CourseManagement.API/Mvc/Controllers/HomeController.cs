using System.Security.Claims;
using CourseManagement.API.Mvc.Security;
using CourseManagement.API.Mvc.ViewModels;
using CourseManagement.Application.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace CourseManagement.API.Mvc.Controllers;

[Route("")]
public sealed class HomeController(
    ICourseService courseService,
    IEnrollmentService enrollmentService,
    IUserService userService) : Controller
{
    [HttpGet("")]
    [AllowAnonymous]
    public async Task<IActionResult> Index()
    {
        var courses = (await courseService.GetAllCoursesAsync()).ToList();
        var isAuthenticated = User.Identity?.IsAuthenticated == true;
        var role = User.FindFirstValue(ClaimTypes.Role) ?? string.Empty;
        var myEnrollments = new List<CourseManagement.Application.DTOs.EnrollmentDto>();
        var usersCount = 0;
        var enrollmentsCount = 0;

        if (isAuthenticated)
        {
            var userId = GetUserId();
            myEnrollments = (await enrollmentService.GetEnrollmentsByUserAsync(userId)).ToList();
        }

        if (role == "Admin")
        {
            usersCount = (await userService.GetAllUsersAsync()).Count();
            enrollmentsCount = (await enrollmentService.GetAllEnrollmentsAsync()).Count();
        }

        return View(new DashboardViewModel
        {
            Courses = courses,
            MyEnrollments = myEnrollments,
            UsersCount = usersCount,
            EnrollmentsCount = enrollmentsCount,
            IsAuthenticated = isAuthenticated,
            Role = role
        });
    }

    [Route("Error")]
    [AllowAnonymous]
    public IActionResult Error() => View(new ErrorViewModel { RequestId = HttpContext.TraceIdentifier });

    private int GetUserId()
    {
        var value = User.FindFirstValue(ClaimTypes.NameIdentifier);
        return int.TryParse(value, out var id) ? id : 0;
    }
}
