using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace freshfood_be.Models
{
    [Table("PasswordResetTokens")]
    public class PasswordResetToken
    {
        [Key]
        public int PasswordResetTokenID { get; set; }

        public int UserID { get; set; }
        [ForeignKey("UserID")]
        public User? User { get; set; }

        [Required]
        [StringLength(128)]
        public string TokenHash { get; set; } = string.Empty;

        public DateTime ExpiresAt { get; set; }
        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
        public DateTime? UsedAt { get; set; }

        [StringLength(64)]
        public string? Purpose { get; set; } = "reset_password";
    }
}

