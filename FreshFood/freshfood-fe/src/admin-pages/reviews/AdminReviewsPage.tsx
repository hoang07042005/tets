import { useEffect, useMemo, useState } from 'react';
import { Link } from 'react-router-dom';
import { apiService, resolveMediaUrl } from '../../services/api';
import type { AdminReviewListResponse, AdminReviewRow } from '../../types';

type Tab = 'pending' | 'approved' | 'hidden' | 'deleted';
type RatingFilter = 'all' | 5 | 4 | 3 | 2 | 1;

function formatCompact(n: number) {
  try {
    return new Intl.NumberFormat('vi-VN').format(n);
  } catch {
    return String(n);
  }
}

function timeAgo(iso: string) {
  const t = new Date(iso).getTime();
  if (!Number.isFinite(t)) return '';
  const diff = Date.now() - t;
  const m = Math.floor(diff / 60000);
  if (m < 1) return 'vừa xong';
  if (m < 60) return `${m} phút trước`;
  const h = Math.floor(m / 60);
  if (h < 24) return `${h} giờ trước`;
  const d = Math.floor(h / 24);
  if (d < 7) return `${d} ngày trước`;
  return new Date(iso).toLocaleString('vi-VN');
}

export function AdminReviewsPage() {
  const [tab, setTab] = useState<Tab>('pending');
  const [q, setQ] = useState('');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [data, setData] = useState<AdminReviewListResponse>({ total: 0, items: [] });

  const [skip, setSkip] = useState(0);
  const take = 30;
  const [ratingFilter, setRatingFilter] = useState<RatingFilter>('all');
  const [range, setRange] = useState<'7d' | '30d' | 'all'>('7d');

  // KPI counters (quick queries)
  const [kpi, setKpi] = useState<{ totalAll: number; pending: number; approved: number; hidden: number; deleted: number; replied: number; repliedPercent: number }>({
    totalAll: 0,
    pending: 0,
    approved: 0,
    hidden: 0,
    deleted: 0,
    replied: 0,
    repliedPercent: 0,
  });
  const [publicSummary, setPublicSummary] = useState<{ averageRating: number; totalReviews: number } | null>(null);

  const load = async (next?: { tab?: Tab; q?: string; skip?: number }) => {
    const st = next?.tab ?? tab;
    const search = next?.q ?? q;
    const nextSkip = typeof next?.skip === 'number' ? next.skip : skip;
    try {
      setLoading(true);
      setError(null);
      const res = await apiService.adminGetReviews({ status: st, q: search || undefined, skip: nextSkip, take });
      setData(res);
    } catch {
      setError('Không thể tải danh sách đánh giá.');
    } finally {
      setLoading(false);
    }
  };

  const refreshKpis = async () => {
    try {
      const s = await apiService.adminGetReviewStats();
      setKpi({
        totalAll: Number(s.total || 0),
        pending: Number(s.pending || 0),
        approved: Number(s.approved || 0),
        hidden: Number(s.hidden || 0),
        deleted: Number(s.deleted || 0),
        replied: Number(s.replied || 0),
        repliedPercent: Number(s.repliedPercent || 0),
      });
    } catch { /* ignore */ }
    try {
      const summary = await apiService.getReviewSummary();
      setPublicSummary(summary);
    } catch {
      // ignore
    }
  };

  useEffect(() => {
    setSkip(0);
    void load({ tab, skip: 0 });
    void refreshKpis();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [tab]);

  const doApprove = async (r: AdminReviewRow) => {
    const note = prompt('Ghi chú (tuỳ chọn):') ?? undefined;
    await apiService.adminApproveReview(r.reviewID, note);
    await load();
    await refreshKpis();
  };

  const doHide = async (r: AdminReviewRow) => {
    const note = prompt('Lý do ẩn (tuỳ chọn):') ?? undefined;
    await apiService.adminHideReview(r.reviewID, note);
    await load();
    await refreshKpis();
  };

  const doPending = async (r: AdminReviewRow) => {
    const note = prompt('Ghi chú (tuỳ chọn):') ?? undefined;
    await apiService.adminSetReviewPending(r.reviewID, note);
    await load();
    await refreshKpis();
  };

  const doDelete = async (r: AdminReviewRow) => {
    if (!confirm(`Xóa đánh giá #${r.reviewID}?`)) return;
    await apiService.adminDeleteReview(r.reviewID);
    await load();
    await refreshKpis();
  };

  const doRestore = async (r: AdminReviewRow) => {
    await apiService.adminRestoreReview(r.reviewID);
    await load();
    await refreshKpis();
  };

  const doReply = async (r: AdminReviewRow) => {
    const initial = r.adminReply || '';
    const next = prompt('Nhập phản hồi (để trống để xóa phản hồi):', initial);
    if (next === null) return;
    await apiService.adminSetReviewReply(r.reviewID, next);
    await load();
    await refreshKpis();
  };

  const totalPages = Math.max(1, Math.ceil((data.total || 0) / take));
  const page = Math.floor(skip / take) + 1;
  const hasPrev = skip > 0;
  const hasNext = skip + take < (data.total || 0);

  const pageNumbers = useMemo(() => {
    // show up to 5 pages around current
    const max = totalPages;
    if (max <= 1) return [1];
    const windowSize = 5;
    const half = Math.floor(windowSize / 2);
    let start = Math.max(1, page - half);
    let end = Math.min(max, start + windowSize - 1);
    start = Math.max(1, end - windowSize + 1);
    const nums: number[] = [];
    for (let i = start; i <= end; i++) nums.push(i);
    return nums;
  }, [page, totalPages]);

  const goToPage = (p: number) => {
    const clamped = Math.max(1, Math.min(totalPages, p));
    const next = (clamped - 1) * take;
    setSkip(next);
    void load({ skip: next });
  };

  const visibleItems = useMemo(() => {
    const list = Array.isArray(data.items) ? data.items : [];
    const byRating = ratingFilter === 'all' ? list : list.filter(x => x.rating === ratingFilter);
    // range is currently UI-only (no backend support); keep it for UX parity.
    return byRating;
  }, [data.items, ratingFilter]);

  const displayStart = data.total === 0 ? 0 : skip + 1;
  const displayEnd = Math.min(skip + take, data.total || 0);

  const exportCsv = () => {
    const rows = visibleItems.map(r => ({
      reviewID: r.reviewID,
      productID: r.productID,
      productName: r.productName,
      userID: r.userID,
      userName: r.userName,
      userEmail: r.userEmail ?? '',
      rating: r.rating,
      comment: (r.comment ?? '').replace(/\s+/g, ' ').trim(),
      reviewDate: r.reviewDate,
      moderationStatus: r.moderationStatus,
      moderatedAt: r.moderatedAt ?? '',
      moderationNote: r.moderationNote ?? '',
    }));
    const header = Object.keys(rows[0] || { reviewID: '' });
    const csv = [header.join(','), ...rows.map(obj => header.map(k => `"${String((obj as any)[k] ?? '').replace(/"/g, '""')}"`).join(','))].join('\n');
    const blob = new Blob([csv], { type: 'text/csv;charset=utf-8' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `reviews_${tab}_${new Date().toISOString().slice(0, 10)}.csv`;
    a.click();
    URL.revokeObjectURL(url);
  };

  return (
    <div className="admin-reviews">
      <div className="admin-dash-hero admin-reviews-hero">
        <div>
          <h2>Kiểm duyệt Đánh giá</h2>
          <p>Quản lý và phản hồi các nhận xét từ cộng đồng FreshFood.</p>
        </div>
        
      </div>

      <div className="admin-dash-stats admin-reviews-kpis">
        <div className="admin-kpi green">
          <div className="admin-kpi-top">
            <div className="admin-kpi-label">Tổng đánh giá</div>
            <div className="admin-kpi-delta"><span>+0%</span></div>
          </div>
          <div className="admin-kpi-value">{formatCompact(kpi.totalAll)}</div>
        </div>

        <div className="admin-kpi orange">
          <div className="admin-kpi-top">
            <div className="admin-kpi-label">Đánh giá mới</div>
            <div className="admin-kpi-delta"><span>{formatCompact(kpi.pending)} cần xử lý</span></div>
          </div>
          <div className="admin-kpi-value">{formatCompact(kpi.pending)}</div>
        </div>

        <div className="admin-kpi green">
          <div className="admin-kpi-top">
            <div className="admin-kpi-label">Tỷ lệ hài lòng</div>
            <div className="admin-kpi-delta"><span>Approved</span></div>
          </div>
          <div className="admin-kpi-value">{publicSummary ? publicSummary.averageRating.toFixed(1) : '—'}</div>
        </div>

        <div className="admin-kpi blue">
          <div className="admin-kpi-top">
            <div className="admin-kpi-label">Đã phản hồi</div>
            <div className="admin-kpi-delta"><span>{kpi.repliedPercent}%</span></div>
          </div>
          <div className="admin-kpi-value">{kpi.repliedPercent}%</div>
          <div className="admin-reviews-kpi-bar" aria-hidden>
            <div className="admin-reviews-kpi-bar-fill" style={{ width: `${Math.max(0, Math.min(100, kpi.repliedPercent))}%` }} />
          </div>
        </div>
      </div>

      <div className="admin-reviews-filters">
        <div className="admin-reviews-filters-left">
          <div className="admin-seg">
            <button className={ratingFilter === 'all' ? 'active' : ''} onClick={() => setRatingFilter('all')} type="button">Tất cả</button>
            <button className={ratingFilter === 5 ? 'active' : ''} onClick={() => setRatingFilter(5)} type="button">5 sao</button>
            <button className={ratingFilter === 4 ? 'active' : ''} onClick={() => setRatingFilter(4)} type="button">4 sao</button>
            <button className={ratingFilter === 3 ? 'active' : ''} onClick={() => setRatingFilter(3)} type="button">3 sao</button>
            <button className={ratingFilter === 2 ? 'active' : ''} onClick={() => setRatingFilter(2)} type="button">2 sao</button>
            <button className={ratingFilter === 1 ? 'active' : ''} onClick={() => setRatingFilter(1)} type="button">1 sao</button>
          </div>

          <div className="admin-reviews-selects">
            <select value={tab} onChange={(e) => setTab(e.target.value as Tab)}>
              <option value="pending">Tất cả trạng thái (Chờ duyệt)</option>
              <option value="approved">Đã duyệt</option>
              <option value="hidden">Đã ẩn</option>
              <option value="deleted">Đã xóa</option>
            </select>

            <select value={range} onChange={(e) => setRange(e.target.value as any)}>
              <option value="7d">7 ngày qua</option>
              <option value="30d">30 ngày qua</option>
              <option value="all">Tất cả</option>
            </select>
          </div>
        </div>

        <div className="admin-reviews-filters-right">
          <div className="admin-reviews-search">
            <input value={q} onChange={(e) => setQ(e.target.value)} placeholder="Tìm theo sản phẩm, user, email, nội dung…" />
            <button
              type="button"
              className="btn-primary"
              onClick={() => {
                setSkip(0);
                void load({ q, skip: 0 });
              }}
              disabled={loading}
            >
              Tìm
            </button>
          </div>
          {/* <div className="admin-reviews-meta">
            Hiển thị {displayStart}-{displayEnd} trên {formatCompact(data.total || 0)} đánh giá
          </div> */}
        </div>
      </div>

      {error ? <div className="admin-alert admin-alert--error" style={{ marginTop: '1rem' }}>{error}</div> : null}

      <div className="admin-reviews-list">
        {loading ? (
          <div className="empty-state" style={{ padding: '2rem 1rem' }}>Đang tải…</div>
        ) : visibleItems.length === 0 ? (
          <div className="empty-state" style={{ padding: '2rem 1rem' }}>Không có đánh giá.</div>
        ) : (
          visibleItems.map((r) => (
            <div
              key={r.reviewID}
              className={`admin-review-card status-${String(r.moderationStatus || '').toLowerCase()}`}
            >
              <div className="admin-review-left">
                <div className="admin-review-user">
                  <div className="admin-review-avatar" aria-hidden>
                    {r.userAvatarUrl ? (
                      <img src={resolveMediaUrl(r.userAvatarUrl)} alt="" />
                    ) : (
                      String(r.userName || '?').trim().slice(0, 1).toUpperCase()
                    )}
                  </div>
                  <div className="admin-review-user-meta">
                    <div className="admin-review-user-name">{r.userName}</div>
                    <div className="admin-review-user-sub">Khách hàng</div>
                  </div>
                </div>

                <div className="admin-review-product">
                  <div className="admin-review-product-row">
                    <div className="admin-review-product-thumb" aria-hidden>
                      {r.productThumbUrl ? <img src={resolveMediaUrl(r.productThumbUrl)} alt="" /> : <div className="admin-review-product-thumb--ph" />}
                    </div>
                    <div className="admin-review-product-meta">
                      <div className="admin-review-product-title">{r.productName}</div>
                      <div className="admin-review-product-sub">
                        ID : <strong>#{(r.productSku && r.productSku.trim().length > 0) ? r.productSku.trim() : r.productID}</strong> •{' '}
                        <Link to={`/product/${r.productToken || r.productID}`} target="_blank" rel="noreferrer" style={{ color: 'var(--primary)', textDecoration: 'none' }}>Xem</Link>
                      </div>
                    </div>
                  </div>
                </div>
              </div>

              <div className="admin-review-mid">
                <div className="admin-review-topline">
                  <div className="admin-review-stars" aria-label={`${r.rating} sao`}>
                    {'★★★★★'.slice(0, Math.max(0, Math.min(5, r.rating)))}{'☆☆☆☆☆'.slice(0, Math.max(0, 5 - Math.max(0, Math.min(5, r.rating))))}
                  </div>
                  <div className="admin-review-time">{timeAgo(r.reviewDate)}</div>
                  <div className={`admin-review-pill ${String(r.moderationStatus || '').toLowerCase()}`}>
                    {String(r.moderationStatus || '').toLowerCase() === 'pending' ? 'CHỜ DUYỆT' : String(r.moderationStatus || '').toUpperCase()}
                  </div>
                </div>

                <div className="admin-review-comment">
                  {r.comment ? r.comment : <em style={{ opacity: 0.7 }}>(Không có nội dung)</em>}
                </div>

                {r.imageUrls && r.imageUrls.length > 0 ? (
                  <div className="admin-review-images">
                    {r.imageUrls.slice(0, 3).map((u, idx) => (
                      <a key={idx} href={resolveMediaUrl(u)} target="_blank" rel="noreferrer">
                        <img src={resolveMediaUrl(u)} alt="" />
                      </a>
                    ))}
                  </div>
                ) : null}

                {r.moderationNote ? (
                  <div className="admin-review-note">
                    <strong>Ghi chú admin:</strong> {r.moderationNote}
                  </div>
                ) : null}

                {r.adminReply ? (
                  <div className="admin-review-reply">
                    <div className="admin-review-reply-head">FRESHFOOD ADMIN PHẢN HỒI</div>
                    <div className="admin-review-reply-body">“{r.adminReply}”</div>
                  </div>
                ) : null}
              </div>

              <div className="admin-review-actions">
                {tab === 'deleted' || r.isDeleted ? (
                  <>
                    <button type="button" className="admin-review-btn admin-review-btn--approve" onClick={() => void doRestore(r)}>
                      Khôi phục
                    </button>
                  </>
                ) : String(r.moderationStatus || '').toLowerCase() === 'approved' ? (
                  <>
                    <button type="button" className="admin-review-btn admin-review-btn--muted" onClick={() => void doReply(r)}>
                      Sửa phản hồi
                    </button>
                    <button type="button" className="admin-review-btn admin-review-btn--ghost" onClick={() => void doHide(r)}>
                      Ẩn
                    </button>
                    <button type="button" className="admin-review-btn admin-review-btn--danger" onClick={() => void doDelete(r)}>
                      Xóa
                    </button>
                  </>
                ) : String(r.moderationStatus || '').toLowerCase() === 'pending' ? (
                  <>
                    <button type="button" className="admin-review-btn admin-review-btn--approve" onClick={() => void doApprove(r)}>
                      Duyệt
                    </button>
                    <button type="button" className="admin-review-btn admin-review-btn--muted" onClick={() => void doReply(r)}>
                      Phản hồi
                    </button>
                    <button type="button" className="admin-review-btn admin-review-btn--ghost" onClick={() => void doHide(r)}>
                      Ẩn
                    </button>
                    <button type="button" className="admin-review-btn admin-review-btn--danger" onClick={() => void doDelete(r)}>
                      Xóa
                    </button>
                  </>
                ) : (
                  <>
                    <button type="button" className="admin-review-btn admin-review-btn--approve" onClick={() => void doApprove(r)}>
                      Hiện
                    </button>
                    <button type="button" className="admin-review-btn admin-review-btn--danger" onClick={() => void doDelete(r)}>
                      Xóa
                    </button>
                  </>
                )}
              </div>
            </div>
          ))
        )}
      </div>

      <div className="admin-reviews-pager">
        <div className="admin-reviews-pager-left">
          HIỂN THỊ <strong>{displayStart}</strong>–<strong>{displayEnd}</strong> TRÊN <strong>{formatCompact(data.total || 0)}</strong> ĐÁNH GIÁ
        </div>
        <div className="admin-reviews-pager-right">
          <div className="admin-reviews-pages" aria-label="Phân trang">
            <button
              type="button"
              className="admin-reviews-nav"
              onClick={() => goToPage(page - 1)}
              disabled={!hasPrev || loading}
              aria-label="Trang trước"
              title="Trang trước"
            >
              ‹
            </button>

            {pageNumbers.map((p) => (
              <button
                key={p}
                type="button"
                className={`admin-reviews-page${p === page ? ' active' : ''}`}
                onClick={() => goToPage(p)}
                disabled={loading}
              >
                {p}
              </button>
            ))}

            {pageNumbers[pageNumbers.length - 1] < totalPages ? (
              <>
                {pageNumbers[pageNumbers.length - 1] < totalPages - 1 ? <span className="admin-reviews-ellipsis">…</span> : null}
                <button type="button" className="admin-reviews-page" onClick={() => goToPage(totalPages)} disabled={loading}>
                  {totalPages}
                </button>
              </>
            ) : null}

            <button
              type="button"
              className="admin-reviews-nav"
              onClick={() => goToPage(page + 1)}
              disabled={!hasNext || loading}
              aria-label="Trang sau"
              title="Trang sau"
            >
              ›
            </button>
          </div>
        </div>
      </div>
    </div>
  );
}

