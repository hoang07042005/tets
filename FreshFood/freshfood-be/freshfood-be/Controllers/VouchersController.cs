using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using freshfood_be.Data;
using freshfood_be.Models;

namespace freshfood_be.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    public class VouchersController : ControllerBase
    {
        private readonly FreshFoodContext _context;

        public VouchersController(FreshFoodContext context)
        {
            _context = context;
        }

        public record VoucherDto(
            int VoucherID,
            string Code,
            string? DiscountType,
            decimal DiscountValue,
            decimal MinOrderAmount,
            DateTime? ExpiryDate,
            bool IsActive
        );

        [HttpGet("active")]
        public async Task<ActionResult<IEnumerable<VoucherDto>>> GetActive([FromQuery] int? userId = null)
        {
            var now = DateTime.UtcNow;

            var q = _context.Vouchers
                .AsNoTracking()
                .Where(v => v.IsActive && (v.ExpiryDate == null || v.ExpiryDate > now));

            if (userId.HasValue && userId.Value > 0)
            {
                var uid = userId.Value;
                q = q.Where(v => !_context.VoucherUsages.Any(vu => vu.UserID == uid && vu.VoucherID == v.VoucherID));
            }

            var vouchers = await q
                .OrderBy(v => v.ExpiryDate == null ? 1 : 0)
                .ThenBy(v => v.ExpiryDate)
                .Select(v => new VoucherDto(
                    v.VoucherID,
                    v.Code,
                    v.DiscountType,
                    v.DiscountValue,
                    v.MinOrderAmount,
                    v.ExpiryDate,
                    v.IsActive
                ))
                .ToListAsync();

            return Ok(vouchers);
        }

        public record ValidateVoucherRequest(int UserID, string Code, decimal Subtotal, decimal Shipping, decimal Tax);

        public record ValidateVoucherResponse(
            int VoucherID,
            string Code,
            decimal DiscountAmount,
            decimal SubtotalAfterDiscount,
            decimal TaxAfterDiscount,
            decimal GrandTotal
        );

        [HttpPost("validate")]
        public async Task<ActionResult<ValidateVoucherResponse>> Validate([FromBody] ValidateVoucherRequest req)
        {
            if (req.UserID <= 0) return BadRequest("Invalid user id.");
            if (string.IsNullOrWhiteSpace(req.Code)) return BadRequest("Missing code.");
            if (req.Subtotal <= 0) return BadRequest("Invalid subtotal.");

            var now = DateTime.UtcNow;
            var code = req.Code.Trim();

            var voucher = await _context.Vouchers.AsNoTracking().FirstOrDefaultAsync(v => v.Code == code);
            if (voucher == null) return BadRequest("Voucher not found.");
            if (!voucher.IsActive) return BadRequest("Voucher is inactive.");
            if (voucher.ExpiryDate != null && voucher.ExpiryDate <= now) return BadRequest("Voucher has expired.");
            if (req.Subtotal < voucher.MinOrderAmount) return BadRequest("Order does not meet minimum amount.");

            var used = await _context.VoucherUsages.AnyAsync(vu => vu.UserID == req.UserID && vu.VoucherID == voucher.VoucherID);
            if (used) return BadRequest("Voucher already used.");

            var discount = ComputeDiscount(voucher, req.Subtotal);
            var subtotalAfter = Math.Max(0, req.Subtotal - discount);
            // Tax should follow FE rule (1.5%), but after discount on subtotal.
            var taxAfter = Math.Round(subtotalAfter * 0.015m, 0, MidpointRounding.AwayFromZero);
            var grand = subtotalAfter + req.Shipping + taxAfter;

            return Ok(new ValidateVoucherResponse(
                voucher.VoucherID,
                voucher.Code,
                discount,
                subtotalAfter,
                taxAfter,
                grand
            ));
        }

        private static decimal ComputeDiscount(Voucher voucher, decimal subtotal)
        {
            var type = (voucher.DiscountType ?? "").Trim().ToLowerInvariant();
            if (type == "percentage")
            {
                var pct = voucher.DiscountValue;
                if (pct <= 0) return 0;
                return Math.Round(subtotal * pct / 100m, 0, MidpointRounding.AwayFromZero);
            }

            // Flat (default)
            return Math.Max(0, Math.Min(subtotal, voucher.DiscountValue));
        }
    }
}

