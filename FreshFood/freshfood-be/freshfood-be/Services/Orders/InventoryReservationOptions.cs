namespace freshfood_be.Services.Orders;

public sealed class InventoryReservationOptions
{
    public bool Enabled { get; set; } = true;
    public int TimeoutMinutes { get; set; } = 30;
    public int SweepIntervalMinutes { get; set; } = 5;
}

