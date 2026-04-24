using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using freshfood_be.Data;
using freshfood_be.Models;
using freshfood_be.Services.Security;

namespace freshfood_be.Controllers
{
    /// <summary>Quản trị vouchers — api/Admin/Vouchers</summary>
    [Authorize(Roles = "Admin")]
    [Route("api/Admin/Vouchers")]
    [ApiController]
    public class AdminVouchersController : ControllerBase
    {
        private readonly FreshFoodContext _context;
        private readonly freshfood_be.Services.Security.IdTokenService _idTokens;
        private readonly AdminAuditLogger _audit;

        public AdminVouchersController(FreshFoodContext context, freshfood_be.Services.Security.IdTokenService idTokens, AdminAuditLogger audit)
        {
            _context = context;
            _idTokens = idTokens;
            _audit = audit;
        }

        public record VoucherDto(
            int VoucherID,
            string VoucherToken,
            string Code,
            string? DiscountType,
            decimal DiscountValue,
            decimal MinOrderAmount,
            DateTime? ExpiryDate,
            bool IsActive);

        public record VoucherUpsertDto(
            string Code,
            string? DiscountType,
            decimal DiscountValue,
            decimal MinOrderAmount,
            DateTime? ExpiryDate,
            bool IsActive);

        [HttpGet]
        public async Task<ActionResult<IEnumerable<VoucherDto>>> List([FromQuery] string? q = null, [FromQuery] bool? active = null)
        {
            var query = _context.Vouchers.AsNoTracking().AsQueryable();

            if (!string.IsNullOrWhiteSpace(q))
            {
                var term = q.Trim();
                query = query.Where(v => v.Code.Contains(term) || v.VoucherID.ToString().Contains(term));
            }

            if (active.HasValue)
                query = query.Where(v => v.IsActive == active.Value);

            var rows = await query
                .OrderByDescending(v => v.IsActive)
                .ThenBy(v => v.ExpiryDate == null ? 1 : 0)
                .ThenBy(v => v.ExpiryDate)
                .ThenBy(v => v.Code)
                .Select(v => new VoucherDto(
                    v.VoucherID,
                    "",
                    v.Code,
                    v.DiscountType,
                    v.DiscountValue,
                    v.MinOrderAmount,
                    v.ExpiryDate,
                    v.IsActive
                ))
                .ToListAsync();

            return Ok(rows.Select(x => x with { VoucherToken = _idTokens.ProtectVoucherId(x.VoucherID) }).ToList());
        }

        [HttpGet("{id:int}")]
        public async Task<ActionResult<VoucherDto>> Get(int id)
        {
            var v = await _context.Vouchers.AsNoTracking().FirstOrDefaultAsync(x => x.VoucherID == id);
            if (v == null) return NotFound();

            return Ok(new VoucherDto(v.VoucherID, _idTokens.ProtectVoucherId(v.VoucherID), v.Code, v.DiscountType, v.DiscountValue, v.MinOrderAmount, v.ExpiryDate, v.IsActive));
        }

        [HttpPost]
        public async Task<ActionResult<VoucherDto>> Create([FromBody] VoucherUpsertDto input)
        {
            var code = (input.Code ?? string.Empty).Trim();
            if (string.IsNullOrWhiteSpace(code)) return BadRequest("Code bắt buộc.");
            if (input.DiscountValue < 0) return BadRequest("DiscountValue phải không âm.");
            if (input.MinOrderAmount < 0) return BadRequest("MinOrderAmount phải không âm.");

            var exists = await _context.Vouchers.AnyAsync(v => v.Code == code);
            if (exists) return Conflict("Code đã tồn tại.");

            var v = new Voucher
            {
                Code = code,
                DiscountType = string.IsNullOrWhiteSpace(input.DiscountType) ? null : input.DiscountType.Trim(),
                DiscountValue = input.DiscountValue,
                MinOrderAmount = input.MinOrderAmount,
                ExpiryDate = input.ExpiryDate,
                IsActive = input.IsActive,
            };

            _context.Vouchers.Add(v);
            await _context.SaveChangesAsync();

            await _audit.LogAsync(
                action: "vouchers.create",
                entityType: "Voucher",
                entityId: v.VoucherID.ToString(),
                summary: $"Created voucher: {v.Code}",
                data: new { voucherId = v.VoucherID, v.Code, v.DiscountType, v.DiscountValue, v.MinOrderAmount, v.ExpiryDate, v.IsActive },
                ct: HttpContext.RequestAborted);

            var dto = new VoucherDto(v.VoucherID, _idTokens.ProtectVoucherId(v.VoucherID), v.Code, v.DiscountType, v.DiscountValue, v.MinOrderAmount, v.ExpiryDate, v.IsActive);
            return CreatedAtAction(nameof(Get), new { id = v.VoucherID }, dto);
        }

