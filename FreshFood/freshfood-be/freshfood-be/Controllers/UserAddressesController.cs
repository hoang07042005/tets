using System.ComponentModel.DataAnnotations;
using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using freshfood_be.Data;
using freshfood_be.Models;

namespace freshfood_be.Controllers;

/// <summary>Sổ địa chỉ — api/UserAddresses</summary>
[Route("api/[controller]")]
[ApiController]
public class UserAddressesController : ControllerBase
{
    private readonly FreshFoodContext _context;

    public UserAddressesController(FreshFoodContext context)
    {
        _context = context;
    }

    public record UserAddressDto(
        int UserAddressID,
        string? Label,
        string RecipientName,
        string? Phone,
        string AddressLine,
        bool IsDefault,
        string CreatedAt);

    public record SaveUserAddressDto
    {
        [Required, StringLength(100)]
        public string RecipientName { get; set; } = string.Empty;

        [StringLength(20)]
        public string? Phone { get; set; }

        [Required, StringLength(500)]
        public string AddressLine { get; set; } = string.Empty;

        [StringLength(60)]
        public string? Label { get; set; }

        public bool IsDefault { get; set; }
    }

    private static UserAddressDto ToDto(UserAddress a) => new(
        a.UserAddressID,
        a.Label,
        a.RecipientName,
        a.Phone,
        a.AddressLine,
        a.IsDefault,
        a.CreatedAt.ToString("O"));

    private async Task ClearOtherDefaultsAsync(int userId, int? exceptId, CancellationToken ct)
    {
        var q = _context.UserAddresses.Where(x => x.UserID == userId && x.IsDefault);
        if (exceptId is int id)
            q = q.Where(x => x.UserAddressID != id);
        foreach (var x in await q.ToListAsync(ct))
            x.IsDefault = false;
    }

    private async Task SyncUserLegacyAddressAsync(int userId, string? addressLine, CancellationToken ct)
    {
        if (string.IsNullOrWhiteSpace(addressLine)) return;
        var u = await _context.Users.FirstOrDefaultAsync(x => x.UserID == userId, ct);
        if (u != null) u.Address = addressLine.Trim();
    }

    private int? GetAuthUserId()
    {
        var v = User?.FindFirstValue(ClaimTypes.NameIdentifier) ?? User?.FindFirstValue("sub");
        return int.TryParse(v, out var id) && id > 0 ? id : null;
    }

    private bool IsOwner(int userId) => GetAuthUserId() == userId;

    [HttpGet("user/{userId:int}")]
    [Authorize]
    public async Task<ActionResult<IReadOnlyList<UserAddressDto>>> ListByUser(int userId, CancellationToken ct)
    {
        if (!IsOwner(userId)) return Forbid();
        if (userId <= 0) return BadRequest("userId không hợp lệ.");
        var exists = await _context.Users.AsNoTracking().AnyAsync(u => u.UserID == userId, ct);
        if (!exists) return NotFound();

        var list = await _context.UserAddresses
            .AsNoTracking()
            .Where(a => a.UserID == userId)
            .OrderByDescending(a => a.IsDefault)
            .ThenByDescending(a => a.CreatedAt)
            .ToListAsync(ct);

        return list.Select(ToDto).ToList();
    }

    [HttpPost("user/{userId:int}")]
    [Authorize]
    public async Task<ActionResult<UserAddressDto>> Create(int userId, [FromBody] SaveUserAddressDto dto, CancellationToken ct)
    {
        if (!IsOwner(userId)) return Forbid();
        if (userId <= 0) return BadRequest("userId không hợp lệ.");
        var exists = await _context.Users.AnyAsync(u => u.UserID == userId, ct);
        if (!exists) return NotFound();

        var name = (dto.RecipientName ?? string.Empty).Trim();
        var line = (dto.AddressLine ?? string.Empty).Trim();
        if (name.Length == 0 || line.Length == 0)
            return BadRequest("Tên người nhận và địa chỉ là bắt buộc.");

        if (dto.IsDefault)
            await ClearOtherDefaultsAsync(userId, null, ct);

        var entity = new UserAddress
        {
            UserID = userId,
            Label = string.IsNullOrWhiteSpace(dto.Label) ? null : dto.Label.Trim(),
            RecipientName = name,
            Phone = string.IsNullOrWhiteSpace(dto.Phone) ? null : dto.Phone.Trim(),
            AddressLine = line,
            IsDefault = dto.IsDefault,
            CreatedAt = DateTime.UtcNow
        };
        _context.UserAddresses.Add(entity);
        await _context.SaveChangesAsync(ct);

        if (dto.IsDefault)
            await SyncUserLegacyAddressAsync(userId, line, ct);
        await _context.SaveChangesAsync(ct);

        return Ok(ToDto(entity));
    }

