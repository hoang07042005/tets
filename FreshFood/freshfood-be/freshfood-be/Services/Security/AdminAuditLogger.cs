using System.Security.Claims;
using System.Text.Json;
using freshfood_be.Data;
using freshfood_be.Models;

namespace freshfood_be.Services.Security;

public sealed class AdminAuditLogger
{
    private readonly FreshFoodContext _context;
    private readonly IHttpContextAccessor _http;

    private static readonly JsonSerializerOptions JsonOpts = new(JsonSerializerDefaults.Web)
    {
        WriteIndented = false
    };

    public AdminAuditLogger(FreshFoodContext context, IHttpContextAccessor http)
    {
        _context = context;
        _http = http;
    }

    public async Task LogAsync(string action, string entityType, string? entityId, string? summary, object? data, CancellationToken ct = default)
    {
        var ctx = _http.HttpContext;
        var user = ctx?.User;

        int? uid = null;
        var uidRaw = user?.FindFirstValue(ClaimTypes.NameIdentifier) ?? user?.FindFirstValue("sub");
        if (int.TryParse(uidRaw, out var n) && n > 0) uid = n;

        var email = user?.FindFirstValue(ClaimTypes.Email) ?? user?.FindFirstValue("email");
        var role = user?.FindFirstValue(ClaimTypes.Role);

        var ip = ctx?.Connection?.RemoteIpAddress?.ToString();
        var ua = ctx?.Request?.Headers["User-Agent"].ToString();

        string? json = null;
        if (data != null)
        {
            try { json = JsonSerializer.Serialize(data, JsonOpts); }
            catch { json = null; }
        }

        _context.Set<AdminAuditLog>().Add(new AdminAuditLog
        {
            ActorUserID = uid,
            ActorEmail = string.IsNullOrWhiteSpace(email) ? null : email.Trim(),
            ActorRole = string.IsNullOrWhiteSpace(role) ? null : role.Trim(),
            Action = (action ?? "").Trim(),
            EntityType = (entityType ?? "").Trim(),
            EntityId = string.IsNullOrWhiteSpace(entityId) ? null : entityId.Trim(),
            Summary = string.IsNullOrWhiteSpace(summary) ? null : summary.Trim(),
            DataJson = json,
            IpAddress = string.IsNullOrWhiteSpace(ip) ? null : ip.Trim(),
            UserAgent = string.IsNullOrWhiteSpace(ua) ? null : ua.Trim(),
            CreatedAt = DateTime.UtcNow
        });

        await _context.SaveChangesAsync(ct);
    }
}

