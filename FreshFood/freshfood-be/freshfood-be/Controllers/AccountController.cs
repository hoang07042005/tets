using Microsoft.AspNetCore.Mvc;
using Microsoft.IdentityModel.Tokens;
using Microsoft.EntityFrameworkCore;
using freshfood_be.Data;
using freshfood_be.Models;
using System.Security.Cryptography;
using System.Text;
using System.IO;
using Microsoft.AspNetCore.Hosting;
using Microsoft.Extensions.Options;
using freshfood_be.Services.Email;
using freshfood_be.Services.Security;
using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;

namespace freshfood_be.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    public class AccountController : ControllerBase
    {
        private readonly FreshFoodContext _context;
        private readonly IWebHostEnvironment _env;
        private readonly ILogger<AccountController> _logger;
        private readonly IEmailSender _emailSender;
        private readonly IConfiguration _configuration;
        private readonly IOptions<EmailSettings> _emailOptions;

        public AccountController(
            FreshFoodContext context,
            IWebHostEnvironment env,
            ILogger<AccountController> logger,
            IEmailSender emailSender,
            IConfiguration configuration,
            IOptions<EmailSettings> emailOptions)
        {
            _context = context;
            _env = env;
            _logger = logger;
            _emailSender = emailSender;
            _configuration = configuration;
            _emailOptions = emailOptions;
        }

        public class RegisterDto
        {
            public string FullName { get; set; } = string.Empty;
            public string Email { get; set; } = string.Empty;
            public string Password { get; set; } = string.Empty;
            public string Phone { get; set; } = string.Empty;
        }

        public class LoginDto
        {
            public string Email { get; set; } = string.Empty;
            public string Password { get; set; } = string.Empty;
        }

        public sealed record LoginResponse(User User, string Token, int ExpiresInSeconds);

        public class UpdateProfileDto
        {
            public string FullName { get; set; } = string.Empty;
            public string? Phone { get; set; }
            public string? Address { get; set; }
        }

        public class ChangePasswordDto
        {
            public int UserID { get; set; }
            public string CurrentPassword { get; set; } = string.Empty;
            public string NewPassword { get; set; } = string.Empty;
        }

        public class ForgotPasswordDto
        {
            public string Email { get; set; } = string.Empty;
        }

        public class ResetPasswordDto
        {
            public string Email { get; set; } = string.Empty;
            public string Token { get; set; } = string.Empty;
            public string NewPassword { get; set; } = string.Empty;
        }

        [HttpPost("register")]
        public async Task<ActionResult<User>> Register(RegisterDto dto)
        {
            var email = (dto.Email ?? string.Empty).Trim().ToLowerInvariant();
            if (string.IsNullOrWhiteSpace(email)) return BadRequest("Email không hợp lệ.");

            var existing = await _context.Users.FirstOrDefaultAsync(u => u.Email.ToLower() == email);
            if (existing != null)
            {
                if (!existing.IsGuestAccount)
                    return BadRequest("Email đã tồn tại.");

                // Nâng tài khoản khách (đặt hàng nhanh) thành tài khoản đầy đủ.
                existing.FullName = (dto.FullName ?? string.Empty).Trim();
                existing.Phone = string.IsNullOrWhiteSpace(dto.Phone) ? null : dto.Phone.Trim();
                existing.PasswordHash = HashPassword(dto.Password);
                existing.IsGuestAccount = false;
                await _context.SaveChangesAsync();
                return Ok(existing);
            }

            var user = new User
            {
                FullName = dto.FullName,
                Email = email,
                Phone = dto.Phone,
                PasswordHash = HashPassword(dto.Password), // Simple hash for demo
                Role = "Customer",
                CreatedAt = DateTime.Now,
                IsGuestAccount = false
            };

            _context.Users.Add(user);
            await _context.SaveChangesAsync();

            return Ok(user);
        }

        [HttpPost("login")]
        public async Task<ActionResult<LoginResponse>> Login(LoginDto dto)
        {
            var emailKey = (dto.Email ?? string.Empty).Trim().ToLowerInvariant();
            var user = await _context.Users.FirstOrDefaultAsync(u => u.Email.ToLower() == emailKey);
            
            if (user == null || !VerifyPassword(dto.Password, user.PasswordHash))
            {
                return Unauthorized("Email hoặc mật khẩu không đúng. Nếu bạn chắc chắn đã nhập đúng mà vẫn không đăng nhập được, tài khoản có thể đã bị khóa hoặc không còn trên hệ thống.");
            }

            if (user.IsGuestAccount)
            {
                return Unauthorized("Đây là tài khoản đặt hàng nhanh. Kiểm tra email (link Tạo mật khẩu sau đơn) hoặc dùng Quên mật khẩu để đặt mật khẩu, rồi đăng nhập.");
            }

            if (user.IsLocked)
                return Unauthorized("Tài khoản của bạn đã bị khóa. Vui lòng liên hệ quản trị viên để được hỗ trợ.");

            var lockFile = Path.Combine(_env.ContentRootPath, "maintenance.lock");
            if (System.IO.File.Exists(lockFile))
            {
                if (!string.Equals(user.Role, "Admin", StringComparison.OrdinalIgnoreCase))
                {
                    return StatusCode(503, new { message = "Hệ thống đang bảo trì, chỉ Admin mới được đăng nhập.", isMaintenance = true });
                }
            }

            // Migrate legacy hashes to PBKDF2 on successful login.
            if (!string.IsNullOrWhiteSpace(user.PasswordHash) && !user.PasswordHash.Trim().StartsWith("pbkdf2$", StringComparison.OrdinalIgnoreCase))
            {
                user.PasswordHash = HashPasswordPbkdf2(dto.Password);
                await _context.SaveChangesAsync();
            }

            var jwt = _configuration.GetSection("Jwt").Get<JwtOptions>() ?? new JwtOptions();
            if (string.IsNullOrWhiteSpace(jwt.Key))
                return StatusCode(500, "JWT configuration missing (Jwt:Key).");

            var token = CreateJwtToken(user, jwt);
            var expiresIn = Math.Max(60, jwt.ExpMinutes * 60);
            return Ok(new LoginResponse(user, token, expiresIn));
        }

        private static string CreateJwtToken(User user, JwtOptions opt)
        {
            var key = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(opt.Key));
            var creds = new SigningCredentials(key, SecurityAlgorithms.HmacSha256);

            var claims = new List<Claim>
            {
                new(JwtRegisteredClaimNames.Sub, user.UserID.ToString()),
                new(JwtRegisteredClaimNames.Email, (user.Email ?? "").Trim()),
                new(ClaimTypes.Role, (user.Role ?? "Customer").Trim()),
                new(ClaimTypes.NameIdentifier, user.UserID.ToString()),
                new(ClaimTypes.Name, (user.FullName ?? "").Trim()),
            };

            var now = DateTime.UtcNow;
            var exp = now.AddMinutes(Math.Max(1, opt.ExpMinutes));

            var jwt = new JwtSecurityToken(
                issuer: opt.Issuer,
                audience: opt.Audience,
                claims: claims,
                notBefore: now,
                expires: exp,
                signingCredentials: creds
            );

            return new JwtSecurityTokenHandler().WriteToken(jwt);
        }

        // PUT: api/Account/5
        [Authorize]
        [HttpPut("{id}")]
        public async Task<ActionResult<User>> UpdateProfile(int id, UpdateProfileDto dto)
        {
            var claimId = User?.FindFirstValue(ClaimTypes.NameIdentifier) ?? User?.FindFirstValue("sub");
            var role = (User?.FindFirstValue(ClaimTypes.Role) ?? "").Trim().ToLowerInvariant();
            var isAdmin = role == "admin";
            if (!isAdmin && (!int.TryParse(claimId, out var authId) || authId != id))
                return Forbid();

            var user = await _context.Users.FirstOrDefaultAsync(u => u.UserID == id);
            if (user == null) return NotFound("Không tìm thấy người dùng.");

            if (string.IsNullOrWhiteSpace(dto.FullName)) return BadRequest("Họ tên đầy đủ là bắt buộc.");

            user.FullName = dto.FullName.Trim();
            user.Phone = string.IsNullOrWhiteSpace(dto.Phone) ? null : dto.Phone.Trim();
            user.Address = string.IsNullOrWhiteSpace(dto.Address) ? null : dto.Address.Trim();
            // Avatar chỉ đổi qua POST .../avatar — tránh ghi đè null khi client không gửi field

            await _context.SaveChangesAsync();
            return Ok(user);
        }

        // POST: api/Account/change-password
        [Authorize]
        [HttpPost("change-password")]
        public async Task<ActionResult> ChangePassword(ChangePasswordDto dto)
        {
            if (dto.UserID <= 0) return BadRequest("Mã người dùng không hợp lệ.");
            if (string.IsNullOrWhiteSpace(dto.CurrentPassword) || string.IsNullOrWhiteSpace(dto.NewPassword))
                return BadRequest("Vui lòng nhập đủ mật khẩu hiện tại và mật khẩu mới.");
            if (dto.NewPassword.Length < 6) return BadRequest("Mật khẩu mới phải có ít nhất 6 ký tự.");

            var claimId = User?.FindFirstValue(ClaimTypes.NameIdentifier) ?? User?.FindFirstValue("sub");
            var role = (User?.FindFirstValue(ClaimTypes.Role) ?? "").Trim().ToLowerInvariant();
            var isAdmin = role == "admin";
            if (!isAdmin && (!int.TryParse(claimId, out var authId) || authId != dto.UserID))
                return Forbid();

            var user = await _context.Users.FirstOrDefaultAsync(u => u.UserID == dto.UserID);
            if (user == null) return NotFound("Không tìm thấy người dùng.");

            if (!VerifyPassword(dto.CurrentPassword, user.PasswordHash))
                return BadRequest("Mật khẩu hiện tại không đúng.");

            user.PasswordHash = HashPassword(dto.NewPassword);
            await _context.SaveChangesAsync();
            return Ok(new { success = true });
        }

        // POST: api/Account/forgot-password
        // NOTE: This project does not have email sending yet. For dev/testing, we return a token in response.
        [HttpPost("forgot-password")]
        public async Task<ActionResult<object>> ForgotPassword([FromBody] ForgotPasswordDto dto)
        {
            var email = (dto?.Email ?? string.Empty).Trim().ToLowerInvariant();
            if (string.IsNullOrWhiteSpace(email)) return BadRequest("Vui lòng nhập email.");

            var user = await _context.Users.FirstOrDefaultAsync(u => u.Email.ToLower() == email);

            // Always return ok to avoid user enumeration
            if (user == null)
                return Ok(new { ok = true });

            var token = GenerateToken();
            var tokenHash = HashToken(token);
            var now = DateTime.UtcNow;

            // Invalidate previous unused reset-password tokens only (giữ link guest_activate sau đơn).
            var old = await _context.PasswordResetTokens
                .Where(t => t.UserID == user.UserID && t.UsedAt == null && t.ExpiresAt > now
                    && (t.Purpose == null || t.Purpose == "reset_password"))
                .ToListAsync();
            foreach (var t in old)
            {
                t.UsedAt = now;
            }

            _context.PasswordResetTokens.Add(new PasswordResetToken
            {
                UserID = user.UserID,
                TokenHash = tokenHash,
                ExpiresAt = now.AddMinutes(15),
                CreatedAt = now,
                Purpose = "reset_password"
            });

            await _context.SaveChangesAsync();

            var feBase = (_configuration["Frontend:BaseUrl"] ?? "http://localhost:5173").Trim().TrimEnd('/');
            var resetLink = $"{feBase}/reset-password?email={Uri.EscapeDataString(user.Email)}&token={Uri.EscapeDataString(token)}";

            var subject = "FreshFood - Đặt lại mật khẩu";
            var html = $"""
                <div style="font-family:Arial,Helvetica,sans-serif;line-height:1.5">
                  <h2 style="margin:0 0 8px 0">Đặt lại mật khẩu</h2>
                  <p>Bạn vừa yêu cầu đặt lại mật khẩu cho tài khoản <b>{System.Net.WebUtility.HtmlEncode(user.Email)}</b>.</p>
                  <p>Mã/link có hiệu lực trong <b>15 phút</b>.</p>
                  <p>
                    <a href="{resetLink}" style="display:inline-block;padding:10px 14px;background:#2ecc71;color:#fff;text-decoration:none;border-radius:8px">
                      Đặt lại mật khẩu
                    </a>
                  </p>
                  <p>Nếu nút không bấm được, hãy copy link sau vào trình duyệt:</p>
                  <p><a href="{resetLink}">{resetLink}</a></p>
                  <hr style="border:none;border-top:1px solid #eee;margin:16px 0"/>
                  <p style="color:#666;margin:0">Nếu bạn không yêu cầu, hãy bỏ qua email này.</p>
                </div>
                """;

            try
            {
                await _emailSender.SendAsync(user.Email, subject, html, HttpContext.RequestAborted);
                return Ok(new { ok = true });
            }
            catch (Exception ex)
            {
                // If SMTP isn't configured, allow dev to continue by returning token (optional).
                _logger.LogWarning(ex, "Failed to send reset email to {Email}.", user.Email);
                var allowReturnToken = _emailOptions.Value.DevReturnToken && _env.IsDevelopment();
                if (allowReturnToken)
                {
                    _logger.LogInformation("Password reset token for {Email}: {Token}", email, token);
                    return Ok(new { ok = true, token });
                }
                return Ok(new { ok = true });
            }
        }

        // POST: api/Account/reset-password
        [HttpPost("reset-password")]
        public async Task<ActionResult<object>> ResetPassword([FromBody] ResetPasswordDto dto)
        {
            var email = (dto?.Email ?? string.Empty).Trim().ToLowerInvariant();
            var token = (dto?.Token ?? string.Empty).Trim();
            var newPwd = dto?.NewPassword ?? string.Empty;

            if (string.IsNullOrWhiteSpace(email) || string.IsNullOrWhiteSpace(token))
                return BadRequest("Thiếu email hoặc mã đặt lại.");
            if (string.IsNullOrWhiteSpace(newPwd) || newPwd.Length < 6)
                return BadRequest("Mật khẩu mới phải có ít nhất 6 ký tự.");

            var user = await _context.Users.FirstOrDefaultAsync(u => u.Email.ToLower() == email);
            if (user == null) return BadRequest("Mã đặt lại không hợp lệ hoặc đã hết hạn.");

            var now = DateTime.UtcNow;
            var tokenHash = HashToken(token);

            var row = await _context.PasswordResetTokens
                .Where(t => t.UserID == user.UserID && t.TokenHash == tokenHash && t.UsedAt == null && t.ExpiresAt > now
                    && (t.Purpose == null || t.Purpose == "reset_password"))
                .OrderByDescending(t => t.CreatedAt)
                .FirstOrDefaultAsync();

            if (row == null) return BadRequest("Mã đặt lại không hợp lệ hoặc đã hết hạn.");

            row.UsedAt = now;
            user.PasswordHash = HashPassword(newPwd);
            await _context.SaveChangesAsync();

            return Ok(new { ok = true });
        }

        /// <summary>Đặt mật khẩu lần đầu cho tài khoản khách (sau đơn) — token Purpose = guest_activate.</summary>
        [HttpPost("set-initial-password")]
        public async Task<ActionResult<object>> SetInitialPassword([FromBody] ResetPasswordDto dto)
        {
            var email = (dto?.Email ?? string.Empty).Trim().ToLowerInvariant();
            var token = (dto?.Token ?? string.Empty).Trim();
            var newPwd = dto?.NewPassword ?? string.Empty;

            if (string.IsNullOrWhiteSpace(email) || string.IsNullOrWhiteSpace(token))
                return BadRequest("Thiếu email hoặc mã.");
            if (string.IsNullOrWhiteSpace(newPwd) || newPwd.Length < 6)
                return BadRequest("Mật khẩu phải có ít nhất 6 ký tự.");

            var user = await _context.Users.FirstOrDefaultAsync(u => u.Email.ToLower() == email);
            if (user == null || !user.IsGuestAccount)
                return BadRequest("Liên kết không hợp lệ hoặc tài khoản đã được kích hoạt.");

            var now = DateTime.UtcNow;
            var tokenHash = HashToken(token);

            var row = await _context.PasswordResetTokens
                .Where(t => t.UserID == user.UserID && t.TokenHash == tokenHash && t.UsedAt == null && t.ExpiresAt > now
                    && t.Purpose == "guest_activate")
                .OrderByDescending(t => t.CreatedAt)
                .FirstOrDefaultAsync();

            if (row == null) return BadRequest("Liên kết không hợp lệ hoặc đã hết hạn.");

            row.UsedAt = now;
            user.PasswordHash = HashPassword(newPwd);
            user.IsGuestAccount = false;
            await _context.SaveChangesAsync();

            return Ok(new { ok = true });
        }

        // POST: api/Account/5/avatar (multipart/form-data: field name "file")
        [Authorize]
        [HttpPost("{id}/avatar")]
        [Consumes("multipart/form-data")]
        public async Task<ActionResult<User>> UploadAvatar([FromRoute] int id, [FromForm] IFormFile file)
        {
            var claimId = User?.FindFirstValue(ClaimTypes.NameIdentifier) ?? User?.FindFirstValue("sub");
            var role = (User?.FindFirstValue(ClaimTypes.Role) ?? "").Trim().ToLowerInvariant();
            var isAdmin = role == "admin";
            if (!isAdmin && (!int.TryParse(claimId, out var authId) || authId != id))
                return Forbid();

            if (file == null || file.Length == 0) return BadRequest("Vui lòng chọn tệp ảnh.");
            if (file.Length > 3 * 1024 * 1024) return BadRequest("Ảnh đại diện không được vượt quá 3MB.");

            var ext = Path.GetExtension(file.FileName).ToLowerInvariant();
            var allowed = new HashSet<string> { ".jpg", ".jpeg", ".png", ".webp" };
            if (!allowed.Contains(ext)) return BadRequest("Chỉ chấp nhận định dạng jpg, jpeg, png, webp.");

            var user = await _context.Users.FirstOrDefaultAsync(u => u.UserID == id);
            if (user == null) return NotFound("Không tìm thấy người dùng.");

            // Cùng thư mục với UseStaticFiles — tránh lưu nhầm vào bin/Debug khi GetCurrentDirectory() đổi
            var avatarsDir = Path.Combine(_env.ContentRootPath, "wwwroot", "avatars");
            Directory.CreateDirectory(avatarsDir);

            var safeName = $"{id}_{DateTime.UtcNow:yyyyMMddHHmmssfff}{ext}";
            var fullPath = Path.Combine(avatarsDir, safeName);
            await using (var stream = System.IO.File.Create(fullPath))
            {
                await file.CopyToAsync(stream);
            }

            user.AvatarUrl = $"/avatars/{safeName}";
            await _context.SaveChangesAsync();

            return Ok(user);
        }

        // GET: api/Account/5 — đọc lại user từ DB (có avatarUrl sau upload)
        [HttpGet("{id:int}")]
        public async Task<ActionResult<User>> GetUser(int id)
        {
            var user = await _context.Users.AsNoTracking().FirstOrDefaultAsync(u => u.UserID == id);
            if (user == null) return NotFound("Không tìm thấy người dùng.");
            return Ok(user);
        }

        private string HashPassword(string password)
        {
            return HashPasswordPbkdf2(password);
        }

        private static bool VerifyPassword(string password, string storedHash)
        {
            var h = (storedHash ?? "").Trim();
            if (h.StartsWith("pbkdf2$", StringComparison.OrdinalIgnoreCase))
            {
                return VerifyPasswordPbkdf2(password, h);
            }

            // Legacy SHA256 hex (no salt) fallback
            return string.Equals(HashPasswordLegacySha256(password), h, StringComparison.OrdinalIgnoreCase);
        }

        private static string HashPasswordLegacySha256(string password)
        {
            using var sha256 = SHA256.Create();
            var hashedBytes = sha256.ComputeHash(Encoding.UTF8.GetBytes(password ?? ""));
            return BitConverter.ToString(hashedBytes).Replace("-", "").ToLowerInvariant();
        }

        private static string HashPasswordPbkdf2(string password)
        {
            // Format: pbkdf2$<iter>$<saltB64>$<hashB64>
            const int iter = 210_000;
            var salt = RandomNumberGenerator.GetBytes(16);
            var subkey = Rfc2898DeriveBytes.Pbkdf2(
                password: password ?? "",
                salt: salt,
                iterations: iter,
                hashAlgorithm: HashAlgorithmName.SHA256,
                outputLength: 32);

            return $"pbkdf2${iter}${Convert.ToBase64String(salt)}${Convert.ToBase64String(subkey)}";
        }

        private static bool VerifyPasswordPbkdf2(string password, string stored)
        {
            try
            {
                var parts = stored.Split('$', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries);
                // expected: ["pbkdf2", "<iter>", "<salt>", "<hash>"]
                if (parts.Length != 4) return false;
                if (!int.TryParse(parts[1], out var iter) || iter < 10_000) return false;
                var salt = Convert.FromBase64String(parts[2]);
                var expected = Convert.FromBase64String(parts[3]);
                var actual = Rfc2898DeriveBytes.Pbkdf2(
                    password: password ?? "",
                    salt: salt,
                    iterations: iter,
                    hashAlgorithm: HashAlgorithmName.SHA256,
                    outputLength: expected.Length);
                return CryptographicOperations.FixedTimeEquals(actual, expected);
            }
            catch
            {
                return false;
            }
        }

        private static string GenerateToken()
        {
            // URL-safe token
            var bytes = RandomNumberGenerator.GetBytes(32);
            return Convert.ToBase64String(bytes).Replace("+", "-").Replace("/", "_").TrimEnd('=');
        }

        private static string HashToken(string token)
        {
            using var sha256 = SHA256.Create();
            var hashedBytes = sha256.ComputeHash(Encoding.UTF8.GetBytes(token));
            return BitConverter.ToString(hashedBytes).Replace("-", "").ToLowerInvariant();
        }
    }
}
