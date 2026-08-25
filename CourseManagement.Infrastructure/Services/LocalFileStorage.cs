using CourseManagement.Application.Interfaces;
using CourseManagement.Application.Options;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Options;

namespace CourseManagement.Infrastructure.Services;

public sealed class LocalFileStorage(
    IHostEnvironment environment,
    IOptions<FileUploadOptions> options) : IFileStorage
{
    private readonly string rootPath = ResolveRoot(environment.ContentRootPath, options.Value.RootPath);

    public async Task<StoredFile> SaveAsync(
        Stream content,
        string extension,
        CancellationToken cancellationToken = default)
    {
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
                bufferSize: 1024 * 64,
                useAsync: true))
            {
                await content.CopyToAsync(target, cancellationToken);
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
            bufferSize: 1024 * 64,
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
