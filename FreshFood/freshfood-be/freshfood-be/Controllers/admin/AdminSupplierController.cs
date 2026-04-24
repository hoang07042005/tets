using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using freshfood_be.Data;
using freshfood_be.Models;
using freshfood_be.Services.Security;

namespace freshfood_be.Controllers;

/// <summary>Quản trị nhà cung cấp — api/Admin/Suppliers</summary>
[Authorize(Roles = "Admin")]
[Route("api/Admin/Suppliers")]
[ApiController]
public class AdminSupplierController : ControllerBase
{
    private readonly FreshFoodContext _context;
    private readonly IWebHostEnvironment _env;
    private readonly AdminAuditLogger _audit;

    public AdminSupplierController(FreshFoodContext context, IWebHostEnvironment env, AdminAuditLogger audit)
    {
        _context = context;
        _env = env;
        _audit = audit;
    }

    public record AdminSupplierRowDto(
        int SupplierID,
        string SupplierName,
        string? SupplierCode,
        string? ContactName,
        string? Phone,
        string? Email,
        string? Address,
        string Status,
        bool IsVerified,
        string? ImageUrl,
        int ProductCount);

    public record AdminSupplierStatsDto(
        int Total,
        int Verified,
        int InTransaction,
        int NewThisMonth);

    public record AdminSuppliersPageDto(
        IReadOnlyList<AdminSupplierRowDto> Items,
        int TotalCount,
        int Page,
        int PageSize,
        AdminSupplierStatsDto Stats);

    public record CreateSupplierDto(
        string SupplierName,
        string? ContactName,
        string? Phone,
        string? Email,
        string? Address,
        string? SupplierCode,
        string? ImageUrl,
        string Status,
        bool IsVerified);

    public sealed record UploadImageResultDto(string ImageUrl);

    // POST: api/Admin/Suppliers/UploadImage (multipart/form-data: field "file")
    [HttpPost("UploadImage")]
    [Consumes("multipart/form-data")]
    [RequestSizeLimit(10_000_000)] // ~10MB
    public async Task<ActionResult<UploadImageResultDto>> UploadImage([FromForm] IFormFile file, CancellationToken ct)
    {
        if (file == null || file.Length == 0) return BadRequest("Vui lòng chọn ảnh.");

        var allowed = new HashSet<string> { ".jpg", ".jpeg", ".png", ".webp", ".gif", ".jfif" };
        var ext = Path.GetExtension(file.FileName).ToLowerInvariant();
        if (string.IsNullOrWhiteSpace(ext) || !allowed.Contains(ext))
            return BadRequest($"Unsupported image extension: {ext}. Allowed: jpg, jpeg, png, webp, gif, jfif.");

        if (string.IsNullOrWhiteSpace(file.ContentType) || !file.ContentType.StartsWith("image/", StringComparison.OrdinalIgnoreCase))
            return BadRequest("Only image files are allowed.");

        var rootDir = Path.Combine(_env.ContentRootPath, "wwwroot", "supplier-assets");
        Directory.CreateDirectory(rootDir);

        var safeName = $"{Guid.NewGuid():N}{ext}";
        var fullPath = Path.Combine(rootDir, safeName);
        await using (var stream = System.IO.File.Create(fullPath))
        {
            await file.CopyToAsync(stream, ct);
        }

        var url = $"/supplier-assets/{safeName}";

        await _audit.LogAsync(
            action: "suppliers.upload_image",
            entityType: "Supplier",
            entityId: "0",
            summary: "Uploaded supplier image",
            data: new { imageUrl = url, fileName = file.FileName, size = file.Length, contentType = file.ContentType },
            ct: ct);

        return Ok(new UploadImageResultDto(url));
    }

