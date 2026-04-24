using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using freshfood_be.Data;
using freshfood_be.Models;

namespace freshfood_be.Controllers
{
    /// <summary>Blog công khai (đọc): danh sách + chi tiết theo slug.</summary>
    [Route("api/[controller]")]
    [ApiController]
    public class BlogPostsController : ControllerBase
    {
        private readonly FreshFoodContext _context;

        public BlogPostsController(FreshFoodContext context)
        {
            _context = context;
        }

        public sealed class BlogPostListItemDto
        {
            public int BlogPostID { get; set; }
            public string Title { get; set; } = string.Empty;
            public string Slug { get; set; } = string.Empty;
            public string? Excerpt { get; set; }
            public string? CoverImageUrl { get; set; }
            public DateTime? PublishedAt { get; set; }
            public int ViewCount { get; set; }
        }

        public sealed class BlogPostDetailDto
        {
            public int BlogPostID { get; set; }
            public string Title { get; set; } = string.Empty;
            public string Slug { get; set; } = string.Empty;
            public string? Excerpt { get; set; }
            public string Content { get; set; } = string.Empty;
            public string? CoverImageUrl { get; set; }
            public DateTime? PublishedAt { get; set; }
            public int ViewCount { get; set; }
        }

        [HttpGet]
        public async Task<ActionResult<IEnumerable<BlogPostListItemDto>>> List([FromQuery] string? q = null)
        {
            var query = _context.BlogPosts.AsNoTracking().Where(p => p.IsPublished);

            if (!string.IsNullOrWhiteSpace(q))
            {
                var term = q.Trim();
                query = query.Where(p =>
                    p.Title.Contains(term) ||
                    (p.Excerpt != null && p.Excerpt.Contains(term)));
            }

            var items = await query
                .OrderByDescending(p => p.PublishedAt ?? p.CreatedAt)
                .Select(p => new BlogPostListItemDto
                {
                    BlogPostID = p.BlogPostID,
                    Title = p.Title,
                    Slug = p.Slug,
                    Excerpt = p.Excerpt,
                    CoverImageUrl = p.CoverImageUrl,
                    PublishedAt = p.PublishedAt,
                    ViewCount = p.ViewCount
                })
                .ToListAsync();

            return items;
        }

        [HttpGet("{slug}")]
        public async Task<ActionResult<BlogPostDetailDto>> GetBySlug(string slug)
        {
            if (string.IsNullOrWhiteSpace(slug))
                return BadRequest();

            var entity = await _context.BlogPosts
                .Where(p => p.IsPublished && p.Slug == slug)
                .FirstOrDefaultAsync();

            if (entity == null)
                return NotFound();

            entity.ViewCount = Math.Max(0, entity.ViewCount) + 1;
            await _context.SaveChangesAsync();

            return Ok(new BlogPostDetailDto
            {
                BlogPostID = entity.BlogPostID,
                Title = entity.Title,
                Slug = entity.Slug,
                Excerpt = entity.Excerpt,
                Content = entity.Content,
                CoverImageUrl = entity.CoverImageUrl,
                PublishedAt = entity.PublishedAt,
                ViewCount = entity.ViewCount
            });
        }

        public sealed class BlogCommentDto
        {
            public int BlogCommentID { get; set; }
            public int BlogPostID { get; set; }
            public int UserID { get; set; }
            public int? ParentCommentID { get; set; }
            public string UserName { get; set; } = string.Empty;
            public string? AvatarUrl { get; set; }
            public string Content { get; set; } = string.Empty;
            public DateTime CreatedAt { get; set; }
        }

        public sealed class CreateBlogCommentDto
        {
            public int UserID { get; set; }
            public int? ParentCommentID { get; set; }
            public string Content { get; set; } = string.Empty;
        }

        [HttpGet("{slug}/Comments")]
        public async Task<ActionResult<IEnumerable<BlogCommentDto>>> ListComments(string slug)
        {
            if (string.IsNullOrWhiteSpace(slug)) return BadRequest();

            var postId = await _context.BlogPosts
                .AsNoTracking()
                .Where(p => p.IsPublished && p.Slug == slug)
                .Select(p => p.BlogPostID)
                .FirstOrDefaultAsync();

            if (postId <= 0) return NotFound();

            var rows = await _context.BlogComments
                .AsNoTracking()
                .Where(c => c.BlogPostID == postId)
                .OrderByDescending(c => c.CreatedAt)
                .Join(_context.Users.AsNoTracking(), c => c.UserID, u => u.UserID, (c, u) => new BlogCommentDto
                {
                    BlogCommentID = c.BlogCommentID,
                    BlogPostID = c.BlogPostID,
                    UserID = c.UserID,
                    ParentCommentID = c.ParentCommentID,
                    UserName = u.FullName,
                    AvatarUrl = u.AvatarUrl,
                    Content = c.Content,
                    CreatedAt = c.CreatedAt
                })
                .ToListAsync();

            return Ok(rows);
        }

        [HttpPost("{slug}/Comments")]
        public async Task<ActionResult<BlogCommentDto>> CreateComment(string slug, [FromBody] CreateBlogCommentDto input)
        {
            if (string.IsNullOrWhiteSpace(slug)) return BadRequest();

            var postId = await _context.BlogPosts
                .AsNoTracking()
                .Where(p => p.IsPublished && p.Slug == slug)
                .Select(p => p.BlogPostID)
                .FirstOrDefaultAsync();

            if (postId <= 0) return NotFound();

            var content = (input?.Content ?? string.Empty).Trim();
            if (content.Length == 0) return BadRequest("Vui lòng nhập nội dung.");
            if (content.Length > 2000) return BadRequest("Nội dung quá dài.");
            if (input == null || input.UserID <= 0) return BadRequest("Vui lòng đăng nhập để bình luận.");

            var userName = await _context.Users
                .AsNoTracking()
                .Where(u => u.UserID == input.UserID)
                .Select(u => u.FullName)
                .FirstOrDefaultAsync();
            if (string.IsNullOrWhiteSpace(userName)) return BadRequest("Tài khoản không hợp lệ.");

            var avatarUrl = await _context.Users
                .AsNoTracking()
                .Where(u => u.UserID == input.UserID)
                .Select(u => u.AvatarUrl)
                .FirstOrDefaultAsync();

            if (input.ParentCommentID.HasValue)
            {
                var parentOk = await _context.BlogComments
                    .AsNoTracking()
                    .AnyAsync(c => c.BlogCommentID == input.ParentCommentID.Value && c.BlogPostID == postId);
                if (!parentOk) return BadRequest("Bình luận trả lời không hợp lệ.");
            }

            var row = new BlogComment
            {
                BlogPostID = postId,
                UserID = input.UserID,
                ParentCommentID = input.ParentCommentID,
                Content = content,
                CreatedAt = DateTime.UtcNow
            };

            _context.BlogComments.Add(row);
            await _context.SaveChangesAsync();

            var dto = new BlogCommentDto
            {
                BlogCommentID = row.BlogCommentID,
                BlogPostID = row.BlogPostID,
                UserID = row.UserID,
                ParentCommentID = row.ParentCommentID,
                UserName = userName,
                AvatarUrl = avatarUrl,
                Content = row.Content,
                CreatedAt = row.CreatedAt
            };

            return Ok(dto);
        }
    }
}

