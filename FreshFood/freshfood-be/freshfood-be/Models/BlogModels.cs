using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace freshfood_be.Models
{
    public class BlogPost
    {
        [Key]
        public int BlogPostID { get; set; }

        [Required]
        [StringLength(200)]
        public string Title { get; set; } = string.Empty;

        [Required]
        [StringLength(220)]
        public string Slug { get; set; } = string.Empty;

        [StringLength(500)]
        public string? Excerpt { get; set; }

        [Required]
        public string Content { get; set; } = string.Empty;

        [StringLength(1000)]
        public string? CoverImageUrl { get; set; }

        public bool IsPublished { get; set; } = true;

        public DateTime? PublishedAt { get; set; }

        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

        public DateTime? UpdatedAt { get; set; }

        public int ViewCount { get; set; } = 0;
    }

    public class BlogComment
    {
        [Key]
        public int BlogCommentID { get; set; }

        [Required]
        public int BlogPostID { get; set; }

        [Required]
        public int UserID { get; set; }

        public int? ParentCommentID { get; set; }

        [Required]
        [StringLength(2000)]
        public string Content { get; set; } = string.Empty;

        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

        [ForeignKey(nameof(BlogPostID))]
        public BlogPost? BlogPost { get; set; }

        [ForeignKey(nameof(UserID))]
        public User? User { get; set; }

        [ForeignKey(nameof(ParentCommentID))]
        public BlogComment? ParentComment { get; set; }
    }
}

