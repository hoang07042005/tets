using MailKit.Net.Smtp;
using MailKit.Security;
using Microsoft.Extensions.Options;
using MimeKit;

namespace freshfood_be.Services.Email
{
    public class SmtpEmailSender : IEmailSender
    {
        private readonly EmailSettings _settings;
        private readonly ILogger<SmtpEmailSender> _logger;

        public SmtpEmailSender(IOptions<EmailSettings> options, ILogger<SmtpEmailSender> logger)
        {
            _settings = options.Value;
            _logger = logger;
        }

        public Task SendAsync(string toEmail, string subject, string htmlBody, CancellationToken ct = default) =>
            SendAsync(toEmail, subject, htmlBody, null, ct);

        public async Task SendAsync(string toEmail, string subject, string htmlBody, IReadOnlyList<EmailLinkedResource>? linkedResources, CancellationToken ct)
        {
            if (string.IsNullOrWhiteSpace(_settings.Host) || string.IsNullOrWhiteSpace(_settings.FromEmail))
                throw new InvalidOperationException("SMTP chưa được cấu hình (Email:Host / Email:FromEmail).");

            var message = new MimeMessage();
            message.From.Add(new MailboxAddress(_settings.FromName ?? "FreshFood", _settings.FromEmail));
            message.To.Add(MailboxAddress.Parse(toEmail));
            message.Subject = subject;
            if (!string.IsNullOrWhiteSpace(_settings.ReplyToEmail))
            {
                message.ReplyTo.Add(new MailboxAddress(_settings.ReplyToName ?? _settings.FromName ?? "FreshFood", _settings.ReplyToEmail.Trim()));
            }

            var builder = new BodyBuilder { HtmlBody = htmlBody };
            if (linkedResources is { Count: > 0 })
            {
                foreach (var r in linkedResources)
                {
                    var stream = new MemoryStream(r.Content, writable: false);
                    var part = builder.LinkedResources.Add(r.FileName, stream, ContentType.Parse(r.ContentType));
                    part.ContentId = r.ContentId;
                    part.ContentDisposition = new ContentDisposition(ContentDisposition.Inline);
                }
            }

            message.Body = builder.ToMessageBody();

            using var client = new SmtpClient();
            client.Timeout = 15000;
            if (_settings.IgnoreCertificateErrors)
            {
                // Dev-only escape hatch for environments missing root/intermediate certs.
                client.ServerCertificateValidationCallback = (_, _, _, _) => true;
            }

            // Port 587 should use STARTTLS (not "when available") to avoid downgrade/mismatch issues.
            var secure = _settings.UseSsl ? SecureSocketOptions.SslOnConnect : SecureSocketOptions.StartTls;
            await client.ConnectAsync(_settings.Host, _settings.Port, secure, ct);

            if (!string.IsNullOrWhiteSpace(_settings.Username))
            {
                await client.AuthenticateAsync(_settings.Username, _settings.Password, ct);
            }

            await client.SendAsync(message, ct);
            await client.DisconnectAsync(true, ct);

            _logger.LogInformation("Sent email to {ToEmail} subject={Subject}", toEmail, subject);
        }
    }
}

