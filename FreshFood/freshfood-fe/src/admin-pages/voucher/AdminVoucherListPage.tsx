import { useCallback, useEffect, useMemo, useState } from 'react';
import { Plus, Pencil, Trash2 } from 'lucide-react';
import { useNavigate } from 'react-router-dom';
import type { Voucher } from '../../types';
import { apiService } from '../../services/api';

function formatMoney(n: number): string {
  if (!Number.isFinite(n)) return '0₫';
  return `${Math.round(n).toLocaleString('vi-VN')}₫`;
}

function formatDate(iso?: string | null): string {
  if (!iso) return '—';
  const d = new Date(iso);
  if (Number.isNaN(d.getTime())) return '—';
  return d.toLocaleString('vi-VN');
}

function typeLabel(t?: string | null): string {
  const x = (t || '').toLowerCase();
  if (x === 'percentage') return 'Percentage';
  if (x === 'flat') return 'Flat';
  // existing data seems to use 'Percentage'/'Flat' - keep display safe
  return t || 'Flat';
}

export function AdminVoucherListPage() {
  const nav = useNavigate();
  const [rows, setRows] = useState<Voucher[]>([]);
  const [loading, setLoading] = useState(true);
  const [err, setErr] = useState<string | null>(null);
  const [q, setQ] = useState('');
  const [active, setActive] = useState<'all' | 'true' | 'false'>('all');
  const [refresh, setRefresh] = useState(0);

  const load = useCallback(async () => {
    setLoading(true);
    setErr(null);
    try {
      const data = await apiService.getAdminVouchers({
        q: q.trim() || undefined,
        active: active === 'all' ? undefined : active === 'true',
      });
      setRows(Array.isArray(data) ? data : []);
    } catch (e: unknown) {
      setErr(e instanceof Error ? e.message : 'Không tải được vouchers.');
      setRows([]);
    } finally {
      setLoading(false);
    }
  }, [q, active, refresh]);

  useEffect(() => {
    load();
  }, [load]);

  const total = rows.length;
  const activeCount = useMemo(() => rows.filter((v) => !!v.isActive).length, [rows]);

  const onDelete = async (v: Voucher) => {
    if (!window.confirm(`Xóa voucher "${v.code}"?`)) return;
    const r = await apiService.adminDeleteVoucher(v.voucherID);
    if (!r.ok) {
      window.alert(r.message || 'Không xóa được.');
      return;
    }
    setRefresh((x) => x + 1);
  };

  return (
    <div className="cat-admin">
      <header className="cat-admin-head">
        <div>
          <h1 className="cat-admin-title">Quản lý Vouchers</h1>
          <p className="cat-admin-sub muted">Danh sách voucher, lọc nhanh, và điều hướng sang trang thêm/sửa.</p>
        </div>
        <button type="button" className="cat-admin-btn-primary" onClick={() => nav('/admin/vouchers/new')}>
          <Plus size={18} strokeWidth={2.25} aria-hidden />
          Thêm voucher mới
        </button>
      </header>

      {err && <div className="cat-admin-err">{err}</div>}

      <div className="cat-admin-stats">
        <div className="cat-admin-stat">
          <div className="cat-admin-stat-label">Tổng vouchers</div>
          <div className="cat-admin-stat-value cat-admin-stat-value--green">{loading ? '—' : total}</div>
        </div>
        <div className="cat-admin-stat">
          <div className="cat-admin-stat-label">Đang kích hoạt</div>
          <div className="cat-admin-stat-value cat-admin-stat-value--green">{loading ? '—' : activeCount}</div>
        </div>
        <div className="cat-admin-stat">
          <div className="cat-admin-stat-label">Nháp / tắt</div>
          <div className="cat-admin-stat-value cat-admin-stat-value--amber">{loading ? '—' : total - activeCount}</div>
        </div>
      </div>

      <div className="prod-admin-toolbar" style={{ marginTop: 14 }}>
        <div className="prod-admin-toolbar-left">
          <span className="prod-admin-toolbar-label muted">Lọc</span>
          <select className="prod-admin-select" value={active} onChange={(e) => setActive((e.target.value as any) || 'all')}>
            <option value="all">Tất cả</option>
            <option value="true">Đang bật</option>
            <option value="false">Đang tắt</option>
          </select>
        </div>
        <input
          className="prod-admin-search"
          placeholder="Tìm theo mã…"
          value={q}
          onChange={(e) => setQ(e.target.value)}
        />
      </div>

      <div className="cat-admin-table-wrap">
        <table className="cat-admin-table">
          <thead>
            <tr>
              <th>Mã</th>
              <th>Loại</th>
              <th>Giá trị</th>
              <th>Đơn tối thiểu</th>
              <th>Hết hạn</th>
              <th>Trạng thái</th>
              <th>Thao tác</th>
            </tr>
          </thead>
          <tbody>
            {loading ? (
              <tr>
                <td colSpan={7} className="cat-admin-td-muted">
                  Đang tải…
                </td>
              </tr>
            ) : rows.length === 0 ? (
              <tr>
                <td colSpan={7} className="cat-admin-td-muted">
                  Chưa có voucher nào.
                </td>
              </tr>
            ) : (
              rows.map((v) => (
                <tr key={v.voucherID}>
                  <td style={{ fontWeight: 700 }}>{v.code}</td>
                  <td className="muted">{typeLabel(v.discountType)}</td>
                  <td>{v.discountType?.toLowerCase() === 'percentage' ? `${v.discountValue}%` : formatMoney(v.discountValue)}</td>
                  <td className="muted">{formatMoney(v.minOrderAmount)}</td>
                  <td className="muted">{formatDate(v.expiryDate)}</td>
                  <td>
                    <span className={v.isActive ? 'cat-admin-badge' : 'muted'}>{v.isActive ? 'Active' : 'Inactive'}</span>
                  </td>
                  <td>
                    <div className="cat-admin-actions">
                      <button
                        type="button"
                        className="cat-admin-icon-btn"
                        title="Sửa"
                        onClick={() => nav(`/admin/vouchers/${v.voucherToken || v.voucherID}/edit`)}
                      >
                        <Pencil size={16} strokeWidth={2} />
                      </button>
                      <button
                        type="button"
                        className="cat-admin-icon-btn cat-admin-icon-btn--danger"
                        title="Xóa"
                        onClick={() => onDelete(v)}
                      >
                        <Trash2 size={16} strokeWidth={2} />
                      </button>
                    </div>
                  </td>
                </tr>
              ))
            )}
          </tbody>
        </table>
      </div>
    </div>
  );
}

