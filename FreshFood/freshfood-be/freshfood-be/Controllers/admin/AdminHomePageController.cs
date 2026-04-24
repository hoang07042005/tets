using System.Text.Json;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using freshfood_be.Data;
using freshfood_be.Models;
using freshfood_be.Services.Security;

namespace freshfood_be.Controllers;

[Authorize(Roles = "Admin")]
[Route("api/Admin/HomePage")]
[ApiController]
public class AdminHomePageController : ControllerBase
{
    private readonly FreshFoodContext _context;
    private readonly IWebHostEnvironment _env;
    private readonly AdminAuditLogger _audit;

    public AdminHomePageController(FreshFoodContext context, IWebHostEnvironment env, AdminAuditLogger audit)
    {
        _context = context;
        _env = env;
        _audit = audit;
    }

    public sealed record HomeHeroDto(
        string Eyebrow,
        string Title,
        string Highlight,
        string Subtitle,
        string ImageUrl,
        string PrimaryCtaText,
        string PrimaryCtaHref,
        string SecondaryCtaText,
        string? SecondaryCtaHref,
        string Feature1Title,
        string Feature1Sub,
        string Feature2Title,
        string Feature2Sub
    );

    public sealed record HomeRootsDto(
        string Subheading,
        string Title,
        string Paragraph1,
        string Paragraph2,
        string ImageUrl,
        string Stat1Value,
        string Stat1Label,
        string Stat2Value,
        string Stat2Label
    );

    public sealed record HomeSeasonalCardDto(string Title, string ImageUrl);

    public sealed record HomeSeasonalDto(string Heading, string Subheading, IReadOnlyList<HomeSeasonalCardDto> Cards);

    public sealed record HomePageSettingsDto(HomeHeroDto Hero, HomeRootsDto Roots, HomeSeasonalDto Seasonal);

    private static readonly JsonSerializerOptions JsonOpts = new(JsonSerializerDefaults.Web)
    {
        PropertyNameCaseInsensitive = true,
        WriteIndented = false
    };

    public sealed record UploadImageResultDto(string ImageUrl);

    private static HashSet<string> CollectHomeAssetUrls(HomePageSettingsDto? x)
    {
        var set = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        if (x == null) return set;

        static string Normalize(string? url)
        {
            var s = (url ?? "").Trim();
            if (string.IsNullOrWhiteSpace(s)) return "";
            if (Uri.TryCreate(s, UriKind.Absolute, out var abs)) s = abs.AbsolutePath;
            s = s.Replace('\\', '/');
            if (!s.StartsWith('/')) s = "/" + s;
            return s;
        }

        void AddIfHomeAsset(string? url)
        {
            var n = Normalize(url);
            if (!string.IsNullOrWhiteSpace(n) && n.StartsWith("/home-assets/", StringComparison.OrdinalIgnoreCase))
                set.Add(n);
        }

        AddIfHomeAsset(x.Hero?.ImageUrl);
        AddIfHomeAsset(x.Roots?.ImageUrl);
        if (x.Seasonal?.Cards != null)
        {
            foreach (var c in x.Seasonal.Cards)
                AddIfHomeAsset(c?.ImageUrl);
        }

        return set;
    }

    private void TryDeleteHomeAsset(string normalizedUrlPath)
    {
        try
        {
            var rel = normalizedUrlPath.Trim().TrimStart('/').Replace('/', Path.DirectorySeparatorChar);
            var full = Path.GetFullPath(Path.Combine(_env.ContentRootPath, "wwwroot", rel));
            var root = Path.GetFullPath(Path.Combine(_env.ContentRootPath, "wwwroot", "home-assets"));
            if (!full.StartsWith(root, StringComparison.OrdinalIgnoreCase)) return;
            if (System.IO.File.Exists(full)) System.IO.File.Delete(full);
        }
        catch
        {
            // best-effort cleanup: ignore failures
        }
    }

