using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using freshfood_be.Data;

namespace freshfood_be.Controllers
{
    [Route("api/[controller]")]
    [Authorize(Roles = "Admin")]
    [ApiController]
    public class AdminController : ControllerBase
    {
        private readonly FreshFoodContext _context;

        public AdminController(FreshFoodContext context)
        {
            _context = context;
        }

        public record DashboardKpiDto(string Key, string Label, decimal Value, string? Unit, decimal DeltaPercent);

        public record RevenuePointDto(string Label, decimal Value);

        public record RecentOrderDto(
            int OrderID,
            string OrderCode,
            string CustomerName,
            decimal TotalAmount,
            string Status,
            string? ThumbUrl
        );

        public record DashboardDto(
            string Range,
            IReadOnlyList<DashboardKpiDto> Kpis,
            IReadOnlyList<RevenuePointDto> RevenueSeries,
            IReadOnlyList<RecentOrderDto> RecentOrders
        );

        public record LowStockProductDto(
            int ProductID,
            string ProductName,
            int StockQuantity,
            string? Unit,
            decimal Price,
            decimal? DiscountPrice,
            string? ThumbUrl
        );

        public record RecentImportDto(
            int LogID,
            int ProductID,
            string ProductName,
            int ImportedQuantity,
            int StockQuantity,
            string? Unit,
            DateTime LogDate,
            string? Note,
            string? ThumbUrl
        );

        [HttpGet("dashboard")]
        public async Task<ActionResult<DashboardDto>> Dashboard([FromQuery] string range = "week")
        {
            var r = (range ?? "week").Trim().ToLowerInvariant();
            var now = DateTime.UtcNow;

            // Use UTC boundaries for consistency.
            DateTime start;
            DateTime prevStart;
            int points;

            if (r == "month")
            {
                // last 30 days, grouped by week (4 points)
                start = now.Date.AddDays(-29);
                prevStart = start.AddDays(-30);
                points = 4;
            }
            else
            {
                r = "week";
                // last 7 days (7 points)
                start = now.Date.AddDays(-6);
                prevStart = start.AddDays(-7);
                points = 7;
            }

            // Revenue should be based on payment success (not fulfillment status).
            // This matches AdminOrdersController stats and avoids missing "success"/VNPAY flows.
            var paymentsInRange = _context.Payments.AsNoTracking().Where(p => p.PaymentDate >= start);
            var paymentsPrevRange = _context.Payments.AsNoTracking().Where(p => p.PaymentDate >= prevStart && p.PaymentDate < start);

            var revenueNow = await paymentsInRange
                .Where(p => p.Status != null && (p.Status.ToLower() == "paid" || p.Status.ToLower() == "success"))
                .SumAsync(p => (decimal?)p.Amount) ?? 0m;

            var revenuePrev = await paymentsPrevRange
                .Where(p => p.Status != null && (p.Status.ToLower() == "paid" || p.Status.ToLower() == "success"))
                .SumAsync(p => (decimal?)p.Amount) ?? 0m;

            var ordersInRange = _context.Orders.AsNoTracking().Where(o => o.OrderDate >= start);
            var ordersPrevRange = _context.Orders.AsNoTracking().Where(o => o.OrderDate >= prevStart && o.OrderDate < start);

            var ordersCountNow = await ordersInRange.CountAsync();
            var ordersCountPrev = await ordersPrevRange.CountAsync();

            var newCustomersNow = await _context.Users.AsNoTracking().Where(u => u.CreatedAt >= start).CountAsync();
            var newCustomersPrev = await _context.Users.AsNoTracking().Where(u => u.CreatedAt >= prevStart && u.CreatedAt < start).CountAsync();

            var stockSum = await _context.Products.AsNoTracking().SumAsync(p => (int?)p.StockQuantity) ?? 0;

            static decimal DeltaPct(decimal nowVal, decimal prevVal)
            {
                if (prevVal == 0) return nowVal == 0 ? 0 : 100;
                return Math.Round((nowVal - prevVal) * 100m / prevVal, 1, MidpointRounding.AwayFromZero);
            }

            static decimal DeltaPctInt(int nowVal, int prevVal)
            {
                if (prevVal == 0) return nowVal == 0 ? 0 : 100;
                return Math.Round((nowVal - prevVal) * 100m / prevVal, 1, MidpointRounding.AwayFromZero);
            }

            var kpis = new List<DashboardKpiDto>
            {
                new("revenue", "Tổng doanh thu", revenueNow, "VND", DeltaPct(revenueNow, revenuePrev)),
                new("orders", "Tổng đơn hàng", ordersCountNow, null, DeltaPctInt(ordersCountNow, ordersCountPrev)),
                new("newCustomers", "Khách hàng mới", newCustomersNow, null, DeltaPctInt(newCustomersNow, newCustomersPrev)),
                new("stock", "Sản phẩm tồn kho", stockSum, null, 0),
            };

            // Revenue series
            List<RevenuePointDto> series = new();
            if (r == "week")
            {
                // 7 days labels: T2..CN in Vietnamese
                var baseDate = start.Date;
                var map = await paymentsInRange
                    .Where(p => p.Status != null && (p.Status.ToLower() == "paid" || p.Status.ToLower() == "success"))
                    .GroupBy(p => p.PaymentDate.Date)
                    .Select(g => new { Day = g.Key, Sum = g.Sum(x => x.Amount) })
                    .ToListAsync();

                decimal SumFor(DateTime d) => map.FirstOrDefault(x => x.Day == d)?.Sum ?? 0m;

                for (var i = 0; i < points; i++)
                {
                    var d = baseDate.AddDays(i);
                    var label = d.ToString("ddd", System.Globalization.CultureInfo.GetCultureInfo("vi-VN"))
                        .Replace("Th 2", "T2")
                        .Replace("Th 3", "T3")
                        .Replace("Th 4", "T4")
                        .Replace("Th 5", "T5")
                        .Replace("Th 6", "T6")
                        .Replace("Th 7", "T7")
                        .Replace("CN", "CN");
                    series.Add(new RevenuePointDto(label, SumFor(d)));
                }
            }
            else
            {
                // 4 weeks (7-day buckets)
                for (var i = 0; i < points; i++)
                {
                    var bucketStart = start.Date.AddDays(i * 7);
                    var bucketEnd = bucketStart.AddDays(7);
                    var sum = await _context.Payments.AsNoTracking()
                        .Where(p => p.PaymentDate >= bucketStart && p.PaymentDate < bucketEnd)
                        .Where(p => p.Status != null && (p.Status.ToLower() == "paid" || p.Status.ToLower() == "success"))
                        .SumAsync(p => (decimal?)p.Amount) ?? 0m;

                    series.Add(new RevenuePointDto($"Tu{i + 1}", sum));
                }
            }

            // Recent orders (top 6)
            var recent = await _context.Orders
                .AsNoTracking()
                .Include(o => o.User)
                .Include(o => o.OrderDetails)
                    .ThenInclude(od => od.Product!)
                    .ThenInclude(p => p.ProductImages)
                .OrderByDescending(o => o.OrderDate)
                .Take(6)
                .Select(o => new RecentOrderDto(
                    o.OrderID,
                    o.OrderCode ?? $"#{o.OrderID}",
                    o.User != null ? o.User.FullName : $"User {o.UserID}",
                    o.TotalAmount,
                    o.Status,
                    o.OrderDetails
                        .OrderByDescending(d => d.Quantity)
                        .Select(d => d.Product!.ProductImages.Where(pi => pi.IsMainImage).Select(pi => pi.ImageURL).FirstOrDefault()
                            ?? d.Product!.ProductImages.Select(pi => pi.ImageURL).FirstOrDefault())
                        .FirstOrDefault()
                ))
                .ToListAsync();

            return Ok(new DashboardDto(r, kpis, series, recent));
        }

