using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace freshfood_be.Models
{
    public class Product
    {
        [Key]
        public int ProductID { get; set; }

        [NotMapped]
        public string? ProductToken { get; set; }

        [Required]
        [StringLength(200)]
        public string ProductName { get; set; } = string.Empty;

        [StringLength(50)]
        public string? Sku { get; set; }

        public int? CategoryID { get; set; }
        [ForeignKey("CategoryID")]
        public Category? Category { get; set; }

        public int? SupplierID { get; set; }
        [ForeignKey("SupplierID")]
        public Supplier? Supplier { get; set; }

        [Column(TypeName = "decimal(18, 2)")]
        public decimal Price { get; set; }

        [Column(TypeName = "decimal(18, 2)")]
        public decimal? DiscountPrice { get; set; }

        public int StockQuantity { get; set; }

        [StringLength(50)]
        public string? Unit { get; set; }

        public string? Description { get; set; }

        /// <summary>Ngày sản xuất / thu hoạch (NSX).</summary>
        public DateTime? ManufacturedDate { get; set; }

        /// <summary>Hạn sử dụng (HSD).</summary>
        public DateTime? ExpiryDate { get; set; }

        [StringLength(500)]
        public string? Origin { get; set; }

        [StringLength(2000)]
        public string? StorageInstructions { get; set; }

        /// <summary>Chứng nhận (Organic, VietGAP, …) — gợi ý nhập ngăn cách dấu phẩy.</summary>
        [StringLength(500)]
        public string? Certifications { get; set; }

        /// <summary>Trạng thái hiển thị: Active | Inactive.</summary>
        [StringLength(20)]
        public string Status { get; set; } = "Active";

        public DateTime CreatedAt { get; set; } = DateTime.Now;

        public ICollection<ProductImage> ProductImages { get; set; } = new List<ProductImage>();
        public ICollection<Review> Reviews { get; set; } = new List<Review>();
        public ICollection<OrderDetail> OrderDetails { get; set; } = new List<OrderDetail>();
        public ICollection<CartItem> CartItems { get; set; } = new List<CartItem>();
        public ICollection<InventoryHistory> InventoryHistories { get; set; } = new List<InventoryHistory>();
        public ICollection<Wishlist> Wishlists { get; set; } = new List<Wishlist>();
    }
}
