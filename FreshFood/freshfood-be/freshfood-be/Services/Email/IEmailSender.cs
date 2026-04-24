namespace freshfood_be.Services.Email
{
    public interface IEmailSender
    {
        Task SendAsync(string toEmail, string subject, string htmlBody, CancellationToken ct = default);

        /// <summary>Gửi HTML kèm ảnh nhúng (multipart/related). <paramref name="linkedResources"/> có thể null.</summary>
        Task SendAsync(string toEmail, string subject, string htmlBody, IReadOnlyList<EmailLinkedResource>? linkedResources, CancellationToken ct);
    }
}

