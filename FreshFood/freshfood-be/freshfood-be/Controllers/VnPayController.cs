using System.Globalization;
using System.Net;
using System.Security.Claims;
using freshfood_be.Data;
using freshfood_be.Models;
using freshfood_be.Services.Email;
using freshfood_be.Services.VnPay;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace freshfood_be.Controllers;

[Route("api/[controller]")]
[ApiController]
public sealed class VnPayController : ControllerBase
{
    private readonly FreshFoodContext _context;
    private readonly VnPayService _vnpay;
    private readonly IEmailSender _emailSender;
    private readonly IConfiguration _configuration;
    private readonly IWebHostEnvironment _env;
    private readonly ILogger<VnPayController> _logger;
    private readonly freshfood_be.Services.Security.IdTokenService _idTokens;

    public VnPayController(
        FreshFoodContext context,
        VnPayService vnpay,
        IEmailSender emailSender,
        IConfiguration configuration,
        IWebHostEnvironment env,
        ILogger<VnPayController> logger,
        freshfood_be.Services.Security.IdTokenService idTokens)
    {
        _context = context;
        _vnpay = vnpay;
        _emailSender = emailSender;
        _configuration = configuration;
        _env = env;
        _logger = logger;
        _idTokens = idTokens;
    }

    public sealed record CreatePaymentUrlRequest(int OrderID, string? BankCode, string? Locale, string? ReturnTo);
    public sealed record CreatePaymentUrlPublicRequest(string OrderCode, string? BankCode, string? Locale, string? ReturnTo);
    public sealed record CreatePaymentUrlResponse(string PaymentUrl);

    // POST: api/VnPay/CreatePaymentUrl
    [Authorize]
    [HttpPost("CreatePaymentUrl")]
    public async Task<ActionResult<CreatePaymentUrlResponse>> CreatePaymentUrl([FromBody] CreatePaymentUrlRequest req)
    {
        var claimId = User?.FindFirstValue(ClaimTypes.NameIdentifier) ?? User?.FindFirstValue("sub");
        if (!int.TryParse(claimId, out var authId) || authId <= 0) return Forbid();

        var order = await _context.Orders.AsNoTracking().FirstOrDefaultAsync(o => o.OrderID == req.OrderID);
        if (order == null) return NotFound("Order not found.");
        if (order.UserID != authId) return Forbid();

        var ip = HttpContext.Connection.RemoteIpAddress?.ToString() ?? "127.0.0.1";
        var rt = (req.ReturnTo ?? "").Trim().ToLowerInvariant();
        rt = rt is "app" or "web" ? rt : "web";
        var backendReturn = _configuration["VnPay:ReturnUrl"] ?? "";
        if (string.IsNullOrWhiteSpace(backendReturn)) backendReturn = "http://localhost/api/VnPay/Return";
        var returnUrl = backendReturn.Contains('?') ? $"{backendReturn}&rt={WebUtility.UrlEncode(rt)}" : $"{backendReturn}?rt={WebUtility.UrlEncode(rt)}";
        var url = _vnpay.CreatePaymentUrl(
            orderId: order.OrderID,
            amountVnd: order.TotalAmount,
            ipAddress: ip,
            bankCode: req.BankCode,
            locale: string.IsNullOrWhiteSpace(req.Locale) ? "vn" : req.Locale!,
            returnUrlOverride: returnUrl
        );

        // Ensure a pending payment record exists
        var existing = await _context.Payments.FirstOrDefaultAsync(p => p.OrderID == order.OrderID && p.PaymentMethod == "VNPAY");
        if (existing == null)
        {
            _context.Payments.Add(new Payment
            {
                OrderID = order.OrderID,
                PaymentMethod = "VNPAY",
                Amount = order.TotalAmount,
                Status = "Pending",
                PaymentDate = DateTime.Now
            });
            await _context.SaveChangesAsync();
        }

        return new CreatePaymentUrlResponse(url);
    }

