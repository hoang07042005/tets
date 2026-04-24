using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using freshfood_be.Data;
using freshfood_be.Models;

namespace freshfood_be.Controllers;

/// <summary>
/// Cart APIs (DB-backed cart). Auth is not implemented in this project,
/// so endpoints take userId explicitly (same pattern as existing Orders APIs).
/// </summary>
[Route("api/[controller]")]
[ApiController]
public class CartController : ControllerBase
{
    private readonly FreshFoodContext _context;

    public CartController(FreshFoodContext context)
    {
        _context = context;
    }

    public record CartItemDto(int ProductID, int Quantity);

    public record CartLineDto(Product Product, int Quantity);

    public record CartDto(int CartID, int UserID, IReadOnlyList<CartLineDto> Items);

    private int? GetAuthUserId()
    {
        var v = User?.FindFirstValue(ClaimTypes.NameIdentifier) ?? User?.FindFirstValue("sub");
        return int.TryParse(v, out var id) && id > 0 ? id : null;
    }

    private bool IsOwner(int userId) => GetAuthUserId() == userId;

    private async Task<Cart> GetOrCreateCartAsync(int userId)
    {
        var cart = await _context.Carts
            .Include(c => c.CartItems)
            .FirstOrDefaultAsync(c => c.UserID == userId);

        if (cart != null) return cart;

        cart = new Cart { UserID = userId, CreatedAt = DateTime.Now, UpdatedAt = DateTime.Now };
        _context.Carts.Add(cart);
        await _context.SaveChangesAsync();
        return cart;
    }

    // GET: api/Cart/user/5
    [Authorize]
    [HttpGet("user/{userId:int}")]
    public async Task<ActionResult<CartDto>> GetUserCart(int userId)
    {
        if (!IsOwner(userId)) return Forbid();
        if (userId <= 0) return BadRequest("Invalid userId.");

        var userExists = await _context.Users.AsNoTracking().AnyAsync(u => u.UserID == userId);
        if (!userExists) return NotFound("User not found.");

        var cart = await GetOrCreateCartAsync(userId);

        // Load products for lines
        var productIds = cart.CartItems.Select(ci => ci.ProductID).Distinct().ToList();
        var products = await _context.Products
            .AsNoTracking()
            .Include(p => p.ProductImages)
            .Include(p => p.Category)
            .Include(p => p.Supplier)
            .Where(p => productIds.Contains(p.ProductID))
            .ToListAsync();

        var map = products.ToDictionary(p => p.ProductID, p => p);
        var lines = cart.CartItems
            .Where(ci => map.ContainsKey(ci.ProductID))
            .Select(ci => new CartLineDto(map[ci.ProductID], ci.Quantity))
            .ToList();

        return Ok(new CartDto(cart.CartID, userId, lines));
    }

    // PUT: api/Cart/user/5
    // Replace the entire cart with provided items.
    [Authorize]
    [HttpPut("user/{userId:int}")]
    public async Task<ActionResult<CartDto>> ReplaceUserCart(int userId, [FromBody] List<CartItemDto> items)
    {
        if (!IsOwner(userId)) return Forbid();
        if (userId <= 0) return BadRequest("Invalid userId.");
        items ??= new List<CartItemDto>();

        var userExists = await _context.Users.AsNoTracking().AnyAsync(u => u.UserID == userId);
        if (!userExists) return NotFound("User not found.");

        // Normalize: sum quantities by product, drop non-positive.
        var normalized = items
            .Where(i => i.ProductID > 0 && i.Quantity > 0)
            .GroupBy(i => i.ProductID)
            .Select(g => new { ProductID = g.Key, Quantity = g.Sum(x => x.Quantity) })
            .ToList();

        // Validate product existence
        var ids = normalized.Select(x => x.ProductID).ToList();
        var existingIds = await _context.Products.AsNoTracking().Where(p => ids.Contains(p.ProductID)).Select(p => p.ProductID).ToListAsync();
        var existingSet = existingIds.ToHashSet();
        normalized = normalized.Where(x => existingSet.Contains(x.ProductID)).ToList();

        await using var tx = await _context.Database.BeginTransactionAsync();
        try
        {
            var cart = await GetOrCreateCartAsync(userId);

            // Remove existing items
            if (cart.CartItems.Count > 0)
            {
                _context.CartItems.RemoveRange(cart.CartItems);
                await _context.SaveChangesAsync();
                cart.CartItems.Clear();
            }

            foreach (var x in normalized)
            {
                cart.CartItems.Add(new CartItem { CartID = cart.CartID, ProductID = x.ProductID, Quantity = x.Quantity });
            }
            cart.UpdatedAt = DateTime.Now;

            await _context.SaveChangesAsync();
            await tx.CommitAsync();

            // Return latest cart
            return await GetUserCart(userId);
        }
        catch
        {
            await tx.RollbackAsync();
            throw;
        }
    }
}

