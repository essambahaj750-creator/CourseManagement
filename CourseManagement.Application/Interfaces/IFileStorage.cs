namespace CourseManagement.Application.Interfaces;

public sealed record StoredFile(string StoredFileName, string AbsolutePath);

public interface IFileStorage
{
    Task<StoredFile> SaveAsync(Stream content, string extension, CancellationToken cancellationToken = default);
    Task<Stream> OpenReadAsync(string storedFileName, CancellationToken cancellationToken = default);
    Task DeleteAsync(string storedFileName, CancellationToken cancellationToken = default);
}
