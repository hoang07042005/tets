import { type FormEvent, useEffect, useMemo, useState } from 'react';
import { Link } from 'react-router-dom';
import { ChevronLeft, ChevronRight, Search } from 'lucide-react';
import { apiService, resolveMediaUrl } from '../../services/api';
import type { BlogPost } from '../../types';
import magHero from '../../assets/blog/banner-blog.jpg';

const GRID_PAGE_SIZE = 4;

const CATEGORY_FILTERS = [
  { id: 'all' as const, label: 'Tất cả' },
  { id: 'knowledge' as const, label: 'Kiến thức' },
  { id: 'recipe' as const, label: 'Công thức nấu ăn' },
  { id: 'farm' as const, label: 'Chuyện nông trại' },
  { id: 'lifestyle' as const, label: 'Lối sống' },
];

type CategoryId = (typeof CATEGORY_FILTERS)[number]['id'];

const POPULAR_TAGS = ['organic', 'nongsach', 'suckhoe', 'raucu', 'freshfood', 'meovat', 'huuco', 'antoan'];

function hashString(s: string): number {
  let h = 0;
  for (let i = 0; i < s.length; i++) h = (Math.imul(31, h) + s.charCodeAt(i)) | 0;
  return Math.abs(h);
}

function postCategory(slug: string): Exclude<CategoryId, 'all'> {
  const keys: Exclude<CategoryId, 'all'>[] = ['knowledge', 'recipe', 'farm', 'lifestyle'];
  return keys[hashString(slug) % keys.length];
}

function categoryLabel(id: Exclude<CategoryId, 'all'>): string {
  const row = CATEGORY_FILTERS.find((c) => c.id === id);
  return row?.label ?? 'Blog';
}

function fmtBlogDate(iso?: string | null): string {
  if (!iso) return '';
  const d = new Date(iso);
  if (Number.isNaN(d.getTime())) return '';
  return `${d.getDate()} Tháng ${d.getMonth() + 1}, ${d.getFullYear()}`;
}

function excerptForCard(p: BlogPost): string {
  if (p.excerpt?.trim()) return p.excerpt.trim();
  const c = (p.content || '').replace(/<[^>]*>/g, ' ').replace(/\s+/g, ' ').trim();
  if (!c) return '';
  return c.length > 180 ? `${c.slice(0, 180)}…` : c;
}

function fakeViews(slug: string): string {
  const k = (hashString(slug) % 50) / 10 + 0.6;
  return `${k.toFixed(1)}k lượt xem`;
}

function PostCard({ post }: { post: BlogPost }) {
  const cover = resolveMediaUrl(post.coverImageUrl);
  const cat = postCategory(post.slug);
  const excerpt = excerptForCard(post);

  return (
    <article className="blog-mag-card">
      <Link className="blog-mag-card__link" to={`/blog/${post.slug}`}>
        <div className="blog-mag-card__media">
          {cover ? <img src={cover} alt="" loading="lazy" /> : <div className="blog-mag-card__media--placeholder" aria-hidden />}
        </div>
        <div className="blog-mag-card__body">
          <div className="blog-mag-card__meta">
            <span className="blog-mag-card__cat">{categoryLabel(cat).toUpperCase()}</span>
            <span className="blog-mag-card__date">{fmtBlogDate(post.publishedAt) || '—'}</span>
          </div>
          <h3 className="blog-mag-card__title">{post.title}</h3>
          {excerpt ? <p className="blog-mag-card__excerpt">{excerpt}</p> : null}
          <span className="blog-mag-card__more">Đọc tiếp →</span>
        </div>
      </Link>
    </article>
  );
}

