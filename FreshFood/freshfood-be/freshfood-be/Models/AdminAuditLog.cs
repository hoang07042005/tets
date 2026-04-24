using System.ComponentModel.DataAnnotations;

namespace freshfood_be.Models;

public sealed class AdminAuditLog
{
    [Key]
    public long AdminAuditLogID { get; set; }

    public int? ActorUserID { get; set; }

    [StringLength(320)]
    public string? ActorEmail { get; set; }

    [StringLength(50)]
    public string? ActorRole { get; set; }

    [Required, StringLength(80)]
    public string Action { get; set; } = string.Empty;

    [Required, StringLength(80)]
    public string EntityType { get; set; } = string.Empty;

    [StringLength(80)]
    public string? EntityId { get; set; }

    [StringLength(500)]
    public string? Summary { get; set; }

    public string? DataJson { get; set; }

    [StringLength(80)]
    public string? IpAddress { get; set; }

    [StringLength(500)]
    public string? UserAgent { get; set; }

    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
}

