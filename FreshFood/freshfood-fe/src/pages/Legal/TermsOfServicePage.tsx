import { Link } from 'react-router-dom';

type TocItem = { id: string; label: string; num: string };

const toc: TocItem[] = [
  { id: 'gioi-thieu-chung', label: 'Giới thiệu chung', num: '01' },
  { id: 'tai-khoan-nguoi-dung', label: 'Tài khoản người dùng', num: '02' },
  { id: 'chinh-sach-mua-hang', label: 'Chính sách mua hàng', num: '03' },
  { id: 'thanh-toan', label: 'Thanh toán', num: '04' },
  { id: 'giao-nhan', label: 'Giao nhận', num: '05' },
  { id: 'doi-tra-boi-thuong', label: 'Đổi trả và bồi thường', num: '06' },
  { id: 'quyen-so-huu-tri-tue', label: 'Quyền sở hữu trí tuệ', num: '07' },
];

export function TermsOfServicePage() {
  return (
    <div className="legal2">
      <div className="container legal2-shell">
        <div className="legal2-hero">
          <div className="legal2-hero-badge">CHÍNH SÁCH / DỊCH VỤ</div>
          <div className="legal2-hero-top">
            <div>
              <h1 className="legal2-title">Điều khoản dịch vụ</h1>
              <p className="legal2-sub">
                Chào mừng bạn đến với FreshFood. Việc bạn sử dụng dịch vụ của chúng tôi đồng nghĩa với việc bạn đồng ý với
                các điều khoản dưới đây nhằm đảm bảo trải nghiệm minh bạch và an toàn.
              </p>
            </div>

            <div className="legal2-meta">
              <div className="legal2-meta-label">Cập nhật lần cuối</div>
              <div className="legal2-meta-value">13/04/2026</div>
            </div>
          </div>
        </div>

        <div className="legal2-grid">
          <aside className="legal2-aside">
            <div className="legal2-toc">
              <div className="legal2-toc-title">Mục lục</div>
              <nav>
                {toc.map((t) => (
                  <a key={t.id} className="legal2-toc-item" href={`#${t.id}`}>
                    <span className="legal2-toc-dot" aria-hidden />
                    <span className="legal2-toc-text">{t.label}</span>
                  </a>
                ))}
              </nav>
            </div>
          </aside>

          <main className="legal2-main">
            <section id="gioi-thieu-chung" className="legal2-sec">
              <div className="legal2-sec-head">
                <div className="legal2-sec-num">01</div>
                <h2 className="legal2-sec-title">Giới thiệu chung</h2>
              </div>
              <p className="legal2-p">
                FreshFood là nền tảng thương mại điện tử chuyên cung cấp thực phẩm tươi sạch. Điều khoản này quy định quyền
                và nghĩa vụ của người dùng khi truy cập và sử dụng website.
              </p>
              <p className="legal2-p">
                Chúng tôi có thể cập nhật nội dung theo thời gian. Phiên bản mới sẽ có hiệu lực kể từ thời điểm được đăng
                tải trên website.
              </p>
            </section>

            <section id="tai-khoan-nguoi-dung" className="legal2-sec">
              <div className="legal2-sec-head">
                <div className="legal2-sec-num">02</div>
                <h2 className="legal2-sec-title">Tài khoản người dùng</h2>
              </div>
              <ul className="legal2-list">
                <li>Bạn chịu trách nhiệm bảo mật thông tin đăng nhập và mọi hoạt động phát sinh từ tài khoản.</li>
                <li>Thông tin cung cấp cần chính xác và được cập nhật khi có thay đổi.</li>
                <li>FreshFood có thể tạm khóa/đình chỉ tài khoản nếu có dấu hiệu gian lận hoặc vi phạm điều khoản.</li>
              </ul>
            </section>

            <section id="chinh-sach-mua-hang" className="legal2-sec">
              <div className="legal2-sec-head">
                <div className="legal2-sec-num">03</div>
                <h2 className="legal2-sec-title">Chính sách mua hàng</h2>
              </div>

              <div className="legal2-two">
                <div className="legal2-block">
                  <h3 className="legal2-h3">Xác nhận đơn hàng</h3>
                  <p className="legal2-p">
                    Đơn hàng được ghi nhận khi bạn hoàn tất thao tác đặt hàng. Với thanh toán online, đơn hàng chỉ được xác
                    nhận khi hệ thống ghi nhận trạng thái thanh toán thành công.
                  </p>
                  <ul className="legal2-list">
                    <li>Thông tin giao nhận cần đầy đủ để tránh giao thất bại.</li>
                    <li>Khuyến mãi/voucher áp dụng theo điều kiện hiển thị tại trang thanh toán.</li>
                  </ul>
                </div>

                <div className="legal2-block">
                  <h3 className="legal2-h3">Tình trạng hàng hóa</h3>
                  <p className="legal2-p">
                    Sản phẩm thực phẩm có thể thay đổi theo mùa vụ. Chúng tôi luôn cố gắng đảm bảo chất lượng và cung cấp
                    thông tin minh bạch.
                  </p>
                  <p className="legal2-p muted" style={{ marginBottom: 0 }}>
                    Nếu phát sinh thiếu hàng, chúng tôi sẽ liên hệ để thay thế/hoàn tiền theo thỏa thuận.
                  </p>
                </div>
              </div>
            </section>

            <section id="thanh-toan" className="legal2-sec">
              <div className="legal2-sec-head">
                <div className="legal2-sec-num">04</div>
                <h2 className="legal2-sec-title">Thanh toán</h2>
              </div>

              <p className="legal2-p">Chúng tôi hỗ trợ các hình thức thanh toán phổ biến:</p>
              <div className="legal2-chips">
                <span className="legal2-chip">Thanh toán khi nhận hàng (COD)</span>
                <span className="legal2-chip">Thanh toán online</span>
                <span className="legal2-chip">Ví/Ngân hàng</span>
                <span className="legal2-chip">Voucher/Khuyến mãi</span>
              </div>
            </section>

            <section id="giao-nhan" className="legal2-sec">
              <div className="legal2-sec-head">
                <div className="legal2-sec-num">05</div>
                <h2 className="legal2-sec-title">Giao nhận</h2>
              </div>

              <div className="legal2-media">
                <div className="legal2-media-img" aria-hidden />
                <div className="legal2-media-cap">
                  Chúng tôi cố gắng giao đúng hẹn, tuy nhiên thời gian giao có thể thay đổi do điều kiện vận chuyển.
                </div>
              </div>

              <p className="legal2-p">
                Vui lòng kiểm tra hàng khi nhận. Nếu có vấn đề về chất lượng/thiếu hàng, hãy phản hồi sớm để chúng tôi hỗ
                trợ nhanh nhất.
              </p>
            </section>

            <section id="doi-tra-boi-thuong" className="legal2-sec">
              <div className="legal2-sec-head">
                <div className="legal2-sec-num">06</div>
                <h2 className="legal2-sec-title">Đổi trả và bồi thường</h2>
              </div>

              <div className="legal2-cards">
                <div className="legal2-card">
                  <div className="legal2-card-kicker">Chính sách đổi trả</div>
                  <div className="legal2-card-title">Đổi/Trả theo quy trình</div>
                  <p className="legal2-p">
                    Bạn có thể tạo yêu cầu hoàn hàng/hoàn tiền theo hướng dẫn trên website. Chúng tôi sẽ kiểm duyệt và phản
                    hồi trong thời gian sớm nhất.
                  </p>
                </div>
                <div className="legal2-card">
                  <div className="legal2-card-kicker">Chính sách hoàn tiền</div>
                  <div className="legal2-card-title">Hoàn tiền minh bạch</div>
                  <p className="legal2-p">
                    Hoàn tiền được xử lý theo phương thức thanh toán và trạng thái yêu cầu. Trường hợp cần chứng từ, admin
                    sẽ cập nhật để bạn theo dõi.
                  </p>
                </div>
              </div>
            </section>

            <section id="quyen-so-huu-tri-tue" className="legal2-sec">
              <div className="legal2-sec-head">
                <div className="legal2-sec-num">07</div>
                <h2 className="legal2-sec-title">Quyền sở hữu trí tuệ</h2>
              </div>
              <p className="legal2-p">
                Nội dung, hình ảnh, giao diện và các tài nguyên trên FreshFood thuộc sở hữu của FreshFood hoặc bên cấp
                phép. Bạn không được sao chép hay khai thác thương mại khi chưa có sự cho phép.
              </p>
              <p className="legal2-p" style={{ marginBottom: 0 }}>
                Cần hỗ trợ? Vui lòng truy cập <Link className="link" to="/contact">Liên hệ</Link>.
              </p>
            </section>
          </main>
        </div>
      </div>
    </div>
  );
}

