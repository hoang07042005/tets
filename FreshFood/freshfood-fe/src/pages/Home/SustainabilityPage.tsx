import { Link } from 'react-router-dom';
import { ArrowRight, Droplets, Leaf, Recycle, Sprout, Trees, Users } from 'lucide-react';

export const SustainabilityPage = () => {
  return (
    <main className="sus-page">
      <section className="sus-hero" aria-label="Phát triển bền vững">
        <div className="sus-hero-inner">
          <div className="sus-hero-copy">
            <span className="sus-hero-eyebrow">FRESHFOOD GREEN</span>
            <h1 className="sus-hero-title">
              Vì một tương lai
              <br />
              <span className="sus-hero-highlight">xanh</span>.
            </h1>
            <p className="sus-hero-subtitle">
              Chúng tôi ưu tiên canh tác bền vững, giảm rác thải nhựa và đồng hành cùng nông dân Việt
              để mang thực phẩm sạch đến mọi gia đình.
            </p>
            <div className="sus-hero-actions">
              <Link to="/products" className="hero-cta hero-cta-primary">Khám phá sản phẩm</Link>
              <Link to="/about" className="hero-cta sus-cta-secondary">
                Câu chuyện của chúng tôi <ArrowRight size={18} aria-hidden />
              </Link>
            </div>
          </div>
        </div>
      </section>

      <section className="sus-metrics" aria-label="Tác động của FreshFood">
        <div className="sus-wrap">
          <div className="sus-metrics-grid">
            <article className="sus-metric">
              <div className="sus-metric-ico"><Leaf size={18} aria-hidden /></div>
              <div>
                <div className="sus-metric-kicker">Tác động của chúng tôi</div>
                <div className="sus-metric-value">1.2M+</div>
                <div className="sus-metric-sub">Sản phẩm sạch đã được giao đến khách hàng</div>
              </div>
            </article>
            <article className="sus-metric">
              <div className="sus-metric-ico"><Recycle size={18} aria-hidden /></div>
              <div>
                <div className="sus-metric-kicker">Giảm rác thải</div>
                <div className="sus-metric-value">85%</div>
                <div className="sus-metric-sub">Đơn hàng dùng đóng gói tối giản &amp; thân thiện hơn</div>
              </div>
            </article>
            <article className="sus-metric">
              <div className="sus-metric-ico"><Droplets size={18} aria-hidden /></div>
              <div>
                <div className="sus-metric-kicker">Bảo vệ tài nguyên</div>
                <div className="sus-metric-value">40%</div>
                <div className="sus-metric-sub">Đối tác áp dụng quy trình tiết kiệm nước &amp; đất</div>
              </div>
            </article>
          </div>
        </div>
      </section>

      <section className="sus-split" aria-label="Nông nghiệp tái tạo">
        <div className="sus-wrap">
          <div className="sus-split-grid">
            <div className="sus-split-media">
              <div className="sus-img-card">
                <img
                  src="https://lh3.googleusercontent.com/aida-public/AB6AXuDEY2k1C2fyhCFJCjzMRVXE5YpDP6SShpjv4t-DW6mp5XEUrSrAqEskgXZejH0uccYDKinCEDB3UJg_SBFzWo2g7BRqKsBevfO4_f8oz60jnC3xnYq7gWDEUPBrSOFcU1pWuwytUPPTXUYrc5UXsklGju2Sj-47ak4Jr6XAVRudFmPjnRjgaG_XaEZRKV-2-kv0mkS1IcQP-H9XpjnZr8Dv00Pvz-i-zFSXbA6APLmRZ9cUu7xA8jr3KMDW6oyfrVzO8aI8llkFxZk"
                  alt="Nông nghiệp tái tạo"
                  loading="lazy"
                />
                <div className="sus-float-card" aria-hidden>
                  <Sprout size={18} />
                  <div>
                    <strong>Soil-first</strong>
                    <span>Chăm đất để cây khỏe</span>
                  </div>
                </div>
              </div>
            </div>
            <div className="sus-split-copy">
              <span className="sus-kicker">NÔNG NGHIỆP TÁI TẠO</span>
              <h2>Hồi sinh lòng đất</h2>
              <p>
                Chúng tôi ưu tiên đối tác thực hành canh tác thân thiện: tăng độ mùn, cải thiện vi sinh vật,
                hạn chế hóa chất và khuyến khích đa dạng sinh học.
              </p>
              <div className="sus-bullets">
                <div className="sus-bullet"><Trees size={18} aria-hidden /> Bảo vệ hệ sinh thái địa phương</div>
                <div className="sus-bullet"><Droplets size={18} aria-hidden /> Tối ưu nước tưới &amp; đất trồng</div>
              </div>
            </div>
          </div>
        </div>
      </section>

      <section className="sus-split" aria-label="Giảm rác thải nhựa">
        <div className="sus-wrap">
          <div className="sus-split-grid">
            <div className="sus-split-copy">
              <span className="sus-kicker">ZERO WASTE</span>
              <h2>Nói không với Rác thải nhựa</h2>
              <p>
                FreshFood tối giản bao bì, ưu tiên vật liệu tái chế và hướng tới tái sử dụng.
                Mục tiêu là giảm nhựa dùng một lần trong từng đơn hàng.
              </p>
              <div className="sus-mini-metrics">
                <div className="sus-mini">
                  <div className="sus-mini-value">500 Tấn</div>
                  <div className="sus-mini-label">Bao bì nhựa được cắt giảm mỗi năm</div>
                </div>
                <div className="sus-mini">
                  <div className="sus-mini-value">100%</div>
                  <div className="sus-mini-label">Ưu tiên vật liệu có thể tái chế</div>
                </div>
              </div>
            </div>
            <div className="sus-split-media">
              <div className="sus-img-card sus-img-card--alt">
                <img
                  src="https://lh3.googleusercontent.com/aida-public/AB6AXuDO2sMhd88wyD7BSfYW0HqRW6Iv-YK2UWSn8b0nehv3RnTbV-tfAVVcsbXsvhjvQ1beWU7io0FIFPP7sMO1MT7M1_1ZBzgn5QTVfJveFU1PL9ewP8NR9nA8H7EIXSekH8I9i7juNte9FynlWnoKyVzLWEihZaMu0JLfSajc-1ICQrOfuqrL8B8RSYws_f4XKz6sX9Si6HgAuCQwC6tWQeUzFK0viJiP8mErIBpf-4YkQ_8kPsVv7XL3mCJvBVeGQ_2Vf-LqFqlMb0k"
                  alt="Đóng gói thân thiện môi trường"
                  loading="lazy"
                />
              </div>
            </div>
          </div>
        </div>
      </section>

      <section className="sus-features" aria-label="Đồng hành cùng nông dân Việt">
        <div className="sus-wrap">
          <h2 className="sus-center-title">Đồng hành cùng Nông dân Việt</h2>
          <div className="sus-feature-grid">
            <article className="sus-feature">
              <div className="sus-feature-ico"><Users size={20} aria-hidden /></div>
              <h3>Hợp tác bền vững</h3>
              <p>Liên kết dài hạn để ổn định đầu ra, chất lượng và giá trị công bằng.</p>
            </article>
            <article className="sus-feature">
              <div className="sus-feature-ico"><Leaf size={20} aria-hidden /></div>
              <h3>Giá trị thật</h3>
              <p>Ưu tiên thu hoạch theo mùa và kiểm soát chất lượng trước khi giao.</p>
            </article>
            <article className="sus-feature">
              <div className="sus-feature-ico"><Recycle size={20} aria-hidden /></div>
              <h3>Quỹ phát triển</h3>
              <p>Trích một phần để hỗ trợ cải tiến quy trình canh tác &amp; giảm lãng phí.</p>
            </article>
          </div>
        </div>
      </section>

      <section className="sus-cta" aria-label="Cùng chúng tôi sống xanh">
        <div className="sus-wrap">
          <div className="sus-cta-card">
            <div className="sus-cta-copy">
              <h2>Cùng chúng tôi tôn tạo lối sống xanh</h2>
              <p>Chọn sản phẩm theo mùa để ngon hơn, và bền vững hơn mỗi ngày.</p>
            </div>
            <div className="sus-cta-actions">
              <Link to="/products" className="hero-cta hero-cta-primary">Mua ngay</Link>
            </div>
          </div>
        </div>
      </section>
    </main>
  );
};

