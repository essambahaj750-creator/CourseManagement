using CourseManagement.API.Extensions;
using CourseManagement.Application.DTOs;
using CourseManagement.Application.Interfaces;
using CourseManagement.Domain.Enums;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace CourseManagement.API.Controllers;

[ApiController]
[Route("api/course/{courseId:int}/assets")]
[Authorize]
public sealed class CourseAssetsController(ICourseAssetService assetService) : ControllerBase
{
    [HttpGet]
    public async Task<ActionResult<IReadOnlyList<CourseAssetDto>>> GetByCourse(
        int courseId,
        CancellationToken cancellationToken)
    {
        var assets = await assetService.GetByCourseIdAsync(
            courseId,
            User.GetUserId(),
            User.IsAdmin(),
            cancellationToken);
        return Ok(assets);
    }

    [HttpPost]
    [Authorize(Roles = "Instructor,Admin")]
    [Consumes("multipart/form-data")]
    public async Task<ActionResult<CourseAssetDto>> Upload(
        int courseId,
        IFormFile? file,
        [FromForm] CourseAssetType? type,
        CancellationToken cancellationToken)
    {
        if (file is null)
            return BadRequest(new { message = "A file is required." });

        var assetType = type ?? InferType(file);
        await using var content = file.OpenReadStream();
        var asset = await assetService.UploadAsync(
            courseId,
            file.FileName,
            file.Length,
            assetType,
            content,
            User.GetUserId(),
            User.IsAdmin(),
            cancellationToken);

        return CreatedAtAction(nameof(GetByCourse), new { courseId }, asset);
    }

    [HttpGet("{assetId:int}/download")]
    public async Task<IActionResult> Download(
        int courseId,
        int assetId,
        CancellationToken cancellationToken)
    {
        var download = await assetService.OpenDownloadAsync(
            courseId,
            assetId,
            User.GetUserId(),
            User.IsAdmin(),
            cancellationToken);
        return File(download.Content, download.ContentType, download.DownloadName, enableRangeProcessing: true);
    }

    [HttpDelete("{assetId:int}")]
    [Authorize(Roles = "Instructor,Admin")]
    public async Task<IActionResult> Delete(
        int courseId,
        int assetId,
        CancellationToken cancellationToken)
    {
        await assetService.DeleteAsync(
            courseId,
            assetId,
            User.GetUserId(),
            User.IsAdmin(),
            cancellationToken);
        return NoContent();
    }

    private static CourseAssetType InferType(IFormFile file) =>
        file.ContentType.StartsWith("video/", StringComparison.OrdinalIgnoreCase)
            ? CourseAssetType.Video
            : CourseAssetType.Attachment;
}
