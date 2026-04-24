using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using System.Text.Json.Serialization;

namespace freshfood_be.Models;

[Table("UserAddresses")]
public class UserAddress
{
    [Key]
    public int UserAddressID { get; set; }

    public int UserID { get; set; }
    [ForeignKey("UserID")]
    [JsonIgnore]
    public User? User { get; set; }

    [StringLength(60)]
    public string? Label { get; set; }

    [Required]
    [StringLength(100)]
    public string RecipientName { get; set; } = string.Empty;

    [StringLength(20)]
    public string? Phone { get; set; }

    [Required]
    [StringLength(500)]
    public string AddressLine { get; set; } = string.Empty;

    public bool IsDefault { get; set; }

    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
}
