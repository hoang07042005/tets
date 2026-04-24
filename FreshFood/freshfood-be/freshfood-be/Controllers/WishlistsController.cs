using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using freshfood_be.Data;
using freshfood_be.Models;

namespace freshfood_be.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    public class WishlistsController : ControllerBase
    {
        private readonly FreshFoodContext _context;

        public WishlistsController(FreshFoodContext context)
        {
            _context = context;
        }

        public record ToggleWishlistRequest(int UserID, int ProductID);

        private int? GetAuthUserId()
        {
            var v = User?.FindFirstValue(ClaimTypes.NameIdentifier) ?? User?.FindFirstValue("sub");
            return int.TryParse(v, out var id) && id > 0 ? id : null;
        }

        private bool IsOwner(int userId) => GetAuthUserId() == userId;

        // GET: api/Wishlists/User/5
        [Authorize]
        [HttpGet("User/{userId}")]
        public async Task<ActionResult<IEnumerable<Wishlist>>> GetUserWishlist(int userId)
        {
            if (!IsOwner(userId)) return Forbid();
            return await _context.Wishlists
                .Where(w => w.UserID == userId)
                .OrderByDescending(w => w.AddedDate)
                .Include(w => w.Product!)
                .ThenInclude(p => p.ProductImages)
                .Include(w => w.Product!)
                .ThenInclude(p => p.Category)
                .ToListAsync();
        }

        // GET: api/Wishlists/Ids/5  -> [1,2,3]
        [Authorize]
        [HttpGet("Ids/{userId}")]
        public async Task<ActionResult<IEnumerable<int>>> GetUserWishlistIds(int userId)
        {
            if (!IsOwner(userId)) return Forbid();
            var ids = await _context.Wishlists
                .Where(w => w.UserID == userId)
                .Select(w => w.ProductID)
                .ToListAsync();
            return Ok(ids);
        }

        // POST: api/Wishlists/Toggle
        [Authorize]
        [HttpPost("Toggle")]
        public async Task<ActionResult> ToggleWishlist([FromBody] ToggleWishlistRequest req)
        {
            if (req.UserID <= 0 || req.ProductID <= 0) return BadRequest("Invalid data.");
            if (!IsOwner(req.UserID)) return Forbid();

            var userExists = await _context.Users.AnyAsync(u => u.UserID == req.UserID);
            if (!userExists) return BadRequest("User not found.");

            var productExists = await _context.Products.AnyAsync(p => p.ProductID == req.ProductID);
            if (!productExists) return BadRequest("Product not found.");

            var existing = await _context.Wishlists
                .FirstOrDefaultAsync(w => w.UserID == req.UserID && w.ProductID == req.ProductID);

            if (existing != null)
            {
                _context.Wishlists.Remove(existing);
                await _context.SaveChangesAsync();
                return Ok(new { wished = false });
            }

            _context.Wishlists.Add(new Wishlist
            {
                UserID = req.UserID,
                ProductID = req.ProductID,
                AddedDate = DateTime.Now
            });
            await _context.SaveChangesAsync();

            return Ok(new { wished = true });
        }
    }
}

