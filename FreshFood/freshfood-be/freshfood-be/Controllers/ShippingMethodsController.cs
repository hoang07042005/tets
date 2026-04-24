using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using freshfood_be.Data;

namespace freshfood_be.Controllers;

[Route("api/[controller]")]
[ApiController]
public class ShippingMethodsController : ControllerBase
{
    private readonly FreshFoodContext _context;

    public ShippingMethodsController(FreshFoodContext context)
    {
        _context = context;
    }

    public record ShippingMethodDto(int MethodID, string MethodName, decimal BaseCost, int? EstimatedDays);

    [HttpGet]
    public async Task<ActionResult<IEnumerable<ShippingMethodDto>>> GetAll()
    {
        var items = await _context.ShippingMethods
            .AsNoTracking()
            .OrderBy(sm => sm.BaseCost)
            .ThenBy(sm => sm.MethodID)
            .Select(sm => new ShippingMethodDto(sm.MethodID, sm.MethodName, sm.BaseCost, sm.EstimatedDays))
            .ToListAsync();

        return Ok(items);
    }
}

