using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using freshfood_be.Data;
using freshfood_be.Models;
using freshfood_be.Services.Media;

namespace freshfood_be.Controllers
{
    /// <summary>Quản trị blog posts — api/Admin/BlogPosts</summary>
    [Authorize(Roles = "Admin")]
    [Route("api/Admin/BlogPosts")]
    [ApiController]
    public class AdminBlogPostsController : ControllerBase
    {
        private readonly FreshFoodContext _context;
        private readonly IWebHostEnvironment _env;
        private readonly freshfood_be.Services.Security.IdTokenService _idTokens;
        private readonly IImageStorage _images;

        public AdminBlogPostsController(FreshFoodContext context, IWebHostEnvironment env, freshfood_be.Services.Security.IdTokenService idTokens, IImageStorage images)
        {
            _context = context;
            _env = env;
            _idTokens = idTokens;
            _images = images;
        }

        private string GetMediaRoot()
        {
            var configured = (Environment.GetEnvironmentVariable("MEDIA_ROOT") ?? string.Empty).Trim();
            return string.IsNullOrWhiteSpace(configured)
                ? Path.Combine(_env.ContentRootPath, "wwwroot")
                : configured;
        }

        public record BlogPostDto(
            int BlogPostID,
            string BlogPostToken,
            string Title,
            string Slug,
            string? Excerpt,
            string Content,
            string? CoverImageUrl,
            bool IsPublished,
            DateTime? PublishedAt,
            DateTime CreatedAt,
            DateTime? UpdatedAt);

        public record BlogPostUpsertDto(
            string Title,
            string Slug,
            string? Excerpt,
            string Content,
            string? CoverImageUrl,
            bool IsPublished,
            DateTime? PublishedAt);

        public sealed record UploadCoverResultDto(string CoverImageUrl);

        // POST: api/Admin/BlogPosts/UploadCover (multipart/form-data: field "file")
        [HttpPost("UploadCover")]
        [Consumes("multipart/form-data")]
        [RequestSizeLimit(10_000_000)] // ~10MB
        public async Task<ActionResult<UploadCoverResultDto>> UploadCover([FromForm] IFormFile file)
        {
            if (file == null || file.Length == 0) return BadRequest("Vui lòng chọn ảnh.");

            var allowed = new HashSet<string> { ".jpg", ".jpeg", ".png", ".webp", ".gif", ".jfif" };
            var ext = Path.GetExtension(file.FileName).ToLowerInvariant();
            if (string.IsNullOrWhiteSpace(ext) || !allowed.Contains(ext))
                return BadRequest($"Unsupported image extension: {ext}. Allowed: jpg, jpeg, png, webp, gif, jfif.");

            if (string.IsNullOrWhiteSpace(file.ContentType) || !file.ContentType.StartsWith("image/", StringComparison.OrdinalIgnoreCase))
                return BadRequest("Only image files are allowed.");

            string url;
            if (_images.IsEnabled)
            {
                url = await _images.UploadImageAsync("blog-covers", file, HttpContext.RequestAborted);
            }
            else
            {
                var rootDir = Path.Combine(GetMediaRoot(), "blog-covers");
                Directory.CreateDirectory(rootDir);

                var safeName = $"{Guid.NewGuid():N}{ext}";
                var fullPath = Path.Combine(rootDir, safeName);
                await using (var stream = System.IO.File.Create(fullPath))
                {
                    await file.CopyToAsync(stream);
                }
                url = $"/blog-covers/{safeName}";
            }
            return Ok(new UploadCoverResultDto(url));
        }

        [HttpGet]
        public async Task<ActionResult<IEnumerable<BlogPostDto>>> List([FromQuery] string? q = null, [FromQuery] bool? published = null)
        {
            var query = _context.BlogPosts.AsNoTracking().AsQueryable();

            if (!string.IsNullOrWhiteSpace(q))
            {
                var term = q.Trim();
                query = query.Where(p =>
                    p.Title.Contains(term) ||
                    p.Slug.Contains(term) ||
                    (p.Excerpt != null && p.Excerpt.Contains(term)) ||
                    p.BlogPostID.ToString().Contains(term));
            }

            if (published.HasValue)
                query = query.Where(p => p.IsPublished == published.Value);

            var rows = await query
                .OrderByDescending(p => p.PublishedAt ?? p.CreatedAt)
                .ThenByDescending(p => p.BlogPostID)
                .Select(p => new BlogPostDto(
                    p.BlogPostID,
                    "",
                    p.Title,
                    p.Slug,
                    p.Excerpt,
                    p.Content,
                    p.CoverImageUrl,
                    p.IsPublished,
                    p.PublishedAt,
                    p.CreatedAt,
                    p.UpdatedAt
                ))
                .ToListAsync();

            return Ok(rows.Select(x => x with { BlogPostToken = _idTokens.ProtectBlogPostId(x.BlogPostID) }).ToList());
        }

