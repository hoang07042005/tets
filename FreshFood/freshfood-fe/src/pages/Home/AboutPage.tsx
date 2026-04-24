import { Link } from 'react-router-dom';
import { CheckCircle2, Leaf, Sprout, Star, Trees, Users } from 'lucide-react';

export const AboutPage = () => {
  return (
    <main className="about-page">
      {/* Hero (khớp layout ảnh mẫu) */}
      <section
        className="about2-hero"
        aria-label="Giới thiệu FreshFood"
        style={{
          backgroundImage:
            "linear-gradient(180deg, rgba(0,0,0,0.35), rgba(0,0,0,0.25)), url('https://lh3.googleusercontent.com/aida-public/AB6AXuDccBjkLs0J4eFMJl_vl2znjjfbFkRMWUZcCfF4zOFN7W_YtjKgUyAYHzpbVmiL-V1q3Jqca5AxeDl_dOCPM-VvaFFosTrYY2_EwSR3QpzVnSt6mhCdKqL2sol9EwK90EIXoy38eokkJLqCAKRtmSY8IGvtnacheqAVXQPfXxwDQ56ylfgvprqFqhWicbcI1Hqg2U4JBAISr7q6cLkxDxFAG4apDNq4HEJcaXEHrfzSMS-13nx4QbZVCTaBVwKdYCbEKdNdakn6tzU')",
        }}
      >
        <div className="container">
          <div className="about2-hero-inner">
            <p className="about2-hero-kicker">Organic • Safe • Fast</p>
            <h1 className="about2-hero-title">Bắt nguồn từ Chất lượng, Dẫn dắt bởi Tự nhiên</h1>
            <p className="about2-hero-sub">
              FreshFood chọn lọc theo mùa, ưu tiên quy trình bền vững và giao nhanh để bạn luôn nhận được sản phẩm tươi ngon.
            </p>
            <div className="about2-hero-badges" aria-label="Điểm nổi bật">
              <span className="about2-pill"><CheckCircle2 size={18} aria-hidden /> Nguồn gốc rõ ràng</span>
              <span className="about2-pill"><CheckCircle2 size={18} aria-hidden /> Đóng gói tiêu chuẩn</span>
              <span className="about2-pill"><CheckCircle2 size={18} aria-hidden /> Giao đúng hẹn</span>
            </div>
          </div>
        </div>
      </section>

      {/* Section 2 cột: text + ảnh (giống ảnh mẫu) */}
      <section className="about2-split">
        <div className="container">
          <div className="about2-split-grid">
            <div className="about2-split-copy">
              <p className="about2-overline">FRESHFOOD</p>
              <h2>Thực phẩm sạch cho tương lai là hữu thịnh.</h2>
              <p>
                FreshFood được hình thành từ niềm tin rằng thực phẩm an toàn phải <strong>dễ tiếp cận</strong> và <strong>đáng tin</strong>.
                Chúng tôi làm việc với nông trại đối tác, ưu tiên thu hoạch đúng vụ, hạn chế trung gian và rút ngắn thời gian vận chuyển.
              </p>
              <p>
                Mỗi lô hàng được phân loại, đóng gói theo tiêu chuẩn và ghi nhận quy cách bảo quản để bạn luôn an tâm khi lựa chọn.
              </p>
              <div className="about2-mini">
                <div className="about2-mini-card">
                  <Sprout size={22} aria-hidden />
                  <div>
                    <strong>Nguồn hàng theo mùa</strong>
                    <span>Tươi ngon, đúng vụ, vị ngon tự nhiên</span>
                  </div>
                </div>
                <div className="about2-mini-card">
                  <Leaf size={22} aria-hidden />
                  <div>
                    <strong>Ưu tiên bền vững</strong>
                    <span>Tôn trọng đất, nước và hệ sinh thái</span>
                  </div>
                </div>
              </div>
            </div>

            <div className="about2-split-media" aria-label="Hình ảnh giới thiệu">
              <div className="about2-book">
                <img
                  className="about2-book-img"
                  src="https://lh3.googleusercontent.com/aida-public/AB6AXuAWh3QiYSfkvCuDExh6UYaNRelFE5e2bHYEpjn_ueLT761t9B9pvimqSNqvOK4LBbDPnJkRz4IlB9Mb_Oy51ackQuHXcuZ8b15VKh4IG482AcBzj7NJi90Nr1DIdxT8Ht6cdVVv25Pbou75ZfrkQYMck7Ebt41pvylmR56d3XwdBg7ZVANi5NenhlJFbwMmQDPLTyJqpYHGfMFo0kLFlAXIQAjZAw0qZg5VH8s4RAxbMSDzAVOVZuGCF7Q_ONsK_w6jbtgzd29l-JY"
                  alt="FreshFood seasonal box"
                  loading="lazy"
                />
                <div className="about2-float">
                  <img
                    src="https://lh3.googleusercontent.com/aida-public/AB6AXuARP7dIJJ_Vi4WadMl3hcOwJRfNMpfCiYO_HvZa7sQNW1gr9p2sTPak6_vUrK2TYqSs0DrS2cNc0h_w4dPRov9OxSYQFUnpySy4bxeu-qOhL333Gv0XH4z_-T-izEcQfo7DxVP40qUp_jezusdwhme4nGxg-Lmy0X0r4riOCiwpu85ZK23lDUylc7IqQIlp5TRwrlQEZSGc2-R1i8z1tCV61pCTCUiiegULq13ct99rzilpplrE5bzhY3yZN7j8c4g1u5ZG1SRXR4Y"
                    alt="FreshFood organic soil"
                    loading="lazy"
                  />
                </div>
              </div>
            </div>
          </div>
        </div>
      </section>

      {/* Giá trị cốt lõi */}
      <section className="about2-values">
        <div className="container">
          <h2 className="about2-section-title">Giá trị cốt lõi</h2>
          <div className="about2-values-grid">
            <article className="about2-value">
              <div className="about2-value-ico"><Leaf size={22} /></div>
              <h3>Chất lượng hàng đầu</h3>
              <p>Tuyển chọn theo mùa, kiểm tra lô hàng và đóng gói chuẩn trước khi giao.</p>
            </article>
            <article className="about2-value">
              <div className="about2-value-ico"><Trees size={22} /></div>
              <h3>Canh tác bền vững</h3>
              <p>Ưu tiên quy trình thân thiện môi trường và gìn giữ hệ sinh thái địa phương.</p>
            </article>
            <article className="about2-value">
              <div className="about2-value-ico"><Users size={22} /></div>
              <h3>Hỗ trợ cộng đồng</h3>
              <p>Kết nối nông trại và khách hàng với mức giá hợp lý, minh bạch và công bằng.</p>
            </article>
          </div>
        </div>
      </section>

      {/* Những bàn tay nuôi dưỡng */}
      {/* <section className="about2-people">
        <div className="container">
          <div className="about2-people-head">
            <h2 className="about2-section-title">Những bàn tay nuôi dưỡng</h2>
            <p>Đội ngũ và đối tác nông trại cùng chung mục tiêu: tươi – sạch – đúng hẹn.</p>
          </div>
          <div className="about2-people-grid">
            <article className="about2-person">
              <div className="about2-avatar" data-variant="a" aria-hidden>LV</div>
              <h3>Lâm Văn Vũ</h3>
              <span>Nhà vườn</span>
            </article>
            <article className="about2-person">
              <div className="about2-avatar" data-variant="b" aria-hidden>CT</div>
              <h3>Cô Tư Trang</h3>
              <span>Nông trại hữu cơ</span>
            </article>
            <article className="about2-person">
              <div className="about2-avatar" data-variant="c" aria-hidden>NH</div>
              <h3>Ngô Hải</h3>
              <span>Thu hoạch &amp; phân loại</span>
            </article>
            <article className="about2-person">
              <div className="about2-avatar" data-variant="d" aria-hidden>NA</div>
              <h3>Nguyễn Minh Anh</h3>
              <span>Kiểm định chất lượng</span>
            </article>
          </div>
        </div>
      </section> */}

      {/* Cam kết bền vững (khối nền tối như ảnh mẫu) */}
      <section className="about2-sustain">
        <div className="container">
          <div className="about2-sustain-grid">
            <div className="about2-sustain-copy">
              <h2>Cam kết bền vững</h2>
              <p>
                Chúng tôi giảm thiểu lãng phí trong đóng gói, tối ưu tuyến giao và ưu tiên đối tác có quy trình canh tác bền vững.
                Mục tiêu là tạo ra chuỗi cung ứng lành mạnh cho cả người dùng và môi trường.
              </p>
              <div className="about2-sustain-list">
                <div className="about2-sustain-item"><CheckCircle2 size={18} aria-hidden /> Bao bì thân thiện hơn</div>
                <div className="about2-sustain-item"><CheckCircle2 size={18} aria-hidden /> Tối ưu giao nhận</div>
                <div className="about2-sustain-item"><CheckCircle2 size={18} aria-hidden /> Hợp tác nhà vườn lâu dài</div>
              </div>
            </div>

            <div className="about2-sustain-cards" aria-label="Minh họa">
              <div className="about2-sustain-card">
                <span className="about2-sustain-tag">RECYCLE</span>
                <p>Phân loại &amp; tái sử dụng</p>
              </div>
              <div className="about2-sustain-card">
                <span className="about2-sustain-tag">GREEN</span>
                <p>Nông nghiệp bền vững</p>
              </div>
              <div className="about2-sustain-card about2-sustain-card--wide">
                <span className="about2-sustain-tag">TRACE</span>
                <p>Ghi nhận lô hàng &amp; nguồn gốc</p>
              </div>
            </div>
          </div>
        </div>
      </section>

      {/* CTA cuối trang */}
      <section className="about2-cta">
        <div className="container about-cta-inner">
          <div className="about2-cta-top">
            <h2>Sẵn sàng thưởng thức sự </h2>
            <h2>khác biệt từ thiên nhiên?</h2>
            <p>Khám phá đợt thu hoạch hàng tuần của chúng tôi được tuyển chọn từ các trang trại độc lập địa phương.</p>
            <div className="about-cta-actions">
              <Link to="/products" className="btn-primary about-cta-primary">
                Mua ngay
              </Link>
            </div>
          </div>
        </div>
      </section>
    </main>
  );
};