    // POST: api/VnPay/CreatePaymentUrlPublic
    // Public (guest) flow: use unguessable OrderCode instead of auth-bound OrderID.
    [HttpPost("CreatePaymentUrlPublic")]
    public async Task<ActionResult<CreatePaymentUrlResponse>> CreatePaymentUrlPublic([FromBody] CreatePaymentUrlPublicRequest req)
    {
        var code = (req.OrderCode ?? "").Trim();
        if (string.IsNullOrWhiteSpace(code)) return BadRequest("Missing orderCode.");

        var order = await _context.Orders.AsNoTracking().FirstOrDefaultAsync(o => o.OrderCode != null && o.OrderCode.Trim() == code);
        if (order == null) return NotFound("Order not found.");

        var ip = HttpContext.Connection.RemoteIpAddress?.ToString() ?? "127.0.0.1";
        var rt = (req.ReturnTo ?? "").Trim().ToLowerInvariant();
        rt = rt is "app" or "web" ? rt : "web";
        var backendReturn = _configuration["VnPay:ReturnUrl"] ?? "";
        if (string.IsNullOrWhiteSpace(backendReturn)) backendReturn = "http://localhost/api/VnPay/Return";
        var returnUrl = backendReturn.Contains('?') ? $"{backendReturn}&rt={WebUtility.UrlEncode(rt)}" : $"{backendReturn}?rt={WebUtility.UrlEncode(rt)}";

        var url = _vnpay.CreatePaymentUrl(
            orderId: order.OrderID,
            amountVnd: order.TotalAmount,
            ipAddress: ip,
            bankCode: req.BankCode,
            locale: string.IsNullOrWhiteSpace(req.Locale) ? "vn" : req.Locale!,
            returnUrlOverride: returnUrl
        );

        // Ensure a pending payment record exists
        var existing = await _context.Payments.FirstOrDefaultAsync(p => p.OrderID == order.OrderID && p.PaymentMethod == "VNPAY");
        if (existing == null)
        {
            _context.Payments.Add(new Payment
            {
                OrderID = order.OrderID,
                PaymentMethod = "VNPAY",
                Amount = order.TotalAmount,
                Status = "Pending",
                PaymentDate = DateTime.Now
            });
            await _context.SaveChangesAsync();
        }

        return new CreatePaymentUrlResponse(url);
    }

    // GET: api/VnPay/Return
    // VNPay will redirect the customer here. We validate signature and then redirect to frontend page.
    [HttpGet("Return")]
    public async Task<IActionResult> Return()
    {
        var dict = Request.Query.ToDictionary(k => k.Key, v => (string?)v.Value);

        var valid = _vnpay.ValidateSignature(dict, out var responseCode);
        var orderRef = dict.TryGetValue("vnp_TxnRef", out var txnRef) ? txnRef : null;

        int.TryParse(orderRef, out var orderId);

        if (valid && orderId > 0)
        {
            var payment = await _context.Payments.FirstOrDefaultAsync(p => p.OrderID == orderId && p.PaymentMethod == "VNPAY");
            string? prevPaymentStatus = null;
            if (payment != null)
            {
                prevPaymentStatus = payment.Status;
                payment.Status = responseCode == "00" ? "Paid" : "Failed";
                payment.PaymentDate = DateTime.Now;
                await _context.SaveChangesAsync();
            }

            var order = await _context.Orders.FirstOrDefaultAsync(o => o.OrderID == orderId);
            if (order != null)
            {
                // Payment status is tracked on Payments table; keep Order.Status for fulfillment/shipping pipeline.
                if (responseCode == "00")
                {
                    var st = (order.Status ?? "").Trim().ToLowerInvariant();
                    if (string.IsNullOrWhiteSpace(st) || st == "pending")
                        order.Status = "Processing";

                    await ClearUserCartAsync(order.UserID);
                }
                else
                {
                    await MarkOrderFailedAndRestockAsync(order.OrderID, HttpContext.RequestAborted);
                }
                await _context.SaveChangesAsync();
            }

            if (responseCode == "00" && payment != null && !IsAlreadyPaidStatus(prevPaymentStatus))
                await TrySendPaymentSuccessEmailAsync(orderId, HttpContext.RequestAborted);
        }

        var rt = (Request.Query.TryGetValue("rt", out var rtv) ? rtv.ToString() : "").Trim().ToLowerInvariant();
        rt = rt is "app" or "web" ? rt : "web";
        var baseUrl = rt == "app" ? _vnpay.FrontendReturnUrlApp : _vnpay.FrontendReturnUrlWeb;
        var sep = baseUrl.Contains('?') ? "&" : "?";
        string? orderCode = null;
        if (int.TryParse(orderRef, out var oid) && oid > 0)
        {
            orderCode = await _context.Orders.AsNoTracking()
                .Where(o => o.OrderID == oid)
                .Select(o => o.OrderCode)
                .FirstOrDefaultAsync();
        }
        var redirect = $"{baseUrl}{sep}orderId={WebUtility.UrlEncode(orderRef ?? "")}&orderCode={WebUtility.UrlEncode(orderCode ?? "")}&code={WebUtility.UrlEncode(responseCode)}&valid={(valid ? "1" : "0")}";
        return Redirect(redirect);
    }

