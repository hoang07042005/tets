using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using freshfood_be.Data;
using freshfood_be.Services.Media;

namespace freshfood_be.Controllers;

[Authorize(Roles = "Admin")]
[Route("api/Admin/ReturnRequests")]
[ApiController]
public class AdminReturnRequestsController : ControllerBase
{
    private readonly FreshFoodContext _context;
    private readonly IWebHostEnvironment _env;
    private readonly freshfood_be.Services.Security.IdTokenService _idTokens;
    private readonly IImageStorage _images;

    public AdminReturnRequestsController(FreshFoodContext context, IWebHostEnvironment env, freshfood_be.Services.Security.IdTokenService idTokens, IImageStorage images)
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

    public record ReturnImageDto(int ReturnRequestImageID, string ImageUrl);
    public record ReturnRequestDto(
        int ReturnRequestID,
        int OrderID,
        int UserID,
        string Status,
        string RequestType,
        string Reason,
        string? AdminNote,
        string? VideoUrl,
        string? RefundProofUrl,
        string? RefundNote,
        DateTime CreatedAt,
        DateTime? ReviewedAt,
        IReadOnlyList<ReturnImageDto> Images);

    public record UpdateReturnStatusDto(string Status, string? AdminNote);

    public record RecentReturnRequestRowDto(
        int ReturnRequestID,
        int OrderID,
        string OrderToken,
        string OrderCode,
        int UserID,
        string CustomerName,
        string Status,
        string RequestType,
        string Reason,
        DateTime CreatedAt
    );

    // GET: api/Admin/ReturnRequests/Recent?take=4
    [HttpGet("Recent")]
    public async Task<ActionResult<IReadOnlyList<RecentReturnRequestRowDto>>> Recent([FromQuery] int take = 4)
    {
        take = Math.Clamp(take, 1, 20);

        var rowsRaw = await _context.ReturnRequests
            .AsNoTracking()
            .Include(r => r.Order!)
                .ThenInclude(o => o.User)
            // Dashboard should show only pending requests (need action).
            .Where(r => !string.IsNullOrWhiteSpace(r.Status) && r.Status.Trim().ToLower() == "pending")
            .OrderByDescending(r => r.CreatedAt)
            .Take(take)
            .Select(r => new RecentReturnRequestRowDto(
                r.ReturnRequestID,
                r.OrderID,
                "",
                r.Order != null ? (r.Order.OrderCode ?? $"#{r.OrderID}") : $"#{r.OrderID}",
                r.UserID,
                r.Order != null && r.Order.User != null ? r.Order.User.FullName : $"User #{r.UserID}",
                r.Status,
                r.RequestType,
                r.Reason,
                r.CreatedAt
            ))
            .ToListAsync();

        var rows = rowsRaw
            .Select(r => r with { OrderToken = _idTokens.ProtectOrderId(r.OrderID) })
            .ToList();

        return Ok(rows);
    }

    [HttpGet("ByOrder/{orderId:int}")]
    public async Task<ActionResult<ReturnRequestDto?>> GetByOrder(int orderId)
    {
        var rr = await _context.ReturnRequests
            .AsNoTracking()
            .Include(r => r.Images)
            .Where(r => r.OrderID == orderId)
            .OrderByDescending(r => r.CreatedAt)
            .FirstOrDefaultAsync();

        if (rr == null) return Ok(null);

        return Ok(new ReturnRequestDto(
            rr.ReturnRequestID,
            rr.OrderID,
            rr.UserID,
            rr.Status,
            rr.RequestType,
            rr.Reason,
            rr.AdminNote,
            rr.VideoUrl,
            rr.RefundProofUrl,
            rr.RefundNote,
            rr.CreatedAt,
            rr.ReviewedAt,
            (rr.Images ?? new List<freshfood_be.Models.ReturnRequestImage>())
                .Select(i => new ReturnImageDto(i.ReturnRequestImageID, i.ImageUrl))
                .ToList()
        ));
    }

