using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using freshfood_be.Data;
using freshfood_be.Models;
using freshfood_be.Services.Email;
using freshfood_be.Services.Security;
using System.Net;

namespace freshfood_be.Controllers;

/// <summary>Admin Orders — api/Admin/Orders</summary>
[Authorize(Roles = "Admin")]
[Route("api/Admin/Orders")]
[ApiController]
public class AdminOrdersController : ControllerBase
{
    private readonly FreshFoodContext _context;
    private readonly IEmailSender _emailSender;
    private readonly IConfiguration _configuration;
    private readonly ILogger<AdminOrdersController> _logger;
    private readonly IWebHostEnvironment _env;
    private readonly freshfood_be.Services.Security.IdTokenService _idTokens;
    private readonly AdminAuditLogger _audit;

    public AdminOrdersController(
        FreshFoodContext context,
        IEmailSender emailSender,
        IConfiguration configuration,
        ILogger<AdminOrdersController> logger,
        IWebHostEnvironment env,
        freshfood_be.Services.Security.IdTokenService idTokens,
        AdminAuditLogger audit)
    {
        _context = context;
        _emailSender = emailSender;
        _configuration = configuration;
        _logger = logger;
        _env = env;
        _idTokens = idTokens;
        _audit = audit;
    }

    public record AdminOrderRowDto(
        int OrderID,
        string OrderToken,
        string OrderCode,
        string CustomerName,
        string CustomerEmail,
        DateTime OrderDate,
        decimal TotalAmount,
        string Status);

    public record AdminOrdersStatsDto(
        decimal DailyRevenue,
        int ShippingCount,
        int PendingCount);

    public record AdminOrdersPageDto(
        IReadOnlyList<AdminOrderRowDto> Items,
        int TotalCount,
        int Page,
        int PageSize,
        AdminOrdersStatsDto Stats);

    public record AdminOrderItemDto(
        int ProductID,
        string ProductName,
        string? Sku,
        string? ThumbUrl,
        int Quantity,
        decimal UnitPrice,
        decimal LineTotal);

    public record AdminOrderCustomerDto(
        int UserID,
        string FullName,
        string Email,
        string? Phone,
        string? AvatarUrl);

    public record AdminOrderPaymentDto(string? Method, string? Status, decimal Amount, DateTime PaymentDate);

    public record AdminShipmentDto(
        int ShipmentID,
        string? TrackingNumber,
        string? Carrier,
        DateTime? ShippedDate,
        DateTime? EstimatedDeliveryDate,
        DateTime? ActualDeliveryDate,
        string? Status);

    public record AdminOrderDetailDto(
        int OrderID,
        string OrderCode,
        DateTime OrderDate,
        string Status,
        string PipelineStatus,
        decimal TotalAmount,
        string ShippingAddress,
        AdminOrderCustomerDto Customer,
        IReadOnlyList<AdminOrderItemDto> Items,
        AdminOrderPaymentDto? LatestPayment,
        IReadOnlyList<AdminShipmentDto> Shipments);

    public record UpdateStatusDto(string Status);
    public record CancelOrderDto(string? Reason);

    private static int StatusRank(string? status)
    {
        var s = (status ?? "").Trim().ToLowerInvariant();
        return s switch
        {
            "pending" => 0,
            "processing" => 1,
            "preparing" or "preparing_goods" or "packing" => 2,
            "shipping" or "intransit" or "in_transit" => 3,
            "delivered" => 4,
            "completed" => 5,
            _ => 0
        };
    }

    private static bool IsKnownPipelineStatus(string? status)
    {
        var s = (status ?? "").Trim().ToLowerInvariant();
        return s is "pending" or "processing" or "preparing" or "preparing_goods" or "packing" or "shipping" or "intransit" or "in_transit" or "delivered" or "completed";
    }

    private static string NormalizeStatus(string? status)
    {
        var s = (status ?? "").Trim();
        if (string.IsNullOrWhiteSpace(s)) return "Pending";
        return s;
    }

    private static bool IsShipping(string status)
    {
        var s = (status ?? "").Trim().ToLowerInvariant();
        return s is "shipping" or "intransit" or "in_transit";
    }

