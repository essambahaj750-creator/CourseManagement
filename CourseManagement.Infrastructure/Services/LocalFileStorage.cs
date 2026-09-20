using CourseManagement.Application.Common;
using CourseManagement.Application.Interfaces;
using CourseManagement.Application.Options;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Options;

namespace CourseManagement.Infrastructure.Services;

public sealed class LocalFileStorage(
    IHostEnvironment environment,
    IOptions<FileUploadOptions> options) : IFileStorage
{
    private const int BufferSize = 1024 * 64;

    private readonly string rootPath = ResolveRoot(environment.ContentRootPath, options.Value.RootPath);

    public async Task<StoredFile> SaveAsync(
        Stream content,
        string extension,
        long maxBytes,
        CancellationToken cancellationToken = default)
    {
        if (maxBytes <= 0)
            throw new ArgumentOutOfRangeException(nameof(maxBytes));

        Directory.CreateDirectory(rootPath);
        var storedFileName = $"{Guid.NewGuid():N}{extension.ToLowerInvariant()}";
        var absolutePath = GetSafePath(storedFileName);
        var temporaryPath = $"{absolutePath}.{Guid.NewGuid():N}.uploading";

        try
        {
            await using (var target = new FileStream(
                temporaryPath,
                FileMode.CreateNew,
                FileAccess.Write,
                FileShare.None,
                bufferSize: BufferSize,
                useAsync: true))
            {
                await CopyBoundedAsync(content, target, maxBytes, cancellationToken);
            }

            File.Move(temporaryPath, absolutePath);
            return new StoredFile(storedFileName, absolutePath);
        }
        catch
        {
            if (File.Exists(temporaryPath))
                File.Delete(temporaryPath);
            throw;
        }
    }

    /// <summary>
    /// Copies at most <paramref name="maxBytes"/>, then reads one byte further to
    /// detect an oversized stream. The declared upload length is never trusted here.
    /// </summary>
    private static async Task CopyBoundedAsync(
        Stream source,
        Stream destination,
        long maxBytes,
        CancellationToken cancellationToken)
    {
        var buffer = new byte[BufferSize];
        var written = 0L;

        while (true)
        {
            var remaining = maxBytes - written;
            if (remaining <= 0)
            {
                // Anything still readable means the stream is over the limit.
                if (await source.ReadAsync(buffer.AsMemory(0, 1), cancellationToken) > 0)
                {
                    throw new InvalidRequestException(
                        $"The file exceeds the {maxBytes / (1024 * 1024)} MB limit.");
                }

                return;
            }

            var toRead = (int)Math.Min(buffer.Length, remaining);
            var read = await source.ReadAsync(buffer.AsMemory(0, toRead), cancellationToken);
            if (read == 0)
                return;

            await destination.WriteAsync(buffer.AsMemory(0, read), cancellationToken);
            written += read;
        }
    }

    public Task<Stream> OpenReadAsync(string storedFileName, CancellationToken cancellationToken = default)
    {
        cancellationToken.ThrowIfCancellationRequested();
        var absolutePath = GetSafePath(storedFileName);
        if (!File.Exists(absolutePath))
            throw new FileNotFoundException("Stored file was not found.", absolutePath);

        Stream stream = new FileStream(
            absolutePath,
            FileMode.Open,
            FileAccess.Read,
            FileShare.Read,
            bufferSize: BufferSize,
            useAsync: true);
        return Task.FromResult(stream);
    }

    public Task DeleteAsync(string storedFileName, CancellationToken cancellationToken = default)
    {
        cancellationToken.ThrowIfCancellationRequested();
        var absolutePath = GetSafePath(storedFileName);
        if (File.Exists(absolutePath))
            File.Delete(absolutePath);
        return Task.CompletedTask;
    }

    private string GetSafePath(string storedFileName)
    {
        if (string.IsNullOrWhiteSpace(storedFileName) ||
            !string.Equals(Path.GetFileName(storedFileName), storedFileName, StringComparison.Ordinal))
            throw new InvalidOperationException("Invalid stored file name.");

        return Path.Combine(rootPath, storedFileName);
    }

    private static string ResolveRoot(string contentRootPath, string configuredRoot)
    {
        if (string.IsNullOrWhiteSpace(configuredRoot))
            throw new InvalidOperationException("FileUploads:RootPath is required.");

        return Path.GetFullPath(Path.IsPathRooted(configuredRoot)
            ? configuredRoot
            : Path.Combine(contentRootPath, configuredRoot));
    }
}
