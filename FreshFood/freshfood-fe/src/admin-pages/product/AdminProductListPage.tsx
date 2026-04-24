import { useCallback, useEffect, useState } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import {
  Plus,
  AlertTriangle,
  Tag,
  Wallet,
  MoreVertical,
  Copy,
  ExternalLink,
  Trash2,
} from 'lucide-react';
import { apiService, resolveMediaUrl } from '../../services/api';
import type { AdminProductRow, AdminProductsPage, Category } from '../../types';

const PAGE_SIZE = 10;
const STOCK_BAR_CAP = 140;
const PLACEHOLDER_IMG =
  'https://images.pexels.com/photos/1300972/pexels-photo-1300972.jpeg?auto=compress&w=120';

function formatPriceVnd(n: number): string {
  return `${Math.round(n).toLocaleString('vi-VN')}₫`;
}

function formatInventoryValue(v: number): string {
  if (!Number.isFinite(v) || v <= 0) return '₫0';

  const compact = (value: number, unit: 'K' | 'M' | 'B', div: number) => {
    const raw = value / div;
    const rounded = raw >= 100 ? Math.round(raw) : Math.round(raw * 10) / 10; // 1 decimal for smaller values
    const text = (Number.isInteger(rounded) ? String(rounded) : String(rounded).replace(/\.0$/, '')).replace(/\.0$/, '');
    return `₫${text}${unit}`;
  };

  if (v >= 1_000_000_000) return compact(v, 'B', 1_000_000_000);
  if (v >= 1_000_000) return compact(v, 'M', 1_000_000);
  if (v >= 1_000) return compact(v, 'K', 1_000);
  return `₫${Math.round(v).toLocaleString('vi-VN')}`;
}

function categoryPillClass(categoryID: number | null | undefined): string {
  const k = (categoryID ?? 0) % 3;
  if (k === 0) return 'prod-admin-cat prod-admin-cat--veg';
  if (k === 1) return 'prod-admin-cat prod-admin-cat--fruit';
  return 'prod-admin-cat prod-admin-cat--baby';
}

function displayCategoryLabel(name: string | null | undefined): string {
  if (!name) return '—';
  return name.toUpperCase();
}

