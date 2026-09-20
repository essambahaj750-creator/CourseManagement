namespace CourseManagement.Application.Common;

/// <summary>
/// Decides whether uploaded bytes actually are what the file extension claims, and
/// supplies the content type the server will store.
///
/// <para>
/// The client-declared content type is deliberately ignored. It is attacker-controlled,
/// and the previous validation accepted <c>application/octet-stream</c> unconditionally,
/// which made the check worth nothing. Trusting the bytes instead means a
/// <c>.png</c> containing markup is rejected outright, and the type persisted with the
/// asset is derived from the extension rather than echoed back from the request.
/// </para>
/// </summary>
public static class UploadContentInspector
{
    /// <summary>
    /// Bytes needed to reach the furthest signature offset. WebP needs the "WEBP"
    /// marker at offset 8, and QuickTime atoms sit at offset 4.
    /// </summary>
    public const int HeaderLength = 16;

    private static readonly Dictionary<string, string> ContentTypesByExtension = new(StringComparer.OrdinalIgnoreCase)
    {
        [".jpg"] = "image/jpeg",
        [".jpeg"] = "image/jpeg",
        [".png"] = "image/png",
        [".webp"] = "image/webp",
        [".mp4"] = "video/mp4",
        [".m4v"] = "video/x-m4v",
        [".mov"] = "video/quicktime",
        [".webm"] = "video/webm",
        [".pdf"] = "application/pdf",
        [".doc"] = "application/msword",
        [".docx"] = "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
        [".ppt"] = "application/vnd.ms-powerpoint",
        [".pptx"] = "application/vnd.openxmlformats-officedocument.presentationml.presentation",
        [".xls"] = "application/vnd.ms-excel",
        [".xlsx"] = "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
        [".zip"] = "application/zip",
        [".txt"] = "text/plain"
    };

    /// <summary>
    /// The content type to persist for an allowed extension. Falls back to
    /// <c>application/octet-stream</c>, which is the safe default for serving.
    /// </summary>
    public static string ResolveContentType(string extension) =>
        ContentTypesByExtension.TryGetValue(extension, out var contentType)
            ? contentType
            : "application/octet-stream";

    /// <summary>
    /// True when <paramref name="header"/> carries a signature consistent with
    /// <paramref name="extension"/>.
    /// <para>
    /// Plain text has no signature, so <c>.txt</c> is accepted on the strength of its
    /// extension and size limit alone; a byte-level check would reject legitimate
    /// UTF-16 files, whose encoding includes NUL bytes.
    /// </para>
    /// <para>
    /// The OPC formats (<c>.docx</c>, <c>.xlsx</c>, <c>.pptx</c>) are ZIP archives and
    /// share one signature, so this confirms a valid OPC container rather than telling
    /// those three apart. Distinguishing them would mean opening the archive.
    /// </para>
    /// </summary>
    public static bool MatchesSignature(string extension, ReadOnlySpan<byte> header) =>
        extension.ToLowerInvariant() switch
        {
            ".txt" => true,

            ".jpg" or ".jpeg" => StartsWith(header, [0xFF, 0xD8, 0xFF]),
            ".png" => StartsWith(header, [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]),
            ".webp" => HasAscii(header, 0, "RIFF") && HasAscii(header, 8, "WEBP"),

            ".mp4" or ".m4v" => HasAscii(header, 4, "ftyp"),
            ".mov" => HasAscii(header, 4, "ftyp") || IsQuickTimeAtom(header),
            ".webm" => StartsWith(header, [0x1A, 0x45, 0xDF, 0xA3]),

            ".pdf" => HasAscii(header, 0, "%PDF-"),
            ".zip" or ".docx" or ".xlsx" or ".pptx" => IsZipArchive(header),
            ".doc" or ".xls" or ".ppt" => StartsWith(header, [0xD0, 0xCF, 0x11, 0xE0, 0xA1, 0xB1, 0x1A, 0xE1]),

            _ => false
        };

    private static bool StartsWith(ReadOnlySpan<byte> header, ReadOnlySpan<byte> signature) =>
        header.Length >= signature.Length && header[..signature.Length].SequenceEqual(signature);

    private static bool HasAscii(ReadOnlySpan<byte> header, int offset, string marker)
    {
        if (header.Length < offset + marker.Length)
            return false;

        for (var index = 0; index < marker.Length; index++)
        {
            if (header[offset + index] != (byte)marker[index])
                return false;
        }

        return true;
    }

    // Legacy QuickTime files open with a top-level atom rather than "ftyp".
    private static bool IsQuickTimeAtom(ReadOnlySpan<byte> header) =>
        HasAscii(header, 4, "moov") ||
        HasAscii(header, 4, "mdat") ||
        HasAscii(header, 4, "free") ||
        HasAscii(header, 4, "skip") ||
        HasAscii(header, 4, "wide") ||
        HasAscii(header, 4, "pnot");

    // Local file header, plus the empty and spanned variants.
    private static bool IsZipArchive(ReadOnlySpan<byte> header) =>
        StartsWith(header, [0x50, 0x4B, 0x03, 0x04]) ||
        StartsWith(header, [0x50, 0x4B, 0x05, 0x06]) ||
        StartsWith(header, [0x50, 0x4B, 0x07, 0x08]);
}
