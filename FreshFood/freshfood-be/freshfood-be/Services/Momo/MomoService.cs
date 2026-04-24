using System.Net.Http.Json;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json.Serialization;
using Microsoft.Extensions.Options;

namespace freshfood_be.Services.Momo;

public sealed class MomoService
{
    private readonly MomoOptions _opt;
    private readonly IHttpClientFactory _httpClientFactory;

    public MomoService(IOptions<MomoOptions> opt, IHttpClientFactory httpClientFactory)
    {
        _opt = opt.Value;
        _httpClientFactory = httpClientFactory;
    }

    public sealed record CreatePaymentUrlResult(
        string OrderId,
        string RequestId,
        string? PayUrl,
        string? Deeplink,
        string? QrCodeUrl,
        int ResultCode,
        string? Message);

    public enum MomoPayMethod
    {
        /// <summary>MoMo-hosted "choose payment method" page (Wallet/ATM/Credit...).</summary>
        Method,
        /// <summary>Direct MoMo wallet flow.</summary>
        Wallet,
        /// <summary>Direct ATM flow.</summary>
        Atm
    }

    public async Task<CreatePaymentUrlResult> CreatePaymentUrlAsync(
        long orderId,
        decimal amountVnd,
        MomoPayMethod payMethod = MomoPayMethod.Wallet,
        string? orderInfo = null,
        string? redirectUrlOverride = null,
        CancellationToken ct = default)
    {
        var requestId = Guid.NewGuid().ToString("N");
        // MoMo requires orderId to be unique per transaction; if user retries payment for the same internal order,
        // using the same orderId will be rejected (resultCode=41).
        // Keep internal mapping via extraData.
        var internalOrderIdStr = orderId.ToString();
        var momoOrderId = $"{internalOrderIdStr}-{requestId}";
        var amount = (long)decimal.Round(amountVnd, 0, MidpointRounding.AwayFromZero);
        var info = string.IsNullOrWhiteSpace(orderInfo) ? $"Thanh toan don hang: {internalOrderIdStr}" : orderInfo.Trim();
        var extraData = Convert.ToBase64String(Encoding.UTF8.GetBytes($"orderId={internalOrderIdStr}"));
        var requestType = payMethod switch
        {
            MomoPayMethod.Atm => "payWithATM",
            MomoPayMethod.Wallet => "captureWallet",
            _ => "payWithMethod"
        };

        var req = new CreateRequest
        {
            PartnerCode = _opt.PartnerCode,
            AccessKey = _opt.AccessKey,
            PartnerName = _opt.PartnerName,
            StoreId = _opt.StoreId,
            RequestId = requestId,
            Amount = amount,
            OrderId = momoOrderId,
            OrderInfo = info,
            RedirectUrl = string.IsNullOrWhiteSpace(redirectUrlOverride) ? _opt.RedirectUrl : redirectUrlOverride!,
            IpnUrl = _opt.IpnUrl,
            ExtraData = extraData,
            RequestType = requestType,
            Lang = "vi",
            AutoCapture = true
        };

        req.Signature = SignCreate(req, _opt.SecretKey);

        var http = _httpClientFactory.CreateClient("momo");
        using var resp = await http.PostAsJsonAsync(_opt.CreateEndpoint, req, ct).ConfigureAwait(false);
        var body = await resp.Content.ReadFromJsonAsync<CreateResponse>(cancellationToken: ct).ConfigureAwait(false);

        if (body == null)
        {
            return new CreatePaymentUrlResult(internalOrderIdStr, requestId, null, null, null, -1, "Empty response from MoMo.");
        }

        return new CreatePaymentUrlResult(
            // Return internal orderId for the app
            OrderId: internalOrderIdStr,
            RequestId: body.RequestId ?? requestId,
            PayUrl: body.PayUrl,
            Deeplink: body.Deeplink,
            QrCodeUrl: body.QrCodeUrl,
            ResultCode: body.ResultCode,
            Message: body.Message);
    }

    public bool ValidateReturnOrIpnSignature(MomoCallback data)
    {
        // MoMo requires raw string built by sorting keys alphabetically (a-z).
        // For callback signature fields can vary, but the core set is typically:
        // accessKey, amount, extraData, message, orderId, orderInfo, orderType, partnerCode,
        // payType, requestId, responseTime, resultCode, transId.
        // We'll validate using the keys we have (non-null), excluding signature itself.
        var dict = new SortedDictionary<string, string>(StringComparer.Ordinal);

        Add(dict, "accessKey", _opt.AccessKey); // accessKey is not always included in callback, but present in signature spec.
        Add(dict, "amount", data.Amount?.ToString());
        Add(dict, "extraData", data.ExtraData);
        Add(dict, "message", data.Message);
        Add(dict, "orderId", data.OrderId);
        Add(dict, "orderInfo", data.OrderInfo);
        Add(dict, "orderType", data.OrderType);
        Add(dict, "partnerCode", data.PartnerCode);
        Add(dict, "payType", data.PayType);
        Add(dict, "requestId", data.RequestId);
        Add(dict, "responseTime", data.ResponseTime?.ToString());
        Add(dict, "resultCode", data.ResultCode?.ToString());
        Add(dict, "transId", data.TransId?.ToString());

        var raw = string.Join("&", dict.Select(kv => $"{kv.Key}={kv.Value}"));
        var sig = HmacSha256Hex(raw, _opt.SecretKey);
        return string.Equals(sig, (data.Signature ?? "").Trim(), StringComparison.OrdinalIgnoreCase);
    }