    // GET: api/VnPay/Ipn
    // VNPay server calls this endpoint. Must return JSON with RspCode/RspMessage.
    [HttpGet("Ipn")]
    public async Task<IActionResult> Ipn()
    {
        var dict = Request.Query.ToDictionary(k => k.Key, v => (string?)v.Value);
        var valid = _vnpay.ValidateSignature(dict, out var responseCode);
        var orderRef = dict.TryGetValue("vnp_TxnRef", out var txnRef) ? txnRef : null;

        if (!valid)
        {
            return Ok(new { RspCode = "97", RspMessage = "Invalid signature" });
        }

        if (!int.TryParse(orderRef, out var orderId) || orderId <= 0)
        {
            return Ok(new { RspCode = "01", RspMessage = "Order not found" });
        }

        var order = await _context.Orders.FirstOrDefaultAsync(o => o.OrderID == orderId);
        if (order == null)
        {
            return Ok(new { RspCode = "01", RspMessage = "Order not found" });
        }

        var payment = await _context.Payments.FirstOrDefaultAsync(p => p.OrderID == orderId && p.PaymentMethod == "VNPAY");
        string? prevPaymentStatus;
        if (payment == null)
        {
            prevPaymentStatus = null;
            payment = new Payment
            {
                OrderID = orderId,
                PaymentMethod = "VNPAY",
                Amount = order.TotalAmount,
                Status = "Pending",
                PaymentDate = DateTime.Now
            };
            _context.Payments.Add(payment);
        }
        else
        {
            prevPaymentStatus = payment.Status;
        }

        payment.Status = responseCode == "00" ? "Paid" : "Failed";
        payment.PaymentDate = DateTime.Now;
        if (responseCode == "00")
        {
            var st = (order.Status ?? "").Trim().ToLowerInvariant();
            if (string.IsNullOrWhiteSpace(st) || st == "pending")
                order.Status = "Processing";

            await ClearUserCartAsync(order.UserID);
        }
        else
        {
            await MarkOrderFailedAndRestockAsync(order.OrderID, HttpContext.RequestAborted);
        }

        await _context.SaveChangesAsync();

        if (responseCode == "00" && !IsAlreadyPaidStatus(prevPaymentStatus))
            await TrySendPaymentSuccessEmailAsync(orderId, HttpContext.RequestAborted);

        return Ok(new { RspCode = "00", RspMessage = "Confirm Success" });
    }

    private async Task MarkOrderFailedAndRestockAsync(int orderId, CancellationToken ct)
    {
        // Idempotent: chỉ hoàn kho khi lần đầu chuyển sang Failed.
        var order = await _context.Orders
            .Include(o => o.OrderDetails)
            .FirstOrDefaultAsync(o => o.OrderID == orderId, ct);
        if (order == null) return;

        var st = (order.Status ?? "").Trim().ToLowerInvariant();
        if (st is "failed" or "cancelled" or "canceled") return;

        await using var tx = await _context.Database.BeginTransactionAsync(ct);
        try
        {
            order.Status = "Failed";

            var details = order.OrderDetails ?? new List<OrderDetail>();
            foreach (var d in details)
            {
                if (d.ProductID <= 0 || d.Quantity <= 0) continue;
                var product = await _context.Products.FirstOrDefaultAsync(p => p.ProductID == d.ProductID, ct);
                if (product == null) continue;
                product.StockQuantity += d.Quantity;
            }

            await _context.SaveChangesAsync(ct);
            await tx.CommitAsync(ct);
        }
        catch
        {
            await tx.RollbackAsync(ct);
            throw;
        }
    }

    private static bool IsAlreadyPaidStatus(string? status)
    {
        var x = (status ?? "").Trim().ToLowerInvariant();
        return x is "paid" or "success";
    }

