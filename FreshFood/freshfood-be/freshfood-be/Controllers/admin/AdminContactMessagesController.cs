using System.ComponentModel.DataAnnotations;
using System.Net;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using freshfood_be.Data;
using freshfood_be.Services.Email;
using Microsoft.Extensions.Options;

namespace freshfood_be.Controllers;

/// <summary>Admin — danh sách tin liên hệ từ form công khai.</summary>
[Authorize(Roles = "Admin")]
[Route("api/Admin/ContactMessages")]
[ApiController]
public class AdminContactMessagesController : ControllerBase
{
    private readonly FreshFoodContext _context;
    private readonly IEmailSender _emailSender;
    private readonly EmailSettings _emailSettings;
    private readonly ILogger<AdminContactMessagesController> _logger;
    private readonly IWebHostEnvironment _env;
    private readonly IConfiguration _config;

    public AdminContactMessagesController(
        FreshFoodContext context,
        IEmailSender emailSender,
        IOptions<EmailSettings> emailOptions,
        ILogger<AdminContactMessagesController> logger,
        IWebHostEnvironment env,
        IConfiguration config)
    {
        _context = context;
        _emailSender = emailSender;
        _emailSettings = emailOptions.Value;
        _logger = logger;
        _env = env;
        _config = config;
    }

    public record ContactMessageListItemDto(
        int ContactMessageID,
        string Name,
        string Email,
        string Subject,
        string MessagePreview,
        DateTime CreatedAt,
        string Status,
        bool IsUrgent);

    public record AdminContactMessagesPageDto(
        IReadOnlyList<ContactMessageListItemDto> Items,
        int TotalCount,
        int Page,
        int PageSize);

    public record ContactMessageDetailDto(
        int ContactMessageID,
        string Name,
        string Email,
        string Subject,
        string Message,
        DateTime CreatedAt,
        string Status,
        bool IsUrgent);

    private static string Preview(string? message, int maxLen = 160)
    {
        if (string.IsNullOrEmpty(message)) return string.Empty;
        var oneLine = message.Replace("\r\n", " ").Replace('\n', ' ').Replace('\r', ' ');
        while (oneLine.Contains("  ", StringComparison.Ordinal))
            oneLine = oneLine.Replace("  ", " ", StringComparison.Ordinal);
        oneLine = oneLine.Trim();
        if (oneLine.Length <= maxLen) return oneLine;
        return oneLine[..maxLen].TrimEnd() + "…";
    }

    [HttpGet]
    public async Task<ActionResult<AdminContactMessagesPageDto>> GetPage(
        [FromQuery] int page = 1,
        [FromQuery] int pageSize = 15,
        [FromQuery] string? q = null,
        [FromQuery] string? status = null,
        CancellationToken ct = default)
    {
        page = page < 1 ? 1 : page;
        pageSize = pageSize is < 1 or > 100 ? 15 : pageSize;

        var query = _context.ContactMessages.AsNoTracking().AsQueryable();
        var term = (q ?? string.Empty).Trim();
        if (term.Length > 0)
        {
            query = query.Where(m =>
                m.Name.Contains(term) ||
                m.Email.Contains(term) ||
                m.Subject.Contains(term) ||
                m.Message.Contains(term));
        }

        var sf = (status ?? "all").Trim().ToLowerInvariant();
        if (sf is "new" or "mới")
            query = query.Where(m => m.Status == "New");
        else if (sf is "processing" or "dangxuly" or "đangxửlý")
            query = query.Where(m => m.Status == "Processing");
        else if (sf is "replied" or "datraloi" or "đãtrảlời")
            query = query.Where(m => m.Status == "Replied");

        var total = await query.CountAsync(ct);
        var rows = await query
            .OrderByDescending(m => m.CreatedAt)
            .Skip((page - 1) * pageSize)
            .Take(pageSize)
            .Select(m => new
            {
                m.ContactMessageID,
                m.Name,
                m.Email,
                m.Subject,
                m.Message,
                m.CreatedAt,
                m.Status,
                m.IsUrgent
            })
            .ToListAsync(ct);

        var items = rows
            .Select(m => new ContactMessageListItemDto(
                m.ContactMessageID,
                m.Name,
                m.Email,
                m.Subject,
                Preview(m.Message),
                m.CreatedAt,
                m.Status,
                m.IsUrgent))
            .ToList();

        return new AdminContactMessagesPageDto(items, total, page, pageSize);
    }

