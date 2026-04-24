namespace freshfood_be.Services.VnPay;

public sealed class VnPayOptions
{
    public string TmnCode { get; set; } = string.Empty;
    public string HashSecret { get; set; } = string.Empty;
    public string BaseUrl { get; set; } = string.Empty;
    public string ReturnUrl { get; set; } = string.Empty;
    public string IpnUrl { get; set; } = string.Empty;
    public string FrontendReturnUrlWeb { get; set; } = string.Empty;
    public string FrontendReturnUrlApp { get; set; } = string.Empty;
}

