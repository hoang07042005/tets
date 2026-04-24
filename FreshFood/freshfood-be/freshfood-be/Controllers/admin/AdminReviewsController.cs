using freshfood_be.Data;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace freshfood_be.Controllers;

/// <summary>Admin Reviews moderation — api/Admin/Reviews</summary>
[Authorize(Roles = "Admin")]
[Route("api/Admin/Reviews")]
[ApiController]
public class AdminReviewsController : ControllerBase
{
    private readonly FreshFoodContext _context;
    private readonly freshfood_be.Services.Security.IdTokenService _idTokens;

    public AdminReviewsController(FreshFoodContext context, freshfood_be.Services.Security.IdTokenService idTokens)
    {
        _context = context;
        _idTokens = idTokens;
    }

    public record AdminReviewRowDto(
        int ReviewID,
        int ProductID,
        string? ProductToken,
        string ProductName,
        string? ProductSku,
        string? ProductThumbUrl,
        int UserID,
        string UserName,
        string? UserAvatarUrl,
        string? UserEmail,
        int Rating,
        string? Comment,
        DateTime ReviewDate,
        IReadOnlyList<string> ImageUrls,
        string ModerationStatus,
        DateTime? ModeratedAt,
        string? ModerationNote,
        string? AdminReply,
        DateTime? RepliedAt,
        bool IsDeleted,
        DateTime? DeletedAt
    );

    public record AdminReviewListResponse(
        int Total,
        IReadOnlyList<AdminReviewRowDto> Items
    );

    public record AdminReviewStatsDto(
        int Total,
        int Pending,
        int Approved,
        int Hidden,
        int Deleted,
        int Replied,
        int RepliedPercent
    );

    // GET: api/Admin/Reviews/stats
    [HttpGet("stats")]
    public async Task<ActionResult<AdminReviewStatsDto>> Stats()
    {
        var q = _context.Reviews.AsNoTracking();

        var total = await q.CountAsync(r => !r.IsDeleted);
        var pending = await q.CountAsync(r => !r.IsDeleted && r.ModerationStatus == "Pending");
        var approved = await q.CountAsync(r => !r.IsDeleted && r.ModerationStatus == "Approved");
        var hidden = await q.CountAsync(r => !r.IsDeleted && r.ModerationStatus == "Hidden");
        var deleted = await q.CountAsync(r => r.IsDeleted);
        var replied = await q.CountAsync(r => !r.IsDeleted && r.AdminReply != null && r.AdminReply.Trim() != "");

        var repliedPercent = total == 0 ? 0 : (int)Math.Round(replied * 100.0 / total, MidpointRounding.AwayFromZero);

        return Ok(new AdminReviewStatsDto(total, pending, approved, hidden, deleted, replied, repliedPercent));
    }

    // GET: api/Admin/Reviews?status=pending&q=...&skip=0&take=30
    [HttpGet]
    public async Task<ActionResult<AdminReviewListResponse>> List(
        [FromQuery] string? status = "pending",
        [FromQuery] string? q = null,
        [FromQuery] int skip = 0,
        [FromQuery] int take = 30)
    {
        skip = Math.Max(0, skip);
        take = Math.Clamp(take, 1, 200);

        var s = (status ?? "pending").Trim().ToLowerInvariant();
        var normalizedStatus = s switch
        {
            "approved" => "Approved",
            "hidden" => "Hidden",
            "deleted" => "Deleted",
            _ => "Pending"
        };

        var query = _context.Reviews
            .AsNoTracking()
            .Include(r => r.User)
            .Include(r => r.Product)
                .ThenInclude(p => p!.ProductImages)
            .Include(r => r.ReviewImages)
            .Where(r => normalizedStatus == "Deleted" ? r.IsDeleted : (!r.IsDeleted && r.ModerationStatus == normalizedStatus));

        if (!string.IsNullOrWhiteSpace(q))
        {
            var kw = q.Trim();
            query = query.Where(r =>
                (r.Comment != null && r.Comment.Contains(kw)) ||
                (r.User != null && r.User.FullName.Contains(kw)) ||
                (r.User != null && r.User.Email.Contains(kw)) ||
                (r.Product != null && r.Product.ProductName.Contains(kw)));
        }

        var total = await query.CountAsync();
        var rows = await query
            .OrderByDescending(r => r.ReviewDate)
            .Skip(skip)
            .Take(take)
            .Select(r => new AdminReviewRowDto(
                r.ReviewID,
                r.ProductID,
                _idTokens.ProtectProductId(r.ProductID),
                r.Product != null ? r.Product.ProductName : $"Sản phẩm #{r.ProductID}",
                r.Product != null && !string.IsNullOrWhiteSpace(r.Product.Sku) ? r.Product.Sku!.Trim() : null,
                r.Product != null
                    ? (r.Product.ProductImages.Where(pi => pi.IsMainImage).Select(pi => pi.ImageURL).FirstOrDefault()
                        ?? r.Product.ProductImages.Select(pi => pi.ImageURL).FirstOrDefault())
                    : null,
                r.UserID,
                r.User != null ? r.User.FullName : $"User #{r.UserID}",
                r.User != null && !string.IsNullOrWhiteSpace(r.User.AvatarUrl) ? r.User.AvatarUrl : null,
                r.User != null ? r.User.Email : null,
                r.Rating,
                r.Comment,
                r.ReviewDate,
                r.ReviewImages.OrderBy(x => x.SortOrder).Select(x => x.ImageUrl).ToList(),
                r.ModerationStatus,
                r.ModeratedAt,
                r.ModerationNote,
                r.AdminReply,
                r.RepliedAt,
                r.IsDeleted,
                r.DeletedAt
            ))
            .ToListAsync();

        return Ok(new AdminReviewListResponse(total, rows));
    }

