using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace freshfood_be.Models;

[Table("ContactMessages")]
public class ContactMessage
{
    [Key]
    public int ContactMessageID { get; set; }

    [Required]
    [StringLength(200)]
    public string Name { get; set; } = string.Empty;

    [Required]
    [StringLength(320)]
    public string Email { get; set; } = string.Empty;

    [Required]
    [StringLength(300)]
    public string Subject { get; set; } = string.Empty;

    [Required]
    public string Message { get; set; } = string.Empty;

    /// <summary>New | Processing | Replied</summary>
    [StringLength(20)]
    public string Status { get; set; } = "New";

    public bool IsUrgent { get; set; }

    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
}
