import { useEffect, useMemo, useState } from 'react';
import { Link, useLocation } from 'react-router-dom';
import { PackageSearch, Search } from 'lucide-react';
import { apiService } from '../../../services/api';
import type { PublicOrderTrack } from '../../../types';
import { partnerTrackingUrl } from '../../../utils/shipmentTracking';

function formatDateTimeVi(d: string): string {
  const dt = new Date(d);
  if (Number.isNaN(dt.getTime())) return d;
  return dt.toLocaleString('vi-VN', {
    day: '2-digit',
    month: '2-digit',
    year: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
  });
}

function statusLabel(s: string): string {
  const x = (s || '').toLowerCase();
  if (x === 'completed' || x === 'delivered') return 'Hoàn tất / Đã giao';
  if (x === 'shipping' || x === 'intransit' || x === 'in_transit') return 'Đang giao hàng';
  if (x === 'preparing' || x === 'preparing_goods' || x === 'packing') return 'Chuẩn bị hàng';
  if (x === 'processing') return 'Đã xác nhận';
  if (x === 'pending') return 'Chờ xử lý';
  return s || '—';
}

export function OrderTrackPage() {
  const location = useLocation();
  const qs = useMemo(() => new URLSearchParams(location.search), [location.search]);
  const initialCode = (qs.get('code') || '').trim();
  const initialPhone = (qs.get('phone') || '').trim();

  const [code, setCode] = useState(initialCode);
  const [phone, setPhone] = useState(initialPhone);
  const [loading, setLoading] = useState(false);
  const [err, setErr] = useState<string | null>(null);
  const [result, setResult] = useState<PublicOrderTrack | null>(null);

  const doTrack = async (nextCode: string, nextPhone: string) => {
    setErr(null);
    setResult(null);
    if (!nextCode.trim() || !nextPhone.trim()) {
      setErr('Vui lòng nhập mã đơn và số điện thoại.');
      return;
    }
    setLoading(true);
    try {
      const data = await apiService.trackOrder(nextCode, nextPhone);
      if (!data) {
        setErr('Không tìm thấy đơn hàng. Kiểm tra mã đơn và số điện thoại đã dùng khi đặt hàng.');
        return;
      }
      setResult(data);
    } catch (e2) {
      setErr(e2 instanceof Error ? e2.message : 'Tra cứu thất bại.');
    } finally {
      setLoading(false);
    }
  };

  const submit = async (e: React.FormEvent) => {
    e.preventDefault();
    await doTrack(code, phone);
  };

  useEffect(() => {
    if (!initialCode || !initialPhone) return;
    // Auto run once when coming from footer quick search.
    void doTrack(initialCode, initialPhone);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  return (
    <div className="order-track-page">
      <div className="container order-track-inner">
        <div className="order-track-card">
          <div className="order-track-grid">
            {/* Cột trái — form */}
            <div className="order-track-form-col">
              <div className="order-track-form-head">
                <div className="order-track-icon-wrap" aria-hidden>
                  <PackageSearch size={26} strokeWidth={2} />
                </div>
                <h1 className="order-track-title">
                  <span className="order-track-title-line">Tra cứu</span>
                  <span className="order-track-title-line">vận đơn</span>
                </h1>
                <p className="order-track-lead">
                  Nhập mã đơn hàng và số điện thoại đã dùng khi đặt (khớp tài khoản khách hàng).
                </p>
              </div>

              <form className="order-track-form" onSubmit={submit} noValidate>
                <label className="order-track-field">
                  <span className="order-track-label">Mã đơn hàng</span>
                  <input
                    className="order-track-input"
                    value={code}
                    onChange={(e) => setCode(e.target.value)}
                    placeholder="VD: VH-2026001234"
                    autoComplete="off"
                  />
                </label>
                <label className="order-track-field">
                  <span className="order-track-label">Số điện thoại</span>
                  <input
                    className="order-track-input"
                    value={phone}
                    onChange={(e) => setPhone(e.target.value)}
                    placeholder="SĐT đặt hàng"
                    inputMode="tel"
                    autoComplete="tel"
                  />
                </label>
                <button type="submit" className="btn-primary order-track-submit" disabled={loading}>
                  {loading ? (
                    'Đang tra cứu…'
                  ) : (
                    <>
                      <Search size={18} strokeWidth={2.5} aria-hidden />
                      Tra cứu
                    </>
                  )}
                </button>
              </form>

              {err ? <div className="order-track-alert">{err}</div> : null}
            </div>

            {/* Cột phải — kết quả */}
            <div className="order-track-result-col">
              <div className="order-track-result-panel">
                <h2 className="order-track-result-heading">Kết quả</h2>

                {loading ? (
                  <div className="order-track-placeholder order-track-placeholder--loading">
                    <span className="order-track-skel order-track-skel--t" />
                    <span className="order-track-skel order-track-skel--l" />
                    <span className="order-track-skel order-track-skel--l" />
                  </div>
                ) : result ? (
                  <div className="order-track-result-body">
                    <div className="order-track-kv">
                      <span className="order-track-k">Mã đơn</span>
                      <span className="order-track-v order-track-v--code">{result.orderCode}</span>
                    </div>
                    <div className="order-track-kv">
                      <span className="order-track-k">Trạng thái đơn</span>
                      <span className="order-track-v">{statusLabel(result.status)}</span>
                    </div>
                    <div className="order-track-kv">
                      <span className="order-track-k">Đặt lúc</span>
                      <span className="order-track-v">{formatDateTimeVi(result.orderDate)}</span>
                    </div>

                    {(result.shipments || []).map((s) => {
                      const ext = partnerTrackingUrl(s.carrier, s.trackingNumber);
                      return (
                        <div key={s.shipmentID} className="order-track-ship-block">
                          <div className="order-track-ship-title">Vận đơn #{s.shipmentID}</div>
                          <div className="order-track-kv">
                            <span className="order-track-k">Đối tác</span>
                            <span className="order-track-v">{s.carrier?.trim() || '—'}</span>
                          </div>
                          <div className="order-track-kv">
                            <span className="order-track-k">Mã vận đơn</span>
                            <span className="order-track-v order-track-v--mono">{s.trackingNumber?.trim() || '—'}</span>
                          </div>
                          <div className="order-track-kv">
                            <span className="order-track-k">Trạng thái giao</span>
                            <span className="order-track-v">{s.status?.trim() || '—'}</span>
                          </div>
                          {s.shippedDate ? (
                            <div className="order-track-kv">
                              <span className="order-track-k">Gửi hàng</span>
                              <span className="order-track-v">{formatDateTimeVi(s.shippedDate)}</span>
                            </div>
                          ) : null}
                          {s.actualDeliveryDate ? (
                            <div className="order-track-kv">
                              <span className="order-track-k">Giao xong</span>
                              <span className="order-track-v">{formatDateTimeVi(s.actualDeliveryDate)}</span>
                            </div>
                          ) : null}
                          {ext ? (
                            <a href={ext} target="_blank" rel="noreferrer" className="order-track-partner-link">
                              Mở tra cứu đối tác
                            </a>
                          ) : null}
                        </div>
                      );
                    })}
                  </div>
                ) : (
                  <div className={`order-track-placeholder ${err ? 'order-track-placeholder--dim' : ''}`}>
                    <p className="order-track-placeholder-text">
                      {err
                        ? 'Chưa có dữ liệu hiển thị. Kiểm tra thông báo bên trái.'
                        : 'Nhập mã đơn và số điện thoại, sau đó bấm Tra cứu để xem trạng thái giao hàng.'}
                    </p>
                  </div>
                )}
              </div>
            </div>
          </div>

          <p className="order-track-footnote">
            Đã đăng nhập? <Link to="/orders">Xem đơn trong tài khoản</Link> để xem đầy đủ chi tiết.
          </p>
        </div>
      </div>
    </div>
  );
}
