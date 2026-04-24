import { Link } from 'react-router-dom';

type TocItem = { id: string; label: string };

const toc: TocItem[] = [
  { id: 'muc-dich', label: 'Mục đích thu thập thông tin cá nhân' },
  { id: 'pham-vi', label: 'Phạm vi sử dụng thông tin' },
  { id: 'thoi-gian-luu', label: 'Thời gian lưu trữ' },
  { id: 'doi-tuong', label: 'Đối tượng tiếp cận' },
  { id: 'dia-chi', label: 'Địa chỉ đơn vị thu thập' },
  { id: 'tiep-can', label: 'Phương thức tiếp cận và chỉnh sửa dữ liệu' },
  { id: 'cam-ket', label: 'Cam kết bảo mật thông tin' },
];

export function PrivacyPolicyPage() {
  return (
    <div className="legal2">
      <div className="container legal2-shell">
        <div className="legal2-hero legal2-hero--privacy">
          <div className="legal2-hero-badge">CHÍNH SÁCH / BẢO MẬT</div>
          <div className="legal2-hero-top">
            <div>
              <h1 className="legal2-title">
                Chính sách <span className="legal2-accent">Bảo mật</span>
              </h1>
              <p className="legal2-sub">
                Cam kết bảo vệ dữ liệu cá nhân của bạn. Chúng tôi chỉ thu thập những thông tin cần thiết để cung cấp dịch vụ
                và nâng cao trải nghiệm.
              </p>
            </div>

            <div className="legal2-meta">
              <div className="legal2-meta-label">Cập nhật lần cuối</div>
              <div className="legal2-meta-value">13/04/2026</div>
            </div>
          </div>

          <div className="legal2-hero-media" aria-hidden />
        </div>

        <div className="legal2-grid">
          <aside className="legal2-aside">
            <div className="legal2-toc">
              <div className="legal2-toc-title">Tại sao cần đọc?</div>
              <div className="legal2-toc-note muted">
                Bạn có thể bấm để chuyển nhanh tới từng mục.
              </div>
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
            <section id="muc-dich" className="legal2-sec">
              <div className="legal2-sec-head">
                <div className="legal2-sec-num">1.</div>
                <h2 className="legal2-sec-title">Mục đích thu thập thông tin cá nhân</h2>
              </div>

              <div className="legal2-bullets">
                <div className="legal2-bullet">
                  <div className="legal2-bullet-ico" aria-hidden>✓</div>
                  <div>
                    <div className="legal2-bullet-title">Xử lý đơn hàng</div>
                    <div className="legal2-bullet-sub muted">Giao nhận, xuất hóa đơn và hỗ trợ sau mua.</div>
                  </div>
                </div>
                <div className="legal2-bullet">
                  <div className="legal2-bullet-ico" aria-hidden>✓</div>
                  <div>
                    <div className="legal2-bullet-title">Nâng cao trải nghiệm</div>
                    <div className="legal2-bullet-sub muted">Gợi ý sản phẩm, lịch sử đơn, wishlist.</div>
                  </div>
                </div>
                <div className="legal2-bullet">
                  <div className="legal2-bullet-ico" aria-hidden>✓</div>
                  <div>
                    <div className="legal2-bullet-title">An toàn hệ thống</div>
                    <div className="legal2-bullet-sub muted">Phòng chống gian lận, bảo mật tài khoản.</div>
                  </div>
                </div>
                <div className="legal2-bullet">
                  <div className="legal2-bullet-ico" aria-hidden>✓</div>
                  <div>
                    <div className="legal2-bullet-title">Thông báo cần thiết</div>
                    <div className="legal2-bullet-sub muted">Email/SMS cập nhật trạng thái đơn hàng khi cần.</div>
                  </div>
                </div>
              </div>
            </section>

            <section id="pham-vi" className="legal2-sec">
              <div className="legal2-sec-head">
                <div className="legal2-sec-num">2.</div>
                <h2 className="legal2-sec-title">Phạm vi sử dụng thông tin</h2>
              </div>

              <div className="legal2-table">
                <div className="legal2-table-col">
                  <div className="legal2-table-h">Collected</div>
                  <div className="legal2-table-p muted">Thông tin bạn cung cấp khi đăng ký/đặt hàng.</div>
                </div>
                <div className="legal2-table-col">
                  <div className="legal2-table-h">Use-case</div>
                  <div className="legal2-table-p muted">Xác thực, giao hàng, hỗ trợ, hoàn tiền/đổi trả.</div>
                </div>
                <div className="legal2-table-col">
                  <div className="legal2-table-h">Policy</div>
                  <div className="legal2-table-p muted">Không bán dữ liệu. Chia sẻ tối thiểu với đối tác liên quan.</div>
                </div>
              </div>
            </section>

            <div className="legal2-split">
              <section id="thoi-gian-luu" className="legal2-sec">
                <div className="legal2-sec-head">
                  <div className="legal2-sec-num">3.</div>
                  <h2 className="legal2-sec-title">Thời gian lưu trữ</h2>
                </div>
                <p className="legal2-p">
                  Dữ liệu được lưu trong thời gian cần thiết để cung cấp dịch vụ và đáp ứng nghĩa vụ pháp lý (đơn hàng, hóa
                  đơn, đối soát). Bạn có thể yêu cầu xoá dữ liệu trong phạm vi pháp luật cho phép.
                </p>
              </section>

              <section id="doi-tuong" className="legal2-sec">
                <div className="legal2-sec-head">
                  <div className="legal2-sec-num">4.</div>
                  <h2 className="legal2-sec-title">Đối tượng tiếp cận</h2>
                </div>
                <p className="legal2-p">
                  Nhân sự vận hành, đối tác vận chuyển và cổng thanh toán có thể tiếp cận dữ liệu tối thiểu để thực hiện
                  dịch vụ. Ngoài ra, chúng tôi chỉ cung cấp dữ liệu khi có yêu cầu hợp lệ từ cơ quan có thẩm quyền.
                </p>
              </section>
            </div>

            <div className="legal2-split">
              <section id="dia-chi" className="legal2-sec">
                <div className="legal2-sec-head">
                  <div className="legal2-sec-num">5.</div>
                  <h2 className="legal2-sec-title">Địa chỉ đơn vị thu thập</h2>
                </div>
                <ul className="legal2-list">
                  <li><b>FreshFood</b> — Nền tảng thương mại điện tử thực phẩm tươi sạch.</li>
                  <li>Email hỗ trợ: <span className="muted">support@freshfood.com</span></li>
                  <li>Trang liên hệ: <Link className="link" to="/contact">Liên hệ</Link></li>
                </ul>
              </section>

              <div className="legal2-photoCard" aria-hidden>
                <div className="legal2-photoCard-img" />
              </div>
            </div>

            <section id="tiep-can" className="legal2-sec">
              <div className="legal2-sec-head">
                <div className="legal2-sec-num">6.</div>
                <h2 className="legal2-sec-title">Phương thức tiếp cận và chỉnh sửa dữ liệu</h2>
              </div>

              <div className="legal2-cards2">
                <div className="legal2-card legal2-card--green">
                  <div className="legal2-card-title">Tự thực hiện</div>
                  <p className="legal2-p">
                    Bạn có thể xem và cập nhật một số thông tin trong trang <b>Tài khoản</b>.
                  </p>
                  <Link className="legal2-btn" to="/profile">Truy cập tài khoản</Link>
                </div>
                <div className="legal2-card legal2-card--soft">
                  <div className="legal2-card-title">Yêu cầu hỗ trợ</div>
                  <p className="legal2-p">
                    Nếu cần xoá dữ liệu hoặc chỉnh sửa thông tin đặc biệt, hãy liên hệ đội hỗ trợ.
                  </p>
                  <Link className="legal2-btn legal2-btn--ghost" to="/contact">Gửi yêu cầu</Link>
                </div>
              </div>
            </section>

            <section id="cam-ket" className="legal2-sec">
              <div className="legal2-sec-head">
                <div className="legal2-sec-num">7.</div>
                <h2 className="legal2-sec-title">Cam kết bảo mật thông tin</h2>
              </div>

              <div className="legal2-note">
                <div className="legal2-note-title">Cam kết</div>
                <p className="legal2-p" style={{ marginBottom: 0 }}>
                  FreshFood áp dụng các biện pháp bảo mật phù hợp để bảo vệ dữ liệu, bao gồm kiểm soát truy cập, mã hoá khi
                  cần thiết và quy trình xử lý sự cố. Chúng tôi không chia sẻ dữ liệu ngoài phạm vi nêu trong chính sách này.
                </p>
              </div>
            </section>

            <div className="legal2-cta">
              <div>
                <div className="legal2-cta-title">Bạn có thắc mắc về quyền riêng tư?</div>
                <div className="legal2-cta-sub muted">Đội ngũ FreshFood sẽ hỗ trợ nhanh chóng và rõ ràng.</div>
              </div>
              <div className="legal2-cta-actions">
                <Link className="legal2-cta-btn" to="/contact">Liên hệ ngay</Link>
                <a className="legal2-cta-btn legal2-cta-btn--ghost" href="mailto:support@freshfood.com">
                  support@freshfood.com
                </a>
              </div>
            </div>
          </main>
        </div>
      </div>
    </div>
  );
}

