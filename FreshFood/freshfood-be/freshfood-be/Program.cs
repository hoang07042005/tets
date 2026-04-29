using Microsoft.AspNetCore.Hosting.Server;
using Microsoft.AspNetCore.Hosting.Server.Features;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.Extensions.FileProviders;
using Microsoft.EntityFrameworkCore;
using Microsoft.IdentityModel.Tokens;
using Microsoft.Extensions.Logging;
using CloudinaryDotNet;
using freshfood_be.Data;
using System.Diagnostics;
using System.IO;
using freshfood_be.Services.VnPay;
using freshfood_be.Services.Email;
using freshfood_be.Services.Momo;
using freshfood_be.Services.Security;
using freshfood_be.Services.Orders;
using freshfood_be.Services.AI;
using freshfood_be.Services.Media;
using System.Text;

var builder = WebApplication.CreateBuilder(args);

// Thêm dòng này để fix lỗi DateTime với PostgreSQL
AppContext.SetSwitch("Npgsql.EnableLegacyTimestampBehavior", true);

// Add services to the container.
var connectionString = builder.Configuration.GetConnectionString("FreshFoodConnection");
Console.WriteLine($"[DEBUG] ConnectionString from Config: {(string.IsNullOrEmpty(connectionString) ? "NULL" : "FOUND")}");

if (string.IsNullOrEmpty(connectionString))
{
    connectionString = Environment.GetEnvironmentVariable("ConnectionStrings__FreshFoodConnection");
    Console.WriteLine($"[DEBUG] ConnectionString from Env: {(string.IsNullOrEmpty(connectionString) ? "NULL" : "FOUND")}");
}

builder.Services.AddDbContext<FreshFoodContext>(options =>
{
    var finalConn = connectionString;
    if (!string.IsNullOrEmpty(finalConn) && (finalConn.StartsWith("postgres://") || finalConn.StartsWith("postgresql://")))
    {
        var databaseUri = new Uri(finalConn);
        var userInfo = databaseUri.UserInfo.Split(':');
        var host = databaseUri.Host;
        var port = databaseUri.Port <= 0 ? 5432 : databaseUri.Port; // Nếu không có port thì mặc định 5432
        var database = databaseUri.AbsolutePath.TrimStart('/');
        
        finalConn = $"Host={host};Port={port};Database={database};Username={userInfo[0]};Password={userInfo[1]};SSL Mode=Require;Trust Server Certificate=true";
    }
    
    if (string.IsNullOrEmpty(finalConn)) {
        Console.WriteLine("[ERROR] FINAL CONNECTION STRING IS EMPTY!");
    }
    options.UseNpgsql(finalConn);
});


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

// Media storage: prefer Cloudinary when CLOUDINARY_URL is configured.
builder.Services.AddSingleton<IImageStorage>(_ =>
{
    var cloudinaryUrl = (Environment.GetEnvironmentVariable("CLOUDINARY_URL")
        ?? builder.Configuration["Cloudinary:Url"]
        ?? string.Empty).Trim();
    if (string.IsNullOrWhiteSpace(cloudinaryUrl))
    {
        return new DisabledImageStorage();
    }

    var account = new Account(cloudinaryUrl);
    var cloudinary = new Cloudinary(account)
    {
        Api = { Secure = true }
    };
    var folder = (Environment.GetEnvironmentVariable("CLOUDINARY_FOLDER")
        ?? builder.Configuration["Cloudinary:Folder"]
        ?? "freshfood").Trim();
    return new CloudinaryImageStorage(cloudinary, folder);
});

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
            var configuredOrigins = (Environment.GetEnvironmentVariable("FRONTEND_ORIGINS")
                ?? builder.Configuration["Frontend:AllowedOrigins"]
                ?? string.Empty)
                .Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries)
                .Where(x => !string.IsNullOrWhiteSpace(x))
                .ToArray();

            if (configuredOrigins.Length > 0)
            {
                policy.WithOrigins(configuredOrigins)
                      .AllowAnyHeader()
                      .AllowAnyMethod();
            }
            else
            {
                // Render-free friendly defaults when env var is not provided.
                policy
                    .SetIsOriginAllowed(origin =>
                    {
                        if (string.IsNullOrWhiteSpace(origin)) return false;
                        if (!Uri.TryCreate(origin, UriKind.Absolute, out var u)) return false;
                        if (u.Host.Equals("localhost", StringComparison.OrdinalIgnoreCase)) return true;
                        return u.Host.EndsWith(".onrender.com", StringComparison.OrdinalIgnoreCase);
                    })
                    .AllowAnyHeader()
                    .AllowAnyMethod();
            }
        }
    });
});

