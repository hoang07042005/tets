using Microsoft.EntityFrameworkCore;
using freshfood_be.Models;

namespace freshfood_be.Data
{
    public class FreshFoodContext : DbContext
    {
        public FreshFoodContext(DbContextOptions<FreshFoodContext> options) : base(options)
        {
        }

        public DbSet<Category> Categories { get; set; } = null!;
        public DbSet<Supplier> Suppliers { get; set; } = null!;
        public DbSet<Product> Products { get; set; } = null!;
        public DbSet<ProductImage> ProductImages { get; set; } = null!;
        public DbSet<User> Users { get; set; } = null!;
        public DbSet<Review> Reviews { get; set; } = null!;
        public DbSet<ReviewImage> ReviewImages { get; set; } = null!;
        public DbSet<ShippingMethod> ShippingMethods { get; set; } = null!;
        public DbSet<Voucher> Vouchers { get; set; } = null!;
        public DbSet<Order> Orders { get; set; } = null!;
        public DbSet<OrderDetail> OrderDetails { get; set; } = null!;
        public DbSet<Shipment> Shipments { get; set; } = null!;
        public DbSet<Payment> Payments { get; set; } = null!;
        public DbSet<ReturnRequest> ReturnRequests { get; set; } = null!;
        public DbSet<ReturnRequestImage> ReturnRequestImages { get; set; } = null!;
        public DbSet<Cart> Carts { get; set; } = null!;
        public DbSet<CartItem> CartItems { get; set; } = null!;
        public DbSet<InventoryHistory> InventoryHistories { get; set; } = null!;
        public DbSet<Wishlist> Wishlists { get; set; } = null!;
        public DbSet<VoucherUsage> VoucherUsages { get; set; } = null!;
        public DbSet<BlogPost> BlogPosts { get; set; } = null!;
        public DbSet<BlogComment> BlogComments { get; set; } = null!;
        public DbSet<PasswordResetToken> PasswordResetTokens { get; set; } = null!;
        public DbSet<ContactMessage> ContactMessages { get; set; } = null!;
        public DbSet<UserAddress> UserAddresses { get; set; } = null!;
        public DbSet<HomePageSettings> HomePageSettings { get; set; } = null!;
        public DbSet<AdminAuditLog> AdminAuditLogs { get; set; } = null!;

        protected override void OnModelCreating(ModelBuilder modelBuilder)
        {
            base.OnModelCreating(modelBuilder);

            // Configure decimal precision
            modelBuilder.Entity<Product>()
                .Property(p => p.Price)
                .HasPrecision(18, 2);

            modelBuilder.Entity<Product>()
                .Property(p => p.DiscountPrice)
                .HasPrecision(18, 2);

            modelBuilder.Entity<Order>()
                .Property(o => o.TotalAmount)
                .HasPrecision(18, 2);

            modelBuilder.Entity<OrderDetail>()
                .Property(od => od.UnitPrice)
                .HasPrecision(18, 2);

            modelBuilder.Entity<ShippingMethod>()
                .Property(sm => sm.BaseCost)
                .HasPrecision(18, 2);

            modelBuilder.Entity<Voucher>()
                .Property(v => v.DiscountValue)
                .HasPrecision(18, 2);

            modelBuilder.Entity<Voucher>()
                .Property(v => v.MinOrderAmount)
                .HasPrecision(18, 2);

            modelBuilder.Entity<Payment>()
                .Property(p => p.Amount)
                .HasPrecision(18, 2);

            // Relationships and Constraints (matching SQL schema)
            modelBuilder.Entity<User>()
                .HasIndex(u => u.Email)
                .IsUnique();

            modelBuilder.Entity<Voucher>()
                .HasIndex(v => v.Code)
                .IsUnique();

            modelBuilder.Entity<VoucherUsage>()
                .HasIndex(vu => new { vu.UserID, vu.VoucherID })
                .IsUnique();

            modelBuilder.Entity<Cart>()
                .HasOne(c => c.User)
                .WithOne(u => u.Cart)
                .HasForeignKey<Cart>(c => c.UserID);

            modelBuilder.Entity<UserAddress>()
                .HasIndex(a => a.UserID);
            
            // Seed data could be added here later if needed, 
            // but the SQL script already has it.
        }
    }
}
