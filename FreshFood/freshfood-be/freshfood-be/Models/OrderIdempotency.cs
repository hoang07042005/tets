using System.ComponentModel.DataAnnotations;

namespace freshfood_be.Models
{
    public class OrderIdempotency
    {
        [Key]
        public int OrderIdempotencyID { get; set; }

        [Required]
        [StringLength(120)]
        public string IdempotencyKey { get; set; } = string.Empty;

        [StringLength(64)]
        public string RequestHash { get; set; } = string.Empty;

        public int? UserID { get; set; }

        public int? OrderID { get; set; }

        public DateTime CreatedAtUtc { get; set; } = DateTime.UtcNow;

        public DateTime? CompletedAtUtc { get; set; }
    }
}

