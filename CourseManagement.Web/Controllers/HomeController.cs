using System.Security.Claims;
using CourseManagement.Web.Security;
using CourseManagement.Web.ViewModels;
using CourseManagement.Application.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace CourseManagement.Web.Controllers;

[Route("")]
public sealed class HomeController(
    ICourseService courseService,
    IEnrollmentService enrollmentService,
    IUserService userService,
    ICourseDiscoveryService discoveryService) : Controller
{
    [HttpGet("")]
    [AllowAnonymous]
    public async Task<IActionResult> Index()
    {
        var courses = (await courseService.GetAllCoursesAsync()).ToList();
        await discoveryService.EnrichSocialProofAsync(courses);
        foreach (var course in courses)
        {
            if (!string.IsNullOrWhiteSpace(course.ImageUrl))
                course.ImageUrl = Url.Action("Cover", "Courses", new { id = course.Id });
        }

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
    public IActionResult Error(int? statusCode = null, string? traceId = null)
    {
        Response.StatusCode = statusCode is >= 400 and <= 599 ? statusCode.Value : StatusCodes.Status500InternalServerError;
        return View(new ErrorViewModel
        {
            RequestId = string.IsNullOrWhiteSpace(traceId) ? HttpContext.TraceIdentifier : traceId
        });
    }

    private int GetUserId()
    {
        var value = User.FindFirstValue(ClaimTypes.NameIdentifier);
        return int.TryParse(value, out var id) ? id : 0;
    }
}
