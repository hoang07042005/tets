import { BrowserRouter as Router, Routes, Route, useLocation } from 'react-router-dom'
import './App.css'
import { Header } from './components/Header'
import { Footer } from './components/Footer'
import { Home } from './pages/Home/Home'
import { CartPage } from './pages/Cart/Cart'
import { CheckoutPage } from './pages/Checkout/Checkout'
import { LoginPage } from './pages/Account/Auth/Login'
import { RegisterPage } from './pages/Account/Auth/Register'
import { ForgotPasswordPage } from './pages/Account/Auth/ForgotPassword'
import { ResetPasswordPage } from './pages/Account/Auth/ResetPassword'
import { GuestSetPasswordPage } from './pages/Account/Auth/GuestSetPasswordPage'
import { ProductPage } from './pages/Shop/ProductPage'
import { PromotionsPage } from './pages/Promotions/PromotionsPage'
import { ContactPage } from './pages/Home/ContactPage'
import { AboutPage } from './pages/Home/AboutPage'
import { CartProvider } from './context/CartContext'
import { AuthProvider } from './context/AuthContext'
import { ProductDetailPage } from './pages/Shop/ProductDetailPage'
import { VnPayReturnPage } from './pages/Checkout/VnPayReturnPage'
import { MomoReturnPage } from './pages/Checkout/MomoReturnPage'
import { ProfilePage } from './pages/Account/ProfilePage'
import { OrdersPage } from './pages/Account/Orders/OrdersPage'
import { OrderDetailPage } from './pages/Account/Orders/OrderDetailPage'
import { OrderTrackPage } from './pages/Account/Orders/OrderTrackPage'
import { WishlistPage } from './pages/Account/WishlistPage'
import { PurchasedProductsPage } from './pages/Account/PurchasedProductsPage'
import { WishlistProvider } from './context/WishlistContext'
import { AdminPage } from './admin-pages/AdminPage'
import { BlogListPage } from './pages/Blog/BlogListPage'
import { BlogDetailPage } from './pages/Blog/BlogDetailPage'
import { FaqPage } from './pages/Help/FaqPage'
import { TermsOfServicePage } from './pages/Legal/TermsOfServicePage'
import { PrivacyPolicyPage } from './pages/Legal/PrivacyPolicyPage'
import { SustainabilityPage } from './pages/Home/SustainabilityPage'
import { AiAssistantPage } from './pages/Ai/AiAssistantPage'

import { useState, useEffect } from 'react';

function AppFrame() {
  const location = useLocation();
  const path = (location.pathname || '').toLowerCase();
  const hideChrome =
    path === '/login' ||
    path === '/register' ||
    path === '/forgot-password' ||
    path === '/reset-password' ||
    path === '/tao-mat-khau';

  const [isMaintenance, setIsMaintenance] = useState(false);

  useEffect(() => {
    const handleMaintenance = () => setIsMaintenance(true);
    window.addEventListener('maintenance-mode', handleMaintenance);
    return () => window.removeEventListener('maintenance-mode', handleMaintenance);
  }, []);

  if (isMaintenance && path !== '/login') {
    return (
      <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', height: '100vh', textAlign: 'center', padding: 20, backgroundColor: '#f9fafb' }}>
        <h1 style={{ fontSize: '2rem', marginBottom: 16, color: '#111827' }}>Hệ thống đang bảo trì</h1>
        <p style={{ color: '#4b5563', marginBottom: 24, fontSize: '1.1rem' }}>Chúng tôi đang tiến hành nâng cấp hệ thống. Vui lòng quay lại sau.</p>
        <div style={{ display: 'flex', gap: 12 }}>
          <button onClick={() => window.location.reload()} style={{ padding: '10px 20px', backgroundColor: '#10b981', color: '#fff', border: 'none', borderRadius: 8, cursor: 'pointer', fontWeight: 600 }}>Tải lại trang</button>
          <button onClick={() => window.location.href = '/login'} style={{ padding: '10px 20px', backgroundColor: '#6b7280', color: '#fff', border: 'none', borderRadius: 8, cursor: 'pointer', fontWeight: 600 }}>Đăng nhập Admin</button>
        </div>
      </div>
    );
  }

  return (
    <div className="app-container">
      {!hideChrome && <Header />}
      <Routes>
        <Route path="/" element={<Home />} />
        <Route path="/blog" element={<BlogListPage />} />
        <Route path="/blog/:slug" element={<BlogDetailPage />} />
        <Route path="/cart" element={<CartPage />} />
        <Route path="/checkout" element={<CheckoutPage />} />
        <Route path="/login" element={<LoginPage />} />
        <Route path="/register" element={<RegisterPage />} />
        <Route path="/forgot-password" element={<ForgotPasswordPage />} />
        <Route path="/reset-password" element={<ResetPasswordPage />} />
        <Route path="/tao-mat-khau" element={<GuestSetPasswordPage />} />
        <Route path="/products" element={<ProductPage />} />
        <Route path="/promotions" element={<PromotionsPage />} />
        <Route path="/contact" element={<ContactPage />} />
        <Route path="/about" element={<AboutPage />} />
        <Route path="/sustainability" element={<SustainabilityPage />} />
        <Route path="/faq" element={<FaqPage />} />
        <Route path="/terms" element={<TermsOfServicePage />} />
        <Route path="/privacy" element={<PrivacyPolicyPage />} />
        <Route path="/product/:id" element={<ProductDetailPage />} />
        <Route path="/payment/vnpay-return" element={<VnPayReturnPage />} />
        <Route path="/payment/momo-return" element={<MomoReturnPage />} />
        <Route path="/profile" element={<ProfilePage />} />
        <Route path="/orders" element={<OrdersPage />} />
        <Route path="/orders/:id" element={<OrderDetailPage />} />
        <Route path="/tra-cuu-don-hang" element={<OrderTrackPage />} />
        <Route path="/wishlist" element={<WishlistPage />} />
        <Route path="/purchased-products" element={<PurchasedProductsPage />} />
        <Route path="/ai-assistant" element={<AiAssistantPage />} />
        <Route path="/admin/*" element={<AdminPage />} />
      </Routes>
      {!hideChrome && <Footer />}
    </div>
  );
}

function App() {
  return (
    <AuthProvider>
      <CartProvider>
        <WishlistProvider>
          <Router>
            <AppFrame />
          </Router>
        </WishlistProvider>
      </CartProvider>
    </AuthProvider>
  )
}

export default App