    [HttpPut("{id:int}/Status")]
    public async Task<IActionResult> UpdateStatus(int id, [FromBody] UpdateReturnStatusDto dto)
    {
        var rr = await _context.ReturnRequests.Include(r => r.Images).FirstOrDefaultAsync(r => r.ReturnRequestID == id);
        if (rr == null) return NotFound();

        var st = (dto.Status ?? "").Trim();
        if (string.IsNullOrWhiteSpace(st)) return BadRequest("Missing status.");

        var lower = st.ToLowerInvariant();
        if (lower != "pending" && lower != "approved" && lower != "rejected")
            return BadRequest("Invalid status. Allowed: Pending, Approved, Rejected.");

        if (lower == "approved" && string.IsNullOrWhiteSpace(dto.AdminNote))
            return BadRequest("Admin note is required to approve a return request.");

        rr.Status = st;
        rr.AdminNote = string.IsNullOrWhiteSpace(dto.AdminNote) ? null : dto.AdminNote.Trim();
        rr.ReviewedAt = DateTime.UtcNow;

        // Sync Order.Status for "Return goods" workflow only.
        var order = await _context.Orders.FirstOrDefaultAsync(o => o.OrderID == rr.OrderID);
        if (order != null)
        {
            var rt = (rr.RequestType ?? "").Trim();
            var rtLower = rt.ToLowerInvariant();
            if (lower == "approved" && rtLower == "return")
            {
                order.Status = "Returned";
            }
        }

        await _context.SaveChangesAsync();

        return NoContent();
    }

    [HttpPost("{id:int}/RefundProof")]
    [Consumes("multipart/form-data")]
    [RequestSizeLimit(10_000_000)]
    public async Task<ActionResult<object>> UploadRefundProof([FromRoute] int id, [FromForm] IFormFile file, [FromForm] string? refundNote)
    {
        var rr = await _context.ReturnRequests.FirstOrDefaultAsync(r => r.ReturnRequestID == id);
        if (rr == null) return NotFound();

        var st = (rr.Status ?? "").Trim().ToLowerInvariant();
        if (st != "approved") return BadRequest("Only approved return requests can upload refund proof.");

        var note = (refundNote ?? "").Trim();
        if (string.IsNullOrWhiteSpace(note)) return BadRequest("Refund note is required (message to customer with the proof).");
        if (note.Length > 2000) return BadRequest("Refund note is too long.");

        if (file == null || file.Length == 0) return BadRequest("Missing file.");
        var ext = Path.GetExtension(file.FileName).ToLowerInvariant();
        var allowed = new HashSet<string> { ".jpg", ".jpeg", ".png", ".webp", ".gif", ".jfif" };
        if (!allowed.Contains(ext)) return BadRequest($"Unsupported image extension: {ext}.");
        if (string.IsNullOrWhiteSpace(file.ContentType) || !file.ContentType.StartsWith("image/", StringComparison.OrdinalIgnoreCase))
            return BadRequest("Only image files are allowed.");

        if (_images.IsEnabled)
        {
            rr.RefundProofUrl = await _images.UploadImageAsync($"return-refund-proofs/{rr.OrderID}/{rr.ReturnRequestID}", file, HttpContext.RequestAborted);
        }
        else
        {
            var safeName = $"{DateTime.UtcNow:yyyyMMddHHmmssfff}{ext}";
            var dir = Path.Combine(GetMediaRoot(), "return-refund-proofs", rr.OrderID.ToString(), rr.ReturnRequestID.ToString());
            Directory.CreateDirectory(dir);
            var fullPath = Path.Combine(dir, safeName);
            await using (var fs = System.IO.File.Create(fullPath))
            {
                await file.CopyToAsync(fs);
            }
            rr.RefundProofUrl = $"/return-refund-proofs/{rr.OrderID}/{rr.ReturnRequestID}/{safeName}";
        }
        rr.RefundNote = note;
        rr.ReviewedAt ??= DateTime.UtcNow;

        // If refund proof uploaded, mark order as refunded for correct display.
        var order = await _context.Orders.FirstOrDefaultAsync(o => o.OrderID == rr.OrderID);
        if (order != null)
        {
            var rt = (rr.RequestType ?? "").Trim().ToLowerInvariant();
            // Only the "return goods" workflow should overwrite the order pipeline status.
            // For CancelRefund (refund after customer cancellation), keep Order.Status = Cancelled
            // and rely on derived status (RefundPending/Refunded) for display in lists.
            if (rt == "return")
            {
                order.Status = "Refunded";
            }
        }

        await _context.SaveChangesAsync();

        return Ok(new { rr.RefundProofUrl, rr.RefundNote });
    }

