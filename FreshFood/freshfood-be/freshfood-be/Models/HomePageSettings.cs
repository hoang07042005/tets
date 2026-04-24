using System.ComponentModel.DataAnnotations;

namespace freshfood_be.Models;

/// <summary>
/// Lưu cấu hình trang chủ (1 bản ghi, id=1) dưới dạng JSON để dễ mở rộng.
/// </summary>
public sealed class HomePageSettings
{
    [Key]
    public int Id { get; set; }

    [Required]
    public string SettingsJson { get; set; } = "{}";

    public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;
}

