import { useCallback, useEffect, useMemo, useState } from 'react';
import { Pencil, Plus, Trash2 } from 'lucide-react';
import { apiService } from '../../services/api';
import type { Category } from '../../types';

const PAGE_SIZE = 10;

const ICON_BG = ['#E8F5E9', '#FFF3E0', '#E3F2FD', '#F3E5F5', '#E0F7FA', '#FBE9E7'];

function countProducts(c: Category): number {
  return c.products?.length ?? 0;
}

export function AdminCategoryPage() {
  const [rows, setRows] = useState<Category[]>([]);
  const [loading, setLoading] = useState(true);
  const [page, setPage] = useState(1);
  const [formOpen, setFormOpen] = useState(false);
  const [editingId, setEditingId] = useState<number | null>(null);
  const [name, setName] = useState('');
  const [desc, setDesc] = useState('');
  const [saving, setSaving] = useState(false);
  const [err, setErr] = useState<string | null>(null);

  const load = useCallback(async () => {
    setLoading(true);
    setErr(null);
    try {
      const data = await apiService.getAdminCategories();
      setRows(Array.isArray(data) ? data : []);
    } catch {
      setErr('Không tải được danh mục.');
      setRows([]);
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    load();
  }, [load]);

  const total = rows.length;
  const totalProductCount = useMemo(() => rows.reduce((s, c) => s + countProducts(c), 0), [rows]);

  const sortedByProducts = useMemo(() => [...rows].sort((a, b) => countProducts(b) - countProducts(a)), [rows]);
  const topId = sortedByProducts[0]?.categoryID;

  const pageCount = Math.max(1, Math.ceil(total / PAGE_SIZE));
  const safePage = Math.min(page, pageCount);
  const start = (safePage - 1) * PAGE_SIZE;
  const pageRows = rows.slice(start, start + PAGE_SIZE);

  useEffect(() => {
    if (page > pageCount) setPage(pageCount);
  }, [page, pageCount]);

  const openNew = () => {
    setEditingId(null);
    setName('');
    setDesc('');
    setFormOpen(true);
    setErr(null);
  };

  const openEdit = (c: Category) => {
    setEditingId(c.categoryID);
    setName(c.categoryName);
    setDesc(c.description ?? '');
    setFormOpen(true);
    setErr(null);
  };

  const submitForm = async (e: React.FormEvent) => {
    e.preventDefault();
    const n = name.trim();
    if (!n) {
      setErr('Vui lòng nhập tên danh mục.');
      return;
    }
    setSaving(true);
    setErr(null);
    try {
      if (editingId != null) {
        const u = await apiService.adminUpdateCategory(editingId, { categoryName: n, description: desc.trim() });
        if (!u) throw new Error('Cập nhật thất bại');
      } else {
        const c = await apiService.adminCreateCategory({ categoryName: n, description: desc.trim() });
        if (!c) throw new Error('Tạo mới thất bại');
      }
      setFormOpen(false);
      setEditingId(null);
      setName('');
      setDesc('');
      await load();
      setPage(1);
    } catch (e: any) {
      setErr(e?.message || 'Lưu không thành công.');
    } finally {
      setSaving(false);
    }
  };

  const onDelete = async (c: Category) => {
    const ok = window.confirm(`Xóa danh mục "${c.categoryName}"?`);
    if (!ok) return;
    const r = await apiService.adminDeleteCategory(c.categoryID);
    if (!r.ok) {
      window.alert(r.message || 'Không xóa được.');
      return;
    }
    await load();
    setPage((p) => Math.min(p, Math.max(1, Math.ceil((total - 1) / PAGE_SIZE))));
  };

  return (
    <div className="cat-admin">
      <header className="cat-admin-head">
        <div>
          <h1 className="cat-admin-title">Quản lý Danh mục</h1>
          <p className="cat-admin-sub muted">Tổ chức và phân loại các sản phẩm nông sản hữu cơ của bạn.</p>
        </div>
        <button type="button" className="cat-admin-btn-primary" onClick={openNew}>
          <Plus size={18} strokeWidth={2.25} aria-hidden />
          Thêm danh mục mới
        </button>
      </header>

      {formOpen && (
        <form className="cat-admin-form" onSubmit={submitForm}>
          <div className="cat-admin-form-grid">
            <div>
              <label className="cat-admin-label">Tên danh mục</label>
              <input className="cat-admin-input" value={name} onChange={(e) => setName(e.target.value)} placeholder="VD: Rau củ tươi" />
            </div>
            <div>
              <label className="cat-admin-label">Mô tả</label>
              <input
                className="cat-admin-input"
                value={desc}
                onChange={(e) => setDesc(e.target.value)}
                placeholder="Mô tả ngắn cho danh mục"
              />
            </div>
          </div>
          {err && <div className="cat-admin-err">{err}</div>}
          <div className="cat-admin-form-actions">
            <button type="submit" className="cat-admin-btn-primary" disabled={saving}>
              {saving ? 'Đang lưu…' : editingId != null ? 'Cập nhật' : 'Tạo danh mục'}
            </button>
            <button
              type="button"
              className="cat-admin-btn-ghost"
              onClick={() => {
                setFormOpen(false);
                setEditingId(null);
                setErr(null);
              }}
            >
              Hủy
            </button>
          </div>
        </form>
      )}

      <div className="cat-admin-stats">
        <div className="cat-admin-stat">
          <div className="cat-admin-stat-label">Tổng danh mục</div>
          <div className="cat-admin-stat-value cat-admin-stat-value--green">{loading ? '—' : total}</div>
        </div>
        <div className="cat-admin-stat">
          <div className="cat-admin-stat-label">Sản phẩm hoạt động</div>
          <div className="cat-admin-stat-value cat-admin-stat-value--green">
            {loading ? '—' : new Intl.NumberFormat('vi-VN').format(totalProductCount)}
          </div>
        </div>
        <div className="cat-admin-stat">
          <div className="cat-admin-stat-label">Cập nhật lần cuối</div>
          <div className="cat-admin-stat-value cat-admin-stat-value--amber">Hôm nay</div>
        </div>
      </div>

      <div className="cat-admin-table-wrap">
        <table className="cat-admin-table">
          <thead>
            <tr>
              <th>Danh mục</th>
              <th>Mô tả</th>
              <th>Số lượng SP</th>
              <th>Thao tác</th>
            </tr>
          </thead>
          <tbody>
            {loading ? (
              <tr>
                <td colSpan={4} className="cat-admin-td-muted">
                  Đang tải…
                </td>
              </tr>
            ) : pageRows.length === 0 ? (
              <tr>
                <td colSpan={4} className="cat-admin-td-muted">
                  Chưa có danh mục. Thêm danh mục mới để bắt đầu.
                </td>
              </tr>
            ) : (
              pageRows.map((c, i) => {
                const n = countProducts(c);
                const bg = ICON_BG[(start + i) % ICON_BG.length];
                const letter = (c.categoryName || '?').trim().charAt(0).toUpperCase();
                return (
                  <tr key={c.categoryID}>
                    <td>
                      <div className="cat-admin-cell-name">
                        <span className="cat-admin-avatar" style={{ background: bg }}>
                          {letter}
                        </span>
                        <div>
                          <div className="cat-admin-name">{c.categoryName}</div>
                          {c.categoryID === topId && n > 0 && <span className="cat-admin-badge">Phổ biến nhất</span>}
                        </div>
                      </div>
                    </td>
                    <td className="cat-admin-desc">{c.description || '—'}</td>
                    <td className="cat-admin-qty">{n}</td>
                    <td>
                      <div className="cat-admin-actions">
                        <button type="button" className="cat-admin-icon-btn" title="Sửa" onClick={() => openEdit(c)}>
                          <Pencil size={16} strokeWidth={2} />
                        </button>
                        <button type="button" className="cat-admin-icon-btn cat-admin-icon-btn--danger" title="Xóa" onClick={() => onDelete(c)}>
                          <Trash2 size={16} strokeWidth={2} />
                        </button>
                      </div>
                    </td>
                  </tr>
                );
              })
            )}
          </tbody>
        </table>
      </div>

      {!loading && total > 0 && (
        <footer className="cat-admin-footer">
          <span className="cat-admin-footer-info muted">
            Hiển thị {start + 1} - {Math.min(start + PAGE_SIZE, total)} trên tổng số {total} danh mục
          </span>
          <div className="cat-admin-pager">
            <button
              type="button"
              className="cat-admin-page-btn"
              disabled={safePage <= 1}
              onClick={() => setPage((p) => Math.max(1, p - 1))}
              aria-label="Trang trước"
            >
              ‹
            </button>
            {Array.from({ length: pageCount }, (_, i) => i + 1).map((p) => (
              <button
                key={p}
                type="button"
                className={`cat-admin-page-btn ${p === safePage ? 'active' : ''}`}
                onClick={() => setPage(p)}
              >
                {p}
              </button>
            ))}
            <button
              type="button"
              className="cat-admin-page-btn"
              disabled={safePage >= pageCount}
              onClick={() => setPage((p) => Math.min(pageCount, p + 1))}
              aria-label="Trang sau"
            >
              ›
            </button>
          </div>
        </footer>
      )}
    </div>
  );
}
