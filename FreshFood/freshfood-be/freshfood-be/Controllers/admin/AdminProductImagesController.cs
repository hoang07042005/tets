using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using freshfood_be.Data;
using freshfood_be.Models;
using freshfood_be.Services.Media;

namespace freshfood_be.Controllers;

/// <summary>Upload/Xóa ảnh sản phẩm — api/Admin/Products/{id}/Images</summary>
[Authorize(Roles = "Admin")]
[Route("api/Admin/Products/{productId:int}/Images")]
[ApiController]
public class AdminProductImagesController : ControllerBase
{
    private readonly FreshFoodContext _context;
    private readonly IWebHostEnvironment _env;
    private readonly IImageStorage _images;

    public AdminProductImagesController(FreshFoodContext context, IWebHostEnvironment env, IImageStorage images)
    {
        _context = context;
        _env = env;
        _images = images;
    }

    public sealed record UploadResultDto(int ImageID, string ImageURL, bool IsMainImage);

    // POST: api/Admin/Products/{id}/Images (multipart/form-data: field "files")
    // Cho phép upload nhiều ảnh, có thể truyền mainIndex để chọn ảnh chính.
    [HttpPost]
    [Consumes("multipart/form-data")]
    [RequestSizeLimit(30_000_000)] // ~30MB
    public async Task<ActionResult<IEnumerable<UploadResultDto>>> Upload(
        [FromRoute] int productId,
        [FromForm] List<IFormFile> files,
        [FromForm] int? mainIndex = null)
    {
        if (files == null || files.Count == 0) return Ok(Array.Empty<UploadResultDto>());
        if (files.Count > 10) return BadRequest("Maximum 10 images per upload.");

        var productExists = await _context.Products.AsNoTracking().AnyAsync(p => p.ProductID == productId);
        if (!productExists) return NotFound("Product not found.");

        // Some browsers on Windows upload .jfif; allow common image extensions.
        var allowed = new HashSet<string> { ".jpg", ".jpeg", ".png", ".webp", ".gif", ".jfif" };

        // Accept mainIndex from query too (in case frontend sends ?mainIndex=0).
        if (!mainIndex.HasValue)
        {
            var q = HttpContext.Request.Query["mainIndex"].ToString();
            if (int.TryParse(q, out var parsed)) mainIndex = parsed;
        }

        foreach (var f in files)
        {
            if (f.Length == 0) continue;
            var ext = Path.GetExtension(f.FileName).ToLowerInvariant();
            if (!allowed.Contains(ext)) return BadRequest($"Unsupported image extension: {ext}. Allowed: jpg, jpeg, png, webp, gif, jfif.");
            if (string.IsNullOrWhiteSpace(f.ContentType) || !f.ContentType.StartsWith("image/", StringComparison.OrdinalIgnoreCase))
                return BadRequest("Only image files are allowed.");
        }

        // Local folder is still used for dev environments without Cloudinary configured.
        var rootDir = Path.Combine(_env.ContentRootPath, "wwwroot", "product-images", productId.ToString());
        if (!_images.IsEnabled) Directory.CreateDirectory(rootDir);

        // Nếu có chọn mainIndex, reset main image hiện tại trước (để đảm bảo 1 ảnh chính).
        if (mainIndex.HasValue && mainIndex.Value >= 0 && mainIndex.Value < files.Count)
        {
            var currentMain = await _context.ProductImages.Where(pi => pi.ProductID == productId && pi.IsMainImage).ToListAsync();
            foreach (var img in currentMain) img.IsMainImage = false;
        }

        var results = new List<UploadResultDto>();

        for (var i = 0; i < files.Count; i++)
        {
            var f = files[i];
            if (f.Length == 0) continue;

            string url;
            if (_images.IsEnabled)
            {
                url = await _images.UploadProductImageAsync(productId, f, HttpContext.RequestAborted);
            }
            else
            {
                var ext = Path.GetExtension(f.FileName);
                if (string.IsNullOrWhiteSpace(ext)) ext = ".jpg";

                var safeName = $"{Guid.NewGuid():N}{ext}";
                var fullPath = Path.Combine(rootDir, safeName);
                await using (var stream = System.IO.File.Create(fullPath))
                {
                    await f.CopyToAsync(stream);
                }
                url = $"/product-images/{productId}/{safeName}";
            }
            var isMain = mainIndex.HasValue && i == mainIndex.Value;

            // Nếu chưa có ảnh chính nào và client không chỉ định mainIndex → ảnh đầu tiên sẽ là main.
            if (!mainIndex.HasValue)
            {
                var hasMain = await _context.ProductImages.AsNoTracking().AnyAsync(pi => pi.ProductID == productId && pi.IsMainImage);
                if (!hasMain && results.Count == 0) isMain = true;
            }

            var entity = new ProductImage
            {
                ProductID = productId,
                ImageURL = url,
                IsMainImage = isMain
            };

            _context.ProductImages.Add(entity);
            await _context.SaveChangesAsync();

            results.Add(new UploadResultDto(entity.ImageID, entity.ImageURL, entity.IsMainImage));
        }

        return Ok(results);
    }

    // PUT: api/Admin/Products/{id}/Images/{imageId}/Main
    [HttpPut("{imageId:int}/Main")]
    public async Task<IActionResult> SetMain([FromRoute] int productId, [FromRoute] int imageId)
    {
        var img = await _context.ProductImages.FirstOrDefaultAsync(x => x.ImageID == imageId && x.ProductID == productId);
        if (img == null) return NotFound();

        var all = await _context.ProductImages.Where(x => x.ProductID == productId).ToListAsync();
        foreach (var x in all) x.IsMainImage = x.ImageID == imageId;
        await _context.SaveChangesAsync();
        return NoContent();
    }

    // DELETE: api/Admin/Products/{id}/Images/{imageId}
    [HttpDelete("{imageId:int}")]
    public async Task<IActionResult> Delete([FromRoute] int productId, [FromRoute] int imageId)
    {
        var img = await _context.ProductImages.FirstOrDefaultAsync(x => x.ImageID == imageId && x.ProductID == productId);
        if (img == null) return NotFound();

        // best-effort delete (local file or Cloudinary if URL can be mapped)
        try
        {
            if (!string.IsNullOrWhiteSpace(img.ImageURL) && img.ImageURL.StartsWith("/product-images/", StringComparison.OrdinalIgnoreCase))
            {
                var relative = img.ImageURL.TrimStart('/').Replace('/', Path.DirectorySeparatorChar);
                var fullPath = Path.Combine(_env.ContentRootPath, "wwwroot", relative);
                if (System.IO.File.Exists(fullPath)) System.IO.File.Delete(fullPath);
            }
            else if (!string.IsNullOrWhiteSpace(img.ImageURL))
            {
                await _images.TryDeleteByUrlAsync(img.ImageURL, HttpContext.RequestAborted);
            }
        }
        catch
        {
            // ignore file IO errors; DB deletion still proceeds
        }

        var wasMain = img.IsMainImage;
        _context.ProductImages.Remove(img);
        await _context.SaveChangesAsync();

        if (wasMain)
        {
            var next = await _context.ProductImages.FirstOrDefaultAsync(x => x.ProductID == productId);
            if (next != null)
            {
                next.IsMainImage = true;
                await _context.SaveChangesAsync();
            }
        }

        return NoContent();
    }
}

