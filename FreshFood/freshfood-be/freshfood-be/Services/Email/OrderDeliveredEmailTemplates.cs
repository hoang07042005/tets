using System.Net;

namespace freshfood_be.Services.Email;

/// <summary>Email khi đơn chuyển sang Đã giao hàng — một lần, kèm nút mở trang chi tiết để bấm &quot;Nhận hàng&quot;.</summary>
public static class OrderDeliveredEmailTemplates
{
    public static string Subject(string orderCode) =>
        $"FreshFood — Đơn {orderCode} đã giao đến bạn";

    /// <param name="orderDetailUrlAbsolute">URL FE, nên kèm fragment <c>#xac-nhan-nhan-hang</c> để cuộn tới nút nhận hàng.</param>
    public static string BuildHtml(string safeCustomerName, string safeOrderCode, string orderDetailUrlAbsolute)
    {
        var safeUrl = WebUtility.HtmlEncode(orderDetailUrlAbsolute);
        return $"""
            <!DOCTYPE html>
            <html lang="vi">
            <head><meta charset="utf-8"/></head>
            <body style="margin:0;padding:0;background:#f4f6f5;font-family:Segoe UI,Arial,Helvetica,sans-serif;color:#0f172a">
              <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="padding:24px 12px">
                <tr>
                  <td align="center">
                    <table role="presentation" width="560" cellspacing="0" cellpadding="0" style="max-width:560px;width:100%;background:#fff;border-radius:14px;padding:28px 24px;box-shadow:0 4px 24px rgba(15,23,42,0.06)">
                      <tr>
                        <td>
                          <h1 style="margin:0 0 12px;font-size:22px;font-weight:800;color:#111827">Đơn hàng đã được giao</h1>
                          <p style="margin:0 0 16px;font-size:15px;line-height:1.6;color:#334155">
                            Xin chào <b>{safeCustomerName}</b>,
                          </p>
                          <p style="margin:0 0 16px;font-size:15px;line-height:1.6;color:#334155">
                            Đơn <b>{safeOrderCode}</b> đã được giao. Vui lòng kiểm tra hàng và <b>xác nhận đã nhận</b> trên website để chúng tôi hoàn tất đơn.
                          </p>
                          <p style="margin:20px 0 8px">
                            <a href="{orderDetailUrlAbsolute}" style="display:inline-block;background:#2ecc71;color:#fff;text-decoration:none;font-weight:800;font-size:15px;padding:14px 26px;border-radius:12px">
                              Xác nhận
                            </a>
                          </p>
                          <p style="margin:0 0 8px;font-size:13px;color:#64748b;line-height:1.5">
                            Sau khi mở trang đơn hàng, hãy nhấn nút <b style="color:#0f172a">Nhận hàng</b> ở cột bên phải.
                          </p>
                          <p style="margin:16px 0 0;font-size:12px;color:#94a3b8;line-height:1.5">
                            Nếu nút không hoạt động:
                            <a href="{orderDetailUrlAbsolute}" style="color:#27ae60;display:inline-block;max-width:520px;overflow-wrap:anywhere;word-break:break-word">{safeUrl}</a>
                          </p>
                          <hr style="border:none;border-top:1px solid #e5e7eb;margin:22px 0"/>
                          <p style="margin:0;font-size:12px;color:#94a3b8">Email tự động từ FreshFood.</p>
                        </td>
                      </tr>
                    </table>
                  </td>
                </tr>
              </table>
            </body>
            </html>
            """;
    }
}
