using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using freshfood_be.Data;
using freshfood_be.Models;
using freshfood_be.Services.Security;

namespace freshfood_be.Controllers;

/// <summary>Danh sách sản phẩm quản trị — api/Admin/Products</summary>
[Authorize(Roles = "Admin")]
[Route("api/Admin/Products")]
[ApiController]
public class AdminProductsController : ControllerBase
{
    private const int LowStockThreshold = 15;

    private readonly FreshFoodContext _context;
    private readonly freshfood_be.Services.Security.IdTokenService _idTokens;
    private readonly AdminAuditLogger _audit;

    public AdminProductsController(FreshFoodContext context, freshfood_be.Services.Security.IdTokenService idTokens, AdminAuditLogger audit)
    {
        _context = context;
        _idTokens = idTokens;
        _audit = audit;
    }

    public record AdminProductStatsDto(int Total, int OutOfStock, int OnSale, decimal InventoryValue);

    public record AdminProductRowDto(
        int ProductID,
        string ProductToken,
        string ProductName,
        string Sku,
        string? CategoryName,
        int? CategoryID,
        string? SupplierName,
        string? ImageUrl,
        decimal Price,
        decimal? DiscountPrice,
        int StockQuantity,
        string? Unit,
        string Status,
        bool IsOnSale,
        bool IsLowStock);

    public record AdminProductsPageDto(
        IReadOnlyList<AdminProductRowDto> Items,
        int TotalCount,
        int Page,
        int PageSize,
        AdminProductStatsDto Stats);

    public record AdminProductUpsertDto(
        string ProductName,
        int? CategoryID,
        int? SupplierID,
        decimal Price,
        decimal? DiscountPrice,
        int StockQuantity,
        string? Unit,
        string? Description,
        DateTime? ManufacturedDate = null,
        DateTime? ExpiryDate = null,
        string? Origin = null,
        string? StorageInstructions = null,
        string? Certifications = null,
        string? Status = null);

    public record ImportStockRequest(int Quantity, string? Note);

    public record ImportStockResponse(int ProductID, int StockQuantity, int ImportedQuantity, DateTime LogDate);

    private static string MakeSku(string name, int id)
    {
        // FF-KALE-001 (lấy chữ cái/ số, bỏ dấu cơ bản)
        var cleaned = (name ?? string.Empty).Trim().ToUpperInvariant();
        cleaned = cleaned
            .Replace("Á", "A").Replace("À", "A").Replace("Ả", "A").Replace("Ã", "A").Replace("Ạ", "A")
            .Replace("Ă", "A").Replace("Ắ", "A").Replace("Ằ", "A").Replace("Ẳ", "A").Replace("Ẵ", "A").Replace("Ặ", "A")
            .Replace("Â", "A").Replace("Ấ", "A").Replace("Ầ", "A").Replace("Ẩ", "A").Replace("Ẫ", "A").Replace("Ậ", "A")
            .Replace("É", "E").Replace("È", "E").Replace("Ẻ", "E").Replace("Ẽ", "E").Replace("Ẹ", "E")
            .Replace("Ê", "E").Replace("Ế", "E").Replace("Ề", "E").Replace("Ể", "E").Replace("Ễ", "E").Replace("Ệ", "E")
            .Replace("Í", "I").Replace("Ì", "I").Replace("Ỉ", "I").Replace("Ĩ", "I").Replace("Ị", "I")
            .Replace("Ó", "O").Replace("Ò", "O").Replace("Ỏ", "O").Replace("Õ", "O").Replace("Ọ", "O")
            .Replace("Ô", "O").Replace("Ố", "O").Replace("Ồ", "O").Replace("Ổ", "O").Replace("Ỗ", "O").Replace("Ộ", "O")
            .Replace("Ơ", "O").Replace("Ớ", "O").Replace("Ờ", "O").Replace("Ở", "O").Replace("Ỡ", "O").Replace("Ợ", "O")
            .Replace("Ú", "U").Replace("Ù", "U").Replace("Ủ", "U").Replace("Ũ", "U").Replace("Ụ", "U")
            .Replace("Ư", "U").Replace("Ứ", "U").Replace("Ừ", "U").Replace("Ử", "U").Replace("Ữ", "U").Replace("Ự", "U")
            .Replace("Ý", "Y").Replace("Ỳ", "Y").Replace("Ỷ", "Y").Replace("Ỹ", "Y").Replace("Ỵ", "Y")
            .Replace("Đ", "D");

        var token = new string(cleaned.Where(ch => (ch >= 'A' && ch <= 'Z') || (ch >= '0' && ch <= '9')).ToArray());
        if (token.Length > 8) token = token.Substring(0, 8);
        if (token.Length < 3) token = "PRD";
        return $"FF-{token}-{id:D3}";
    }

