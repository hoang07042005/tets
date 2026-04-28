import { Link, useNavigate } from 'react-router-dom';
import { Package, History } from 'lucide-react';
import { useEffect, useMemo, useState } from 'react';
import { useAuth } from '../../context/AuthContext';
import { apiService, resolveMediaUrl } from '../../services/api';
import type { Order, Product } from '../../types';

type PurchasedRow = {
  product: Product;
  times: number;
  qty: number;
  lastOrderDate: string;
};

function isOrderCounted(status: string): boolean {
  const s = (status || '').trim().toLowerCase();
  // Ignore cancelled/failed orders for "purchased"
  if (s === 'cancelled' || s === 'canceled' || s === 'failed') return false;
  return true;
}

export const PurchasedProductsPage = () => {
  const { user, isAuthenticated } = useAuth();
  const nav = useNavigate();
  const [orders, setOrders] = useState<Order[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const load = async () => {
      if (!isAuthenticated || !user) return;
      setLoading(true);
      try {
        const data = await apiService.getUserOrders(user.userID);
        setOrders(data || []);
      } finally {
        setLoading(false);
      }
    };
    load();
  }, [isAuthenticated, user?.userID]);

  const rows = useMemo(() => {
    const map = new Map<number, PurchasedRow>();
    for (const o of orders || []) {
      if (!isOrderCounted(o.status)) continue;
      for (const d of o.orderDetails || []) {
        const p = d.product;
        if (!p) continue;
        const id = p.productID;
        if (!id) continue;
        const prev = map.get(id);
        const qty = Number(d.quantity || 0) || 0;
        if (!prev) {
          map.set(id, {
            product: p,
            times: 1,
            qty,
            lastOrderDate: o.orderDate,
          });
        } else {
          prev.times += 1;
          prev.qty += qty;
          if (new Date(o.orderDate).getTime() > new Date(prev.lastOrderDate).getTime()) {
            prev.lastOrderDate = o.orderDate;
          }
        }
      }
    }
    const arr = Array.from(map.values());
    arr.sort((a, b) => new Date(b.lastOrderDate).getTime() - new Date(a.lastOrderDate).getTime());
    return arr;
  }, [orders]);

  const formatDate = (iso: string) => {
    const d = new Date(iso);
    if (Number.isNaN(d.getTime())) return iso;
    return d.toLocaleDateString('vi-VN', { year: 'numeric', month: 'short', day: '2-digit' });
  };

  const formatPrice = (price: number) =>
    new Intl.NumberFormat('vi-VN', { style: 'currency', currency: 'VND' }).format(price);

  if (!isAuthenticated || !user) {
    return (
      <div className="empty-state" style={{ padding: '5rem 2rem', textAlign: 'center' }}>
        <h2>Bạn chưa đăng nhập</h2>
        <p>Vui lòng đăng nhập để xem sản phẩm đã mua.</p>
        <Link to="/login" className="btn-primary" style={{ display: 'inline-block', marginTop: '1.5rem', textDecoration: 'none' }}>
          Đăng nhập
        </Link>
      </div>
    );
  }

  return (
    <div className="wishlist-page">
      <div className="container">
        <div className="wishlist-header">
          <div>
            <h1>Sản phẩm đã mua</h1>
            <p>Danh sách sản phẩm bạn đã từng đặt trước đây. Mua lại chỉ với 1 cú click.</p>
          </div>
          <Link to="/products" className="btn-primary" style={{ textDecoration: 'none' }}>
            Tiếp tục mua sắm
          </Link>
        </div>

        {loading ? (
          <div style={{ padding: '3rem', textAlign: 'center' }}>Đang tải...</div>
        ) : rows.length === 0 ? (
          <div className="feature-card" style={{ justifyContent: 'center' }}>
            <div style={{ textAlign: 'center' }}>
              <History size={44} color="#bbb" style={{ marginBottom: '0.75rem' }} />
              <h3 style={{ marginBottom: '0.25rem' }}>Chưa có sản phẩm đã mua</h3>
              <p style={{ color: '#777' }}>Khi bạn đặt hàng, các sản phẩm sẽ xuất hiện ở đây để mua lại nhanh.</p>
            </div>
          </div>
        ) : (
          <div className="grid">
            {rows.map((r) => {
              const p = r.product;
              const img = resolveMediaUrl(
                p.productImages?.find((x) => x.isMainImage)?.imageURL || p.productImages?.[0]?.imageURL || ''
              );
              return (
                <div key={p.productID} className="product-card">
                  <div className="product-image">
                    {img ? <img src={img} alt={p.productName} /> : <div className="product-noimg">No Image</div>}
                  </div>
                  <div className="product-info">
                    <span className="product-cat">{p.category?.categoryName || 'Sản phẩm'}</span>
                    <h3 className="product-name">{p.productName}</h3>
                    <div className="product-price">
                      {formatPrice(p.discountPrice ?? p.price)}
                      <span> / {p.unit || 'Kg'}</span>
                    </div>

                    <div style={{ display: 'flex', flexDirection: 'column', gap: 6, marginTop: 8, color: '#6b7280', fontSize: '0.9rem', fontWeight: 700 }}>
                      <div>Đã mua: {r.times} lần · SL: {r.qty}</div>
                      <div>Lần gần nhất: {formatDate(r.lastOrderDate)}</div>
                    </div>

                    <button className="btn-add" onClick={() => nav(`/product/${p.productToken || p.productID}`)}>
                      <Package size={18} /> Mua lại / Xem
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