    private static bool IsPending(string status)
    {
        var s = (status ?? "").Trim().ToLowerInvariant();
        return s is "pending" or "processing";
    }

    private static bool IsCompletedForRevenue(string status)
    {
        var s = (status ?? "").Trim().ToLowerInvariant();
        return s is "paid" or "completed" or "delivered";
    }

    private static string DeriveStatusFromReturnRequest(string? fallbackStatus, freshfood_be.Models.ReturnRequest? rr)
    {
        if (rr == null) return NormalizeStatus(fallbackStatus);

        var rt = (rr.RequestType ?? "").Trim().ToLowerInvariant();
        if (string.IsNullOrWhiteSpace(rt)) rt = "return";

        // Never override a failed order status.
        // For CancelRefund flow, allow override on Cancelled so admin can see refund state.
        var baseLower = (fallbackStatus ?? "").Trim().ToLowerInvariant();
        if (baseLower == "failed")
            return NormalizeStatus(fallbackStatus);
        if ((baseLower == "cancelled" || baseLower == "canceled") && rt != "cancelrefund")
            return NormalizeStatus(fallbackStatus);

        var rrSt = (rr.Status ?? "").Trim().ToLowerInvariant();
        if (rt == "return")
        {
            if (rrSt == "pending") return "ReturnPending";
            if (rrSt == "approved") return string.IsNullOrWhiteSpace(rr.RefundProofUrl) ? "Returned" : "Refunded";
        }
        else if (rt == "cancelrefund")
        {
            if (rrSt == "pending") return "RefundPending";
            if (rrSt == "approved") return string.IsNullOrWhiteSpace(rr.RefundProofUrl) ? "RefundPending" : "Refunded";
        }

        return NormalizeStatus(fallbackStatus);
    }

