using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using freshfood_be.Data;
using freshfood_be.Services.Media;

namespace freshfood_be.Controllers;

/// <summary>Migrate local wwwroot media URLs to Cloudinary.</summary>
[Authorize(Roles = "Admin")]
[Route("api/Admin/Media")]
[ApiController]
public sealed class AdminMediaMigrationController : ControllerBase
{
    private readonly FreshFoodContext _context;
    private readonly IWebHostEnvironment _env;
    private readonly IImageStorage _images;

    public AdminMediaMigrationController(FreshFoodContext context, IWebHostEnvironment env, IImageStorage images)
    {
        _context = context;
        _env = env;
        _images = images;
    }

    public sealed record MigrateProductImagesResultDto(
        int Scanned,
        int Migrated,
        int SkippedMissingFile,
        int SkippedNotLocalUrl,
        int Failed,
        IReadOnlyList<string> Errors);

    /// <summary>
    /// Migrates ProductImages whose ImageURL starts with "/product-images/" to Cloudinary and updates DB.
    /// Run this on a machine that still has the local files under wwwroot.
    /// </summary>
    [HttpPost("MigrateProductImagesToCloudinary")]
    public async Task<ActionResult<MigrateProductImagesResultDto>> MigrateProductImagesToCloudinary(
        [FromQuery] int take = 200,
        [FromQuery] bool dryRun = true,
        CancellationToken ct = default)
    {
        if (!_images.IsEnabled)
            return BadRequest("Cloudinary chưa được cấu hình (thiếu CLOUDINARY_URL).");

        take = Math.Clamp(take, 1, 5000);

        var targets = await _context.ProductImages
            .Where(x => x.ImageURL != null && x.ImageURL.StartsWith("/product-images/", StringComparison.OrdinalIgnoreCase))
            .OrderBy(x => x.ImageID)
            .Take(take)
            .ToListAsync(ct);

        var scanned = 0;
        var migrated = 0;
        var skippedMissing = 0;
        var skippedNotLocal = 0;
        var failed = 0;
        var errors = new List<string>();

        foreach (var img in targets)
        {
            ct.ThrowIfCancellationRequested();
            scanned += 1;

            var url = (img.ImageURL ?? string.Empty).Trim();
            if (!url.StartsWith("/product-images/", StringComparison.OrdinalIgnoreCase))
            {
                skippedNotLocal += 1;
                continue;
            }

            var relative = url.TrimStart('/').Replace('/', Path.DirectorySeparatorChar);
            var fullPath = Path.Combine(_env.ContentRootPath, "wwwroot", relative);
            if (!System.IO.File.Exists(fullPath))
            {
                skippedMissing += 1;
                continue;
            }

            if (dryRun)
                continue;

            try
            {
                var newUrl = await _images.UploadProductImageFromPathAsync(img.ProductID, fullPath, ct);
                img.ImageURL = newUrl;
                migrated += 1;
            }
            catch (Exception ex)
            {
                failed += 1;
                errors.Add($"ImageID={img.ImageID}, ProductID={img.ProductID}: {ex.Message}");
            }
        }

        if (!dryRun && migrated > 0)
        {
            await _context.SaveChangesAsync(ct);
        }

        return Ok(new MigrateProductImagesResultDto(scanned, migrated, skippedMissing, skippedNotLocal, failed, errors));
    }
}

