using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;
using freshfood_be.Data;
using freshfood_be.Models;
using freshfood_be.Services.Email;
using System.ComponentModel.DataAnnotations;
using System.Globalization;
using System.Net;
using System.Security.Cryptography;
using System.Text;
using System.IO;
using System.Security.Claims;
using System.Text.Json;

namespace freshfood_be.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    public class OrdersController : ControllerBase
    {
        private const string GuestActivatePurpose = "guest_activate";

        private readonly FreshFoodContext _context;
        private readonly IEmailSender _emailSender;
        private readonly IConfiguration _configuration;
        private readonly ILogger<OrdersController> _logger;
        private readonly IWebHostEnvironment _env;
        private readonly IOptions<EmailSettings> _emailOptions;
        private readonly freshfood_be.Services.Security.IdTokenService _idTokens;

        public OrdersController(
            FreshFoodContext context,
            IEmailSender emailSender,
            IConfiguration configuration,
            ILogger<OrdersController> logger,
            IWebHostEnvironment env,
            IOptions<EmailSettings> emailOptions,
            freshfood_be.Services.Security.IdTokenService idTokens)
        {
            _context = context;
            _emailSender = emailSender;
            _configuration = configuration;
            _logger = logger;
            _env = env;
            _emailOptions = emailOptions;
            _idTokens = idTokens;
        }

        private int? GetAuthUserId()
        {
            var v = User?.FindFirstValue(ClaimTypes.NameIdentifier) ?? User?.FindFirstValue("sub");
            return int.TryParse(v, out var id) && id > 0 ? id : null;
        }

        // GET: api/Orders/User/5
        [Authorize]
        [HttpGet("User/{userId}")]
        public async Task<ActionResult<IEnumerable<Order>>> GetUserOrders(int userId)
        {
            var claimId = User?.FindFirstValue(ClaimTypes.NameIdentifier) ?? User?.FindFirstValue("sub");
            if (!int.TryParse(claimId, out var authId) || authId <= 0) return Forbid();
            if (authId != userId) return Forbid();
            var orders = await _context.Orders
                .AsNoTracking()
                .Where(o => o.UserID == userId)
                .Include(o => o.Payments)
                .Include(o => o.Shipments)
                .Include(o => o.OrderDetails)
                    .ThenInclude(od => od.Product!)
                    .ThenInclude(p => p.ProductImages)
                .ToListAsync();

            // Derive a user-friendly order status for return/refund flows so the history page matches the detail page.
            // Mapping (based on latest return request per order):
            // - RequestType=Return:
            //   - Pending  => ReturnPending
            //   - Approved => Returned OR Refunded (if RefundProofUrl exists)
            // - RequestType=CancelRefund:
            //   - Pending  => RefundPending
            //   - Approved => Refunded (if RefundProofUrl exists) else RefundPending
            var orderIds = orders.Select(o => o.OrderID).Distinct().ToList();
            if (orderIds.Count > 0)
            {
                var latestRrs = await _context.ReturnRequests
                    .AsNoTracking()
                    .Where(r => r.UserID == userId && orderIds.Contains(r.OrderID))
                    .GroupBy(r => r.OrderID)
                    .Select(g => g.OrderByDescending(x => x.CreatedAt).FirstOrDefault())
                    .ToListAsync();

                foreach (var o in orders)
                {
                    var rr = latestRrs.FirstOrDefault(x => x != null && x.OrderID == o.OrderID);
                    if (rr == null) continue;

                    var rt = (rr.RequestType ?? "").Trim().ToLowerInvariant();
                    if (string.IsNullOrWhiteSpace(rt)) rt = "return";

                    // Never override a failed order status.
                    // For CancelRefund flow, allow override on Cancelled so users can see refund state.
                    var baseLower = (o.Status ?? "").Trim().ToLowerInvariant();
                    if (baseLower == "failed") continue;
                    if ((baseLower == "cancelled" || baseLower == "canceled") && rt != "cancelrefund") continue;

                    var rrSt = (rr.Status ?? "").Trim().ToLowerInvariant();
                    if (rt == "return")
                    {
                        if (rrSt == "pending")
                        {
                            o.Status = "ReturnPending";
                            continue;
                        }

                        if (rrSt == "approved")
                        {
                            o.Status = string.IsNullOrWhiteSpace(rr.RefundProofUrl) ? "Returned" : "Refunded";
                        }
                    }
                    else if (rt == "cancelrefund")
                    {
                        if (rrSt == "pending")
                        {
                            o.Status = "RefundPending";
                            continue;
                        }

                        if (rrSt == "approved")
                        {
                            o.Status = string.IsNullOrWhiteSpace(rr.RefundProofUrl) ? "RefundPending" : "Refunded";
                        }
                    }
                }
            }

            foreach (var o in orders)
                o.OrderToken = _idTokens.ProtectOrderId(o.OrderID);

            return orders;
        }

        // GET: api/Orders/5  (id:int tránh trùng với api/Orders/track)
        [Authorize]
        [HttpGet("{id:int}")]
        public async Task<ActionResult<Order>> GetOrder(int id)
        {
            var authId = GetAuthUserId();
            if (authId is not > 0) return Forbid();

            var order = await _context.Orders
                .Include(o => o.Payments)
                .Include(o => o.Shipments)
                .Include(o => o.OrderDetails)
                .ThenInclude(od => od.Product!)
                .ThenInclude(p => p.ProductImages)
                .FirstOrDefaultAsync(o => o.OrderID == id);

            if (order == null)
            {
                return NotFound();
            }

            var role = (User?.FindFirstValue(ClaimTypes.Role) ?? "").Trim().ToLowerInvariant();
            var isAdmin = role == "admin";
            if (!isAdmin && order.UserID != authId.Value) return Forbid();

            order.OrderToken = _idTokens.ProtectOrderId(order.OrderID);
            return order;
        }

        // GET: api/Orders/token/xxxx  (tokenized id)
        [Authorize]
        [HttpGet("token/{token}")]
        public async Task<ActionResult<Order>> GetOrderByToken([FromRoute] string token)
        {
            if (string.IsNullOrWhiteSpace(token)) return NotFound();
            var id = _idTokens.UnprotectOrderId(token.Trim());
            if (id == null || id <= 0) return NotFound();
            return await GetOrder(id.Value);
        }

        public record PublicShipmentTrackDto(
            int ShipmentID,
            string? TrackingNumber,
            string? Carrier,
            string? Status,
            DateTime? ShippedDate,
            DateTime? EstimatedDeliveryDate,
            DateTime? ActualDeliveryDate);

        public record PublicOrderTrackDto(
            string OrderCode,
            string Status,
            DateTime OrderDate,
            IReadOnlyList<PublicShipmentTrackDto> Shipments);

        private static string DigitsOnly(string? s) =>
            s == null ? "" : new string(s.Where(char.IsDigit).ToArray());

        /// <summary>Tra cứu công khai: mã đơn + SĐT đặt hàng (khớp số trong tài khoản).</summary>
        [HttpGet("track")]
        public async Task<ActionResult<PublicOrderTrackDto>> TrackOrder([FromQuery] string? orderCode, [FromQuery] string? phone)
        {
            var code = (orderCode ?? "").Trim();
            var phoneDigits = DigitsOnly(phone);
            if (string.IsNullOrWhiteSpace(code) || phoneDigits.Length < 9)
                return NotFound();

            var order = await _context.Orders
                .AsNoTracking()
                .Include(o => o.User)
                .Include(o => o.Shipments)
                .FirstOrDefaultAsync(o =>
                    o.OrderCode != null &&
                    o.OrderCode.Trim().ToLower() == code.ToLowerInvariant());

            if (order == null) return NotFound();

            var userDigits = DigitsOnly(order.User?.Phone);
            if (string.IsNullOrEmpty(userDigits) || userDigits != phoneDigits)
                return NotFound();

            var shipments = (order.Shipments ?? new List<Shipment>())
                .OrderBy(s => s.ShipmentID)
                .Select(s => new PublicShipmentTrackDto(
                    s.ShipmentID,
                    s.TrackingNumber,
                    s.Carrier,
                    s.Status,
                    s.ShippedDate,
                    s.EstimatedDeliveryDate,
                    s.ActualDeliveryDate))
                .ToList();

            return Ok(new PublicOrderTrackDto(
                order.OrderCode ?? $"#VH-{order.OrderID:D4}",
                order.Status ?? "Pending",
                order.OrderDate,
                shipments));
        }

        public class GuestCheckoutDto
        {
            [Required, StringLength(100)]
            public string FullName { get; set; } = string.Empty;

            [Required, EmailAddress, StringLength(100)]
            public string Email { get; set; } = string.Empty;

            [Required, StringLength(20)]
            public string Phone { get; set; } = string.Empty;
        }

        public class CreateOrderDto
        {
            /// <summary>Đặt hàng khi đã đăng nhập. Bỏ trống nếu dùng <see cref="GuestCheckout"/>.</summary>
            public int? UserID { get; set; }

            /// <summary>Đặt hàng khách: tạo/ghép tài khoản khách theo email.</summary>
            public GuestCheckoutDto? GuestCheckout { get; set; }

            public string ShippingAddress { get; set; } = string.Empty;

            /// <summary>Khi đã đăng nhập: dùng địa chỉ trong sổ (bỏ qua <see cref="ShippingAddress"/> nếu hợp lệ).</summary>
            public int? ShippingAddressId { get; set; }

            public int? ShippingMethodID { get; set; }
            public List<OrderItemDto> Items { get; set; } = new List<OrderItemDto>();
            // Default COD if not provided by client
            public string? PaymentMethod { get; set; }
            public string? VoucherCode { get; set; }
        }

        public class OrderItemDto
        {
            public int ProductID { get; set; }
            public int Quantity { get; set; }
        }

        public class ConfirmReceivedDto
        {
            public int UserID { get; set; }
        }

        public class CreateReturnRequestDto
        {
            public int UserID { get; set; }
            public string Reason { get; set; } = string.Empty;
            public List<IFormFile> Files { get; set; } = new();
        }

        // POST: api/Orders
        [HttpPost]
        public async Task<ActionResult<Order>> CreateOrder(CreateOrderDto orderDto)
        {
            if (orderDto == null || !orderDto.Items.Any())
            {
                return BadRequest("Invalid order data.");
            }

            var idempotencyKey = (Request.Headers["Idempotency-Key"].FirstOrDefault() ?? string.Empty).Trim();
            OrderIdempotency? idem = null;
            var requestHash = ComputeCreateOrderRequestHash(orderDto);
            if (!string.IsNullOrWhiteSpace(idempotencyKey))
            {
                try
                {
                    idem = await TryBeginIdempotentOrderRequestAsync(idempotencyKey, requestHash, orderDto);
                }
                catch (InvalidOperationException ex)
                {
                    return Conflict(new { message = ex.Message });
                }
                if (idem == null)
                {
                    return Conflict(new { message = "Yêu cầu tạo đơn đang được xử lý. Vui lòng đợi trong giây lát." });
                }

                if (idem.OrderID is > 0)
                {
                    var existing = await _context.Orders
                        .Include(o => o.OrderDetails)
                        .Include(o => o.Payments)
                        .Include(o => o.Shipments)
                        .FirstOrDefaultAsync(o => o.OrderID == idem.OrderID.Value);
                    if (existing != null)
                    {
                        existing.OrderToken = _idTokens.ProtectOrderId(existing.OrderID);
                        return CreatedAtAction(nameof(GetOrder), new { id = existing.OrderID }, existing);
                    }
                }
            }

            var notifyGuestAfterOrder = orderDto.GuestCheckout != null && orderDto.UserID is not > 0;

            using var transaction = await _context.Database.BeginTransactionAsync();
            try
            {
                int resolvedUserId;
                try
                {
                    resolvedUserId = await ResolveCheckoutUserIdAsync(orderDto);
                }
                catch (InvalidOperationException ex) when (ex.Message == "EMAIL_REGISTERED")
                {
                    await transaction.RollbackAsync();
                    return Conflict("Email này đã có tài khoản. Vui lòng đăng nhập để đặt hàng.");
                }
                catch (InvalidOperationException ex)
                {
                    await transaction.RollbackAsync();
                    return BadRequest(ex.Message);
                }

                string shippingText;
                if (orderDto.ShippingAddressId is int addrId && addrId > 0)
                {
                    if (orderDto.GuestCheckout != null || orderDto.UserID is not > 0)
                    {
                        await transaction.RollbackAsync();
                        return BadRequest("Địa chỉ đã lưu chỉ dùng khi đã đăng nhập.");
                    }

                    var ua = await _context.UserAddresses.AsNoTracking()
                        .FirstOrDefaultAsync(a => a.UserAddressID == addrId && a.UserID == resolvedUserId);
                    if (ua == null)
                    {
                        await transaction.RollbackAsync();
                        return BadRequest("Không tìm thấy địa chỉ đã lưu.");
                    }

                    var usr = await _context.Users.AsNoTracking().FirstAsync(u => u.UserID == resolvedUserId);
                    var phone = string.IsNullOrWhiteSpace(ua.Phone) ? "" : ua.Phone.Trim();
                    shippingText = $"{ua.RecipientName.Trim()} - {phone} - {usr.Email} - {ua.AddressLine.Trim()}";
                }
                else
                {
                    shippingText = (orderDto.ShippingAddress ?? string.Empty).Trim();
                    if (string.IsNullOrWhiteSpace(shippingText))
                    {
                        await transaction.RollbackAsync();
                        return BadRequest("Thiếu địa chỉ giao hàng.");
                    }
                }

                var order = new Order
                {
                    UserID = resolvedUserId,
                    ShippingAddress = shippingText,
                    OrderDate = DateTime.Now,
                    // Default pipeline status: order placed, awaiting confirmation.
                    Status = "Pending",
                    TotalAmount = 0
                };

                _context.Orders.Add(order);
                await _context.SaveChangesAsync();

                decimal total = 0;
                foreach (var item in orderDto.Items)
                {
                    var product = await _context.Products.FindAsync(item.ProductID);
                    if (product == null)
                    {
                        await transaction.RollbackAsync();
                        return BadRequest($"Không tìm thấy sản phẩm (mã #{item.ProductID}).");
                    }

                    if (item.Quantity <= 0)
                    {
                        await transaction.RollbackAsync();
                        return BadRequest($"Số lượng không hợp lệ cho sản phẩm \"{product.ProductName}\".");
                    }

                    // Pricing: follow FE cart rule (use DiscountPrice when valid).
                    // This keeps online payment amount consistent with what users see in Cart/Checkout.
                    var unitPrice = product.Price;
                    if (product.DiscountPrice is decimal dp && dp > 0 && dp < product.Price)
                        unitPrice = dp;

                    // Atomic stock decrement to avoid oversell under concurrency.
                    // If another checkout is decrementing at the same time, this UPDATE will fail (0 rows affected).
                    var rows = await _context.Database.ExecuteSqlInterpolatedAsync($"""
                        UPDATE "Products"
                        SET "StockQuantity" = "StockQuantity" - {item.Quantity}
                        WHERE "ProductID" = {item.ProductID} AND "StockQuantity" >= {item.Quantity}
                        """);
                    if (rows <= 0)
                    {
                        await transaction.RollbackAsync();
                        var latestStock = await _context.Products.AsNoTracking()
                            .Where(p => p.ProductID == item.ProductID)
                            .Select(p => p.StockQuantity)
                            .FirstOrDefaultAsync();
                        return BadRequest(
                            $"Sản phẩm \"{product.ProductName}\" chỉ còn {latestStock} trong kho; bạn đang đặt {item.Quantity}. Vui lòng giảm số lượng hoặc xóa khỏi giỏ.");
                    }

                    var detail = new OrderDetail
                    {
                        OrderID = order.OrderID,
                        ProductID = item.ProductID,
                        Quantity = item.Quantity,
                        UnitPrice = unitPrice
                    };

                    total += detail.UnitPrice * detail.Quantity;
                    _context.OrderDetails.Add(detail);
                }

                // Pricing: keep consistent with FE Cart/Checkout
                var subtotal = total;
                // Shipping fee is based on subtotal BEFORE VAT and BEFORE shipping fee.
                // If subtotal >= 200k => freeship, otherwise fee = selected shipping method base cost.
                var methodId = orderDto.ShippingMethodID;
                var method = methodId.HasValue
                    ? await _context.ShippingMethods.AsNoTracking().FirstOrDefaultAsync(sm => sm.MethodID == methodId.Value)
                    : await _context.ShippingMethods.AsNoTracking().OrderBy(sm => sm.BaseCost).FirstOrDefaultAsync();

                if (methodId.HasValue && method == null)
                {
                    await transaction.RollbackAsync();
                    return BadRequest("Không tìm thấy phương thức vận chuyển đã chọn.");
                }

                order.ShippingMethodID = method?.MethodID;

                var baseShipping = method?.BaseCost ?? 30000m;
                var shipping = subtotal >= 200000m ? 0m : baseShipping;
                var discount = 0m;

                Voucher? voucher = null;
                if (!string.IsNullOrWhiteSpace(orderDto.VoucherCode))
                {
                    var code = orderDto.VoucherCode.Trim();
                    voucher = await _context.Vouchers.FirstOrDefaultAsync(v => v.Code == code);
                    if (voucher == null)
                    {
                        await transaction.RollbackAsync();
                        return BadRequest("Mã giảm giá không tồn tại.");
                    }

                    if (!voucher.IsActive)
                    {
                        await transaction.RollbackAsync();
                        return BadRequest("Mã giảm giá hiện không hoạt động.");
                    }

                    if (voucher.ExpiryDate != null && voucher.ExpiryDate <= DateTime.UtcNow)
                    {
                        await transaction.RollbackAsync();
                        return BadRequest("Mã giảm giá đã hết hạn.");
                    }

                    if (subtotal < voucher.MinOrderAmount)
                    {
                        await transaction.RollbackAsync();
                        return BadRequest($"Đơn hàng chưa đạt giá trị tối thiểu để dùng mã này ({voucher.MinOrderAmount:N0}đ).");
                    }

                    var used = await _context.VoucherUsages.AnyAsync(vu => vu.UserID == resolvedUserId && vu.VoucherID == voucher.VoucherID);
                    if (used)
                    {
                        await transaction.RollbackAsync();
                        return BadRequest("Bạn đã sử dụng mã giảm giá này rồi.");
                    }

                    discount = ComputeDiscount(voucher, subtotal);
                    order.VoucherID = voucher.VoucherID;
                }

                var subtotalAfterDiscount = Math.Max(0m, subtotal - discount);
                var estimatedTax = Math.Round(subtotalAfterDiscount * 0.015m, 0, MidpointRounding.AwayFromZero);
                var grandTotal = subtotalAfterDiscount + shipping + estimatedTax;

                order.TotalAmount = grandTotal;
                await _context.SaveChangesAsync();

                // Create shipment row (so admin can track delivery later).
                if (method != null)
                {
                    _context.Shipments.Add(new Shipment
                    {
                        OrderID = order.OrderID,
                        Status = "Pending",
                        EstimatedDeliveryDate = method.EstimatedDays.HasValue ? DateTime.Now.AddDays(method.EstimatedDays.Value) : null
                    });
                    await _context.SaveChangesAsync();
                }

                if (voucher != null)
                {
                    _context.VoucherUsages.Add(new VoucherUsage
                    {
                        UserID = resolvedUserId,
                        VoucherID = voucher.VoucherID,
                        OrderID = order.OrderID,
                        UsedAt = DateTime.UtcNow
                    });
                    await _context.SaveChangesAsync();
                }

                // Generate a friendly order code after we have OrderID
                if (string.IsNullOrWhiteSpace(order.OrderCode))
                {
                    order.OrderCode = await GenerateUniqueOrderCodeAsync();
                    await _context.SaveChangesAsync();
                }

                // Create a payment record (COD by default). VNPay flow will create/update its own payment row later.
                var paymentMethod = string.IsNullOrWhiteSpace(orderDto.PaymentMethod) ? "COD" : orderDto.PaymentMethod.Trim().ToUpperInvariant();
                if (paymentMethod is "VNPAY" or "MOMO" or "MOMO_ATM")
                {
                    // leave as-is; Online payment controller will create Pending payment when generating payment URL
                }
                else
                {
                    _context.Payments.Add(new Payment
                    {
                        OrderID = order.OrderID,
                        PaymentMethod = "COD",
                        Amount = order.TotalAmount,
                        Status = "Pending",
                        PaymentDate = DateTime.Now
                    });
                    await _context.SaveChangesAsync();
                }

                // Clear DB-backed cart after placing order (non-VNPay).
                // For VNPay, we clear cart when payment succeeds (see VnPayController Return/IPN).
                // For MoMo, we clear cart when payment succeeds (see MomoController Return/IPN).
                if (paymentMethod is not ("VNPAY" or "MOMO" or "MOMO_ATM"))
                {
                    await ClearUserCartAsync(resolvedUserId);
                }

                await transaction.CommitAsync();

                if (idem != null)
                {
                    idem.OrderID = order.OrderID;
                    idem.CompletedAtUtc = DateTime.UtcNow;
                    await _context.SaveChangesAsync();
                }

                // Online payments: mail thanh toán thành công gửi từ controller tương ứng (VNPay/MoMo).
                // Email “cập nhật trạng thái đơn” chỉ khi Đã giao (Admin).
                if (resolvedUserId > 0 && paymentMethod is not ("VNPAY" or "MOMO" or "MOMO_ATM"))
                    await TrySendOrderPlacedEmailAsync(order.OrderID, HttpContext.RequestAborted);

                if (notifyGuestAfterOrder && resolvedUserId > 0)
                {
                    try
                    {
                        await TrySendGuestAccountSetupEmailAsync(resolvedUserId, HttpContext.RequestAborted);
                    }
                    catch (Exception mailEx)
                    {
                        _logger.LogWarning(mailEx, "Không gửi được email tạo mật khẩu (guest) cho UserID={UserId}", resolvedUserId);
                    }
                }

                return CreatedAtAction(nameof(GetOrder), new { id = order.OrderID }, order);
            }
            catch (Exception ex)
            {
                await transaction.RollbackAsync();
                if (idem != null && idem.OrderID is not > 0)
                {
                    try
                    {
                        _context.OrderIdempotencies.Remove(idem);
                        await _context.SaveChangesAsync();
                    }
                    catch
                    {
                        // ignore cleanup failure; key may expire or be handled manually
                    }
                }
                _logger.LogError(ex, "CreateOrder failed unexpectedly");
                return StatusCode(500, "Không tạo được đơn hàng do lỗi máy chủ. Vui lòng thử lại sau.");
            }
        }

        // POST: api/Orders/5/confirm-cod-paid
        // Mark COD payment as Paid (manual confirmation).
        [HttpPost("{id:int}/confirm-cod-paid")]
        public async Task<ActionResult<Order>> ConfirmCodPaid(int id)
        {
            var order = await _context.Orders
                .Include(o => o.Payments)
                .FirstOrDefaultAsync(o => o.OrderID == id);

            if (order == null) return NotFound();

            var orderSt = (order.Status ?? "").Trim().ToLowerInvariant();
            if (orderSt is "cancelled" or "canceled" or "failed")
                return BadRequest("Không thể xác nhận thanh toán cho đơn đã hủy / thất bại.");

            var payment = order.Payments
                .OrderByDescending(p => p.PaymentDate)
                .FirstOrDefault(p => (p.PaymentMethod ?? "").ToUpper() == "COD");

            if (payment == null) return BadRequest("COD payment not found.");

            var status = (payment.Status ?? "").ToLowerInvariant();
            if (status == "paid" || status == "success")
            {
                return Ok(order);
            }

            payment.Status = "Paid";
            payment.PaymentDate = DateTime.Now;
            
            // Payment status is tracked on Payments table.
            // Order status should represent fulfillment/shipping pipeline (Pending/Processing/Shipping/Delivered...),
            // so do NOT overwrite it with "Paid".
            if (string.IsNullOrWhiteSpace(order.Status) || order.Status.Trim().ToLowerInvariant() == "pending")
            {
                order.Status = "Processing";
            }

            await _context.SaveChangesAsync();

            await TrySendCodPaymentConfirmedEmailAsync(id, HttpContext.RequestAborted);

            return Ok(order);
        }

        // POST: api/Orders/5/confirm-received
        // Customer confirms they have received the goods (moves Order.Status -> Completed).
        [Authorize]
        [HttpPost("{id:int}/confirm-received")]
        public async Task<ActionResult<Order>> ConfirmReceived(int id, [FromBody] ConfirmReceivedDto dto)
        {
            var order = await _context.Orders
                .Include(o => o.Shipments)
                .FirstOrDefaultAsync(o => o.OrderID == id);

            if (order == null) return NotFound();
            var authId = GetAuthUserId();
            if (authId is not > 0) return Forbid();
            if (dto == null || dto.UserID <= 0 || dto.UserID != authId.Value) return Forbid();
            if (order.UserID != authId.Value) return StatusCode(403, "Forbidden.");

            var st = (order.Status ?? "").Trim().ToLowerInvariant();
            if (st == "completed") return Ok(order);

            // Only allow confirm-received if order is delivered (or shipment indicates delivered).
            var deliveredByShipment = order.Shipments?.Any(s =>
                !string.IsNullOrWhiteSpace(s.Status) && s.Status.Trim().ToLowerInvariant() == "delivered") == true
                || order.Shipments?.Any(s => s.ActualDeliveryDate != null) == true;

            if (st != "delivered" && st != "completed" && !deliveredByShipment)
            {
                return BadRequest("Order is not delivered yet.");
            }

            order.Status = "Completed";

            // If we have a shipment row but missing delivery date, set it for consistency.
            var primary = order.Shipments?.OrderByDescending(s => s.ShippedDate ?? DateTime.MinValue).FirstOrDefault();
            if (primary != null)
            {
                if (string.IsNullOrWhiteSpace(primary.Status)) primary.Status = "Delivered";
                if (primary.ActualDeliveryDate == null) primary.ActualDeliveryDate = DateTime.Now;
            }

            await _context.SaveChangesAsync();
            return Ok(order);
        }

        public record CancelOrderDto(int? UserID, string? Reason);

        public record MarkPaymentFailedDto(int? UserID, string? Provider, string? Code);

        // POST: api/Orders/5/mark-payment-failed
        // Fallback endpoint: FE gọi khi return page báo fail (valid=1) để đảm bảo đơn Failed và hoàn kho.
        [Authorize]
        [HttpPost("{id:int}/mark-payment-failed")]
        public async Task<ActionResult<Order>> MarkPaymentFailed(int id, [FromBody] MarkPaymentFailedDto dto)
        {
            var authId = GetAuthUserId();
            if (authId is not > 0) return Forbid();
            if (dto == null || dto.UserID <= 0 || dto.UserID != authId.Value) return Forbid();

            var order = await _context.Orders
                .Include(o => o.Shipments)
                .Include(o => o.OrderDetails)
                .FirstOrDefaultAsync(o => o.OrderID == id);
            if (order == null) return NotFound();
            if (order.UserID != authId.Value) return StatusCode(403, "Forbidden.");

            var st = (order.Status ?? "").Trim().ToLowerInvariant();
            if (st is "failed" or "cancelled" or "canceled") return Ok(order);

            // Không cho phép đánh fail nếu đơn đã giao/đang giao.
            if (st is "shipping" or "intransit" or "in_transit" or "delivered" or "completed" or "returned" or "refunded" or "returnpending")
                return BadRequest("Không thể đánh dấu thất bại khi đơn đã được giao/đang giao hoặc đang ở luồng hoàn hàng.");

            var shippedByShipment = order.Shipments?.Any(s =>
                !string.IsNullOrWhiteSpace(s.Status) &&
                (s.Status.Trim().ToLowerInvariant() == "shipping" ||
                 s.Status.Trim().ToLowerInvariant() == "intransit" ||
                 s.Status.Trim().ToLowerInvariant() == "in_transit" ||
                 s.Status.Trim().ToLowerInvariant() == "delivered")) == true
                || order.Shipments?.Any(s => s.ShippedDate != null || s.ActualDeliveryDate != null) == true;
            if (shippedByShipment)
                return BadRequest("Không thể đánh dấu thất bại khi đơn đã được giao/đang giao.");

            await using var tx = await _context.Database.BeginTransactionAsync();
            try
            {
                order.Status = "Failed";

                // Hoàn kho.
                var details = order.OrderDetails ?? new List<OrderDetail>();
                foreach (var d in details)
                {
                    if (d.ProductID <= 0 || d.Quantity <= 0) continue;
                    var product = await _context.Products.FirstOrDefaultAsync(p => p.ProductID == d.ProductID);
                    if (product == null) continue;
                    product.StockQuantity += d.Quantity;
                }

                // Payment row: best-effort mark failed if exists.
                var provider = (dto.Provider ?? "").Trim().ToUpperInvariant();
                if (provider == "MOMO" || provider == "VNPAY")
                {
                    var payment = await _context.Payments
                        .FirstOrDefaultAsync(p => p.OrderID == id && p.PaymentMethod == provider);
                    if (payment != null)
                    {
                        payment.Status = "Failed";
                        payment.PaymentDate = DateTime.Now;
                    }
                }

                await _context.SaveChangesAsync();
                await tx.CommitAsync();
                return Ok(order);
            }
            catch
            {
                await tx.RollbackAsync();
                throw;
            }
        }

        // POST: api/Orders/5/cancel
        // Customer cancels an order (only allowed before shipping).
        [Authorize]
        [HttpPost("{id:int}/cancel")]
        public async Task<ActionResult<Order>> CancelOrder(int id, [FromBody] CancelOrderDto dto)
        {
            var order = await _context.Orders
                .Include(o => o.Shipments)
                .Include(o => o.OrderDetails)
                .FirstOrDefaultAsync(o => o.OrderID == id);

            if (order == null) return NotFound();
            var authId = GetAuthUserId();
            if (authId is not > 0) return Forbid();
            if (dto == null || dto.UserID <= 0 || dto.UserID != authId.Value) return Forbid();
            if (order.UserID != authId.Value) return StatusCode(403, "Forbidden.");

            var st = (order.Status ?? "").Trim().ToLowerInvariant();
            if (st is "cancelled" or "canceled") return Ok(order);
            if (st == "failed") return Ok(order);

            // Allow cancel only for early pipeline statuses.
            // Do NOT allow cancel once shipping/delivered/completed/return flow.
            if (st is "shipping" or "intransit" or "in_transit" or "delivered" or "completed" or "returned" or "refunded" or "returnpending")
                return BadRequest("Không thể hủy đơn khi đơn đã được giao/đang giao hoặc đang ở luồng hoàn hàng.");

            // Also block cancel if any shipment indicates shipped/delivered.
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

                // Hoàn lại tồn kho (đơn bị hủy trước khi giao).
                // Idempotency: chỉ chạy khi đang chuyển từ non-cancelled -> cancelled (đã chặn ở trên).
                var details = order.OrderDetails ?? new List<OrderDetail>();
                foreach (var d in details)
                {
                    if (d.ProductID <= 0 || d.Quantity <= 0) continue;
                    var product = await _context.Products.FirstOrDefaultAsync(p => p.ProductID == d.ProductID);
                    if (product == null) continue;
                    product.StockQuantity += d.Quantity;
                }

                // Best-effort: mark shipments as cancelled too (if any).
                if (order.Shipments != null)
                {
                    foreach (var s in order.Shipments)
                    {
                        if (string.IsNullOrWhiteSpace(s.Status)) s.Status = "Cancelled";
                    }
                }

                // If customer already paid online, create a manual refund request for admin to process.
                // This is separate from "return goods" flow.
                var latestPayment = await _context.Payments
                    .AsNoTracking()
                    .Where(p => p.OrderID == id)
                    .OrderByDescending(p => p.PaymentDate)
                    .FirstOrDefaultAsync();

                var pm = (latestPayment?.PaymentMethod ?? "").Trim().ToUpperInvariant();
                var pst = (latestPayment?.Status ?? "").Trim().ToLowerInvariant();
                var isPaid = pst is "paid" or "success";
                var isCod = pm == "COD";

                if (latestPayment != null && isPaid && !isCod)
                {
                    var existingRefund = await _context.ReturnRequests
                        .AsNoTracking()
                        .Where(r => r.OrderID == id && r.UserID == authId.Value && r.RequestType == "CancelRefund" && r.Status != "Rejected")
                        .OrderByDescending(r => r.CreatedAt)
                        .FirstOrDefaultAsync();

                    if (existingRefund == null)
                    {
                        var reason = (dto.Reason ?? "").Trim();
                        if (string.IsNullOrWhiteSpace(reason)) reason = "Hủy đơn — yêu cầu hoàn tiền.";

                        _context.ReturnRequests.Add(new ReturnRequest
                        {
                            OrderID = id,
                            UserID = authId.Value,
                            Status = "Pending",
                            RequestType = "CancelRefund",
                            Reason = reason,
                            CreatedAt = DateTime.UtcNow
                        });
                    }
                }

                await _context.SaveChangesAsync();
                await tx.CommitAsync();
                return Ok(order);
            }
            catch
            {
                await tx.RollbackAsync();
                throw;
            }
        }

        // GET: api/Orders/5/return-request?userId=1
        [Authorize]
        [HttpGet("{id:int}/return-request")]
        public async Task<ActionResult<object?>> GetReturnRequest(int id, [FromQuery] int userId)
        {
            var authId = GetAuthUserId();
            if (authId is not > 0) return Forbid();
            if (authId.Value != userId) return Forbid();

            var rr = await _context.ReturnRequests
                .AsNoTracking()
                .Include(r => r.Images)
                .Where(r => r.OrderID == id && r.UserID == userId)
                .OrderByDescending(r => r.CreatedAt)
                .FirstOrDefaultAsync();

            if (rr == null) return Ok(null);

            return Ok(new
            {
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
                Images = (rr.Images ?? new List<ReturnRequestImage>()).Select(i => new { i.ReturnRequestImageID, i.ImageUrl }).ToList()
            });
        }

        // POST: api/Orders/5/return-request  (multipart/form-data) — route id:int
        [Authorize]
        [HttpPost("{id:int}/return-request")]
        [Consumes("multipart/form-data")]
        [RequestSizeLimit(80_000_000)] // allow optional video
        public async Task<IActionResult> CreateReturnRequest([FromRoute] int id, [FromForm] int userId, [FromForm] string reason, [FromForm] List<IFormFile> files, [FromForm] IFormFile? video)
        {
            var authId = GetAuthUserId();
            if (authId is not > 0) return Forbid();
            if (authId.Value != userId) return Forbid();
            if (userId <= 0) return BadRequest("Missing userId.");
            if (string.IsNullOrWhiteSpace(reason)) return BadRequest("Missing reason.");
            if (files != null && files.Count > 6) return BadRequest("Maximum 6 images.");

            var order = await _context.Orders.AsNoTracking().FirstOrDefaultAsync(o => o.OrderID == id);
            if (order == null) return NotFound();
            if (order.UserID != userId) return StatusCode(403, "Forbidden.");

            var st = (order.Status ?? "").Trim().ToLowerInvariant();
            if (st != "delivered") return BadRequest("Only delivered orders can request return.");

            var existing = await _context.ReturnRequests
                .Where(r => r.OrderID == id && r.UserID == userId && r.Status != "Rejected")
                .OrderByDescending(r => r.CreatedAt)
                .FirstOrDefaultAsync();
            if (existing != null) return BadRequest("A return request already exists for this order.");

            var allowed = new HashSet<string> { ".jpg", ".jpeg", ".png", ".webp", ".gif", ".jfif" };
            var allowedVideo = new HashSet<string> { ".mp4", ".mov", ".webm", ".m4v" };
            if (files != null)
            {
                foreach (var f in files)
                {
                    if (f.Length == 0) continue;
                    var ext = Path.GetExtension(f.FileName).ToLowerInvariant();
                    if (!allowed.Contains(ext)) return BadRequest($"Unsupported image extension: {ext}.");
                    if (string.IsNullOrWhiteSpace(f.ContentType) || !f.ContentType.StartsWith("image/", StringComparison.OrdinalIgnoreCase))
                        return BadRequest("Only image files are allowed.");
                }
            }

            if (video != null && video.Length > 0)
            {
                var ext = Path.GetExtension(video.FileName).ToLowerInvariant();
                if (!allowedVideo.Contains(ext)) return BadRequest($"Unsupported video extension: {ext}.");
                if (string.IsNullOrWhiteSpace(video.ContentType) || !video.ContentType.StartsWith("video/", StringComparison.OrdinalIgnoreCase))
                    return BadRequest("Only video files are allowed.");
                if (video.Length > 70_000_000) return BadRequest("Video is too large (max ~70MB).");
            }

            var rr = new ReturnRequest
            {
                OrderID = id,
                UserID = userId,
                Status = "Pending",
                RequestType = "Return",
                Reason = reason.Trim(),
                CreatedAt = DateTime.UtcNow
            };
            _context.ReturnRequests.Add(rr);
            await _context.SaveChangesAsync();

            var rootDir = Path.Combine(AppContext.BaseDirectory, "..", "..", "..", "wwwroot", "return-images", id.ToString(), rr.ReturnRequestID.ToString());
            rootDir = Path.GetFullPath(rootDir);
            Directory.CreateDirectory(rootDir);

            // Save video if provided
            if (video != null && video.Length > 0)
            {
                var vDir = Path.Combine(AppContext.BaseDirectory, "..", "..", "..", "wwwroot", "return-videos", id.ToString(), rr.ReturnRequestID.ToString());
                vDir = Path.GetFullPath(vDir);
                Directory.CreateDirectory(vDir);

                var ext = Path.GetExtension(video.FileName);
                if (string.IsNullOrWhiteSpace(ext)) ext = ".mp4";
                var safeName = $"video-{Guid.NewGuid():N}{ext}";
                var fullPath = Path.Combine(vDir, safeName);
                await using (var stream = System.IO.File.Create(fullPath))
                {
                    await video.CopyToAsync(stream);
                }

                rr.VideoUrl = $"/return-videos/{id}/{rr.ReturnRequestID}/{safeName}";
                await _context.SaveChangesAsync();
            }

            if (files != null)
            {
                foreach (var f in files)
                {
                    if (f.Length == 0) continue;
                    var ext = Path.GetExtension(f.FileName);
                    if (string.IsNullOrWhiteSpace(ext)) ext = ".jpg";

                    var safeName = $"{Guid.NewGuid():N}{ext}";
                    var fullPath = Path.Combine(rootDir, safeName);
                    await using (var stream = System.IO.File.Create(fullPath))
                    {
                        await f.CopyToAsync(stream);
                    }

                    var url = $"/return-images/{id}/{rr.ReturnRequestID}/{safeName}";
                    _context.ReturnRequestImages.Add(new ReturnRequestImage { ReturnRequestID = rr.ReturnRequestID, ImageUrl = url });
                }
                await _context.SaveChangesAsync();
            }

            return Ok(new { rr.ReturnRequestID });
        }

        private async Task<string> GenerateUniqueOrderCodeAsync()
        {
            const string alphabet = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"; // no 0/1/I/O to reduce confusion
            var buffer = new char[18];
            var bytes = new byte[18];

            for (var attempt = 0; attempt < 20; attempt++)
            {
                RandomNumberGenerator.Fill(bytes);
                for (var i = 0; i < buffer.Length; i++)
                {
                    buffer[i] = alphabet[bytes[i] % alphabet.Length];
                }

                var code = new string(buffer);
                var exists = await _context.Orders.AnyAsync(o => o.OrderCode == code);
                if (!exists) return code;
            }

            // Extremely unlikely, but keep it deterministic if RNG collisions keep happening
            return $"OD{DateTime.UtcNow:yyMMddHHm}";
        }

        private static decimal ComputeDiscount(Voucher voucher, decimal subtotal)
        {
            var type = (voucher.DiscountType ?? "").Trim().ToLowerInvariant();
            if (type == "percentage")
            {
                var pct = voucher.DiscountValue;
                if (pct <= 0) return 0m;
                return Math.Round(subtotal * pct / 100m, 0, MidpointRounding.AwayFromZero);
            }
            return Math.Max(0m, Math.Min(subtotal, voucher.DiscountValue));
        }

        private async Task<int> ResolveCheckoutUserIdAsync(CreateOrderDto orderDto)
        {
            if (orderDto.UserID is > 0)
            {
                var ok = await _context.Users.AsNoTracking().AnyAsync(u => u.UserID == orderDto.UserID.Value);
                if (!ok) throw new InvalidOperationException("Không tìm thấy người dùng.");
                return orderDto.UserID.Value;
            }

            if (orderDto.GuestCheckout == null)
                throw new InvalidOperationException("Vui lòng đăng nhập hoặc điền thông tin khách (họ tên, email, điện thoại).");

            var g = orderDto.GuestCheckout;
            var email = (g.Email ?? string.Empty).Trim().ToLowerInvariant();
            var fullName = (g.FullName ?? string.Empty).Trim();
            var phone = (g.Phone ?? string.Empty).Trim();
            if (string.IsNullOrWhiteSpace(fullName) || string.IsNullOrWhiteSpace(email) || string.IsNullOrWhiteSpace(phone))
                throw new InvalidOperationException("Thông tin khách chưa đủ (họ tên, email, điện thoại).");
            if (!new EmailAddressAttribute().IsValid(email))
                throw new InvalidOperationException("Email khách không hợp lệ.");

            var existing = await _context.Users.FirstOrDefaultAsync(u => u.Email.ToLower() == email);
            if (existing != null)
            {
                if (!existing.IsGuestAccount)
                    throw new InvalidOperationException("EMAIL_REGISTERED");

                existing.FullName = fullName;
                existing.Phone = phone;
                await _context.SaveChangesAsync();
                return existing.UserID;
            }

            var pwdBytes = RandomNumberGenerator.GetBytes(48);
            var randomSecret = Convert.ToHexString(pwdBytes);
            var guest = new User
            {
                FullName = fullName,
                Email = email,
                Phone = phone,
                PasswordHash = HashPassword(randomSecret),
                Role = "Customer",
                CreatedAt = DateTime.Now,
                IsGuestAccount = true,
                IsLocked = false
            };
            _context.Users.Add(guest);
            await _context.SaveChangesAsync();
            return guest.UserID;
        }

        private static string HashPassword(string password)
        {
            // PBKDF2 (salt + iterations) — same format as AccountController: pbkdf2$<iter>$<saltB64>$<hashB64>
            const int iter = 210_000;
            var salt = RandomNumberGenerator.GetBytes(16);
            var subkey = Rfc2898DeriveBytes.Pbkdf2(
                password: password ?? "",
                salt: salt,
                iterations: iter,
                hashAlgorithm: HashAlgorithmName.SHA256,
                outputLength: 32);
            return $"pbkdf2${iter}${Convert.ToBase64String(salt)}${Convert.ToBase64String(subkey)}";
        }

        private static string GenerateUrlSafeToken()
        {
            var bytes = RandomNumberGenerator.GetBytes(32);
            return Convert.ToBase64String(bytes).Replace("+", "-").Replace("/", "_").TrimEnd('=');
        }

        private static string HashToken(string token)
        {
            using var sha256 = SHA256.Create();
            var hashedBytes = sha256.ComputeHash(Encoding.UTF8.GetBytes(token));
            return BitConverter.ToString(hashedBytes).Replace("-", "").ToLowerInvariant();
        }

        private enum OrderReceiptMailKind
        {
            OrderPlaced,
            CodPaymentConfirmed,
        }

        private async Task TrySendOrderPlacedEmailAsync(int orderId, CancellationToken ct) =>
            await TrySendOrderReceiptEmailAsync(orderId, OrderReceiptMailKind.OrderPlaced, ct);

        private async Task TrySendCodPaymentConfirmedEmailAsync(int orderId, CancellationToken ct) =>
            await TrySendOrderReceiptEmailAsync(orderId, OrderReceiptMailKind.CodPaymentConfirmed, ct);

        private async Task TrySendOrderReceiptEmailAsync(int orderId, OrderReceiptMailKind kind, CancellationToken ct)
        {
            try
            {
                var order = await _context.Orders
                    .AsNoTracking()
                    .Include(o => o.User)
                    .Include(o => o.Payments)
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
                var safeName = WebUtility.HtmlEncode(order.User.FullName?.Trim() ?? "Khách hàng");
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

                var pm = order.Payments?.OrderByDescending(p => p.PaymentDate).FirstOrDefault();
                var method = (pm?.PaymentMethod ?? "").ToUpperInvariant();
                var payStatus = (pm?.Status ?? "").Trim().ToLowerInvariant();

                string subject;
                string mainHeading;
                string statusBadgeText;
                string statusDotColor;
                string totalsCardTitle;
                string paymentMethodViRaw;
                string? footerItalic = null;

                if (kind == OrderReceiptMailKind.CodPaymentConfirmed)
                {
                    subject = PaymentSuccessEmailTemplates.Subject(code);
                    mainHeading = "Thanh toán thành công";
                    statusBadgeText = "Đã xác nhận thanh toán (COD)";
                    statusDotColor = "#22c55e";
                    totalsCardTitle = "TỔNG KẾT THANH TOÁN";
                    paymentMethodViRaw = "Thanh toán khi nhận hàng (COD)";
                }
                else if (method == "COD")
                {
                    subject = PaymentSuccessEmailTemplates.SubjectOrderPlaced(code);
                    mainHeading = "Đặt hàng thành công";
                    statusBadgeText = "Thanh toán khi nhận hàng (COD)";
                    statusDotColor = "#0d9488";
                    totalsCardTitle = "TỔNG ĐƠN HÀNG";
                    paymentMethodViRaw = "Thanh toán khi nhận hàng (COD) — thanh toán khi shipper giao hàng";
                    footerItalic =
                        "Bạn sẽ thanh toán bằng tiền mặt khi nhận hàng. Chúng tôi sẽ thông báo khi đơn được vận chuyển.";
                }
                else
                {
                    subject = PaymentSuccessEmailTemplates.SubjectOrderPlaced(code);
                    mainHeading = "Đã nhận đơn hàng";
                    statusBadgeText = "Chờ xử lý";
                    statusDotColor = "#d97706";
                    totalsCardTitle = "TỔNG ĐƠN HÀNG (DỰ KIẾN)";
                    paymentMethodViRaw = method switch
                    {
                        "VNPAY" => payStatus is "paid" or "success"
                            ? "VNPay — đã thanh toán"
                            : "VNPay — vui lòng hoàn tất thanh toán theo hướng dẫn trên website",
                        _ => string.IsNullOrWhiteSpace(method) ? "—" : method
                    };
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
                    paymentMethodVi: WebUtility.HtmlEncode(paymentMethodViRaw),
                    lines: lines,
                    safeShippingAddress: WebUtility.HtmlEncode(order.ShippingAddress ?? "—"),
                    estimatedDeliveryLine: estLine,
                    subtotalFormatted: subtotalS,
                    shippingFormatted: shipS,
                    taxFormatted: taxS,
                    totalFormatted: totalS,
                    trackOrderUrlAbsolute: trackUrl,
                    mainHeading: mainHeading,
                    statusBadgeText: statusBadgeText,
                    statusDotColor: statusDotColor,
                    totalsCardTitle: totalsCardTitle,
                    footerItalic: footerItalic);

                await _emailSender.SendAsync(to, subject, html, linked.Count > 0 ? linked : null, ct).ConfigureAwait(false);
            }
            catch (Exception ex)
            {
                _logger.LogWarning(ex, "Không gửi được email đơn hàng OrderID={OrderId} Kind={Kind}", orderId, kind);
                if (_env.IsDevelopment())
                    _logger.LogInformation("Dev: kiểm tra SMTP và Frontend:BaseUrl / Backend:PublicUrl.");
            }
        }

        private async Task TrySendGuestAccountSetupEmailAsync(int userId, CancellationToken ct)
        {
            var user = await _context.Users.FirstOrDefaultAsync(u => u.UserID == userId, ct);
            if (user == null || !user.IsGuestAccount) return;

            var token = GenerateUrlSafeToken();
            var tokenHash = HashToken(token);
            var now = DateTime.UtcNow;

            var oldGuest = await _context.PasswordResetTokens
                .Where(t => t.UserID == userId && t.Purpose == GuestActivatePurpose && t.UsedAt == null && t.ExpiresAt > now)
                .ToListAsync(ct);
            foreach (var t in oldGuest)
                t.UsedAt = now;

            _context.PasswordResetTokens.Add(new PasswordResetToken
            {
                UserID = userId,
                TokenHash = tokenHash,
                ExpiresAt = now.AddHours(48),
                CreatedAt = now,
                Purpose = GuestActivatePurpose
            });
            await _context.SaveChangesAsync(ct);

            var feBase = (_configuration["Frontend:BaseUrl"] ?? "http://localhost:5173").Trim().TrimEnd('/');
            var setPwdLinkWeb = $"{feBase}/tao-mat-khau?email={WebUtility.UrlEncode(user.Email)}&token={WebUtility.UrlEncode(token)}";
            // App deep link (custom scheme). Some Android email clients/browsers may not handoff custom schemes reliably,
            // so we also provide an Intent URL that forces opening the app on Android.
            var setPwdLinkApp = $"freshfood://auth/guest-set-password?email={WebUtility.UrlEncode(user.Email)}&token={WebUtility.UrlEncode(token)}";
            var setPwdLinkAppIntent =
                $"intent://auth/guest-set-password?email={WebUtility.UrlEncode(user.Email)}&token={WebUtility.UrlEncode(token)}#Intent;scheme=freshfood;package=com.example.freshfood_app;end";
            var safeEmail = WebUtility.HtmlEncode(user.Email);

            var subject = "FreshFood - Tạo mật khẩu cho tài khoản của bạn";
            var html = $"""
                <div style="font-family:Arial,Helvetica,sans-serif;line-height:1.55">
                  <h2 style="margin:0 0 10px 0">Chào bạn,</h2>
                  <p>Cảm ơn bạn đã đặt hàng tại FreshFood. Chúng tôi đã tạo <b>tài khoản</b> gắn với email <b>{safeEmail}</b> để bạn theo dõi đơn hàng sau này.</p>
                  <p>Vui lòng bấm nút bên dưới để <b>đặt mật khẩu</b> (khác với “Quên mật khẩu” — đây là bước kích hoạt lần đầu). Liên kết có hiệu lực trong <b>48 giờ</b>.</p>
                  <p>
                    <a href="{setPwdLinkAppIntent}" style="display:inline-block;padding:12px 18px;background:#2ecc71;color:#fff;text-decoration:none;border-radius:8px;font-weight:700">
                      Tạo mật khẩu
                    </a>
                  </p>
                  <p style="font-size:14px;color:#444">Nếu bạn đang dùng máy tính, hãy mở link web sau:</p>
                  <p style="word-break:break-all"><a href="{setPwdLinkWeb}">{WebUtility.HtmlEncode(setPwdLinkWeb)}</a></p>
                  <p style="font-size:14px;color:#444;margin-top:10px">Nếu mở trên điện thoại mà không tự vào app, hãy thử copy link app sau:</p>
                  <p style="word-break:break-all"><a href="{setPwdLinkApp}">{WebUtility.HtmlEncode(setPwdLinkApp)}</a></p>
                  <hr style="border:none;border-top:1px solid #eee;margin:18px 0"/>
                  <p style="color:#666;margin:0;font-size:13px">Nếu bạn không đặt hàng, hãy bỏ qua email này.</p>
                </div>
                """;

            try
            {
                await _emailSender.SendAsync(user.Email, subject, html, ct);
            }
            catch (Exception ex)
            {
                _logger.LogWarning(ex, "SMTP lỗi khi gửi email guest_activate tới {Email}", user.Email);
                if (_emailOptions.Value.DevReturnToken && _env.IsDevelopment())
                    _logger.LogInformation("Dev: guest set-password links for {Email}: intent={IntentLink} app={AppLink} web={WebLink}", user.Email, setPwdLinkAppIntent, setPwdLinkApp, setPwdLinkWeb);
                // Không throw: đơn đã tạo thành công, chỉ thiếu email.
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

        private static string ComputeCreateOrderRequestHash(CreateOrderDto dto)
        {
            var payload = JsonSerializer.Serialize(new
            {
                userID = dto.UserID,
                guestCheckout = dto.GuestCheckout == null ? null : new
                {
                    fullName = (dto.GuestCheckout.FullName ?? string.Empty).Trim(),
                    email = (dto.GuestCheckout.Email ?? string.Empty).Trim().ToLowerInvariant(),
                    phone = (dto.GuestCheckout.Phone ?? string.Empty).Trim(),
                },
                shippingAddress = (dto.ShippingAddress ?? string.Empty).Trim(),
                shippingAddressId = dto.ShippingAddressId,
                shippingMethodID = dto.ShippingMethodID,
                paymentMethod = (dto.PaymentMethod ?? string.Empty).Trim().ToUpperInvariant(),
                voucherCode = (dto.VoucherCode ?? string.Empty).Trim().ToUpperInvariant(),
                items = (dto.Items ?? new List<OrderItemDto>())
                    .OrderBy(x => x.ProductID)
                    .ThenBy(x => x.Quantity)
                    .Select(x => new { x.ProductID, x.Quantity })
                    .ToList()
            });
            using var sha = SHA256.Create();
            var bytes = sha.ComputeHash(Encoding.UTF8.GetBytes(payload));
            return Convert.ToHexString(bytes).ToLowerInvariant();
        }

        private async Task<OrderIdempotency?> TryBeginIdempotentOrderRequestAsync(string key, string requestHash, CreateOrderDto dto)
        {
            var normalized = key.Trim();
            if (string.IsNullOrWhiteSpace(normalized)) return null;

            var authId = GetAuthUserId();
            var candidateUserId = authId is > 0 ? authId : dto.UserID;

            var existing = await _context.OrderIdempotencies.FirstOrDefaultAsync(x => x.IdempotencyKey == normalized);
            if (existing != null)
            {
                if (!string.Equals(existing.RequestHash ?? string.Empty, requestHash, StringComparison.OrdinalIgnoreCase))
                {
                    throw new InvalidOperationException("Idempotency-Key đã được dùng cho một payload khác.");
                }
                return existing;
            }

            var row = new OrderIdempotency
            {
                IdempotencyKey = normalized,
                RequestHash = requestHash,
                UserID = candidateUserId
            };
            _context.OrderIdempotencies.Add(row);
            try
            {
                await _context.SaveChangesAsync();
                return row;
            }
            catch (DbUpdateException)
            {
                _context.Entry(row).State = EntityState.Detached;
                var raced = await _context.OrderIdempotencies.FirstOrDefaultAsync(x => x.IdempotencyKey == normalized);
                if (raced != null && !string.Equals(raced.RequestHash ?? string.Empty, requestHash, StringComparison.OrdinalIgnoreCase))
                {
                    throw new InvalidOperationException("Idempotency-Key đã được dùng cho một payload khác.");
                }
                return raced;
            }
        }
    }
}