export function AdminProductListPage() {
  const navigate = useNavigate();
  const [page, setPage] = useState(1);
  const [data, setData] = useState<AdminProductsPage | null>(null);
  const [loading, setLoading] = useState(true);
  const [err, setErr] = useState<string | null>(null);
  const [q, setQ] = useState('');
  const [categoryId, setCategoryId] = useState<number | ''>('');
  const [status, setStatus] = useState<'all' | 'Active' | 'Inactive'>('all');
  const [categories, setCategories] = useState<Category[]>([]);
  const [suppliers, setSuppliers] = useState<{ id: number; name: string }[]>([]);
  const [menuProductId, setMenuProductId] = useState<number | null>(null);
  const [refresh, setRefresh] = useState(0);

  useEffect(() => {
    let cancelled = false;
    (async () => {
      try {
        const [cats, supRes] = await Promise.all([
          apiService.getAdminCategories(),
          apiService.getAdminSuppliersPage({ page: 1, pageSize: 200, tab: 'all' }),
        ]);
        if (cancelled) return;
        setCategories(Array.isArray(cats) ? cats : []);
        const items = supRes?.items ?? [];
        setSuppliers(items.map((s) => ({ id: s.supplierID, name: s.supplierName })));
      } catch {
        if (!cancelled) setCategories([]);
      }
    })();
    return () => {
      cancelled = true;
    };
  }, []);

  useEffect(() => {
    if (menuProductId == null) return;
    const onDown = (e: MouseEvent) => {
      const t = e.target as HTMLElement;
      if (!t.closest('[data-product-menu]')) setMenuProductId(null);
    };
    document.addEventListener('mousedown', onDown);
    return () => document.removeEventListener('mousedown', onDown);
  }, [menuProductId]);

  const load = useCallback(async () => {
    setLoading(true);
    setErr(null);
    try {
      const res = await apiService.getAdminProductsPage({
        page,
        pageSize: PAGE_SIZE,
        q: q.trim() || undefined,
        categoryId: categoryId === '' ? undefined : categoryId,
        status,
      });
      setData(res);
    } catch (e: unknown) {
      setErr(e instanceof Error ? e.message : 'Không tải được dữ liệu.');
      setData(null);
    } finally {
      setLoading(false);
    }
  }, [page, q, categoryId, status, refresh]);

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

  const openCreateForm = () => {
    navigate('/admin/products/new');
  };

  const copySku = async (r: AdminProductRow) => {
    try {
      await navigator.clipboard.writeText(r.sku);
    } catch {
      window.prompt('Mã SKU:', r.sku);
    }
    setMenuProductId(null);
  };

  const onDelete = async (r: AdminProductRow) => {
    setMenuProductId(null);
    if (!window.confirm(`Xóa sản phẩm "${r.productName}"?`)) return;
    const res = await apiService.adminDeleteProduct(r.productID);
    if (!res.ok) {
      window.alert(res.message || 'Không xóa được.');
      return;
    }
    setRefresh((x) => x + 1);
  };

  const openEdit = (r: AdminProductRow) => {
    setMenuProductId(null);
    navigate(`/admin/products/${r.productToken || r.productID}/edit`);
  };

  return (
    <div className="prod-admin">
      <div className="prod-admin-kicker">Admin catalog</div>
      <header className="prod-admin-head">
        <div>
          <h1 className="prod-admin-title">Danh mục hàng hóa</h1>
          <p className="prod-admin-sub muted">Quản lý SKU, giá, tồn kho và đối tác cung ứng.</p>
        </div>
        <button type="button" className="prod-admin-btn-primary" onClick={openCreateForm}>
          <Plus size={18} strokeWidth={2.25} aria-hidden />
          Thêm sản phẩm mới
        </button>
      </header>

      {err && <div className="prod-admin-err">{err}</div>}

      <div className="prod-admin-stats">
        <div className="prod-admin-stat prod-admin-stat--hero">
          <div className="prod-admin-stat-label">Tổng sản phẩm</div>
          <div className="prod-admin-stat-num">{loading ? '—' : stats?.total ?? 0}</div>
        </div>
        <div className="prod-admin-stat">
          <div className="prod-admin-stat-head">
            <span className="prod-admin-stat-label">Hết hàng</span>
            <AlertTriangle className="prod-admin-stat-ico prod-admin-stat-ico--warn" size={20} aria-hidden />
          </div>
          <div className="prod-admin-stat-num prod-admin-stat-num--warn">{loading ? '—' : stats?.outOfStock ?? 0}</div>
        </div>
        <div className="prod-admin-stat">
          <div className="prod-admin-stat-head">
            <span className="prod-admin-stat-label">Đang giảm giá</span>
            <Tag className="prod-admin-stat-ico prod-admin-stat-ico--sale" size={20} aria-hidden />
          </div>
          <div className="prod-admin-stat-num prod-admin-stat-num--sale">{loading ? '—' : stats?.onSale ?? 0}</div>
        </div>
        <div className="prod-admin-stat">
          <div className="prod-admin-stat-head">
            <span className="prod-admin-stat-label">Giá trị tồn kho</span>
            <Wallet className="prod-admin-stat-ico" size={20} aria-hidden />
          </div>
          <div className="prod-admin-stat-num prod-admin-stat-num--money">
            {loading ? '—' : formatInventoryValue(stats?.inventoryValue ?? 0)}
          </div>
        </div>
      </div>

      <div className="prod-admin-toolbar">
        <div className="prod-admin-toolbar-left">
          <span className="prod-admin-toolbar-label muted">Lọc nhanh</span>
          <select
            className="prod-admin-select"
            value={categoryId === '' ? '' : String(categoryId)}
            onChange={(e) => {
              setCategoryId(e.target.value === '' ? '' : Number(e.target.value));
              setPage(1);
            }}
          >
            <option value="">Tất cả danh mục</option>
            {categories.map((c) => (
              <option key={c.categoryID} value={c.categoryID}>
                {c.categoryName}
              </option>
            ))}
          </select>
          <select
            className="prod-admin-select"
            value={status}
            onChange={(e) => {
              setStatus(e.target.value as 'all' | 'Active' | 'Inactive');
              setPage(1);
            }}
            title="Trạng thái"
            aria-label="Trạng thái"
          >
            <option value="all">Tất cả trạng thái</option>
            <option value="Active">Hoạt động</option>
            <option value="Inactive">Ngừng hoạt động</option>
          </select>
        </div>
        <input
          className="prod-admin-search"
          placeholder="Tìm theo tên hoặc mã…"
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
              <th>Sản phẩm</th>
              <th>Danh mục</th>
              <th>Nhà cung cấp</th>
              <th>Giá bán</th>
              <th>Trạng thái</th>
              <th>Tồn kho</th>
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
                  Không có sản phẩm phù hợp.
                </td>
              </tr>
            ) : (
              items.map((r: AdminProductRow) => {
                const barPct = Math.min(100, Math.round((r.stockQuantity / STOCK_BAR_CAP) * 100));
                const sellPrice = r.discountPrice != null && r.discountPrice < r.price ? r.discountPrice : r.price;
                const isInactive = String(r.status || '').toLowerCase() === 'inactive';
                return (
                  <tr key={r.productID}>
                    <td>
                      <div className="prod-admin-cell-name">
                        <img
                          className="prod-admin-thumb"
                          src={r.imageUrl ? resolveMediaUrl(r.imageUrl) : PLACEHOLDER_IMG}
                          alt=""
                          onError={(e) => {
                            (e.target as HTMLImageElement).src = PLACEHOLDER_IMG;
                          }}
                        />
                        <div>
                          <div className="prod-admin-name">{r.productName}</div>
                          <div className="prod-admin-sku muted">Mã: {r.sku}</div>
                        </div>
                      </div>
                    </td>
                    <td>
                      {r.categoryName ? (
                        <span className={categoryPillClass(r.categoryID ?? undefined)}>{displayCategoryLabel(r.categoryName)}</span>
                      ) : (
                        <span className="muted">—</span>
                      )}
                    </td>
                    <td className="muted prod-admin-supplier">{r.supplierName || '—'}</td>
                    <td>
                      <div className="prod-admin-price-block">
                        <span className="prod-admin-price-main">{formatPriceVnd(sellPrice)}</span>
                        {r.isOnSale && (
                          <span className="prod-admin-price-old muted">{formatPriceVnd(r.price)}</span>
                        )}
                      </div>
                    </td>
                    <td>
                      <span className={`prod-admin-pill ${isInactive ? 'prod-admin-pill--off' : 'prod-admin-pill--on'}`}>
                        {isInactive ? 'Ngừng' : 'Hoạt động'}
                      </span>
                    </td>
                    <td>
                      <div className="prod-admin-stock-wrap">
                        <div
                          className={`prod-admin-stock-bar ${r.isLowStock ? 'prod-admin-stock-bar--low' : ''}`}
                          role="progressbar"
                          aria-valuenow={barPct}
                          aria-valuemin={0}
                          aria-valuemax={100}
                        >
                          <span style={{ width: `${barPct}%` }} />
                        </div>
                        <span className="prod-admin-stock-label">
                          {r.stockQuantity} {r.unit || 'kg'}
                        </span>
                      </div>
                    </td>
                    <td className="prod-admin-actions-cell">
                      <div className="prod-admin-more-wrap" data-product-menu>
                        <button
                          type="button"
                          className="prod-admin-more"
                          aria-expanded={menuProductId === r.productID}
                          title="Thao tác"
                          aria-label="Thao tác"
                          data-product-menu
                          onClick={() => setMenuProductId((id) => (id === r.productID ? null : r.productID))}
                        >
                          <MoreVertical size={18} />
                        </button>
                        {menuProductId === r.productID && (
                          <ul className="prod-admin-dropdown" role="menu" data-product-menu>
                            <li role="none">
                              <button type="button" role="menuitem" onClick={() => copySku(r)}>
                                <Copy size={16} aria-hidden /> Sao chép Mã SKU
                              </button>
                            </li>
                          <li role="none">
                            <button type="button" role="menuitem" onClick={() => openEdit(r)}>
                              Chỉnh sửa
                            </button>
                          </li>
                            <li role="none">
                              <Link to={`/product/${r.productToken || r.productID}`} role="menuitem" className="prod-admin-drop-link" data-product-menu onClick={() => setMenuProductId(null)}>
                                <ExternalLink size={16} aria-hidden /> Xem cửa hàng
                              </Link>
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
            {items.length ? ` – ${start + items.length}` : ''} trên {totalFiltered} sản phẩm
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
