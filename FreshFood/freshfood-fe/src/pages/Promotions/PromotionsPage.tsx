import { useEffect, useMemo, useState } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { Heart, ShoppingCart, Tag } from 'lucide-react';
import { apiService, resolveMediaUrl } from '../../services/api';
import type { Product } from '../../types';
import { useCart } from '../../context/CartContext';
import { useAuth } from '../../context/AuthContext';
import { useWishlist } from '../../context/WishlistContext';

function seasonBadgeLabel(): string {
  const y = new Date().getFullYear();
  const m = new Date().getMonth() + 1;
  if (m >= 3 && m <= 5) return `MÙA XUÂN ${y}`;
  if (m >= 6 && m <= 8) return `MÙA HÈ ${y}`;
  if (m >= 9 && m <= 11) return `MÙA THU ${y}`;
  return `MÙA ĐÔNG ${y}`;
}

const vndFormatter = new Intl.NumberFormat('vi-VN', { style: 'currency', currency: 'VND' });

function formatVnd(n: number): string {
  const v = !Number.isFinite(n) || n < 0 ? 0 : n;
  return vndFormatter.format(Math.round(v));
}

function mainImageUrl(p: Product): string {
  const imgs = p.productImages ?? [];
  const main = imgs.find((i) => i.isMainImage);
  const url = main?.imageURL ?? imgs[0]?.imageURL;
  return resolveMediaUrl(url) || '';
}

function discountPercent(price: number, discountPrice: number): number | null {
  if (!discountPrice || discountPrice >= price || price <= 0) return null;
  return Math.round(((price - discountPrice) / price) * 100);
}

function categoryLabel(p: Product): string {
  const raw = p.category?.categoryName?.trim();
  if (raw) return raw.toUpperCase();
  return 'KHUYẾN MÃI';
}

export const PromotionsPage = () => {
  const [products, setProducts] = useState<Product[]>([]);
  const [loading, setLoading] = useState(true);
  const nav = useNavigate();
  const { addToCart } = useCart();
  const { isAuthenticated } = useAuth();
  const { isWished, toggle } = useWishlist();
  const badgeText = useMemo(() => seasonBadgeLabel(), []);

  useEffect(() => {
    let cancelled = false;
    (async () => {
      setLoading(true);
      try {
        const data = await apiService.getPromotions();
        if (!cancelled) setProducts(Array.isArray(data) ? data : []);
      } catch {
        if (!cancelled) setProducts([]);
      } finally {
        if (!cancelled) setLoading(false);
      }
    })();
    return () => {
      cancelled = true;
    };
  }, []);

  return (
    <main className="promotions-page">
      <div className="promotions-inner">
        <header className="promotions-hero">
          <div className="promotions-hero__text">
            <h1 className="promotions-hero__title">
              Khuyến mãi từ <span className="promotions-hero__brand">FreshFood</span>
            </h1>
            <p className="promotions-hero__desc">
              Combo rau củ quả tươi, eat clean và detox — gom gọn cho bữa ăn nhà bạn với mức giá ưu đãi. Số lượng có hạn,
              ưu tiên đơn đặt sớm trong mùa.
            </p>
          </div>
          <div className="promotions-hero__badge" aria-hidden>
            {badgeText}
          </div>
        </header>

        {loading ? (
          <div className="promotions-state promotions-state--loading">Đang tải ưu đãi…</div>
        ) : products.length === 0 ? (
          <div className="promotions-state promotions-state--empty">
            <Tag size={48} strokeWidth={1.5} aria-hidden />
            <h2>Hiện chưa có chương trình khuyến mãi</h2>
            <p>Quay lại sau để không bỏ lỡ combo và giá tốt nhé.</p>
          </div>
        ) : (
          <div className="promotions-grid">
            {products.map((product) => {
              const img = mainImageUrl(product);
              const sell = product.discountPrice != null && product.discountPrice < product.price ? product.discountPrice : product.price;
              const pct = discountPercent(product.price, product.discountPrice ?? 0);
              const hasSale = product.discountPrice != null && product.discountPrice < product.price;

              return (
                <article key={product.productID} className="promotions-card">
                  <div className="promotions-card__media">
                    <Link to={`/product/${product.productToken || product.productID}`} className="promotions-card__media-link">
                      {img ? (
                        <img src={img} alt="" className="promotions-card__img" loading="lazy" decoding="async" />
                      ) : (
                        <div className="promotions-card__img promotions-card__img--placeholder" aria-hidden />
                      )}
                      {pct != null && pct > 0 && (
                        <span className="promotions-card__discount">-{pct}%</span>
                      )}
                    </Link>
                    <button
                      type="button"
                      className={`promotions-card__wishlist ${isWished(product.productID) ? 'is-active' : ''}`}
                      title={isWished(product.productID) ? 'Bỏ yêu thích' : 'Yêu thích'}
                      aria-label={isWished(product.productID) ? 'Bỏ yêu thích' : 'Yêu thích'}
                      onClick={(e) => {
                        e.preventDefault();
                        e.stopPropagation();
                        if (!isAuthenticated) {
                          nav('/login');
                          return;
                        }
                        toggle(product.productID);
                      }}
                    >
                      <Heart size={20} strokeWidth={2} aria-hidden />
                    </button>
                  </div>

                  <div className="promotions-card__body">
                    <p className="promotions-card__cat">{categoryLabel(product)}</p>
                    <Link to={`/product/${product.productToken || product.productID}`} className="promotions-card__title-link">
                      <h2 className="promotions-card__title">{product.productName}</h2>
                    </Link>

                    <div className="promotions-card__footer">
                      <div className="promotions-card__prices">
                        <span className="promotions-card__price-now">{formatVnd(sell)}</span>
                        {hasSale && (
                          <span className="promotions-card__price-old">{formatVnd(product.price)}</span>
                        )}
                      </div>
                      <button
                        type="button"
                        className="promotions-card__btn"
                        onClick={() => addToCart(product)}
                      >
                        <ShoppingCart size={18} strokeWidth={2} aria-hidden />
                        <span>Thêm vào giỏ</span>
                      </button>
                    </div>
                  </div>
                </article>
              );
            })}
          </div>
        )}
      </div>
    </main>
  );
};
