using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace freshfood_be.Models
{
    public class Cart
    {
        [Key]
        public int CartID { get; set; }

        public int? UserID { get; set; }
        [ForeignKey("UserID")]
        public User? User { get; set; }

        public DateTime CreatedAt { get; set; } = DateTime.Now;
        public DateTime UpdatedAt { get; set; } = DateTime.Now;

        public ICollection<CartItem> CartItems { get; set; } = new List<CartItem>();
    }

    public class CartItem
    {
        [Key]
        public int CartItemID { get; set; }

        public int CartID { get; set; }
        [ForeignKey("CartID")]
        public Cart? Cart { get; set; }

        public int ProductID { get; set; }
        [ForeignKey("ProductID")]
        public Product? Product { get; set; }

        public int Quantity { get; set; } = 1;
    }
}
