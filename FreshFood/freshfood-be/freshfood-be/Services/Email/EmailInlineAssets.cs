using Microsoft.AspNetCore.Hosting;
using Microsoft.Extensions.Configuration;

namespace freshfood_be.Services.Email;

/// <summary>Chuẩn hóa URL media và nhúng file local (logo, ảnh SP) để client mail không cần tải từ localhost.</summary>
public static class EmailInlineAssets
{
    public const string LogoContentId = "ff-email-logo";

    private static string WebRoot(IWebHostEnvironment env)
    {
        var mediaRoot = (Environment.GetEnvironmentVariable("MEDIA_ROOT") ?? "").Trim();
        if (!string.IsNullOrWhiteSpace(mediaRoot))
            return mediaRoot;
        if (!string.IsNullOrWhiteSpace(env.WebRootPath))
            return env.WebRootPath;
        return Path.Combine(env.ContentRootPath, "wwwroot");
    }

    public static string ToAbsoluteMediaUrl(string apiBase, string? path)
    {
        if (string.IsNullOrWhiteSpace(path)) return "";
        var p = path.Trim();
        if (p.StartsWith("http://", StringComparison.OrdinalIgnoreCase) || p.StartsWith("https://", StringComparison.OrdinalIgnoreCase))
            return p;
        var b = apiBase.Trim().TrimEnd('/');
        return p.StartsWith('/') ? b + p : b + "/" + p;
    }

    /// <summary>Ưu tiên <c>Email:LogoUrl</c> (CDN); sau đó file <c>wwwroot/email-assets/logo-email.png</c> (cid); cuối cùng URL tuyệt đối từ API.</summary>
    public static async Task<string> ResolveLogoSrcAsync(
        IWebHostEnvironment env,
        IConfiguration config,
        List<EmailLinkedResource> linked,
        string apiBase,
        CancellationToken ct)
    {
        var custom = (config["Email:LogoUrl"] ?? "").Trim();
        if (!string.IsNullOrEmpty(custom))
            return custom;

        var path = Path.Combine(WebRoot(env), "email-assets", "logo-email.png");
        if (File.Exists(path))
        {
            var bytes = await File.ReadAllBytesAsync(path, ct).ConfigureAwait(false);
            linked.Add(new EmailLinkedResource(bytes, "logo-email.png", LogoContentId, "image/png"));
            return "cid:" + LogoContentId;
        }

        var fe = (config["Frontend:BaseUrl"] ?? "").Trim().TrimEnd('/');
        if (!string.IsNullOrEmpty(fe))
            return fe + "/favicon.svg";

        var b = apiBase.Trim().TrimEnd('/');
        return b + "/email-assets/logo-email.png";
    }

    /// <summary>Nhúng ảnh nếu file nằm dưới <c>wwwroot/product-images</c> (path tương đối hoặc URL cùng host).</summary>
    public static async Task<string?> ResolveProductImageSrcAsync(
        IWebHostEnvironment env,
        List<EmailLinkedResource> linked,
        string apiBase,
        string? imageUrlFromDb,
        int productId,
        int lineIndex,
        CancellationToken ct)
    {
        var physical = MapProductImageToWebRootPath(env, imageUrlFromDb);
        if (physical != null && File.Exists(physical))
        {
            var cid = $"ff-p-{productId}-{lineIndex}";
            var bytes = await File.ReadAllBytesAsync(physical, ct).ConfigureAwait(false);
            var name = Path.GetFileName(physical);
            var mime = GuessImageMime(physical);
            linked.Add(new EmailLinkedResource(bytes, string.IsNullOrEmpty(name) ? "product.png" : name, cid, mime));
            return "cid:" + cid;
        }

        var abs = ToAbsoluteMediaUrl(apiBase, imageUrlFromDb);
        return string.IsNullOrWhiteSpace(abs) ? null : abs;
    }

    private static string GuessImageMime(string path)
    {
        return Path.GetExtension(path).ToLowerInvariant() switch
        {
            ".png" => "image/png",
            ".jpg" or ".jpeg" or ".jfif" => "image/jpeg",
            ".webp" => "image/webp",
            ".gif" => "image/gif",
            ".svg" => "image/svg+xml",
            _ => "application/octet-stream"
        };
    }

    private static string? MapProductImageToWebRootPath(IWebHostEnvironment env, string? path)
    {
        if (string.IsNullOrWhiteSpace(path)) return null;
        var root = WebRoot(env);
        if (string.IsNullOrWhiteSpace(root) || !Directory.Exists(root)) return null;

        var p = path.Trim();
        if (p.StartsWith("http://", StringComparison.OrdinalIgnoreCase) || p.StartsWith("https://", StringComparison.OrdinalIgnoreCase))
        {
            if (!Uri.TryCreate(p, UriKind.Absolute, out var u)) return null;
            p = u.AbsolutePath;
        }

        if (!p.StartsWith('/')) p = "/" + p;
        if (!p.StartsWith("/product-images/", StringComparison.OrdinalIgnoreCase)) return null;

        var rel = p.TrimStart('/').Replace('/', Path.DirectorySeparatorChar);
        var full = Path.Combine(root, rel);
        return full;
    }
}