    [HttpGet]
    public async Task<ActionResult<AdminOrdersPageDto>> List(
        [FromQuery] int page = 1,
        [FromQuery] int pageSize = 10,
        [FromQuery] string? status = null,
        [FromQuery] string? q = null)
    {
        page = Math.Max(1, page);
        pageSize = Math.Clamp(pageSize, 1, 100);

        var today = DateTime.Today;
        var tomorrow = today.AddDays(1);

        var ordersAll = _context.Orders.AsNoTracking();

        // Revenue should be based on payment success (not fulfillment status).
        var dailyRevenue = await _context.Payments
            .AsNoTracking()
            .Where(p => p.PaymentDate >= today && p.PaymentDate < tomorrow)
            .Where(p => p.Status != null && (p.Status.ToLower() == "paid" || p.Status.ToLower() == "success"))
            .SumAsync(p => (decimal?)p.Amount) ?? 0m;

        var shippingCount = await ordersAll.CountAsync(o =>
            o.Status != null &&
            (o.Status.ToLower() == "shipping" || o.Status.ToLower() == "intransit" || o.Status.ToLower() == "in_transit"));

        var pendingCount = await ordersAll.CountAsync(o =>
            o.Status != null &&
            (o.Status.ToLower() == "pending" || o.Status.ToLower() == "processing"));

        var stats = new AdminOrdersStatsDto(dailyRevenue, shippingCount, pendingCount);

        var baseQuery = _context.Orders
            .AsNoTracking()
            .Include(o => o.User)
            .AsQueryable();

        if (!string.IsNullOrWhiteSpace(status) && status.Trim().ToLowerInvariant() != "all")
        {
            var st = status.Trim().ToLowerInvariant();

            // Support return/refund flow statuses in admin list filters.
            if (st is "returnpending" or "returned" or "refundpending" or "refunded")
            {
                var rrLatest = _context.ReturnRequests
                    .AsNoTracking()
                    .GroupBy(r => r.OrderID)
                    .Select(g => g.OrderByDescending(x => x.CreatedAt).FirstOrDefault());

                if (st == "returnpending")
                {
                    baseQuery = baseQuery.Where(o =>
                        rrLatest.Any(rr =>
                            rr != null &&
                            rr.OrderID == o.OrderID &&
                            rr.RequestType != null &&
                            rr.RequestType.Trim().ToLower() == "return" &&
                            rr.Status != null &&
                            rr.Status.Trim().ToLower() == "pending"));
                }
                else if (st == "returned")
                {
                    baseQuery = baseQuery.Where(o =>
                        rrLatest.Any(rr =>
                            rr != null &&
                            rr.OrderID == o.OrderID &&
                            rr.RequestType != null &&
                            rr.RequestType.Trim().ToLower() == "return" &&
                            rr.Status != null &&
                            rr.Status.Trim().ToLower() == "approved" &&
                            (rr.RefundProofUrl == null || rr.RefundProofUrl.Trim() == "")));
                }
                else if (st == "refundpending")
                {
                    baseQuery = baseQuery.Where(o =>
                        rrLatest.Any(rr =>
                            rr != null &&
                            rr.OrderID == o.OrderID &&
                            rr.RequestType != null &&
                            rr.RequestType.Trim().ToLower() == "cancelrefund" &&
                            rr.Status != null &&
                            (rr.Status.Trim().ToLower() == "pending" ||
                             (rr.Status.Trim().ToLower() == "approved" && (rr.RefundProofUrl == null || rr.RefundProofUrl.Trim() == "")))));
                }
                else if (st == "refunded")
                {
                    baseQuery = baseQuery.Where(o =>
                        rrLatest.Any(rr =>
                            rr != null &&
                            rr.OrderID == o.OrderID &&
                            rr.RequestType != null &&
                            (rr.RequestType.Trim().ToLower() == "return" || rr.RequestType.Trim().ToLower() == "cancelrefund") &&
                            rr.Status != null &&
                            rr.Status.Trim().ToLower() == "approved" &&
                            rr.RefundProofUrl != null &&
                            rr.RefundProofUrl.Trim() != ""));
                }
            }
            else
            {
                baseQuery = baseQuery.Where(o => o.Status != null && o.Status.ToLower() == st);
            }
        }

        if (!string.IsNullOrWhiteSpace(q))
        {
            var term = q.Trim();
            baseQuery = baseQuery.Where(o =>
                (o.OrderCode != null && o.OrderCode.Contains(term)) ||
                o.OrderID.ToString().Contains(term) ||
                (o.User != null && (o.User.FullName.Contains(term) || o.User.Email.Contains(term))));
        }

        var totalCount = await baseQuery.CountAsync();

        var items = await baseQuery
            .OrderByDescending(o => o.OrderDate)
            .Skip((page - 1) * pageSize)
            .Take(pageSize)
            .Select(o => new AdminOrderRowDto(
                o.OrderID,
                "", // filled after query (needs IdTokenService outside EF translation)
                o.OrderCode ?? $"#VH-{o.OrderID:D4}",
                o.User != null ? o.User.FullName : "—",
                o.User != null ? o.User.Email : "—",
                o.OrderDate,
                o.TotalAmount,
                o.Status))
            .ToListAsync();

        // Derive return-flow status for the page items only (fast, avoids N+1).
        var pageOrderIds = items.Select(x => x.OrderID).Distinct().ToList();
        if (pageOrderIds.Count > 0)
        {
            var latestRrs = await _context.ReturnRequests
                .AsNoTracking()
                .Where(r => pageOrderIds.Contains(r.OrderID))
                .GroupBy(r => r.OrderID)
                .Select(g => g.OrderByDescending(x => x.CreatedAt).FirstOrDefault())
                .ToListAsync();

            items = items
                .Select(x =>
                {
                    var rr = latestRrs.FirstOrDefault(r => r != null && r.OrderID == x.OrderID);
                    var nextStatus = DeriveStatusFromReturnRequest(x.Status, rr);
                    return new AdminOrderRowDto(x.OrderID, _idTokens.ProtectOrderId(x.OrderID), x.OrderCode, x.CustomerName, x.CustomerEmail, x.OrderDate, x.TotalAmount, nextStatus);
                })
                .ToList();
        }
        else
        {
            // Still fill tokens even when no return requests are present.
            items = items.Select(x => new AdminOrderRowDto(x.OrderID, _idTokens.ProtectOrderId(x.OrderID), x.OrderCode, x.CustomerName, x.CustomerEmail, x.OrderDate, x.TotalAmount, x.Status)).ToList();
        }

        return Ok(new AdminOrdersPageDto(items, totalCount, page, pageSize, stats));
    }

