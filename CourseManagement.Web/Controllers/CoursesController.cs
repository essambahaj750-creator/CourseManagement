using System.Security.Claims;
using CourseManagement.Web.Security;
using CourseManagement.Web.ViewModels;
using CourseManagement.Application.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace CourseManagement.Web.Controllers;

[Route("Courses")]
public sealed class CoursesController(ICourseService courseService) : Controller
{
    [HttpGet("")]
    [AllowAnonymous]
    public async Task<IActionResult> Index([FromQuery] CourseFilterViewModel filter)
    {
        var catalog = await courseService.SearchCoursesAsync(filter.ToDto());
        var instructors = await courseService.GetInstructorOptionsAsync();

        filter.Page = catalog.Page;
        filter.PageSize = catalog.PageSize;

        return View(new CoursesIndexViewModel
        {
            Courses = catalog.Items,
            Instructors = instructors,
            Filters = filter,
            TotalCount = catalog.TotalCount,
            TotalPages = catalog.TotalPages
        });
    }

    [HttpGet("Details/{id:int}")]
    [AllowAnonymous]
    public async Task<IActionResult> Details(int id)
    {
        var course = await courseService.GetCourseByIdAsync(id);
        return course is null ? NotFound() : View(course);
    }

    [HttpGet("Create")]
    [Authorize(Roles = "Instructor,Admin", AuthenticationSchemes = MvcAuthenticationDefaults.Scheme)]
    public IActionResult Create() => View(new CourseFormViewModel());

    [HttpPost("Create")]
    [Authorize(Roles = "Instructor,Admin", AuthenticationSchemes = MvcAuthenticationDefaults.Scheme)]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> Create(CourseFormViewModel model)
    {
        if (!ModelState.IsValid) return View(model);

        try
        {
            var course = await courseService.CreateCourseAsync(model.ToDto(), GetUserId());
            TempData["Success"] = "تم إنشاء الكورس بنجاح.";
            return RedirectToAction(nameof(Details), new { id = course.Id });
        }
        catch (Exception ex)
        {
            ModelState.AddModelError(string.Empty, ex.Message);
            return View(model);
        }
    }

    [HttpGet("Edit/{id:int}")]
    [Authorize(Roles = "Instructor,Admin", AuthenticationSchemes = MvcAuthenticationDefaults.Scheme)]
    public async Task<IActionResult> Edit(int id)
    {
        var course = await courseService.GetCourseByIdAsync(id);
        if (course is null) return NotFound();
        if (!CanManage(course.InstructorId)) return Forbid();

        return View(new CourseFormViewModel
        {
            Id = course.Id,
            Title = course.Title,
            Description = course.Description,
            Price = course.Price,
            ImageUrl = course.ImageUrl
        });
    }

    [HttpPost("Edit/{id:int}")]
    [Authorize(Roles = "Instructor,Admin", AuthenticationSchemes = MvcAuthenticationDefaults.Scheme)]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> Edit(int id, CourseFormViewModel model)
    {
        if (id != model.Id) return BadRequest();
        if (!ModelState.IsValid) return View(model);

        try
        {
            var course = await courseService.UpdateCourseAsync(id, model.ToDto(), GetUserId(), User.IsInRole("Admin"));
            TempData["Success"] = "تم تحديث الكورس بنجاح.";
            return RedirectToAction(nameof(Details), new { id = course.Id });
        }
        catch (Exception ex)
        {
            ModelState.AddModelError(string.Empty, ex.Message);
            return View(model);
        }
    }

    [HttpGet("Delete/{id:int}")]
    [Authorize(Roles = "Instructor,Admin", AuthenticationSchemes = MvcAuthenticationDefaults.Scheme)]
    public async Task<IActionResult> Delete(int id)
    {
        var course = await courseService.GetCourseByIdAsync(id);
        if (course is null) return NotFound();
        if (!CanManage(course.InstructorId)) return Forbid();
        return View(course);
    }

    [HttpPost("Delete/{id:int}")]
    [Authorize(Roles = "Instructor,Admin", AuthenticationSchemes = MvcAuthenticationDefaults.Scheme)]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> DeleteConfirmed(int id)
    {
        try
        {
            await courseService.DeleteCourseAsync(id, GetUserId(), User.IsInRole("Admin"));
            TempData["Success"] = "تم حذف الكورس بنجاح.";
            return RedirectToAction(nameof(Index));
        }
        catch (Exception ex)
        {
            TempData["Error"] = ex.Message;
            return RedirectToAction(nameof(Details), new { id });
        }
    }

    private int GetUserId()
        => int.TryParse(User.FindFirstValue(ClaimTypes.NameIdentifier), out var id) ? id : 0;

    private bool CanManage(int instructorId) => User.IsInRole("Admin") || instructorId == GetUserId();
}
