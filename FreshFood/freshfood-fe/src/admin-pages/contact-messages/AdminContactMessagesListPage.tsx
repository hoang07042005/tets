import { useCallback, useEffect, useMemo, useState } from 'react';
import { ChevronLeft, ChevronRight, Filter, Mail, MessageSquare, RefreshCw, Search, X } from 'lucide-react';
import { apiService } from '../../services/api';
import type { AdminContactMessageDetail, AdminContactMessageRow, AdminContactMessagesPage } from '../../types';

const PAGE_SIZE = 12;

type TabKey = 'all' | 'new' | 'processing' | 'replied';

function formatDateTime(iso?: string | null): string {
  if (!iso) return '—';
  const d = new Date(iso);
  if (Number.isNaN(d.getTime())) return '—';
  return d.toLocaleString('vi-VN', {
    day: '2-digit',
    month: '2-digit',
    year: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
  });
}

/** Thời gian hiển thị kiểu inbox (Hôm qua, 2 ngày trước, giờ hôm nay). */
function formatRelativeInbox(iso?: string | null): string {
  if (!iso) return '—';
  const d = new Date(iso);
  if (Number.isNaN(d.getTime())) return '—';
  const now = new Date();
  const startToday = new Date(now.getFullYear(), now.getMonth(), now.getDate());
  const startMsg = new Date(d.getFullYear(), d.getMonth(), d.getDate());
  const diffDays = Math.round((startToday.getTime() - startMsg.getTime()) / 86400000);
  if (diffDays === 0) {
    return d.toLocaleTimeString('vi-VN', { hour: '2-digit', minute: '2-digit' });
  }
  if (diffDays === 1) return 'Hôm qua';
  if (diffDays >= 2 && diffDays < 7) return `${diffDays} ngày trước`;
  return d.toLocaleDateString('vi-VN', { day: '2-digit', month: '2-digit' });
}

function initialsFromName(name: string): string {
  const p = name.trim().split(/\s+/).filter(Boolean);
  if (p.length === 0) return '?';
  if (p.length === 1) return p[0].slice(0, 2).toUpperCase();
  return (p[0][0] + p[p.length - 1][0]).toUpperCase();
}

const AVATAR_BG = ['#dcfce7', '#ffedd5', '#dbeafe', '#f3e8ff', '#fef3c7', '#e0f2fe'];

function avatarColor(name: string): string {
  let h = 0;
  for (let i = 0; i < name.length; i++) h = (h + name.charCodeAt(i) * (i + 1)) % AVATAR_BG.length;
  return AVATAR_BG[h];
}

function normalizeStatus(s?: string): 'New' | 'Processing' | 'Replied' {
  const x = (s || 'New').trim();
  if (x === 'Processing') return 'Processing';
  if (x === 'Replied') return 'Replied';
  return 'New';
}

function statusPill(status: string): { label: string; className: string } {
  const n = normalizeStatus(status);
  if (n === 'Processing') return { label: 'ĐANG XỬ LÝ', className: 'cm2-pill cm2-pill--proc' };
  if (n === 'Replied') return { label: 'ĐÃ TRẢ LỜI', className: 'cm2-pill cm2-pill--done' };
  return { label: 'MỚI', className: 'cm2-pill cm2-pill--new' };
}

function visiblePageNumbers(current: number, total: number): (number | '…')[] {
  if (total <= 7) return Array.from({ length: total }, (_, i) => i + 1);
  const set = new Set<number>([1, total, current - 1, current, current + 1]);
  for (const p of [...set]) {
    if (p < 1 || p > total) set.delete(p);
  }
  const sorted = [...set].sort((a, b) => a - b);
  const out: (number | '…')[] = [];
  for (let i = 0; i < sorted.length; i++) {
    const n = sorted[i];
    if (i > 0 && n - sorted[i - 1] > 1) out.push('…');
    out.push(n);
  }
  return out;
}

