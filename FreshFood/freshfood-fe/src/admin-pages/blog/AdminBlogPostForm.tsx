import { useEffect, useMemo, useRef, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { ImagePlus } from 'lucide-react';
import { apiService, resolveMediaUrl } from '../../services/api';
import type { BlogPost } from '../../types';

function sanitizeBlogHtml(input: string): string {
  const raw = (input || '').trim();
  if (!raw) return '';
  // Basic hardening: remove script/style blocks + inline event handlers.
  return raw
    .replace(/<\s*(script|style)[^>]*>[\s\S]*?<\s*\/\s*\1\s*>/gi, '')
    .replace(/\son\w+\s*=\s*(".*?"|'.*?'|[^\s>]+)/gi, '');
}

function toInputDateTimeLocal(iso?: string | null): string {
  if (!iso) return '';
  const d = new Date(iso);
  if (Number.isNaN(d.getTime())) return '';
  const pad = (n: number) => String(n).padStart(2, '0');
  const yyyy = d.getFullYear();
  const mm = pad(d.getMonth() + 1);
  const dd = pad(d.getDate());
  const hh = pad(d.getHours());
  const mi = pad(d.getMinutes());
  return `${yyyy}-${mm}-${dd}T${hh}:${mi}`;
}

function fromInputDateTimeLocal(v: string): string | null {
  const s = (v || '').trim();
  if (!s) return null;
  const d = new Date(s);
  if (Number.isNaN(d.getTime())) return null;
  return d.toISOString();
}

function slugify(input: string): string {
  const s = (input || '')
    .trim()
    .toLowerCase()
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '') // remove accents
    .replace(/đ/g, 'd')
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/(^-|-$)/g, '');
  return s || 'bai-viet';
}

type Props = {
  mode: 'create' | 'edit';
  initial?: BlogPost | null;
  blogPostId?: number;
};

