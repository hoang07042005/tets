using Microsoft.AspNetCore.Hosting.Server;
using Microsoft.AspNetCore.Hosting.Server.Features;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.EntityFrameworkCore;
using Microsoft.IdentityModel.Tokens;
using Microsoft.Extensions.Logging;
using freshfood_be.Data;
using System.Diagnostics;
using System.IO;
using freshfood_be.Services.VnPay;
using freshfood_be.Services.Email;
using freshfood_be.Services.Momo;
using freshfood_be.Services.Security;
using freshfood_be.Services.Orders;
using freshfood_be.Services.AI;
using System.Text;

var builder = WebApplication.CreateBuilder(args);

// Add services to the container.
builder.Services.AddDbContext<FreshFoodContext>(options =>
    options.UseNpgsql(builder.Configuration.GetConnectionString("FreshFoodConnection")));


builder.Services.AddControllers()
    .AddJsonOptions(options =>
    {
        options.JsonSerializerOptions.ReferenceHandler = System.Text.Json.Serialization.ReferenceHandler.IgnoreCycles;
    });
// Learn more about configuring OpenAPI at https://aka.ms/aspnet/openapi
builder.Services.AddOpenApi();

builder.Services.Configure<VnPayOptions>(builder.Configuration.GetSection("VnPay"));
builder.Services.AddSingleton<VnPayService>();

builder.Services.Configure<MomoOptions>(builder.Configuration.GetSection("Momo"));
builder.Services.AddHttpClient("momo");
builder.Services.AddSingleton<MomoService>();

builder.Services.Configure<EmailSettings>(builder.Configuration.GetSection("Email"));
builder.Services.AddSingleton<IEmailSender, SmtpEmailSender>();

// Tokenize IDs for safer URLs (e.g., /orders/:token).
builder.Services.AddDataProtection();
builder.Services.AddSingleton<freshfood_be.Services.Security.IdTokenService>();

// AI Service
builder.Services.AddHttpClient<IAIService, AIService>();

// JWT Auth
builder.Services.Configure<JwtOptions>(builder.Configuration.GetSection("Jwt"));
var jwt = builder.Configuration.GetSection("Jwt").Get<JwtOptions>() ?? new JwtOptions();
if (string.IsNullOrWhiteSpace(jwt.Key))
{
    // Dev fallback to avoid startup crash if config missing
    jwt.Key = "dev-only-change-me-please-dev-only-change-me-please";
}

builder.Services
    .AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(options =>
    {
        options.TokenValidationParameters = new TokenValidationParameters
        {
            ValidateIssuer = true,
            ValidIssuer = jwt.Issuer,
            ValidateAudience = true,
            ValidAudience = jwt.Audience,
            ValidateIssuerSigningKey = true,
            IssuerSigningKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(jwt.Key)),
            ValidateLifetime = true,
            ClockSkew = TimeSpan.FromSeconds(30),
        };
    });

builder.Services.AddAuthorization();

// Inventory reservation auto-release for abandoned online payments
builder.Services.Configure<InventoryReservationOptions>(builder.Configuration.GetSection("InventoryReservation"));
builder.Services.AddHostedService<AbandonedOnlinePaymentSweeper>();

// Admin audit logging
builder.Services.AddHttpContextAccessor();
builder.Services.AddScoped<freshfood_be.Services.Security.AdminAuditLogger>();

// Add CORS
builder.Services.AddCors(options =>
{
    options.AddPolicy("AllowFrontend", policy =>
    {
        if (builder.Environment.IsDevelopment())
        {
            policy
                .SetIsOriginAllowed(_ => true)
                .AllowAnyHeader()
                .AllowAnyMethod();
        }
        else
        {
            policy.WithOrigins("http://localhost:5173") // Default Vite port
                  .AllowAnyHeader()
                  .AllowAnyMethod();
        }
    });
});

var app = builder.Build();

