using System.Globalization;
using System.Net;
using System.Text;
using System.Security.Claims;
using freshfood_be.Data;
using freshfood_be.Models;
using freshfood_be.Services.Email;
using freshfood_be.Services.Momo;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace freshfood_be.Controllers;

[Route("api/[controller]")]
[ApiController]
public sealed class MomoController : ControllerBase
{
    private readonly FreshFoodContext _context;
    private readonly MomoService _momo;
    private readonly IEmailSender _emailSender;
    private readonly IConfiguration _configuration;
    private readonly IWebHostEnvironment _env;
    private readonly ILogger<MomoController> _logger;
    private readonly freshfood_be.Services.Security.IdTokenService _idTokens;

    public MomoController(
        FreshFoodContext context,
        MomoService momo,
        IEmailSender emailSender,
        IConfiguration configuration,
        IWebHostEnvironment env,
        ILogger<MomoController> logger,
        freshfood_be.Services.Security.IdTokenService idTokens)
    {
        _context = context;
        _momo = momo;
        _emailSender = emailSender;
        _configuration = configuration;
        _env = env;
        _logger = logger;
        _idTokens = idTokens;
    }

    public sealed record CreatePaymentUrlRequest(int OrderID, string? PayMethod, string? ReturnTo);
    public sealed record CreatePaymentUrlPublicRequest(string OrderCode, string? PayMethod, string? ReturnTo);
    public sealed record CreatePaymentUrlResponse(string? PaymentUrl, string? QrCodeUrl, string? Deeplink, int ResultCode, string? Message);

    // POST: api/Momo/CreatePaymentUrl
    [Authorize]
    [HttpPost("CreatePaymentUrl")]
    public async Task<ActionResult<CreatePaymentUrlResponse>> CreatePaymentUrl([FromBody] CreatePaymentUrlRequest req, CancellationToken ct)
    {
        var claimId = User?.FindFirstValue(ClaimTypes.NameIdentifier) ?? User?.FindFirstValue("sub");
        if (!int.TryParse(claimId, out var authId) || authId <= 0) return Forbid();

        var order = await _context.Orders.AsNoTracking().FirstOrDefaultAsync(o => o.OrderID == req.OrderID, ct);
        if (order == null) return NotFound("Order not found.");
        if (order.UserID != authId) return Forbid();

        var pm = (req.PayMethod ?? "").Trim().ToLowerInvariant();
        var payMethod =
            pm is "" or "method" or "paywithmethod" ? MomoService.MomoPayMethod.Method :
            pm is "atm" or "paywithatm" ? MomoService.MomoPayMethod.Atm :
            MomoService.MomoPayMethod.Wallet;

        var rt = (req.ReturnTo ?? "").Trim().ToLowerInvariant();
        rt = rt is "app" or "web" ? rt : "web";
        var backendReturn = _configuration["Momo:RedirectUrl"] ?? "";
        if (string.IsNullOrWhiteSpace(backendReturn)) backendReturn = "http://localhost/api/Momo/Return";
        var redirectUrl = backendReturn.Contains('?') ? $"{backendReturn}&rt={WebUtility.UrlEncode(rt)}" : $"{backendReturn}?rt={WebUtility.UrlEncode(rt)}";

        // If we want rt=... to flow back, we must override redirectUrl on gateway create.
        var r = await _momo.CreatePaymentUrlAsync(
            orderId: order.OrderID,
            amountVnd: order.TotalAmount,
            payMethod: payMethod,
            redirectUrlOverride: redirectUrl,
            ct: ct);

        // Ensure a pending payment record exists
        var existing = await _context.Payments.FirstOrDefaultAsync(p => p.OrderID == order.OrderID && p.PaymentMethod == "MOMO", ct);
        if (existing == null)
        {
            _context.Payments.Add(new Payment
            {
                OrderID = order.OrderID,
                PaymentMethod = "MOMO",
                Amount = order.TotalAmount,
                Status = "Pending",
                PaymentDate = DateTime.Now
            });
            await _context.SaveChangesAsync(ct);
        }

        return new CreatePaymentUrlResponse(r.PayUrl, r.QrCodeUrl, r.Deeplink, r.ResultCode, r.Message);
    }