        [HttpGet("{id:int}")]
        public async Task<ActionResult<BlogPostDto>> Get(int id)
        {
            var p = await _context.BlogPosts.AsNoTracking().FirstOrDefaultAsync(x => x.BlogPostID == id);
            if (p == null) return NotFound();

            return Ok(new BlogPostDto(
                p.BlogPostID,
                _idTokens.ProtectBlogPostId(p.BlogPostID),
                p.Title,
                p.Slug,
                p.Excerpt,
                p.Content,
                p.CoverImageUrl,
                p.IsPublished,
                p.PublishedAt,
                p.CreatedAt,
                p.UpdatedAt
            ));
        }

        [HttpGet("token/{token}")]
        public async Task<ActionResult<BlogPostDto>> GetByToken([FromRoute] string token)
        {
            if (string.IsNullOrWhiteSpace(token)) return NotFound();
            var id = _idTokens.UnprotectBlogPostId(token.Trim());
            if (id == null || id <= 0) return NotFound();
            return await Get(id.Value);
        }

        [HttpPost]
        public async Task<ActionResult<BlogPostDto>> Create([FromBody] BlogPostUpsertDto input)
        {
            var title = (input.Title ?? string.Empty).Trim();
            var slug = (input.Slug ?? string.Empty).Trim();
            var content = (input.Content ?? string.Empty).Trim();

            if (string.IsNullOrWhiteSpace(title)) return BadRequest("Title bắt buộc.");
            if (string.IsNullOrWhiteSpace(slug)) return BadRequest("Slug bắt buộc.");
            if (string.IsNullOrWhiteSpace(content)) return BadRequest("Content bắt buộc.");

            var slugExists = await _context.BlogPosts.AnyAsync(p => p.Slug == slug);
            if (slugExists) return Conflict("Slug đã tồn tại.");

            var p = new BlogPost
            {
                Title = title,
                Slug = slug,
                Excerpt = string.IsNullOrWhiteSpace(input.Excerpt) ? null : input.Excerpt.Trim(),
                Content = content,
                CoverImageUrl = string.IsNullOrWhiteSpace(input.CoverImageUrl) ? null : input.CoverImageUrl.Trim(),
                IsPublished = input.IsPublished,
                PublishedAt = input.PublishedAt,
                CreatedAt = DateTime.UtcNow,
                UpdatedAt = null
            };

            _context.BlogPosts.Add(p);
            await _context.SaveChangesAsync();

            var dto = new BlogPostDto(
                p.BlogPostID,
                _idTokens.ProtectBlogPostId(p.BlogPostID),
                p.Title,
                p.Slug,
                p.Excerpt,
                p.Content,
                p.CoverImageUrl,
                p.IsPublished,
                p.PublishedAt,
                p.CreatedAt,
                p.UpdatedAt
            );

            return CreatedAtAction(nameof(Get), new { id = p.BlogPostID }, dto);
        }

        [HttpPut("{id:int}")]
        public async Task<ActionResult<BlogPostDto>> Update(int id, [FromBody] BlogPostUpsertDto input)
        {
            var p = await _context.BlogPosts.FirstOrDefaultAsync(x => x.BlogPostID == id);
            if (p == null) return NotFound();

            var title = (input.Title ?? string.Empty).Trim();
            var slug = (input.Slug ?? string.Empty).Trim();
            var content = (input.Content ?? string.Empty).Trim();

            if (string.IsNullOrWhiteSpace(title)) return BadRequest("Title bắt buộc.");
            if (string.IsNullOrWhiteSpace(slug)) return BadRequest("Slug bắt buộc.");
            if (string.IsNullOrWhiteSpace(content)) return BadRequest("Content bắt buộc.");

            var slugTaken = await _context.BlogPosts.AnyAsync(x => x.BlogPostID != id && x.Slug == slug);
            if (slugTaken) return Conflict("Slug đã tồn tại.");

            p.Title = title;
            p.Slug = slug;
            p.Excerpt = string.IsNullOrWhiteSpace(input.Excerpt) ? null : input.Excerpt.Trim();
            p.Content = content;
            p.CoverImageUrl = string.IsNullOrWhiteSpace(input.CoverImageUrl) ? null : input.CoverImageUrl.Trim();
            p.IsPublished = input.IsPublished;
            p.PublishedAt = input.PublishedAt;
            p.UpdatedAt = DateTime.UtcNow;

            await _context.SaveChangesAsync();

            return Ok(new BlogPostDto(
                p.BlogPostID,
                _idTokens.ProtectBlogPostId(p.BlogPostID),
                p.Title,
                p.Slug,
                p.Excerpt,
                p.Content,
                p.CoverImageUrl,
                p.IsPublished,
                p.PublishedAt,
                p.CreatedAt,
                p.UpdatedAt
            ));
        }

        [HttpDelete("{id:int}")]
        public async Task<IActionResult> Delete(int id)
        {
            var p = await _context.BlogPosts.FindAsync(id);
            if (p == null) return NotFound();

            _context.BlogPosts.Remove(p);
            await _context.SaveChangesAsync();
            return NoContent();
        }
    }
}

