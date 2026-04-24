import { useCallback, useEffect, useMemo, useState } from 'react';
import type { AdminShipmentRow } from '../../types';
import { Link, useNavigate, useParams } from 'react-router-dom';
import { ChevronLeft, Printer, RefreshCw } from 'lucide-react';
import { apiService, resolveMediaUrl } from '../../services/api';
import type { AdminOrderDetail } from '../../types';
import type { ReturnRequest } from '../../types';
import type { ShippingMethod } from '../../types';

function formatPriceVnd(n: number): string {
  return `${Math.round(n).toLocaleString('vi-VN')} đ`;
}

function formatDateTimeVi(d: string): string {
  const dt = new Date(d);
  if (Number.isNaN(dt.getTime())) return d;
  return dt.toLocaleString('vi-VN', { hour: '2-digit', minute: '2-digit', day: '2-digit', month: '2-digit', year: 'numeric' });
}

function statusUi(status: string): { label: string; cls: string } {
  const s = (status || '').toLowerCase();
  if (s === 'returnpending') return { label: 'Chờ duyệt hoàn hàng', cls: 'pend' };
  if (s === 'refundpending') return { label: 'Chờ hoàn tiền', cls: 'pend' };
  if (s === 'returned') return { label: 'Hoàn hàng', cls: 'proc' };
  if (s === 'refunded') return { label: 'Đã hoàn tiền', cls: 'refund' };
  if (s === 'cancelled' || s === 'canceled') return { label: 'Đã hủy', cls: 'fail' };
  if (s === 'failed') return { label: 'Thất bại', cls: 'fail' };
  if (s === 'completed' || s === 'delivered') return { label: 'Hoàn tất', cls: 'ok' };
  if (s === 'shipping' || s === 'intransit' || s === 'in_transit') return { label: 'Đang giao', cls: 'ship' };
  if (s === 'preparing' || s === 'preparing_goods' || s === 'packing') return { label: 'Chuẩn bị hàng', cls: 'proc' };
  if (s === 'pending') return { label: 'Chờ xử lý', cls: 'pend' };
  if (s === 'processing') return { label: 'Đã xác nhận', cls: 'proc' };
  return { label: status || 'Đang xử lý', cls: 'proc' };
}

type Step = { key: string; label: string };
const BASE_STEPS: Step[] = [
  { key: 'pending', label: 'Chờ xử lý' },
  { key: 'confirmed', label: 'Đã xác nhận' },
  { key: 'preparing', label: 'Đang chuẩn bị hàng' },
  { key: 'shipping', label: 'Đang giao hàng' },
  { key: 'delivered', label: 'Đã giao hàng' },
  { key: 'completed', label: 'Hoàn thành' },
];

const PIPELINE_OPTIONS: { value: string; label: string }[] = [
  { value: 'Pending', label: 'Chờ xử lý' },
  { value: 'Processing', label: 'Đã xác nhận' },
  { value: 'Preparing', label: 'Chuẩn bị hàng' },
  { value: 'Shipping', label: 'Đang giao' },
  { value: 'Delivered', label: 'Đã giao' },
  { value: 'Completed', label: 'Hoàn tất' },
];

function stepIndexFromStatus(status: string): number {
  const s = (status || '').toLowerCase();
  if (s === 'pending') return 0;
  if (s === 'processing') return 1;
  if (s === 'preparing' || s === 'preparing_goods' || s === 'packing') return 2;
  if (s === 'shipping' || s === 'intransit' || s === 'in_transit') return 3;
  if (s === 'delivered') return 4;
  if (s === 'completed') return 5;
  return 1;
}

