using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using freshfood_be.Data;
using System.IO;
using freshfood_be.Services.Media;

namespace freshfood_be.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    public class ReviewsController : ControllerBase
    {
        private readonly FreshFoodContext _context;
        private readonly IWebHostEnvironment _env;
        private readonly IImageStorage _images;

        public ReviewsController(FreshFoodContext context, IWebHostEnvironment env, IImageStorage images)
        {
            _context = context;
            _env = env;
            _images = images;
        }

        private string GetMediaRoot()
        {
            var configured = (Environment.GetEnvironmentVariable("MEDIA_ROOT") ?? string.Empty).Trim();
            return string.IsNullOrWhiteSpace(configured)
                ? Path.Combine(_env.ContentRootPath, "wwwroot")
                : configured;
        }

        public sealed record ReviewDto(
            int ReviewID,
            int ProductID,
            int UserID,
            string UserName,
            string? AvatarUrl,
            int Rating,
            string? Comment,
            DateTime ReviewDate,
            IEnumerable<string> ImageUrls,
            string ModerationStatus
        );

        // GET: api/Reviews/Recent?take=3
        [HttpGet("Recent")]
        public async Task<ActionResult<IEnumerable<ReviewDto>>> GetRecent([FromQuery] int take = 3)
        {
            take = Math.Clamp(take, 1, 10);

            var reviews = await _context.Reviews
                .AsNoTracking()
                .Include(r => r.User)
                .Include(r => r.ReviewImages)
                .Where(r => !r.IsDeleted && r.ModerationStatus == "Approved")
                .OrderByDescending(r => r.ReviewDate)
                .Take(take)
                .Select(r => new ReviewDto(
                    r.ReviewID,
                    r.ProductID,
                    r.UserID,
                    r.User != null ? r.User.FullName : "Khách hàng",
                    r.User != null ? r.User.AvatarUrl : null,
                    r.Rating,
                    r.Comment,
                    r.ReviewDate,
                    r.ReviewImages
                        .OrderBy(ri => ri.SortOrder)
                        .Select(ri => ri.ImageUrl),
                    r.ModerationStatus
                ))
                .ToListAsync();

            return reviews;
        }

        public sealed record RatingSummaryDto(double AverageRating, int TotalReviews);

        public sealed record CreateReviewRequest(
            int ProductID,
            int UserID,
            int Rating,
            string? Comment,
            IEnumerable<string>? ImageUrls
        );

        // POST: api/Reviews/UploadImages
        // Upload tối đa 3 ảnh, trả về URL (có thể bỏ qua ảnh vẫn đánh giá được)
        [Authorize]
        [HttpPost("UploadImages")]
        [RequestSizeLimit(15_000_000)] // ~15MB
        public async Task<ActionResult<IEnumerable<string>>> UploadImages([FromForm] List<IFormFile> files)
        {
            if (files == null || files.Count == 0) return Ok(Array.Empty<string>());
            if (files.Count > 3) return BadRequest("Maximum 3 images.");

            var urls = new List<string>();
            foreach (var f in files)
            {
                if (f.Length == 0) continue;
                if (string.IsNullOrWhiteSpace(f.ContentType) || !f.ContentType.StartsWith("image/", StringComparison.OrdinalIgnoreCase))
                    return BadRequest("Only image files are allowed.");

                var ext = Path.GetExtension(f.FileName);
                if (string.IsNullOrWhiteSpace(ext)) ext = ".jpg";

                if (_images.IsEnabled)
                {
                    var remote = await _images.UploadImageAsync("review-images", f, HttpContext.RequestAborted);
                    urls.Add(remote);
                }
                else
                {
                    var root = Path.Combine(GetMediaRoot(), "review-images");
                    Directory.CreateDirectory(root);
                    var fileName = $"{Guid.NewGuid():N}{ext}";
                    var fullPath = Path.Combine(root, fileName);
                    await using (var stream = System.IO.File.Create(fullPath))
                    {
                        await f.CopyToAsync(stream);
                    }
                    urls.Add($"/review-images/{fileName}");
                }
            }

            return Ok(urls);
        }

        // POST: api/Reviews
        [Authorize]
        [HttpPost]
        public async Task<ActionResult<ReviewDto>> PostReview([FromBody] CreateReviewRequest req)
        {
            var claimId = User?.FindFirstValue(ClaimTypes.NameIdentifier) ?? User?.FindFirstValue("sub");
            if (!int.TryParse(claimId, out var authId) || authId <= 0) return Forbid();
            if (req.UserID != authId) return Forbid();

            if (req.Rating < 1 || req.Rating > 5) return BadRequest("Rating must be between 1 and 5.");
            if (req.Comment != null && req.Comment.Length > 1000) return BadRequest("Comment is too long (max 1000).");

            var productExists = await _context.Products.AsNoTracking().AnyAsync(p => p.ProductID == req.ProductID);
            if (!productExists) return BadRequest("Product not found.");

            var user = await _context.Users.AsNoTracking().FirstOrDefaultAsync(u => u.UserID == req.UserID);
            if (user == null) return BadRequest("User not found.");

            // Anti-spam: chỉ cho review khi user đã mua và đơn đã giao/hoàn tất.
            // Lưu ý: FE đang hiển thị "Completed", còn pipeline admin dùng "Delivered" trước khi khách xác nhận nhận hàng.
            var deliveredStatuses = new[]
            {
                "delivered", "completed",
                "đã giao", "da giao", "da_giao",
                "hoàn tất", "hoan tat",
                "hoàn thành", "hoan thanh"
            };
            var hasDeliveredPurchase = await _context.Orders
                .AsNoTracking()
                .Where(o => o.UserID == req.UserID)
                .Where(o => o.Status != null && deliveredStatuses.Contains(o.Status.ToLower()))
                .Where(o => o.OrderDetails.Any(d => d.ProductID == req.ProductID))
                .AnyAsync();

            if (!hasDeliveredPurchase)
            {
                return BadRequest("Bạn chỉ có thể đánh giá sau khi đơn hàng đã được giao.");
            }

            // Anti-spam: chặn spam nhiều lần cho cùng sản phẩm trong thời gian ngắn.
            var last = await _context.Reviews
                .AsNoTracking()
                .Where(r => r.UserID == req.UserID && r.ProductID == req.ProductID)
                .OrderByDescending(r => r.ReviewDate)
                .Select(r => new { r.ReviewID, r.ReviewDate })
                .FirstOrDefaultAsync();

            if (last != null && (DateTime.Now - last.ReviewDate).TotalHours < 24)
            {
                return BadRequest("Bạn đã đánh giá sản phẩm này gần đây. Vui lòng thử lại sau.");
            }

            var imageUrls = (req.ImageUrls ?? Array.Empty<string>())
                .Where(u => !string.IsNullOrWhiteSpace(u))
                .Take(3)
                .ToList();

            var review = new Models.Review
            {
                ProductID = req.ProductID,
                UserID = req.UserID,
                Rating = req.Rating,
                Comment = req.Comment,
                ReviewDate = DateTime.Now,
                ModerationStatus = "Pending"
            };

            _context.Reviews.Add(review);
            await _context.SaveChangesAsync();

            if (imageUrls.Count > 0)
            {
                var imgs = imageUrls.Select((url, idx) => new Models.ReviewImage
                {
                    ReviewID = review.ReviewID,
                    ImageUrl = url.Trim(),
                    SortOrder = idx
                });
                _context.ReviewImages.AddRange(imgs);
                await _context.SaveChangesAsync();
            }

            var dto = new ReviewDto(
                review.ReviewID,
                review.ProductID,
                review.UserID,
                user?.FullName ?? "Khách hàng",
                user?.AvatarUrl,
                review.Rating,
                review.Comment,
                review.ReviewDate,
                imageUrls,
                review.ModerationStatus
            );

            return CreatedAtAction(nameof(GetRecent), new { take = 1 }, dto);
        }

        // GET: api/Reviews/Summary
        [HttpGet("Summary")]
        public async Task<ActionResult<RatingSummaryDto>> GetSummary()
        {
            var total = await _context.Reviews.CountAsync(r => !r.IsDeleted && r.ModerationStatus == "Approved");
            if (total == 0) return new RatingSummaryDto(0, 0);

            var avg = await _context.Reviews
                .Where(r => !r.IsDeleted && r.ModerationStatus == "Approved")
                .AverageAsync(r => (double)r.Rating);
            return new RatingSummaryDto(Math.Round(avg, 1), total);
        }
    }
}