    public record SetModerationRequest(string? Note);

    public record SetReplyRequest(string? Reply);

    // PATCH: api/Admin/Reviews/{id}/approve
    [HttpPatch("{id:int}/approve")]
    public async Task<IActionResult> Approve(int id, [FromBody] SetModerationRequest? req)
    {
        var review = await _context.Reviews.FirstOrDefaultAsync(r => r.ReviewID == id);
        if (review == null) return NotFound();
        if (review.IsDeleted) return BadRequest("Review is deleted.");

        review.ModerationStatus = "Approved";
        review.ModeratedAt = DateTime.UtcNow;
        review.ModerationNote = string.IsNullOrWhiteSpace(req?.Note) ? null : req!.Note!.Trim();

        await _context.SaveChangesAsync();
        return NoContent();
    }

    // PATCH: api/Admin/Reviews/{id}/hide
    [HttpPatch("{id:int}/hide")]
    public async Task<IActionResult> Hide(int id, [FromBody] SetModerationRequest? req)
    {
        var review = await _context.Reviews.FirstOrDefaultAsync(r => r.ReviewID == id);
        if (review == null) return NotFound();
        if (review.IsDeleted) return BadRequest("Review is deleted.");

        review.ModerationStatus = "Hidden";
        review.ModeratedAt = DateTime.UtcNow;
        review.ModerationNote = string.IsNullOrWhiteSpace(req?.Note) ? null : req!.Note!.Trim();

        await _context.SaveChangesAsync();
        return NoContent();
    }

    // PATCH: api/Admin/Reviews/{id}/pending
    [HttpPatch("{id:int}/pending")]
    public async Task<IActionResult> SetPending(int id, [FromBody] SetModerationRequest? req)
    {
        var review = await _context.Reviews.FirstOrDefaultAsync(r => r.ReviewID == id);
        if (review == null) return NotFound();
        if (review.IsDeleted) return BadRequest("Review is deleted.");

        review.ModerationStatus = "Pending";
        review.ModeratedAt = DateTime.UtcNow;
        review.ModerationNote = string.IsNullOrWhiteSpace(req?.Note) ? null : req!.Note!.Trim();

        await _context.SaveChangesAsync();
        return NoContent();
    }

    // PATCH: api/Admin/Reviews/{id}/reply
    [HttpPatch("{id:int}/reply")]
    public async Task<IActionResult> SetReply(int id, [FromBody] SetReplyRequest? req)
    {
        var review = await _context.Reviews.FirstOrDefaultAsync(r => r.ReviewID == id);
        if (review == null) return NotFound();
        if (review.IsDeleted) return BadRequest("Review is deleted.");

        var reply = (req?.Reply ?? "").Trim();
        if (reply.Length > 2000) return BadRequest("Reply is too long (max 2000).");

        review.AdminReply = string.IsNullOrWhiteSpace(reply) ? null : reply;
        review.RepliedAt = string.IsNullOrWhiteSpace(reply) ? null : DateTime.UtcNow;
        await _context.SaveChangesAsync();
        return NoContent();
    }

    // DELETE: api/Admin/Reviews/{id}
    [HttpDelete("{id:int}")]
    public async Task<IActionResult> Delete(int id)
    {
        var review = await _context.Reviews.FirstOrDefaultAsync(r => r.ReviewID == id);
        if (review == null) return NotFound();

        if (review.IsDeleted) return NoContent();

        // Soft delete (allow restore).
        review.IsDeleted = true;
        review.DeletedAt = DateTime.UtcNow;
        await _context.SaveChangesAsync();
        return NoContent();
    }

    // PATCH: api/Admin/Reviews/{id}/restore
    [HttpPatch("{id:int}/restore")]
    public async Task<IActionResult> Restore(int id)
    {
        var review = await _context.Reviews.FirstOrDefaultAsync(r => r.ReviewID == id);
        if (review == null) return NotFound();

        if (!review.IsDeleted) return NoContent();
        review.IsDeleted = false;
        review.DeletedAt = null;
        await _context.SaveChangesAsync();
        return NoContent();
    }
}

