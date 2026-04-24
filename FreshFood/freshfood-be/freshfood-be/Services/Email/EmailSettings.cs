namespace freshfood_be.Services.Email
{
    public class EmailSettings
    {
        public string Host { get; set; } = string.Empty;
        public int Port { get; set; } = 587;
        public bool UseSsl { get; set; }
        public bool IgnoreCertificateErrors { get; set; }
        public string Username { get; set; } = string.Empty;
        public string Password { get; set; } = string.Empty;
        public string FromEmail { get; set; } = string.Empty;
        public string FromName { get; set; } = "FreshFood";
        public string? ReplyToEmail { get; set; }
        public string? ReplyToName { get; set; }

        /// <summary>
        /// Nếu true, API /forgot-password sẽ trả token về client (chỉ nên bật khi dev).
        /// </summary>
        public bool DevReturnToken { get; set; }

        /// <summary>
        /// Email nhận bản sao mỗi khi có người gửi form liên hệ (tùy chọn). Để trống thì chỉ lưu DB.
        /// </summary>
        public string? ContactNotificationTo { get; set; }
    }
}

