using System.ComponentModel.DataAnnotations;
using System.Net;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;
using freshfood_be.Data;
using freshfood_be.Models;
using freshfood_be.Services.Email;

namespace freshfood_be.Controllers;

[Route("api/[controller]")]
[ApiController]
public class ContactMessagesController : ControllerBase
{
    private readonly FreshFoodContext _context;
    private readonly IEmailSender _emailSender;
    private readonly EmailSettings _emailSettings;
    private readonly ILogger<ContactMessagesController> _logger;

    public ContactMessagesController(
        FreshFoodContext context,
        IEmailSender emailSender,
        IOptions<EmailSettings> emailOptions,
        ILogger<ContactMessagesController> logger)
    {
        _context = context;
        _emailSender = emailSender;
        _emailSettings = emailOptions.Value;
        _logger = logger;
    }

    public class CreateContactMessageDto
    {
        [Required, StringLength(200)]
        public string Name { get; set; } = string.Empty;

        [Required, EmailAddress, StringLength(320)]
        public string Email { get; set; } = string.Empty;

        [Required, StringLength(300)]
        public string Subject { get; set; } = string.Empty;

        [Required, MinLength(5), StringLength(8000)]
        public string Message { get; set; } = string.Empty;
    }

    /// <summary>Lưu tin nhắn liên hệ; gửi email thông báo shop nếu cấu hình ContactNotificationTo và SMTP hợp lệ.</summary>
    [HttpPost]
    public async Task<ActionResult<object>> Post([FromBody] CreateContactMessageDto dto, CancellationToken ct)
    {
        if (!ModelState.IsValid)
            return ValidationProblem(ModelState);

        var subj = dto.Subject.Trim();
        var msg = dto.Message.Trim();
        var entity = new ContactMessage
        {
            Name = dto.Name.Trim(),
            Email = dto.Email.Trim(),
            Subject = subj,
            Message = msg,
            Status = "New",
            IsUrgent = LooksUrgent(subj, msg),
            CreatedAt = DateTime.UtcNow
        };

        _context.ContactMessages.Add(entity);
        await _context.SaveChangesAsync(ct);

        var notifyTo = (_emailSettings.ContactNotificationTo ?? string.Empty).Trim();
        if (!string.IsNullOrEmpty(notifyTo))
        {
            try
            {
                var safeName = WebUtility.HtmlEncode(entity.Name);
                var safeEmail = WebUtility.HtmlEncode(entity.Email);
                var safeSubject = WebUtility.HtmlEncode(entity.Subject);
                var safeBody = WebUtility.HtmlEncode(entity.Message).Replace("\r\n", "<br/>").Replace("\n", "<br/>");

                var html = $"""
                    <p>Có tin nhắn mới từ form liên hệ FreshFood.</p>
                    <ul>
                      <li><b>ID:</b> {entity.ContactMessageID}</li>
                      <li><b>Họ tên:</b> {safeName}</li>
                      <li><b>Email:</b> {safeEmail}</li>
                      <li><b>Chủ đề:</b> {safeSubject}</li>
                    </ul>
                    <p><b>Nội dung:</b></p>
                    <p>{safeBody}</p>
                    """;

                await _emailSender.SendAsync(notifyTo, $"[FreshFood Liên hệ] {entity.Subject}", html, ct);
            }
            catch (Exception ex)
            {
                _logger.LogWarning(ex, "Đã lưu ContactMessageID={Id} nhưng gửi email thông báo thất bại.", entity.ContactMessageID);
            }
        }

        return Ok(new { contactMessageID = entity.ContactMessageID });
    }

    private static bool LooksUrgent(string subject, string message)
    {
        var t = $"{subject}\n{message}".ToLowerInvariant();
        return t.Contains("khẩn cấp", StringComparison.OrdinalIgnoreCase)
               || t.Contains("khẩn", StringComparison.OrdinalIgnoreCase)
               || t.Contains("gấp", StringComparison.OrdinalIgnoreCase)
               || t.Contains("urgent", StringComparison.OrdinalIgnoreCase)
               || t.Contains("asap", StringComparison.OrdinalIgnoreCase);
    }
}
