using CloudinaryDotNet;
using CloudinaryDotNet.Actions;
using Microsoft.AspNetCore.Http;

namespace freshfood_be.Services.Media;

public interface IImageStorage
{
    bool IsEnabled { get; }
    Task<string> UploadProductImageAsync(int productId, IFormFile file, CancellationToken ct);
    Task<string> UploadProductImageFromPathAsync(int productId, string filePath, CancellationToken ct);
    Task TryDeleteByUrlAsync(string url, CancellationToken ct);
}

public sealed class CloudinaryImageStorage : IImageStorage
{
    private readonly Cloudinary _cloudinary;
    private readonly string _folder;

    public CloudinaryImageStorage(Cloudinary cloudinary, string folder)
    {
        _cloudinary = cloudinary;
        _folder = string.IsNullOrWhiteSpace(folder) ? "freshfood" : folder.Trim().Trim('/');
    }

    public bool IsEnabled => true;

    public async Task<string> UploadProductImageAsync(int productId, IFormFile file, CancellationToken ct)
    {
        await using var stream = file.OpenReadStream();
        var ext = Path.GetExtension(file.FileName);
        var publicId = $"{_folder}/products/{productId}/{Guid.NewGuid():N}{ext}";
        publicId = publicId.Replace("\\", "/");

        var uploadParams = new ImageUploadParams
        {
            File = new FileDescription(file.FileName, stream),
            PublicId = publicId,
            Overwrite = false,
            // Basic optimization defaults
            Transformation = new Transformation().Quality("auto").FetchFormat("auto")
        };

        var res = await _cloudinary.UploadAsync(uploadParams, ct);
        if (res == null || res.StatusCode != System.Net.HttpStatusCode.OK || string.IsNullOrWhiteSpace(res.SecureUrl?.ToString()))
        {
            var msg = res?.Error?.Message;
            throw new InvalidOperationException(string.IsNullOrWhiteSpace(msg) ? "Upload ảnh thất bại (Cloudinary)." : msg);
        }

        return res.SecureUrl.ToString();
    }

    public async Task<string> UploadProductImageFromPathAsync(int productId, string filePath, CancellationToken ct)
    {
        var p = (filePath ?? string.Empty).Trim();
        if (string.IsNullOrWhiteSpace(p) || !File.Exists(p))
            throw new FileNotFoundException("Không tìm thấy file ảnh để upload.", p);

        var ext = Path.GetExtension(p);
        var publicId = $"{_folder}/products/{productId}/{Guid.NewGuid():N}{ext}";
        publicId = publicId.Replace("\\", "/");

        var uploadParams = new ImageUploadParams
        {
            File = new FileDescription(p),
            PublicId = publicId,
            Overwrite = false,
            Transformation = new Transformation().Quality("auto").FetchFormat("auto")
        };

        var res = await _cloudinary.UploadAsync(uploadParams, ct);
        if (res == null || res.StatusCode != System.Net.HttpStatusCode.OK || string.IsNullOrWhiteSpace(res.SecureUrl?.ToString()))
        {
            var msg = res?.Error?.Message;
            throw new InvalidOperationException(string.IsNullOrWhiteSpace(msg) ? "Upload ảnh thất bại (Cloudinary)." : msg);
        }

        return res.SecureUrl.ToString();
    }

    public async Task TryDeleteByUrlAsync(string url, CancellationToken ct)
    {
        var publicId = TryExtractPublicId(url);
        if (string.IsNullOrWhiteSpace(publicId)) return;

        try
        {
            // CloudinaryDotNet does not provide cancellation token overload here.
            await _cloudinary.DestroyAsync(new DeletionParams(publicId));
        }
        catch
        {
            // best-effort cleanup only
        }
    }

    // Cloudinary secure URL: https://res.cloudinary.com/<cloud>/image/upload/v123/folder/.../name.ext
    private static string? TryExtractPublicId(string url)
    {
        if (string.IsNullOrWhiteSpace(url)) return null;
        if (!Uri.TryCreate(url.Trim(), UriKind.Absolute, out var u)) return null;
        var path = u.AbsolutePath ?? "";
        var idx = path.IndexOf("/upload/", StringComparison.OrdinalIgnoreCase);
        if (idx < 0) return null;
        var after = path[(idx + "/upload/".Length)..].Trim('/');
        // strip "v123/" prefix if present
        if (after.StartsWith("v", StringComparison.OrdinalIgnoreCase))
        {
            var slash = after.IndexOf('/');
            if (slash > 0)
            {
                var ver = after[..slash];
                if (ver.Length > 1 && ver.Skip(1).All(char.IsDigit))
                    after = after[(slash + 1)..];
            }
        }
        var dot = after.LastIndexOf('.');
        if (dot > 0) after = after[..dot];
        return after;
    }
}

public sealed class DisabledImageStorage : IImageStorage
{
    public bool IsEnabled => false;
    public Task<string> UploadProductImageAsync(int productId, IFormFile file, CancellationToken ct) =>
        throw new InvalidOperationException("Image storage is not configured.");

    public Task<string> UploadProductImageFromPathAsync(int productId, string filePath, CancellationToken ct) =>
        throw new InvalidOperationException("Image storage is not configured.");

    public Task TryDeleteByUrlAsync(string url, CancellationToken ct) => Task.CompletedTask;
}

