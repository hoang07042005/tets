import { useState } from 'react';
import { Link } from 'react-router-dom';
import { Mail } from 'lucide-react';
import { apiService } from '../../../services/api';

export const ForgotPasswordPage = () => {
  const [email, setEmail] = useState('');
  const [loading, setLoading] = useState(false);
  const [done, setDone] = useState(false);
  const [devToken, setDevToken] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);

  const onSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError(null);
    setDevToken(null);
    setLoading(true);
    try {
      const res = await apiService.forgotPassword({ email });
      setDone(true);
      setDevToken(res?.token ?? null);
    } catch (err) {
      const msg = err instanceof Error ? err.message : 'Gửi yêu cầu thất bại. Vui lòng thử lại.';
      setError(msg);
    } finally {
      setLoading(false);
    }
  };

  return (
    <main className="auth-split">
      <section className="auth-left" aria-label="FreshFood introduction">
        <div className="auth-left-inner">
          <div className="auth-brand">
            <img className="auth-brand-logo" src="/icon-logo-freshfood.png" alt="" width={22} height={22} />
            <span className="auth-brand-text">FRESHFOOD</span>
          </div>
          <h1 className="auth-hero-title">Khôi phục mật khẩu</h1>
          <p className="auth-hero-sub">Nhập email để nhận mã đặt lại mật khẩu.</p>
        </div>
        <div className="auth-left-overlay" aria-hidden />
      </section>

      <section className="auth-right" aria-label="Forgot password">
        <div className="auth-card">
          <header className="auth-card-head">
            <h2 className="auth-title">Quên mật khẩu</h2>
            <p className="auth-sub">Chúng tôi sẽ gửi hướng dẫn (hiện đang ở chế độ dev: trả về mã).</p>
          </header>

          {error && (
            <div className="auth-form-error" role="alert" style={{ marginBottom: '0.9rem' }}>
              {error}
            </div>
          )}

          {done ? (
            <div className="auth-form">
              <div className="auth-form-success">
                Nếu email tồn tại trong hệ thống, bạn sẽ nhận được mã đặt lại trong vài phút.
              </div>
              {devToken && (
                <div className="auth-dev-token" style={{ marginTop: '0.8rem' }}>
                  <div className="muted" style={{ marginBottom: '0.25rem' }}>
                    Mã (dev):
                  </div>
                  <code style={{ wordBreak: 'break-all' }}>{devToken}</code>
                  <div style={{ marginTop: '0.6rem' }}>
                    <Link className="auth-link" to={`/reset-password?email=${encodeURIComponent(email)}&token=${encodeURIComponent(devToken)}`}>
                      Đặt lại mật khẩu ngay
                    </Link>
                  </div>
                </div>
              )}
              <div style={{ marginTop: '1rem' }}>
                <Link className="auth-link" to="/login">
                  Quay lại đăng nhập
                </Link>
              </div>
            </div>
          ) : (
            <form onSubmit={onSubmit} className="auth-form">
              <div className="auth-field">
                <label className="auth-label">ĐỊA CHỈ EMAIL</label>
                <div className="auth-input-wrap">
                  <Mail size={18} className="auth-input-ico" aria-hidden />
                  <input
                    type="email"
                    placeholder="hello@freshfood.com"
                    required
                    value={email}
                    onChange={(e) => setEmail(e.target.value)}
                  />
                </div>
              </div>

              <button type="submit" className="auth-submit" disabled={loading}>
                {loading ? 'Đang gửi…' : 'Gửi mã đặt lại'}
                <span aria-hidden>→</span>
              </button>

              <p className="auth-legal" style={{ marginTop: '0.9rem' }}>
                Đã nhớ mật khẩu?{' '}
                <Link className="auth-legal-link" to="/login">
                  Đăng nhập
                </Link>
              </p>
            </form>
          )}
        </div>
      </section>
    </main>
  );
};