    [HttpGet]
    public async Task<ActionResult<AdminSuppliersPageDto>> List(
        [FromQuery] int page = 1,
        [FromQuery] int pageSize = 10,
        [FromQuery] string tab = "all",
        [FromQuery] string? q = null)
    {
        page = Math.Max(1, page);
        pageSize = Math.Clamp(pageSize, 1, 100);
        var t = (tab ?? "all").Trim().ToLowerInvariant();

        var baseQuery = _context.Suppliers.AsNoTracking();

        if (t == "pending")
            baseQuery = baseQuery.Where(s => s.Status == "Pending");
        else if (t == "paused")
            baseQuery = baseQuery.Where(s => s.Status == "Paused");
        // "all" — no status filter

        if (!string.IsNullOrWhiteSpace(q))
        {
            var term = q.Trim();
            baseQuery = baseQuery.Where(s =>
                s.SupplierName.Contains(term) ||
                (s.SupplierCode != null && s.SupplierCode.Contains(term)) ||
                (s.ContactName != null && s.ContactName.Contains(term)) ||
                (s.Phone != null && s.Phone.Contains(term)));
        }

        var now = DateTime.UtcNow;
        var monthStart = new DateTime(now.Year, now.Month, 1, 0, 0, 0, DateTimeKind.Utc);

        var totalAll = await _context.Suppliers.AsNoTracking().CountAsync();
        var verifiedAll = await _context.Suppliers.AsNoTracking().CountAsync(s => s.IsVerified);
        var inTransaction = await _context.Suppliers.AsNoTracking()
            .Where(s => s.Products.Any())
            .CountAsync();
        var newThisMonth = await _context.Suppliers.AsNoTracking()
            .CountAsync(s => s.CreatedAt >= monthStart);

        var stats = new AdminSupplierStatsDto(totalAll, verifiedAll, inTransaction, newThisMonth);

        var totalFiltered = await baseQuery.CountAsync();

        var items = await baseQuery
            .OrderBy(s => s.SupplierName)
            .Skip((page - 1) * pageSize)
            .Take(pageSize)
            .Select(s => new AdminSupplierRowDto(
                s.SupplierID,
                s.SupplierName,
                s.SupplierCode,
                s.ContactName,
                s.Phone,
                s.Email,
                s.Address,
                s.Status,
                s.IsVerified,
                s.ImageUrl,
                s.Products.Count))
            .ToListAsync();

        return Ok(new AdminSuppliersPageDto(items, totalFiltered, page, pageSize, stats));
    }

    [HttpPost]
    public async Task<ActionResult<AdminSupplierRowDto>> Create([FromBody] CreateSupplierDto input)
    {
        var name = (input.SupplierName ?? "").Trim();
        if (string.IsNullOrEmpty(name))
            return BadRequest("Tên nhà cung cấp bắt buộc.");

        var status = string.IsNullOrWhiteSpace(input.Status) ? "Active" : input.Status.Trim();
        if (status is not ("Active" or "Paused" or "Pending"))
            status = "Active";

        var s = new Supplier
        {
            SupplierName = name,
            ContactName = string.IsNullOrWhiteSpace(input.ContactName) ? null : input.ContactName.Trim(),
            Phone = string.IsNullOrWhiteSpace(input.Phone) ? null : input.Phone.Trim(),
            Email = string.IsNullOrWhiteSpace(input.Email) ? null : input.Email.Trim(),
            Address = string.IsNullOrWhiteSpace(input.Address) ? null : input.Address.Trim(),
            SupplierCode = string.IsNullOrWhiteSpace(input.SupplierCode) ? null : input.SupplierCode.Trim(),
            ImageUrl = string.IsNullOrWhiteSpace(input.ImageUrl) ? null : input.ImageUrl.Trim(),
            Status = status,
            IsVerified = input.IsVerified,
            CreatedAt = DateTime.UtcNow,
        };

        _context.Suppliers.Add(s);
        await _context.SaveChangesAsync();

        if (string.IsNullOrWhiteSpace(s.SupplierCode))
        {
            s.SupplierCode = $"VH-{DateTime.UtcNow:yyyy}-{s.SupplierID:D3}";
            await _context.SaveChangesAsync();
        }

        await _audit.LogAsync(
            action: "suppliers.create",
            entityType: "Supplier",
            entityId: s.SupplierID.ToString(),
            summary: $"Created supplier: {s.SupplierName}",
            data: new { supplierId = s.SupplierID, s.SupplierName, s.SupplierCode, s.Status, s.IsVerified },
            ct: HttpContext.RequestAborted);

        var dto = new AdminSupplierRowDto(
            s.SupplierID,
            s.SupplierName,
            s.SupplierCode,
            s.ContactName,
            s.Phone,
            s.Email,
            s.Address,
            s.Status,
            s.IsVerified,
            s.ImageUrl,
            0);

        return CreatedAtAction(nameof(List), new { page = 1, pageSize = 10 }, dto);
    }