    [HttpGet("{id:int}")]
    public async Task<ActionResult<AdminOrderDetailDto>> Detail(int id)
    {
        var order = await _context.Orders
            .AsNoTracking()
            .Include(o => o.User)
            .Include(o => o.Payments)
            .Include(o => o.Shipments)
            .Include(o => o.OrderDetails)
                .ThenInclude(d => d.Product!)
                .ThenInclude(p => p.ProductImages)
            .FirstOrDefaultAsync(o => o.OrderID == id);

        if (order == null) return NotFound();

        // Derive return-flow status for the detail header as well.
        var latestRr = await _context.ReturnRequests
            .AsNoTracking()
            .Where(r => r.OrderID == id)
            .OrderByDescending(r => r.CreatedAt)
            .FirstOrDefaultAsync();

        var customer = new AdminOrderCustomerDto(
            order.UserID,
            order.User?.FullName ?? "—",
            order.User?.Email ?? "—",
            order.User?.Phone,
            order.User?.AvatarUrl);

        var items = (order.OrderDetails ?? new List<freshfood_be.Models.OrderDetail>())
            .Select(d =>
            {
                var p = d.Product;
                var thumb = p?.ProductImages?.Where(x => x.IsMainImage).Select(x => x.ImageURL).FirstOrDefault()
                            ?? p?.ProductImages?.Select(x => x.ImageURL).FirstOrDefault();
                return new AdminOrderItemDto(
                    d.ProductID,
                    p?.ProductName ?? $"Sản phẩm #{d.ProductID}",
                    p?.Sku,
                    thumb,
                    d.Quantity,
                    d.UnitPrice,
                    d.UnitPrice * d.Quantity);
            })
            .ToList();

        var latestPayment = order.Payments?
            .OrderByDescending(p => p.PaymentDate)
            .Select(p => new AdminOrderPaymentDto(p.PaymentMethod, p.Status, p.Amount, p.PaymentDate))
            .FirstOrDefault();

        var shipments = (order.Shipments ?? new List<freshfood_be.Models.Shipment>())
            .OrderBy(s => s.ShipmentID)
            .Select(s => new AdminShipmentDto(
                s.ShipmentID,
                s.TrackingNumber,
                s.Carrier,
                s.ShippedDate,
                s.EstimatedDeliveryDate,
                s.ActualDeliveryDate,
                s.Status))
            .ToList();

        return Ok(new AdminOrderDetailDto(
            order.OrderID,
            order.OrderCode ?? $"#VH-{order.OrderID:D4}",
            order.OrderDate,
            DeriveStatusFromReturnRequest(order.Status, latestRr),
            NormalizeStatus(order.Status),
            order.TotalAmount,
            order.ShippingAddress,
            customer,
            items,
            latestPayment,
            shipments));
    }

    // GET: api/Admin/Orders/token/xxxx
    [HttpGet("token/{token}")]
    public async Task<ActionResult<AdminOrderDetailDto>> DetailByToken([FromRoute] string token)
    {
        if (string.IsNullOrWhiteSpace(token)) return NotFound();
        var id = _idTokens.UnprotectOrderId(token.Trim());
        if (id == null || id <= 0) return NotFound();
        return await Detail(id.Value);
    }

