using System.ComponentModel.DataAnnotations;
using System.Text.Json.Serialization;

namespace freshfood_be.Models
{
    public class User
    {
        [Key]
        public int UserID { get; set; }

        [Required]
        [StringLength(100)]
        public string FullName { get; set; } = string.Empty;

        [Required]
        [StringLength(100)]
        [EmailAddress]
        public string Email { get; set; } = string.Empty;

        [Required]
        [JsonIgnore]
        public string PasswordHash { get; set; } = string.Empty;

        [StringLength(1000)]
        public string? AvatarUrl { get; set; }

        [StringLength(20)]
        public string? Phone { get; set; }

        [StringLength(500)]
        public string? Address { get; set; }

        [StringLength(20)]
        public string Role { get; set; } = "Customer";

        /// <summary>Khi true: không cho đăng nhập (khóa tài khoản).</summary>
        public bool IsLocked { get; set; }

        /// <summary>Tài khoản tạo từ đặt hàng khách (chưa đặt mật khẩu đăng nhập). Dùng Quên mật khẩu để hoàn tất tài khoản.</summary>
        public bool IsGuestAccount { get; set; }

        public DateTime CreatedAt { get; set; } = DateTime.Now;

        [JsonIgnore]
        public ICollection<Order> Orders { get; set; } = new List<Order>();
        [JsonIgnore]
        public ICollection<Review> Reviews { get; set; } = new List<Review>();
        [JsonIgnore]
        public Cart? Cart { get; set; }
        [JsonIgnore]
        public ICollection<Wishlist> Wishlists { get; set; } = new List<Wishlist>();
        [JsonIgnore]
        public ICollection<UserAddress> UserAddresses { get; set; } = new List<UserAddress>();
    }
}
