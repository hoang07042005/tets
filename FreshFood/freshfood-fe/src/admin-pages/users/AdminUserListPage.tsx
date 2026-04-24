import { useCallback, useEffect, useMemo, useState } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { Lock, MoreVertical, Shield, Trash2, Unlock, UserCircle2, Users } from 'lucide-react';
import { apiService, resolveMediaUrl } from '../../services/api';
import type { AdminUserRow, AdminUsersPage } from '../../types';
import { useAuth } from '../../context/AuthContext';

const PAGE_SIZE = 15;

function formatDate(iso?: string | null): string {
  if (!iso) return '—';
  const d = new Date(iso);
  if (Number.isNaN(d.getTime())) return '—';
  return d.toLocaleString('vi-VN');
}

function isAdminRole(role?: string | null): boolean {
  return (role || '').trim().toLowerCase() === 'admin';
}

function initials(name: string): string {
  const p = name.trim().split(/\s+/).slice(0, 2);
  return p.map((x) => x[0]).join('').toUpperCase() || '?';
}

function UserAvatar({ name, url }: { name: string; url: string }) {
  const [broken, setBroken] = useState(!url);
  if (broken || !url) {
    return (
      <span className="admin-user-avatar-fallback" aria-hidden>
        {initials(name)}
      </span>
    );
  }
  return (
    <img
      className="prod-admin-thumb admin-user-avatar"
      src={url}
      alt=""
      onError={() => setBroken(true)}
    />
  );
}

