namespace freshfood_be.Services.Momo;

public sealed class MomoOptions
{
    public string PartnerCode { get; set; } = string.Empty;
    public string AccessKey { get; set; } = string.Empty;
    public string SecretKey { get; set; } = string.Empty;

    /// <summary>Store ID shown on MoMo payment page (required for payWithMethod).</summary>
    public string StoreId { get; set; } = string.Empty;

    /// <summary>Partner name shown on MoMo payment page (optional).</summary>
    public string PartnerName { get; set; } = string.Empty;

    /// <summary>MoMo gateway create endpoint (e.g. https://test-payment.momo.vn/v2/gateway/api/create).</summary>
    public string CreateEndpoint { get; set; } = string.Empty;

    /// <summary>Backend endpoint MoMo redirects user to after payment.</summary>
    public string RedirectUrl { get; set; } = string.Empty;

    /// <summary>Backend IPN endpoint MoMo server calls.</summary>
    public string IpnUrl { get; set; } = string.Empty;

    public string FrontendReturnUrlWeb { get; set; } = string.Empty;
    public string FrontendReturnUrlApp { get; set; } = string.Empty;
}