export function AdminContactMessagesListPage() {
  const [page, setPage] = useState(1);
  const [q, setQ] = useState('');
  const [tab, setTab] = useState<TabKey>('all');
  const [showFilters, setShowFilters] = useState(false);
  const [data, setData] = useState<AdminContactMessagesPage | null>(null);
  const [loading, setLoading] = useState(true);
  const [err, setErr] = useState<string | null>(null);
  const [refresh, setRefresh] = useState(0);
  const [detailId, setDetailId] = useState<number | null>(null);
  const [detail, setDetail] = useState<AdminContactMessageDetail | null>(null);
  const [detailLoading, setDetailLoading] = useState(false);
  const [replySubject, setReplySubject] = useState('');
  const [replyMessage, setReplyMessage] = useState('');
  const [includeOriginal, setIncludeOriginal] = useState(true);
  const [sendLoading, setSendLoading] = useState(false);
  const [sendErr, setSendErr] = useState<string | null>(null);
  const [sendOk, setSendOk] = useState<string | null>(null);
  const [statusSaving, setStatusSaving] = useState(false);

  const statusParam = useMemo(() => {
    if (tab === 'all') return 'all' as const;
    if (tab === 'new') return 'new' as const;
    if (tab === 'processing') return 'processing' as const;
    return 'replied' as const;
  }, [tab]);

  const load = useCallback(async () => {
    setLoading(true);
    setErr(null);
    try {
      const res = await apiService.getAdminContactMessagesPage({
        page,
        pageSize: PAGE_SIZE,
        q: q.trim() || undefined,
        status: statusParam,
      });
      setData(res);
    } catch (e: unknown) {
      setErr(e instanceof Error ? e.message : 'Không tải được dữ liệu.');
      setData(null);
    } finally {
      setLoading(false);
    }
  }, [page, q, refresh, statusParam]);

  useEffect(() => {
    load();
  }, [load]);

  const items = data?.items ?? [];
  const total = data?.totalCount ?? 0;
  const pageCount = Math.max(1, Math.ceil(total / PAGE_SIZE));
  const safePage = Math.min(page, pageCount);

  useEffect(() => {
    if (page > pageCount) setPage(pageCount);
  }, [page, pageCount]);

  useEffect(() => {
    if (detailId == null) {
      setDetail(null);
      setReplySubject('');
      setReplyMessage('');
      setIncludeOriginal(true);
      setSendErr(null);
      setSendOk(null);
      return;
    }
    let cancelled = false;
    setDetailLoading(true);
    (async () => {
      const d = await apiService.getAdminContactMessage(detailId);
      if (!cancelled) {
        setDetail(d);
        setDetailLoading(false);
      }
    })();
    return () => {
      cancelled = true;
    };
  }, [detailId]);

  useEffect(() => {
    if (!detail) return;
    setReplySubject(`Re: ${detail.subject || ''}`.trim());
    setReplyMessage('');
    setIncludeOriginal(true);
    setSendErr(null);
    setSendOk(null);
  }, [detail?.contactMessageID]);

  const pageLabelFooter = useMemo(() => {
    const n = items.length;
    if (total === 0) return `Hiển thị 0 trên ${total} tin nhắn`;
    const start = (safePage - 1) * PAGE_SIZE;
    return `Hiển thị ${n} trên ${total.toLocaleString('vi-VN')} tin nhắn`;
  }, [safePage, items.length, total]);

  useEffect(() => {
    if (detailId == null) return;
    const onKeyDown = (e: KeyboardEvent) => {
      if (e.key === 'Escape') closeDetail();
    };
    window.addEventListener('keydown', onKeyDown);
    return () => window.removeEventListener('keydown', onKeyDown);
  }, [detailId]);

  const openDetail = (row: AdminContactMessageRow) => {
    setDetailId(row.contactMessageID);
    setDetail(null);
  };

  const closeDetail = () => {
    setDetailId(null);
    setDetail(null);
  };

  const markProcessing = async () => {
    if (detailId == null) return;
    setStatusSaving(true);
    try {
      await apiService.adminPatchContactMessageStatus(detailId, 'Processing');
      setRefresh((x) => x + 1);
      const d = await apiService.getAdminContactMessage(detailId);
      setDetail(d);
    } catch (e: unknown) {
      setSendErr(e instanceof Error ? e.message : 'Không cập nhật được trạng thái.');
    } finally {
      setStatusSaving(false);
    }
  };

  const sendReply = async () => {
    if (detailId == null) return;
    const subj = replySubject.trim();
    const msg = replyMessage.trim();
    setSendErr(null);
    setSendOk(null);
    if (!subj) {
      setSendErr('Vui lòng nhập tiêu đề email.');
      return;
    }
    if (msg.length < 2) {
      setSendErr('Vui lòng nhập nội dung phản hồi (ít nhất 2 ký tự).');
      return;
    }
    setSendLoading(true);
    try {
      await apiService.adminReplyContactMessage(detailId, { subject: subj, message: msg, includeOriginal });
      setSendOk('Đã gửi email phản hồi thành công.');
      setReplyMessage('');
      setRefresh((x) => x + 1);
      const d = await apiService.getAdminContactMessage(detailId);
      setDetail(d);
    } catch (e: unknown) {
      setSendErr(e instanceof Error ? e.message : 'Gửi email thất bại.');
    } finally {
      setSendLoading(false);
    }
  };

  const tabs: { key: TabKey; label: string }[] = [
    { key: 'all', label: 'Tất cả' },
    { key: 'new', label: 'Mới' },
    { key: 'processing', label: 'Đang xử lý' },
    { key: 'replied', label: 'Đã trả lời' },
  ];

  const pageButtons = useMemo(() => visiblePageNumbers(safePage, pageCount), [safePage, pageCount]);

  return (
    <div className="cm2-page">
      <header className="cm2-page-head">
        <div>
          <h1 className="cm2-title">Tin liên hệ</h1>
          <p className="cm2-sub muted">Quản lý tin nhắn từ form Liên hệ công khai.</p>
        </div>
        <button type="button" className="cm2-icon-btn" onClick={() => setRefresh((x) => x + 1)} title="Làm mới">
          <RefreshCw size={18} aria-hidden />
        </button>
      </header>

      <div className="cm2-toolbar">
        <div className="cm2-tabs" role="tablist" aria-label="Lọc theo trạng thái">
          {tabs.map((t) => (
            <button
              key={t.key}
              type="button"
              role="tab"
              aria-selected={tab === t.key}
              className={`cm2-tab ${tab === t.key ? 'cm2-tab--active' : ''}`}
              onClick={() => {
                setTab(t.key);
                setPage(1);
              }}
            >
              {t.label}
            </button>
          ))}
        </div>
        <button
          type="button"
          className={`cm2-filter-btn ${showFilters ? 'cm2-filter-btn--on' : ''}`}
          onClick={() => setShowFilters((v) => !v)}
          aria-expanded={showFilters}
        >
          <Filter size={18} aria-hidden />
          Bộ lọc
        </button>
      </div>

      {showFilters ? (
        <div className="cm2-filter-panel">
          <div className="cm2-search">
            <Search size={16} className="cm2-search-ico" aria-hidden />
            <input
              className="cm2-search-input"
              placeholder="Tìm theo tên, email, chủ đề, nội dung…"
              value={q}
              onChange={(e) => {
                setQ(e.target.value);
                setPage(1);
              }}
            />
            {q.trim() ? (
              <button type="button" className="cm2-search-clear" onClick={() => setQ('')} aria-label="Xoá từ khoá">
                <X size={16} />
              </button>
            ) : null}
          </div>
        </div>
      ) : null}

      {err ? <div className="admin-alert admin-alert--danger cm2-alert">{err}</div> : null}

      <div className="cm2-card">
        {loading ? (
          <div className="cm2-loading muted">Đang tải…</div>
        ) : items.length === 0 ? (
          <div className="cm2-empty muted">
            <MessageSquare size={22} aria-hidden />
            <span>Chưa có tin nhắn nào{q.trim() ? ' khớp bộ lọc' : ''}.</span>
          </div>
        ) : (
          <ul className="cm2-list">
            {items.map((row) => {
              const st = normalizeStatus(row.status);
              const pill = statusPill(row.status);
              const snippetItalic = st === 'Replied';
              return (
                <li key={row.contactMessageID} className="cm2-row">
                  <button type="button" className="cm2-row-main" onClick={() => openDetail(row)}>
                    <span className="cm2-avatar" style={{ background: avatarColor(row.name) }}>
                      {initialsFromName(row.name)}
                    </span>
                    <span className="cm2-row-body">
                      <span className="cm2-row-name">{row.name}</span>
                      <span className="cm2-row-email">{row.email}</span>
                      <span className={`cm2-row-snippet ${snippetItalic ? 'cm2-row-snippet--italic' : ''}`}>
                        {row.messagePreview || row.subject || '—'}
                      </span>
                    </span>
                    <span className="cm2-row-aside">
                      <span className="cm2-row-time">{formatRelativeInbox(row.createdAt)}</span>
                      <span className="cm2-pills">
                        {row.isUrgent ? <span className="cm2-pill cm2-pill--urgent">KHẨN CẤP</span> : null}
                        <span className={pill.className}>{pill.label}</span>
                      </span>
                    </span>
                  </button>
                </li>
              );
            })}
          </ul>
        )}

        {!loading && items.length > 0 ? (
          <footer className="cm2-footer">
            <span className="cm2-footer-count muted">{pageLabelFooter}</span>
            <nav className="cm2-pager" aria-label="Phân trang">
              <button
                type="button"
                className="cm2-page-arrow"
                disabled={safePage <= 1}
                onClick={() => setPage((p) => Math.max(1, p - 1))}
                aria-label="Trang trước"
              >
                <ChevronLeft size={18} />
              </button>
              {pageButtons.map((p, i) =>
                p === '…' ? (
                  <span key={`e-${i}`} className="cm2-page-ellipsis">
                    …
                  </span>
                ) : (
                  <button
                    key={p}
                    type="button"
                    className={`cm2-page-num ${p === safePage ? 'cm2-page-num--active' : ''}`}
                    onClick={() => setPage(p)}
                  >
                    {p}
                  </button>
                ),
              )}
              <button
                type="button"
                className="cm2-page-arrow"
                disabled={safePage >= pageCount}
                onClick={() => setPage((p) => Math.min(pageCount, p + 1))}
                aria-label="Trang sau"
              >
                <ChevronRight size={18} />
              </button>
            </nav>
          </footer>
        ) : null}
      </div>

      {detailId != null ? (
        <div className="rrg-modal cm-drawer" role="dialog" aria-modal="true" aria-labelledby="contact-msg-detail-title">
          <div className="rrg-backdrop" role="presentation" onClick={closeDetail} />
          <div className="rrg-panel cm-drawer-panel">
            <div className="rrg-top">
              <h2 id="contact-msg-detail-title" className="rrg-title">
                Chi tiết tin #{detailId}
              </h2>
              <button type="button" className="rrg-close" onClick={closeDetail} aria-label="Đóng">
                <X size={18} />
              </button>
            </div>
            {detailLoading ? (
              <p className="muted">Đang tải…</p>
            ) : !detail ? (
              <p className="muted">Không tải được tin này.</p>
            ) : (
              <div className="cm-detail">
                <div className="cm2-drawer-actions">
                  {normalizeStatus(detail.status) !== 'Replied' && normalizeStatus(detail.status) !== 'Processing' ? (
                    <button type="button" className="ord-admin-btn ord-admin-btn--primary" onClick={markProcessing} disabled={statusSaving}>
                      {statusSaving ? 'Đang lưu…' : 'Đánh dấu đang xử lý'}
                    </button>
                  ) : null}
                </div>
                <div className="cm-detail-row">
                  <div className="cm-detail-label">Thời gian</div>
                  <div className="cm-detail-value">{formatDateTime(detail.createdAt)}</div>
                </div>
                <div className="cm-detail-row">
                  <div className="cm-detail-label">Người gửi</div>
                  <div className="cm-detail-value">{detail.name}</div>
                </div>
                <div className="cm-detail-row">
                  <div className="cm-detail-label">Email</div>
                  <a className="cm-detail-mail" href={`mailto:${detail.email}?subject=${encodeURIComponent('Re: ' + detail.subject)}`}>
                    <Mail size={16} aria-hidden />
                    {detail.email}
                  </a>
                </div>
                <div className="cm-detail-row">
                  <div className="cm-detail-label">Chủ đề</div>
                  <div className="cm-detail-value">{detail.subject}</div>
                </div>
                <div className="cm-detail-row">
                  <div className="cm-detail-label">Nội dung</div>
                  <div className="cm-detail-message">{detail.message}</div>
                </div>

                <div className="cm-reply">
                  <div className="cm-reply-title">Trả lời ngay trong admin</div>
                  {sendErr ? <div className="admin-alert admin-alert--danger">{sendErr}</div> : null}
                  {sendOk ? <div className="admin-alert admin-alert--success">{sendOk}</div> : null}

                  <label className="cm-field">
                    <span className="cm-field-label">Tiêu đề</span>
                    <input
                      className="cm-input"
                      value={replySubject}
                      onChange={(e) => setReplySubject(e.target.value)}
                      placeholder="Re: ..."
                    />
                  </label>

                  <label className="cm-field">
                    <span className="cm-field-label">Nội dung phản hồi</span>
                    <textarea
                      className="cm-textarea"
                      value={replyMessage}
                      onChange={(e) => setReplyMessage(e.target.value)}
                      placeholder="Nhập nội dung email..."
                      rows={7}
                    />
                  </label>

                  <label className="cm-check">
                    <input type="checkbox" checked={includeOriginal} onChange={(e) => setIncludeOriginal(e.target.checked)} />
                    <span>Đính kèm tin nhắn gốc ở cuối email</span>
                  </label>

                  <div className="cm-reply-actions">
                    <button type="button" className="ord-admin-btn" onClick={() => setReplyMessage('')} disabled={sendLoading || !replyMessage.trim()}>
                      Xoá nội dung
                    </button>
                    <button type="button" className="ord-admin-btn ord-admin-btn--primary" onClick={sendReply} disabled={sendLoading}>
                      {sendLoading ? 'Đang gửi…' : 'Gửi email'}
                    </button>
                  </div>
                </div>
              </div>
            )}
          </div>
        </div>
      ) : null}
    </div>
  );
}
