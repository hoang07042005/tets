using System.Globalization;
using System.Net;
using System.Security.Cryptography;
using System.Text;

namespace freshfood_be.Services.VnPay;

public sealed class VnPayLibrary
{
    public const string VERSION = "2.1.0";
    private readonly SortedList<string, string> _requestData = new(new VnPayCompare());
    private readonly SortedList<string, string> _responseData = new(new VnPayCompare());

    public void AddRequestData(string key, string value)
    {
        if (!string.IsNullOrWhiteSpace(value)) _requestData[key] = value;
    }

    public void AddResponseData(string key, string value)
    {
        if (!string.IsNullOrWhiteSpace(value)) _responseData[key] = value;
    }

    public string CreateRequestUrl(string baseUrl, string hashSecret)
    {
        var data = new StringBuilder();
        foreach (var kv in _requestData)
        {
            if (!string.IsNullOrEmpty(kv.Value))
            {
                data.Append(WebUtility.UrlEncode(kv.Key))
                    .Append('=')
                    .Append(WebUtility.UrlEncode(kv.Value))
                    .Append('&');
            }
        }

        var queryString = data.ToString();
        var signData = queryString.Length > 0 ? queryString[..^1] : string.Empty; // remove trailing '&'
        var secureHash = Utils.HmacSHA512(hashSecret, signData);

        return $"{baseUrl}?{queryString}vnp_SecureHash={secureHash}";
    }

    public bool ValidateSignature(string inputHash, string secretKey)
    {
        var rspRaw = GetResponseDataRaw();
        var myChecksum = Utils.HmacSHA512(secretKey, rspRaw);
        return myChecksum.Equals(inputHash, StringComparison.InvariantCultureIgnoreCase);
    }

    private string GetResponseDataRaw()
    {
        var data = new StringBuilder();

        _responseData.Remove("vnp_SecureHashType");
        _responseData.Remove("vnp_SecureHash");

        foreach (var kv in _responseData)
        {
            if (!string.IsNullOrEmpty(kv.Value))
            {
                data.Append(WebUtility.UrlEncode(kv.Key))
                    .Append('=')
                    .Append(WebUtility.UrlEncode(kv.Value))
                    .Append('&');
            }
        }

        if (data.Length > 0) data.Length -= 1;
        return data.ToString();
    }
}

public static class Utils
{
    public static string HmacSHA512(string key, string inputData)
    {
        var hash = new StringBuilder();
        var keyBytes = Encoding.UTF8.GetBytes(key);
        var inputBytes = Encoding.UTF8.GetBytes(inputData ?? string.Empty);
        using var hmac = new HMACSHA512(keyBytes);
        var hashValue = hmac.ComputeHash(inputBytes);
        foreach (var b in hashValue) hash.Append(b.ToString("x2"));
        return hash.ToString();
    }
}

public sealed class VnPayCompare : IComparer<string>
{
    public int Compare(string? x, string? y)
    {
        if (x == y) return 0;
        if (x == null) return -1;
        if (y == null) return 1;
        var vnpCompare = CompareInfo.GetCompareInfo("en-US");
        return vnpCompare.Compare(x, y, CompareOptions.Ordinal);
    }
}