    [HttpPut("{id:int}/status")]
    public async Task<IActionResult> UpdateStatus(int id, [FromBody] UpdateStatusDto input)
    {
        var order = await _context.Orders
            .Include(o => o.Shipments)
            .FirstOrDefaultAsync(o => o.OrderID == id);
        if (order == null) return NotFound();

        var next = NormalizeStatus(input.Status);
        if (!IsKnownPipelineStatus(next))
            return BadRequest("Trạng thái không hợp lệ.");

        var curRank = StatusRank(order.Status);
        var nextRank = StatusRank(next);
        if (nextRank < curRank)
            return BadRequest("Không thể chuyển về trạng thái trước đó.");

        var prevStatusNorm = (order.Status ?? "").Trim();
        order.Status = next;

        // Keep Shipments in sync with the order pipeline status (avoid "Pending" shipments for delivered orders).
        var primary = order.Shipments?
            .OrderByDescending(s => s.ShippedDate ?? DateTime.MinValue)
            .FirstOrDefault();

        if (primary != null)
        {
            var ns = next.Trim().ToLowerInvariant();
            if (ns is "shipping" or "intransit" or "in_transit")
            {
                if (string.IsNullOrWhiteSpace(primary.Status)) primary.Status = "Shipping";
                if (primary.ShippedDate == null) primary.ShippedDate = DateTime.Now;
            }
            else if (ns is "delivered" or "completed")
            {
                primary.Status = "Delivered";
                if (primary.ActualDeliveryDate == null) primary.ActualDeliveryDate = DateTime.Now;
                if (primary.ShippedDate == null) primary.ShippedDate = primary.ActualDeliveryDate;
            }
        }

        await _context.SaveChangesAsync();

        await _audit.LogAsync(
            action: "orders.update_status",
            entityType: "Order",
            entityId: id.ToString(),
            summary: $"Order status: {prevStatusNorm} -> {next}",
            data: new { orderId = id, from = prevStatusNorm, to = next },
            ct: HttpContext.RequestAborted);

        var nowDelivered = string.Equals(next.Trim(), "delivered", StringComparison.OrdinalIgnoreCase);
        var wasDelivered = string.Equals(prevStatusNorm, "delivered", StringComparison.OrdinalIgnoreCase);
        if (nowDelivered && !wasDelivered)
            await TrySendOrderDeliveredEmailAsync(order.OrderID, order.UserID, HttpContext.RequestAborted);

        return NoContent();
    }

