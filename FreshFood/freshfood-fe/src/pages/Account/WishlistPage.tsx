import { Link, useNavigate } from 'react-router-dom';
import { Heart, Package } from 'lucide-react';
import { useAuth } from '../../context/AuthContext';
import { useWishlist } from '../../context/WishlistContext';
import { resolveMediaUrl } from '../../services/api';
import type { Product } from '../../types';

export const WishlistPage = () => {
  const { user, isAuthenticated } = useAuth();
  const { items, loading, toggle } = useWishlist();
  const nav = useNavigate();

  const formatPrice = (price: number) =>
    new Intl.NumberFormat('vi-VN', { style: 'currency', currency: 'VND' }).format(price);

  if (!isAuthenticated || !user) {
    return (
      <div className="empty-state" style={{ padding: '5rem 2rem', textAlign: 'center' }}>
        <h2>Bạn chưa đăng nhập</h2>
        <p>Vui lòng đăng nhập để xem danh sách yêu thích.</p>
        <Link to="/login" className="btn-primary" style={{ display: 'inline-block', marginTop: '1.5rem', textDecoration: 'none' }}>
          Đăng nhập
        </Link>
      </div>
    );
  }

  const products: Product[] = items.map((x) => x.product!).filter(Boolean);

  return (
    <div className="wishlist-page">
      <div className="container">
        <div className="wishlist-header">
          <div>
            <h1>Yêu thích</h1>
            <p>Những sản phẩm bạn đã lưu để mua sau.</p>
          </div>
          <Link to="/products" className="btn-primary" style={{ textDecoration: 'none' }}>
            Tiếp tục mua sắm
          </Link>
        </div>

        {loading ? (
          <div style={{ padding: '3rem', textAlign: 'center' }}>Đang tải...</div>
        ) : products.length === 0 ? (
          <div className="feature-card" style={{ justifyContent: 'center' }}>
            <div style={{ textAlign: 'center' }}>
              <Heart size={44} color="#bbb" style={{ marginBottom: '0.75rem' }} />
              <h3 style={{ marginBottom: '0.25rem' }}>Chưa có sản phẩm yêu thích</h3>
              <p style={{ color: '#777' }}>Hãy bấm vào icon trái tim để lưu sản phẩm.</p>
            </div>
          </div>
        ) : (
          <div className="grid">
            {products.map((p) => {
              const img = resolveMediaUrl(
                p.productImages?.find((x) => x.isMainImage)?.imageURL || p.productImages?.[0]?.imageURL || ''
              );
              return (
                <div key={p.productID} className="product-card">
                  <div className="product-image">
                    {img ? <img src={img} alt={p.productName} /> : <div className="product-noimg">No Image</div>}
                    <button
                      type="button"
                      className="wishlist-btn wished"
                      title="Bỏ yêu thích"
                      onClick={(e) => {
                        e.stopPropagation();
                        toggle(p.productID);
                      }}
                    >
                      <Heart size={18} />
                    </button>
                  </div>
                  <div className="product-info">
                    <span className="product-cat">{p.category?.categoryName || 'Sản phẩm'}</span>
                    <h3 className="product-name">{p.productName}</h3>
                    <div className="product-price">
                      {formatPrice(p.price)}
                      <span> / {p.unit || 'Kg'}</span>
                    </div>
                    <button className="btn-add" onClick={() => nav(`/product/${p.productToken || p.productID}`)}>
                      <Package size={18} /> Xem chi tiết
                    </button>
                  </div>
                </div>
              );
            })}
          </div>
        )}
      </div>
    </div>
  );
};

