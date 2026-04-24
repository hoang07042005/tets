import { useEffect, useMemo, useState } from 'react';
import { Link, Navigate, Route, Routes, useLocation, useNavigate } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';
import { AdminSidebar, type AdminTabKey, isProductSubTab } from './AdminSidebar';
import { AdminDashboard } from './AdminDashboard';
import { AdminCategoryPage } from './category/AdminCategoryPage';
import { AdminSupplierPage } from './supplier/AdminSupplierPage';
import { AdminProductListPage } from './product/AdminProductListPage';
import { AdminProductCreatePage } from './product/AdminProductCreatePage';
import { AdminProductEditPage } from './product/AdminProductEditPage';
import { AdminOrdersListPage } from './orders/AdminOrdersListPage';
import { AdminOrderDetailPage } from './orders/AdminOrderDetailPage';
import { AdminVoucherListPage } from './voucher/AdminVoucherListPage';
import { AdminVoucherCreatePage } from './voucher/AdminVoucherCreatePage';
import { AdminVoucherEditPage } from './voucher/AdminVoucherEditPage';
import { AdminBlogPostListPage } from './blog/AdminBlogPostListPage';
import { AdminBlogPostCreatePage } from './blog/AdminBlogPostCreatePage';
import { AdminBlogPostEditPage } from './blog/AdminBlogPostEditPage';
import { AdminUserListPage } from './users/AdminUserListPage';
import { AdminContactMessagesListPage } from './contact-messages/AdminContactMessagesListPage';
import { AdminReviewsPage } from './reviews/AdminReviewsPage';
import { AdminHomePageSettingsPage } from './home/AdminHomePageSettingsPage';

export const AdminPage = () => {
  const { user, isAuthenticated } = useAuth();
  const location = useLocation();
  const navigate = useNavigate();

  const [tab, setTab] = useState<AdminTabKey>('dashboard');
  const [productsOpen, setProductsOpen] = useState(false);

  const tabFromPath = useMemo<AdminTabKey>(() => {
    const p = (location.pathname || '').toLowerCase();
    if (p === '/admin' || p === '/admin/') return 'dashboard';
    if (p.startsWith('/admin/home')) return 'home-settings';
    if (p.startsWith('/admin/products')) return 'products-list';
    if (p.startsWith('/admin/suppliers')) return 'products-supplier';
    if (p.startsWith('/admin/categories')) return 'products-category';
    if (p.startsWith('/admin/vouchers')) return 'vouchers';
    if (p.startsWith('/admin/blog')) return 'blog';
    if (p.startsWith('/admin/orders')) return 'orders';
    if (p.startsWith('/admin/reviews')) return 'reviews';
    if (p.startsWith('/admin/contact-messages')) return 'contact-messages';
    if (p.startsWith('/admin/users')) return 'users';
    return 'dashboard';
  }, [location.pathname]);

  useEffect(() => {
    setTab(tabFromPath);
    if (isProductSubTab(tabFromPath)) setProductsOpen(true);
  }, [tabFromPath]);

  const handleTab = (next: AdminTabKey) => {
    setTab(next);
    if (isProductSubTab(next)) setProductsOpen(true);
    if (next === 'dashboard') navigate('/admin');
    else if (next === 'home-settings') navigate('/admin/home');
    else if (next === 'products-list') navigate('/admin/products');
    else if (next === 'products-supplier') navigate('/admin/suppliers');
    else if (next === 'products-category') navigate('/admin/categories');
    else if (next === 'vouchers') navigate('/admin/vouchers');
    else if (next === 'blog') navigate('/admin/blog');
    else if (next === 'orders') navigate('/admin/orders');
    else if (next === 'reviews') navigate('/admin/reviews');
    else if (next === 'contact-messages') navigate('/admin/contact-messages');
    else if (next === 'users') navigate('/admin/users');
  };

  const isAdmin = useMemo(() => {
    const role = (user?.role || '').toLowerCase();
    return role === 'admin';
  }, [user?.role]);

  if (!isAuthenticated || !user) {
    return (
      <div className="empty-state" style={{ padding: '5rem 2rem', textAlign: 'center' }}>
        <h2>Bạn chưa đăng nhập</h2>
        <p>Vui lòng đăng nhập bằng tài khoản quản trị để truy cập trang Admin.</p>
        <Link to="/login" className="btn-primary" style={{ display: 'inline-block', marginTop: '1.5rem', textDecoration: 'none' }}>
          Đăng nhập
        </Link>
      </div>
    );
  }

  if (!isAdmin) {
    return (
      <div className="empty-state" style={{ padding: '5rem 2rem', textAlign: 'center' }}>
        <h2>Không có quyền truy cập</h2>
        <p>Tài khoản của bạn không có quyền quản trị.</p>
        <Link to="/" className="btn-primary" style={{ display: 'inline-block', marginTop: '1.5rem', textDecoration: 'none' }}>
          Về trang chủ
        </Link>
      </div>
    );
  }

  return (
    <main className="admin-page">
      <div className="container">
        <div className="admin-layout">
          <AdminSidebar tab={tab} onChange={handleTab} productsOpen={productsOpen} onProductsOpenChange={setProductsOpen} />

          <section className="admin-content">
            <Routes>
              <Route index element={<AdminDashboard />} />

              <Route path="home" element={<AdminHomePageSettingsPage />} />

              <Route path="products" element={<AdminProductListPage />} />
              <Route path="products/new" element={<AdminProductCreatePage />} />
              <Route path="products/:id/edit" element={<AdminProductEditPage />} />

              <Route path="suppliers" element={<AdminSupplierPage />} />
              <Route path="categories" element={<AdminCategoryPage />} />

              <Route path="vouchers" element={<AdminVoucherListPage />} />
              <Route path="vouchers/new" element={<AdminVoucherCreatePage />} />
              <Route path="vouchers/:id/edit" element={<AdminVoucherEditPage />} />

              <Route path="blog" element={<AdminBlogPostListPage />} />
              <Route path="blog/new" element={<AdminBlogPostCreatePage />} />
              <Route path="blog/:id/edit" element={<AdminBlogPostEditPage />} />

              <Route path="orders" element={<AdminOrdersListPage />} />
              <Route path="orders/:id" element={<AdminOrderDetailPage />} />

              <Route path="reviews" element={<AdminReviewsPage />} />

              <Route path="contact-messages" element={<AdminContactMessagesListPage />} />

              <Route path="users" element={<AdminUserListPage />} />

              <Route path="*" element={<Navigate to="/admin" replace />} />
            </Routes>
          </section>
        </div>
      </div>
    </main>
  );
};