export function AdminOrderDetailPage() {
  const nav = useNavigate();
  const { id } = useParams();
  const idOrToken = String(id || '').trim();
  const numericId = Number(idOrToken);
  const hasNumericId = Number.isFinite(numericId) && numericId > 0 && String(Math.trunc(numericId)) === idOrToken;
  const [data, setData] = useState<AdminOrderDetail | null>(null);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [status, setStatus] = useState<string>('');
  const [returnReq, setReturnReq] = useState<ReturnRequest | null>(null);
  const [returnNote, setReturnNote] = useState('');
  const [returnSaving, setReturnSaving] = useState(false);
  const [refundFile, setRefundFile] = useState<File | null>(null);
  const [refundUploading, setRefundUploading] = useState(false);
  const [refundProofNote, setRefundProofNote] = useState('');
  const [refundNoteSaving, setRefundNoteSaving] = useState(false);
  /** Nháp mã vận đơn / đối tác theo ShipmentID */
  const [shipDrafts, setShipDrafts] = useState<Record<number, { carrier: string; tracking: string }>>({});
  const [shipSavingId, setShipSavingId] = useState<number | null>(null);
  const [shippingMethods, setShippingMethods] = useState<ShippingMethod[]>([]);

  const load = useCallback(async () => {
    if (!idOrToken) return;
    setLoading(true);
    try {
      const res = hasNumericId ? await apiService.getAdminOrderDetail(numericId) : await apiService.getAdminOrderDetailByToken(idOrToken);
      setData(res);
      const drafts: Record<number, { carrier: string; tracking: string }> = {};
      (res.shipments || []).forEach((s: AdminShipmentRow) => {
        drafts[s.shipmentID] = { carrier: s.carrier ?? '', tracking: s.trackingNumber ?? '' };
      });
      setShipDrafts(drafts);
      setStatus(res.pipelineStatus || res.status || '');
      const rr = await apiService.adminGetReturnRequestByOrder(res.orderID);
      setReturnReq(rr);
      setReturnNote(rr?.adminNote || '');
      setRefundProofNote(rr?.refundNote || '');
      setRefundFile(null);
    } finally {
      setLoading(false);
    }
  }, [idOrToken, hasNumericId, numericId]);

  useEffect(() => {
    load();
  }, [load]);

  useEffect(() => {
    apiService.getShippingMethods().then((xs) => setShippingMethods(xs || [])).catch(() => setShippingMethods([]));
  }, []);

  const payOk = ['paid', 'success'].includes((data?.latestPayment?.status || '').toLowerCase());
  const ui = payOk ? { label: 'Thanh toán thành công', cls: 'ok' } : statusUi(data?.status || status);
  const pipelineStatus = data?.pipelineStatus || data?.status || '';
  const rawStepIndex = useMemo(() => stepIndexFromStatus(pipelineStatus || status), [pipelineStatus, status]);
  const currentIndex = useMemo(() => stepIndexFromStatus(pipelineStatus || ''), [pipelineStatus]);
  const isCancelled = useMemo(() => {
    const s = (pipelineStatus || '').trim().toLowerCase();
    return s === 'cancelled' || s === 'canceled' || s === 'failed';
  }, [pipelineStatus]);

  const canAdminCancel = useMemo(() => {
    if (!data) return false;
    const s = (pipelineStatus || '').trim().toLowerCase();
    if (s === 'cancelled' || s === 'canceled' || s === 'failed') return false;
    if (s === 'shipping' || s === 'intransit' || s === 'in_transit' || s === 'delivered' || s === 'completed') return false;
    if (s === 'returnpending' || s === 'returned' || s === 'refundpending' || s === 'refunded') return false;
    const shippedByShipment =
      (data.shipments || []).some((x) => {
        const st = (x.status || '').trim().toLowerCase();
        return st === 'shipping' || st === 'intransit' || st === 'in_transit' || st === 'delivered';
      }) || (data.shipments || []).some((x) => !!x.shippedDate || !!x.actualDeliveryDate);
    return !shippedByShipment;
  }, [data, pipelineStatus]);

  const adminCancel = async () => {
    if (!data) return;
    const reason = window.prompt('Lý do hủy đơn (tùy chọn):', '') ?? '';
    if (!window.confirm(`Xác nhận hủy đơn ${data.orderCode || `#${data.orderID}`}?`)) return;
    setSaving(true);
    try {
      await apiService.adminCancelOrder(data.orderID, reason.trim() || null);
      await load();
    } catch (e: unknown) {
      window.alert(e instanceof Error ? e.message : 'Hủy đơn thất bại.');
    } finally {
      setSaving(false);
    }
  };

  const subtotal = useMemo(() => (data?.items || []).reduce((sum, it) => sum + (it.lineTotal || 0), 0), [data?.items]);
  // Freeship rule: based on subtotal BEFORE VAT and BEFORE shipping fee
  const shippingFee = useMemo(() => {
    if (subtotal >= 200000) return 0;
    const mid = (data as any)?.shippingMethodID as number | null | undefined;
    const picked = mid ? (shippingMethods || []).find((m) => m.methodID === mid) : null;
    const fallback = (shippingMethods || []).slice().sort((a, b) => (a.baseCost || 0) - (b.baseCost || 0))[0] || null;
    const base = (picked?.baseCost ?? fallback?.baseCost ?? 30000) || 30000;
    return base;
  }, [subtotal, data, shippingMethods]);
  const returnApproved = (returnReq?.status || '').trim().toLowerCase() === 'approved';
  const approveNoteOk = returnNote.trim().length > 0;
  const refundProofNoteOk = refundProofNote.trim().length > 0;
  const returnPending = (returnReq?.status || '').trim().toLowerCase() === 'pending';
  const returnType = (returnReq?.requestType || 'Return').trim().toLowerCase();
  const isReturnFlow = returnType === 'return';
  const returnMode = !isCancelled && isReturnFlow && !!returnReq && (returnPending || returnApproved);

  const steps = useMemo(() => {
    if (!returnMode) return BASE_STEPS;
    return BASE_STEPS.map((s, i) => (i === BASE_STEPS.length - 1 ? { key: 'return', label: 'Hoàn hàng' } : s));
  }, [returnMode]);

  const stepIndex = useMemo(() => {
    if (!returnMode) return rawStepIndex;
    // When return request is pending/approved, show last step as "Hoàn hàng"
    return Math.max(rawStepIndex, steps.length - 1);
  }, [returnMode, rawStepIndex, steps.length]);

  const saveStatus = async () => {
    if (!data) return;
    setSaving(true);
    try {
      const ok = await apiService.adminUpdateOrderStatus(data.orderID, status);
      if (!ok) throw new Error('Cập nhật thất bại');
      await load();
    } finally {
      setSaving(false);
    }
  };

  if (!idOrToken) {
    return (
      <div className="admin-card">
        <div className="admin-card-title">Chi tiết đơn hàng</div>
        <div className="muted">ID không hợp lệ.</div>
      </div>
    );
  }

  return (
    <div className="ord-detail">
      <div className="ord-detail-top">
        <div className="ord-detail-left">
          <div className="ord-detail-badge">{ui.label}</div>
          <h1 className="ord-detail-title">Chi Tiết Đơn Hàng: {data?.orderCode || `#${idOrToken}`}</h1>
          <div className="ord-detail-sub muted">{data?.orderDate ? `Đặt vào lúc ${formatDateTimeVi(data.orderDate)}` : '—'}</div>
        </div>
        <div className="ord-detail-actions">
          <button type="button" className="ord-admin-btn" onClick={() => window.print()}>
            <Printer size={16} aria-hidden /> In Hóa Đơn
          </button>
          {canAdminCancel ? (
            <button type="button" className="ord-admin-btn" onClick={adminCancel} disabled={!data || saving}>
              Hủy đơn
            </button>
          ) : null}
          {!isCancelled ? (
            <div className="ord-detail-status">
              <select className="ord-admin-select" value={status} onChange={(e) => setStatus(e.target.value)} disabled={!data || saving}>
                {PIPELINE_OPTIONS.map((opt) => (
                  <option key={opt.value} value={opt.value} disabled={stepIndexFromStatus(opt.value) < currentIndex}>
                    {opt.label}
                  </option>
                ))}
                <option value={data?.status || ''}>Giữ nguyên</option>
              </select>
              <button type="button" className="ord-admin-btn ord-admin-btn--primary" onClick={saveStatus} disabled={!data || saving}>
                <RefreshCw size={16} aria-hidden /> Cập nhật Trạng Thái
              </button>
            </div>
          ) : null}
        </div>
      </div>

      {isCancelled ? (
        <div className="order-progress-cancel" style={{ marginTop: 12 }}>
          Đơn hàng đã bị hủy / thất bại.
        </div>
      ) : (
        <div
          className="ord-steps"
          style={
            {
              ['--ord-progress' as any]: `${Math.max(0, Math.min(100, (stepIndex / Math.max(1, steps.length - 1)) * 100))}%`
            } as React.CSSProperties
          }
        >
          {steps.map((s, i) => {
            const done = i < stepIndex;
            const active = i === stepIndex;
            const isLast = i === steps.length - 1;
            const pending = returnMode && returnPending && isLast;
            return (
              <div key={s.key} className={`ord-step ${done ? 'done' : ''} ${active ? 'active' : ''} ${pending ? 'pending' : ''}`}>
                <div className="ord-step-dot" aria-hidden>
                  <span className="ord-step-check">
                    {pending ? (
                      <svg width="14" height="14" viewBox="0 0 24 24" fill="none" aria-hidden>
                        <path
                          d="M12 2a10 10 0 1 0 10 10A10 10 0 0 0 12 2Zm0 18a8 8 0 1 1 8-8a8 8 0 0 1-8 8Z"
                          fill="currentColor"
                        />
                        <path d="M12.75 7h-1.5v6l5 3 .75-1.23-4.25-2.52Z" fill="currentColor" />
                      </svg>
                    ) : (
                      '✓'
                    )}
                  </span>
                </div>
                <div className="ord-step-label">{s.label}</div>
              </div>
            );
          })}
        </div>
      )}

      {data && !loading ? (
        <section className="ord-card" style={{ marginBottom: 18 }}>
          <div className="ord-card-head">
            <div className="ord-card-title">Vận đơn & đối tác</div>
          </div>
          <div
            style={{
              marginBottom: 16,
              padding: '12px 14px',
              borderRadius: 12,
              background: 'rgba(234, 179, 8, 0.09)',
              border: '1px solid rgba(202, 138, 4, 0.28)',
              fontSize: 13,
              lineHeight: 1.55,
              color: '#713f12',
            }}
          >
            <strong style={{ display: 'block', marginBottom: 6 }}>Lưu ý khi lưu mã vận đơn</strong>
            <span style={{ display: 'block' }}>
              Mã vận đơn trên GHN/GHTK là do <strong>đối tác cấp</strong> sau khi shop tạo đơn giao trên hệ thống họ (hoặc sau này khi tích hợp API sẽ tự điền). Khác với{' '}
              <strong>mã đơn hàng</strong> do website tự sinh. Hãy nhập <strong>đúng mã đối tác</strong> và <strong>tên đối tác</strong> (VD: GHN, GHTK) để khách tra cứu công khai và
              mở link tra cứu trên app đối tác đúng.
            </span>
          </div>
          {(data.shipments?.length ?? 0) === 0 ? (
            <div className="muted" style={{ lineHeight: 1.5 }}>
              Chưa có bản ghi vận đơn (thường gặp khi đơn không chọn phương thức vận chuyển có tạo shipment).
            </div>
          ) : (
            <div style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
              {data.shipments!.map((s, idx) => {
                const dr = shipDrafts[s.shipmentID] ?? { carrier: s.carrier ?? '', tracking: s.trackingNumber ?? '' };
                return (
                  <div
                    key={s.shipmentID}
                    style={{
                      padding: '12px 0',
                      borderTop: idx === 0 ? 'none' : '1px solid rgba(0,0,0,0.06)',
                    }}
                  >
                    <div className="muted" style={{ fontWeight: 800, marginBottom: 8 }}>
                      Vận đơn #{s.shipmentID}
                      {s.status ? (
                        <span style={{ marginLeft: 8, fontWeight: 600 }}>({s.status})</span>
                      ) : null}
                    </div>
                    <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr auto', gap: 10, alignItems: 'end' }}>
                      <label style={{ display: 'flex', flexDirection: 'column', gap: 4, fontSize: 12, fontWeight: 800 }}>
                        Đối tác
                        <input
                          value={dr.carrier}
                          onChange={(e) =>
                            setShipDrafts((prev) => ({
                              ...prev,
                              [s.shipmentID]: { ...dr, carrier: e.target.value },
                            }))
                          }
                          placeholder="VD: GHN, GHTK, Nội bộ"
                          style={{
                            padding: '8px 10px',
                            borderRadius: 10,
                            border: '1px solid rgba(0,0,0,0.12)',
                            fontWeight: 600,
                          }}
                        />
                      </label>
                      <label style={{ display: 'flex', flexDirection: 'column', gap: 4, fontSize: 12, fontWeight: 800 }}>
                        Mã vận đơn
                        <input
                          value={dr.tracking}
                          onChange={(e) =>
                            setShipDrafts((prev) => ({
                              ...prev,
                              [s.shipmentID]: { ...dr, tracking: e.target.value },
                            }))
                          }
                          placeholder="Mã từ GHN/GHTK…"
                          style={{
                            padding: '8px 10px',
                            borderRadius: 10,
                            border: '1px solid rgba(0,0,0,0.12)',
                            fontFamily: 'ui-monospace, monospace',
                          }}
                        />
                      </label>
                      <button
                        type="button"
                        className="ord-admin-btn ord-admin-btn--primary"
                        disabled={shipSavingId != null}
                        onClick={async () => {
                          setShipSavingId(s.shipmentID);
                          try {
                            const ok = await apiService.adminUpdateShipmentDetails(s.shipmentID, {
                              carrier: dr.carrier.trim() || null,
                              trackingNumber: dr.tracking.trim() || null,
                            });
                            if (!ok) throw new Error('Lưu thất bại');
                            await load();
                          } finally {
                            setShipSavingId(null);
                          }
                        }}
                      >
                        {shipSavingId === s.shipmentID ? 'Đang lưu…' : 'Lưu'}
                      </button>
                    </div>
                  </div>
                );
              })}
            </div>
          )}
        </section>
      ) : null}

      {loading ? (
        <div className="admin-card">Đang tải…</div>
      ) : !data ? (
        <div className="admin-card">Không tìm thấy đơn hàng.</div>
      ) : (
        <div className="ord-detail-grid">
          <div className="ord-detail-main">
            <section className="ord-card">
              <div className="ord-card-head">
                <div className="ord-card-title">Sản phẩm trong đơn</div>
                <Link to="/admin/orders" className="ord-back">
                  <ChevronLeft size={16} aria-hidden /> Quay lại
                </Link>
              </div>

              <div className="ord-items">
                <div className="ord-items-head">
                  <div>SẢN PHẨM</div>
                  <div className="ord-items-right">
                    <div>GIÁ</div>
                    <div>SỐ LƯỢNG</div>
                    <div>TỔNG</div>
                  </div>
                </div>

                {data.items.map((it) => (
                  <div key={it.productID} className="ord-item">
                    <div className="ord-item-prod">
                      <img className="ord-item-img" src={resolveMediaUrl(it.thumbUrl)} alt={it.productName} />
                      <div>
                        <div className="ord-item-name">{it.productName}</div>
                        {it.sku ? <div className="muted ord-item-sku">{it.sku}</div> : null}
                      </div>
                    </div>
                    <div className="ord-items-right">
                      <div className="ord-item-price">{formatPriceVnd(it.unitPrice)}</div>
                      <div className="ord-item-qty">{String(it.quantity).padStart(2, '0')}</div>
                      <div className="ord-item-total">{formatPriceVnd(it.lineTotal)}</div>
                    </div>
                  </div>
                ))}

                <div className="ord-sum">
                  <div className="ord-sum-row">
                    <div className="muted">Tạm tính</div>
                    <div>{formatPriceVnd(subtotal)}</div>
                  </div>
                  <div className="ord-sum-row">
                    <div className="muted">Phí giao hàng</div>
                    <div>{formatPriceVnd(shippingFee)}</div>
                  </div>
                  <div className="ord-sum-row">
                    <div className="muted">Thuế (VAT+TNCN 1,5%)</div>
                    <div className="muted">—</div>
                  </div>
                  <div className="ord-sum-row ord-sum-total">
                    <div>Tổng cộng</div>
                    <div>{formatPriceVnd(data.totalAmount)}</div>
                  </div>
                </div>
              </div>
            </section>

            {returnReq && (
              <section className="ord-card">
                <div className="ord-card-head">
                  <div className="ord-card-title">{(returnReq.requestType || 'Return') === 'CancelRefund' ? 'Yêu cầu hoàn tiền (hủy đơn)' : 'Yêu cầu hoàn hàng'}</div>
                  <div className="muted" style={{ fontWeight: 800 }}>{returnReq.status}</div>
                </div>
                <div className="rr-reason" style={{ marginTop: 10, fontWeight: 800, lineHeight: 1.4 }}>
                  {returnReq.reason}
                </div>
                {returnReq.videoUrl ? (
                  <div style={{ marginTop: 12 }}>
                    <div className="muted" style={{ fontWeight: 900, marginBottom: 6 }}>Video</div>
                    <video src={resolveMediaUrl(returnReq.videoUrl)} controls style={{ width: '100%', borderRadius: 14, border: '1px solid rgba(0,0,0,0.08)' }} />
                  </div>
                ) : null}
                {returnReq.images?.length ? (
                  <div style={{ display: 'grid', gridTemplateColumns: 'repeat(6, minmax(0, 1fr))', gap: 8, marginTop: 12 }}>
                    {returnReq.images.map((img) => (
                      <a key={img.returnRequestImageID} href={resolveMediaUrl(img.imageUrl)} target="_blank" rel="noreferrer" style={{ display: 'block' }}>
                        <img src={resolveMediaUrl(img.imageUrl)} alt="return" style={{ width: '100%', height: 54, objectFit: 'cover', borderRadius: 10, border: '1px solid rgba(0,0,0,0.08)' }} />
                      </a>
                    ))}
                  </div>
                ) : null}

                {returnApproved && (
                  <div style={{ marginTop: 14 }}>
                    <div className="muted" style={{ fontWeight: 900, marginBottom: 6 }}>Chứng từ đã hoàn tiền</div>
                    <div className="muted" style={{ fontSize: 12, marginBottom: 8, lineHeight: 1.45 }}>
                      Nội dung gửi khách (bắt buộc khi upload ảnh): ví dụ số tiền, thời gian, nội dung chuyển khoản.
                    </div>

                    {returnReq.refundProofUrl ? (
                      <>
                        <div className="rr-reason" style={{ marginBottom: 10, fontWeight: 700, lineHeight: 1.45 }}>
                          {returnReq.refundNote || '—'}
                        </div>
                        <a
                          href={resolveMediaUrl(returnReq.refundProofUrl)}
                          target="_blank"
                          rel="noreferrer"
                          style={{ display: 'block', textDecoration: 'none', marginBottom: 12 }}
                        >
                          <img
                            src={resolveMediaUrl(returnReq.refundProofUrl)}
                            alt="refund-proof"
                            style={{ width: '100%', maxWidth: 520, borderRadius: 14, border: '1px solid rgba(0,0,0,0.08)' }}
                          />
                        </a>
                        <div className="muted" style={{ fontWeight: 900, marginBottom: 6 }}>Sửa nội dung gửi khách</div>
                        <textarea
                          value={refundProofNote}
                          onChange={(e) => setRefundProofNote(e.target.value)}
                          rows={3}
                          disabled={refundNoteSaving}
                          style={{ width: '100%', borderRadius: 12, border: '1px solid rgba(0,0,0,0.10)', background: '#f6f7f8', padding: 10, outline: 'none' }}
                        />
                        <button
                          type="button"
                          className="ord-admin-btn ord-admin-btn--primary"
                          style={{ marginTop: 8 }}
                          disabled={refundNoteSaving || !refundProofNote.trim()}
                          onClick={async () => {
                            if (!returnReq || !refundProofNote.trim()) return;
                            setRefundNoteSaving(true);
                            try {
                              const ok = await apiService.adminUpdateReturnRefundNote(returnReq.returnRequestID, refundProofNote.trim());
                              if (!ok) throw new Error('Lưu thất bại');
                              await load();
                            } finally {
                              setRefundNoteSaving(false);
                            }
                          }}
                        >
                          {refundNoteSaving ? 'Đang lưu...' : 'Lưu nội dung'}
                        </button>
                      </>
                    ) : (
                      <>
                        <textarea
                          value={refundProofNote}
                          onChange={(e) => setRefundProofNote(e.target.value)}
                          rows={3}
                          placeholder="Ví dụ: Đã chuyển 500.000đ vào STK … lúc 14:30 09/04/2026, nội dung CK: HOAN TIEN DH …"
                          disabled={refundUploading}
                          style={{ width: '100%', borderRadius: 12, border: '1px solid rgba(0,0,0,0.10)', background: '#f6f7f8', padding: 10, outline: 'none', marginBottom: 10 }}
                        />
                        <div style={{ display: 'flex', gap: 10, alignItems: 'center', flexWrap: 'wrap' }}>
                          <input
                            type="file"
                            accept="image/*"
                            disabled={refundUploading}
                            onChange={(e) => setRefundFile((e.target.files || [])[0] || null)}
                          />
                          <button
                            type="button"
                            className="ord-admin-btn ord-admin-btn--primary"
                            disabled={!refundFile || !refundProofNoteOk || refundUploading}
                            title={!refundProofNoteOk ? 'Nhập nội dung xác nhận hoàn tiền trước khi upload' : undefined}
                            onClick={async () => {
                              if (!returnReq || !refundFile || !refundProofNote.trim()) return;
                              setRefundUploading(true);
                              try {
                                await apiService.adminUploadReturnRefundProof(returnReq.returnRequestID, refundFile, refundProofNote.trim());
                                await load();
                              } finally {
                                setRefundUploading(false);
                              }
                            }}
                          >
                            {refundUploading ? 'Đang upload...' : 'Upload chứng từ'}
                          </button>
                        </div>
                      </>
                    )}
                  </div>
                )}

                <div style={{ marginTop: 12 }}>
                  <div className="muted" style={{ fontWeight: 900, marginBottom: 6 }}>
                    Ghi chú admin <span style={{ color: '#b45309' }}>(bắt buộc khi duyệt / từ chối)</span>
                  </div>
                  <textarea
                    value={returnNote}
                    onChange={(e) => setReturnNote(e.target.value)}
                    rows={3}
                    placeholder="Ví dụ: đã xác nhận hoàn tiền theo STK khách cung cấp..."
                    style={{ width: '100%', borderRadius: 12, border: '1px solid rgba(0,0,0,0.10)', background: '#f6f7f8', padding: 10, outline: 'none' }}
                    disabled={returnSaving}
                  />
                </div>

                <div style={{ display: 'flex', gap: 10, marginTop: 12 }}>
                  <button
                    type="button"
                    className="ord-admin-btn"
                    disabled={returnSaving || returnReq.status.toLowerCase() !== 'pending'}
                    onClick={async () => {
                      setReturnSaving(true);
                      try {
                        await apiService.adminUpdateReturnRequestStatus(returnReq.returnRequestID, 'Rejected', returnNote);
                        const rr = await apiService.adminGetReturnRequestByOrder(data.orderID);
                        setReturnReq(rr);
                      } finally {
                        setReturnSaving(false);
                      }
                    }}
                  >
                    Từ chối
                  </button>
                  <button
                    type="button"
                    className="ord-admin-btn ord-admin-btn--primary"
                    disabled={returnSaving || returnReq.status.toLowerCase() !== 'pending' || !approveNoteOk}
                    title={!approveNoteOk ? 'Vui lòng nhập ghi chú admin trước khi duyệt' : undefined}
                    onClick={async () => {
                      if (!returnNote.trim()) return;
                      setReturnSaving(true);
                      try {
                        await apiService.adminUpdateReturnRequestStatus(returnReq.returnRequestID, 'Approved', returnNote.trim());
                        const rr = await apiService.adminGetReturnRequestByOrder(data.orderID);
                        setReturnReq(rr);
                      } finally {
                        setReturnSaving(false);
                      }
                    }}
                  >
                    Duyệt hoàn hàng
                  </button>
                </div>
              </section>
            )}

            <section className="ord-card">
              <div className="ord-card-head">
                <div className="ord-card-title">Ghi chú nội bộ</div>
                <button type="button" className="ord-note-add">+ Thêm ghi chú</button>
              </div>
              <div className="ord-note">
                <div className="ord-note-item">
                  <div className="ord-note-name">{data.customer.fullName}</div>
                  <div className="ord-note-text muted">Bạn có thể bổ sung tính năng lưu ghi chú vào DB ở bước sau.</div>
                </div>
                <div className="ord-note-input">
                  <input placeholder="Mô tả ghi chú mới..." />
                  <button type="button">Gửi</button>
                </div>
              </div>
            </section>
          </div>

          <aside className="ord-detail-side">
            <section className="ord-card">
              <div className="ord-card-title">Thông tin khách hàng</div>
              <div className="ord-customer">
                <div className="ord-customer-avatar">
                  {data.customer.avatarUrl ? (
                    <img
                      src={resolveMediaUrl(data.customer.avatarUrl)}
                      alt={data.customer.fullName || 'Avatar'}
                      style={{ width: '100%', height: '100%', objectFit: 'cover', borderRadius: '999px', display: 'block' }}
                    />
                  ) : (
                    (data.customer.fullName || 'U').slice(0, 1).toUpperCase()
                  )}
                </div>
                <div>
                  <div className="ord-customer-name">{data.customer.fullName}</div>
                  <div className="muted">Khách hàng tiềm năng</div>
                </div>
              </div>
              <div className="ord-customer-meta">
                <div className="muted">{data.customer.email}</div>
                {data.customer.phone ? <div className="muted">{data.customer.phone}</div> : null}
              </div>
            </section>

            <section className="ord-card">
              <div className="ord-card-title">Giao hàng &amp; Thanh toán</div>
              <div className="ord-ship">
                <div className="ord-ship-label muted">ĐỊA CHỈ GIAO HÀNG</div>
                <div className="ord-ship-val">{data.shippingAddress}</div>
              </div>
              <div className="ord-ship">
                <div className="ord-ship-label muted">PHƯƠNG THỨC THANH TOÁN</div>
                <div className="ord-ship-val">
                  {data.latestPayment?.method ? data.latestPayment.method : '—'}
                  {data.latestPayment?.status ? <span className="muted"> ({data.latestPayment.status})</span> : null}
                </div>
              </div>
            </section>

            <section className="ord-card">
              <div className="ord-card-title">Lịch sử hoạt động</div>
              <p className="muted" style={{ fontSize: 12, lineHeight: 1.5, margin: '0 0 14px' }}>
                Backend hiện <strong>chưa lưu nhật ký</strong> từng lần đổi trạng thái (Pending → Processing → …). Phần dưới chỉ là{' '}
                <strong>tóm tắt trạng thái hiện tại</strong>, không phải timeline từng bước — vì vậy sẽ không thấy đủ các bước trung gian.
              </p>
              <div className="ord-activity">
                <div className="ord-activity-item">
                  <div className="ord-activity-dot" />
                  <div>
                    <div>Đặt hàng</div>
                    <div className="muted">{formatDateTimeVi(data.orderDate)}</div>
                  </div>
                </div>
                <div className="ord-activity-item">
                  <div className="ord-activity-dot" />
                  <div>
                    <div>
                      Trạng thái đơn (hiện tại): <b>{data.status}</b>
                    </div>
                    <div className="muted" style={{ fontSize: 12 }}>
                      Không có thời điểm “đổi sang trạng thái này” — bảng Orders chưa có cột cập nhật / bảng nhật ký.
                    </div>
                  </div>
                </div>
                {data.latestPayment ? (
                  <div className="ord-activity-item">
                    <div className="ord-activity-dot" />
                    <div>
                      <div>
                        Thanh toán: <b>{data.latestPayment.status || '—'}</b>
                        {data.latestPayment.method ? (
                          <span className="muted"> ({data.latestPayment.method})</span>
                        ) : null}
                      </div>
                      <div className="muted">{formatDateTimeVi(data.latestPayment.paymentDate)}</div>
                    </div>
                  </div>
                ) : null}
              </div>
            </section>

          </aside>
        </div>
      )}

      <div style={{ marginTop: 16 }}>
        <Link to="/admin/orders" className="ord-plain-link">
          <ChevronLeft size={16} aria-hidden /> Về danh sách
        </Link>
      </div>
    </div>
  );
}