    // POST: api/Momo/CreatePaymentUrlPublic
    // Public (guest) flow: use unguessable OrderCode instead of auth-bound OrderID.
    [HttpPost("CreatePaymentUrlPublic")]
    public async Task<ActionResult<CreatePaymentUrlResponse>> CreatePaymentUrlPublic([FromBody] CreatePaymentUrlPublicRequest req, CancellationToken ct)
    {
        var code = (req.OrderCode ?? "").Trim();
        if (string.IsNullOrWhiteSpace(code)) return BadRequest("Missing orderCode.");

        var order = await _context.Orders.AsNoTracking().FirstOrDefaultAsync(o => o.OrderCode != null && o.OrderCode.Trim() == code, ct);
        if (order == null) return NotFound("Order not found.");

        var pm = (req.PayMethod ?? "").Trim().ToLowerInvariant();
        var payMethod =
            pm is "" or "method" or "paywithmethod" ? MomoService.MomoPayMethod.Method :
            pm is "atm" or "paywithatm" ? MomoService.MomoPayMethod.Atm :
            MomoService.MomoPayMethod.Wallet;

        var rt = (req.ReturnTo ?? "").Trim().ToLowerInvariant();
        rt = rt is "app" or "web" ? rt : "web";
        var backendReturn = _configuration["Momo:RedirectUrl"] ?? "";
        if (string.IsNullOrWhiteSpace(backendReturn)) backendReturn = "http://localhost/api/Momo/Return";
        var redirectUrl = backendReturn.Contains('?') ? $"{backendReturn}&rt={WebUtility.UrlEncode(rt)}" : $"{backendReturn}?rt={WebUtility.UrlEncode(rt)}";

        var r = await _momo.CreatePaymentUrlAsync(
            orderId: order.OrderID,
            amountVnd: order.TotalAmount,
            payMethod: payMethod,
            redirectUrlOverride: redirectUrl,
            ct: ct);

        // Ensure a pending payment record exists
        var existing = await _context.Payments.FirstOrDefaultAsync(p => p.OrderID == order.OrderID && p.PaymentMethod == "MOMO", ct);
        if (existing == null)
        {
            _context.Payments.Add(new Payment
            {
                OrderID = order.OrderID,
                PaymentMethod = "MOMO",
                Amount = order.TotalAmount,
                Status = "Pending",
                PaymentDate = DateTime.Now
            });
            await _context.SaveChangesAsync(ct);
        }

        return new CreatePaymentUrlResponse(r.PayUrl, r.QrCodeUrl, r.Deeplink, r.ResultCode, r.Message);
    }

    // GET: api/Momo/Return
    // MoMo redirects the customer here. Validate signature and redirect to frontend page.
    [HttpGet("Return")]
    public async Task<IActionResult> Return(CancellationToken ct)
    {
        var cb = FromQuery(Request.Query);
        var valid = _momo.ValidateReturnOrIpnSignature(cb);

        var orderId = ResolveInternalOrderId(cb);
        var orderIdStr = orderId?.ToString() ?? "";

        if (valid && orderId is > 0)
        {
            var ok = cb.ResultCode == 0;

            var payment = await _context.Payments.FirstOrDefaultAsync(p => p.OrderID == orderId.Value && p.PaymentMethod == "MOMO", ct);
            string? prevPaymentStatus = null;
            if (payment != null)
            {
                prevPaymentStatus = payment.Status;
                payment.Status = ok ? "Paid" : "Failed";
                payment.PaymentDate = DateTime.Now;
                await _context.SaveChangesAsync(ct);
            }

            var order = await _context.Orders.FirstOrDefaultAsync(o => o.OrderID == orderId.Value, ct);
            if (order != null)
            {
                if (ok)
                {
                    var st = (order.Status ?? "").Trim().ToLowerInvariant();
                    if (string.IsNullOrWhiteSpace(st) || st == "pending")
                        order.Status = "Processing";

                    await ClearUserCartAsync(order.UserID, ct);
                }
                else
                {
                    await MarkOrderFailedAndRestockAsync(order.OrderID, ct);
                }
                await _context.SaveChangesAsync(ct);
            }

            if (ok && payment != null && !IsAlreadyPaidStatus(prevPaymentStatus))
                await TrySendPaymentSuccessEmailAsync(orderId.Value, "MoMo (thanh toán trực tuyến)", ct);
        }

        var code = cb.ResultCode?.ToString() ?? "";
        var rt = (Request.Query.TryGetValue("rt", out var rtv) ? rtv.ToString() : "").Trim().ToLowerInvariant();
        rt = rt is "app" or "web" ? rt : "web";
        var baseUrl = rt == "app" ? _momo.FrontendReturnUrlApp : _momo.FrontendReturnUrlWeb;
        var sep = baseUrl.Contains('?') ? "&" : "?";
        string? orderCode = null;
        if (orderId is > 0)
        {
            orderCode = await _context.Orders.AsNoTracking()
                .Where(o => o.OrderID == orderId.Value)
                .Select(o => o.OrderCode)
                .FirstOrDefaultAsync(ct);
        }
        var redirect = $"{baseUrl}{sep}orderId={WebUtility.UrlEncode(orderIdStr)}&orderCode={WebUtility.UrlEncode(orderCode ?? "")}&code={WebUtility.UrlEncode(code)}&valid={(valid ? "1" : "0")}";
        return Redirect(redirect);
    }

