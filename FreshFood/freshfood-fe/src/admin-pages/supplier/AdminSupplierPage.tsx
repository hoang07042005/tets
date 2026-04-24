import { useCallback, useEffect, useState } from 'react';
import {
  Plus,
  Filter,
  User,
  Phone,
  Truck,
  BadgeCheck,
  MoreVertical,
  Pencil,
  Trash2,
  Copy,
} from 'lucide-react';
import { apiService } from '../../services/api';
import type { AdminSupplierRow, AdminSuppliersPage } from '../../types';

type TabKey = 'all' | 'pending' | 'paused';

const PAGE_SIZE = 10;

function statusLabel(status: string): string {
  const s = (status || '').toLowerCase();
  if (s === 'active') return 'Hoạt động';
  if (s === 'paused') return 'Tạm dừng';
  if (s === 'pending') return 'Chờ duyệt';
  return status || '—';
}

function statusClass(status: string): string {
  const s = (status || '').toLowerCase();
  if (s === 'active') return 'sup-admin-pill sup-admin-pill--ok';
  if (s === 'paused') return 'sup-admin-pill sup-admin-pill--warn';
  if (s === 'pending') return 'sup-admin-pill sup-admin-pill--muted';
  return 'sup-admin-pill';
}

export function AdminSupplierPage() {
  const [tab, setTab] = useState<TabKey>('all');
  const [page, setPage] = useState(1);
  const [data, setData] = useState<AdminSuppliersPage | null>(null);
  const [loading, setLoading] = useState(true);
  const [err, setErr] = useState<string | null>(null);
  const [filterOpen, setFilterOpen] = useState(false);
  const [q, setQ] = useState('');
  const [formOpen, setFormOpen] = useState(false);
  const [formName, setFormName] = useState('');
  const [formContact, setFormContact] = useState('');
  const [formPhone, setFormPhone] = useState('');
  const [formEmail, setFormEmail] = useState('');
  const [formAddress, setFormAddress] = useState('');
  const [formImageUrl, setFormImageUrl] = useState('');
  const [formStatus, setFormStatus] = useState<'Active' | 'Paused' | 'Pending'>('Pending');
  const [formVerified, setFormVerified] = useState(false);
  const [editingId, setEditingId] = useState<number | null>(null);
  const [menuSupplierId, setMenuSupplierId] = useState<number | null>(null);
  const [saving, setSaving] = useState(false);
  const [refresh, setRefresh] = useState(0);

  useEffect(() => {
    if (menuSupplierId == null) return;
    const onDown = (e: MouseEvent) => {
      const t = e.target as HTMLElement;
      if (!t.closest('[data-supplier-menu]')) setMenuSupplierId(null);
    };
    document.addEventListener('mousedown', onDown);
    return () => document.removeEventListener('mousedown', onDown);
  }, [menuSupplierId]);

  const load = useCallback(async () => {
    setLoading(true);
    setErr(null);
    try {
      const res = await apiService.getAdminSuppliersPage({
        page,
        pageSize: PAGE_SIZE,
        tab,
        q: q.trim() || undefined,
      });
      setData(res);
    } catch (e: any) {
      setErr(e?.message || 'Không tải được dữ liệu.');
      setData(null);
    } finally {
      setLoading(false);
    }
  }, [page, tab, q, refresh]);

  useEffect(() => {
    load();
  }, [load]);

  const stats = data?.stats;
  const items = data?.items ?? [];
  const totalFiltered = data?.totalCount ?? 0;
  const pageCount = Math.max(1, Math.ceil(totalFiltered / PAGE_SIZE));
  const safePage = Math.min(page, pageCount);
  const start = (safePage - 1) * PAGE_SIZE;

  useEffect(() => {
    if (page > pageCount) setPage(pageCount);
  }, [page, pageCount]);

  const openEdit = (r: AdminSupplierRow) => {
    setMenuSupplierId(null);
    setEditingId(r.supplierID);
    setFormName(r.supplierName ?? '');
    setFormContact(r.contactName ?? '');
    setFormPhone(r.phone ?? '');
    setFormEmail(r.email ?? '');
    setFormAddress(r.address ?? '');
    setFormImageUrl(r.imageUrl ?? '');
    const st = (r.status || 'Active').trim();
    setFormStatus(st === 'Paused' ? 'Paused' : st === 'Pending' ? 'Pending' : 'Active');
    setFormVerified(!!r.isVerified);
    setFormOpen(true);
    setErr(null);
  };

  const copySupplierCode = async (r: AdminSupplierRow) => {
    const code = (r.supplierCode || `VH-${r.supplierID}`).trim();
    try {
      await navigator.clipboard.writeText(code);
    } catch {
      window.prompt('Sao chép mã NCC:', code);
    }
    setMenuSupplierId(null);
  };

  const onDelete = async (r: AdminSupplierRow) => {
    setMenuSupplierId(null);
    if (!window.confirm(`Xóa nhà cung cấp "${r.supplierName}"?`)) return;
    const res = await apiService.adminDeleteSupplier(r.supplierID);
    if (!res.ok) {
      window.alert(res.message || 'Không xóa được.');
      return;
    }
    setRefresh((x) => x + 1);
  };

  const submitCreate = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!formName.trim()) return;
    setSaving(true);
    try {
      if (editingId != null) {
        const row = await apiService.adminUpdateSupplier(editingId, {
          supplierName: formName.trim(),
          contactName: formContact.trim(),
          phone: formPhone.trim(),
          email: formEmail.trim(),
          address: formAddress.trim(),
          imageUrl: formImageUrl.trim() || undefined,
          status: formStatus,
          isVerified: formVerified,
        });
        if (!row) throw new Error('Cập nhật thất bại');
      } else {
        const row = await apiService.adminCreateSupplier({
          supplierName: formName.trim(),
          contactName: formContact.trim(),
          phone: formPhone.trim(),
          email: formEmail.trim(),
          address: formAddress.trim(),
          imageUrl: formImageUrl.trim() || undefined,
          status: 'Pending',
          isVerified: false,
        });
        if (!row) throw new Error('Tạo thất bại');
        setTab('all');
        setPage(1);
      }
      setFormOpen(false);
      setEditingId(null);
      setFormName('');
      setFormContact('');
      setFormPhone('');
      setFormEmail('');
      setFormAddress('');
      setFormImageUrl('');
      setFormStatus('Pending');
      setFormVerified(false);
      setRefresh((x) => x + 1);
    } catch {
      setErr(editingId != null ? 'Không cập nhật được nhà cung cấp.' : 'Không tạo được nhà cung cấp.');
    } finally {
      setSaving(false);
    }
  };

  return (
    <div className="sup-admin">
      <div className="sup-admin-kicker">Admin panel</div>
      <header className="sup-admin-head">
        <div>
          <h1 className="sup-admin-title">Đối tác cung ứng</h1>
          <p className="sup-admin-sub muted">Quản lý mạng lưới các trang trại và nhà cung cấp hữu cơ của bạn.</p>
        </div>
        <button
          type="button"
          className="sup-admin-btn-primary"
          onClick={() => {
            setEditingId(null);
            setFormName('');
            setFormContact('');
            setFormPhone('');
            setFormEmail('');
            setFormAddress('');
            setFormImageUrl('');
            setFormStatus('Pending');
            setFormVerified(false);
            setFormOpen((v) => !v);
          }}
        >
          <Plus size={18} strokeWidth={2.25} aria-hidden />
          Thêm nhà cung cấp
        </button>
      </header>

      {formOpen && (
        <form className="sup-admin-form" onSubmit={submitCreate}>
          <div className="sup-admin-form-grid">
            <div>
              <label className="sup-admin-label">Tên nhà cung cấp *</label>
              <input className="sup-admin-input" value={formName} onChange={(e) => setFormName(e.target.value)} required />
            </div>
            <div>
              <label className="sup-admin-label">Người liên hệ</label>
              <input className="sup-admin-input" value={formContact} onChange={(e) => setFormContact(e.target.value)} />
            </div>
            <div>
              <label className="sup-admin-label">Điện thoại</label>
              <input className="sup-admin-input" value={formPhone} onChange={(e) => setFormPhone(e.target.value)} />
            </div>
            <div>
              <label className="sup-admin-label">Email</label>
              <input className="sup-admin-input" type="email" value={formEmail} onChange={(e) => setFormEmail(e.target.value)} />
            </div>
            <div className="sup-admin-form-full">
              <label className="sup-admin-label">Địa chỉ</label>
              <input className="sup-admin-input" value={formAddress} onChange={(e) => setFormAddress(e.target.value)} />
            </div>
            <div className="sup-admin-form-full">
              <label className="sup-admin-label">URL ảnh đại diện</label>
              <input
                className="sup-admin-input"
                value={formImageUrl}
                onChange={(e) => setFormImageUrl(e.target.value)}
                placeholder="https://…"
              />
            </div>
            {editingId != null && (
              <>
                <div>
                  <label className="sup-admin-label">Trạng thái</label>
                  <select
                    className="sup-admin-input"
                    value={formStatus}
                    onChange={(e) => setFormStatus(e.target.value as typeof formStatus)}
                  >
                    <option value="Active">Hoạt động</option>
                    <option value="Paused">Tạm dừng</option>
                    <option value="Pending">Chờ duyệt</option>
                  </select>
                </div>
                <div className="sup-admin-form-check">
                  <label className="sup-admin-label-row">
                    <input type="checkbox" checked={formVerified} onChange={(e) => setFormVerified(e.target.checked)} />
                    <span>Đã xác minh</span>
                  </label>
                </div>
              </>
            )}
          </div>
          <div className="sup-admin-form-actions">
            <button type="submit" className="sup-admin-btn-primary" disabled={saving}>
              {saving ? 'Đang lưu…' : editingId != null ? 'Cập nhật' : 'Lưu'}
            </button>
            <button
              type="button"
              className="sup-admin-btn-ghost"
              onClick={() => {
                setFormOpen(false);
                setEditingId(null);
              }}
            >
              Đóng
            </button>
          </div>
        </form>
      )}

      {err && <div className="sup-admin-err">{err}</div>}

      <div className="sup-admin-stats">
        <div className="sup-admin-stat sup-admin-stat--hero">
          <div className="sup-admin-stat-label">Tổng số đối tác</div>
          <div className="sup-admin-stat-num">{loading ? '—' : stats?.total ?? 0}</div>
          <div className="sup-admin-stat-pill">
            +{loading ? '—' : stats?.newThisMonth ?? 0} trong tháng này
          </div>
        </div>
        <div className="sup-admin-stat">
          <div className="sup-admin-stat-head">
            <span className="sup-admin-stat-label">Đã xác minh</span>
            <BadgeCheck className="sup-admin-stat-ico" size={20} aria-hidden />
          </div>
          <div className="sup-admin-stat-num sup-admin-stat-num--dark">{loading ? '—' : stats?.verified ?? 0}</div>
        </div>
        <div className="sup-admin-stat">
          <div className="sup-admin-stat-head">
            <span className="sup-admin-stat-label">Đang giao dịch</span>
            <Truck className="sup-admin-stat-ico sup-admin-stat-ico--truck" size={20} aria-hidden />
          </div>
          <div className="sup-admin-stat-num sup-admin-stat-num--dark">{loading ? '—' : stats?.inTransaction ?? 0}</div>
        </div>
      </div>

      <div className="sup-admin-toolbar">
        <div className="sup-admin-tabs" role="tablist">
          {(
            [
              ['all', 'Tất cả'],
              ['pending', 'Chờ duyệt'],
              ['paused', 'Tạm dừng'],
            ] as const
          ).map(([key, label]) => (
            <button
              key={key}
              type="button"
              role="tab"
              aria-selected={tab === key}
              className={`sup-admin-tab ${tab === key ? 'active' : ''}`}
              onClick={() => {
                setTab(key);
                setPage(1);
              }}
            >
              {label}
            </button>
          ))}
        </div>
        <div className="sup-admin-filter-wrap">
          <button type="button" className="sup-admin-btn-filter" onClick={() => setFilterOpen((v) => !v)}>
            <Filter size={16} aria-hidden />
            Lọc dữ liệu
          </button>
          {filterOpen && (
            <input
              className="sup-admin-filter-input"
              placeholder="Tìm theo tên, mã, SĐT…"
              value={q}
              onChange={(e) => {
                setQ(e.target.value);
                setPage(1);
              }}
            />
          )}
        </div>
      </div>

      <div className="sup-admin-table-wrap">
        <table className="sup-admin-table">
          <thead>
            <tr>
              <th>Tên nhà cung cấp</th>
              <th>Liên hệ</th>
              <th>Địa chỉ</th>
              <th>Trạng thái</th>
              <th aria-label="Thao tác" />
            </tr>
          </thead>
          <tbody>
            {loading ? (
              <tr>
                <td colSpan={5} className="sup-admin-td-muted">
                  Đang tải…
                </td>
              </tr>
            ) : items.length === 0 ? (
              <tr>
                <td colSpan={5} className="sup-admin-td-muted">
                  Không có nhà cung cấp phù hợp.
                </td>
              </tr>
            ) : (
              items.map((r: AdminSupplierRow) => (
                <tr key={r.supplierID}>
                  <td>
                    <div className="sup-admin-cell-name">
                      <img
                        className="sup-admin-thumb"
                        src={
                          r.imageUrl ||
                          'https://images.pexels.com/photos/1300972/pexels-photo-1300972.jpeg?auto=compress&w=120'
                        }
                        alt=""
                        onError={(e) => {
                          (e.target as HTMLImageElement).src =
                            'https://images.pexels.com/photos/1300972/pexels-photo-1300972.jpeg?auto=compress&w=120';
                        }}
                      />
                      <div>
                        <div className="sup-admin-name">{r.supplierName}</div>
                        <div className="sup-admin-code muted">Mã NCC: {r.supplierCode || `VH-${r.supplierID}`}</div>
                      </div>
                    </div>
                  </td>
                  <td>
                    <div className="sup-admin-contact">
                      {r.contactName && (
                        <div className="sup-admin-contact-line">
                          <User size={14} aria-hidden /> {r.contactName}
                        </div>
                      )}
                      {r.phone && (
                        <div className="sup-admin-contact-line">
                          <Phone size={14} aria-hidden /> {r.phone}
                        </div>
                      )}
                      {!r.contactName && !r.phone && <span className="muted">—</span>}
                    </div>
                  </td>
                  <td className="sup-admin-address muted">{r.address || '—'}</td>
                  <td>
                    <span className={statusClass(r.status)}>{statusLabel(r.status)}</span>
                  </td>
                  <td className="sup-admin-actions-cell">
                    <div className="sup-admin-more-wrap" data-supplier-menu>
                      <button
                        type="button"
                        className="sup-admin-more"
                        title="Thao tác"
                        aria-label="Thao tác"
                        aria-expanded={menuSupplierId === r.supplierID}
                        data-supplier-menu
                        onClick={() => setMenuSupplierId((id) => (id === r.supplierID ? null : r.supplierID))}
                      >
                        <MoreVertical size={18} />
                      </button>
                      {menuSupplierId === r.supplierID && (
                        <ul className="sup-admin-dropdown" role="menu" data-supplier-menu>
                          <li role="none">
                            <button type="button" role="menuitem" onClick={() => copySupplierCode(r)}>
                              <Copy size={16} aria-hidden /> Sao chép mã NCC
                            </button>
                          </li>
                          <li role="none">
                            <button type="button" role="menuitem" onClick={() => openEdit(r)}>
                              <Pencil size={16} aria-hidden /> Chỉnh sửa
                            </button>
                          </li>
                          <li role="none">
                            <button type="button" role="menuitem" className="danger" onClick={() => onDelete(r)}>
                              <Trash2 size={16} aria-hidden /> Xóa
                            </button>
                          </li>
                        </ul>
                      )}
                    </div>
                  </td>
                </tr>
              ))
            )}
          </tbody>
        </table>
      </div>

      {!loading && totalFiltered > 0 && (
        <footer className="sup-admin-footer">
          <span className="sup-admin-footer-info muted">
            Hiển thị {start + (items.length ? 1 : 0)}
            {items.length ? ` - ${start + items.length}` : ''} trên {totalFiltered} nhà cung cấp
          </span>
          <div className="sup-admin-pager">
            <button
              type="button"
              className="sup-admin-page-btn"
              disabled={safePage <= 1}
              onClick={() => setPage((p) => Math.max(1, p - 1))}
            >
              ‹
            </button>
            {Array.from({ length: pageCount }, (_, i) => i + 1).map((p) => (
              <button
                key={p}
                type="button"
                className={`sup-admin-page-btn ${p === safePage ? 'active' : ''}`}
                onClick={() => setPage(p)}
              >
                {p}
              </button>
            ))}
            <button
              type="button"
              className="sup-admin-page-btn"
              disabled={safePage >= pageCount}
              onClick={() => setPage((p) => Math.min(pageCount, p + 1))}
            >
              ›
            </button>
          </div>
        </footer>
      )}
    </div>
  );
}