        [HttpGet("token/{token}")]
        public async Task<ActionResult<VoucherDto>> GetByToken([FromRoute] string token)
        {
            if (string.IsNullOrWhiteSpace(token)) return NotFound();
            var id = _idTokens.UnprotectVoucherId(token.Trim());
            if (id == null || id <= 0) return NotFound();
            return await Get(id.Value);
        }

        [HttpPut("{id:int}")]
        public async Task<ActionResult<VoucherDto>> Update(int id, [FromBody] VoucherUpsertDto input)
        {
            var v = await _context.Vouchers.FirstOrDefaultAsync(x => x.VoucherID == id);
            if (v == null) return NotFound();

            var before = new { v.Code, v.DiscountType, v.DiscountValue, v.MinOrderAmount, v.ExpiryDate, v.IsActive };
            var code = (input.Code ?? string.Empty).Trim();
            if (string.IsNullOrWhiteSpace(code)) return BadRequest("Code bắt buộc.");
            if (input.DiscountValue < 0) return BadRequest("DiscountValue phải không âm.");
            if (input.MinOrderAmount < 0) return BadRequest("MinOrderAmount phải không âm.");

            var codeTaken = await _context.Vouchers.AnyAsync(x => x.VoucherID != id && x.Code == code);
            if (codeTaken) return Conflict("Code đã tồn tại.");

            v.Code = code;
            v.DiscountType = string.IsNullOrWhiteSpace(input.DiscountType) ? null : input.DiscountType.Trim();
            v.DiscountValue = input.DiscountValue;
            v.MinOrderAmount = input.MinOrderAmount;
            v.ExpiryDate = input.ExpiryDate;
            v.IsActive = input.IsActive;

            await _context.SaveChangesAsync();

            await _audit.LogAsync(
                action: "vouchers.update",
                entityType: "Voucher",
                entityId: id.ToString(),
                summary: $"Updated voucher: {v.Code}",
                data: new { voucherId = id, before, after = new { v.Code, v.DiscountType, v.DiscountValue, v.MinOrderAmount, v.ExpiryDate, v.IsActive } },
                ct: HttpContext.RequestAborted);

            return Ok(new VoucherDto(v.VoucherID, _idTokens.ProtectVoucherId(v.VoucherID), v.Code, v.DiscountType, v.DiscountValue, v.MinOrderAmount, v.ExpiryDate, v.IsActive));
        }

        [HttpDelete("{id:int}")]
        public async Task<IActionResult> Delete(int id)
        {
            var v = await _context.Vouchers.FindAsync(id);
            if (v == null) return NotFound();

            var used = await _context.VoucherUsages.AnyAsync(vu => vu.VoucherID == id);
            if (used) return Conflict("Không xóa được: voucher đã được sử dụng.");

            _context.Vouchers.Remove(v);
            await _context.SaveChangesAsync();

            await _audit.LogAsync(
                action: "vouchers.delete",
                entityType: "Voucher",
                entityId: id.ToString(),
                summary: $"Deleted voucher: {v.Code}",
                data: new { voucherId = id, v.Code },
                ct: HttpContext.RequestAborted);
            return NoContent();
        }
    }
}

