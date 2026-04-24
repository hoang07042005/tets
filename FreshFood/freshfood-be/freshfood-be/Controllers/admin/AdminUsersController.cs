using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using freshfood_be.Data;

namespace freshfood_be.Controllers;

/// <summary>Quản lý người dùng — api/Admin/Users</summary>
[Authorize(Roles = "Admin")]
[Route("api/Admin/Users")]
[ApiController]
public class AdminUsersController : ControllerBase
{
    private readonly FreshFoodContext _context;

    public AdminUsersController(FreshFoodContext context)
    {
        _context = context;
    }

    public record AdminUserStatsDto(int Total, int Admins, int Customers, int Locked);

    public record AdminUserRowDto(
        int UserID,
        string FullName,
        string Email,
        string? Phone,
        string? AvatarUrl,
        string Role,
        DateTime CreatedAt,
        bool IsLocked,
        int OrderCount);

    public record AdminUsersPageDto(
        IReadOnlyList<AdminUserRowDto> Items,
        int TotalCount,
        int Page,
        int PageSize,
        AdminUserStatsDto Stats);

    public record UpdateUserRoleDto(string Role);

    public record LockUserDto(bool IsLocked);

    private static bool IsAdminRole(string? r) =>
        string.Equals(r?.Trim(), "Admin", StringComparison.OrdinalIgnoreCase);

    private static string NormalizeRoleInput(string? role)
    {
        if (string.IsNullOrWhiteSpace(role)) return "Customer";
        return IsAdminRole(role) ? "Admin" : "Customer";
    }

    private async Task<AdminUserRowDto?> RowDtoAsync(int userId, CancellationToken ct = default)
    {
        return await _context.Users.AsNoTracking()
            .Where(u => u.UserID == userId)
            .Select(u => new AdminUserRowDto(
                u.UserID,
                u.FullName,
                u.Email,
                u.Phone,
                u.AvatarUrl,
                u.Role,
                u.CreatedAt,
                u.IsLocked,
                _context.Orders.Count(o => o.UserID == u.UserID)))
            .FirstOrDefaultAsync(ct);
    }

    [HttpGet]
    public async Task<ActionResult<AdminUsersPageDto>> List(
        [FromQuery] int page = 1,
        [FromQuery] int pageSize = 15,
        [FromQuery] string? q = null,
        [FromQuery] string? role = null,
        [FromQuery] string? status = null)
    {
        page = Math.Max(1, page);
        pageSize = Math.Clamp(pageSize, 1, 100);

        var totalUsers = await _context.Users.AsNoTracking().CountAsync();
        var adminCount = await _context.Users.AsNoTracking()
            .CountAsync(u => u.Role != null && u.Role.Trim().ToLower() == "admin");
        var lockedCount = await _context.Users.AsNoTracking().CountAsync(u => u.IsLocked);
        var stats = new AdminUserStatsDto(totalUsers, adminCount, Math.Max(0, totalUsers - adminCount), lockedCount);

        var baseQuery = _context.Users.AsNoTracking().AsQueryable();

        if (!string.IsNullOrWhiteSpace(q))
        {
            var term = q.Trim();
            baseQuery = baseQuery.Where(u =>
                u.FullName.Contains(term) || u.Email.Contains(term) ||
                (u.Phone != null && u.Phone.Contains(term)));
        }

        var rf = (role ?? "all").Trim().ToLowerInvariant();
        if (rf == "admin")
            baseQuery = baseQuery.Where(u => u.Role != null && u.Role.Trim().ToLower() == "admin");
        else if (rf == "customer")
            baseQuery = baseQuery.Where(u => u.Role == null || u.Role.Trim().ToLower() != "admin");

        var sf = (status ?? "all").Trim().ToLowerInvariant();
        if (sf == "locked")
            baseQuery = baseQuery.Where(u => u.IsLocked);
        else if (sf == "active")
            baseQuery = baseQuery.Where(u => !u.IsLocked);

        var totalCount = await baseQuery.CountAsync();

        var items = await baseQuery
            .OrderByDescending(u => u.CreatedAt)
            .Skip((page - 1) * pageSize)
            .Take(pageSize)
            .Select(u => new AdminUserRowDto(
                u.UserID,
                u.FullName,
                u.Email,
                u.Phone,
                u.AvatarUrl,
                u.Role,
                u.CreatedAt,
                u.IsLocked,
                _context.Orders.Count(o => o.UserID == u.UserID)))
            .ToListAsync();

        return Ok(new AdminUsersPageDto(items, totalCount, page, pageSize, stats));
    }