    [HttpGet]
    public async Task<ActionResult<AdminProductsPageDto>> List(
        [FromQuery] int page = 1,
        [FromQuery] int pageSize = 10,
        [FromQuery] string? q = null,
        [FromQuery] int? categoryId = null,
        [FromQuery] string? status = null)
    {
        page = Math.Max(1, page);
        pageSize = Math.Clamp(pageSize, 1, 100);

        var totalAll = await _context.Products.AsNoTracking().CountAsync();
        var outOfStock = await _context.Products.AsNoTracking().CountAsync(p => p.StockQuantity <= 0);
        var onSale = await _context.Products.AsNoTracking()
            .CountAsync(p => p.DiscountPrice.HasValue && p.DiscountPrice < p.Price);
        var inventoryValue = await _context.Products.AsNoTracking()
            .SumAsync(p => (p.DiscountPrice ?? p.Price) * p.StockQuantity);

        var stats = new AdminProductStatsDto(totalAll, outOfStock, onSale, inventoryValue);

        var baseQuery = _context.Products.AsNoTracking().AsQueryable();

        if (categoryId is > 0)
            baseQuery = baseQuery.Where(p => p.CategoryID == categoryId);

        if (!string.IsNullOrWhiteSpace(q))
        {
            var term = q.Trim();
            baseQuery = baseQuery.Where(p =>
                p.ProductName.Contains(term) ||
                (p.Sku != null && p.Sku.Contains(term)) ||
                p.ProductID.ToString().Contains(term));
        }

        if (!string.IsNullOrWhiteSpace(status) && status.Trim().ToLowerInvariant() != "all")
        {
            var st = status.Trim();
            baseQuery = baseQuery.Where(p => p.Status == st);
        }

        var totalFiltered = await baseQuery.CountAsync();

        var rows = await baseQuery
            .OrderBy(p => p.ProductName)
            .Skip((page - 1) * pageSize)
            .Take(pageSize)
            .Select(p => new AdminProductRowDto(
                p.ProductID,
                "",
                p.ProductName,
                (p.Sku ?? $"FF-PRD-{p.ProductID:D3}"),
                p.Category != null ? p.Category.CategoryName : null,
                p.CategoryID,
                p.Supplier != null ? p.Supplier.SupplierName : null,
                p.ProductImages.Where(pi => pi.IsMainImage).Select(pi => pi.ImageURL).FirstOrDefault()
                    ?? p.ProductImages.Select(pi => pi.ImageURL).FirstOrDefault(),
                p.Price,
                p.DiscountPrice,
                p.StockQuantity,
                p.Unit,
                (p.Status ?? "Active"),
                p.DiscountPrice.HasValue && p.DiscountPrice < p.Price,
                p.StockQuantity <= LowStockThreshold))
            .ToListAsync();

        rows = rows
            .Select(r => new AdminProductRowDto(
                r.ProductID,
                _idTokens.ProtectProductId(r.ProductID),
                r.ProductName,
                r.Sku,
                r.CategoryName,
                r.CategoryID,
                r.SupplierName,
                r.ImageUrl,
                r.Price,
                r.DiscountPrice,
                r.StockQuantity,
                r.Unit,
                r.Status,
                r.IsOnSale,
                r.IsLowStock))
            .ToList();

        return Ok(new AdminProductsPageDto(rows, totalFiltered, page, pageSize, stats));
    }

