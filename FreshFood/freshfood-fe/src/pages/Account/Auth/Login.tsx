import { useState } from 'react';
import { useAuth } from '../../../context/AuthContext';
import { apiService } from '../../../services/api';
import { useNavigate, Link } from 'react-router-dom';
import { Mail, Lock } from 'lucide-react';

export const LoginPage = () => {
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [remember, setRemember] = useState(true);
  const [loading, setLoading] = useState(false);
  const [formError, setFormError] = useState<string | null>(null);
  const { login } = useAuth();
  const navigate = useNavigate();

  const handleLogin = async (e: React.FormEvent) => {
    e.preventDefault();
    setFormError(null);
    setLoading(true);
    try {
      const res = await apiService.login({ email, password });
      login({ user: res.user, token: res.token, expiresInSeconds: res.expiresInSeconds });
      const isAdmin = (res.user?.role || '').toLowerCase() === 'admin';
      navigate(isAdmin ? '/admin' : '/');
    } catch (error) {
      const msg = error instanceof Error ? error.message : 'Đăng nhập thất bại. Vui lòng thử lại.';
      setFormError(msg);
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
          <h1 className="auth-hero-title">Từ nông trại đến bàn ăn, chọn lọc tinh hoa.</h1>
          <p className="auth-hero-sub">
            Tham gia cộng đồng yêu thực phẩm sạch, canh tác bền vững và theo mùa. Hành trình sống xanh đang chờ bạn.
          </p>
          <div className="auth-stats">
            <div className="auth-stat">
              <div className="auth-stat-num">12k+</div>
              <div className="auth-stat-label">THÀNH VIÊN HOẠT ĐỘNG</div>
            </div>
            <div className="auth-stat">
              <div className="auth-stat-num">100%</div>
              <div className="auth-stat-label">HỮU CƠ CHỨNG NHẬN</div>
            </div>
          </div>
        </div>
        <div className="auth-left-overlay" aria-hidden />
      </section>

      <section className="auth-right" aria-label="Login">
        <div className="auth-card">
          <header className="auth-card-head">
            <h2 className="auth-title">Chào mừng trở lại</h2>
            <p className="auth-sub">Đăng nhập để tiếp tục mua sắm cùng FreshFood.</p>
          </header>

          <div className="auth-tabs" role="tablist" aria-label="Auth tabs">
            <span className="auth-tab auth-tab--active" role="tab" aria-selected="true">
              Đăng nhập
            </span>
            <Link className="auth-tab" to="/register" role="tab" aria-selected="false">
              Đăng ký
            </Link>
          </div>

          <div className="auth-social">
            <button type="button" className="auth-social-btn" disabled title="Demo UI">
              <span className="auth-social-icon">G</span> Google
            </button>
            <button type="button" className="auth-social-btn" disabled title="Demo UI">
              <span className="auth-social-icon"></span> Apple
            </button>
          </div>

          <div className="auth-divider">
            <span>HOẶC DÙNG EMAIL</span>
          </div>

          <form onSubmit={handleLogin} className="auth-form">
            {formError && (
              <div className="auth-form-error" role="alert">
                {formError}
              </div>
            )}
            <div className="auth-field">
              <label className="auth-label">ĐỊA CHỈ EMAIL</label>
              <div className="auth-input-wrap">
                <Mail size={18} className="auth-input-ico" aria-hidden />
                <input
                  type="email"
                  placeholder="hello@freshfood.com"
                  required
                  value={email}
                  onChange={(e) => {
                    setEmail(e.target.value);
                    setFormError(null);
                  }}
                />
              </div>
            </div>

            <div className="auth-field">
              <div className="auth-label-row">
                <label className="auth-label">MẬT KHẨU</label>
                <Link className="auth-link" to="/forgot-password">
                  Quên mật khẩu?
                </Link>
              </div>
              <div className="auth-input-wrap">
                <Lock size={18} className="auth-input-ico" aria-hidden />
                <input
                  type="password"
                  placeholder="••••••••"
                  required
                  value={password}
                  onChange={(e) => {
                    setPassword(e.target.value);
                    setFormError(null);
                  }}
                />
              </div>
            </div>

            <label className="auth-remember">
              <input type="checkbox" checked={remember} onChange={(e) => setRemember(e.target.checked)} />
              <span>Ghi nhớ đăng nhập trong 24 giờ</span>
            </label>

            <button type="submit" className="auth-submit" disabled={loading}>
              {loading ? 'Đang đăng nhập…' : 'Đăng nhập'}
              <span aria-hidden>→</span>
            </button>
          </form>

          <p className="auth-legal">
            Tiếp tục nghĩa là bạn đồng ý với{' '}
            <Link className="auth-legal-link" to="/terms" target="_blank" rel="noreferrer">
              Điều khoản dịch vụ
            </Link>{' '}
            và{' '}
            <Link className="auth-legal-link" to="/privacy" target="_blank" rel="noreferrer">
              Chính sách bảo mật
            </Link>{' '}
            của FreshFood.
          </p>
        </div>
      </section>
    </main>
  );
};