    public string FrontendReturnUrlWeb => _opt.FrontendReturnUrlWeb;
    public string FrontendReturnUrlApp => _opt.FrontendReturnUrlApp;

    private static void Add(IDictionary<string, string> dict, string key, string? value)
    {
        if (string.IsNullOrWhiteSpace(value)) return;
        dict[key] = value;
    }

    private static string SignCreate(CreateRequest req, string secretKey)
    {
        // Required by MoMo create endpoint for captureWallet:
        // accessKey, amount, extraData, ipnUrl, orderId, orderInfo, partnerCode, redirectUrl, requestId, requestType
        var raw =
            $"accessKey={req.AccessKey}" +
            $"&amount={req.Amount}" +
            $"&extraData={req.ExtraData}" +
            $"&ipnUrl={req.IpnUrl}" +
            $"&orderId={req.OrderId}" +
            $"&orderInfo={req.OrderInfo}" +
            $"&partnerCode={req.PartnerCode}" +
            $"&redirectUrl={req.RedirectUrl}" +
            $"&requestId={req.RequestId}" +
            $"&requestType={req.RequestType}";

        return HmacSha256Hex(raw, secretKey);
    }

    private static string HmacSha256Hex(string raw, string secretKey)
    {
        var keyBytes = Encoding.UTF8.GetBytes(secretKey ?? "");
        var msgBytes = Encoding.UTF8.GetBytes(raw ?? "");
        using var hmac = new HMACSHA256(keyBytes);
        var hash = hmac.ComputeHash(msgBytes);
        return Convert.ToHexString(hash).ToLowerInvariant();
    }

    private sealed class CreateRequest
    {
        [JsonPropertyName("partnerCode")]
        public string PartnerCode { get; set; } = string.Empty;

        [JsonPropertyName("accessKey")]
        public string AccessKey { get; set; } = string.Empty;

        [JsonPropertyName("partnerName")]
        public string? PartnerName { get; set; }

        [JsonPropertyName("storeId")]
        public string? StoreId { get; set; }

        [JsonPropertyName("requestId")]
        public string RequestId { get; set; } = string.Empty;

        [JsonPropertyName("amount")]
        public long Amount { get; set; }

        [JsonPropertyName("orderId")]
        public string OrderId { get; set; } = string.Empty;

        [JsonPropertyName("orderInfo")]
        public string OrderInfo { get; set; } = string.Empty;

        [JsonPropertyName("redirectUrl")]
        public string RedirectUrl { get; set; } = string.Empty;

        [JsonPropertyName("ipnUrl")]
        public string IpnUrl { get; set; } = string.Empty;

        [JsonPropertyName("extraData")]
        public string ExtraData { get; set; } = string.Empty;

        [JsonPropertyName("requestType")]
        public string RequestType { get; set; } = "captureWallet";

        [JsonPropertyName("signature")]
        public string Signature { get; set; } = string.Empty;

        [JsonPropertyName("lang")]
        public string? Lang { get; set; }

        [JsonPropertyName("autoCapture")]
        public bool? AutoCapture { get; set; }
    }

    private sealed class CreateResponse
    {
        [JsonPropertyName("resultCode")]
        public int ResultCode { get; set; }

        [JsonPropertyName("message")]
        public string? Message { get; set; }

        [JsonPropertyName("payUrl")]
        public string? PayUrl { get; set; }

        [JsonPropertyName("deeplink")]
        public string? Deeplink { get; set; }

        [JsonPropertyName("qrCodeUrl")]
        public string? QrCodeUrl { get; set; }

        [JsonPropertyName("orderId")]
        public string? OrderId { get; set; }

        [JsonPropertyName("requestId")]
        public string? RequestId { get; set; }
    }
}

public sealed class MomoCallback
{
    [JsonPropertyName("partnerCode")]
    public string? PartnerCode { get; set; }

    [JsonPropertyName("orderId")]
    public string? OrderId { get; set; }

    [JsonPropertyName("requestId")]
    public string? RequestId { get; set; }

    [JsonPropertyName("amount")]
    public long? Amount { get; set; }

    [JsonPropertyName("orderInfo")]
    public string? OrderInfo { get; set; }

    [JsonPropertyName("orderType")]
    public string? OrderType { get; set; }

    [JsonPropertyName("transId")]
    public long? TransId { get; set; }

    [JsonPropertyName("resultCode")]
    public int? ResultCode { get; set; }

    [JsonPropertyName("message")]
    public string? Message { get; set; }

    [JsonPropertyName("payType")]
    public string? PayType { get; set; }

    [JsonPropertyName("responseTime")]
    public long? ResponseTime { get; set; }

    [JsonPropertyName("extraData")]
    public string? ExtraData { get; set; }

    [JsonPropertyName("signature")]
    public string? Signature { get; set; }
}

