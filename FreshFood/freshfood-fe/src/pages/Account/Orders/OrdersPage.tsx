import { useEffect, useMemo, useState } from 'react';
import { Link } from 'react-router-dom';
import { useAuth } from '../../../context/AuthContext';
import { apiService } from '../../../services/api';
import { resolveMediaUrl } from '../../../services/api';
import type { Order } from '../../../types';
import { ChevronLeft, ChevronRight, Package } from 'lucide-react';

export const OrdersPage = () => {
  const { user, isAuthenticated } = useAuth();
  const [orders, setOrders] = useState<Order[]>([]);
  const [loading, setLoading] = useState(true);
  const [activeTab, setActiveTab] = useState<'all' | 'processing' | 'shipping' | 'delivered' | 'returned' | 'cancelled'>('all');
  const [currentPage, setCurrentPage] = useState(1);
  const itemsPerPage = 10;

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

  const formatPrice = (price: number) =>
    new Intl.NumberFormat('vi-VN', { style: 'currency', currency: 'VND' }).format(price);

  const formatDate = (iso: string) => {
    const d = new Date(iso);
    if (Number.isNaN(d.getTime())) return iso;
    return d.toLocaleDateString('vi-VN', { year: 'numeric', month: 'short', day: '2-digit' });
  };

  const statusUi = (status: string) => {
    const s = (status || '').toLowerCase();
    if (s === 'paid') return { label: 'Đã thanh toán', cls: 'delivered' };
    if (s === 'delivered') return { label: 'Đã giao', cls: 'delivered' };
    if (s === 'returnpending') return { label: 'Chờ duyệt hoàn hàng', cls: 'processing' };
    if (s === 'refundpending') return { label: 'Chờ hoàn tiền', cls: 'processing' };
    if (s === 'returned') return { label: 'Hoàn hàng', cls: 'processing' };
    if (s === 'refunded') return { label: 'Đã hoàn tiền', cls: 'refunded' };
    if (s === 'intransit' || s === 'in_transit' || s === 'shipping') return { label: 'Đang giao', cls: 'intransit' };
    if (s === 'processing') return { label: 'Đang xử lý', cls: 'processing' };
    if (s === 'cancelled' || s === 'canceled') return { label: 'Đã hủy', cls: 'failed' };
    if (s === 'failed') return { label: 'Thất bại', cls: 'failed' };
    return { label: status || 'Đang xử lý', cls: 'processing' };
  };

  const sorted = useMemo(() => {
    return [...orders].sort((a, b) => new Date(b.orderDate).getTime() - new Date(a.orderDate).getTime());
  }, [orders]);

  const filtered = useMemo(() => {
    if (activeTab === 'all') return sorted;
    return sorted.filter((o) => {
      const s = (o.status || '').toLowerCase();
      if (activeTab === 'processing') return s === 'processing';
      if (activeTab === 'shipping') return s === 'shipping' || s === 'intransit' || s === 'in_transit';
      if (activeTab === 'delivered') return s === 'delivered' || s === 'paid';
      if (activeTab === 'returned') return s === 'returnpending' || s === 'refundpending' || s === 'returned' || s === 'refunded';
      if (activeTab === 'cancelled') return s === 'cancelled' || s === 'canceled' || s === 'failed';
      return true;
    });
  }, [sorted, activeTab]);

  useEffect(() => {
    setCurrentPage(1);
  }, [activeTab]);

  const totalPages = Math.ceil(filtered.length / itemsPerPage);
  const paginated = useMemo(() => {
    const start = (currentPage - 1) * itemsPerPage;
    return filtered.slice(start, start + itemsPerPage);
  }, [filtered, currentPage]);

  const goToPage = (page: number) => {
    const next = Math.min(Math.max(page, 1), Math.max(totalPages, 1));
    setCurrentPage(next);
    window.scrollTo({ top: 0, behavior: 'smooth' });
  };

  const pageItems = useMemo(() => {
    const maxButtons = 5;
    if (totalPages <= maxButtons) return Array.from({ length: totalPages }, (_, i) => i + 1);
    const half = Math.floor(maxButtons / 2);
    let start = currentPage - half;
    let end = currentPage + half;
    if (start < 1) {
      start = 1;
      end = maxButtons;
    }
    if (end > totalPages) {
      end = totalPages;
      start = totalPages - maxButtons + 1;
    }
    return Array.from({ length: end - start + 1 }, (_, i) => start + i);
  }, [currentPage, totalPages]);

  const counts = useMemo(() => {
    const out = { all: sorted.length, processing: 0, shipping: 0, delivered: 0, returned: 0, cancelled: 0 };
    for (const o of sorted) {
      const s = (o.status || '').toLowerCase();
      if (s === 'processing') out.processing++;
      else if (s === 'shipping' || s === 'intransit' || s === 'in_transit') out.shipping++;
      else if (s === 'delivered' || s === 'paid') out.delivered++;
      else if (s === 'returnpending' || s === 'refundpending' || s === 'returned' || s === 'refunded') out.returned++;
      else if (s === 'cancelled' || s === 'canceled' || s === 'failed') out.cancelled++;
      else out.processing++;
    }
    return out;
  }, [sorted]);

  const formatOrderCode = (o: Order) => {
    if (o.orderCode && String(o.orderCode).trim()) {
      const c = String(o.orderCode).trim();
      return c.startsWith('#') ? c : `#${c}`;
    }
    return `#FF-${String(o.orderID).padStart(5, '0')}`;
  };

  if (!isAuthenticated || !user) {
    return (
      <div className="empty-state" style={{padding: '5rem 2rem', textAlign: 'center'}}>
        <h2>Bạn chưa đăng nhập</h2>
        <p>Vui lòng đăng nhập để xem đơn hàng.</p>
        <Link to="/login" className="btn-primary" style={{display: 'inline-block', marginTop: '1.5rem', textDecoration: 'none'}}>
          Đăng nhập
        </Link>
      </div>
    );
  }

  return (
    <div className="orders-history-page">
      <div className="container">
        <div className="orders-history-header">
          <div>
            <h1>Lịch sử đơn hàng</h1>
            <p>Xem các đơn hàng gần đây và theo dõi hành trình nông sản tươi đến tận cửa nhà bạn.</p>
          </div>
        </div>

        <div className="orders-tabs" role="tablist" aria-label="Lọc trạng thái đơn hàng">
          <button type="button" className={`orders-tab ${activeTab === 'all' ? 'active' : ''}`} onClick={() => setActiveTab('all')} role="tab" aria-selected={activeTab === 'all'}>
            Tất cả đơn hàng <span className="orders-tab__count">{counts.all}</span>
          </button>
          <button type="button" className={`orders-tab ${activeTab === 'processing' ? 'active' : ''}`} onClick={() => setActiveTab('processing')} role="tab" aria-selected={activeTab === 'processing'}>
            Đang xử lý <span className="orders-tab__count">{counts.processing}</span>
          </button>
          <button type="button" className={`orders-tab ${activeTab === 'shipping' ? 'active' : ''}`} onClick={() => setActiveTab('shipping')} role="tab" aria-selected={activeTab === 'shipping'}>
            Đang giao <span className="orders-tab__count">{counts.shipping}</span>
          </button>
          <button type="button" className={`orders-tab ${activeTab === 'delivered' ? 'active' : ''}`} onClick={() => setActiveTab('delivered')} role="tab" aria-selected={activeTab === 'delivered'}>
            Đã giao <span className="orders-tab__count">{counts.delivered}</span>
          </button>
          <button type="button" className={`orders-tab ${activeTab === 'returned' ? 'active' : ''}`} onClick={() => setActiveTab('returned')} role="tab" aria-selected={activeTab === 'returned'}>
            Hoàn hàng <span className="orders-tab__count">{counts.returned}</span>
          </button>
          <button type="button" className={`orders-tab ${activeTab === 'cancelled' ? 'active' : ''}`} onClick={() => setActiveTab('cancelled')} role="tab" aria-selected={activeTab === 'cancelled'}>
            Đã hủy <span className="orders-tab__count">{counts.cancelled}</span>
          </button>
        </div>

      {loading ? (
        <div style={{padding: '3rem', textAlign: 'center'}}>Đang tải đơn hàng...</div>
      ) : sorted.length === 0 ? (
        <div className="feature-card" style={{justifyContent: 'center'}}>
          <div style={{textAlign: 'center'}}>
            <Package size={44} color="#bbb" style={{marginBottom: '0.75rem'}} />
            <h3 style={{marginBottom: '0.25rem'}}>Chưa có đơn hàng</h3>
            <p style={{color: '#777'}}>Bạn chưa đặt đơn nào. Hãy mua sắm ngay!</p>
          </div>
        </div>
      ) : (
        <>
          <div className="orders-grid">
            {paginated.map((o) => {
              const ui = statusUi(o.status);
              const first = o.orderDetails?.[0];
              const thumb = resolveMediaUrl(
                first?.product?.productImages?.[0]?.imageURL || first?.product?.productImages?.find((x) => x.isMainImage)?.imageURL || ''
              );
              const dateText = `Đặt ngày: ${formatDate(o.orderDate)}`;
              const code = formatOrderCode(o);
              return (
                <article key={o.orderID} className="order-tile">
                  <div className="order-tile__head">
                    <div className="order-tile__left">
                      <div className="order-tile__thumb" aria-hidden>
                        {thumb ? <img src={thumb} alt="" /> : <div className="order-history-thumb-fallback" />}
                      </div>
                      <div className="order-tile__meta">
                        <div className="order-tile__code">{code}</div>
                        <div className="order-tile__date">{dateText}</div>
                      </div>
                    </div>
                    <span className={`order-status-pill ${ui.cls}`}>{ui.label}</span>
                  </div>

                  <div className="order-tile__body">
                    <div className="order-tile__amount-label">TỔNG THANH TOÁN</div>
                    <div className="order-tile__amount">{formatPrice(o.totalAmount)}</div>
                  </div>

                  <Link to={`/orders/${o.orderToken || o.orderID}`} className="order-tile__link">
                    Xem chi tiết <span aria-hidden>→</span>
                  </Link>
                </article>
              );
            })}
          </div>

          {totalPages > 1 ? (
            <nav className="shop-pager" aria-label="Phân trang đơn hàng" style={{ marginTop: '2.25rem' }}>
              <button
                type="button"
                onClick={() => goToPage(currentPage - 1)}
                disabled={currentPage <= 1}
                aria-label="Trang trước"
                style={{
                  width: 38,
                  height: 38,
                  borderRadius: 999,
                  border: '1px solid #e5e7eb',
                  background: '#fff',
                  color: '#6b7280',
                  display: 'grid',
                  placeItems: 'center',
                  cursor: currentPage <= 1 ? 'not-allowed' : 'pointer',
                  opacity: currentPage <= 1 ? 0.5 : 1,
                }}
              >
                <ChevronLeft size={18} aria-hidden />
              </button>

              {pageItems.map((p) => {
                const active = p === currentPage;
                return (
                  <button
                    key={p}
                    type="button"
                    onClick={() => goToPage(p)}
                    aria-label={`Trang ${p}`}
                    aria-current={active ? 'page' : undefined}
                    style={{
                      width: 38,
                      height: 38,
                      borderRadius: 999,
                      border: active ? '1px solid var(--primary)' : '1px solid #e5e7eb',
                      background: active ? 'var(--primary)' : '#fff',
                      color: active ? '#fff' : '#111827',
                      fontWeight: 800,
                      display: 'grid',
                      placeItems: 'center',
                      cursor: 'pointer',
                    }}
                  >
                    {p}
                  </button>
                );
              })}

              <button
                type="button"
                onClick={() => goToPage(currentPage + 1)}
                disabled={currentPage >= totalPages}
                aria-label="Trang sau"
                style={{
                  width: 38,
                  height: 38,
                  borderRadius: 999,
                  border: '1px solid #e5e7eb',
                  background: '#fff',
                  color: '#6b7280',
                  display: 'grid',
                  placeItems: 'center',
                  cursor: currentPage >= totalPages ? 'not-allowed' : 'pointer',
                  opacity: currentPage >= totalPages ? 0.5 : 1,
                }}
              >
                <ChevronRight size={18} aria-hidden />
              </button>
            </nav>
          ) : null}
        </>
      )}
      </div>
    </div>
  );
};

