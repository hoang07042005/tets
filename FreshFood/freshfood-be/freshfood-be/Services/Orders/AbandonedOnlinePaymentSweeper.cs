using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;
using freshfood_be.Data;

namespace freshfood_be.Services.Orders;

/// <summary>
/// Auto-release reserved inventory for abandoned online payments.
/// Orders currently decrement StockQuantity at creation time, so we must restock if payment is not completed in time.
/// </summary>
public sealed class AbandonedOnlinePaymentSweeper : BackgroundService
{
    private static readonly string[] OnlineMethods = { "MOMO", "VNPAY" };

    private readonly IServiceScopeFactory _scopeFactory;
    private readonly ILogger<AbandonedOnlinePaymentSweeper> _logger;
    private readonly InventoryReservationOptions _opt;

    public AbandonedOnlinePaymentSweeper(
        IServiceScopeFactory scopeFactory,
        IOptions<InventoryReservationOptions> opt,
        ILogger<AbandonedOnlinePaymentSweeper> logger)
    {
        _scopeFactory = scopeFactory;
        _logger = logger;
        _opt = opt.Value ?? new InventoryReservationOptions();
    }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        var intervalMin = Math.Clamp(_opt.SweepIntervalMinutes, 1, 60);

        while (!stoppingToken.IsCancellationRequested)
        {
            try
            {
                if (_opt.Enabled)
                    await SweepOnceAsync(stoppingToken);
            }
            catch (Exception ex)
            {
                _logger.LogWarning(ex, "AbandonedOnlinePaymentSweeper failed.");
            }

            try
            {
                await Task.Delay(TimeSpan.FromMinutes(intervalMin), stoppingToken);
            }
            catch (TaskCanceledException)
            {
                // shutting down
            }
        }
    }

    private async Task SweepOnceAsync(CancellationToken ct)
    {
        var timeoutMin = Math.Clamp(_opt.TimeoutMinutes, 5, 24 * 60);
        var cutoff = DateTime.UtcNow.AddMinutes(-timeoutMin);

        await using var scope = _scopeFactory.CreateAsyncScope();
        var db = scope.ServiceProvider.GetRequiredService<FreshFoodContext>();

        // Candidate orders:
        // - Order.Status == Pending (created, awaiting online payment)
        // - Has a pending payment for MOMO/VNPAY older than cutoff
        // - No paid/success payment exists
        var candidates = await db.Orders
            .Include(o => o.Payments)
            .Include(o => o.OrderDetails)
            .Where(o => o.Status != null && o.Status.ToLower() == "pending")
            .Where(o => o.Payments.Any(p =>
                p.PaymentMethod != null &&
                OnlineMethods.Contains(p.PaymentMethod.ToUpper()) &&
                p.Status != null &&
                p.Status.ToLower() == "pending" &&
                p.PaymentDate <= cutoff))
            .Where(o => !o.Payments.Any(p => p.Status != null && (p.Status.ToLower() == "paid" || p.Status.ToLower() == "success")))
            .Take(50)
            .ToListAsync(ct);

        if (candidates.Count == 0) return;

        var changed = 0;
        foreach (var order in candidates)
        {
            var st = (order.Status ?? "").Trim().ToLowerInvariant();
            if (st is "failed" or "cancelled" or "canceled") continue;

            await using var tx = await db.Database.BeginTransactionAsync(ct);
            try
            {
                // Re-read within transaction to avoid double-processing.
                var o2 = await db.Orders
                    .Include(x => x.Payments)
                    .Include(x => x.OrderDetails)
                    .FirstOrDefaultAsync(x => x.OrderID == order.OrderID, ct);

                if (o2 == null)
                {
                    await tx.RollbackAsync(ct);
                    continue;
                }

                var st2 = (o2.Status ?? "").Trim().ToLowerInvariant();
                if (st2 is "failed" or "cancelled" or "canceled")
                {
                    await tx.RollbackAsync(ct);
                    continue;
                }

                var hasPaid = o2.Payments.Any(p => (p.Status ?? "").Trim().ToLowerInvariant() is "paid" or "success");
                if (hasPaid)
                {
                    await tx.RollbackAsync(ct);
                    continue;
                }

                var hasExpiredPending = o2.Payments.Any(p =>
                    OnlineMethods.Contains((p.PaymentMethod ?? "").Trim().ToUpperInvariant()) &&
                    (p.Status ?? "").Trim().ToLowerInvariant() == "pending" &&
                    p.PaymentDate.ToUniversalTime() <= cutoff);
                if (!hasExpiredPending)
                {
                    await tx.RollbackAsync(ct);
                    continue;
                }

                o2.Status = "Failed";

                // Restock
                foreach (var d in o2.OrderDetails ?? new List<freshfood_be.Models.OrderDetail>())
                {
                    if (d.ProductID <= 0 || d.Quantity <= 0) continue;
                    var product = await db.Products.FirstOrDefaultAsync(p => p.ProductID == d.ProductID, ct);
                    if (product == null) continue;
                    product.StockQuantity += d.Quantity;
                }

                // Mark pending online payments as Failed (best effort)
                foreach (var p in o2.Payments)
                {
                    var method = (p.PaymentMethod ?? "").Trim().ToUpperInvariant();
                    var ps = (p.Status ?? "").Trim().ToLowerInvariant();
                    if (OnlineMethods.Contains(method) && ps == "pending")
                    {
                        p.Status = "Failed";
                        p.PaymentDate = DateTime.Now;
                    }
                }

                await db.SaveChangesAsync(ct);
                await tx.CommitAsync(ct);
                changed++;
            }
            catch (Exception ex)
            {
                await tx.RollbackAsync(ct);
                _logger.LogWarning(ex, "Failed to auto-release OrderID={OrderId}", order.OrderID);
            }
        }

        if (changed > 0)
            _logger.LogInformation("Auto-released {Count} abandoned online orders.", changed);
    }
}