var app = builder.Build();


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

// Media root (Render persistent disk supported via MEDIA_ROOT)
var mediaRoot = (Environment.GetEnvironmentVariable("MEDIA_ROOT") ?? string.Empty).Trim();
if (string.IsNullOrWhiteSpace(mediaRoot))
{
    mediaRoot = Path.Combine(app.Environment.ContentRootPath, "wwwroot");
}

Directory.CreateDirectory(mediaRoot);
Directory.CreateDirectory(Path.Combine(mediaRoot, "review-images"));
Directory.CreateDirectory(Path.Combine(mediaRoot, "avatars"));
Directory.CreateDirectory(Path.Combine(mediaRoot, "product-images"));
Directory.CreateDirectory(Path.Combine(mediaRoot, "email-assets"));
Directory.CreateDirectory(Path.Combine(mediaRoot, "blog-covers"));
Directory.CreateDirectory(Path.Combine(mediaRoot, "supplier-assets"));
Directory.CreateDirectory(Path.Combine(mediaRoot, "return-images"));
Directory.CreateDirectory(Path.Combine(mediaRoot, "return-videos"));
Directory.CreateDirectory(Path.Combine(mediaRoot, "return-refund-proofs"));

// Trang chủ / — thông báo backend đã chạy
app.UseDefaultFiles();
if (string.Equals(Path.GetFullPath(mediaRoot), Path.GetFullPath(Path.Combine(app.Environment.ContentRootPath, "wwwroot")), StringComparison.OrdinalIgnoreCase))
{
    app.UseStaticFiles();
}
else
{
    // Serve files from persistent disk with root-relative URLs (/product-images/..., /avatars/...)
    app.UseStaticFiles(new StaticFileOptions
    {
        FileProvider = new PhysicalFileProvider(mediaRoot),
        RequestPath = ""
    });
}

app.UseCors("AllowFrontend");

app.UseAuthentication();
app.UseAuthorization();

app.UseMiddleware<freshfood_be.Middlewares.MaintenanceMiddleware>();

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


// --- TỰ ĐỘNG KHỞI TẠO DATABASE ---
using (var scope = app.Services.CreateScope())
{
    var services = scope.ServiceProvider;
    try
    {
        var context = services.GetRequiredService<FreshFoodContext>();
        Console.WriteLine("[INFO] Ensuring database schema exists...");
        context.Database.EnsureCreated(); // Tự động tạo bảng nếu chưa có
        try
        {
            var provider = context.Database.ProviderName ?? string.Empty;
            if (provider.Contains("Npgsql", StringComparison.OrdinalIgnoreCase))
            {
                context.Database.ExecuteSqlRaw("""
                    CREATE TABLE IF NOT EXISTS "OrderIdempotencies" (
                        "OrderIdempotencyID" integer GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
                        "IdempotencyKey" varchar(120) NOT NULL,
                        "RequestHash" varchar(64) NOT NULL DEFAULT '',
                        "UserID" integer NULL,
                        "OrderID" integer NULL,
                        "CreatedAtUtc" timestamp with time zone NOT NULL DEFAULT NOW(),
                        "CompletedAtUtc" timestamp with time zone NULL
                    );
                    CREATE UNIQUE INDEX IF NOT EXISTS "IX_OrderIdempotencies_IdempotencyKey"
                    ON "OrderIdempotencies" ("IdempotencyKey");
                """);
            }
        }
        catch (Exception ex)
        {
            Console.WriteLine($"[WARN] Could not ensure OrderIdempotencies table exists: {ex.Message}");
        }
        Console.WriteLine("[INFO] Database schema is ready.");
    }
    catch (Exception ex)
    {
        Console.WriteLine($"[ERROR] An error occurred during database initialization: {ex.Message}");
    }
}

app.Run();
