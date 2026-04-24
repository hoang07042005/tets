import { useState } from 'react';
import { apiService } from '../../services/api';
import { Mail, MapPin, Phone, Send, CheckCircle, UtensilsCrossed } from 'lucide-react';

const MAP_EMBED =
  'https://www.openstreetmap.org/export/embed.html?bbox=106.695%2C10.772%2C106.705%2C10.780&layer=mapnik&marker=10.776%2C106.700';
const MAP_LINK = 'https://www.openstreetmap.org/?mlat=10.776&mlon=106.700#map=16/10.776/106.700';

export const ContactPage = () => {
  const [formData, setFormData] = useState({
    name: '',
    email: '',
    subject: '',
    message: ''
  });
  const [loading, setLoading] = useState(false);
  const [success, setSuccess] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError(null);
    setLoading(true);
    try {
      await apiService.submitContactForm(formData);
      setSuccess(true);
    } catch (err) {
      const msg = err instanceof Error ? err.message : 'Đã xảy ra lỗi. Vui lòng thử lại sau.';
      setError(msg);
    } finally {
      setLoading(false);
    }
  };

  if (success) {
    return (
      <div className="contact-v2 contact-v2--plain">
        <div className="contact-v2-success-card">
          <CheckCircle className="contact-v2-success-icon" size={72} aria-hidden />
          <h2 className="contact-v2-success-title">Cảm ơn bạn đã liên hệ!</h2>
          <p className="contact-v2-success-text">Chúng tôi đã nhận được tin nhắn của bạn và sẽ phản hồi sớm nhất có thể.</p>
          <button
            type="button"
            className="contact-v2-btn"
            onClick={() => {
              setSuccess(false);
              setFormData({ name: '', email: '', subject: '', message: '' });
            }}
          >
            Gửi tin nhắn mới
          </button>
        </div>
      </div>
    );
  }

  return (
    <div className="contact-v2">
      <section className="contact-v2-hero" aria-labelledby="contact-v2-heading">
        <div
          className="contact-v2-hero__bg"
          style={{
            backgroundImage:
              'linear-gradient(105deg, rgba(15, 40, 20, 0.72) 0%, rgba(15, 40, 20, 0.35) 45%, rgba(20, 50, 25, 0.25) 100%), url(https://lh3.googleusercontent.com/aida-public/AB6AXuBs5dSP4Xp-IWBr5s8sXdxhf_dNSjq5bu2GxkQT-2X9gMnLtf97bxb1EncYdsreUQaNKPKZZKFFz5kffrys5-aDS2BgtzOFSno0xkGwHkqQtE6MT2qgV7fj5KotENgu_qp0EU5BHE5h0fR4pQf3_ayEF_IaUe3VJBWi4oXmfrGMI87yDyHfJFwVzMPv3UFTYu1Y7ib81IAZrUKAxGLmTdWlD1zKuCkcCcDAqimPsoyQIIr8DWWWo3n-qMnTlgWOxWsW1MQRCAouGKk)',
          }}
        />
        <div className="contact-v2-hero__inner">
          <p className="contact-v2-hero__badge">KẾT NỐI VỚI CHÚNG TÔI</p>
          <h1 id="contact-v2-heading" className="contact-v2-hero__title">
            Liên hệ với chúng tôi
          </h1>
          <p className="contact-v2-hero__lead">
            Chúng tôi luôn sẵn sàng lắng nghe góp ý, hợp tác hoặc hỗ trợ bạn — hãy để lại lời nhắn bên dưới.
          </p>
        </div>

        <div className="contact-v2-hero__cards">
          <article className="contact-v2-info-card">
            <div className="contact-v2-info-card__icon" aria-hidden>
              <MapPin size={22} strokeWidth={2.25} />
            </div>
            <div className="contact-v2-info-card__body">
              <h3 className="contact-v2-info-card__title">Địa chỉ</h3>
              <p className="contact-v2-info-card__text">123 Đường Nông Nghiệp Xanh, Quận 1, TP. Hồ Chí Minh</p>
            </div>
          </article>
          <article className="contact-v2-info-card">
            <div className="contact-v2-info-card__icon" aria-hidden>
              <Phone size={22} strokeWidth={2.25} />
            </div>
            <div className="contact-v2-info-card__body">
              <h3 className="contact-v2-info-card__title">Điện thoại</h3>
              <p className="contact-v2-info-card__text">1900 1234 56</p>
            </div>
          </article>
          <article className="contact-v2-info-card">
            <div className="contact-v2-info-card__icon" aria-hidden>
              <Mail size={22} strokeWidth={2.25} />
            </div>
            <div className="contact-v2-info-card__body">
              <h3 className="contact-v2-info-card__title">Email</h3>
              <a className="contact-v2-info-card__link" href="mailto:hello@freshfood.vn">
                hello@freshfood.vn
              </a>
            </div>
          </article>
        </div>
      </section>

      <div className="contact-v2-main">
        <div className="contact-v2-main__grid">
          <div className="contact-v2-form-block">
            <h2 className="contact-v2-form-block__title">Gửi lời nhắn cho chúng tôi</h2>
            <p className="contact-v2-form-block__lead">
              Điền biểu mẫu — đội ngũ FreshFood thường phản hồi trong vòng 24 giờ làm việc.
            </p>

            <form className="contact-v2-form" onSubmit={handleSubmit}>
              <div className="contact-v2-form__row2">
                <div className="contact-v2-field">
                  <label htmlFor="contact-name" className="contact-v2-label">
                    Họ và tên
                  </label>
                  <input
                    id="contact-name"
                    name="name"
                    type="text"
                    className="contact-v2-input"
                    autoComplete="name"
                    required
                    placeholder="Nguyễn Văn A"
                    value={formData.name}
                    onChange={(e) => setFormData({ ...formData, name: e.target.value })}
                  />
                </div>
                <div className="contact-v2-field">
                  <label htmlFor="contact-email" className="contact-v2-label">
                    Địa chỉ Email
                  </label>
                  <input
                    id="contact-email"
                    name="email"
                    type="email"
                    className="contact-v2-input"
                    autoComplete="email"
                    required
                    placeholder="example@email.com"
                    value={formData.email}
                    onChange={(e) => setFormData({ ...formData, email: e.target.value })}
                  />
                </div>
              </div>

              <div className="contact-v2-field">
                <label htmlFor="contact-subject" className="contact-v2-label">
                  Chủ đề
                </label>
                <input
                  id="contact-subject"
                  name="subject"
                  type="text"
                  className="contact-v2-input"
                  required
                  placeholder="Hợp tác, Hỗ trợ đơn hàng…"
                  value={formData.subject}
                  onChange={(e) => setFormData({ ...formData, subject: e.target.value })}
                />
              </div>

              <div className="contact-v2-field">
                <label htmlFor="contact-message" className="contact-v2-label">
                  Tin nhắn của bạn
                </label>
                <textarea
                  id="contact-message"
                  name="message"
                  className="contact-v2-textarea"
                  rows={5}
                  required
                  placeholder="Bạn cần hỗ trợ điều gì?"
                  value={formData.message}
                  onChange={(e) => setFormData({ ...formData, message: e.target.value })}
                />
              </div>

              {error ? (
                <div className="contact-v2-alert" role="alert">
                  {error}
                </div>
              ) : null}

              <button type="submit" className="contact-v2-btn" disabled={loading}>
                <Send size={18} aria-hidden />
                {loading ? 'Đang gửi...' : 'Gửi tin nhắn'}
              </button>
            </form>
          </div>

          <div className="contact-v2-map-block">
            <div className="contact-v2-map-frame">
              <span className="contact-v2-map-pin" aria-hidden>
                <UtensilsCrossed size={18} strokeWidth={2.5} />
              </span>
              <iframe
                className="contact-v2-map-iframe"
                title="Bản đồ FreshFood"
                src={MAP_EMBED}
                loading="lazy"
                referrerPolicy="no-referrer-when-downgrade"
              />
              <div className="contact-v2-map-float">
                <div>
                  <div className="contact-v2-map-float__title">Văn phòng FreshFood</div>
                  <div className="contact-v2-map-float__addr">123 Đường Nông Nghiệp Xanh, Q.1, TP.HCM</div>
                </div>
                <a className="contact-v2-map-float__link" href={MAP_LINK} target="_blank" rel="noreferrer">
                  Chỉ đường
                </a>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};
