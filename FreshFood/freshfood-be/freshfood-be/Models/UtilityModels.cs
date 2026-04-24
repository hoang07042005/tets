using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace freshfood_be.Models
{
    public class ProductImage
    {
        [Key]
        public int ImageID { get; set; }

        public int ProductID { get; set; }
        [ForeignKey("ProductID")]
        public Product? Product { get; set; }

        [Required]
        [StringLength(1000)]
        public string ImageURL { get; set; } = string.Empty;

        public bool IsMainImage { get; set; }
    }

    public class Review
    {
        [Key]
        public int ReviewID { get; set; }

        public int ProductID { get; set; }
        [ForeignKey("ProductID")]
        public Product? Product { get; set; }

        public int UserID { get; set; }
        [ForeignKey("UserID")]
        public User? User { get; set; }

        [Range(1, 5)]
        public int Rating { get; set; }

        public string? Comment { get; set; }

        public DateTime ReviewDate { get; set; } = DateTime.Now;

        /// <summary>Trạng thái kiểm duyệt: Pending | Approved | Hidden.</summary>
        [StringLength(20)]
        public string ModerationStatus { get; set; } = "Approved";

        public DateTime? ModeratedAt { get; set; }

        [StringLength(500)]
        public string? ModerationNote { get; set; }

        /// <summary>Phản hồi của admin hiển thị cho khách.</summary>
        [StringLength(2000)]
        public string? AdminReply { get; set; }

        public DateTime? RepliedAt { get; set; }

        /// <summary>Xóa mềm để có thể khôi phục.</summary>
        public bool IsDeleted { get; set; }

        public DateTime? DeletedAt { get; set; }

        public ICollection<ReviewImage> ReviewImages { get; set; } = new List<ReviewImage>();
    }

    public class ReviewImage
    {
        [Key]
        public int ReviewImageID { get; set; }

        public int ReviewID { get; set; }
        [ForeignKey("ReviewID")]
        public Review? Review { get; set; }

        [Required]
        [StringLength(1000)]
        public string ImageUrl { get; set; } = string.Empty;

        public int SortOrder { get; set; }
    }
}
