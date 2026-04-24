using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace freshfood_be.Models;

public class ReturnRequest
{
    [Key]
    public int ReturnRequestID { get; set; }

    public int OrderID { get; set; }
    [ForeignKey("OrderID")]
    public Order? Order { get; set; }

    public int UserID { get; set; }
    [ForeignKey("UserID")]
    public User? User { get; set; }

    [Required]
    [StringLength(30)]
    public string Status { get; set; } = "Pending"; // Pending, Approved, Rejected

    /// <summary>
    /// Loại yêu cầu: Return (hoàn hàng) | CancelRefund (hoàn tiền do hủy đơn).
    /// </summary>
    [Required]
    [StringLength(30)]
    public string RequestType { get; set; } = "Return";

    [Required]
    [StringLength(2000)]
    public string Reason { get; set; } = string.Empty;

    [StringLength(2000)]
    public string? AdminNote { get; set; }

    [StringLength(1000)]
    public string? VideoUrl { get; set; }

    [StringLength(1000)]
    public string? RefundProofUrl { get; set; }

    [StringLength(2000)]
    public string? RefundNote { get; set; }

    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    public DateTime? ReviewedAt { get; set; }

    public ICollection<ReturnRequestImage> Images { get; set; } = new List<ReturnRequestImage>();
}

public class ReturnRequestImage
{
    [Key]
    public int ReturnRequestImageID { get; set; }

    public int ReturnRequestID { get; set; }
    [ForeignKey("ReturnRequestID")]
    public ReturnRequest? ReturnRequest { get; set; }

    [Required]
    [StringLength(1000)]
    public string ImageUrl { get; set; } = string.Empty;
}