    [HttpPatch("{id:int}")]
    public async Task<ActionResult<AdminUserRowDto>> UpdateRole(int id, [FromBody] UpdateUserRoleDto dto)
    {
        if (dto == null || string.IsNullOrWhiteSpace(dto.Role))
            return BadRequest("Thiếu vai trò.");

        var user = await _context.Users.FirstOrDefaultAsync(u => u.UserID == id);
        if (user == null) return NotFound();

        var newRole = NormalizeRoleInput(dto.Role);
        var wasAdmin = IsAdminRole(user.Role);

        if (wasAdmin && newRole == "Customer")
        {
            var admins = await _context.Users.CountAsync(u => u.Role != null && u.Role.Trim().ToLower() == "admin");
            if (admins <= 1)
                return BadRequest("Không thể hạ quyền admin cuối cùng.");
        }

        user.Role = newRole;
        await _context.SaveChangesAsync();

        var row = await RowDtoAsync(id);
        return row is null ? NotFound() : Ok(row);
    }

    [HttpPatch("{id:int}/lock")]
    public async Task<ActionResult<AdminUserRowDto>> SetLock(int id, [FromBody] LockUserDto dto)
    {
        var user = await _context.Users.FirstOrDefaultAsync(u => u.UserID == id);
        if (user == null) return NotFound();

        if (dto.IsLocked && IsAdminRole(user.Role) && !user.IsLocked)
        {
            var otherUnlockedAdmins = await _context.Users.CountAsync(u =>
                u.UserID != id &&
                u.Role != null && u.Role.Trim().ToLower() == "admin" &&
                !u.IsLocked);
            if (otherUnlockedAdmins == 0)
                return BadRequest("Không thể khóa admin cuối cùng đang hoạt động.");
        }

        user.IsLocked = dto.IsLocked;
        await _context.SaveChangesAsync();

        var row = await RowDtoAsync(id);
        return row is null ? NotFound() : Ok(row);
    }

    [HttpDelete("{id:int}")]
    public async Task<IActionResult> Delete(int id)
    {
        var user = await _context.Users.FirstOrDefaultAsync(u => u.UserID == id);
        if (user == null) return NotFound();

        if (await _context.Orders.AsNoTracking().AnyAsync(o => o.UserID == id))
            return BadRequest("Không xóa được: tài khoản có lịch sử đơn hàng.");

        if (IsAdminRole(user.Role))
        {
            var admins = await _context.Users.CountAsync(u => u.Role != null && u.Role.Trim().ToLower() == "admin");
            if (admins <= 1)
                return BadRequest("Không xóa được admin cuối cùng.");
        }

        await DeleteUserRelatedDataAsync(id);
        _context.Users.Remove(user);
        await _context.SaveChangesAsync();
        return NoContent();
    }

    /// <summary>Xóa dữ liệu phụ thuộc user (không có đơn hàng).</summary>
    private async Task DeleteUserRelatedDataAsync(int userId)
    {
        var seedIds = await _context.BlogComments.AsNoTracking()
            .Where(c => c.UserID == userId)
            .Select(c => c.BlogCommentID)
            .ToListAsync();
        var toDeleteComments = new HashSet<int>(seedIds);
        bool added;
        do
        {
            added = false;
            var children = await _context.BlogComments.AsNoTracking()
                .Where(c => c.ParentCommentID != null && toDeleteComments.Contains(c.ParentCommentID.Value))
                .Select(c => c.BlogCommentID)
                .ToListAsync();
            foreach (var cid in children)
            {
                if (toDeleteComments.Add(cid)) added = true;
            }
        } while (added);

        if (toDeleteComments.Count > 0)
        {
            var commentRows = await _context.BlogComments.Where(c => toDeleteComments.Contains(c.BlogCommentID)).ToListAsync();
            _context.BlogComments.RemoveRange(commentRows);
        }

        var reviewIds = await _context.Reviews.Where(r => r.UserID == userId).Select(r => r.ReviewID).ToListAsync();
        if (reviewIds.Count > 0)
        {
            var reviewImages = await _context.ReviewImages.Where(ri => reviewIds.Contains(ri.ReviewID)).ToListAsync();
            _context.ReviewImages.RemoveRange(reviewImages);
            var reviews = await _context.Reviews.Where(r => r.UserID == userId).ToListAsync();
            _context.Reviews.RemoveRange(reviews);
        }

        var usages = await _context.VoucherUsages.Where(v => v.UserID == userId).ToListAsync();
        _context.VoucherUsages.RemoveRange(usages);

        var wishes = await _context.Wishlists.Where(w => w.UserID == userId).ToListAsync();
        _context.Wishlists.RemoveRange(wishes);

        var returns = await _context.ReturnRequests.Include(r => r.Images).Where(r => r.UserID == userId).ToListAsync();
        foreach (var r in returns)
            _context.ReturnRequestImages.RemoveRange(r.Images);
        _context.ReturnRequests.RemoveRange(returns);

        var cart = await _context.Carts.Include(c => c.CartItems).FirstOrDefaultAsync(c => c.UserID == userId);
        if (cart != null)
        {
            _context.CartItems.RemoveRange(cart.CartItems);
            _context.Carts.Remove(cart);
        }
    }
}
