import { Share2, Mail, Search } from 'lucide-react';
import { Link, useNavigate } from 'react-router-dom';
import { useState } from 'react';

export const Footer = () => {
  const nav = useNavigate();
  const [trackCode, setTrackCode] = useState('');
  const [trackPhone, setTrackPhone] = useState('');

  return (
    <footer className="footer-v3">
      <div className="container">
        <div className="footer-grid">
          {/* Column 1: Brand Info */}
          <div className="footer-col brand-info">
            <div className="footer-logo">
              <img className="footer-logo-img" src="/icon-logo-freshfood.png" alt="" width={28} height={28} />
              <h2 className="footer-brand">FreshFood</h2>
            </div>
            <p className="footer-desc">
              Mang tinh hoa của đất mẹ đến bàn ăn gia đình bạn với quy trình hữu cơ bền vững.
            </p>
            <div className="social-links">
              <div className="social-icon"><Share2 size={18} /></div>
              <div className="social-icon"><Mail size={18} /></div>
            </div>
          </div>

          {/* Column 2: Quick Links */}
          <div className="footer-col">
            <h3>Liên kết nhanh</h3>
            <ul>
              <li><Link to="/about">Về chúng tôi</Link></li>
              <li><Link to="/sustainability">Phát triển bền vững</Link></li>
              <li><Link to="/shipping">Chính sách vận chuyển</Link></li>
              <li><Link to="/faq">Câu hỏi thường gặp</Link></li>
              <li><Link to="/tra-cuu-don-hang">Tra cứu vận đơn</Link></li>
            </ul>
          </div>

          {/* Column 3: Categories */}
          <div className="footer-col">
            <h3>Danh mục</h3>
            <ul>
              <li><Link to="/products">Rau củ theo mùa</Link></li>
              <li><Link to="/products">Trái cây tươi</Link></li>
              <li><Link to="/products">Rau gia vị</Link></li>
              <li><Link to="/products">Sữa & Trứng</Link></li>
            </ul>
          </div>

          {/* Column 4: Quick shipment tracking */}
          <div className="footer-col newsletter">
            <h3>Tra cứu nhanh vận đơn</h3>
            <p>Nhập mã đơn và SĐT đã dùng khi đặt để tra cứu trạng thái vận chuyển.</p>
            <form
              className="newsletter-form"
              onSubmit={(e) => {
                e.preventDefault();
                const code = trackCode.trim();
                const phone = trackPhone.trim();
                const qs = new URLSearchParams();
                if (code) qs.set('code', code);
                if (phone) qs.set('phone', phone);
                nav(`/tra-cuu-don-hang${qs.toString() ? `?${qs.toString()}` : ''}`);
              }}
            >
              <input
                type="text"
                placeholder="Mã đơn hàng"
                value={trackCode}
                onChange={(e) => setTrackCode(e.target.value)}
                autoComplete="off"
              />
              <input
                type="tel"
                placeholder="Số điện thoại"
                value={trackPhone}
                onChange={(e) => setTrackPhone(e.target.value)}
                autoComplete="tel"
                inputMode="tel"
              />
              <button type="submit" title="Tra cứu">
                <Search size={16} aria-hidden />
              </button>
            </form>
          </div>
        </div>

        <div className="footer-bottom">
          <p>© 2026 FreshFood. Tận tâm vì chất lượng.</p>
        </div>
      </div>
    </footer>
  );
};
