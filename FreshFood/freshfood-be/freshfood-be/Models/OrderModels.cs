using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace freshfood_be.Models
{
    public class Order
    {
        [Key]
        public int OrderID { get; set; }

        [NotMapped]
        public string? OrderToken { get; set; }

        [StringLength(30)]
        public string? OrderCode { get; set; }

        public int UserID { get; set; }
        [ForeignKey("UserID")]
        public User? User { get; set; }

        public DateTime OrderDate { get; set; } = DateTime.Now;

        [Column(TypeName = "decimal(18, 2)")]
        public decimal TotalAmount { get; set; }

        [Required]
        [StringLength(500)]
        public string ShippingAddress { get; set; } = string.Empty;

        public int? ShippingMethodID { get; set; }
        [ForeignKey("ShippingMethodID")]
        public ShippingMethod? ShippingMethod { get; set; }

        public int? VoucherID { get; set; }
        [ForeignKey("VoucherID")]
        public Voucher? Voucher { get; set; }

        [StringLength(50)]
        public string Status { get; set; } = "Pending";

        public ICollection<OrderDetail> OrderDetails { get; set; } = new List<OrderDetail>();
        public ICollection<Shipment> Shipments { get; set; } = new List<Shipment>();
        public ICollection<Payment> Payments { get; set; } = new List<Payment>();
    }

    public class OrderDetail
    {
        [Key]
        public int OrderDetailID { get; set; }

        public int OrderID { get; set; }
        [ForeignKey("OrderID")]
        public Order? Order { get; set; }

        public int ProductID { get; set; }
        [ForeignKey("ProductID")]
        public Product? Product { get; set; }

        public int Quantity { get; set; }

        [Column(TypeName = "decimal(18, 2)")]
        public decimal UnitPrice { get; set; }
    }
}