    [HttpGet("{id:int}")]
    public async Task<ActionResult<Product>> GetById([FromRoute] int id)
    {
        var product = await _context.Products
            .Include(p => p.Category)
            .Include(p => p.Supplier)
            .Include(p => p.ProductImages)
            .Include(p => p.Reviews.Where(r => !r.IsDeleted && r.ModerationStatus == "Approved"))
                .ThenInclude(r => r.User)
            .Include(p => p.Reviews.Where(r => !r.IsDeleted && r.ModerationStatus == "Approved"))
                .ThenInclude(r => r.ReviewImages)
            .FirstOrDefaultAsync(p => p.ProductID == id);

        if (product == null) return NotFound();
        product.ProductToken = _idTokens.ProtectProductId(product.ProductID);
        return Ok(product);
    }

    [HttpGet("token/{token}")]
    public async Task<ActionResult<Product>> GetByToken([FromRoute] string token)
    {
        if (string.IsNullOrWhiteSpace(token)) return NotFound();
        var id = _idTokens.UnprotectProductId(token.Trim());
        if (id == null || id <= 0) return NotFound();
        return await GetById(id.Value);
    }

    [HttpPost]
    public async Task<ActionResult<Product>> Create([FromBody] AdminProductUpsertDto input)
    {
        var name = (input.ProductName ?? string.Empty).Trim();
        if (string.IsNullOrWhiteSpace(name))
            return BadRequest("Tên sản phẩm bắt buộc.");

        if (input.Price < 0 || input.StockQuantity < 0)
            return BadRequest("Giá và tồn kho phải không âm.");

        var p = new Product
        {
            ProductName = name,
            CategoryID = input.CategoryID,
            SupplierID = input.SupplierID,
            Price = input.Price,
            DiscountPrice = input.DiscountPrice,
            StockQuantity = input.StockQuantity,
            Unit = string.IsNullOrWhiteSpace(input.Unit) ? "kg" : input.Unit!.Trim(),
            Description = string.IsNullOrWhiteSpace(input.Description) ? null : input.Description!.Trim(),
            ManufacturedDate = input.ManufacturedDate,
            ExpiryDate = input.ExpiryDate,
            Origin = string.IsNullOrWhiteSpace(input.Origin) ? null : input.Origin.Trim(),
            StorageInstructions = string.IsNullOrWhiteSpace(input.StorageInstructions) ? null : input.StorageInstructions.Trim(),
            Certifications = string.IsNullOrWhiteSpace(input.Certifications) ? null : input.Certifications.Trim(),
            Status = string.IsNullOrWhiteSpace(input.Status) ? "Active" : input.Status.Trim(),
            CreatedAt = DateTime.UtcNow,
        };

        _context.Products.Add(p);
        await _context.SaveChangesAsync();

        if (string.IsNullOrWhiteSpace(p.Sku))
        {
            p.Sku = MakeSku(p.ProductName, p.ProductID);
            await _context.SaveChangesAsync();
        }

        await _audit.LogAsync(
            action: "products.create",
            entityType: "Product",
            entityId: p.ProductID.ToString(),
            summary: $"Created product: {p.ProductName}",
            data: new { productId = p.ProductID, p.ProductName, p.Price, p.StockQuantity, p.Status },
            ct: HttpContext.RequestAborted);

        return CreatedAtAction(nameof(List), new { page = 1, pageSize = 10 }, p);
    }