// DB bootstrap (idempotent raw SQL). Disable via config: DatabaseBootstrap:Enabled=false
var dbBootstrapEnabled = builder.Configuration.GetValue("DatabaseBootstrap:Enabled", true);
if (dbBootstrapEnabled)
{
    using var scope = app.Services.CreateScope();
    var db = scope.ServiceProvider.GetRequiredService<FreshFoodContext>();
    var log = scope.ServiceProvider.GetRequiredService<ILoggerFactory>().CreateLogger("DatabaseBootstrap");
    try
    {
        db.Database.ExecuteSqlRaw("""
            IF COL_LENGTH('dbo.Suppliers', 'SupplierCode') IS NULL
            BEGIN
                ALTER TABLE dbo.Suppliers ADD
                    SupplierCode NVARCHAR(50) NULL,
                    ImageUrl NVARCHAR(1000) NULL,
                    Status NVARCHAR(20) NOT NULL CONSTRAINT DF_Suppliers_FF_Status DEFAULT ('Active'),
                    IsVerified BIT NOT NULL CONSTRAINT DF_Suppliers_FF_Verified DEFAULT (0),
                    CreatedAt DATETIME NOT NULL CONSTRAINT DF_Suppliers_FF_Created DEFAULT (GETUTCDATE());
            END
            """);
        db.Database.ExecuteSqlRaw("""
            UPDATE dbo.Suppliers SET SupplierCode = CONCAT('VH-', YEAR(GETUTCDATE()), '-', RIGHT(CONCAT('000', CAST(SupplierID AS VARCHAR(10))), 3))
            WHERE SupplierCode IS NULL OR LTRIM(RTRIM(ISNULL(SupplierCode, ''))) = ''
            """);

        // Bổ sung cột SKU cho Products nếu DB cũ chưa có.
        db.Database.ExecuteSqlRaw("""
            IF COL_LENGTH('dbo.Products', 'Sku') IS NULL
            BEGIN
                ALTER TABLE dbo.Products ADD Sku NVARCHAR(50) NULL;
            END
            """);
        db.Database.ExecuteSqlRaw("""
            UPDATE dbo.Products
            SET Sku = CONCAT('FF-PRD-', RIGHT(CONCAT('000', CAST(ProductID AS VARCHAR(10))), 3))
            WHERE Sku IS NULL OR LTRIM(RTRIM(ISNULL(Sku, ''))) = ''
            """);

        // Đặc tả tươi / thực phẩm: NSX, HSD, nguồn gốc, bảo quản, chứng nhận.
        db.Database.ExecuteSqlRaw("""
            IF COL_LENGTH('dbo.Products', 'ManufacturedDate') IS NULL
                ALTER TABLE dbo.Products ADD ManufacturedDate DATETIME2 NULL;
            """);
        db.Database.ExecuteSqlRaw("""
            IF COL_LENGTH('dbo.Products', 'ExpiryDate') IS NULL
                ALTER TABLE dbo.Products ADD ExpiryDate DATETIME2 NULL;
            """);
        db.Database.ExecuteSqlRaw("""
            IF COL_LENGTH('dbo.Products', 'Origin') IS NULL
                ALTER TABLE dbo.Products ADD Origin NVARCHAR(500) NULL;
            """);
        db.Database.ExecuteSqlRaw("""
            IF COL_LENGTH('dbo.Products', 'StorageInstructions') IS NULL
                ALTER TABLE dbo.Products ADD StorageInstructions NVARCHAR(2000) NULL;
            """);
        db.Database.ExecuteSqlRaw("""
            IF COL_LENGTH('dbo.Products', 'Certifications') IS NULL
                ALTER TABLE dbo.Products ADD Certifications NVARCHAR(500) NULL;
            """);

        // Trạng thái hiển thị sản phẩm (Active/Inactive).
        db.Database.ExecuteSqlRaw("""
            IF COL_LENGTH('dbo.Products', 'Status') IS NULL
            BEGIN
                ALTER TABLE dbo.Products ADD Status NVARCHAR(20) NOT NULL CONSTRAINT DF_Products_FF_Status DEFAULT ('Active');
            END
            """);

        // Thiết lập trang chủ (1 bản ghi id=1, lưu JSON).
        db.Database.ExecuteSqlRaw("""
            IF OBJECT_ID('dbo.HomePageSettings') IS NULL
            BEGIN
                CREATE TABLE dbo.HomePageSettings (
                    Id INT NOT NULL CONSTRAINT PK_HomePageSettings PRIMARY KEY,
                    SettingsJson NVARCHAR(MAX) NOT NULL,
                    UpdatedAt DATETIME2 NOT NULL CONSTRAINT DF_HomePageSettings_UpdatedAt DEFAULT (SYSUTCDATETIME())
                );
            END
            """);

        // Admin audit logs (idempotent).
        db.Database.ExecuteSqlRaw("""
            IF OBJECT_ID('dbo.AdminAuditLogs') IS NULL
            BEGIN
                CREATE TABLE dbo.AdminAuditLogs (
                    AdminAuditLogID BIGINT IDENTITY(1,1) PRIMARY KEY,
                    ActorUserID INT NULL,
                    ActorEmail NVARCHAR(320) NULL,
                    ActorRole NVARCHAR(50) NULL,
                    Action NVARCHAR(80) NOT NULL,
                    EntityType NVARCHAR(80) NOT NULL,
                    EntityId NVARCHAR(80) NULL,
                    Summary NVARCHAR(500) NULL,
                    DataJson NVARCHAR(MAX) NULL,
                    IpAddress NVARCHAR(80) NULL,
                    UserAgent NVARCHAR(500) NULL,
                    CreatedAt DATETIME2 NOT NULL CONSTRAINT DF_AdminAuditLogs_CreatedAt DEFAULT (SYSUTCDATETIME())
                );
                CREATE INDEX IX_AdminAuditLogs_CreatedAt ON dbo.AdminAuditLogs(CreatedAt DESC);
                CREATE INDEX IX_AdminAuditLogs_ActorUserID ON dbo.AdminAuditLogs(ActorUserID);
                CREATE INDEX IX_AdminAuditLogs_Entity ON dbo.AdminAuditLogs(EntityType, EntityId);
            END
            """);

        // Seed ShippingMethods if table exists but empty (to support checkout shipping selection).
        db.Database.ExecuteSqlRaw("""
            IF OBJECT_ID('dbo.ShippingMethods') IS NOT NULL
               AND NOT EXISTS (SELECT 1 FROM dbo.ShippingMethods)
            BEGIN
                INSERT INTO dbo.ShippingMethods (MethodName, BaseCost, EstimatedDays) VALUES
                    (N'Tiêu chuẩn', 30000, 3),
                    (N'Nhanh', 45000, 2),
                    (N'Hỏa tốc', 70000, 1);
            END
            """);

        // Create ReturnRequests tables if missing (idempotent, no EF migrations).
        db.Database.ExecuteSqlRaw("""
            IF OBJECT_ID('dbo.ReturnRequests') IS NULL
            BEGIN
                CREATE TABLE dbo.ReturnRequests (
                    ReturnRequestID INT IDENTITY(1,1) PRIMARY KEY,
                    OrderID INT NOT NULL,
                    UserID INT NOT NULL,
                    Status NVARCHAR(30) NOT NULL CONSTRAINT DF_ReturnRequests_Status DEFAULT ('Pending'),
                    Reason NVARCHAR(2000) NOT NULL,
                    AdminNote NVARCHAR(2000) NULL,
                    VideoUrl NVARCHAR(1000) NULL,
                    RefundProofUrl NVARCHAR(1000) NULL,
                    RefundNote NVARCHAR(2000) NULL,
                    CreatedAt DATETIME2 NOT NULL CONSTRAINT DF_ReturnRequests_CreatedAt DEFAULT (SYSUTCDATETIME()),
                    ReviewedAt DATETIME2 NULL,
                    CONSTRAINT FK_ReturnRequests_Order FOREIGN KEY (OrderID) REFERENCES dbo.Orders(OrderID),
                    CONSTRAINT FK_ReturnRequests_User FOREIGN KEY (UserID) REFERENCES dbo.Users(UserID)
                );
                CREATE INDEX IX_ReturnRequests_OrderID ON dbo.ReturnRequests(OrderID);
            END
            """);

        db.Database.ExecuteSqlRaw("""
            IF OBJECT_ID('dbo.ReturnRequests') IS NOT NULL
               AND COL_LENGTH('dbo.ReturnRequests', 'VideoUrl') IS NULL
            BEGIN
                ALTER TABLE dbo.ReturnRequests ADD VideoUrl NVARCHAR(1000) NULL;
            END
            """);

        db.Database.ExecuteSqlRaw("""
            IF OBJECT_ID('dbo.ReturnRequests') IS NOT NULL
               AND COL_LENGTH('dbo.ReturnRequests', 'RefundProofUrl') IS NULL
            BEGIN
                ALTER TABLE dbo.ReturnRequests ADD RefundProofUrl NVARCHAR(1000) NULL;
            END
            """);

        db.Database.ExecuteSqlRaw("""
            IF OBJECT_ID('dbo.ReturnRequests') IS NOT NULL
               AND COL_LENGTH('dbo.ReturnRequests', 'RefundNote') IS NULL
            BEGIN
                ALTER TABLE dbo.ReturnRequests ADD RefundNote NVARCHAR(2000) NULL;
            END
            """);

        db.Database.ExecuteSqlRaw("""
            IF OBJECT_ID('dbo.ReturnRequests') IS NOT NULL
               AND COL_LENGTH('dbo.ReturnRequests', 'RequestType') IS NULL
            BEGIN
                ALTER TABLE dbo.ReturnRequests ADD RequestType NVARCHAR(30) NOT NULL CONSTRAINT DF_ReturnRequests_RequestType DEFAULT ('Return');
                CREATE INDEX IX_ReturnRequests_RequestType ON dbo.ReturnRequests(RequestType);
            END
            """);

        db.Database.ExecuteSqlRaw("""
            IF OBJECT_ID('dbo.ReturnRequestImages') IS NULL
            BEGIN
                CREATE TABLE dbo.ReturnRequestImages (
                    ReturnRequestImageID INT IDENTITY(1,1) PRIMARY KEY,
                    ReturnRequestID INT NOT NULL,
                    ImageUrl NVARCHAR(1000) NOT NULL,
                    CONSTRAINT FK_ReturnRequestImages_ReturnRequest FOREIGN KEY (ReturnRequestID) REFERENCES dbo.ReturnRequests(ReturnRequestID) ON DELETE CASCADE
                );
                CREATE INDEX IX_ReturnRequestImages_ReturnRequestID ON dbo.ReturnRequestImages(ReturnRequestID);
            END
            """);

        // Create BlogPosts table if missing (idempotent, no EF migrations).
        db.Database.ExecuteSqlRaw("""
            IF OBJECT_ID('dbo.BlogPosts') IS NULL
            BEGIN
                CREATE TABLE dbo.BlogPosts (
                    BlogPostID INT IDENTITY(1,1) PRIMARY KEY,
                    Title NVARCHAR(200) NOT NULL,
                    Slug NVARCHAR(220) NOT NULL,
                    Excerpt NVARCHAR(500) NULL,
                    Content NVARCHAR(MAX) NOT NULL,
                    CoverImageUrl NVARCHAR(1000) NULL,
                    IsPublished BIT NOT NULL CONSTRAINT DF_BlogPosts_IsPublished DEFAULT (1),
                    PublishedAt DATETIME2 NULL,
                    ViewCount INT NOT NULL CONSTRAINT DF_BlogPosts_ViewCount DEFAULT (0),
                    CreatedAt DATETIME2 NOT NULL CONSTRAINT DF_BlogPosts_CreatedAt DEFAULT (SYSUTCDATETIME()),
                    UpdatedAt DATETIME2 NULL
                );
                CREATE UNIQUE INDEX UX_BlogPosts_Slug ON dbo.BlogPosts(Slug);
                CREATE INDEX IX_BlogPosts_PublishedAt ON dbo.BlogPosts(PublishedAt);
            END
            """);

        // Add ViewCount if missing (idempotent).
        db.Database.ExecuteSqlRaw("""
            IF OBJECT_ID('dbo.BlogPosts') IS NOT NULL
               AND COL_LENGTH('dbo.BlogPosts', 'ViewCount') IS NULL
            BEGIN
                ALTER TABLE dbo.BlogPosts ADD ViewCount INT NOT NULL CONSTRAINT DF_BlogPosts_ViewCount DEFAULT (0);
            END
            """);

        // Khóa tài khoản (admin) — cột IsLocked cho Users.
        db.Database.ExecuteSqlRaw("""
            IF OBJECT_ID('dbo.Users') IS NOT NULL
               AND COL_LENGTH('dbo.Users', 'IsLocked') IS NULL
            BEGIN
                ALTER TABLE dbo.Users ADD IsLocked BIT NOT NULL CONSTRAINT DF_Users_IsLocked DEFAULT (0);
            END
            """);

        // Đặt hàng khách — đánh dấu tài khoản tạo nhanh (không đăng nhập bằng mật khẩu cho đến khi đặt mật khẩu qua Quên mật khẩu).
        db.Database.ExecuteSqlRaw("""
            IF OBJECT_ID('dbo.Users') IS NOT NULL
               AND COL_LENGTH('dbo.Users', 'IsGuestAccount') IS NULL
            BEGIN
                ALTER TABLE dbo.Users ADD IsGuestAccount BIT NOT NULL CONSTRAINT DF_Users_IsGuestAccount DEFAULT (0);
            END
            """);

        // Kiểm duyệt đánh giá (Reviews): trạng thái duyệt/ẩn + ghi chú (idempotent, không dùng EF migrations).
        db.Database.ExecuteSqlRaw("""
            IF OBJECT_ID('dbo.Reviews') IS NOT NULL
               AND COL_LENGTH('dbo.Reviews', 'ModerationStatus') IS NULL
            BEGIN
                ALTER TABLE dbo.Reviews ADD
                    ModerationStatus NVARCHAR(20) NOT NULL CONSTRAINT DF_Reviews_ModerationStatus DEFAULT ('Approved'),
                    ModeratedAt DATETIME2 NULL,
                    ModerationNote NVARCHAR(500) NULL;
            END
            """);

        // Reviews: phản hồi admin + xóa mềm (khôi phục được).
        db.Database.ExecuteSqlRaw("""
            IF OBJECT_ID('dbo.Reviews') IS NOT NULL
               AND COL_LENGTH('dbo.Reviews', 'AdminReply') IS NULL
            BEGIN
                ALTER TABLE dbo.Reviews ADD
                    AdminReply NVARCHAR(2000) NULL,
                    RepliedAt DATETIME2 NULL;
            END
            """);

        db.Database.ExecuteSqlRaw("""
            IF OBJECT_ID('dbo.Reviews') IS NOT NULL
               AND COL_LENGTH('dbo.Reviews', 'IsDeleted') IS NULL
            BEGIN
                ALTER TABLE dbo.Reviews ADD
                    IsDeleted BIT NOT NULL CONSTRAINT DF_Reviews_IsDeleted DEFAULT (0),
                    DeletedAt DATETIME2 NULL;
            END
            """);

        db.Database.ExecuteSqlRaw("""
            IF OBJECT_ID('dbo.Reviews') IS NOT NULL
               AND NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Reviews_ModerationStatus' AND object_id = OBJECT_ID('dbo.Reviews'))
            BEGIN
                CREATE INDEX IX_Reviews_ModerationStatus ON dbo.Reviews(ModerationStatus);
            END
            """);

        db.Database.ExecuteSqlRaw("""
            IF OBJECT_ID('dbo.Reviews') IS NOT NULL
               AND NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Reviews_Product_Status_Date' AND object_id = OBJECT_ID('dbo.Reviews'))
            BEGIN
                CREATE INDEX IX_Reviews_Product_Status_Date ON dbo.Reviews(ProductID, ModerationStatus, ReviewDate DESC);
            END
            """);

        db.Database.ExecuteSqlRaw("""
            IF OBJECT_ID('dbo.Reviews') IS NOT NULL
               AND NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Reviews_IsDeleted' AND object_id = OBJECT_ID('dbo.Reviews'))
            BEGIN
                CREATE INDEX IX_Reviews_IsDeleted ON dbo.Reviews(IsDeleted);
            END
            """);

        // Create PasswordResetTokens table if missing (idempotent, no EF migrations).
        db.Database.ExecuteSqlRaw("""
            IF OBJECT_ID('dbo.PasswordResetTokens') IS NULL
            BEGIN
                CREATE TABLE dbo.PasswordResetTokens (
                    PasswordResetTokenID INT IDENTITY(1,1) PRIMARY KEY,
                    UserID INT NOT NULL,
                    TokenHash NVARCHAR(128) NOT NULL,
                    Purpose NVARCHAR(64) NULL,
                    ExpiresAt DATETIME NOT NULL,
                    CreatedAt DATETIME NOT NULL CONSTRAINT DF_PasswordResetTokens_CreatedAt DEFAULT (GETUTCDATE()),
                    UsedAt DATETIME NULL,
                    CONSTRAINT FK_PasswordResetTokens_User FOREIGN KEY (UserID) REFERENCES dbo.Users(UserID) ON DELETE CASCADE
                );
                CREATE INDEX IX_PasswordResetTokens_User_TokenHash ON dbo.PasswordResetTokens(UserID, TokenHash);
            END
            """);

        // Create BlogComments table if missing (idempotent, no EF migrations).
        db.Database.ExecuteSqlRaw("""
            IF OBJECT_ID('dbo.BlogComments') IS NULL
            BEGIN
                CREATE TABLE dbo.BlogComments (
                    BlogCommentID INT IDENTITY(1,1) PRIMARY KEY,
                    BlogPostID INT NOT NULL,
                    UserID INT NOT NULL,
                    Content NVARCHAR(2000) NOT NULL,
                    CreatedAt DATETIME2 NOT NULL CONSTRAINT DF_BlogComments_CreatedAt DEFAULT (SYSUTCDATETIME()),
                    CONSTRAINT FK_BlogComments_BlogPost FOREIGN KEY (BlogPostID) REFERENCES dbo.BlogPosts(BlogPostID) ON DELETE CASCADE,
                    CONSTRAINT FK_BlogComments_User FOREIGN KEY (UserID) REFERENCES dbo.Users(UserID)
                );
                CREATE INDEX IX_BlogComments_BlogPostID ON dbo.BlogComments(BlogPostID);
                CREATE INDEX IX_BlogComments_UserID ON dbo.BlogComments(UserID);
                CREATE INDEX IX_BlogComments_CreatedAt ON dbo.BlogComments(CreatedAt);
            END
            """);

        // If BlogComments exists from older version (UserName), add UserID column (nullable) for compatibility.
        db.Database.ExecuteSqlRaw("""
            IF OBJECT_ID('dbo.BlogComments') IS NOT NULL
               AND COL_LENGTH('dbo.BlogComments', 'UserID') IS NULL
            BEGIN
                ALTER TABLE dbo.BlogComments ADD UserID INT NULL;
            END
            """);

        // If older schema had UserName, drop it for cleanliness.
        db.Database.ExecuteSqlRaw("""
            IF OBJECT_ID('dbo.BlogComments') IS NOT NULL
               AND COL_LENGTH('dbo.BlogComments', 'UserName') IS NOT NULL
            BEGIN
                ALTER TABLE dbo.BlogComments DROP COLUMN UserName;
            END
            """);

        // Add ParentCommentID for threaded replies.
        db.Database.ExecuteSqlRaw("""
            IF OBJECT_ID('dbo.BlogComments') IS NOT NULL
               AND COL_LENGTH('dbo.BlogComments', 'ParentCommentID') IS NULL
            BEGIN
                ALTER TABLE dbo.BlogComments ADD ParentCommentID INT NULL;
                CREATE INDEX IX_BlogComments_ParentCommentID ON dbo.BlogComments(ParentCommentID);
            END
            """);

        // Add self FK for ParentCommentID if not exists.
        db.Database.ExecuteSqlRaw("""
            IF OBJECT_ID('dbo.BlogComments') IS NOT NULL
               AND COL_LENGTH('dbo.BlogComments', 'ParentCommentID') IS NOT NULL
               AND NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_BlogComments_ParentComment')
            BEGIN
                ALTER TABLE dbo.BlogComments
                ADD CONSTRAINT FK_BlogComments_ParentComment
                FOREIGN KEY (ParentCommentID) REFERENCES dbo.BlogComments(BlogCommentID)
                ON DELETE NO ACTION;
            END
            """);

        // Contact form submissions (public POST api/ContactMessages).
        db.Database.ExecuteSqlRaw("""
            IF OBJECT_ID('dbo.ContactMessages') IS NULL
            BEGIN
                CREATE TABLE dbo.ContactMessages (
                    ContactMessageID INT IDENTITY(1,1) PRIMARY KEY,
                    Name NVARCHAR(200) NOT NULL,
                    Email NVARCHAR(320) NOT NULL,
                    Subject NVARCHAR(300) NOT NULL,
                    Message NVARCHAR(MAX) NOT NULL,
                    CreatedAt DATETIME2 NOT NULL CONSTRAINT DF_ContactMessages_CreatedAt DEFAULT (SYSUTCDATETIME())
                );
                CREATE INDEX IX_ContactMessages_CreatedAt ON dbo.ContactMessages(CreatedAt DESC);
            END
            """);
        db.Database.ExecuteSqlRaw("""
            IF OBJECT_ID('dbo.ContactMessages') IS NOT NULL
               AND COL_LENGTH('dbo.ContactMessages', 'Status') IS NULL
            BEGIN
                ALTER TABLE dbo.ContactMessages ADD
                    Status NVARCHAR(20) NOT NULL CONSTRAINT DF_ContactMessages_Status DEFAULT (N'New'),
                    IsUrgent BIT NOT NULL CONSTRAINT DF_ContactMessages_IsUrgent DEFAULT (0);
                CREATE INDEX IX_ContactMessages_Status ON dbo.ContactMessages(Status);
            END
            """);

        // Sổ địa chỉ giao hàng (nhiều địa chỉ / mặc định).
        db.Database.ExecuteSqlRaw("""
            IF OBJECT_ID('dbo.UserAddresses') IS NULL
            BEGIN
                CREATE TABLE dbo.UserAddresses (
                    UserAddressID INT IDENTITY(1,1) PRIMARY KEY,
                    UserID INT NOT NULL,
                    Label NVARCHAR(60) NULL,
                    RecipientName NVARCHAR(100) NOT NULL,
                    Phone NVARCHAR(20) NULL,
                    AddressLine NVARCHAR(500) NOT NULL,
                    IsDefault BIT NOT NULL CONSTRAINT DF_UserAddresses_IsDefault DEFAULT (0),
                    CreatedAt DATETIME2 NOT NULL CONSTRAINT DF_UserAddresses_CreatedAt DEFAULT (SYSUTCDATETIME()),
                    CONSTRAINT FK_UserAddresses_User FOREIGN KEY (UserID) REFERENCES dbo.Users(UserID) ON DELETE CASCADE
                );
                CREATE INDEX IX_UserAddresses_UserID ON dbo.UserAddresses(UserID);
            END
            """);

        // Seed a couple blog posts if empty (demo content).
        db.Database.ExecuteSqlRaw("""
            IF OBJECT_ID('dbo.BlogPosts') IS NOT NULL
               AND NOT EXISTS (SELECT 1 FROM dbo.BlogPosts)
            BEGIN
                INSERT INTO dbo.BlogPosts (Title, Slug, Excerpt, Content, CoverImageUrl, IsPublished, PublishedAt)
                VALUES
                (
                    N'FreshFood – Mẹo chọn rau củ tươi mỗi ngày',
                    N'meo-chon-rau-cu-tuoi-moi-ngay',
                    N'Những mẹo đơn giản giúp bạn chọn rau củ tươi ngon, an toàn và bảo quản đúng cách.',
                    N'<p>Chọn rau củ tươi không khó. Bạn có thể bắt đầu từ việc quan sát <strong>màu sắc</strong>, <strong>độ giòn</strong> và <strong>mùi</strong>.</p>
                    <ul>
                      <li>Ưu tiên rau có màu tự nhiên, không quá bóng.</li>
                      <li>Tránh rau bị dập, úa, có đốm lạ.</li>
                      <li>Bảo quản bằng túi giấy/khăn giấy để hút ẩm.</li>
                    </ul>
                    <p>FreshFood luôn chọn lọc nguồn hàng mỗi ngày để bạn yên tâm mua sắm.</p>',
                    NULL,
                    1,
                    SYSUTCDATETIME()
                ),
                (
                    N'Gợi ý thực đơn eat-clean 3 ngày',
                    N'goi-y-thuc-don-eat-clean-3-ngay',
                    N'Thực đơn tham khảo dễ làm, đủ chất, phù hợp người bận rộn.',
                    N'<p>Dưới đây là gợi ý thực đơn 3 ngày (tham khảo):</p>
                    <ol>
                      <li>Ngày 1: Ức gà + salad + khoai lang</li>
                      <li>Ngày 2: Cá hồi + rau củ hấp + cơm gạo lứt</li>
                      <li>Ngày 3: Trứng + yến mạch + trái cây</li>
                    </ol>
                    <p>Bạn có thể đặt nguyên liệu tại FreshFood để tiết kiệm thời gian.</p>',
                    NULL,
                    1,
                    SYSUTCDATETIME()
                );
            END
            """);
    }
    catch (Exception ex)
    {
        log.LogError(ex, "Không tự migrate cột Suppliers. Chạy script trong FreshFood_Schema.sql (phần migration Suppliers) rồi khởi động lại backend.");
    }
}

