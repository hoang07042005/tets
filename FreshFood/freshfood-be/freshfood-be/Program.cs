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
