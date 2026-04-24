import { useEffect, useMemo, useRef, useState } from 'react';
import { Link, useNavigate, useParams } from 'react-router-dom';
import { Eye } from 'lucide-react';
import { apiService, resolveMediaUrl } from '../../services/api';
import type { BlogComment, BlogPost } from '../../types';
import { useAuth } from '../../context/AuthContext';

function stripHtml(html: string): string {
  return html.replace(/<[^>]*>/g, ' ').replace(/\s+/g, ' ').trim();
}

function looksLikeHtml(input: string): boolean {
  const s = (input || '').trim();
  if (!s) return false;
  return /<\/?[a-z][\s\S]*>/i.test(s);
}

function hashString(s: string): number {
  let h = 0;
  for (let i = 0; i < s.length; i++) h = (Math.imul(31, h) + s.charCodeAt(i)) | 0;
  return Math.abs(h);
}

function displayViews(p: BlogPost): number {
  const v = Number((p as any)?.viewCount);
  if (Number.isFinite(v) && v >= 0) return v;
  // Fallback for older backend responses
  return (hashString(p.slug) % 9000) + 1200;
}

function postCategory(slug: string): 'knowledge' | 'recipe' | 'farm' | 'lifestyle' {
  const keys = ['knowledge', 'recipe', 'farm', 'lifestyle'] as const;
  return keys[hashString(slug) % keys.length];
}

function categoryLabel(id: ReturnType<typeof postCategory>): string {
  if (id === 'knowledge') return 'Kiến thức';
  if (id === 'recipe') return 'Công thức';
  if (id === 'farm') return 'Chuyện nông trại';
  return 'Lối sống';
}

function timeAgoVi(iso: string): string {
  const s = (iso || '').trim();
  // If backend returns no timezone (e.g. "2026-04-10T10:46:00"), treat it as UTC.
  const d = new Date(/[zZ]|[+-]\d{2}:\d{2}$/.test(s) ? s : `${s}Z`);
  if (Number.isNaN(d.getTime())) return '';
  const sec = Math.floor((Date.now() - d.getTime()) / 1000);
  if (sec < 45) return 'Vừa xong';
  if (sec < 3600) return `${Math.floor(sec / 60)} phút trước`;
  if (sec < 86400) return `${Math.floor(sec / 3600)} giờ trước`;
  if (sec < 604800) return `${Math.floor(sec / 86400)} ngày trước`;
  return d.toLocaleDateString('vi-VN');
}

function initials(name: string): string {
  const parts = (name || '').trim().split(/\s+/).filter(Boolean);
  if (parts.length === 0) return 'U';
  const first = parts[0]?.[0] || '';
  const last = parts.length > 1 ? parts[parts.length - 1]?.[0] || '' : '';
  return (first + last).toUpperCase();
}