    [HttpPut("{id:int}")]
    public async Task<ActionResult<AdminSupplierRowDto>> Update(int id, [FromBody] CreateSupplierDto input)
    {
        var s = await _context.Suppliers.FirstOrDefaultAsync(x => x.SupplierID == id);
        if (s == null) return NotFound();

        var before = new { s.SupplierName, s.SupplierCode, s.Status, s.IsVerified, s.ImageUrl, s.Phone, s.Email, s.Address };

        var name = (input.SupplierName ?? "").Trim();
        if (string.IsNullOrEmpty(name))
            return BadRequest("Tên nhà cung cấp bắt buộc.");

        var status = string.IsNullOrWhiteSpace(input.Status) ? s.Status : input.Status.Trim();
        if (status is not ("Active" or "Paused" or "Pending"))
            status = "Active";

        s.SupplierName = name;
        s.ContactName = string.IsNullOrWhiteSpace(input.ContactName) ? null : input.ContactName.Trim();
        s.Phone = string.IsNullOrWhiteSpace(input.Phone) ? null : input.Phone.Trim();
        s.Email = string.IsNullOrWhiteSpace(input.Email) ? null : input.Email.Trim();
        s.Address = string.IsNullOrWhiteSpace(input.Address) ? null : input.Address.Trim();
        if (!string.IsNullOrWhiteSpace(input.SupplierCode))
            s.SupplierCode = input.SupplierCode.Trim();
        s.ImageUrl = string.IsNullOrWhiteSpace(input.ImageUrl) ? null : input.ImageUrl.Trim();
        s.Status = status;
        s.IsVerified = input.IsVerified;

        await _context.SaveChangesAsync();

        var productCount = await _context.Products.AsNoTracking().CountAsync(p => p.SupplierID == id);

        await _audit.LogAsync(
            action: "suppliers.update",
            entityType: "Supplier",
            entityId: id.ToString(),
            summary: $"Updated supplier: {s.SupplierName}",
            data: new { supplierId = id, before, after = new { s.SupplierName, s.SupplierCode, s.Status, s.IsVerified, s.ImageUrl, s.Phone, s.Email, s.Address } },
            ct: HttpContext.RequestAborted);

        return Ok(new AdminSupplierRowDto(
            s.SupplierID,
            s.SupplierName,
            s.SupplierCode,
            s.ContactName,
            s.Phone,
            s.Email,
            s.Address,
            s.Status,
            s.IsVerified,
            s.ImageUrl,
            productCount));
    }

    [HttpDelete("{id:int}")]
    public async Task<IActionResult> Delete(int id)
    {
        var s = await _context.Suppliers.FirstOrDefaultAsync(x => x.SupplierID == id);
        if (s == null) return NotFound();

        var hasProducts = await _context.Products.AsNoTracking().AnyAsync(p => p.SupplierID == id);
        if (hasProducts)
            return BadRequest("Không xóa được nhà cung cấp đang có sản phẩm.");

        _context.Suppliers.Remove(s);
        await _context.SaveChangesAsync();

        await _audit.LogAsync(
            action: "suppliers.delete",
            entityType: "Supplier",
            entityId: id.ToString(),
            summary: $"Deleted supplier: {s.SupplierName}",
            data: new { supplierId = id, s.SupplierName, s.SupplierCode },
            ct: HttpContext.RequestAborted);
        return NoContent();
    }
}