// Configure the HTTP request pipeline.
if (app.Environment.IsDevelopment())
{
    app.MapOpenApi();
    app.UseSwaggerUI(options => options.SwaggerEndpoint("/openapi/v1.json", "v1"));
}

// In dev we often run only HTTP (:5013). Avoid redirecting static image requests to HTTPS.
if (!app.Environment.IsDevelopment())
{
    app.UseHttpsRedirection();
}

// Ensure wwwroot exists for static files (review images upload)
Directory.CreateDirectory(Path.Combine(app.Environment.ContentRootPath, "wwwroot"));
Directory.CreateDirectory(Path.Combine(app.Environment.ContentRootPath, "wwwroot", "review-images"));
Directory.CreateDirectory(Path.Combine(app.Environment.ContentRootPath, "wwwroot", "avatars"));
Directory.CreateDirectory(Path.Combine(app.Environment.ContentRootPath, "wwwroot", "product-images"));
Directory.CreateDirectory(Path.Combine(app.Environment.ContentRootPath, "wwwroot", "email-assets"));
Directory.CreateDirectory(Path.Combine(app.Environment.ContentRootPath, "wwwroot", "blog-covers"));
Directory.CreateDirectory(Path.Combine(app.Environment.ContentRootPath, "wwwroot", "supplier-assets"));
Directory.CreateDirectory(Path.Combine(app.Environment.ContentRootPath, "wwwroot", "return-images"));
Directory.CreateDirectory(Path.Combine(app.Environment.ContentRootPath, "wwwroot", "return-videos"));
Directory.CreateDirectory(Path.Combine(app.Environment.ContentRootPath, "wwwroot", "return-refund-proofs"));

// Trang chủ / — thông báo backend đã chạy
app.UseDefaultFiles();
app.UseStaticFiles();

app.UseCors("AllowFrontend");

app.UseAuthentication();
app.UseAuthorization();

app.MapControllers();

if (app.Environment.IsDevelopment())
{
    app.Lifetime.ApplicationStarted.Register(() =>
    {
        try
        {
            var server = app.Services.GetRequiredService<IServer>();
            var addresses = server.Features.Get<IServerAddressesFeature>()?.Addresses;
            var url = addresses?
                .Where(a => a.StartsWith("http://", StringComparison.OrdinalIgnoreCase))
                .FirstOrDefault()
                ?? addresses?.FirstOrDefault();
            if (string.IsNullOrEmpty(url))
                return;
            Process.Start(new ProcessStartInfo
            {
                FileName = url.TrimEnd('/') + "/",
                UseShellExecute = true
            });
        }
        catch
        {
            // Môi trường không có trình duyệt / shell
        }
    });
}

app.Run();
