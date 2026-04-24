using System.ComponentModel.DataAnnotations;

namespace freshfood_be.Models
{
    public class Supplier
    {
        [Key]
        public int SupplierID { get; set; }

        [Required]
        [StringLength(200)]
        public string SupplierName { get; set; } = string.Empty;

        [StringLength(100)]
        public string? ContactName { get; set; }

        [StringLength(20)]
        public string? Phone { get; set; }

        [StringLength(100)]
        public string? Email { get; set; }

        [StringLength(500)]
        public string? Address { get; set; }

        [StringLength(50)]
        public string? SupplierCode { get; set; }

        [StringLength(1000)]
        public string? ImageUrl { get; set; }

        /// <summary>Active | Paused | Pending</summary>
        [StringLength(20)]
        public string Status { get; set; } = "Active";

        public bool IsVerified { get; set; }

        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

        public ICollection<Product> Products { get; set; } = new List<Product>();
    }
}