export function AdminBlogPostForm({ mode, initial, blogPostId }: Props) {
  const navigate = useNavigate();
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const fileRef = useRef<HTMLInputElement | null>(null);
  const editorRef = useRef<HTMLDivElement | null>(null);

  const [title, setTitle] = useState(initial?.title || '');
  const [slug, setSlug] = useState(initial?.slug || '');
  const [excerpt, setExcerpt] = useState(initial?.excerpt || '');
  const [coverImageUrl, setCoverImageUrl] = useState(initial?.coverImageUrl || '');
  const [removeCover, setRemoveCover] = useState(false);
  const [coverFile, setCoverFile] = useState<File | null>(null);
  const [coverPreviewUrl, setCoverPreviewUrl] = useState<string>('');
  const [coverUploading, setCoverUploading] = useState(false);

  const [isPublished, setIsPublished] = useState(Boolean(initial?.isPublished ?? (initial as any)?.isPublished ?? true));
  const [publishedAt, setPublishedAt] = useState<string>(toInputDateTimeLocal((initial as any)?.publishedAt || null));
  const [content, setContent] = useState((initial as any)?.content || '');

  const canAutoSlug = useMemo(() => mode === 'create' && !slug.trim(), [mode, slug]);

  const existingCoverResolved = useMemo(() => resolveMediaUrl(removeCover ? '' : coverImageUrl), [coverImageUrl, removeCover]);

  useEffect(() => {
    if (!canAutoSlug) return;
    if (!title.trim()) return;
    setSlug(slugify(title));
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [title]);

  useEffect(() => {
    if (!coverFile) {
      setCoverPreviewUrl('');
      return;
    }
    const url = URL.createObjectURL(coverFile);
    setCoverPreviewUrl(url);
    return () => URL.revokeObjectURL(url);
  }, [coverFile]);

  const pickFile = () => fileRef.current?.click();

  const clearPickedFile = () => {
    setCoverFile(null);
    if (fileRef.current) fileRef.current.value = '';
  };

  useEffect(() => {
    // When editing / switching initial data, make sure editor HTML matches state.
    if (!editorRef.current) return;
    const desired = content || '';
    if (editorRef.current.innerHTML !== desired) editorRef.current.innerHTML = desired;
  }, [initial?.blogPostID, mode]);

  const onSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError(null);

    let nextCoverUrl: string | null = removeCover ? null : (coverImageUrl.trim() ? coverImageUrl.trim() : null);

    if (coverFile) {
      setCoverUploading(true);
      try {
        const res = await apiService.adminUploadBlogCover(coverFile);
        if (!res?.coverImageUrl) {
          setError('Upload ảnh thất bại.');
          return;
        }
        nextCoverUrl = res.coverImageUrl;
      } catch (err: any) {
        setError(err?.message || 'Upload ảnh thất bại.');
        return;
      } finally {
        setCoverUploading(false);
      }
    }

    const payload = {
      title: title.trim(),
      slug: slug.trim(),
      excerpt: excerpt.trim() ? excerpt.trim() : null,
      content: sanitizeBlogHtml(content),
      coverImageUrl: nextCoverUrl,
      isPublished,
      publishedAt: publishedAt.trim() ? fromInputDateTimeLocal(publishedAt) : null,
    };

    if (!payload.title) return setError('Vui lòng nhập tiêu đề.');
    if (!payload.slug) return setError('Vui lòng nhập slug.');
    if (!payload.content) return setError('Vui lòng nhập nội dung.');

    setSubmitting(true);
    try {
      const res =
        mode === 'create'
          ? await apiService.adminCreateBlogPost(payload)
          : await apiService.adminUpdateBlogPost(blogPostId as number, payload);

      if (!res) {
        setError('Lưu thất bại. Có thể slug bị trùng hoặc dữ liệu không hợp lệ.');
        return;
      }

      navigate('/admin/blog');
    } catch (err: any) {
      setError(err?.message || 'Lưu thất bại.');
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <form className="prod-edit blog-post-form" onSubmit={onSubmit}>
      {error ? (
        <div className="admin-alert admin-alert--danger blog-post-form__banner">{error}</div>
      ) : null}

      <div className="prod-edit-grid">
        <div className="prod-edit-left">
          <section className="prod-card">
            <div className="prod-card-title">Thông tin bài viết</div>
            <div className="prod-card-body blog-post-form__stack">
              <div>
                <label className="prod-admin-label" htmlFor="blog-title">
                  Tiêu đề
                </label>
                <input
                  id="blog-title"
                  className="prod-admin-input"
                  value={title}
                  onChange={(e) => setTitle(e.target.value)}
                  placeholder="Nhập tiêu đề bài viết"
                />
              </div>
              <div>
                <label className="prod-admin-label" htmlFor="blog-slug">
                  Slug (URL)
                </label>
                <input
                  id="blog-slug"
                  className="prod-admin-input"
                  value={slug}
                  onChange={(e) => setSlug(e.target.value)}
                  placeholder="vd: meo-chon-rau-cu"
                />
                {canAutoSlug ? <p className="blog-post-form__hint">Slug tự cập nhật theo tiêu đề. Chỉnh tay nếu cần.</p> : null}
              </div>
            </div>
          </section>

          <section className="prod-card">
            <div className="prod-card-title">Nội dung</div>
            <div className="prod-card-body blog-post-form__stack">
              <div>
                <label className="prod-admin-label" htmlFor="blog-excerpt">
                  Mô tả ngắn
                </label>
                <textarea
                  id="blog-excerpt"
                  className="prod-admin-input prod-admin-textarea"
                  value={excerpt}
                  onChange={(e) => setExcerpt(e.target.value)}
                  placeholder="Tóm tắt hiển thị ở danh sách blog"
                  rows={3}
                />
              </div>
              <div>
                <label className="prod-admin-label" htmlFor="blog-content-editor">
                  Nội dung bài viết
                </label>
                <div
                  id="blog-content-editor"
                  ref={editorRef}
                  className="blog-post-form__editor"
                  contentEditable={!submitting && !coverUploading}
                  suppressContentEditableWarning
                  data-placeholder="Dán nội dung ở đây (có thể dán kèm ảnh)."
                  onInput={(e) => {
                    const html = (e.currentTarget as HTMLDivElement).innerHTML;
                    setContent(html);
                  }}
                />
                <p className="blog-post-form__hint">
                  Bạn có thể copy/dán nội dung có ảnh (clipboard) vào đây. Khi lưu, nội dung được lưu dạng HTML và trang chi tiết sẽ hiển thị kèm ảnh.
                </p>
              </div>
            </div>
          </section>
        </div>

        <aside className="prod-edit-right">
          <section className="prod-card">
            <div className="prod-card-title">Ảnh cover</div>
            <div className="prod-card-body blog-post-form__stack">
              <input
                ref={fileRef}
                type="file"
                accept="image/*"
                className="prod-admin-file"
                onChange={(e) => {
                  const f = e.target.files?.[0] || null;
                  setRemoveCover(false);
                  setCoverFile(f);
                }}
              />

              <div
                className="blog-post-form__cover-drop"
                onClick={pickFile}
                onKeyDown={(e) => {
                  if (e.key === 'Enter' || e.key === ' ') {
                    e.preventDefault();
                    pickFile();
                  }
                }}
                role="button"
                tabIndex={0}
              >
                <div className="blog-post-form__cover-preview" aria-label="Xem trước ảnh cover">
                  {coverPreviewUrl ? (
                    <img src={coverPreviewUrl} alt="" />
                  ) : existingCoverResolved ? (
                    <img src={existingCoverResolved} alt="" />
                  ) : (
                    <div className="blog-post-form__cover-empty">
                      <span className="blog-post-form__cover-ico" aria-hidden>
                        <ImagePlus size={22} />
                      </span>
                      <span className="blog-post-form__cover-empty-title">Chọn ảnh đại diện</span>
                      <span className="blog-post-form__cover-empty-sub">PNG, JPG — bấm hoặc dùng nút bên dưới</span>
                    </div>
                  )}
                </div>
              </div>

              <div className="blog-post-form__cover-actions">
                <button type="button" className="prod-admin-btn-ghost" onClick={pickFile} disabled={submitting || coverUploading}>
                  Chọn ảnh
                </button>
                {coverFile ? (
                  <button type="button" className="prod-admin-btn-ghost" onClick={clearPickedFile} disabled={submitting || coverUploading}>
                    Bỏ file đang chọn
                  </button>
                ) : null}
              </div>

              {coverImageUrl && !coverFile ? (
                <label className="blog-post-form__remove-cover">
                  <input
                    type="checkbox"
                    checked={removeCover}
                    onChange={(e) => setRemoveCover(e.target.checked)}
                    disabled={submitting || coverUploading}
                  />
                  <span>Xóa ảnh cover hiện tại khi lưu</span>
                </label>
              ) : null}

              <p className="blog-post-form__hint">Ảnh được upload khi bạn bấm lưu bài viết.</p>
            </div>
          </section>

          <section className="prod-card">
            <div className="prod-card-title">Xuất bản</div>
            <div className="prod-card-body blog-post-form__stack">
              <div>
                <label className="prod-admin-label" htmlFor="blog-status">
                  Trạng thái
                </label>
                <select
                  id="blog-status"
                  className="prod-admin-input prod-admin-select"
                  value={isPublished ? 'published' : 'draft'}
                  onChange={(e) => setIsPublished(e.target.value === 'published')}
                >
                  <option value="published">Đã đăng</option>
                  <option value="draft">Bản nháp</option>
                </select>
              </div>
              <div>
                <label className="prod-admin-label" htmlFor="blog-published-at">
                  Ngày giờ đăng
                </label>
                <input
                  id="blog-published-at"
                  className="prod-admin-input"
                  type="datetime-local"
                  value={publishedAt}
                  onChange={(e) => setPublishedAt(e.target.value)}
                />
              </div>
            </div>
          </section>
        </aside>
      </div>

      <div className="prod-edit-actions blog-post-form__actions">
        <button type="button" className="prod-admin-btn-ghost" onClick={() => navigate('/admin/blog')} disabled={submitting}>
          Hủy
        </button>
        <button type="submit" className="prod-admin-btn-primary" disabled={submitting || coverUploading}>
          {submitting || coverUploading ? 'Đang lưu…' : mode === 'create' ? 'Tạo bài viết' : 'Lưu thay đổi'}
        </button>
      </div>
    </form>
  );
}

