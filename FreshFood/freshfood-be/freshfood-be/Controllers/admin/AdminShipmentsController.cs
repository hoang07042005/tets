using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using freshfood_be.Data;
using freshfood_be.Models;

namespace freshfood_be.Controllers;

/// <summary>Admin Shipments — api/Admin/Shipments</summary>
[Authorize(Roles = "Admin")]
[Route("api/Admin/Shipments")]
[ApiController]
public class AdminShipmentsController : ControllerBase
{
    private readonly FreshFoodContext _context;

    public AdminShipmentsController(FreshFoodContext context)
    {
        _context = context;
    }

    public record UpdateShipmentStatusDto(string Status);

    public record UpdateShipmentDetailsDto(string? TrackingNumber, string? Carrier);

    private static string NormalizeShipmentStatus(string? status)
    {
        var s = (status ?? "").Trim();
        if (string.IsNullOrWhiteSpace(s)) return "Pending";
        return s;
    }

    private static string NormalizeOrderStatus(string? status)
    {
        var s = (status ?? "").Trim();
        if (string.IsNullOrWhiteSpace(s)) return "Pending";
        return s;
    }

    private static int OrderStatusRank(string? status)
    {
        var s = (status ?? "").Trim().ToLowerInvariant();
        return s switch
        {
            "pending" => 0,
            "processing" => 1,
            "preparing" or "preparing_goods" or "packing" => 2,
            "shipping" or "intransit" or "in_transit" => 3,
            "delivered" => 4,
            "completed" => 5,
            _ => 0
        };
    }

    private static string CanonicalShipmentStatus(string? status)
    {
        var s = (status ?? "").Trim().ToLowerInvariant();
        return s switch
        {
            "pending" => "Pending",
            "shipping" or "intransit" or "in_transit" => "Shipping",
            "delivered" => "Delivered",
            _ => NormalizeShipmentStatus(status)
        };
    }

    /// <summary>
    /// Cập nhật trạng thái giao hàng và đồng bộ Order.Status theo shipment.
    /// </summary>
    [HttpPut("{shipmentId:int}/status")]
    public async Task<IActionResult> UpdateStatus(int shipmentId, [FromBody] UpdateShipmentStatusDto input)
    {
        if (input == null) return BadRequest("Thiếu dữ liệu.");

        var shipment = await _context.Shipments
            .Include(s => s.Order)
            .FirstOrDefaultAsync(s => s.ShipmentID == shipmentId);

        if (shipment == null) return NotFound();

        var next = CanonicalShipmentStatus(input.Status);
        shipment.Status = next;

        // Keep dates consistent.
        var ns = next.Trim().ToLowerInvariant();
        if (ns == "shipping")
        {
            if (shipment.ShippedDate == null) shipment.ShippedDate = DateTime.Now;
        }
        if (ns == "delivered")
        {
            if (shipment.ActualDeliveryDate == null) shipment.ActualDeliveryDate = DateTime.Now;
            if (shipment.ShippedDate == null) shipment.ShippedDate = shipment.ActualDeliveryDate;
        }

        // Sync Order.Status upwards based on shipment status.
        if (shipment.Order != null)
        {
            var cur = NormalizeOrderStatus(shipment.Order.Status);
            var curRank = OrderStatusRank(cur);

            if (ns == "shipping")
            {
                var targetRank = OrderStatusRank("shipping");
                if (curRank < targetRank) shipment.Order.Status = "Shipping";
            }
            else if (ns == "delivered")
            {
                var targetRank = OrderStatusRank("delivered");
                // Do not downgrade Completed -> Delivered
                if (curRank < targetRank) shipment.Order.Status = "Delivered";
            }
        }

        await _context.SaveChangesAsync();
        return NoContent();
    }

    /// <summary>Cập nhật mã vận đơn và đơn vị vận chuyển (GHN, GHTK, …).</summary>
    [HttpPut("{shipmentId:int}/details")]
    public async Task<IActionResult> UpdateDetails(int shipmentId, [FromBody] UpdateShipmentDetailsDto? input)
    {
        if (input == null) return BadRequest("Thiếu dữ liệu.");

        var shipment = await _context.Shipments.FirstOrDefaultAsync(s => s.ShipmentID == shipmentId);
        if (shipment == null) return NotFound();

        var tn = (input.TrackingNumber ?? "").Trim();
        var cr = (input.Carrier ?? "").Trim();
        shipment.TrackingNumber = string.IsNullOrEmpty(tn) ? null : tn[..Math.Min(tn.Length, 100)];
        shipment.Carrier = string.IsNullOrEmpty(cr) ? null : cr[..Math.Min(cr.Length, 100)];

        await _context.SaveChangesAsync();
        return NoContent();
    }
}

