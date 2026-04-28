import { useEffect, useMemo, useRef, useState } from 'react';
import { ShoppingCart, LogOut, User as UserIcon, ChevronDown, Heart, Package, Menu, X, History } from 'lucide-react';
import { useCart } from '../context/CartContext';
import { useAuth } from '../context/AuthContext';
import { Link, NavLink, useLocation } from 'react-router-dom';
import { API_ORIGIN } from '../services/api';

export const Header = () => {
  const location = useLocation();
  const { totalItems } = useCart();
  const { user, logout, isAuthenticated } = useAuth();
  const [open, setOpen] = useState(false);
  const [mobileNavOpen, setMobileNavOpen] = useState(false);
  const [avatarImgFailed, setAvatarImgFailed] = useState(false);
  const menuRef = useRef<HTMLDivElement | null>(null);

  const displayName = useMemo(() => {
    const name = user?.fullName?.trim();
    if (!name) return 'Tài khoản';
    const parts = name.split(/\s+/);
    return parts[parts.length - 1] || name;
  }, [user?.fullName]);

  const avatarLetter = useMemo(() => {
    const c = user?.fullName?.trim()?.[0] || 'U';
    return c.toUpperCase();
  }, [user?.fullName]);

  const avatarUrl = useMemo(() => {
    if (!user?.avatarUrl) return '';
    const u = user.avatarUrl.trim();
    if (!u) return '';
    if (/^https?:\/\//i.test(u)) return u;
    if (u.startsWith('/')) return `${API_ORIGIN}${u}`;
    return `${API_ORIGIN}/${u}`;
  }, [user?.avatarUrl]);

  useEffect(() => {
    setAvatarImgFailed(false);
  }, [avatarUrl]);

  useEffect(() => {
    if (!open) return;
    const onDown = (e: MouseEvent) => {
      if (!menuRef.current) return;
      if (!menuRef.current.contains(e.target as Node)) setOpen(false);
    };
    window.addEventListener('mousedown', onDown);
    return () => window.removeEventListener('mousedown', onDown);
  }, [open]);

  useEffect(() => {
    // Close mobile nav when navigating.
    setMobileNavOpen(false);
  }, [location.pathname]);

  const isProductsActive = location.pathname === '/products' || location.pathname.startsWith('/product/');
  const isAdmin = (user?.role || '').toLowerCase() === 'admin';

  return (
    <header className="navbar">
      <div className="navbar-row">
        <Link to="/" className="logo">
          <img className="logo-icon" src="/freshfood-app.png" alt="" width={28} height={28} />
          <span>FreshFood</span>
        </Link>

        <nav className="desktop-nav" aria-label="Main navigation">
          <NavLink to="/" end className={({ isActive }) => `nav-link ${isActive ? 'active' : ''}`}>Trang chủ</NavLink>
          <NavLink to="/products" className={() => `nav-link ${isProductsActive ? 'active' : ''}`}>Sản phẩm</NavLink>
          <NavLink to="/promotions" className={({ isActive }) => `nav-link ${isActive ? 'active' : ''}`}>Khuyến mãi</NavLink>
          <NavLink to="/blog" className={({ isActive }) => `nav-link ${isActive ? 'active' : ''}`}>Blog</NavLink>
          <NavLink to="/ai-assistant" className={({ isActive }) => `nav-link ${isActive ? 'active' : ''}`}>Hôm nay ăn gì?</NavLink>
          <NavLink to="/about" className={({ isActive }) => `nav-link ${isActive ? 'active' : ''}`}>Giới thiệu</NavLink>
          <NavLink to="/contact" className={({ isActive }) => `nav-link ${isActive ? 'active' : ''}`}>Liên hệ</NavLink>
          {isAuthenticated && isAdmin && (
            <NavLink to="/admin" className={({ isActive }) => `nav-link ${isActive ? 'active' : ''}`}>Admin</NavLink>
          )}
        </nav>

        <div className="header-actions">
          <button
            type="button"
            className="mobile-menu-btn"
            aria-label={mobileNavOpen ? 'Đóng menu' : 'Mở menu'}
            aria-expanded={mobileNavOpen}
            onClick={() => setMobileNavOpen((v) => !v)}
          >
            {mobileNavOpen ? <X size={20} /> : <Menu size={20} />}
          </button>

          <Link to="/cart" className="cart-badge" aria-label="Giỏ hàng">
            <ShoppingCart />
            {totalItems > 0 && <span className="badge">{totalItems}</span>}
          </Link>
          
          {isAuthenticated ? (
            <div className="user-menu" ref={menuRef}>
              <button
                type="button"
                className="user-menu-trigger"
                onClick={() => setOpen((v) => !v)}
                aria-haspopup="menu"
                aria-expanded={open}
                title={user?.fullName || 'Tài khoản'}
              >
                <span className="user-avatar" aria-hidden="true">
                  {avatarUrl && !avatarImgFailed ? (
                    <img
                      src={avatarUrl}
                      alt=""
                      decoding="async"
                      onError={() => setAvatarImgFailed(true)}
                    />
                  ) : (
                    avatarLetter
                  )}
                </span>
                <span className="user-name">{displayName}</span>
                <ChevronDown size={18} className={`user-caret ${open ? 'open' : ''}`} />
              </button>

              {open && (
                <div className="user-menu-dropdown" role="menu">
                  <Link to="/profile" className="user-menu-item" role="menuitem" onClick={() => setOpen(false)}>
                    <UserIcon size={18} />
                    Hồ sơ
                  </Link>
                  <Link to="/orders" className="user-menu-item" role="menuitem" onClick={() => setOpen(false)}>
                    <Package size={18} />
                    Đơn hàng
                  </Link>
                  <Link to="/wishlist" className="user-menu-item" role="menuitem" onClick={() => setOpen(false)}>
                    <Heart size={18} />
                    Yêu thích
                  </Link>
                  <Link to="/purchased-products" className="user-menu-item" role="menuitem" onClick={() => setOpen(false)}>
                    <History size={18} />
                    Sản phẩm đã mua
                  </Link>
                  <button
                    type="button"
                    className="user-menu-item danger"
                    role="menuitem"
                    onClick={() => {
                      setOpen(false);
                      logout();
                    }}
                  >
                    <LogOut size={18} />
                    Đăng xuất
                  </button>
                </div>
              )}
            </div>
          ) : (
            <Link to="/login" className="btn-login" style={{textDecoration: 'none'}}>Đăng nhập</Link>
          )}
        </div>
      </div>

      {mobileNavOpen && (
        <nav className="mobile-nav" aria-label="Mobile navigation">
          <NavLink to="/" end className={({ isActive }) => `mobile-nav-link ${isActive ? 'active' : ''}`}>Trang chủ</NavLink>
          <NavLink to="/products" className={() => `mobile-nav-link ${isProductsActive ? 'active' : ''}`}>Sản phẩm</NavLink>
          <NavLink to="/blog" className={({ isActive }) => `mobile-nav-link ${isActive ? 'active' : ''}`}>Blog</NavLink>
          <NavLink to="/about" className={({ isActive }) => `mobile-nav-link ${isActive ? 'active' : ''}`}>Giới thiệu</NavLink>
          <NavLink to="/promotions" className={({ isActive }) => `mobile-nav-link ${isActive ? 'active' : ''}`}>Khuyến mãi</NavLink>
          <NavLink to="/ai-assistant" className={({ isActive }) => `mobile-nav-link ${isActive ? 'active' : ''}`}>Hôm nay ăn gì?</NavLink>
          <NavLink to="/contact" className={({ isActive }) => `mobile-nav-link ${isActive ? 'active' : ''}`}>Liên hệ</NavLink>
          {isAuthenticated && isAdmin && (
            <NavLink to="/admin" className={({ isActive }) => `mobile-nav-link ${isActive ? 'active' : ''}`}>Admin</NavLink>
          )}
        </nav>
      )}
    </header>
  );
};