    // POST: api/Admin/Orders/5/cancel
    // Admin cancels an order (only allowed before shipping). Will restock items.
    [HttpPost("{id:int}/cancel")]
    public async Task<IActionResult> Cancel(int id, [FromBody] CancelOrderDto? input)
    {
        var order = await _context.Orders
            .Include(o => o.Shipments)
            .Include(o => o.OrderDetails)
            .FirstOrDefaultAsync(o => o.OrderID == id);
        if (order == null) return NotFound();

        var st = (order.Status ?? "").Trim().ToLowerInvariant();
        if (st is "cancelled" or "canceled") return NoContent();
        if (st == "failed") return NoContent();

        // Do NOT allow cancel once shipping/delivered/completed/return flow.
        if (st is "shipping" or "intransit" or "in_transit" or "delivered" or "completed" or "returned" or "refunded" or "returnpending")
            return BadRequest("Không thể hủy đơn khi đơn đã được giao/đang giao hoặc đang ở luồng hoàn hàng.");

        var shippedByShipment = order.Shipments?.Any(s =>
            !string.IsNullOrWhiteSpace(s.Status) &&
            (s.Status.Trim().ToLowerInvariant() == "shipping" ||
             s.Status.Trim().ToLowerInvariant() == "intransit" ||
             s.Status.Trim().ToLowerInvariant() == "in_transit" ||
             s.Status.Trim().ToLowerInvariant() == "delivered")) == true
            || order.Shipments?.Any(s => s.ShippedDate != null || s.ActualDeliveryDate != null) == true;
        if (shippedByShipment)
            return BadRequest("Không thể hủy đơn khi đơn đã được giao/đang giao.");

        await using var tx = await _context.Database.BeginTransactionAsync();
        try
        {
            order.Status = "Cancelled";

            // Restock (idempotent because we short-circuit above if already cancelled/failed)
            var details = order.OrderDetails?.ToList() ?? new List<OrderDetail>();
            foreach (var d in details)
            {
                if (d.ProductID <= 0 || d.Quantity <= 0) continue;
                var product = await _context.Products.FirstOrDefaultAsync(p => p.ProductID == d.ProductID);
                if (product == null) continue;
                product.StockQuantity += d.Quantity;
            }

            // Best-effort: mark shipments as cancelled too.
            if (order.Shipments != null)
            {
                foreach (var s in order.Shipments)
                {
                    if (string.IsNullOrWhiteSpace(s.Status)) s.Status = "Cancelled";
                }
            }

            // If order already paid online, open a cancel-refund request for admin processing.
            var latestPayment = await _context.Payments
                .AsNoTracking()
                .Where(p => p.OrderID == id)
                .OrderByDescending(p => p.PaymentDate)
                .FirstOrDefaultAsync();

            var pm = (latestPayment?.PaymentMethod ?? "").Trim().ToUpperInvariant();
            var pst = (latestPayment?.Status ?? "").Trim().ToLowerInvariant();
            var isPaid = pst is "paid" or "success";
            var isCod = pm == "COD";

            if (latestPayment != null && isPaid && !isCod && order.UserID > 0)
            {
                var existingRefund = await _context.ReturnRequests
                    .AsNoTracking()
                    .Where(r => r.OrderID == id && r.UserID == order.UserID && r.RequestType == "CancelRefund" && r.Status != "Rejected")
                    .OrderByDescending(r => r.CreatedAt)
                    .FirstOrDefaultAsync();

                if (existingRefund == null)
                {
                    var reason = (input?.Reason ?? "").Trim();
                    if (string.IsNullOrWhiteSpace(reason)) reason = "Admin hủy đơn — yêu cầu hoàn tiền.";

                    _context.ReturnRequests.Add(new ReturnRequest
                    {
                        OrderID = id,
                        UserID = order.UserID,
                        Status = "Pending",
                        RequestType = "CancelRefund",
                        Reason = reason,
                        CreatedAt = DateTime.UtcNow
                    });
                }
            }

            await _context.SaveChangesAsync();
            await tx.CommitAsync();

            await _audit.LogAsync(
                action: "orders.cancel",
                entityType: "Order",
                entityId: id.ToString(),
                summary: string.IsNullOrWhiteSpace(input?.Reason) ? "Admin cancelled order" : $"Admin cancelled order: {input!.Reason}",
                data: new { orderId = id, reason = input?.Reason },
                ct: HttpContext.RequestAborted);
            return NoContent();
        }
        catch
        {
            await tx.RollbackAsync();
            throw;
        }
    }

    /// <summary>Chỉ gửi khi trạng thái đơn là Đã giao hàng — một email, nút mở trang chi tiết để khách bấm &quot;Nhận hàng&quot;.</summary>
    private async Task TrySendOrderDeliveredEmailAsync(int orderId, int userId, CancellationToken ct)
    {
        try
        {
            if (userId <= 0) return;
            var user = await _context.Users.AsNoTracking().FirstOrDefaultAsync(u => u.UserID == userId, ct);
            if (user == null) return;
            var to = (user.Email ?? "").Trim();
            if (string.IsNullOrEmpty(to)) return;

            var order = await _context.Orders.AsNoTracking().FirstOrDefaultAsync(o => o.OrderID == orderId, ct);
            if (order == null) return;

            var feBase = (_configuration["Frontend:BaseUrl"] ?? "http://localhost:5173").Trim().TrimEnd('/');
            var detailUrl = $"{feBase}/orders/{_idTokens.ProtectOrderId(orderId)}#xac-nhan-nhan-hang";
            var code = order.OrderCode ?? $"#{order.OrderID}";
            var safeCode = WebUtility.HtmlEncode(code);
            var safeName = WebUtility.HtmlEncode(user.FullName?.Trim() ?? "Khách hàng");

            var subject = OrderDeliveredEmailTemplates.Subject(code);
            var html = OrderDeliveredEmailTemplates.BuildHtml(safeName, safeCode, detailUrl);

            await _emailSender.SendAsync(to, subject, html, ct);
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "Không gửi được email đã giao hàng OrderID={OrderId}", orderId);
            if (_env.IsDevelopment())
                _logger.LogInformation("Dev: kiểm tra SMTP khi admin chuyển đơn sang Delivered.");
        }
    }
}

