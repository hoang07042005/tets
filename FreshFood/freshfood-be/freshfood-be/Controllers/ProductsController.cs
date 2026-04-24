using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using freshfood_be.Data;
using freshfood_be.Models;

namespace freshfood_be.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    public class ProductsController : ControllerBase
    {
        private readonly FreshFoodContext _context;
            private readonly freshfood_be.Services.Security.IdTokenService _idTokens;

        public ProductsController(FreshFoodContext context, freshfood_be.Services.Security.IdTokenService idTokens)
        {
            _context = context;
            _idTokens = idTokens;
        }

        public sealed record PublicProductDto(
            int ProductID,
            string? ProductToken,
            string ProductName,
            int? CategoryID,
            Category? Category,
            int? SupplierID,
            Supplier? Supplier,
            decimal Price,
            decimal? DiscountPrice,
            int StockQuantity,
            string? Unit,
            string? Description,
            DateTime? ManufacturedDate,
            DateTime? ExpiryDate,
            string? Origin,
            string? StorageInstructions,
            string? Certifications,
            DateTime CreatedAt,
            IEnumerable<ProductImage> ProductImages,
            double AverageRating,
            int ReviewCount
        );

        // GET: api/Products?categoryID=&searchTerm=&minPrice=&maxPrice=&sort=
        // sort: newest | priceAsc | priceDesc | nameAsc | bestsellers
        [HttpGet]
        public async Task<ActionResult<IEnumerable<PublicProductDto>>> GetProducts(
            int? categoryID = null,
            string? searchTerm = null,
            decimal? minPrice = null,
            decimal? maxPrice = null,
            string? sort = null)
        {
            var query = _context.Products
                .Include(p => p.Category)
                .Include(p => p.Supplier)
                .Include(p => p.ProductImages)
                .Include(p => p.Reviews.Where(r => !r.IsDeleted && r.ModerationStatus == "Approved"))
                .Where(p => p.Status == "Active")
                .AsQueryable();

            if (categoryID.HasValue)
                query = query.Where(p => p.CategoryID == categoryID.Value);

            if (!string.IsNullOrEmpty(searchTerm))
                query = query.Where(p => p.ProductName.Contains(searchTerm));

            if (minPrice.HasValue)
                query = query.Where(p =>
                    (p.DiscountPrice.HasValue && p.DiscountPrice < p.Price ? p.DiscountPrice.Value : p.Price) >= minPrice.Value);

            if (maxPrice.HasValue)
                query = query.Where(p =>
                    (p.DiscountPrice.HasValue && p.DiscountPrice < p.Price ? p.DiscountPrice.Value : p.Price) <= maxPrice.Value);

            var sortKey = (sort ?? "newest").Trim().ToLowerInvariant();

            if (sortKey == "bestsellers")
            {
                var list = await query.ToListAsync();
                var sales = await _context.OrderDetails.AsNoTracking()
                    .GroupBy(od => od.ProductID)
                    .Select(g => new { ProductId = g.Key, Sold = g.Sum(x => x.Quantity) })
                    .ToListAsync();

                var rank = new Dictionary<int, int>();
                var order = 0;
                foreach (var row in sales.OrderByDescending(x => x.Sold))
                    rank[row.ProductId] = order++;

                list = list
                    .OrderBy(p => rank.TryGetValue(p.ProductID, out var r) ? r : int.MaxValue)
                    .ThenBy(p => p.ProductName)
                    .ToList();

                return list.Select(p =>
                {
                    var token = _idTokens.ProtectProductId(p.ProductID);
                    var reviews = p.Reviews ?? new List<Review>();
                    var count = reviews.Count;
                    var avg = count > 0 ? Math.Round(reviews.Average(r => (double)r.Rating), 1) : 0d;
                    return new PublicProductDto(
                        p.ProductID,
                        token,
                        p.ProductName,
                        p.CategoryID,
                        p.Category,
                        p.SupplierID,
                        p.Supplier,
                        p.Price,
                        p.DiscountPrice,
                        p.StockQuantity,
                        p.Unit,
                        p.Description,
                        p.ManufacturedDate,
                        p.ExpiryDate,
                        p.Origin,
                        p.StorageInstructions,
                        p.Certifications,
                        p.CreatedAt,
                        p.ProductImages ?? new List<ProductImage>(),
                        avg,
                        count
                    );
                }).ToList();
            }

            query = sortKey switch
            {
                "priceasc" => query
                    .OrderBy(p => p.DiscountPrice.HasValue && p.DiscountPrice < p.Price ? p.DiscountPrice.Value : p.Price)
                    .ThenBy(p => p.ProductID),
                "pricedesc" => query
                    .OrderByDescending(p => p.DiscountPrice.HasValue && p.DiscountPrice < p.Price ? p.DiscountPrice.Value : p.Price)
                    .ThenBy(p => p.ProductID),
                "nameasc" => query.OrderBy(p => p.ProductName).ThenBy(p => p.ProductID),
                _ => query.OrderByDescending(p => p.CreatedAt).ThenByDescending(p => p.ProductID),
            };

            var items = await query.ToListAsync();
            return items.Select(p =>
            {
                var token = _idTokens.ProtectProductId(p.ProductID);
                var reviews = p.Reviews ?? new List<Review>();
                var count = reviews.Count;
                var avg = count > 0 ? Math.Round(reviews.Average(r => (double)r.Rating), 1) : 0d;
                return new PublicProductDto(
                    p.ProductID,
                    token,
                    p.ProductName,
                    p.CategoryID,
                    p.Category,
                    p.SupplierID,
                    p.Supplier,
                    p.Price,
                    p.DiscountPrice,
                    p.StockQuantity,
                    p.Unit,
                    p.Description,
                    p.ManufacturedDate,
                    p.ExpiryDate,
                    p.Origin,
                    p.StorageInstructions,
                    p.Certifications,
                    p.CreatedAt,
                    p.ProductImages ?? new List<ProductImage>(),
                    avg,
                    count
                );
            }).ToList();
        }

        // GET: api/Products/Promotions
        [HttpGet("Promotions")]
        public async Task<ActionResult<IEnumerable<PublicProductDto>>> GetPromotions()
        {
            var list = await _context.Products
                .Include(p => p.Category)
                .Include(p => p.ProductImages)
                .Include(p => p.Reviews.Where(r => !r.IsDeleted && r.ModerationStatus == "Approved"))
                .Where(p => p.Status == "Active" && p.DiscountPrice.HasValue && p.DiscountPrice < p.Price)
                .ToListAsync();

            return list.Select(p =>
            {
                var token = _idTokens.ProtectProductId(p.ProductID);
                var reviews = p.Reviews ?? new List<Review>();
                var count = reviews.Count;
                var avg = count > 0 ? Math.Round(reviews.Average(r => (double)r.Rating), 1) : 0d;
                return new PublicProductDto(
                    p.ProductID,
                    token,
                    p.ProductName,
                    p.CategoryID,
                    p.Category,
                    p.SupplierID,
                    p.Supplier,
                    p.Price,
                    p.DiscountPrice,
                    p.StockQuantity,
                    p.Unit,
                    p.Description,
                    p.ManufacturedDate,
                    p.ExpiryDate,
                    p.Origin,
                    p.StorageInstructions,
                    p.Certifications,
                    p.CreatedAt,
                    p.ProductImages ?? new List<ProductImage>(),
                    avg,
                    count
                );
            }).ToList();
        }

        // GET: api/Products/5
        [HttpGet("{id}")]
        public async Task<ActionResult<Product>> GetProduct(int id)
        {
            var product = await _context.Products
                .Include(p => p.Category)
                .Include(p => p.Supplier)
                .Include(p => p.ProductImages)
                .Include(p => p.Reviews.Where(r => !r.IsDeleted && r.ModerationStatus == "Approved"))
                    .ThenInclude(r => r.User)
                .Include(p => p.Reviews.Where(r => !r.IsDeleted && r.ModerationStatus == "Approved"))
                    .ThenInclude(r => r.ReviewImages)
                .FirstOrDefaultAsync(p => p.ProductID == id && p.Status == "Active");

            if (product == null)
            {
                return NotFound();
            }

            product.ProductToken = _idTokens.ProtectProductId(product.ProductID);
            return product;
        }

        // GET: api/Products/token/xxxx  (tokenized id)
        [HttpGet("token/{token}")]
        public async Task<ActionResult<Product>> GetProductByToken([FromRoute] string token)
        {
            if (string.IsNullOrWhiteSpace(token)) return NotFound();
            var id = _idTokens.UnprotectProductId(token.Trim());
            if (id == null || id <= 0) return NotFound();
            return await GetProduct(id.Value);
        }

        // POST: api/Products
        [HttpPost]
        public async Task<ActionResult<Product>> PostProduct(Product product)
        {
            product.CreatedAt = DateTime.UtcNow;
            _context.Products.Add(product);
            await _context.SaveChangesAsync();

            return CreatedAtAction("GetProduct", new { id = product.ProductID }, product);
        }

        // PUT: api/Products/5
        [HttpPut("{id}")]
        public async Task<IActionResult> PutProduct(int id, Product product)
        {
            if (id != product.ProductID)
            {
                return BadRequest();
            }

            _context.Entry(product).State = EntityState.Modified;

            try
            {
                await _context.SaveChangesAsync();
            }
            catch (DbUpdateConcurrencyException)
            {
                if (!ProductExists(id))
                {
                    return NotFound();
                }
                else
                {
                    throw;
                }
            }

            return NoContent();
        }

        // DELETE: api/Products/5
        [HttpDelete("{id}")]
        public async Task<IActionResult> DeleteProduct(int id)
        {
            var product = await _context.Products.FindAsync(id);
            if (product == null)
            {
                return NotFound();
            }

            _context.Products.Remove(product);
            await _context.SaveChangesAsync();

            return NoContent();
        }

        private bool ProductExists(int id)
        {
            return _context.Products.Any(e => e.ProductID == id);
        }
    }
}
