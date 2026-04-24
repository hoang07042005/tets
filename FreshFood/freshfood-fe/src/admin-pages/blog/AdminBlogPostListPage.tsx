import { useEffect, useMemo, useState } from 'react';
import { Link } from 'react-router-dom';
import { ExternalLink, MoreVertical, Trash2 } from 'lucide-react';
import { apiService, resolveMediaUrl } from '../../services/api';
import type { BlogPost } from '../../types';

function fmtDate(iso?: string | null): string {
  if (!iso) return '—';
  const d = new Date(iso);
  if (Number.isNaN(d.getTime())) return '—';
  return d.toLocaleString('vi-VN');
}

/** Bản xem trước trong bảng: bỏ thẻ HTML, gộp khoảng trắng/xuống dòng thành một đoạn ngắn. */
function contentListPreview(raw?: string | null): string {
  if (!raw?.trim()) return '';
  const plain = raw.replace(/<[^>]*>/g, ' ').replace(/\s+/g, ' ').trim();
  return plain;
}

export const AdminBlogPostListPage = () => {
  const [loading, setLoading] = useState(true);
  const [items, setItems] = useState<BlogPost[]>([]);
  const [q, setQ] = useState('');
  const [published, setPublished] = useState<'all' | 'published' | 'draft'>('all');
  const [error, setError] = useState<string | null>(null);
  const [menuBlogPostId, setMenuBlogPostId] = useState<number | null>(null);

  const publishedFilter = useMemo(() => {
    if (published === 'published') return true;
    if (published === 'draft') return false;
    return undefined;
  }, [published]);

  const load = async () => {
    setLoading(true);
    setError(null);
    try {
      const data = await apiService.getAdminBlogPosts({
        q: q.trim() || undefined,
        published: publishedFilter,
      });
      setItems(data || []);
    } catch (e: unknown) {
      const msg = e instanceof Error ? e.message : 'Không tải được bài viết';
      setError(msg);
      setItems([]);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    load();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [q, publishedFilter]);

  useEffect(() => {
    if (menuBlogPostId == null) return;
    const onDown = (e: MouseEvent) => {
      const t = e.target as HTMLElement;
      if (!t.closest('[data-blog-menu]')) setMenuBlogPostId(null);
    };
    document.addEventListener('mousedown', onDown);
    return () => document.removeEventListener('mousedown', onDown);
  }, [menuBlogPostId]);

  const onDelete = async (id: number) => {
    setMenuBlogPostId(null);
    const ok = window.confirm('Xóa bài viết này?');
    if (!ok) return;
    const res = await apiService.adminDeleteBlogPost(id);
    if (!res.ok) {
      window.alert(res.message || 'Xóa thất bại');
      return;
    }
    await load();
  };

  return (
    <div className="blog-admin-list">
      <div className="blog-admin-list__kicker">Nội dung</div>
      <header className="blog-admin-list__head">
        <div>
          <h1 className="blog-admin-list__title">Quản lý Blog</h1>
          <p className="blog-admin-list__sub">Danh sách bài viết, lọc theo trạng thái, chỉnh sửa nhanh.</p>
        </div>
        <Link to="/admin/blog/new" className="prod-admin-btn-primary" style={{ textDecoration: 'none' }}>
          Thêm bài viết
        </Link>
      </header>

      <section className="blog-admin-list__filters" aria-label="Bộ lọc">
        <div className="blog-admin-list__filters-row">
          <label className="blog-admin-list__field">
            <span className="visually-hidden">Tìm kiếm</span>
            <input
              className="blog-admin-list__input"
              type="search"
              placeholder="Tìm theo tiêu đề, slug…"
              value={q}
              onChange={(e) => setQ(e.target.value)}
              autoComplete="off"
            />
          </label>
          <label className="blog-admin-list__field blog-admin-list__field--narrow">
            <span className="visually-hidden">Trạng thái</span>
            <select className="blog-admin-list__input" value={published} onChange={(e) => setPublished(e.target.value as 'all' | 'published' | 'draft')}>
              <option value="all">Tất cả</option>
              <option value="published">Đã đăng</option>
              <option value="draft">Bản nháp</option>
            </select>
          </label>
        </div>
        {error ? <div className="admin-alert admin-alert--danger" style={{ marginTop: '0.75rem' }}>{error}</div> : null}
      </section>

      <div className="blog-admin-list__table-wrap">
        {loading ? (
          <div className="blog-admin-list__empty">Đang tải…</div>
        ) : items.length === 0 ? (
          <div className="blog-admin-list__empty">Chưa có bài viết.</div>
        ) : (
          <div className="blog-admin-list__scroll">
            <table className="blog-admin-list__table">
              <thead>
                <tr>
                  <th className="blog-admin-list__th blog-admin-list__th--thumb" scope="col">
                    Ảnh
                  </th>
                  <th className="blog-admin-list__th" scope="col">
                    Tiêu đề
                  </th>
                  <th className="blog-admin-list__th blog-admin-list__th--content" scope="col">
                    Nội dung
                  </th>
                  <th className="blog-admin-list__th blog-admin-list__th--status" scope="col">
                    Trạng thái
                  </th>
                  <th className="blog-admin-list__th blog-admin-list__th--date" scope="col">
                    Ngày đăng
                  </th>
                  <th className="blog-admin-list__th prod-admin-th-actions" aria-label="Thao tác" scope="col" />
                </tr>
              </thead>
              <tbody>
                {items.map((p) => {
                  const contentPreview = contentListPreview(p.content);
                  const contentTitle = contentPreview.length > 400 ? `${contentPreview.slice(0, 400)}…` : contentPreview || undefined;
                  return (
                    <tr key={p.blogPostID}>
                      <td className="blog-admin-list__td blog-admin-list__td--thumb">
                        <div className="blog-admin-list__thumb" aria-hidden>
                          {p.coverImageUrl ? <img src={resolveMediaUrl(p.coverImageUrl)} alt="" loading="lazy" /> : null}
                        </div>
                      </td>
                      <td className="blog-admin-list__td blog-admin-list__td--title">
                        <div className="blog-admin-list__post-title">{p.title}</div>
                        {p.excerpt ? <p className="blog-admin-list__excerpt">{p.excerpt}</p> : null}
                      </td>
                      <td className="blog-admin-list__td blog-admin-list__td--content">
                        <p className="blog-admin-list__content-preview" title={contentTitle}>
                          {contentPreview || '—'}
                        </p>
                      </td>
                      <td className="blog-admin-list__td blog-admin-list__td--status">
                        {p.isPublished ? (
                          <span className="blog-admin-list__badge blog-admin-list__badge--live">Đã đăng</span>
                        ) : (
                          <span className="blog-admin-list__badge">Bản nháp</span>
                        )}
                      </td>
                      <td className="blog-admin-list__td blog-admin-list__td--date">{fmtDate(p.publishedAt)}</td>
                      <td className="blog-admin-list__td prod-admin-actions-cell">
                        <div className="prod-admin-more-wrap" data-blog-menu>
                          <button
                            type="button"
                            className="prod-admin-more"
                            aria-expanded={menuBlogPostId === p.blogPostID}
                            title="Thao tác"
                            aria-label="Thao tác"
                            data-blog-menu
                            onClick={() => setMenuBlogPostId((id) => (id === p.blogPostID ? null : p.blogPostID))}
                          >
                            <MoreVertical size={18} />
                          </button>
                          {menuBlogPostId === p.blogPostID && (
                            <ul className="prod-admin-dropdown" role="menu" data-blog-menu>
                              <li role="none">
                                <Link
                                  to={`/blog/${p.slug}`}
                                  role="menuitem"
                                  className="prod-admin-drop-link"
                                  data-blog-menu
                                  target="_blank"
                                  rel="noreferrer"
                                  onClick={() => setMenuBlogPostId(null)}
                                >
                                  <ExternalLink size={16} aria-hidden /> Xem bài viết
                                </Link>
                              </li>
                              <li role="none">
                                <Link
                                  to={`/admin/blog/${p.blogPostToken || p.blogPostID}/edit`}
                                  role="menuitem"
                                  className="prod-admin-drop-link"
                                  data-blog-menu
                                  onClick={() => setMenuBlogPostId(null)}
                                >
                                  Chỉnh sửa
                                </Link>
                              </li>
                              <li role="none">
                                <button type="button" role="menuitem" className="danger" data-blog-menu onClick={() => onDelete(p.blogPostID)}>
                                  <Trash2 size={16} aria-hidden /> Xóa
                                </button>
                              </li>
                            </ul>
                          )}
                        </div>
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
        )}
      </div>
    </div>
  );
};
