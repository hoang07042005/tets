import { useCallback, useEffect, useMemo, useState } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { Download, Filter, MoreVertical } from 'lucide-react';
import { apiService } from '../../services/api';
import type { AdminOrderRow, AdminOrdersPage } from '../../types';

const PAGE_SIZE = 8;

function formatPriceVnd(n: number): string {
  return `${Math.round(n).toLocaleString('vi-VN')} đ`;
}

function formatDateVi(d: string): string {
  const dt = new Date(d);
  if (Number.isNaN(dt.getTime())) return d;
  return dt.toLocaleDateString('vi-VN', { day: '2-digit', month: '2-digit', year: 'numeric' });
}

function statusUi(status: string): { label: string; cls: string } {
  const s = (status || '').toLowerCase();
  // "paid" is a payment state; keep it green but don't imply shipping.
  if (s === 'paid') return { label: 'Đã thanh toán', cls: 'ok' };
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

export function AdminOrdersListPage() {
  const nav = useNavigate();
  const [page, setPage] = useState(1);
  const [data, setData] = useState<AdminOrdersPage | null>(null);
  const [loading, setLoading] = useState(true);
  const [q, setQ] = useState('');
  const [status, setStatus] = useState('all');
  const [refresh, setRefresh] = useState(0);

  const load = useCallback(async () => {
    setLoading(true);
    try {
      const res = await apiService.getAdminOrdersPage({ page, pageSize: PAGE_SIZE, status, q: q.trim() || undefined });
      setData(res);
    } finally {
      setLoading(false);
    }
  }, [page, status, q, refresh]);

  useEffect(() => {
    load();
  }, [load]);

  const items = data?.items ?? [];
  const stats = data?.stats;
  const total = data?.totalCount ?? 0;
  const pageCount = Math.max(1, Math.ceil(total / PAGE_SIZE));
  const safePage = Math.min(page, pageCount);

  useEffect(() => {
    if (page > pageCount) setPage(pageCount);
  }, [page, pageCount]);

  const exportCsv = () => {
    const header = ['orderCode', 'customerName', 'customerEmail', 'orderDate', 'totalAmount', 'status'];
    const lines = items.map((o) => [
      o.orderCode,
      o.customerName,
      o.customerEmail,
      o.orderDate,
      String(o.totalAmount),
      o.status,
    ]);
    const csv = [header, ...lines]
      .map((row) =>
        row
          .map((x) => {
            const s = String(x ?? '');
            return `"${s.split('"').join('""')}"`;
          })
          .join(',')
      )
      .join('\n');
    const blob = new Blob([csv], { type: 'text/csv;charset=utf-8' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `admin-orders-${new Date().toISOString().slice(0, 10)}.csv`;
    a.click();
    URL.revokeObjectURL(url);
  };

  const pageLabel = useMemo(() => {
    const start = (safePage - 1) * PAGE_SIZE;
    return `Hiển thị ${start + (items.length ? 1 : 0)}-${start + items.length} trên ${total} đơn hàng`;
  }, [safePage, items.length, total]);

  return (
    <div className="ord-admin">
      <header className="ord-admin-head">
        <div>
          <h1 className="ord-admin-title">Đơn hàng hiện tại</h1>
          <p className="ord-admin-sub muted">Giám sát và quản lý các giao dịch từ khách hàng trong hệ thống nông sản sạch.</p>
        </div>
      </header>

      <div className="ord-admin-table-wrap">
        <div className="ord-admin-filters">
          <input
            className="ord-admin-search"
            placeholder="Tìm theo mã đơn, tên khách, email…"
            value={q}
            onChange={(e) => {
              setQ(e.target.value);
              setPage(1);
            }}
          />
          <select
            className="ord-admin-select"
            value={status}
            onChange={(e) => {
              setStatus(e.target.value);
              setPage(1);
            }}
          >
            <option value="all">Tất cả</option>
            <option value="Pending">Chờ xử lý</option>
            <option value="Processing">Đã xác nhận</option>
            <option value="Preparing">Chuẩn bị hàng</option>
            <option value="Shipping">Đang giao</option>
            <option value="Delivered">Đã giao</option>
            <option value="Completed">Hoàn tất</option>
            <option value="Paid">Đã thanh toán</option>
            <option value="ReturnPending">Chờ duyệt hoàn hàng</option>
            <option value="Returned">Hoàn hàng</option>
            <option value="RefundPending">Chờ hoàn tiền</option>
            <option value="Refunded">Đã hoàn tiền</option>
            <option value="Cancelled">Đã hủy</option>
            <option value="Failed">Thất bại</option>
          </select>
        </div>

        <table className="ord-admin-table">
          <thead>
            <tr>
              <th>Mã đơn hàng</th>
              <th>Khách hàng</th>
              <th>Ngày đặt</th>
              <th>Tổng tiền</th>
              <th>Trạng thái</th>
              <th aria-label="Thao tác" />
            </tr>
          </thead>
          <tbody>
            {loading ? (
              <tr>
                <td colSpan={6} className="ord-admin-td-muted">Đang tải…</td>
              </tr>
            ) : items.length === 0 ? (
              <tr>
                <td colSpan={6} className="ord-admin-td-muted">Không có đơn hàng phù hợp.</td>
              </tr>
            ) : (
              items.map((o: AdminOrderRow) => {
                const ui = statusUi(o.status);
                return (
                  <tr key={o.orderID} onClick={() => nav(`/admin/orders/${o.orderToken || o.orderID}`)} className="ord-admin-row">
                    <td className="ord-admin-code">{o.orderCode}</td>
                    <td>
                      <div className="ord-admin-cust">
                        <div className="ord-admin-cust-name">{o.customerName}</div>
                        <div className="ord-admin-cust-email muted">{o.customerEmail}</div>
                      </div>
                    </td>
                    <td className="muted">{formatDateVi(o.orderDate)}</td>
                    <td className="ord-admin-money">{formatPriceVnd(o.totalAmount)}</td>
                    <td>
                      <span className={`ord-admin-pill ord-admin-pill--${ui.cls}`}>{ui.label}</span>
                    </td>
                    <td>
                      <Link to={`/admin/orders/${o.orderToken || o.orderID}`} className="ord-admin-more" onClick={(e) => e.stopPropagation()} aria-label="Chi tiết">
                        <MoreVertical size={18} />
                      </Link>
                    </td>
                  </tr>
                );
              })
            )}
          </tbody>
        </table>

        <div className="ord-admin-footer">
          <div className="muted">{pageLabel}</div>
          <div className="ord-admin-pager">
            <button className="ord-admin-page" type="button" disabled={safePage <= 1} onClick={() => setPage((p) => Math.max(1, p - 1))}>
              ‹
            </button>
            {Array.from({ length: pageCount }, (_, i) => i + 1).map((p) => (
              <button key={p} className={`ord-admin-page ${p === safePage ? 'active' : ''}`} type="button" onClick={() => setPage(p)}>
                {p}
              </button>
            ))}
            <button className="ord-admin-page" type="button" disabled={safePage >= pageCount} onClick={() => setPage((p) => Math.min(pageCount, p + 1))}>
              ›
            </button>
          </div>
        </div>
      </div>

      <div className="ord-admin-stats">
        <div className="ord-admin-stat ord-admin-stat--money">
          <div className="ord-admin-stat-label">DOANH THU NGÀY</div>
          <div className="ord-admin-stat-val">{formatPriceVnd(stats?.dailyRevenue ?? 0)}</div>
        </div>
        <div className="ord-admin-stat ord-admin-stat--ship">
          <div className="ord-admin-stat-label">ĐANG GIAO</div>
          <div className="ord-admin-stat-val">{String(stats?.shippingCount ?? 0).padStart(2, '0')} Đơn</div>
        </div>
        <div className="ord-admin-stat ord-admin-stat--pend">
          <div className="ord-admin-stat-label">CHỜ XỬ LÝ</div>
          <div className="ord-admin-stat-val">{String(stats?.pendingCount ?? 0).padStart(2, '0')} Đơn</div>
        </div>
      </div>
    </div>
  );
}

