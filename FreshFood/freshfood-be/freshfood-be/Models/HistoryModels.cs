using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace freshfood_be.Models
{
    [Table("InventoryHistory")]
    public class InventoryHistory
    {
        [Key]
        public int LogID { get; set; }

        public int ProductID { get; set; }
        [ForeignKey("ProductID")]
        public Product? Product { get; set; }

        public int ChangeQuantity { get; set; }

        [StringLength(50)]
        public string? ChangeType { get; set; }

        public DateTime LogDate { get; set; } = DateTime.Now;

        [StringLength(500)]
        public string? Note { get; set; }
    }

    public class Wishlist
    {
        [Key]
        public int WishlistID { get; set; }

        public int UserID { get; set; }
        [ForeignKey("UserID")]
        public User? User { get; set; }

        public int ProductID { get; set; }
        [ForeignKey("ProductID")]
        public Product? Product { get; set; }

        public DateTime AddedDate { get; set; } = DateTime.Now;
    }
}