export const BlogListPage = () => {
  const [loading, setLoading] = useState(true);
  const [posts, setPosts] = useState<BlogPost[]>([]);
  const [q, setQ] = useState('');
  const [searchDraft, setSearchDraft] = useState('');
  const [category, setCategory] = useState<CategoryId>('all');
  const [page, setPage] = useState(1);
  const [newsletterEmail, setNewsletterEmail] = useState('');
  const [newsletterSent, setNewsletterSent] = useState(false);

  useEffect(() => {
    const t = window.setTimeout(() => setQ(searchDraft.trim()), 350);
    return () => window.clearTimeout(t);
  }, [searchDraft]);

  useEffect(() => {
    let alive = true;
    (async () => {
      setLoading(true);
      try {
        const items = await apiService.getBlogPosts({ q: q || undefined });
        if (!alive) return;
        setPosts(items || []);
      } finally {
        if (alive) setLoading(false);
      }
    })();
    return () => {
      alive = false;
    };
  }, [q]);

  const sortedFiltered = useMemo(() => {
    const list = [...posts];
    list.sort((a, b) => {
      const ta = new Date(a.publishedAt || a.createdAt || 0).getTime();
      const tb = new Date(b.publishedAt || b.createdAt || 0).getTime();
      return tb - ta;
    });
    if (category === 'all') return list;
    return list.filter((p) => postCategory(p.slug) === category);
  }, [posts, category]);

  useEffect(() => {
    setPage(1);
  }, [category, q]);

  const featured = sortedFiltered[0];
  const featuredCoverUrl = featured ? resolveMediaUrl(featured.coverImageUrl) : '';
  const featuredExcerpt = featured ? excerptForCard(featured) : '';
  const gridPosts = sortedFiltered.slice(1);
  const totalGridPages = Math.max(1, Math.ceil(gridPosts.length / GRID_PAGE_SIZE));
  const safePage = Math.min(page, totalGridPages);
  const gridSlice = gridPosts.slice((safePage - 1) * GRID_PAGE_SIZE, safePage * GRID_PAGE_SIZE);

  const popular = useMemo(() => {
    const base = [...posts].sort((a, b) => {
      const ta = new Date(a.publishedAt || a.createdAt || 0).getTime();
      const tb = new Date(b.publishedAt || b.createdAt || 0).getTime();
      return tb - ta;
    });
    return base.slice(0, 3);
  }, [posts]);

  const emptyHint = useMemo(() => {
    if (q) return 'Không tìm thấy bài viết phù hợp.';
    if (category !== 'all') return 'Không có bài trong mục này.';
    return 'Chưa có bài viết nào.';
  }, [q, category]);

  const onNewsletter = (e: FormEvent) => {
    e.preventDefault();
    if (!newsletterEmail.trim()) return;
    setNewsletterSent(true);
    setNewsletterEmail('');
  };

  const pagerNums = useMemo(() => {
    const n = totalGridPages;
    if (n <= 7) return Array.from({ length: n }, (_, i) => i + 1);
    const nums = new Set<number>([1, n, safePage, safePage - 1, safePage + 1].filter((x) => x >= 1 && x <= n));
    return [...nums].sort((a, b) => a - b);
  }, [totalGridPages, safePage]);

  return (
    <main className="blog-page blog-mag">
      <div className="container blog-shell blog-mag-hero-shell">
        <section className="blog-mag-hero">
          <div className="blog-mag-hero__bg" style={{ backgroundImage: `url(${magHero})` }} aria-hidden />
          <div className="blog-mag-hero__overlay" aria-hidden />
          <div className="blog-mag-hero__inner">
            <p className="blog-mag-hero__script" aria-hidden="true">
              Fresh Food
            </p>
            <span className="blog-mag-hero__badge">Chuyện từ đất mẹ</span>
            <h1 className="blog-mag-hero__title">
              <span className="blog-mag-hero__title-line">Kinh nghiệm &amp; Câu chuyện</span>
              <span className="blog-mag-hero__title-line blog-mag-hero__title-line--accent">Lan tỏa lối sống xanh</span>
            </h1>
          </div>
        </section>
      </div>

      <section className="blog-mag-main">
        <div className="container blog-shell blog-mag-layout">
          <div className="blog-mag-feed">
            {loading ? (
              <p className="blog-mag-muted blog-mag-muted--pad">Đang tải…</p>
            ) : sortedFiltered.length === 0 ? (
              <p className="blog-mag-muted blog-mag-muted--pad">{emptyHint}</p>
            ) : (
              <>
                {featured ? (
                  <article className="blog-mag-feature">
                    <Link className="blog-mag-feature__link" to={`/blog/${featured.slug}`}>
                      <div className="blog-mag-feature__media">
                        {featuredCoverUrl ? (
                          <img src={featuredCoverUrl} alt="" loading="lazy" />
                        ) : (
                          <div className="blog-mag-feature__media--placeholder" aria-hidden />
                        )}
                      </div>
                      <div className="blog-mag-feature__body">
                        <p className="blog-mag-feature__meta">
                          <span className="blog-mag-feature__cat">{categoryLabel(postCategory(featured.slug)).toUpperCase()}</span>
                          <span className="blog-mag-feature__meta-sep" aria-hidden="true">
                            &nbsp;•&nbsp;
                          </span>
                          <time className="blog-mag-feature__date" dateTime={featured.publishedAt || undefined}>
                            {fmtBlogDate(featured.publishedAt) || '—'}
                          </time>
                        </p>
                        <h2 className="blog-mag-feature__title">{featured.title}</h2>
                        {featuredExcerpt ? <p className="blog-mag-feature__excerpt">{featuredExcerpt}</p> : null}
                        <span className="blog-mag-feature__more">Đọc tiếp →</span>
                      </div>
                    </Link>
                  </article>
                ) : null}

                <div className="blog-mag-filters" role="tablist" aria-label="Lọc theo chủ đề">
                  {CATEGORY_FILTERS.map((c) => (
                    <button
                      key={c.id}
                      type="button"
                      role="tab"
                      aria-selected={category === c.id}
                      className={`blog-mag-filter ${category === c.id ? 'is-active' : ''}`}
                      onClick={() => setCategory(c.id)}
                    >
                      {c.label}
                    </button>
                  ))}
                </div>

                {gridPosts.length === 0 ? (
                  <p className="blog-mag-muted">Chỉ có một bài trong danh sách hiện tại.</p>
                ) : (
                  <>
                    <div className="blog-mag-grid">
                      {gridSlice.map((p) => (
                        <PostCard key={p.blogPostID} post={p} />
                      ))}
                    </div>

                    {totalGridPages > 1 ? (
                      <nav className="blog-mag-pager" aria-label="Phân trang">
                        <button
                          type="button"
                          className="blog-mag-pager__arrow"
                          disabled={safePage <= 1}
                          onClick={() => setPage((p) => Math.max(1, p - 1))}
                          aria-label="Trang trước"
                        >
                          <ChevronLeft size={22} strokeWidth={2.25} />
                        </button>
                        {pagerNums.map((num, idx) => {
                          const prev = pagerNums[idx - 1];
                          const showEllipsis = prev != null && num - prev > 1;
                          return (
                            <span key={num} className="blog-mag-pager__group">
                              {showEllipsis ? <span className="blog-mag-pager__ellipsis" aria-hidden>…</span> : null}
                              <button
                                type="button"
                                className={`blog-mag-pager__num ${num === safePage ? 'is-active' : ''}`}
                                onClick={() => setPage(num)}
                                aria-label={`Trang ${num}`}
                                aria-current={num === safePage ? 'page' : undefined}
                              >
                                {num}
                              </button>
                            </span>
                          );
                        })}
                        <button
                          type="button"
                          className="blog-mag-pager__arrow"
                          disabled={safePage >= totalGridPages}
                          onClick={() => setPage((p) => Math.min(totalGridPages, p + 1))}
                          aria-label="Trang sau"
                        >
                          <ChevronRight size={22} strokeWidth={2.25} />
                        </button>
                      </nav>
                    ) : null}
                  </>
                )}
              </>
            )}
          </div>

          <aside className="blog-mag-sidebar" aria-label="Thanh bên">
            <div className="blog-mag-widget">
              <div className="blog-mag-widget__title">
                <Search size={18} strokeWidth={2.25} aria-hidden />
                Tìm kiếm
              </div>
              <label className="visually-hidden" htmlFor="blog-sidebar-search">
                Từ khóa
              </label>
              <input
                id="blog-sidebar-search"
                className="blog-mag-widget__input"
                placeholder="Gõ từ khóa…"
                value={searchDraft}
                onChange={(e) => setSearchDraft(e.target.value)}
                autoComplete="off"
              />
            </div>

            <div className="blog-mag-widget">
              <div className="blog-mag-widget__title">Xem nhiều nhất</div>
              {popular.length === 0 ? (
                <p className="blog-mag-widget__empty">Chưa có dữ liệu.</p>
              ) : (
                <ol className="blog-mag-popular">
                  {popular.map((p, i) => (
                    <li key={p.blogPostID} className="blog-mag-popular__item">
                      <span className="blog-mag-popular__idx">{String(i + 1).padStart(2, '0')}</span>
                      <div className="blog-mag-popular__text">
                        <Link to={`/blog/${p.slug}`}>{p.title}</Link>
                        <span className="blog-mag-popular__views">{fakeViews(p.slug)}</span>
                      </div>
                    </li>
                  ))}
                </ol>
              )}
            </div>

            <div className="blog-mag-widget blog-mag-widget--news">
              <div className="blog-mag-widget__title blog-mag-widget__title--on-dark">Đăng ký nhận tin</div>
              <p className="blog-mag-news__text">Nhận mẹo bảo quản thực phẩm và tin mới mỗi tuần.</p>
              {newsletterSent ? (
                <p className="blog-mag-news__ok">Cảm ơn bạn đã đăng ký!</p>
              ) : (
                <form className="blog-mag-news__form" onSubmit={onNewsletter}>
                  <label className="visually-hidden" htmlFor="blog-news-email">
                    Email
                  </label>
                  <input
                    id="blog-news-email"
                    type="email"
                    className="blog-mag-news__input"
                    placeholder="Email của bạn"
                    value={newsletterEmail}
                    onChange={(e) => setNewsletterEmail(e.target.value)}
                  />
                  <button type="submit" className="blog-mag-news__btn">
                    Tham gia ngay
                  </button>
                </form>
              )}
            </div>

            <div className="blog-mag-widget">
              <div className="blog-mag-widget__title">Từ khóa phổ biến</div>
              <div className="blog-mag-tags">
                {POPULAR_TAGS.map((tag) => (
                  <button
                    key={tag}
                    type="button"
                    className="blog-mag-tag"
                    onClick={() => {
                      setSearchDraft(tag);
                      setQ(tag);
                    }}
                  >
                    #{tag}
                  </button>
                ))}
              </div>
            </div>
          </aside>
        </div>
      </section>
    </main>
  );
};
