using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using freshfood_be.Data;
using freshfood_be.Models;
using freshfood_be.Services.Security;

namespace freshfood_be.Controllers
{
    /// <summary>Quản trị danh mục — chỉ dùng cho admin FE, tách khỏi API Categories công khai.</summary>
    [Authorize(Roles = "Admin")]
    [Route("api/Admin/Categories")]
    [ApiController]
    public class AdminCategoriesController : ControllerBase
    {
        private readonly FreshFoodContext _context;
        private readonly AdminAuditLogger _audit;

        public AdminCategoriesController(FreshFoodContext context, AdminAuditLogger audit)
        {
            _context = context;
            _audit = audit;
        }

        [HttpGet]
        public async Task<ActionResult<IEnumerable<Category>>> GetAll()
        {
            return await _context.Categories
                .AsNoTracking()
                .Include(c => c.Products)
                .OrderBy(c => c.CategoryName)
                .ToListAsync();
        }

        [HttpGet("{id:int}")]
        public async Task<ActionResult<Category>> GetCategory(int id)
        {
            var category = await _context.Categories
                .AsNoTracking()
                .Include(c => c.Products)
                .FirstOrDefaultAsync(c => c.CategoryID == id);

            if (category == null)
                return NotFound();

            return category;
        }

        [HttpPost]
        public async Task<ActionResult<Category>> Create([FromBody] Category category)
        {
            category.CategoryID = 0;
            _context.Categories.Add(category);
            await _context.SaveChangesAsync();

            await _audit.LogAsync(
                action: "categories.create",
                entityType: "Category",
                entityId: category.CategoryID.ToString(),
                summary: $"Created category: {category.CategoryName}",
                data: new { categoryId = category.CategoryID, category.CategoryName },
                ct: HttpContext.RequestAborted);

            return CreatedAtAction(nameof(GetCategory), new { id = category.CategoryID }, category);
        }

        [HttpPut("{id:int}")]
        public async Task<ActionResult<Category>> Update(int id, [FromBody] Category input)
        {
            var existing = await _context.Categories.FindAsync(id);
            if (existing == null)
                return NotFound();

            var before = new { existing.CategoryName, existing.Description };
            existing.CategoryName = input.CategoryName;
            existing.Description = input.Description;
            await _context.SaveChangesAsync();

            await _audit.LogAsync(
                action: "categories.update",
                entityType: "Category",
                entityId: id.ToString(),
                summary: $"Updated category: {existing.CategoryName}",
                data: new { categoryId = id, before, after = new { existing.CategoryName, existing.Description } },
                ct: HttpContext.RequestAborted);

            return Ok(existing);
        }

        [HttpDelete("{id:int}")]
        public async Task<IActionResult> Delete(int id)
        {
            var existing = await _context.Categories.FindAsync(id);
            if (existing == null)
                return NotFound();

            var hasProducts = await _context.Products.AnyAsync(p => p.CategoryID == id);
            if (hasProducts)
                return Conflict("Không xóa được: danh mục còn sản phẩm.");

            _context.Categories.Remove(existing);
            await _context.SaveChangesAsync();

            await _audit.LogAsync(
                action: "categories.delete",
                entityType: "Category",
                entityId: id.ToString(),
                summary: $"Deleted category: {existing.CategoryName}",
                data: new { categoryId = id, existing.CategoryName },
                ct: HttpContext.RequestAborted);
            return NoContent();
        }
    }
}