export const BlogDetailPage = () => {
  const { slug } = useParams();
  const nav = useNavigate();
  const { user, isAuthenticated } = useAuth();
  const commentBoxRef = useRef<HTMLTextAreaElement | null>(null);
  const [loading, setLoading] = useState(true);
  const [post, setPost] = useState<BlogPost | null>(null);
  const [related, setRelated] = useState<BlogPost[]>([]);
  const [loadingRelated, setLoadingRelated] = useState(false);
  const [comments, setComments] = useState<BlogComment[]>([]);
  const [loadingComments, setLoadingComments] = useState(false);
  const [commentText, setCommentText] = useState('');
  const [sendingComment, setSendingComment] = useState(false);
  const [replyTo, setReplyTo] = useState<BlogComment | null>(null);
  const [openReplies, setOpenReplies] = useState<Record<number, boolean>>({});

  useEffect(() => {
    let alive = true;
    (async () => {
      if (!slug) {
        setPost(null);
        setLoading(false);
        return;
      }
      setLoading(true);
      try {
        const p = await apiService.getBlogPostBySlug(slug);
        if (!alive) return;
        setPost(p);
      } finally {
        if (alive) setLoading(false);
      }
    })();
    return () => {
      alive = false;
    };
  }, [slug]);

  const cover = useMemo(() => resolveMediaUrl(post?.coverImageUrl), [post?.coverImageUrl]);
  const readableExcerpt = useMemo(() => {
    const c = post?.content || '';
    if (!c) return '';
    const text = stripHtml(c);
    return text.length > 180 ? text.slice(0, 180) + '…' : text;
  }, [post?.content]);

  useEffect(() => {
    let alive = true;
    (async () => {
      if (!post?.slug) {
        setRelated([]);
        return;
      }
      setLoadingRelated(true);
      try {
        const items = await apiService.getBlogPosts();
        if (!alive) return;
        const cat = postCategory(post.slug);
        const list = (items || [])
          .filter((p) => p.slug && p.slug !== post.slug)
          .sort((a, b) => {
            const ta = new Date(a.publishedAt || a.createdAt || 0).getTime();
            const tb = new Date(b.publishedAt || b.createdAt || 0).getTime();
            return tb - ta;
          });
        const sameCat = list.filter((p) => postCategory(p.slug) === cat);
        const pick = (sameCat.length >= 3 ? sameCat : list).slice(0, 3);
        setRelated(pick);
      } finally {
        if (alive) setLoadingRelated(false);
      }
    })();
    return () => {
      alive = false;
    };
  }, [post?.slug]);

  useEffect(() => {
    let alive = true;
    (async () => {
      if (!post?.slug) {
        setComments([]);
        return;
      }
      setLoadingComments(true);
      try {
        const rows = await apiService.getBlogCommentsBySlug(post.slug);
        if (!alive) return;
        setComments(rows || []);
      } finally {
        if (alive) setLoadingComments(false);
      }
    })();
    return () => {
      alive = false;
    };
  }, [post?.slug]);

  const commentTree = useMemo(() => {
    const byParent = new Map<number, BlogComment[]>();
    const roots: BlogComment[] = [];
    for (const c of comments) {
      const pid = c.parentCommentID ?? null;
      if (!pid) {
        roots.push(c);
        continue;
      }
      const list = byParent.get(pid) || [];
      list.push(c);
      byParent.set(pid, list);
    }
    // keep order newest first like API returned
    return { roots, byParent };
  }, [comments]);

  return (
    <main className="blog-page">
      <section className="blog-detail">
        <div className="container blog-shell">
          <div className="blog-breadcrumbs">
            <Link to="/blog" className="blog-back">
              ← Quay lại Blog
            </Link>
          </div>

          {loading ? (
            <div className="blog-muted">Đang tải…</div>
          ) : !post ? (
            <div className="blog-muted">Không tìm thấy bài viết.</div>
          ) : (
            <>
              <article className="blog-article">
                <header className="blog-article-head">
                  <h1 className="blog-article-title">{post.title}</h1>
                  <div className="blog-article-meta">
                    <span className="blog-article-meta__item">
                      <Eye size={16} aria-hidden />
                      {displayViews(post).toLocaleString('vi-VN')} lượt xem
                    </span>
                  </div>
                  {/* {post.excerpt ? <p className="blog-article-excerpt">{post.excerpt}</p> : readableExcerpt ? <p className="blog-article-excerpt">{readableExcerpt}</p> : null} */}
                </header>

                {cover ? (
                  <div className="blog-article-cover">
                    <img src={cover} alt="" loading="lazy" />
                  </div>
                ) : null}

                {looksLikeHtml(post.content || '') ? (
                  <div className="blog-article-content" dangerouslySetInnerHTML={{ __html: post.content || '' }} />
                ) : (
                  <div className="blog-article-content blog-article-content--plain">{post.content || ''}</div>
                )}
              </article>

              <section className="blog-related" aria-label="Bài viết liên quan">
                <h2 className="blog-related__title">Bài viết liên quan</h2>

                {loadingRelated ? (
                  <div className="blog-related__muted">Đang tải…</div>
                ) : related.length === 0 ? null : (
                  <div className="blog-related__grid">
                    {related.map((p) => {
                      const img = resolveMediaUrl(p.coverImageUrl);
                      const cat = categoryLabel(postCategory(p.slug));
                      return (
                        <Link key={p.blogPostID} to={`/blog/${p.slug}`} className="blog-related-card">
                          <div className="blog-related-card__img">
                            {img ? <img src={img} alt="" loading="lazy" /> : <div className="blog-related-card__img--ph" aria-hidden />}
                          </div>
                          <div className="blog-related-card__body">
                            <div className="blog-related-card__cat">{cat.toUpperCase()}</div>
                            <div className="blog-related-card__name">{p.title}</div>
                          </div>
                        </Link>
                      );
                    })}
                  </div>
                )}
              </section>

              <section className="blog-comments" aria-label="Bình luận">
                <div className="blog-comments__head">
                  <h2 className="blog-comments__title">
                    Bình luận <span className="blog-comments__count">{comments.length}</span>
                  </h2>
                </div>

                {loadingComments ? (
                  <div className="blog-comments__muted">Đang tải…</div>
                ) : comments.length === 0 ? (
                  <div className="blog-comments__muted">Chưa có bình luận. Hãy là người đầu tiên chia sẻ!</div>
                ) : (
                  <div className="blog-comments__list">
                    {commentTree.roots.map((c) => {
                      const replies = commentTree.byParent.get(c.blogCommentID) || [];
                      const isOpen = openReplies[c.blogCommentID] ?? false;
                      return (
                      <article key={c.blogCommentID} className="blog-comment">
                        <div className="blog-comment__avatar" aria-hidden>
                          {c.avatarUrl ? <img src={resolveMediaUrl(c.avatarUrl)} alt="" /> : initials(c.userName)}
                        </div>
                        <div className="blog-comment__body">
                          <div className="blog-comment__top">
                            <div className="blog-comment__name">{c.userName}</div>
                            <div className="blog-comment__time">{timeAgoVi(c.createdAt)}</div>
                          </div>
                          <p className="blog-comment__text">{c.content}</p>
                          {replies.length > 0 ? (
                            <button
                              type="button"
                              className="blog-comment__toggle"
                              onClick={() => setOpenReplies((m) => ({ ...m, [c.blogCommentID]: !isOpen }))}
                            >
                              {isOpen ? 'Ẩn trả lời' : `Xem trả lời (${replies.length})`}
                            </button>
                          ) : null}
                          <button
                            type="button"
                            className="blog-comment__reply"
                            onClick={() => {
                              if (!isAuthenticated) {
                                nav('/login');
                                return;
                              }
                              setReplyTo(c);
                              window.setTimeout(() => commentBoxRef.current?.focus(), 0);
                            }}
                          >
                            Trả lời
                          </button>

                          {isOpen && replies.length > 0 ? (
                            <div className="blog-replies">
                              {replies.map((r) => (
                                <article key={r.blogCommentID} className="blog-comment blog-comment--reply">
                                  <div className="blog-comment__avatar" aria-hidden>
                                    {r.avatarUrl ? <img src={resolveMediaUrl(r.avatarUrl)} alt="" /> : initials(r.userName)}
                                  </div>
                                  <div className="blog-comment__body">
                                    <div className="blog-comment__top">
                                      <div className="blog-comment__name">{r.userName}</div>
                                      <div className="blog-comment__time">{timeAgoVi(r.createdAt)}</div>
                                    </div>
                                    <p className="blog-comment__text">{r.content}</p>
                                    <button
                                      type="button"
                                      className="blog-comment__reply"
                                      onClick={() => {
                                        if (!isAuthenticated) {
                                          nav('/login');
                                          return;
                                        }
                                        setReplyTo(c);
                                        window.setTimeout(() => commentBoxRef.current?.focus(), 0);
                                      }}
                                    >
                                      Trả lời
                                    </button>
                                  </div>
                                </article>
                              ))}
                            </div>
                          ) : null}
                        </div>
                      </article>
                      );
                    })}
                  </div>
                )}

                <div className="blog-comments__form">
                  <h3 className="blog-comments__form-title">Để lại bình luận của bạn</h3>
                  {!isAuthenticated ? (
                    <div className="blog-comments__login">
                      <p className="blog-comments__muted">Bạn cần đăng nhập để bình luận.</p>
                      <button type="button" className="blog-comments__submit" onClick={() => nav('/login')}>
                        Đăng nhập
                      </button>
                    </div>
                  ) : (
                    <div className="blog-comments__form-grid">
                      {replyTo ? (
                        <div className="blog-comments__replying">
                          Đang trả lời <b>{replyTo.userName}</b>
                          <button type="button" className="blog-comments__cancel" onClick={() => setReplyTo(null)}>
                            Hủy
                          </button>
                        </div>
                      ) : null}
                      <label className="blog-comments__field blog-comments__field--full">
                        <span className="blog-comments__label">Bình luận</span>
                        <textarea
                          ref={commentBoxRef}
                          className="blog-comments__textarea"
                          placeholder="Viết bình luận của bạn tại đây..."
                          rows={4}
                          value={commentText}
                          onChange={(e) => setCommentText(e.target.value)}
                        />
                      </label>
                      <div className="blog-comments__actions">
                        <button
                          type="button"
                          className="blog-comments__submit"
                          disabled={sendingComment}
                          onClick={async () => {
                            if (!post?.slug) return;
                            if (!user?.userID) return;
                            const text = commentText.trim();
                            if (!text) return;
                            setSendingComment(true);
                            try {
                              await apiService.createBlogCommentBySlug(post.slug, {
                                userID: user.userID,
                                content: text,
                                parentCommentID: replyTo?.blogCommentID ?? null,
                              });
                              const rows = await apiService.getBlogCommentsBySlug(post.slug);
                              setComments(rows || []);
                              setCommentText('');
                              setReplyTo(null);
                            } catch (e) {
                              // eslint-disable-next-line no-alert
                              alert(e instanceof Error ? e.message : 'Gửi bình luận thất bại');
                            } finally {
                              setSendingComment(false);
                            }
                          }}
                        >
                          {sendingComment ? 'Đang gửi…' : 'Gửi bình luận'}
                        </button>
                      </div>
                    </div>
                  )}
                </div>
              </section>
            </>
          )}
        </div>
      </section>
    </main>
  );
};