    public record UpdateRefundNoteDto(string? Note);

    public record SyncReturnOrderStatusesResult(int scannedOrders, int updatedOrders);

    /// <summary>
    /// Backfill Order.Status for existing return requests (older data).
    /// Rule:
    /// - Latest approved return request with RefundProofUrl => Order.Status = "Refunded"
    /// - Latest approved return request without RefundProofUrl => Order.Status = "Returned"
    /// </summary>
    [HttpPost("SyncOrderStatuses")]
    public async Task<ActionResult<SyncReturnOrderStatusesResult>> SyncOrderStatuses([FromQuery] int take = 500)
    {
        take = Math.Clamp(take, 1, 5000);

        // Get latest return request per order (most recent)
        var latest = await _context.ReturnRequests
            .AsNoTracking()
            .GroupBy(r => r.OrderID)
            .Select(g => g.OrderByDescending(x => x.CreatedAt).FirstOrDefault())
            .Where(x => x != null)
            .Take(take)
            .ToListAsync();

        var orderIds = latest.Select(x => x!.OrderID).Distinct().ToList();
        var orders = await _context.Orders.Where(o => orderIds.Contains(o.OrderID)).ToListAsync();

        var updated = 0;
        foreach (var rr in latest)
        {
            if (rr == null) continue;
            var st = (rr.Status ?? "").Trim().ToLowerInvariant();
            if (st != "approved") continue;

            var order = orders.FirstOrDefault(o => o.OrderID == rr.OrderID);
            if (order == null) continue;

            var rt = (rr.RequestType ?? "").Trim().ToLowerInvariant();
            if (rt != "return") continue;

            var next = string.IsNullOrWhiteSpace(rr.RefundProofUrl) ? "Returned" : "Refunded";
            if (!string.Equals(order.Status ?? "", next, StringComparison.OrdinalIgnoreCase))
            {
                order.Status = next;
                updated++;
            }
        }

        if (updated > 0)
            await _context.SaveChangesAsync();

        return Ok(new SyncReturnOrderStatusesResult(orderIds.Count, updated));
    }

    [HttpPut("{id:int}/RefundNote")]
    public async Task<IActionResult> UpdateRefundNote(int id, [FromBody] UpdateRefundNoteDto dto)
    {
        var rr = await _context.ReturnRequests.FirstOrDefaultAsync(r => r.ReturnRequestID == id);
        if (rr == null) return NotFound();

        var st = (rr.Status ?? "").Trim().ToLowerInvariant();
        if (st != "approved") return BadRequest("Only approved return requests can update refund note.");
        if (string.IsNullOrWhiteSpace(rr.RefundProofUrl)) return BadRequest("Upload refund proof first.");

        var note = (dto.Note ?? "").Trim();
        if (string.IsNullOrWhiteSpace(note)) return BadRequest("Note is required.");
        if (note.Length > 2000) return BadRequest("Note is too long.");

        rr.RefundNote = note;
        await _context.SaveChangesAsync();
        return NoContent();
    }
}

