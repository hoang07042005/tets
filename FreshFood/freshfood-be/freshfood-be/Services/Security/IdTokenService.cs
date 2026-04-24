using System.Text;
using Microsoft.AspNetCore.DataProtection;
using Microsoft.AspNetCore.WebUtilities;

namespace freshfood_be.Services.Security;

public class IdTokenService
{
    private readonly IDataProtector _orderProtector;
    private readonly IDataProtector _productProtector;
    private readonly IDataProtector _blogPostProtector;
    private readonly IDataProtector _voucherProtector;

    public IdTokenService(IDataProtectionProvider provider)
    {
        _orderProtector = provider.CreateProtector("FreshFood.IdToken.Order.v1");
        _productProtector = provider.CreateProtector("FreshFood.IdToken.Product.v1");
        _blogPostProtector = provider.CreateProtector("FreshFood.IdToken.BlogPost.v1");
        _voucherProtector = provider.CreateProtector("FreshFood.IdToken.Voucher.v1");
    }

    public string ProtectOrderId(int id)
    {
        var protectedPayload = _orderProtector.Protect(id.ToString());
        return WebEncoders.Base64UrlEncode(Encoding.UTF8.GetBytes(protectedPayload));
    }

    public int? UnprotectOrderId(string token)
    {
        try
        {
            var raw = Encoding.UTF8.GetString(WebEncoders.Base64UrlDecode(token));
            var unprotected = _orderProtector.Unprotect(raw);
            return int.TryParse(unprotected, out var id) ? id : null;
        }
        catch
        {
            return null;
        }
    }

    public string ProtectProductId(int id)
    {
        var protectedPayload = _productProtector.Protect(id.ToString());
        return WebEncoders.Base64UrlEncode(Encoding.UTF8.GetBytes(protectedPayload));
    }

    public int? UnprotectProductId(string token)
    {
        try
        {
            var raw = Encoding.UTF8.GetString(WebEncoders.Base64UrlDecode(token));
            var unprotected = _productProtector.Unprotect(raw);
            return int.TryParse(unprotected, out var id) ? id : null;
        }
        catch
        {
            return null;
        }
    }

    public string ProtectBlogPostId(int id)
    {
        var protectedPayload = _blogPostProtector.Protect(id.ToString());
        return WebEncoders.Base64UrlEncode(Encoding.UTF8.GetBytes(protectedPayload));
    }

    public int? UnprotectBlogPostId(string token)
    {
        try
        {
            var raw = Encoding.UTF8.GetString(WebEncoders.Base64UrlDecode(token));
            var unprotected = _blogPostProtector.Unprotect(raw);
            return int.TryParse(unprotected, out var id) ? id : null;
        }
        catch
        {
            return null;
        }
    }

    public string ProtectVoucherId(int id)
    {
        var protectedPayload = _voucherProtector.Protect(id.ToString());
        return WebEncoders.Base64UrlEncode(Encoding.UTF8.GetBytes(protectedPayload));
    }

    public int? UnprotectVoucherId(string token)
    {
        try
        {
            var raw = Encoding.UTF8.GetString(WebEncoders.Base64UrlDecode(token));
            var unprotected = _voucherProtector.Unprotect(raw);
            return int.TryParse(unprotected, out var id) ? id : null;
        }
        catch
        {
            return null;
        }
    }
}