    [HttpPut("{id:int}")]
    public async Task<ActionResult<Product>> Update(int id, [FromBody] AdminProductUpsertDto input)
    {
        var product = await _context.Products.FirstOrDefaultAsync(p => p.ProductID == id);
        if (product == null) return NotFound();

        var before = new { product.ProductName, product.Price, product.DiscountPrice, product.StockQuantity, product.Status };

        var name = (input.ProductName ?? string.Empty).Trim();
        if (string.IsNullOrWhiteSpace(name))
            return BadRequest("Tên sản phẩm bắt buộc.");

        if (input.Price < 0 || input.StockQuantity < 0)
            return BadRequest("Giá và tồn kho phải không âm.");

        product.ProductName = name;
        product.CategoryID = input.CategoryID;
        product.SupplierID = input.SupplierID;
        product.Price = input.Price;
        product.DiscountPrice = input.DiscountPrice;
        product.StockQuantity = input.StockQuantity;
        product.Unit = string.IsNullOrWhiteSpace(input.Unit) ? "kg" : input.Unit!.Trim();
        product.Description = string.IsNullOrWhiteSpace(input.Description) ? null : input.Description!.Trim();
        product.ManufacturedDate = input.ManufacturedDate;
        product.ExpiryDate = input.ExpiryDate;
        product.Origin = string.IsNullOrWhiteSpace(input.Origin) ? null : input.Origin.Trim();
        product.StorageInstructions = string.IsNullOrWhiteSpace(input.StorageInstructions) ? null : input.StorageInstructions.Trim();
        product.Certifications = string.IsNullOrWhiteSpace(input.Certifications) ? null : input.Certifications.Trim();
        product.Status = string.IsNullOrWhiteSpace(input.Status) ? (product.Status ?? "Active") : input.Status.Trim();

        await _context.SaveChangesAsync();

        if (string.IsNullOrWhiteSpace(product.Sku))
        {
            product.Sku = MakeSku(product.ProductName, product.ProductID);
            await _context.SaveChangesAsync();
        }

        await _audit.LogAsync(
            action: "products.update",
            entityType: "Product",
            entityId: id.ToString(),
            summary: $"Updated product: {product.ProductName}",
            data: new { productId = id, before, after = new { product.ProductName, product.Price, product.DiscountPrice, product.StockQuantity, product.Status } },
            ct: HttpContext.RequestAborted);

        return Ok(product);
    }

    /// <summary>
    /// Nhập thêm hàng (tăng StockQuantity) và ghi lịch sử kho (InventoryHistory).
    /// </summary>
    [HttpPost("{id:int}/stock/import")]
    public async Task<ActionResult<ImportStockResponse>> ImportStock(int id, [FromBody] ImportStockRequest input)
    {
        if (input == null) return BadRequest("Thiếu dữ liệu nhập kho.");
        if (input.Quantity <= 0) return BadRequest("Số lượng nhập phải lớn hơn 0.");

        var product = await _context.Products.FirstOrDefaultAsync(p => p.ProductID == id);
        if (product == null) return NotFound("Không tìm thấy sản phẩm.");

        await using var tx = await _context.Database.BeginTransactionAsync();
        try
        {
            var beforeQty = product.StockQuantity;
            product.StockQuantity += input.Quantity;

            var log = new InventoryHistory
            {
                ProductID = product.ProductID,
                ChangeQuantity = input.Quantity,
                ChangeType = "Import",
                Note = string.IsNullOrWhiteSpace(input.Note) ? null : input.Note.Trim(),
                LogDate = DateTime.UtcNow,
            };
            _context.InventoryHistories.Add(log);

            await _context.SaveChangesAsync();
            await tx.CommitAsync();

            await _audit.LogAsync(
                action: "products.import_stock",
                entityType: "Product",
                entityId: id.ToString(),
                summary: $"Import stock +{input.Quantity}",
                data: new { productId = id, beforeQty, afterQty = product.StockQuantity, imported = input.Quantity, note = input.Note },
                ct: HttpContext.RequestAborted);

            return Ok(new ImportStockResponse(product.ProductID, product.StockQuantity, input.Quantity, log.LogDate));
        }
        catch
        {
            await tx.RollbackAsync();
            throw;
        }
    }
}
