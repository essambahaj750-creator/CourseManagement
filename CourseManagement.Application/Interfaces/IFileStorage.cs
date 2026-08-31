namespace CourseManagement.Application.Interfaces;

public sealed record StoredFile(string StoredFileName, string AbsolutePath);

public interface IFileStorage
{
    /// <summary>
    /// Streams <paramref name="content"/> to storage, refusing to write more than
    /// <paramref name="maxBytes"/>. The ceiling is enforced while copying rather than
    /// from a caller-supplied length, so a stream that understates its size cannot
    /// fill the disk. Throws <see cref="Common.InvalidRequestException"/> when exceeded,
    /// leaving nothing behind.
    /// </summary>
    Task<StoredFile> SaveAsync(Stream content, string extension, long maxBytes, CancellationToken cancellationToken = default);

    Task<Stream> OpenReadAsync(string storedFileName, CancellationToken cancellationToken = default);
    Task DeleteAsync(string storedFileName, CancellationToken cancellationToken = default);
}
