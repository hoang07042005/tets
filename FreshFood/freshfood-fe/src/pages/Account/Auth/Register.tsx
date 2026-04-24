import { useState } from 'react';
import { apiService } from '../../../services/api';
import { useNavigate, Link } from 'react-router-dom';
import { Mail, Lock, User, Phone } from 'lucide-react';

export const RegisterPage = () => {
  const [formData, setFormData] = useState({
    fullName: '',
    email: '',
    phone: '',
    password: '',
    confirmPassword: ''
  });
  const [loading, setLoading] = useState(false);
  const navigate = useNavigate();

  const handleChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    setFormData({ ...formData, [e.target.name]: e.target.value });
  };

  const handleRegister = async (e: React.FormEvent) => {
    e.preventDefault();
    if (formData.password !== formData.confirmPassword) {
      alert('Mật khẩu xác nhận không khớp.');
      return;
    }

    setLoading(true);
    try {
      await apiService.register({
        fullName: formData.fullName,
        email: formData.email,
        phone: formData.phone,
        password: formData.password
      });
      alert('Đăng ký thành công! Vui lòng đăng nhập.');
      navigate('/login');
    } catch (error) {
      alert('Đăng ký thất bại. Email có thể đã tồn tại.');
    } finally {
      setLoading(false);
    }
  };

  return (
    <main className="auth-split">
      <section className="auth-left auth-left--register" aria-label="FreshFood introduction">
        <div className="auth-left-inner">
          <div className="auth-brand">
            <img className="auth-brand-logo" src="/icon-logo-freshfood.png" alt="" width={22} height={22} />
            <span className="auth-brand-text">FreshFood</span>
          </div>
          <h1 className="auth-hero-title">Bắt nguồn từ thiên nhiên thuần khiết.</h1>
          <p className="auth-hero-sub">
            Tham gia cùng chúng tôi để khám phá những thực phẩm hữu cơ tươi ngon nhất, được tuyển chọn kỹ lưỡng từ các
            nông trại địa phương bền vững.
          </p>
          <div className="auth-join-pill">
            <span className="auth-join-avatars" aria-hidden>
              <span />
              <span />
              <span />
            </span>
            <span>Hơn 5,000+ người đã tham gia</span>
          </div>
        </div>
        <div className="auth-left-overlay" aria-hidden />
      </section>

      <section className="auth-right" aria-label="Register">
        <div className="auth-card">
          <header className="auth-card-head">
            <h2 className="auth-title">Tạo tài khoản mới</h2>
            <p className="auth-sub">Bắt đầu hành trình sống xanh cùng chúng tôi hôm nay.</p>
          </header>

          <div className="auth-tabs" role="tablist" aria-label="Auth tabs">
            <Link className="auth-tab" to="/login" role="tab" aria-selected="false">
              Đăng nhập
            </Link>
            <span className="auth-tab auth-tab--active" role="tab" aria-selected="true">
              Đăng ký
            </span>
          </div>

          <form onSubmit={handleRegister} className="auth-form">
            <div className="auth-form-grid">
              <div className="auth-field auth-span-2">
                <label className="auth-label">HỌ VÀ TÊN</label>
                <div className="auth-input-wrap">
                  <User size={18} className="auth-input-ico" aria-hidden />
                  <input type="text" name="fullName" placeholder="Nguyễn Văn A" required value={formData.fullName} onChange={handleChange} />
                </div>
              </div>

              <div className="auth-field">
                <label className="auth-label">EMAIL</label>
                <div className="auth-input-wrap">
                  <Mail size={18} className="auth-input-ico" aria-hidden />
                  <input type="email" name="email" placeholder="email@freshfood.com" required value={formData.email} onChange={handleChange} />
                </div>
              </div>

              <div className="auth-field">
                <label className="auth-label">SỐ ĐIỆN THOẠI</label>
                <div className="auth-input-wrap">
                  <Phone size={18} className="auth-input-ico" aria-hidden />
                  <input type="text" name="phone" placeholder="0901 234 567" required value={formData.phone} onChange={handleChange} />
                </div>
              </div>

              <div className="auth-field">
                <label className="auth-label">MẬT KHẨU</label>
                <div className="auth-input-wrap">
                  <Lock size={18} className="auth-input-ico" aria-hidden />
                  <input type="password" name="password" placeholder="••••••••" required value={formData.password} onChange={handleChange} />
                </div>
              </div>

              <div className="auth-field">
                <label className="auth-label">XÁC NHẬN MẬT KHẨU</label>
                <div className="auth-input-wrap">
                  <Lock size={18} className="auth-input-ico" aria-hidden />
                  <input
                    type="password"
                    name="confirmPassword"
                    placeholder="••••••••"
                    required
                    value={formData.confirmPassword}
                    onChange={handleChange}
                  />
                </div>
              </div>
            </div>

            <button type="submit" className="auth-submit" disabled={loading}>
              {loading ? 'Đang xử lý…' : 'Đăng ký ngay'}
            </button>
          </form>

          <div className="auth-divider" style={{ marginTop: '1.15rem' }}>
            <span>HOẶC ĐĂNG KÝ BẰNG</span>
          </div>

          <div className="auth-social">
            <button type="button" className="auth-social-btn" disabled title="Demo UI">
              <span className="auth-social-icon">G</span> Google
            </button>
            <button type="button" className="auth-social-btn" disabled title="Demo UI">
              <span className="auth-social-icon">f</span> Facebook
            </button>
          </div>

          <p className="auth-legal" style={{ marginTop: '1.1rem' }}>
            Đã có tài khoản? <Link className="auth-legal-link" to="/login">Đăng nhập ngay</Link>
          </p>
        </div>
      </section>
    </main>
  );
};
