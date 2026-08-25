namespace CourseManagement.Application.Options;

public sealed class FileUploadOptions
{
    public string RootPath { get; set; } = "../CourseManagement.Uploads";
    public long MaxVideoBytes { get; set; } = 512L * 1024 * 1024;
    public long MaxAttachmentBytes { get; set; } = 50L * 1024 * 1024;
    public long MaxCoverImageBytes { get; set; } = 5L * 1024 * 1024;
    public string[] AllowedVideoExtensions { get; set; } = [".mp4", ".webm", ".mov", ".m4v"];
    public string[] AllowedAttachmentExtensions { get; set; } = [".pdf", ".doc", ".docx", ".ppt", ".pptx", ".xls", ".xlsx", ".zip", ".txt"];
    public string[] AllowedCoverImageExtensions { get; set; } = [".jpg", ".jpeg", ".png", ".webp"];

    public bool IsVideoExtension(string extension) =>
        AllowedVideoExtensions.Any(x => string.Equals(x, extension, StringComparison.OrdinalIgnoreCase));

    public bool IsAttachmentExtension(string extension) =>
        AllowedAttachmentExtensions.Any(x => string.Equals(x, extension, StringComparison.OrdinalIgnoreCase));

    public bool IsCoverImageExtension(string extension) =>
        AllowedCoverImageExtensions.Any(x => string.Equals(x, extension, StringComparison.OrdinalIgnoreCase));
}