    // POST: api/Admin/HomePage/UploadImage (multipart/form-data: field "file")
    [HttpPost("UploadImage")]
    [Consumes("multipart/form-data")]
    [RequestSizeLimit(10_000_000)] // ~10MB
    public async Task<ActionResult<UploadImageResultDto>> UploadImage([FromForm] IFormFile file, CancellationToken ct)
    {
        if (file == null || file.Length == 0) return BadRequest("Vui lòng chọn ảnh.");

        var allowed = new HashSet<string> { ".jpg", ".jpeg", ".png", ".webp", ".gif", ".jfif" };
        var ext = Path.GetExtension(file.FileName).ToLowerInvariant();
        if (string.IsNullOrWhiteSpace(ext) || !allowed.Contains(ext))
            return BadRequest($"Unsupported image extension: {ext}. Allowed: jpg, jpeg, png, webp, gif, jfif.");

        if (string.IsNullOrWhiteSpace(file.ContentType) || !file.ContentType.StartsWith("image/", StringComparison.OrdinalIgnoreCase))
            return BadRequest("Only image files are allowed.");

        var rootDir = Path.Combine(_env.ContentRootPath, "wwwroot", "home-assets");
        Directory.CreateDirectory(rootDir);

        var safeName = $"{Guid.NewGuid():N}{ext}";
        var fullPath = Path.Combine(rootDir, safeName);
        await using (var stream = System.IO.File.Create(fullPath))
        {
            await file.CopyToAsync(stream, ct);
        }

        var url = $"/home-assets/{safeName}";

        await _audit.LogAsync(
            action: "home.upload_image",
            entityType: "HomePageSettings",
            entityId: "1",
            summary: "Uploaded home asset image",
            data: new { imageUrl = url, fileName = file.FileName, size = file.Length, contentType = file.ContentType },
            ct: ct);
        return Ok(new UploadImageResultDto(url));
    }

    [HttpGet]
    public async Task<ActionResult<HomePageSettingsDto>> Get(CancellationToken ct)
    {
        var row = await _context.HomePageSettings.AsNoTracking().FirstOrDefaultAsync(x => x.Id == 1, ct);
        if (row == null || string.IsNullOrWhiteSpace(row.SettingsJson)) return NotFound();
        try
        {
            var dto = JsonSerializer.Deserialize<HomePageSettingsDto>(row.SettingsJson, JsonOpts);
            return dto == null ? NotFound() : Ok(dto);
        }
        catch
        {
            return BadRequest("Dữ liệu trang chủ không hợp lệ (JSON parse error).");
        }
    }

    [HttpPut]
    public async Task<ActionResult> Put([FromBody] HomePageSettingsDto input, CancellationToken ct)
    {
        if (input == null) return BadRequest("Thiếu dữ liệu.");
        if (input.Seasonal?.Cards == null || input.Seasonal.Cards.Count != 3)
            return BadRequest("Seasonal.Cards phải có đúng 3 phần tử.");

        var row = await _context.HomePageSettings.FirstOrDefaultAsync(x => x.Id == 1, ct);
        HomePageSettingsDto? oldDto = null;
        if (row != null && !string.IsNullOrWhiteSpace(row.SettingsJson))
        {
            try
            {
                oldDto = JsonSerializer.Deserialize<HomePageSettingsDto>(row.SettingsJson, JsonOpts);
            }
            catch
            {
                oldDto = null;
            }
        }

        var oldAssets = CollectHomeAssetUrls(oldDto);
        var newAssets = CollectHomeAssetUrls(input);

        var json = JsonSerializer.Serialize(input, JsonOpts);
        if (row == null)
        {
            row = new HomePageSettings { Id = 1, SettingsJson = json, UpdatedAt = DateTime.UtcNow };
            _context.HomePageSettings.Add(row);
        }
        else
        {
            row.SettingsJson = json;
            row.UpdatedAt = DateTime.UtcNow;
        }

        await _context.SaveChangesAsync(ct);

        // Cleanup ảnh cũ không còn tham chiếu.
        var removed = new List<string>();
        foreach (var oldUrl in oldAssets)
        {
            if (!newAssets.Contains(oldUrl))
            {
                TryDeleteHomeAsset(oldUrl);
                removed.Add(oldUrl);
            }
        }

        await _audit.LogAsync(
            action: "home.update_settings",
            entityType: "HomePageSettings",
            entityId: "1",
            summary: "Updated homepage settings",
            data: new
            {
                deletedAssets = removed.OrderBy(x => x).ToList(),
                hero = new { input.Hero?.Title, input.Hero?.Subtitle, input.Hero?.ImageUrl },
                roots = new { input.Roots?.Subheading, input.Roots?.Title, input.Roots?.ImageUrl },
                seasonal = new { input.Seasonal?.Heading, input.Seasonal?.Subheading, cards = input.Seasonal?.Cards?.Select(c => new { c?.Title, c?.ImageUrl }).ToList() }
            },
            ct: ct);

        return NoContent();
    }
}