    [HttpPut("{addressId:int}")]
    [Authorize]
    public async Task<ActionResult<UserAddressDto>> Update(int addressId, [FromQuery] int userId, [FromBody] SaveUserAddressDto dto, CancellationToken ct)
    {
        if (!IsOwner(userId)) return Forbid();
        if (userId <= 0) return BadRequest("userId không hợp lệ.");
        var entity = await _context.UserAddresses.FirstOrDefaultAsync(a => a.UserAddressID == addressId && a.UserID == userId, ct);
        if (entity == null) return NotFound();

        var name = (dto.RecipientName ?? string.Empty).Trim();
        var line = (dto.AddressLine ?? string.Empty).Trim();
        if (name.Length == 0 || line.Length == 0)
            return BadRequest("Tên người nhận và địa chỉ là bắt buộc.");

        if (dto.IsDefault)
            await ClearOtherDefaultsAsync(userId, addressId, ct);

        entity.Label = string.IsNullOrWhiteSpace(dto.Label) ? null : dto.Label.Trim();
        entity.RecipientName = name;
        entity.Phone = string.IsNullOrWhiteSpace(dto.Phone) ? null : dto.Phone.Trim();
        entity.AddressLine = line;
        entity.IsDefault = dto.IsDefault;

        await _context.SaveChangesAsync(ct);

        if (dto.IsDefault)
            await SyncUserLegacyAddressAsync(userId, line, ct);
        await _context.SaveChangesAsync(ct);

        return Ok(ToDto(entity));
    }

    [HttpDelete("{addressId:int}")]
    [Authorize]
    public async Task<IActionResult> Delete(int addressId, [FromQuery] int userId, CancellationToken ct)
    {
        if (!IsOwner(userId)) return Forbid();
        if (userId <= 0) return BadRequest("userId không hợp lệ.");
        var entity = await _context.UserAddresses.FirstOrDefaultAsync(a => a.UserAddressID == addressId && a.UserID == userId, ct);
        if (entity == null) return NotFound();

        var wasDefault = entity.IsDefault;
        _context.UserAddresses.Remove(entity);
        await _context.SaveChangesAsync(ct);

        if (wasDefault)
        {
            var next = await _context.UserAddresses
                .Where(a => a.UserID == userId)
                .OrderByDescending(a => a.CreatedAt)
                .FirstOrDefaultAsync(ct);
            if (next != null)
            {
                next.IsDefault = true;
                await SyncUserLegacyAddressAsync(userId, next.AddressLine, ct);
                await _context.SaveChangesAsync(ct);
            }
        }

        return NoContent();
    }

    [HttpPut("{addressId:int}/set-default")]
    [Authorize]
    public async Task<ActionResult<UserAddressDto>> SetDefault(int addressId, [FromQuery] int userId, CancellationToken ct)
    {
        if (!IsOwner(userId)) return Forbid();
        if (userId <= 0) return BadRequest("userId không hợp lệ.");
        var entity = await _context.UserAddresses.FirstOrDefaultAsync(a => a.UserAddressID == addressId && a.UserID == userId, ct);
        if (entity == null) return NotFound();

        await ClearOtherDefaultsAsync(userId, null, ct);
        entity.IsDefault = true;
        await _context.SaveChangesAsync(ct);
        await SyncUserLegacyAddressAsync(userId, entity.AddressLine, ct);
        await _context.SaveChangesAsync(ct);

        return Ok(ToDto(entity));
    }
}