    // POST: api/Momo/Ipn
    // MoMo server calls this endpoint with JSON body.
    [HttpPost("Ipn")]
    public async Task<IActionResult> Ipn([FromBody] MomoCallback cb, CancellationToken ct)
    {
        var valid = _momo.ValidateReturnOrIpnSignature(cb);
        if (!valid)
            return Ok(new { resultCode = 97, message = "Invalid signature" });

        var orderId = ResolveInternalOrderId(cb);
        if (orderId is not > 0)
            return Ok(new { resultCode = 1, message = "Order not found" });

        var order = await _context.Orders.FirstOrDefaultAsync(o => o.OrderID == orderId.Value, ct);
        if (order == null)
            return Ok(new { resultCode = 1, message = "Order not found" });

        var ok = cb.ResultCode == 0;

        var payment = await _context.Payments.FirstOrDefaultAsync(p => p.OrderID == orderId.Value && p.PaymentMethod == "MOMO", ct);
        string? prevPaymentStatus;
        if (payment == null)
        {
            prevPaymentStatus = null;
            payment = new Payment
            {
                OrderID = orderId.Value,
                PaymentMethod = "MOMO",
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

        payment.Status = ok ? "Paid" : "Failed";
        payment.PaymentDate = DateTime.Now;

        if (ok)
        {
            var st = (order.Status ?? "").Trim().ToLowerInvariant();
            if (string.IsNullOrWhiteSpace(st) || st == "pending")
                order.Status = "Processing";

            await ClearUserCartAsync(order.UserID, ct);
        }
        else
        {
            await MarkOrderFailedAndRestockAsync(order.OrderID, ct);
        }

        await _context.SaveChangesAsync(ct);

        if (ok && !IsAlreadyPaidStatus(prevPaymentStatus))
            await TrySendPaymentSuccessEmailAsync(orderId.Value, "MoMo (thanh toán trực tuyến)", ct);

        return Ok(new { resultCode = 0, message = "Confirm Success" });
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

    private static int? ResolveInternalOrderId(MomoCallback cb)
    {
        // Preferred: extraData carries internal orderId.
        var extra = (cb.ExtraData ?? "").Trim();
        if (!string.IsNullOrWhiteSpace(extra))
        {
            try
            {
                var decoded = Encoding.UTF8.GetString(Convert.FromBase64String(extra));
                // format: orderId=123
                var parts = decoded.Split('=', 2, StringSplitOptions.TrimEntries);
                if (parts.Length == 2 && parts[0].Equals("orderId", StringComparison.OrdinalIgnoreCase))
                {
                    if (int.TryParse(parts[1], out var id1) && id1 > 0) return id1;
                }
            }
            catch
            {
                // ignore invalid extraData
            }
        }

        // Fallback: cb.orderId might be "123-<requestId>".
        var oid = (cb.OrderId ?? "").Trim();
        if (string.IsNullOrWhiteSpace(oid)) return null;
        var dash = oid.IndexOf('-', StringComparison.Ordinal);
        if (dash > 0) oid = oid[..dash];
        return int.TryParse(oid, out var id2) && id2 > 0 ? id2 : null;
    }

    private static MomoCallback FromQuery(IQueryCollection q)
    {
        long? ParseLong(string key) => q.TryGetValue(key, out var v) && long.TryParse(v.ToString(), out var x) ? x : null;
        int? ParseInt(string key) => q.TryGetValue(key, out var v) && int.TryParse(v.ToString(), out var x) ? x : null;
        string? Str(string key) => q.TryGetValue(key, out var v) ? v.ToString() : null;

        return new MomoCallback
        {
            PartnerCode = Str("partnerCode"),
            OrderId = Str("orderId"),
            RequestId = Str("requestId"),
            Amount = ParseLong("amount"),
            OrderInfo = Str("orderInfo"),
            OrderType = Str("orderType"),
            TransId = ParseLong("transId"),
            ResultCode = ParseInt("resultCode"),
            Message = Str("message"),
            PayType = Str("payType"),
            ResponseTime = ParseLong("responseTime"),
            ExtraData = Str("extraData"),
            Signature = Str("signature")
        };
    }

    private static bool IsAlreadyPaidStatus(string? status)
    {
        var x = (status ?? "").Trim().ToLowerInvariant();
        return x is "paid" or "success";
    }

    private async Task TrySendPaymentSuccessEmailAsync(int orderId, string paymentMethodVi, CancellationToken ct)
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

            string? estLine;
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
                paymentMethodVi: paymentMethodVi,
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
            _logger.LogWarning(ex, "Không gửi được email thanh toán MoMo thành công OrderID={OrderId}", orderId);
        }
    }

    private async Task ClearUserCartAsync(int userId, CancellationToken ct)
    {
        if (userId <= 0) return;

        var cart = await _context.Carts
            .Include(c => c.CartItems)
            .FirstOrDefaultAsync(c => c.UserID == userId, ct);

        if (cart == null) return;
        if (cart.CartItems != null && cart.CartItems.Count > 0)
        {
            _context.CartItems.RemoveRange(cart.CartItems);
            cart.CartItems.Clear();
        }
        cart.UpdatedAt = DateTime.Now;
        await _context.SaveChangesAsync(ct);
    }
}