    private async Task TrySendPaymentSuccessEmailAsync(int orderId, CancellationToken ct)
    {
        try
        {
            var order = await _context.Orders
                .AsNoTracking()
                .Include(o => o.User)
                .Include(o => o.ShippingMethod)
                .Include(o => o.OrderDetails)
                .ThenInclude(od => od.Product!)
                .ThenInclude(p => p.ProductImages)
                .FirstOrDefaultAsync(o => o.OrderID == orderId, ct);

            if (order?.User == null) return;
            var to = (order.User.Email ?? "").Trim();
            if (string.IsNullOrEmpty(to)) return;

            var feBase = (_configuration["Frontend:BaseUrl"] ?? "http://localhost:5173").Trim().TrimEnd('/');
            var apiBase = (_configuration["Backend:PublicUrl"] ?? "http://localhost:5013").Trim().TrimEnd('/');
            var trackUrl = $"{feBase}/orders/{_idTokens.ProtectOrderId(orderId)}";
            var linked = new List<EmailLinkedResource>();
            var logoUrl = await EmailInlineAssets.ResolveLogoSrcAsync(_env, _configuration, linked, apiBase, ct).ConfigureAwait(false);

            var vi = CultureInfo.GetCultureInfo("vi-VN");
            var safeName = WebUtility.HtmlEncode(order.User.FullName?.Trim() ?? "Quý khách");
            var code = order.OrderCode ?? orderId.ToString(CultureInfo.InvariantCulture);
            var safeCode = WebUtility.HtmlEncode(code);
            var orderDateStr = order.OrderDate.ToString("HH:mm dd/MM/yyyy", vi);

            var details = order.OrderDetails?.ToList() ?? new List<OrderDetail>();
            var subtotal = details.Sum(d => d.UnitPrice * d.Quantity);
            var tax = Math.Round(subtotal * 0.015m, 0, MidpointRounding.AwayFromZero);
            var shipping = order.TotalAmount - subtotal - tax;
            if (shipping < 0) shipping = 0;

            var lines = new List<PaymentSuccessEmailTemplates.Line>();
            var lineIdx = 0;
            foreach (var d in details)
            {
                var p = d.Product;
                var img = p?.ProductImages?
                    .OrderByDescending(x => x.IsMainImage)
                    .Select(x => x.ImageURL)
                    .FirstOrDefault()
                    ?? p?.ProductImages?.Select(x => x.ImageURL).FirstOrDefault();
                var imgSrc = await EmailInlineAssets.ResolveProductImageSrcAsync(_env, linked, apiBase, img, d.ProductID, lineIdx, ct).ConfigureAwait(false);
                lineIdx++;
                var nm = WebUtility.HtmlEncode(p?.ProductName ?? $"Sản phẩm #{d.ProductID}");
                var lineTotal = (d.UnitPrice * d.Quantity).ToString("N0", vi) + "\u00a0đ";
                lines.Add(new PaymentSuccessEmailTemplates.Line(nm, d.Quantity, lineTotal, string.IsNullOrWhiteSpace(imgSrc) ? null : imgSrc));
            }

            string? estLine = null;
            if (order.ShippingMethod?.EstimatedDays is int ed && ed > 0)
            {
                var eta = order.OrderDate.AddDays(ed);
                estLine = "Dự kiến giao hàng: " + eta.ToString("dddd, dd/MM/yyyy", vi);
            }
            else
            {
                var eta = order.OrderDate.AddDays(1);
                estLine = "Dự kiến giao hàng: khoảng " + eta.ToString("dd/MM/yyyy", vi);
            }

            var subtotalS = subtotal.ToString("N0", vi) + "\u00a0đ";
            var shipS = shipping.ToString("N0", vi) + "\u00a0đ";
            var taxS = tax.ToString("N0", vi) + "\u00a0đ";
            var totalS = order.TotalAmount.ToString("N0", vi) + "\u00a0đ";

            var html = PaymentSuccessEmailTemplates.BuildHtml(
                logoUrlAbsolute: logoUrl,
                safeCustomerName: safeName,
                safeOrderCode: safeCode,
                orderDateDisplay: orderDateStr,
                paymentMethodVi: "VNPay (thanh toán trực tuyến)",
                lines: lines,
                safeShippingAddress: WebUtility.HtmlEncode(order.ShippingAddress ?? "—"),
                estimatedDeliveryLine: estLine,
                subtotalFormatted: subtotalS,
                shippingFormatted: shipS,
                taxFormatted: taxS,
                totalFormatted: totalS,
                trackOrderUrlAbsolute: trackUrl);

            var subject = PaymentSuccessEmailTemplates.Subject(code);
            await _emailSender.SendAsync(to, subject, html, linked.Count > 0 ? linked : null, ct).ConfigureAwait(false);
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "Không gửi được email thanh toán thành công OrderID={OrderId}", orderId);
        }
    }

    private async Task ClearUserCartAsync(int userId)
    {
        if (userId <= 0) return;

        var cart = await _context.Carts
            .Include(c => c.CartItems)
            .FirstOrDefaultAsync(c => c.UserID == userId);

        if (cart == null) return;
        if (cart.CartItems != null && cart.CartItems.Count > 0)
        {
            _context.CartItems.RemoveRange(cart.CartItems);
            cart.CartItems.Clear();
        }
        cart.UpdatedAt = DateTime.Now;
        await _context.SaveChangesAsync();
    }
}