    [HttpGet("{id:int}")]
    public async Task<ActionResult<ContactMessageDetailDto>> GetOne(int id, CancellationToken ct)
    {
        var m = await _context.ContactMessages
            .AsNoTracking()
            .Where(x => x.ContactMessageID == id)
            .Select(x => new ContactMessageDetailDto(
                x.ContactMessageID,
                x.Name,
                x.Email,
                x.Subject,
                x.Message,
                x.CreatedAt,
                x.Status,
                x.IsUrgent))
            .FirstOrDefaultAsync(ct);

        if (m == null) return NotFound();
        return m;
    }

    public record UpdateContactMessageStatusDto
    {
        [Required]
        public string Status { get; set; } = string.Empty;
    }

    private static string? NormalizeContactStatus(string? raw)
    {
        var x = (raw ?? string.Empty).Trim();
        if (x.Equals("New", StringComparison.OrdinalIgnoreCase)) return "New";
        if (x.Equals("Processing", StringComparison.OrdinalIgnoreCase)) return "Processing";
        if (x.Equals("Replied", StringComparison.OrdinalIgnoreCase)) return "Replied";
        return null;
    }

    /// <summary>Đánh dấu trạng thái xử lý (Mới / Đang xử lý / Đã trả lời).</summary>
    [HttpPatch("{id:int}/status")]
    public async Task<IActionResult> PatchStatus(int id, [FromBody] UpdateContactMessageStatusDto dto, CancellationToken ct)
    {
        if (!ModelState.IsValid)
            return ValidationProblem(ModelState);

        var norm = NormalizeContactStatus(dto.Status);
        if (norm == null)
            return BadRequest("Status phải là New, Processing hoặc Replied.");

        var entity = await _context.ContactMessages.FirstOrDefaultAsync(x => x.ContactMessageID == id, ct);
        if (entity == null) return NotFound();

        entity.Status = norm;
        await _context.SaveChangesAsync(ct);
        return NoContent();
    }

    public class ReplyContactMessageDto
    {
        [Required, StringLength(300)]
        public string Subject { get; set; } = string.Empty;

        [Required, MinLength(2), StringLength(8000)]
        public string Message { get; set; } = string.Empty;

        /// <summary>Nếu true, đính kèm nội dung tin nhắn gốc ở cuối email.</summary>
        public bool IncludeOriginal { get; set; } = true;
    }