export function AdminUserListPage() {
  const navigate = useNavigate();
  const { user: authUser, logout } = useAuth();
  const [page, setPage] = useState(1);
  const [data, setData] = useState<AdminUsersPage | null>(null);
  const [loading, setLoading] = useState(true);
  const [err, setErr] = useState<string | null>(null);
  const [q, setQ] = useState('');
  const [roleFilter, setRoleFilter] = useState<'all' | 'admin' | 'customer'>('all');
  const [statusFilter, setStatusFilter] = useState<'all' | 'active' | 'locked'>('all');
  const [refresh, setRefresh] = useState(0);
  const [savingId, setSavingId] = useState<number | null>(null);
  const [menuUserId, setMenuUserId] = useState<number | null>(null);

  const load = useCallback(async () => {
    setLoading(true);
    setErr(null);
    try {
      const res = await apiService.getAdminUsersPage({
        page,
        pageSize: PAGE_SIZE,
        q: q.trim() || undefined,
        role: roleFilter,
        status: statusFilter,
      });
      setData(res);
    } catch (e: unknown) {
      setErr(e instanceof Error ? e.message : 'Không tải được dữ liệu.');
      setData(null);
    } finally {
      setLoading(false);
    }
  }, [page, q, roleFilter, statusFilter, refresh]);

  useEffect(() => {
    load();
  }, [load]);

  useEffect(() => {
    if (menuUserId == null) return;
    const onDown = (e: MouseEvent) => {
      const t = e.target as HTMLElement;
      if (!t.closest('[data-admin-user-menu]')) setMenuUserId(null);
    };
    document.addEventListener('mousedown', onDown);
    return () => document.removeEventListener('mousedown', onDown);
  }, [menuUserId]);

  const stats = data?.stats;
  const items = data?.items ?? [];
  const totalFiltered = data?.totalCount ?? 0;
  const pageCount = Math.max(1, Math.ceil(totalFiltered / PAGE_SIZE));
  const safePage = Math.min(page, pageCount);
  const start = (safePage - 1) * PAGE_SIZE;

  useEffect(() => {
    if (page > pageCount) setPage(pageCount);
  }, [page, pageCount]);

  const onRoleChange = async (row: AdminUserRow, next: 'Admin' | 'Customer') => {
    const current = isAdminRole(row.role) ? 'Admin' : 'Customer';
    if (next === current) return;

    if (current === 'Admin' && next === 'Customer') {
      if (!window.confirm(`Hạ quyền "${row.fullName}" xuống Khách hàng?`)) return;
    }

    setSavingId(row.userID);
    setErr(null);
    try {
      await apiService.adminUpdateUserRole(row.userID, next);
      if (authUser?.userID === row.userID && next === 'Customer') {
        logout();
        navigate('/', { replace: true });
        window.alert('Bạn không còn quyền quản trị. Đã đăng xuất.');
        return;
      }
      setRefresh((x) => x + 1);
    } catch (e: unknown) {
      setErr(e instanceof Error ? e.message : 'Không cập nhật được vai trò.');
    } finally {
      setSavingId(null);
    }
  };

  const onSetLock = async (row: AdminUserRow, isLocked: boolean) => {
    setMenuUserId(null);
    const verb = isLocked ? 'khóa' : 'mở khóa';
    if (!window.confirm(`${isLocked ? 'Khóa' : 'Mở khóa'} tài khoản "${row.fullName}" (${row.email})?`)) return;

    setSavingId(row.userID);
    setErr(null);
    try {
      await apiService.adminSetUserLock(row.userID, isLocked);
      if (authUser?.userID === row.userID && isLocked) {
        logout();
        navigate('/login', { replace: true });
        window.alert('Tài khoản của bạn đã bị khóa. Vui lòng liên hệ quản trị viên khác.');
        return;
      }
      setRefresh((x) => x + 1);
    } catch (e: unknown) {
      setErr(e instanceof Error ? e.message : `Không ${verb} được tài khoản.`);
    } finally {
      setSavingId(null);
    }
  };

  const onDelete = async (row: AdminUserRow) => {
    setMenuUserId(null);
    if (
      !window.confirm(
        `Xóa vĩnh viễn tài khoản "${row.fullName}"?\nChỉ thực hiện được khi người dùng chưa có đơn hàng nào.`,
      )
    )
      return;

    setSavingId(row.userID);
    setErr(null);
    try {
      const r = await apiService.adminDeleteUser(row.userID);
      if (!r.ok) {
        setErr(r.message || 'Không xóa được.');
        return;
      }
      if (authUser?.userID === row.userID) {
        logout();
        navigate('/', { replace: true });
        window.alert('Tài khoản đã được xóa.');
        return;
      }
      setRefresh((x) => x + 1);
    } finally {
      setSavingId(null);
    }
  };

  const statCards = useMemo(
    () => [
      { label: 'Tổng tài khoản', value: stats?.total ?? 0, icon: Users },
      { label: 'Quản trị viên', value: stats?.admins ?? 0, icon: Shield, accent: 'prod-admin-stat-num--sale' as const },
      { label: 'Khách hàng', value: stats?.customers ?? 0, icon: UserCircle2 },
      { label: 'Đang khóa', value: stats?.locked ?? 0, icon: Lock, accent: 'prod-admin-stat-num--warn' as const },
    ],
    [stats],
  );

  return (
    <div className="prod-admin">
      <div className="prod-admin-kicker">Admin</div>
      <header className="prod-admin-head">
        <div>
          <h1 className="prod-admin-title">Quản lý người dùng</h1>
          <p className="prod-admin-sub muted">Danh sách tài khoản, khóa/mở khóa đăng nhập, phân quyền và xóa (khi chưa có đơn).</p>
        </div>
      </header>

      {err && <div className="prod-admin-err">{err}</div>}

      <div className="prod-admin-stats">
        {statCards.map(({ label, value, icon: Icon, accent }) => (
          <div key={label} className="prod-admin-stat">
            <div className="prod-admin-stat-head">
              <span className="prod-admin-stat-label">{label}</span>
              <Icon className="prod-admin-stat-ico" size={20} aria-hidden />
            </div>
            <div className={`prod-admin-stat-num ${accent ?? ''}`}>{loading ? '—' : value}</div>
          </div>
        ))}
      </div>

      <div className="prod-admin-toolbar">
        <div className="prod-admin-toolbar-left">
          <span className="prod-admin-toolbar-label muted">Vai trò</span>
          <select
            className="prod-admin-select"
            value={roleFilter}
            onChange={(e) => {
              setRoleFilter(e.target.value as 'all' | 'admin' | 'customer');
              setPage(1);
            }}
          >
            <option value="all">Tất cả</option>
            <option value="admin">Admin</option>
            <option value="customer">Khách hàng</option>
          </select>
          <span className="prod-admin-toolbar-label muted" style={{ marginLeft: 10 }}>
            Trạng thái
          </span>
          <select
            className="prod-admin-select"
            value={statusFilter}
            onChange={(e) => {
              setStatusFilter(e.target.value as 'all' | 'active' | 'locked');
              setPage(1);
            }}
          >
            <option value="all">Tất cả</option>
            <option value="active">Đang hoạt động</option>
            <option value="locked">Đã khóa</option>
          </select>
        </div>
        <input
          className="prod-admin-search"
          placeholder="Tìm theo tên, email, SĐT…"
          value={q}
          onChange={(e) => {
            setQ(e.target.value);
            setPage(1);
          }}
        />
      </div>

      <div className="prod-admin-table-wrap">
        <table className="prod-admin-table">
          <thead>
            <tr>
              <th>Người dùng</th>
              <th>Số điện thoại</th>
              <th>Trạng thái</th>
              <th>Vai trò</th>
              <th>Đơn hàng</th>
              <th>Ngày đăng ký</th>
              <th className="prod-admin-th-actions" aria-label="Thao tác" />
            </tr>
          </thead>
          <tbody>
            {loading ? (
              <tr>
                <td colSpan={7} className="prod-admin-td-muted">
                  Đang tải…
                </td>
              </tr>
            ) : items.length === 0 ? (
              <tr>
                <td colSpan={7} className="prod-admin-td-muted">
                  Không có người dùng phù hợp.
                </td>
              </tr>
            ) : (
              items.map((r) => {
                const av = r.avatarUrl ? resolveMediaUrl(r.avatarUrl) : '';
                const roleVal = isAdminRole(r.role) ? 'Admin' : 'Customer';
                const busy = savingId === r.userID;
                const locked = !!r.isLocked;
                return (
                  <tr key={r.userID} className={locked ? 'admin-user-row--locked' : undefined}>
                    <td>
                      <div className="prod-admin-cell-name admin-user-cell">
                        <UserAvatar name={r.fullName} url={av} />
                        <div>
                          <div className="prod-admin-name">{r.fullName}</div>
                          <div className="prod-admin-sku muted">{r.email}</div>
                        </div>
                      </div>
                    </td>
                    <td className="muted">{r.phone || '—'}</td>
                    <td>
                      <span className={`admin-user-status ${locked ? 'admin-user-status--locked' : 'admin-user-status--active'}`}>
                        {locked ? 'Đã khóa' : 'Hoạt động'}
                      </span>
                    </td>
                    <td>
                      <select
                        className="prod-admin-select admin-user-role-select"
                        value={roleVal}
                        disabled={busy}
                        aria-label={`Vai trò ${r.fullName}`}
                        onChange={(e) => onRoleChange(r, e.target.value as 'Admin' | 'Customer')}
                      >
                        <option value="Customer">Khách hàng</option>
                        <option value="Admin">Quản trị viên</option>
                      </select>
                    </td>
                    <td>
                      {r.orderCount > 0 ? (
                        <Link to="/admin/orders" className="admin-user-orders-link">
                          {r.orderCount}
                        </Link>
                      ) : (
                        <span className="muted">0</span>
                      )}
                    </td>
                    <td className="muted prod-admin-date">{formatDate(r.createdAt)}</td>
                    <td className="prod-admin-actions-cell">
                      <div className="prod-admin-more-wrap" data-admin-user-menu>
                        <button
                          type="button"
                          className="prod-admin-more"
                          aria-expanded={menuUserId === r.userID}
                          title="Thao tác"
                          aria-label="Thao tác"
                          data-admin-user-menu
                          disabled={busy}
                          onClick={() => setMenuUserId((id) => (id === r.userID ? null : r.userID))}
                        >
                          <MoreVertical size={18} />
                        </button>
                        {menuUserId === r.userID && (
                          <ul className="prod-admin-dropdown" role="menu" data-admin-user-menu>
                            <li role="none">
                              <button
                                type="button"
                                role="menuitem"
                                onClick={() => (locked ? onSetLock(r, false) : onSetLock(r, true))}
                              >
                                {locked ? (
                                  <>
                                    <Unlock size={16} aria-hidden /> Mở khóa
                                  </>
                                ) : (
                                  <>
                                    <Lock size={16} aria-hidden /> Khóa tài khoản
                                  </>
                                )}
                              </button>
                            </li>
                            <li role="none">
                              <button
                                type="button"
                                role="menuitem"
                                className="danger"
                                onClick={() => onDelete(r)}
                                disabled={r.orderCount > 0}
                                title={r.orderCount > 0 ? 'Có đơn hàng — không thể xóa' : undefined}
                              >
                                <Trash2 size={16} aria-hidden /> Xóa tài khoản
                              </button>
                            </li>
                          </ul>
                        )}
                      </div>
                    </td>
                  </tr>
                );
              })
            )}
          </tbody>
        </table>
      </div>

      {!loading && totalFiltered > 0 && (
        <footer className="prod-admin-footer">
          <span className="prod-admin-footer-info muted">
            Hiển thị {start + (items.length ? 1 : 0)}
            {items.length ? ` – ${start + items.length}` : ''} trên {totalFiltered} tài khoản
          </span>
          <div className="prod-admin-pager">
            <button type="button" className="prod-admin-page-btn" disabled={safePage <= 1} onClick={() => setPage((p) => Math.max(1, p - 1))}>
              ‹
            </button>
            {Array.from({ length: pageCount }, (_, i) => i + 1).map((p) => (
              <button
                key={p}
                type="button"
                className={`prod-admin-page-btn ${p === safePage ? 'active' : ''}`}
                onClick={() => setPage(p)}
              >
                {p}
              </button>
            ))}
            <button
              type="button"
              className="prod-admin-page-btn"
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
