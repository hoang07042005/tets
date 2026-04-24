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
    public class UsersController : ControllerBase
    {
        private readonly FreshFoodContext _context;

        public UsersController(FreshFoodContext context)
        {
            _context = context;
        }

        // GET: api/Users
        [Authorize(Roles = "Admin")]
        [HttpGet]
        public async Task<ActionResult<IEnumerable<User>>> GetUsers()
        {
            return await _context.Users.ToListAsync();
        }

        // GET: api/Users/5
        [Authorize]
        [HttpGet("{id}")]
        public async Task<ActionResult<User>> GetUser(int id)
        {
            var claimId = User?.FindFirstValue(ClaimTypes.NameIdentifier) ?? User?.FindFirstValue("sub");
            var role = (User?.FindFirstValue(ClaimTypes.Role) ?? "").Trim().ToLowerInvariant();
            var isAdmin = role == "admin";
            if (!isAdmin && (!int.TryParse(claimId, out var authId) || authId != id))
                return Forbid();

            var user = await _context.Users
                .Include(u => u.Orders)
                .Include(u => u.Cart)
                .FirstOrDefaultAsync(u => u.UserID == id);

            if (user == null)
            {
                return NotFound();
            }

            return user;
        }

        // POST: api/Users (Register)
        [Authorize(Roles = "Admin")]
        [HttpPost]
        public async Task<ActionResult<User>> PostUser(User user)
        {
            // Simple logic: check if email exists
            if (await _context.Users.AnyAsync(u => u.Email == user.Email))
            {
                return BadRequest("Email already exists.");
            }

            _context.Users.Add(user);
            await _context.SaveChangesAsync();

            // Create an empty cart for the new user
            var cart = new Cart { UserID = user.UserID };
            _context.Carts.Add(cart);
            await _context.SaveChangesAsync();

            return CreatedAtAction("GetUser", new { id = user.UserID }, user);
        }
    }
}