    /// <summary>Gửi email trả lời cho người đã liên hệ.</summary>
    [HttpPost("{id:int}/reply")]
    public async Task<ActionResult<object>> Reply(int id, [FromBody] ReplyContactMessageDto dto, CancellationToken ct)
    {
        if (!ModelState.IsValid)
            return ValidationProblem(ModelState);

        var m = await _context.ContactMessages.FirstOrDefaultAsync(x => x.ContactMessageID == id, ct);

        if (m == null) return NotFound();

        if (string.IsNullOrWhiteSpace(_emailSettings.Host) || string.IsNullOrWhiteSpace(_emailSettings.FromEmail))
            return Problem("SMTP chưa được cấu hình (Email:Host / Email:FromEmail).", statusCode: 500);

        var to = (m.Email ?? string.Empty).Trim();
        if (string.IsNullOrWhiteSpace(to))
            return Problem("Không có email người liên hệ để gửi.", statusCode: 400);

        var subject = (dto.Subject ?? string.Empty).Trim();
        var body = (dto.Message ?? string.Empty).Trim();

        var safeReply = WebUtility.HtmlEncode(body).Replace("\r\n", "<br/>").Replace("\n", "<br/>");
        var safeName = WebUtility.HtmlEncode(m.Name ?? string.Empty);
        var safeEmail = WebUtility.HtmlEncode(m.Email ?? string.Empty);
        var safeSubject = WebUtility.HtmlEncode(m.Subject ?? string.Empty);
        var safeOriginal = WebUtility.HtmlEncode(m.Message ?? string.Empty).Replace("\r\n", "<br/>").Replace("\n", "<br/>");
        var created = m.CreatedAt.ToLocalTime().ToString("dd/MM/yyyy HH:mm");

        var apiBase = (_config["Backend:PublicUrl"] ?? "").Trim();
        if (string.IsNullOrWhiteSpace(apiBase))
        {
            apiBase = $"{Request.Scheme}://{Request.Host}";
        }

        var linked = new List<EmailLinkedResource>();
        var logoSrc = await EmailInlineAssets.ResolveLogoSrcAsync(_env, _config, linked, apiBase, ct);

        // Preheader text (hidden in body but shown in inbox preview).
        var preheader = WebUtility.HtmlEncode($"FreshFood đã nhận và phản hồi liên hệ của bạn: {m.Subject}".Trim());

        var html = $"""
            <div style="display:none!important;max-height:0;overflow:hidden;opacity:0;color:transparent">{preheader}</div>
            <div style="background:#f6f7fb;padding:22px 0">
              <div style="width:100%;max-width:640px;margin:0 auto;padding:0 14px">
                <div style="background:#ffffff;border:1px solid rgba(15,23,42,0.08);border-radius:18px;overflow:hidden;box-shadow:0 18px 55px rgba(15,23,42,0.08)">
                  <div style="display:flex;align-items:center;gap:12px;padding:14px 16px;background:linear-gradient(90deg, rgba(46,204,113,0.10), rgba(46,204,113,0.03));border-bottom:1px solid rgba(15,23,42,0.08)">
                    <img src="{logoSrc}" alt="FreshFood" width="34" height="34" style="display:block;border-radius:10px" />
                    <div style="min-width:0">
                      <div style="font-weight:950;letter-spacing:0.08em;font-size:12px;color:rgba(15,23,42,0.75)">FRESHFOOD</div>
                      <div style="font-weight:900;font-size:14px;color:#0f172a">Phản hồi liên hệ</div>
                    </div>
                  </div>
                  <div style="padding:16px 16px 6px;font-family:Arial,Helvetica,sans-serif;line-height:1.6;color:#0f172a">
                    <p style="margin:0 0 10px">Chào bạn{(string.IsNullOrWhiteSpace(safeName) ? "" : $" <b>{safeName}</b>")},</p>
                    <p style="margin:0 0 12px;color:rgba(15,23,42,0.78)">Cảm ơn bạn đã liên hệ FreshFood. Dưới đây là phản hồi từ chúng tôi:</p>
                    <div style="padding:12px 14px;border:1px solid rgba(15,23,42,0.10);border-radius:14px;background:#f8fafc">
                      {safeReply}
                    </div>
                  </div>
            """;

        if (dto.IncludeOriginal)
        {
            html += $"""

              <hr style="border:none;border-top:1px solid rgba(15,23,42,0.10);margin:18px 0"/>
              <p style="margin:0 0 8px"><b>Tin nhắn gốc</b></p>
              <div style="font-size:13px;color:rgba(15,23,42,0.75)">
                <div><b>Thời gian:</b> {created}</div>
                <div><b>Email:</b> {safeEmail}</div>
                <div><b>Chủ đề:</b> {safeSubject}</div>
              </div>
              <div style="margin-top:10px;padding:12px 14px;border:1px dashed rgba(15,23,42,0.20);border-radius:12px;background:#ffffff">
                {safeOriginal}
              </div>
            """;
        }

        html += $"""
                  <div style="padding:12px 16px 16px;font-family:Arial,Helvetica,sans-serif">
                    <p style="margin:0;color:rgba(15,23,42,0.78)">Trân trọng,<br/><b>{WebUtility.HtmlEncode(_emailSettings.FromName ?? "FreshFood")}</b></p>
                    <div style="margin-top:10px;font-size:12px;color:rgba(15,23,42,0.55)">
                      Email này được gửi tự động từ hệ thống FreshFood. Nếu bạn cần hỗ trợ thêm, hãy phản hồi lại email này.
                    </div>
                    <div style="margin-top:8px;font-size:12px;color:rgba(15,23,42,0.45)">
                      © {DateTime.Now.Year} FreshFood. All rights reserved.
                    </div>
                  </div>
                </div>
              </div>
            </div>
            """;

        try
        {
            await _emailSender.SendAsync(to, subject, html, linked, ct);
            m.Status = "Replied";
            await _context.SaveChangesAsync(ct);
            _logger.LogInformation("Replied ContactMessageID={Id} to {To}", m.ContactMessageID, to);
            return Ok(new { ok = true });
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "Reply email failed ContactMessageID={Id} to {To}", m.ContactMessageID, to);
            var extra = _env.IsDevelopment() ? $" Chi tiết: {ex.Message}" : string.Empty;
            return Problem($"Gửi email thất bại. Vui lòng kiểm tra cấu hình SMTP.{extra}", statusCode: 500);
        }
    }
}