        [HttpGet("low-stock")]
        public async Task<ActionResult<IReadOnlyList<LowStockProductDto>>> LowStock([FromQuery] int threshold = 10, [FromQuery] int take = 12)
        {
            threshold = Math.Max(0, threshold);
            take = Math.Clamp(take, 1, 100);

            var rows = await _context.Products
                .AsNoTracking()
                .Include(p => p.ProductImages)
                .Where(p => p.StockQuantity <= threshold)
                .OrderBy(p => p.StockQuantity)
                .ThenBy(p => p.ProductName)
                .Take(take)
                .Select(p => new LowStockProductDto(
                    p.ProductID,
                    p.ProductName,
                    p.StockQuantity,
                    p.Unit,
                    p.Price,
                    p.DiscountPrice,
                    p.ProductImages.Where(pi => pi.IsMainImage).Select(pi => pi.ImageURL).FirstOrDefault()
                        ?? p.ProductImages.Select(pi => pi.ImageURL).FirstOrDefault()
                ))
                .ToListAsync();

            return Ok(rows);
        }

        // GET: api/Admin/inventory/recent-imports?take=6
        [HttpGet("inventory/recent-imports")]
        public async Task<ActionResult<IReadOnlyList<RecentImportDto>>> RecentImports([FromQuery] int take = 6)
        {
            take = Math.Clamp(take, 1, 50);

            var rows = await _context.InventoryHistories
                .AsNoTracking()
                .Include(h => h.Product!)
                    .ThenInclude(p => p.ProductImages)
                .Where(h => h.ChangeQuantity > 0 && (h.ChangeType ?? "") == "Import")
                .OrderByDescending(h => h.LogDate)
                .Take(take)
                .Select(h => new RecentImportDto(
                    h.LogID,
                    h.ProductID,
                    h.Product != null ? h.Product.ProductName : $"Sản phẩm #{h.ProductID}",
                    h.ChangeQuantity,
                    h.Product != null ? h.Product.StockQuantity : 0,
                    h.Product != null ? h.Product.Unit : null,
                    h.LogDate,
                    h.Note,
                    h.Product != null
                        ? (h.Product.ProductImages.Where(pi => pi.IsMainImage).Select(pi => pi.ImageURL).FirstOrDefault()
                            ?? h.Product.ProductImages.Select(pi => pi.ImageURL).FirstOrDefault())
                        : null
                ))
                .ToListAsync();

            return Ok(rows);
        }
    }
}

