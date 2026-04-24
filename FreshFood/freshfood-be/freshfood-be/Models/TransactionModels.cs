using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace freshfood_be.Models
{
    public class ShippingMethod
    {
        [Key]
        public int MethodID { get; set; }

        [Required]
        [StringLength(100)]
        public string MethodName { get; set; } = string.Empty;

        [Column(TypeName = "decimal(18, 2)")]
        public decimal BaseCost { get; set; }

        public int? EstimatedDays { get; set; }
    }

    public class Voucher
    {
        [Key]
        public int VoucherID { get; set; }

        [Required]
        [StringLength(50)]
        public string Code { get; set; } = string.Empty;

        [StringLength(20)]
        public string? DiscountType { get; set; }

        [Column(TypeName = "decimal(18, 2)")]
        public decimal DiscountValue { get; set; }

        [Column(TypeName = "decimal(18, 2)")]
        public decimal MinOrderAmount { get; set; }

        public DateTime? ExpiryDate { get; set; }

        public bool IsActive { get; set; } = true;
    }

    public class Shipment
    {
        [Key]
        public int ShipmentID { get; set; }

        public int OrderID { get; set; }
        [ForeignKey("OrderID")]
        public Order? Order { get; set; }

        [StringLength(100)]
        public string? TrackingNumber { get; set; }

        [StringLength(100)]
        public string? Carrier { get; set; }

        public DateTime? ShippedDate { get; set; }
        public DateTime? EstimatedDeliveryDate { get; set; }
        public DateTime? ActualDeliveryDate { get; set; }

        [StringLength(50)]
        public string? Status { get; set; }
    }

    public class Payment
    {
        [Key]
        public int PaymentID { get; set; }

        public int OrderID { get; set; }
        [ForeignKey("OrderID")]
        public Order? Order { get; set; }

        public DateTime PaymentDate { get; set; } = DateTime.Now;

        [StringLength(50)]
        public string? PaymentMethod { get; set; }

        [Column(TypeName = "decimal(18, 2)")]
        public decimal Amount { get; set; }

        [StringLength(50)]
        public string? Status { get; set; }
    }
}
