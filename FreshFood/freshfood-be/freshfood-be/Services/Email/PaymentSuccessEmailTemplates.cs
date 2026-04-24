using System.Globalization;
using System.Net;
using System.Text;

namespace freshfood_be.Services.Email;

/// <summary>Email HTML “Thanh toán thành công” (VNPay / cổng online) — layout gần mockup, inline CSS cho client mail.</summary>
public static class PaymentSuccessEmailTemplates
{
    public sealed record Line(string ProductNameSafe, int Quantity, string LineTotalFormatted, string? ImageUrlAbsolute);

    public static string Subject(string orderCode) =>
        $"FreshFood — Thanh toán thành công · {orderCode}";

    public static string SubjectOrderPlaced(string orderCode) =>
        $"FreshFood — Đã nhận đơn hàng · {orderCode}";

    /// <summary>Gửi URL logo &amp; ảnh SP đã là absolute (https…).</summary>
    public static string BuildHtml(
        string logoUrlAbsolute,
        string safeCustomerName,
        string safeOrderCode,
        string orderDateDisplay,
        string paymentMethodVi,
        IReadOnlyList<Line> lines,
        string safeShippingAddress,
        string? estimatedDeliveryLine,
        string subtotalFormatted,
        string shippingFormatted,
        string taxFormatted,
        string totalFormatted,
        string trackOrderUrlAbsolute,
        string mainHeading = "Thanh toán thành công",
        string statusBadgeText = "Đã xác nhận thanh toán",
        string statusDotColor = "#22c55e",
        string totalsCardTitle = "TỔNG KẾT THANH TOÁN",
        string? footerItalic = null)
    {
        var safeTrack = WebUtility.HtmlEncode(trackOrderUrlAbsolute);
        var footerText = string.IsNullOrWhiteSpace(footerItalic)
            ? "Chúng tôi sẽ gửi thông báo cho bạn khi đơn hàng bắt đầu được vận chuyển."
            : footerItalic.Trim();
        var sb = new StringBuilder();
        foreach (var line in lines)
        {
            var img = string.IsNullOrWhiteSpace(line.ImageUrlAbsolute)
                ? "<td style=\"width:72px;vertical-align:top;padding:0 12px 0 0\"><div style=\"width:64px;height:64px;border-radius:10px;background:#e8f5e9;border:1px solid #c8e6c9\"></div></td>"
                : $"<td style=\"width:72px;vertical-align:top;padding:0 12px 0 0\"><img src=\"{WebUtility.HtmlEncode(line.ImageUrlAbsolute)}\" alt=\"\" width=\"64\" height=\"64\" style=\"display:block;border-radius:10px;object-fit:cover;border:1px solid #e5e7eb\" /></td>";

            sb.Append(CultureInfo.InvariantCulture, $"""
                <tr>
                  {img}
                  <td style="vertical-align:top;padding:4px 0">
                    <div style="font-weight:700;color:#0f172a;font-size:15px">{line.ProductNameSafe}</div>
                    <div style="font-size:13px;color:#64748b;margin-top:4px">Số lượng: {line.Quantity:00}</div>
                  </td>
                  <td style="vertical-align:top;text-align:right;white-space:nowrap;padding:4px 0 0 8px;font-weight:700;color:#0f172a">{line.LineTotalFormatted}</td>
                </tr>
                """);
        }

        var deliveryBlock = string.IsNullOrWhiteSpace(estimatedDeliveryLine)
            ? ""
            : $"""
              <p style="margin:10px 0 0 0;font-size:14px;color:#334155">
                <span style="display:inline-block;width:18px;text-align:center">🕐</span> {WebUtility.HtmlEncode(estimatedDeliveryLine)}
              </p>
              """;

        return $"""
            <!DOCTYPE html>
            <html lang="vi">
            <head><meta charset="utf-8"/><meta name="viewport" content="width=device-width,initial-scale=1"/></head>
            <body style="margin:0;padding:0;background:#f0f4f1;font-family:Segoe UI,Arial,Helvetica,sans-serif;color:#0f172a">
              <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="background:#f0f4f1;padding:24px 12px">
                <tr>
                  <td align="center">
                    <table role="presentation" width="600" cellspacing="0" cellpadding="0" style="max-width:600px;width:100%;background:#ffffff;border-radius:16px;overflow:hidden;box-shadow:0 4px 24px rgba(15,23,42,0.08)">
                      <tr>
                        <td style="padding:28px 28px 8px 28px;text-align:center">
                          <img src="{WebUtility.HtmlEncode(logoUrlAbsolute)}" alt="FreshFood" style="display:inline-block;vertical-align:middle;border:0;max-height:56px;width:auto;height:auto"/>
                          <div style="margin-top:8px;font-size:18px;font-weight:800;color:#2ecc71;letter-spacing:-0.02em">FreshFood</div>
                        </td>
                      </tr>
                      <tr>
                        <td style="padding:8px 28px 20px 28px">
                          <h1 style="margin:0 0 14px 0;font-size:26px;font-weight:800;color:#0f172a;line-height:1.2">{WebUtility.HtmlEncode(mainHeading)}</h1>
                          <p style="margin:0;font-size:15px;line-height:1.65;color:#334155">
                            Chào <b>{safeCustomerName}</b>,<br/>
                            Cảm ơn bạn đã lựa chọn thực phẩm sạch tại <b>FreshFood</b>! Đơn hàng của bạn đang được chúng tôi chuẩn bị với sự tận tâm nhất.
                          </p>
                        </td>
                      </tr>
                      <tr>
                        <td style="padding:0 28px 20px 28px">
                          <table role="presentation" width="100%" cellspacing="0" cellpadding="0">
                            <tr>
                              <td width="50%" valign="top" style="padding-right:8px">
                                <div style="background:#f5f5f5;border-radius:12px;padding:16px 18px">
                                  <div style="font-size:11px;font-weight:700;color:#64748b;letter-spacing:0.06em">CHI TIẾT ĐƠN HÀNG</div>
                                  <div style="margin-top:8px;font-size:20px;font-weight:800;color:#0f172a">#{safeOrderCode}</div>
                                  <div style="margin-top:6px;font-size:14px;color:#475569">Ngày đặt: {WebUtility.HtmlEncode(orderDateDisplay)}</div>
                                </div>
                              </td>
                              <td width="50%" valign="top" style="padding-left:8px">
                                <div style="background:#f5f5f5;border-radius:12px;padding:16px 18px">
                                  <div style="font-size:11px;font-weight:700;color:#64748b;letter-spacing:0.06em">TRẠNG THÁI</div>
                                  <div style="margin-top:10px;font-size:15px;font-weight:700;color:#2ecc71">
                                    <span style="display:inline-block;width:10px;height:10px;background:{statusDotColor};border-radius:50%;vertical-align:middle;margin-right:8px"></span>
                                    {WebUtility.HtmlEncode(statusBadgeText)}
                                  </div>
                                  <div style="margin-top:14px;font-size:11px;font-weight:700;color:#0d9488;letter-spacing:0.06em">HÌNH THỨC THANH TOÁN</div>
                                  <div style="margin-top:6px;font-size:14px;color:#0f172a;font-weight:600">{paymentMethodVi}</div>
                                </div>
                              </td>
                            </tr>
                          </table>
                        </td>
                      </tr>
                      <tr>
                        <td style="padding:0 28px 16px 28px">
                          <div style="font-size:17px;font-weight:800;color:#0f172a;margin-bottom:12px">
                            <span style="margin-right:8px">🍴</span>Giỏ hàng của bạn
                          </div>
                          <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="background:#fafafa;border-radius:12px;border:1px solid #eef0f2">
                            <tr><td style="padding:16px">
                              <table role="presentation" width="100%" cellspacing="0" cellpadding="0">
                                {sb}
                              </table>
                            </td></tr>
                          </table>
                        </td>
                      </tr>
                      <tr>
                        <td style="padding:0 28px 24px 28px">
                          <table role="presentation" width="100%" cellspacing="0" cellpadding="0">
                            <tr>
                              <td width="52%" valign="top" style="padding-right:10px">
                                <div style="font-size:11px;font-weight:800;color:#0d9488;letter-spacing:0.06em;margin-bottom:8px">THÔNG TIN GIAO HÀNG</div>
                                <p style="margin:0;font-size:14px;line-height:1.55;color:#334155">
                                  <span style="display:inline-block;width:18px">📍</span> {safeShippingAddress}
                                </p>
                                {deliveryBlock}
                              </td>
                              <td width="48%" valign="top" style="padding-left:10px">
                                <div style="background:#f5f5f5;border-radius:12px;padding:16px 18px">
                                  <div style="font-size:14px;font-weight:800;color:#0f172a;margin-bottom:12px">{WebUtility.HtmlEncode(totalsCardTitle)}</div>
                                  <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="font-size:14px;color:#475569">
                                    <tr><td>Tạm tính</td><td align="right" style="padding-bottom:8px">{subtotalFormatted}</td></tr>
                                    <tr><td>Phí vận chuyển</td><td align="right" style="padding-bottom:8px">{shippingFormatted}</td></tr>
                                    <tr><td>Thuế (1,5%)</td><td align="right" style="padding-bottom:12px">{taxFormatted}</td></tr>
                                    <tr><td colspan="2" style="border-top:1px solid #e5e7eb;padding-top:12px"></td></tr>
                                    <tr><td style="font-weight:800;color:#0f172a">Tổng cộng</td><td align="right" style="font-size:18px;font-weight:800;color:#2ecc71">{totalFormatted}</td></tr>
                                  </table>
                                </div>
                              </td>
                            </tr>
                          </table>
                        </td>
                      </tr>
                      <tr>
                        <td style="padding:0 28px 28px 28px;text-align:center">
                          <a href="{trackOrderUrlAbsolute}" style="display:inline-block;background:#2ecc71;color:#ffffff;text-decoration:none;font-weight:700;font-size:15px;padding:14px 28px;border-radius:12px">
                            🚚 Theo dõi đơn hàng
                          </a>
                          <p style="margin:18px 0 0 0;font-size:13px;color:#64748b;font-style:italic;line-height:1.5">
                            {WebUtility.HtmlEncode(footerText)}
                          </p>
                          <p style="margin:16px 0 0 0;font-size:12px;color:#94a3b8;line-height:1.5">
                            Nếu nút không hoạt động, mở liên kết:
                            <a href="{trackOrderUrlAbsolute}" style="color:#27ae60;display:inline-block;max-width:520px;overflow-wrap:anywhere;word-break:break-word">{safeTrack}</a>
                          </p>
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
