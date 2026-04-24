import { useEffect, useMemo, useRef, useState } from 'react';
import { Link, useNavigate, useParams, useLocation } from 'react-router-dom';
import { useAuth } from '../../../context/AuthContext';
import { apiService, resolveMediaUrl } from '../../../services/api';
import { partnerTrackingUrl } from '../../../utils/shipmentTracking';
import type { Order, Payment } from '../../../types';
import type { ShippingMethod } from '../../../types';
import type { ReturnRequest } from '../../../types';

export const OrderDetailPage = () => {
  const { id } = useParams();
  const idOrToken = String(id || '').trim();
  const numericId = Number(idOrToken);
  const hasNumericId = Number.isFinite(numericId) && numericId > 0 && String(Math.trunc(numericId)) === idOrToken;
  const nav = useNavigate();
  const location = useLocation();
  const { user, isAuthenticated } = useAuth();

  const [order, setOrder] = useState<Order | null>(null);
  const [loading, setLoading] = useState(true);
  const [confirmingPaid, setConfirmingPaid] = useState(false);
  const [confirmingReceived, setConfirmingReceived] = useState(false);
  const [cancellingOrder, setCancellingOrder] = useState(false);
  const [payMsg, setPayMsg] = useState<string | null>(null);
  const [returnReq, setReturnReq] = useState<ReturnRequest | null>(null);
  const [shippingMethods, setShippingMethods] = useState<ShippingMethod[]>([]);
  const [returnOpen, setReturnOpen] = useState(false);
  const [returnReason, setReturnReason] = useState('');
  const [returnFiles, setReturnFiles] = useState<File[]>([]);
  const [returnPreviews, setReturnPreviews] = useState<string[]>([]);
  const [returnVideo, setReturnVideo] = useState<File | null>(null);
  const [returnVideoUrl, setReturnVideoUrl] = useState<string | null>(null);
  const [creatingReturn, setCreatingReturn] = useState(false);
  const [returnChosen, setReturnChosen] = useState(false);
  const [receivedChosen, setReceivedChosen] = useState(false);
  const [refundProofHalfW, setRefundProofHalfW] = useState<number | null>(null);
  const [rrGalleryOpen, setRrGalleryOpen] = useState(false);
  const [rrGalleryIndex, setRrGalleryIndex] = useState(0);

  const returnFilesInputRef = useRef<HTMLInputElement | null>(null);
  const returnVideoInputRef = useRef<HTMLInputElement | null>(null);

  useEffect(() => {
    if (!isAuthenticated || !user) return;
    if (!idOrToken) return;

    const load = async () => {
      setLoading(true);
      try {
        const data = hasNumericId ? await apiService.getOrder(numericId) : await apiService.getOrderByToken(idOrToken);
        // Basic guard: don't show other user's order
        if (data && data.userID !== user.userID) {
          setOrder(null);
          return;
        }
        setOrder(data);
        // load return request (if any)
        try {
          const rr = data ? await apiService.getOrderReturnRequest(data.orderID, user.userID) : null;
          setReturnReq(rr);
        } catch {
          setReturnReq(null);
        }
      } finally {
        setLoading(false);
      }
    };
    load();
  }, [isAuthenticated, user?.userID, idOrToken, hasNumericId, numericId]);

  useEffect(() => {
    // Shipping methods for correct shipping fee (avoid hardcoded 30k).
    apiService.getShippingMethods().then((xs) => setShippingMethods(xs || [])).catch(() => setShippingMethods([]));
  }, []);

  useEffect(() => {
    // previews for return images
    returnPreviews.forEach((u) => URL.revokeObjectURL(u));
    const next = (returnFiles || []).map((f) => URL.createObjectURL(f));
    setReturnPreviews(next);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [returnFiles]);

  useEffect(() => {
    if (returnVideoUrl) URL.revokeObjectURL(returnVideoUrl);
    if (!returnVideo) {
      setReturnVideoUrl(null);
      return;
    }
    setReturnVideoUrl(URL.createObjectURL(returnVideo));
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [returnVideo]);

  useEffect(() => {
    setRefundProofHalfW(null);
  }, [returnReq?.refundProofUrl]);

  useEffect(() => {
    if (!rrGalleryOpen) return;
    const onKeyDown = (e: KeyboardEvent) => {
      if (e.key === 'Escape') setRrGalleryOpen(false);
      if (e.key === 'ArrowLeft') setRrGalleryIndex((i) => Math.max(0, i - 1));
      if (e.key === 'ArrowRight') {
        const max = Math.max(0, (returnReq?.images?.length || 0) - 1);
        setRrGalleryIndex((i) => Math.min(max, i + 1));
      }
    };
    window.addEventListener('keydown', onKeyDown);
    return () => window.removeEventListener('keydown', onKeyDown);
  }, [rrGalleryOpen, returnReq?.images?.length]);

  const formatPrice = (price: number) =>
    new Intl.NumberFormat('vi-VN', { style: 'currency', currency: 'VND' }).format(price);

  const formatDate = (iso: string) => {
    const d = new Date(iso);
    if (Number.isNaN(d.getTime())) return iso;
    return d.toLocaleDateString('vi-VN', { year: 'numeric', month: '2-digit', day: '2-digit' });
  };

  const formatDateTime = (iso?: string | null) => {
    if (!iso) return '';
    const d = new Date(iso);
    if (Number.isNaN(d.getTime())) return '';
    return d.toLocaleString('vi-VN', { day: '2-digit', month: '2-digit', hour: '2-digit', minute: '2-digit' });
  };

  const statusUi = (status: string) => {
    const s = (status || '').trim().toLowerCase();
    if (s === 'returnpending') return { label: 'Chờ duyệt hoàn hàng', cls: 'processing' };
    if (s === 'refundpending') return { label: 'Chờ hoàn tiền', cls: 'processing' };
    if (s === 'returned') return { label: 'Hoàn hàng', cls: 'processing' };
    if (s === 'refunded') return { label: 'Đã hoàn tiền', cls: 'refunded' };
    if (s === 'delivered') return { label: 'Đã giao', cls: 'delivered' };
    if (s === 'shipped' || s === 'intransit' || s === 'in_transit' || s === 'shipping') return { label: 'Đang giao', cls: 'intransit' };
    if (s === 'processing') return { label: 'Đang xử lý', cls: 'processing' };
    if (s === 'pending') return { label: 'Đã đặt hàng', cls: 'processing' };
    if (s === 'cancelled' || s === 'canceled') return { label: 'Đã hủy', cls: 'failed' };
    if (s === 'failed') return { label: 'Thất bại', cls: 'failed' };
    return { label: status || 'Đang xử lý', cls: 'processing' };
  };

  const returnStatusLabel = (status: string) => {
    const s = (status || '').trim().toLowerCase();
    if (s === 'pending') return 'Chờ duyệt';
    if (s === 'approved' || s === 'accept' || s === 'accepted') return 'Đã chấp nhận';
    if (s === 'rejected' || s === 'reject' || s === 'declined' || s === 'denied') return 'Đã từ chối';
    return status || '—';
  };

  const progress = useMemo(() => {
    const s = (order?.status || '').trim().toLowerCase();
    const primaryShipment = (order?.shipments || [])[0] || null;
    const shipStatus = (primaryShipment?.status || '').trim().toLowerCase();
    const hasShippedDate = !!primaryShipment?.shippedDate;
    const hasDeliveredDate = !!primaryShipment?.actualDeliveryDate;

    const isCancelled = s === 'cancelled' || s === 'canceled' || s === 'failed';
    const delivered =
      hasDeliveredDate ||
      shipStatus === 'delivered' ||
      s === 'delivered' ||
      s === 'completed';

    const shipped =
      hasShippedDate ||
      shipStatus === 'intransit' ||
      shipStatus === 'in_transit' ||
      shipStatus === 'shipping' ||
      s === 'shipped' ||
      s === 'intransit' ||
      s === 'in_transit' ||
      s === 'shipping';

    // Treat "paid" as a PAYMENT state, not a shipping pipeline step.
    const processing = s === 'processing';
    const preparing = s === 'preparing' || s === 'preparing_goods' || s === 'packing';
    const pending = s === 'pending' || !s;

    let step = 0;
    if (pending) step = 0;
    if (processing) step = 1;
    if (preparing) step = 2;
    if (shipped) step = 3;
    if (delivered) step = 4;
    if (s === 'completed') step = 5;

    if (returnChosen || !!returnReq) step = 5;
    return { step, isCancelled, delivered };
  }, [order?.status, order?.shipments, returnChosen, returnReq]);

  const stepItems = useMemo(() => {
    const placedAt = order?.orderDate || null;
    const primaryShipment = (order?.shipments || [])[0] || null;
    const shippedAt = primaryShipment?.shippedDate || null;
    const deliveredAt = primaryShipment?.actualDeliveryDate || null;

    return [
      { t: 'Đã đặt hàng', time: formatDateTime(placedAt) },
      { t: 'Đã xác nhận', time: progress.step >= 1 ? formatDateTime(placedAt) : '' },
      { t: 'Đang chuẩn bị hàng', time: progress.step >= 2 ? formatDateTime(placedAt) : '' },
      { t: 'Đang giao hàng', time: progress.step >= 3 ? formatDateTime(shippedAt) : '' },
      { t: 'Đã giao hàng', time: progress.step >= 4 ? formatDateTime(deliveredAt) : '' },
      { t: (returnChosen || !!returnReq) ? 'Hoàn hàng' : 'Hoàn thành', time: progress.step >= 5 ? formatDateTime(deliveredAt) : '' },
    ];
  }, [order?.orderDate, order?.shipments, progress.step, returnChosen, returnReq]);

  const paymentUi = (p?: Payment | null) => {
    const method = (p?.paymentMethod || '').toUpperCase();
    const status = (p?.status || '').trim().toLowerCase();
    const methodLabel = method === 'VNPAY' ? 'VNPay' : method === 'COD' ? 'Thanh toán khi nhận hàng' : (p?.paymentMethod || '—');
    const statusLabel = status === 'paid' || status === 'success' ? 'Thành công' : status === 'pending' ? 'Chờ thanh toán' : (p?.status || '—');
    return { methodLabel, statusLabel };
  };

  const subtotal = useMemo(() => {
    if (!order) return 0;
    return (order.orderDetails || []).reduce((sum, d) => sum + (d.unitPrice || 0) * (d.quantity || 0), 0);
  }, [order]);

  const shipping = useMemo(() => {
    if (subtotal >= 200000) return 0;
    const mid = (order as any)?.shippingMethodID as number | null | undefined;
    const picked = mid ? (shippingMethods || []).find((m) => m.methodID === mid) : null;
    const fallback = (shippingMethods || []).slice().sort((a, b) => (a.baseCost || 0) - (b.baseCost || 0))[0] || null;
    const base = (picked?.baseCost ?? fallback?.baseCost ?? 30000) || 30000;
    return base;
  }, [subtotal, order, shippingMethods]);
  const estimatedTax = useMemo(() => Math.round(subtotal * 0.015), [subtotal]);
  const grandTotal = useMemo(() => subtotal + shipping + estimatedTax, [subtotal, shipping, estimatedTax]);

  const code = order?.orderCode || (order ? `#${order.orderID}` : '');
  const st = statusUi(order?.status || '');
  const payment = order?.payments?.[0] || null;
  const pui = paymentUi(payment);
  const payOk = ['paid', 'success'].includes((payment?.status || '').trim().toLowerCase());
  const isCod = ((payment?.paymentMethod || '').toUpperCase() === 'COD') || pui.methodLabel === 'Thanh toán khi nhận hàng';
  const isPending = ['pending', ''].includes((payment?.status || '').trim().toLowerCase());
  const orderStLower = (order?.status || '').trim().toLowerCase();
  const isOrderCancelled = orderStLower === 'cancelled' || orderStLower === 'canceled' || orderStLower === 'failed';
  const canConfirmPaid = !!order && !isOrderCancelled && isCod && isPending;
  const isDelivered = useMemo(() => {
    if (!order) return false;
    const s = (order.status || '').trim().toLowerCase();
    if (s === 'delivered') return true;
    // Some older records / flows mark delivery via shipment fields or jump to "completed".
    if (s === 'completed') return true;
    const shipped = (order.shipments || [])[0] ?? null;
    const ss = (shipped?.status || '').trim().toLowerCase();
    if (ss === 'delivered') return true;
    if (!!shipped?.actualDeliveryDate) return true;
    return false;
  }, [order]);
  const canConfirmReceived = isDelivered && orderStLower !== 'completed';
  const canRequestReturn = isDelivered && !returnReq;
  const canCancelOrder = useMemo(() => {
    if (!order) return false;
    if (returnChosen || !!returnReq) return false;
    const s = (order.status || '').trim().toLowerCase();
    if (s === 'cancelled' || s === 'canceled' || s === 'failed') return false;
    if (s === 'shipping' || s === 'intransit' || s === 'in_transit' || s === 'delivered' || s === 'completed') return false;
    if (s === 'returned' || s === 'refunded' || s === 'returnpending' || s === 'refundpending') return false;
    const shippedByShipment =
      (order.shipments || []).some((sh) => {
        const ss = (sh?.status || '').trim().toLowerCase();
        return ss === 'shipping' || ss === 'intransit' || ss === 'in_transit' || ss === 'delivered' || !!sh?.shippedDate || !!sh?.actualDeliveryDate;
      });
    if (shippedByShipment) return false;
    return s === 'pending' || s === 'processing' || s === 'preparing' || s === 'preparing_goods' || s === 'packing' || !s;
  }, [order, returnChosen, returnReq]);

  useEffect(() => {
    if (!order || !canConfirmReceived) return;
    if (location.hash !== '#xac-nhan-nhan-hang') return;
    const el = document.getElementById('xac-nhan-nhan-hang');
    if (!el) return;
    const t = window.setTimeout(() => {
      el.scrollIntoView({ behavior: 'smooth', block: 'center' });
    }, 200);
    return () => window.clearTimeout(t);
  }, [order, canConfirmReceived, location.hash]);

  const primaryShipment = useMemo(() => (order?.shipments || [])[0] ?? null, [order?.shipments]);
  const partnerTrackUrl = useMemo(
    () => partnerTrackingUrl(primaryShipment?.carrier, primaryShipment?.trackingNumber),
    [primaryShipment?.carrier, primaryShipment?.trackingNumber],
  );
  const returnMode = returnChosen || !!returnReq;
  const receiveMode = receivedChosen || ((order?.status || '').trim().toLowerCase() === 'completed');
  const returnPending =
    returnMode &&
    !!returnReq &&
    !['approved', 'accept', 'accepted'].includes((returnReq.status || '').trim().toLowerCase()) &&
    !['rejected', 'reject', 'declined', 'denied'].includes((returnReq.status || '').trim().toLowerCase());

  if (!isAuthenticated || !user) {
    return (
      <div className="empty-state" style={{ padding: '5rem 2rem', textAlign: 'center' }}>
        <h2>Bạn chưa đăng nhập</h2>
        <p>Vui lòng đăng nhập để xem chi tiết đơn hàng.</p>
        <Link to="/login" className="btn-primary" style={{ display: 'inline-block', marginTop: '1.5rem', textDecoration: 'none' }}>
          Đăng nhập
        </Link>
      </div>
    );
  }

  return (
    <div className="order-detail-page">
      <div className="container">
        <div className="order-detail-breadcrumb">
          <span className="muted">Tài khoản</span>
          <span className="sep">›</span>
          <Link to="/orders" className="link">
            Đơn hàng của tôi
          </Link>
          <span className="sep">›</span>
          <span className="muted">Đơn {code}</span>
        </div>

        {loading ? (
          <div style={{ padding: '3rem', textAlign: 'center' }}>Đang tải chi tiết đơn hàng...</div>
        ) : !order ? (
          <div className="feature-card" style={{ justifyContent: 'center' }}>
            <div style={{ textAlign: 'center' }}>
              <h3 style={{ marginBottom: '0.25rem' }}>Không tìm thấy đơn hàng</h3>
              <p style={{ color: '#777' }}>Đơn hàng không tồn tại hoặc bạn không có quyền xem.</p>
              <button type="button" className="btn-primary" style={{ marginTop: '1rem' }} onClick={() => nav('/orders')}>
                Quay lại
              </button>
            </div>
          </div>
        ) : (
          <>
            <div className="order-detail-header">
              <div>
                <h1>Chi tiết đơn hàng:  {code}</h1>
                <div className="order-detail-meta">
                  <span className={`order-status-pill ${st.cls}`}>{st.label}</span>
                  {payOk && (
                    <>
                      <span className="dot">•</span>
                      <span className="muted">Đã thanh toán</span>
                    </>
                  )}
                  <span className="dot">•</span>
                  <span className="muted">Đặt lúc {formatDate(order.orderDate)}</span>
                </div>
              </div>

              {/* <div className="order-detail-actions">
                <button type="button" className="btn-secondary" disabled title="Chưa hỗ trợ xuất hóa đơn tự động">
                  Tải hóa đơn
                </button>
                <Link to="/products" className="btn-primary" style={{ textDecoration: 'none' }}>
                  Mua lại
                </Link>
              </div> */}
            </div>

            <div className="order-card order-progress">
              <div className="order-card-title">Tiến trình đơn hàng</div>
              {progress.isCancelled ? (
                <div className="order-progress-cancel">Đơn hàng đã bị hủy / thất bại.</div>
              ) : (
                <ol className="order-steps-v2" aria-label="Tiến trình xử lý đơn hàng">
                  {stepItems.map((x, idx) => {
                    const done = idx < progress.step;
                    const active = idx === progress.step;
                    const isReturnStep = idx === stepItems.length - 1 && returnMode;
                    const pendingReturnStep = isReturnStep && returnPending;
                    return (
                      <li key={x.t} className={`order-step-v2 ${done ? 'done' : ''} ${active ? 'active' : ''} ${pendingReturnStep ? 'pending' : ''}`}>
                        <div className="order-step-v2-icon" aria-hidden>
                          {pendingReturnStep ? (
                            <svg width="18" height="18" viewBox="0 0 24 24" fill="none">
                              <path
                                d="M12 2a10 10 0 1 0 10 10A10 10 0 0 0 12 2Zm0 18a8 8 0 1 1 8-8a8 8 0 0 1-8 8Z"
                                fill="currentColor"
                              />
                              <path d="M12.75 7h-1.5v6l5 3 .75-1.23-4.25-2.52Z" fill="currentColor" />
                            </svg>
                          ) : (
                            '✓'
                          )}
                        </div>
                        <div className="order-step-v2-title">{x.t}</div>
                        {/* <div className="order-step-v2-time">{x.time || ''}</div> */}
                      </li>
                    );
                  })}
                </ol>
              )}
            </div>

            <div className="order-detail-layout">
              <div className="order-detail-left">
                <div className="order-card">
                  <div className="order-card-title">Danh sách sản phẩm ({order.orderDetails?.length || 0})</div>
                  <div className="order-items">
                    {(order.orderDetails || []).map((d) => {
                      const p = d.product;
                      const img = resolveMediaUrl(
                        p?.productImages?.find((x) => x.isMainImage)?.imageURL ||
                        p?.productImages?.[0]?.imageURL ||
                        ''
                      );
                      const lineTotal = (d.unitPrice || 0) * (d.quantity || 0);
                      const sku = (p as any)?.sku || (p as any)?.Sku || (p as any)?.SKU || null;
                      return (
                        <div key={d.orderDetailID} className="order-item-row">
                          <div className="order-item-thumb">
                            {img ? <img src={img} alt={p?.productName || 'Sản phẩm'} /> : <div className="order-item-thumb-fallback" />}
                          </div>
                          <div className="order-item-main">
                            <div className="order-item-name">{p?.productName || `Sản phẩm #${d.productID}`}</div>
                            {/* {sku ? <div className="order-item-sku muted">Mã sản phẩm: {String(sku)}</div> : null} */}
                            <div className="order-item-sub muted">
                              {p?.unit ? `Đơn vị: ${p.unit}` : ''}
                            </div>
                            {/* <div className="order-item-sub muted">Đơn giá: {formatPrice(d.unitPrice)}</div> */}
                          </div>
                          <div className="order-item-priceBox">
                            <div className="order-item-priceLine muted">
                              {formatPrice(d.unitPrice)} × {d.quantity}
                            </div>
                            <div className="order-item-price">{formatPrice(lineTotal)}</div>
                          </div>
                        </div>
                      );
                    })}
                  </div>
                </div>

                <div className="order-info-grid">
                  <div className="order-card">
                    <div className="order-card-title">Thông tin vận chuyển</div>
                    <div className="order-info-row">
                      <div className="order-info-label">Người nhận</div>
                      <div className="order-info-val">{user.fullName}</div>
                    </div>
                    <div className="order-info-row">
                      <div className="order-info-label">Địa chỉ giao hàng</div>
                      <div className="order-info-val">{order.shippingAddress}</div>
                    </div>
                    {primaryShipment && (primaryShipment.carrier?.trim() || primaryShipment.trackingNumber?.trim()) ? (
                      <>
                        <div className="order-info-row">
                          <div className="order-info-label">Đối tác vận chuyển</div>
                          <div className="order-info-val">{primaryShipment.carrier?.trim() || '—'}</div>
                        </div>
                        <div className="order-info-row">
                          <div className="order-info-label">Mã vận đơn</div>
                          <div className="order-info-val" style={{ fontFamily: 'ui-monospace, monospace' }}>
                            {primaryShipment.trackingNumber?.trim() || '—'}
                          </div>
                        </div>
                        {partnerTrackUrl ? (
                          <div style={{ marginTop: '0.75rem' }}>
                            <a href={partnerTrackUrl} target="_blank" rel="noreferrer" className="btn-secondary" style={{ textDecoration: 'none' }}>
                              Tra cứu trên đối tác
                            </a>
                          </div>
                        ) : null}
                      </>
                    ) : null}
                  </div>

                  <div className="order-card">
                    <div className="order-card-title">Thông tin thanh toán</div>
                    {payMsg && <div className="profile-msg" style={{ marginBottom: '0.8rem' }}>{payMsg}</div>}
                    <div className="order-info-row">
                      <div className="order-info-label">Phương thức</div>
                      <div className="order-info-val">{pui.methodLabel}</div>
                    </div>
                    <div className="order-info-row">
                      <div className="order-info-label">Trạng thái</div>
                      <div className="order-info-val">{pui.statusLabel}</div>
                    </div>
                    {canConfirmPaid && (
                      <button
                        type="button"
                        className="btn-primary profile-save"
                        style={{ marginTop: '0.9rem' }}
                        disabled={confirmingPaid}
                        onClick={async () => {
                          if (!order) return;
                          setPayMsg(null);
                          setConfirmingPaid(true);
                          try {
                            const updated = await apiService.confirmCodPaid(order.orderID);
                            if (updated) {
                              setOrder(updated);
                              setPayMsg('Đã xác nhận thanh toán.');
                            } else {
                              setPayMsg('Xác nhận thất bại.');
                            }
                          } catch (e) {
                            setPayMsg(e instanceof Error ? e.message : 'Xác nhận thất bại.');
                          } finally {
                            setConfirmingPaid(false);
                          }
                        }}
                      >
                        {confirmingPaid ? 'Đang xác nhận...' : 'Xác nhận đã thanh toán'}
                      </button>
                    )}
                  </div>
                </div>
              </div>

              <aside className="order-detail-right">
                <div className="order-right-sticky">
                  <div className="order-card">
                    <div className="order-card-title">Tóm tắt chi phí</div>
                    <div className="order-sum">
                      <div className="order-sum-line">
                        <span className="muted">Tạm tính</span>
                        <span>{formatPrice(subtotal)}</span>
                      </div>
                      <div className="order-sum-line">
                        <span className="muted">Phí vận chuyển</span>
                        <span className={shipping === 0 ? 'green' : ''}>{shipping === 0 ? 'Miễn phí' : formatPrice(shipping)}</span>
                      </div>
                      <div className="order-sum-line">
                        <span className="muted">Thuế (1,5%)</span>
                        <span>{formatPrice(estimatedTax)}</span>
                      </div>
                      <div className="order-sum-divider" />
                      <div className="order-sum-total">
                        <span>Tổng cộng</span>
                        <span className="green">{formatPrice(order.totalAmount || grandTotal)}</span>
                      </div>
                    </div>
                  </div>

                  {canCancelOrder && (
                    <button
                      type="button"
                      className="btn-danger"
                      style={{ width: '100%', marginTop: '0.85rem' }}
                      disabled={cancellingOrder}
                      onClick={async () => {
                        if (!order || !user) return;
                        const ok = window.confirm('Bạn chắc chắn muốn hủy đơn hàng này?');
                        if (!ok) return;
                        setPayMsg(null);
                        setCancellingOrder(true);
                        try {
                          const updated = await apiService.cancelOrder(order.orderID, user.userID);
                          if (updated) {
                            setOrder(updated);
                            setPayMsg('Đã hủy đơn hàng.');
                          }
                        } catch (e) {
                          setPayMsg(e instanceof Error ? e.message : 'Hủy đơn thất bại.');
                        } finally {
                          setCancellingOrder(false);
                        }
                      }}
                    >
                      {cancellingOrder ? 'Đang hủy...' : 'Hủy đơn'}
                    </button>
                  )}

                  {(canConfirmReceived || canRequestReturn) && (
                    <div className="order-receive-actions" id="xac-nhan-nhan-hang">
                      {canConfirmReceived && !returnMode && (
                        <button
                          type="button"
                          className="order-btn-receive"
                          disabled={confirmingReceived}
                          onClick={async () => {
                            if (!order || !user) return;
                            setPayMsg(null);
                            setReceivedChosen(true);
                            setConfirmingReceived(true);
                            try {
                              const updated = await apiService.confirmOrderReceived(order.orderID, user.userID);
                              if (updated) {
                                setOrder(updated);
                                setPayMsg('Đã xác nhận nhận hàng. Cảm ơn bạn!');
                              } else {
                                setPayMsg('Xác nhận nhận hàng thất bại.');
                                setReceivedChosen(false);
                              }
                            } catch (e) {
                              setPayMsg(e instanceof Error ? e.message : 'Xác nhận nhận hàng thất bại.');
                              setReceivedChosen(false);
                            } finally {
                              setConfirmingReceived(false);
                            }
                          }}
                        >
                          {confirmingReceived ? 'Đang xử lý...' : 'Nhận hàng'}
                        </button>
                      )}

                      {canRequestReturn && !receiveMode && (
                        <button
                          type="button"
                          className="order-btn-return"
                          onClick={() => {
                            setReturnOpen(true);
                            setReturnChosen(true);
                            setReturnReason('');
                            setReturnFiles([]);
                            setReturnVideo(null);
                            setPayMsg(null);
                          }}
                        >
                          Hoàn hàng
                        </button>
                      )}
                    </div>
                  )}
                </div>
              </aside>
            </div>

            {returnReq && (
              <div className="order-return-wide">
                <div className="order-card">
                  <div className="order-card-title">{(returnReq.requestType || 'Return') === 'CancelRefund' ? 'Yêu cầu hoàn tiền (hủy đơn)' : 'Yêu cầu hoàn hàng'}</div>
                  <div style={{ fontWeight: 900 }}>
                    Trạng thái: <span className="muted">{returnStatusLabel(returnReq.status)}</span>
                  </div>

                  <div className="order-rr-layout">
                    <div className="order-rr-left">
                      <div className="rr-badges" style={{ marginTop: 10 }}>
                        <span className="rr-pill rr-pill--user">Bạn gửi</span>
                        <span className="rr-pill rr-pill--status">{returnStatusLabel(returnReq.status)}</span>
                      </div>
                      <div className="muted" style={{ fontWeight: 950, marginBottom: 6, marginTop: 10 }}>Nội dung yêu cầu</div>
                      <div className="rr-reason muted" style={{ fontWeight: 600 }}>
                        {returnReq.reason}
                      </div>
                    </div>

                    <div className="order-rr-right">
                      {returnReq.videoUrl ? (
                        <div className="order-rr-videoBlock">
                          <div className="muted" style={{ fontWeight: 900, marginBottom: 6 }}>Video</div>
                          <div className="order-rr-videoFrame">
                            <video
                              src={resolveMediaUrl(returnReq.videoUrl)}
                              controls
                              style={{ width: '100%', height: '100%', objectFit: 'contain', display: 'block' }}
                            />
                          </div>
                        </div>
                      ) : null}

                      {!!returnReq.images?.length && (
                        <div className="order-rr-imagesBlock">
                          <div className="order-rr-imagesHead">
                            <div className="muted" style={{ fontWeight: 900 }}>Ảnh</div>
                            {returnReq.images.length > 3 ? (
                              <button
                                type="button"
                                className="order-rr-moreBtn"
                                onClick={() => {
                                  setRrGalleryIndex(0);
                                  setRrGalleryOpen(true);
                                }}
                              >
                                Xem tất cả ({returnReq.images.length})
                              </button>
                            ) : null}
                          </div>

                          <div className="order-rr-thumbs">
                            {returnReq.images.slice(0, 3).map((img, idx) => (
                              <button
                                key={img.returnRequestImageID}
                                type="button"
                                className="order-rr-thumb"
                                onClick={() => {
                                  setRrGalleryIndex(idx);
                                  setRrGalleryOpen(true);
                                }}
                                aria-label="Xem ảnh"
                                title="Xem ảnh"
                              >
                                <img src={resolveMediaUrl(img.imageUrl)} alt="return" />
                              </button>
                            ))}
                          </div>
                        </div>
                      )}
                    </div>
                  </div>
                </div>
              </div>
            )}

            {rrGalleryOpen && (returnReq?.images?.length || 0) > 0 ? (
              <div className="rrg-modal" role="dialog" aria-modal="true">
                <div className="rrg-backdrop" onClick={() => setRrGalleryOpen(false)} />
                <div className="rrg-panel">
                  <div className="rrg-top">
                    <div className="rrg-title">Ảnh hoàn hàng</div>
                    <button type="button" className="rrg-close" onClick={() => setRrGalleryOpen(false)} aria-label="Đóng">
                      ×
                    </button>
                  </div>

                  {(() => {
                    const imgs = returnReq?.images ?? [];
                    const max = Math.max(0, imgs.length - 1);
                    const idx = Math.max(0, Math.min(max, rrGalleryIndex));
                    const active = imgs[idx];
                    if (!active) return null;
                    return (
                      <>
                        <div className="rrg-body">
                    <button
                      type="button"
                      className="rrg-nav rrg-prev"
                      disabled={idx <= 0}
                      onClick={() => setRrGalleryIndex((i) => Math.max(0, i - 1))}
                      aria-label="Ảnh trước"
                    >
                      ‹
                    </button>

                    <a
                      className="rrg-imageFrame"
                      href={resolveMediaUrl(active.imageUrl)}
                      target="_blank"
                      rel="noreferrer"
                      title="Mở ảnh gốc"
                    >
                      <img
                        src={resolveMediaUrl(active.imageUrl)}
                        alt={`return-${rrGalleryIndex + 1}`}
                      />
                    </a>

                    <button
                      type="button"
                      className="rrg-nav rrg-next"
                      disabled={idx >= imgs.length - 1}
                      onClick={() => setRrGalleryIndex((i) => Math.min(imgs.length - 1, i + 1))}
                      aria-label="Ảnh sau"
                    >
                      ›
                    </button>
                  </div>

                  <div className="rrg-foot muted">
                    {idx + 1}/{imgs.length} · Dùng phím ← → để chuyển, ESC để đóng
                  </div>
                      </>
                    );
                  })()}
                </div>
              </div>
            ) : null}

            {returnReq?.adminNote?.trim() ? (
              <div className="order-admin-reply-wide">
                <div className="order-card order-card--admin-reply">
                  <div className="order-card-title">Phản hồi từ shop</div>
                  <div className="rr-badges" style={{ marginTop: 10 }}>
                    <span className="rr-pill rr-pill--admin">Shop phản hồi</span>
                  </div>
                  <p className="muted" style={{ margin: '0 0 10px', fontWeight: 700, fontSize: '0.92rem', lineHeight: 1.45 }}>
                    Shop đã xử lý yêu cầu hoàn hàng của bạn (duyệt hoặc từ chối). Nội dung bên dưới là ghi chú từ phía cửa hàng.
                  </p>
                  <div className="rr-reason rr-admin-reply" style={{ fontWeight: 600, lineHeight: 1.5, color: '#111827' }}>
                    {returnReq.adminNote.trim()}
                  </div>
                </div>
              </div>
            ) : null}

            {returnReq?.refundProofUrl ? (
              <div className="order-refund-proof-wide">
                <div className="order-card order-card--refund-proof">
                  <div className="order-card-title">Chứng từ đã hoàn tiền</div>
                  <div className="order-refund-proof-layout">
                    <div className="order-refund-proof-text">
                      {returnReq.refundNote?.trim() ? (
                        <div className="rr-reason" style={{ margin: '0 0 14px', fontWeight: 600, lineHeight: 1.5, color: '#111827' }}>
                          {returnReq.refundNote.trim()}
                        </div>
                      ) : (
                        <p className="muted" style={{ margin: '0 0 14px', fontWeight: 700, lineHeight: 1.45 }}>
                          Shop đã đính kèm ảnh chuyển khoản. Bạn có thể xem thêm ý kiến xử lý yêu cầu ở mục <strong>Phản hồi từ shop</strong> (nếu đã có).
                        </p>
                      )}
                      <p className="muted order-refund-proof-hint">
                        Bấm vào khung ảnh bên phải để xem chứng từ gốc (kích thước đầy đủ).
                      </p>
                    </div>
                    <div className="order-refund-proof-aside">
                      <a
                        className="order-refund-proof-frame"
                        href={resolveMediaUrl(returnReq.refundProofUrl)}
                        target="_blank"
                        rel="noreferrer"
                        title="Mở ảnh chứng từ đầy đủ"
                      >
                        <img
                          src={resolveMediaUrl(returnReq.refundProofUrl)}
                          alt="Chứng từ hoàn tiền"
                          className="order-refund-proof-img"
                          onLoad={(e) => {
                            const nw = e.currentTarget.naturalWidth;
                            if (nw > 0) setRefundProofHalfW(Math.round(nw / 2));
                          }}
                          style={{
                            width: refundProofHalfW != null ? `${refundProofHalfW}px` : undefined,
                            maxWidth: '100%',
                            height: 'auto',
                          }}
                        />
                      </a>
                    </div>
                  </div>
                </div>
              </div>
            ) : null}
          </>
        )}
      </div>

      {returnOpen && (
        <div className="rr-modal" role="dialog" aria-modal="true">
          <div
            className="rr-backdrop"
            onClick={() => {
              if (creatingReturn) return;
              setReturnOpen(false);
              if (!returnReq) setReturnChosen(false);
            }}
          />
          <div className="rr-panel">
            <div className="rr-title">Yêu cầu hoàn hàng</div>
            <div className="muted" style={{ marginTop: 6 }}>Mô tả vấn đề và tải ảnh sản phẩm lỗi để admin xác nhận.</div>

            <textarea
              value={returnReason}
              onChange={(e) => setReturnReason(e.target.value)}
              placeholder="Nội dung chi tiết (ví dụ: sản phẩm bị dập, thiếu hàng...)"
              className="rr-textarea"
              rows={4}
              disabled={creatingReturn}
            />

            <div className="rr-upload">
              <input
                className="rr-file"
                type="file"
                accept="image/*"
                multiple
                ref={returnFilesInputRef}
                disabled={creatingReturn}
                onChange={(e) => {
                  const fs = Array.from(e.target.files || []);
                  setReturnFiles(fs.slice(0, 6));
                }}
              />
              <button
                type="button"
                className="rr-pick"
                disabled={creatingReturn}
                onClick={() => returnFilesInputRef.current?.click()}
              >
                Chọn ảnh (tối đa 6)
              </button>
              <div className="rr-hint muted">
                {returnFiles.length ? `Đã chọn ${returnFiles.length} ảnh` : 'Chưa chọn ảnh'}
              </div>
            </div>

            <div className="rr-upload" style={{ marginTop: 8 }}>
              <input
                className="rr-file"
                type="file"
                accept="video/*"
                ref={returnVideoInputRef}
                disabled={creatingReturn}
                onChange={(e) => {
                  const f = (e.target.files || [])[0] || null;
                  setReturnVideo(f);
                }}
              />
              <button
                type="button"
                className="rr-pick"
                disabled={creatingReturn}
                onClick={() => returnVideoInputRef.current?.click()}
              >
                Chọn video (tùy chọn)
              </button>
              <div className="rr-hint muted">
                {returnVideo ? `Đã chọn: ${returnVideo.name}` : 'Chưa chọn video'}
              </div>
            </div>

            {returnVideoUrl && (
              <div className="rr-video" style={{ marginTop: 10 }}>
                <video src={returnVideoUrl} controls style={{ width: '100%', borderRadius: 14, border: '1px solid rgba(0,0,0,0.08)' }} />
                <button
                  type="button"
                  className="rr-video-x"
                  disabled={creatingReturn}
                  onClick={() => setReturnVideo(null)}
                  aria-label="Xóa video"
                  title="Xóa video"
                >
                  ×
                </button>
              </div>
            )}

            {returnPreviews.length > 0 && (
              <div className="rr-grid">
                {returnPreviews.map((src, idx) => (
                  <div key={src} className="rr-thumb">
                    <img src={src} alt={`return-${idx}`} />
                    <button
                      type="button"
                      className="rr-x"
                      disabled={creatingReturn}
                      onClick={() => setReturnFiles((arr) => arr.filter((_, i) => i !== idx))}
                      aria-label="Xóa ảnh"
                    >
                      ×
                    </button>
                  </div>
                ))}
              </div>
            )}

            <div className="rr-actions">
              <button
                type="button"
                className="btn-secondary"
                disabled={creatingReturn}
                onClick={() => {
                  setReturnOpen(false);
                  if (!returnReq) setReturnChosen(false);
                }}
              >
                Hủy
              </button>
              <button
                type="button"
                className="btn-primary"
                disabled={creatingReturn || returnReason.trim().length < 10}
                onClick={async () => {
                  if (!order || !user) return;
                  setCreatingReturn(true);
                  try {
                    await apiService.createOrderReturnRequest(order.orderID, user.userID, returnReason.trim(), returnFiles, returnVideo);
                    const rr = await apiService.getOrderReturnRequest(order.orderID, user.userID);
                    setReturnReq(rr);
                    setReturnOpen(false);
                    setPayMsg('Đã gửi yêu cầu hoàn hàng. Admin sẽ xác nhận sớm.');
                  } catch (e) {
                    setPayMsg(e instanceof Error ? e.message : 'Tạo yêu cầu hoàn hàng thất bại.');
                    if (!returnReq) setReturnChosen(false);
                  } finally {
                    setCreatingReturn(false);
                  }
                }}
              >
                {creatingReturn ? 'Đang gửi...' : 'Gửi yêu cầu'}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};

