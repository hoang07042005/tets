using System.Net;
using Microsoft.Extensions.Options;

namespace freshfood_be.Services.VnPay;

public sealed class VnPayService
{
    private readonly VnPayOptions _opt;

    public VnPayService(IOptions<VnPayOptions> opt)
    {
        _opt = opt.Value;
    }

    public string CreatePaymentUrl(
        long orderId,
        decimal amountVnd,
        string ipAddress,
        string? bankCode = null,
        string locale = "vn",
        string? returnUrlOverride = null)
    {
        var vnp = new VnPayLibrary();

        vnp.AddRequestData("vnp_Version", VnPayLibrary.VERSION);
        vnp.AddRequestData("vnp_Command", "pay");
        vnp.AddRequestData("vnp_TmnCode", _opt.TmnCode);
        vnp.AddRequestData("vnp_Amount", ToVnPayAmount(amountVnd));
        vnp.AddRequestData("vnp_CreateDate", DateTime.Now.ToString("yyyyMMddHHmmss"));
        vnp.AddRequestData("vnp_CurrCode", "VND");
        vnp.AddRequestData("vnp_IpAddr", string.IsNullOrWhiteSpace(ipAddress) ? "127.0.0.1" : ipAddress);
        vnp.AddRequestData("vnp_Locale", string.IsNullOrWhiteSpace(locale) ? "vn" : locale);
        vnp.AddRequestData("vnp_OrderInfo", $"Thanh toan don hang: {orderId}");
        vnp.AddRequestData("vnp_OrderType", "other");
        vnp.AddRequestData("vnp_ReturnUrl", string.IsNullOrWhiteSpace(returnUrlOverride) ? _opt.ReturnUrl : returnUrlOverride!);
        vnp.AddRequestData("vnp_TxnRef", orderId.ToString());

        if (!string.IsNullOrWhiteSpace(bankCode))
        {
            vnp.AddRequestData("vnp_BankCode", bankCode);
        }

        return vnp.CreateRequestUrl(_opt.BaseUrl, _opt.HashSecret);
    }

    public bool ValidateSignature(IDictionary<string, string?> query, out string responseCode)
    {
        responseCode = query.TryGetValue("vnp_ResponseCode", out var rc) ? (rc ?? "") : "";
        if (!query.TryGetValue("vnp_SecureHash", out var hash) || string.IsNullOrWhiteSpace(hash))
            return false;

        var vnp = new VnPayLibrary();
        foreach (var (k, v) in query)
        {
            if (string.IsNullOrWhiteSpace(k) || v == null) continue;
            if (!k.StartsWith("vnp_", StringComparison.OrdinalIgnoreCase)) continue;
            vnp.AddResponseData(k, v);
        }

        return vnp.ValidateSignature(hash, _opt.HashSecret);
    }

    public string FrontendReturnUrlWeb => _opt.FrontendReturnUrlWeb;
    public string FrontendReturnUrlApp => _opt.FrontendReturnUrlApp;

    private static string ToVnPayAmount(decimal amountVnd)
    {
        // VNPay expects amount * 100, no separators
        var v = decimal.Round(amountVnd, 0, MidpointRounding.AwayFromZero);
        var scaled = (long)(v * 100);
        return scaled.ToString();
    }
}

