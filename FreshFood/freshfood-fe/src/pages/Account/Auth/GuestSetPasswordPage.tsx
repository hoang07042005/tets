import { useMemo, useState } from 'react';
import { Link, useNavigate, useSearchParams } from 'react-router-dom';
import { Mail, Lock } from 'lucide-react';
import { apiService } from '../../../services/api';

/** Trang từ link email sau đơn hàng khách — không dùng luồng "Quên mật khẩu". */
export const GuestSetPasswordPage = () => {
  const [params] = useSearchParams();
  const navigate = useNavigate();

  const initialEmail = useMemo(() => params.get('email') || '', [params]);
  const initialToken = useMemo(() => params.get('token') || '', [params]);

  const [email, setEmail] = useState(initialEmail);
  const [token, setToken] = useState(initialToken);
  const [newPassword, setNewPassword] = useState('');
  const [confirmPassword, setConfirmPassword] = useState('');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const onSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError(null);
    if (newPassword !== confirmPassword) {
      setError('Mật khẩu xác nhận không khớp.');
      return;
    }
    setLoading(true);
    try {
      await apiService.setInitialPassword({ email, token, newPassword });
      alert('Đã tạo mật khẩu thành công. Bạn có thể đăng nhập.');
      navigate('/login');
    } catch (err) {
      const msg = err instanceof Error ? err.message : 'Đặt mật khẩu thất bại.';
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
          <h1 className="auth-hero-title">Tạo mật khẩu</h1>
          <p className="auth-hero-sub">Kích hoạt tài khoản sau khi đặt hàng — dùng link trong email chúng tôi đã gửi.</p>
        </div>
        <div className="auth-left-overlay" aria-hidden />
      </section>

      <section className="auth-right" aria-label="Tạo mật khẩu tài khoản khách">
        <div className="auth-card">
          <header className="auth-card-head">
            <h2 className="auth-title">Đặt mật khẩu cho tài khoản của bạn</h2>
            <p className="auth-sub">Liên kết có hiệu lực 48 giờ.</p>
          </header>

          {error && (
            <div className="auth-form-error" role="alert" style={{ marginBottom: '0.9rem' }}>
              {error}
            </div>
          )}

          <form onSubmit={onSubmit} className="auth-form">
            <div className="auth-field">
              <label className="auth-label">EMAIL</label>
              <div className="auth-input-wrap">
                <Mail size={18} className="auth-input-ico" aria-hidden />
                <input type="email" required value={email} onChange={(e) => setEmail(e.target.value)} />
              </div>
            </div>

            <div className="auth-field">
              <label className="auth-label">MÃ TỪ EMAIL</label>
              <div className="auth-input-wrap">
                <Lock size={18} className="auth-input-ico" aria-hidden />
                <input required value={token} onChange={(e) => setToken(e.target.value)} placeholder="Đã điền sẵn nếu bạn mở đúng link" />
              </div>
            </div>

            <div className="auth-field">
              <label className="auth-label">MẬT KHẨU</label>
              <div className="auth-input-wrap">
                <Lock size={18} className="auth-input-ico" aria-hidden />
                <input type="password" required value={newPassword} onChange={(e) => setNewPassword(e.target.value)} placeholder="Tối thiểu 6 ký tự" />
              </div>
            </div>

            <div className="auth-field">
              <label className="auth-label">XÁC NHẬN MẬT KHẨU</label>
              <div className="auth-input-wrap">
                <Lock size={18} className="auth-input-ico" aria-hidden />
                <input
                  type="password"
                  required
                  value={confirmPassword}
                  onChange={(e) => setConfirmPassword(e.target.value)}
                  placeholder="••••••••"
                />
              </div>
            </div>

            <button type="submit" className="auth-submit" disabled={loading}>
              {loading ? 'Đang lưu…' : 'Tạo mật khẩu'}
              <span aria-hidden>→</span>
            </button>

            <p className="auth-legal" style={{ marginTop: '0.9rem' }}>
              <Link className="auth-legal-link" to="/forgot-password">
                Không dùng được link / cần mã mới
              </Link>
              {' · '}
              <Link className="auth-legal-link" to="/login">
                Đăng nhập
              </Link>
            </p>
          </form>
        </div>
      </section>
    </main>
  );
};
