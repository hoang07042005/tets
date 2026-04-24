using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using System.Text.Json.Serialization;

namespace freshfood_be.Models
{
    public class VoucherUsage
    {
        [Key]
        public int VoucherUsageID { get; set; }

        public int VoucherID { get; set; }
        [ForeignKey("VoucherID")]
        [JsonIgnore]
        public Voucher? Voucher { get; set; }

        public int UserID { get; set; }
        [ForeignKey("UserID")]
        [JsonIgnore]
        public User? User { get; set; }

        public int? OrderID { get; set; }
        [ForeignKey("OrderID")]
        [JsonIgnore]
        public Order? Order { get; set; }

        public DateTime UsedAt { get; set; } = DateTime.UtcNow;
    }
}

