import { useState, useEffect, useMemo } from 'react';
import { Truck, ShieldCheck, Plus, ChevronRight, Heart, BadgePercent, Copy, Sparkles, ShoppingCart, TagIcon } from 'lucide-react';
import { Link, useNavigate } from 'react-router-dom';
import { Product, Category, RecentReview, ReviewSummary, Voucher } from '../../types';
import { apiService, resolveMediaUrl } from '../../services/api';
import { useCart } from '../../context/CartContext';
import { useWishlist } from '../../context/WishlistContext';
import { useAuth } from '../../context/AuthContext';

export const Home = () => {
  const [products, setProducts] = useState<Product[]>([]);
  const [categories, setCategories] = useState<Category[]>([]);
  const [recentReviews, setRecentReviews] = useState<RecentReview[]>([]);
  const [reviewSummary, setReviewSummary] = useState<ReviewSummary>({ averageRating: 0, totalReviews: 0 });
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [copiedCode, setCopiedCode] = useState<string | null>(null);
  const [vouchers, setVouchers] = useState<Voucher[]>([]);
  const [avatarErrorReviewIds, setAvatarErrorReviewIds] = useState<Set<number>>(() => new Set());
  const [savedVoucherCodes, setSavedVoucherCodes] = useState<string[]>(() => {
    try {
      const raw = localStorage.getItem('freshfood_saved_vouchers');
      return raw ? (JSON.parse(raw) as string[]) : [];
    } catch {
      return [];
    }
  });
  const { addToCart } = useCart();
  const { isAuthenticated, user } = useAuth();
  const { isWished, toggle } = useWishlist();
  const nav = useNavigate();

  const [homeSettings, setHomeSettings] = useState<import('../../types').HomePageSettings | null>(null);

  const toggleSaveVoucher = (code: string) => {
    const next = savedVoucherCodes.includes(code)
      ? savedVoucherCodes.filter(c => c !== code)
      : [...savedVoucherCodes, code];
    setSavedVoucherCodes(next);
    localStorage.setItem('freshfood_saved_vouchers', JSON.stringify(next));
  };

  useEffect(() => {
    const loadData = async () => {
      try {
        setLoading(true);
        const [prodData, catData, reviewsData, summaryData, voucherData, homeCfg] = await Promise.all([
          apiService.getProducts(),
          apiService.getCategories(),
          // Fetch more so we can pick top-rated + newest 2 on client.
          apiService.getRecentReviews(30),
          apiService.getReviewSummary(),
          apiService.getActiveVouchers(isAuthenticated ? user?.userID : undefined),
          apiService.getHomePageSettings(),
        ]);
        setProducts(prodData);
        setCategories(catData);
        setRecentReviews(reviewsData);
        setReviewSummary(summaryData);
        setVouchers(voucherData);
        setHomeSettings(homeCfg);
      } catch (err) {
        setError('Không thể kết nối tới server. Vui lòng thử lại sau.');
        console.error(err);
      } finally {
        setLoading(false);
      }
    };
    loadData();
  }, [isAuthenticated, user?.userID]);

  const topReviews = useMemo(() => {
    const list = Array.isArray(recentReviews) ? recentReviews : [];
    return [...list]
      .sort((a, b) => {
        const ratingDiff = (b.rating ?? 0) - (a.rating ?? 0);
        if (ratingDiff !== 0) return ratingDiff;
        const tA = new Date(a.reviewDate || 0).getTime();
        const tB = new Date(b.reviewDate || 0).getTime();
        return tB - tA;
      })
      .slice(0, 2);
  }, [recentReviews]);

  const marqueeVouchers = useMemo(() => {
    // Duplicate vouchers to create a seamless marquee even on wide screens.
    const list = Array.isArray(vouchers) ? vouchers : [];
    if (list.length === 0) return [];
    return [...list, ...list];
  }, [vouchers]);

  // Pick 8 random products if available, otherwise just first 8
  const featuredProducts = useMemo(() => {
    if (products.length === 0) return [];
    // Shuffle and pick 8
    return [...products].sort(() => 0.5 - Math.random()).slice(0, 8);
  }, [products]);

  const formatPrice = (price: number) => {
    return new Intl.NumberFormat('vi-VN', { style: 'currency', currency: 'VND' }).format(price);
  };

  const renderStars = (rating: number) => {
    const full = Math.max(0, Math.min(5, Math.round(rating)));
    return (
      <div className="rating-stars" aria-label={`Đánh giá ${full}/5`}>
        {Array.from({ length: 5 }).map((_, i) => (
          <span key={i} className={i < full ? 'star star-on' : 'star star-off'}>★</span>
        ))}
      </div>
    );
  };

  return (
    <main>
      <section className="home-hero">
        <div className="home-hero-inner">
          <div className="hero-copy">
            <span className="hero-eyebrow">{homeSettings?.hero?.eyebrow || 'FRESH FROM THE FARM'}</span>
            <h1 className="hero-title">
              {homeSettings?.hero?.title || 'Thực phẩm sạch cho'}
              <br />
              <span className="hero-highlight">{homeSettings?.hero?.highlight || 'cuộc sống xanh'}</span>
            </h1>
            <p className="hero-subtitle">
              {homeSettings?.hero?.subtitle ||
                `Mang tinh hoa của đất mẹ đến bàn ăn gia đình bạn. Chúng tôi cam kết 100% hữu cơ,
              tươi mới và canh tác bền vững.`}
            </p>
            <div className="hero-cta-row">
              <Link to={homeSettings?.hero?.primaryCtaHref || '/shop'} className="hero-cta hero-cta-primary">
                {homeSettings?.hero?.primaryCtaText || 'Shop Collections'}
              </Link>
              {homeSettings?.hero?.secondaryCtaHref ? (
                <Link to={homeSettings.hero.secondaryCtaHref} className="hero-cta hero-cta-secondary">
                  {homeSettings?.hero?.secondaryCtaText || 'View Story'}
                </Link>
              ) : (
                <button className="hero-cta hero-cta-secondary" type="button">
                  {homeSettings?.hero?.secondaryCtaText || 'View Story'}
                </button>
              )}
            </div>
          </div>
          <div className="hero-image-wrapper">
            <div className="hero-image-card">
              <img
                src={
                  resolveMediaUrl(
                    homeSettings?.hero?.imageUrl 
                  )
                }
                alt="Giỏ rau củ quả tươi xanh"
              />
            </div>
          </div>
        </div>

        <div className="hero-features-row">
          <div className="feature-pill">
            <Truck size={22} />
            <div>
              <strong>{homeSettings?.hero?.feature1Title || 'Giao hàng trong 2h'}</strong>
              <p>{homeSettings?.hero?.feature1Sub || 'Nhanh chóng & tiện lợi'}</p>
            </div>
          </div>
          <div className="feature-pill">
            <ShieldCheck size={22} />
            <div>
              <strong>{homeSettings?.hero?.feature2Title || 'Đảm bảo ATVSTP'}</strong>
              <p>{homeSettings?.hero?.feature2Sub || 'Kiểm duyệt nghiêm ngặt'}</p>
            </div>
          </div>
        </div>
      </section>

      <section className="voucher-section" aria-label="Mã giảm giá">
        <div className="container">
          <div className="voucher-head">
            <div>
              <span className="voucher-kicker"><Sparkles size={16} aria-hidden /> Ưu đãi tuần này</span>
              <h2 className="voucher-title">Vouchers</h2>
              <p className="voucher-sub">Chọn mã phù hợp và sao chép để dùng khi thanh toán.</p>
            </div>
            <div className="voucher-hint" aria-live="polite">
              {copiedCode ? <>Đã sao chép: <strong>{copiedCode}</strong></> : ' '}
            </div>
          </div>

          <div className="voucher-marquee" role="region" aria-label="Danh sách vouchers">
            <div className="voucher-track">
              {marqueeVouchers.map((v, idx) => {
              const exp = v.expiryDate ? new Date(v.expiryDate).toLocaleDateString('vi-VN') : 'Không giới hạn';
              const title =
                (v.discountType || '').toLowerCase() === 'percentage'
                  ? `Giảm ${v.discountValue}%`
                  : `Giảm ${new Intl.NumberFormat('vi-VN').format(v.discountValue)}đ`;
              const desc = `Đơn từ ${new Intl.NumberFormat('vi-VN').format(v.minOrderAmount)}đ`;
              const note = `HSD: ${exp}`;
              const saved = savedVoucherCodes.includes(v.code);
              return (
                <article key={`${v.voucherID}-${idx}`} className="voucher-card">
                <div className="voucher-badge">
                  <TagIcon size={18} aria-hidden />
                  <span>{title}</span>
                </div>
                <div className="voucher-main">
                  <div className="voucher-code">{v.code}</div>
                  <div className="voucher-desc">{desc}</div>
                  <div className="voucher-note">{note}</div>
                </div>
                <div className="voucher-actions">
                  <button
                    type="button"
                    className="voucher-copy"
                    onClick={async () => {
                      try {
                        await navigator.clipboard.writeText(v.code);
                        setCopiedCode(v.code);
                        window.setTimeout(() => setCopiedCode(null), 1800);
                      } catch {
                        setCopiedCode(v.code);
                      }
                    }}
                  >
                    <Copy size={18} aria-hidden /> Sao chép
                  </button>
                  <button
                    type="button"
                    className={`voucher-save ${saved ? 'saved' : ''}`}
                    onClick={() => toggleSaveVoucher(v.code)}
                    aria-pressed={saved}
                  >
                    {saved ? 'Đã lưu' : 'Lưu'}
                  </button>
                </div>
              </article>
              );
            })}
            </div>
          </div>
        </div>
      </section>

      <section className="product-list">
        <div style={{display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '2.5rem'}}>
          <h2 style={{margin: 0}}>Sản phẩm Nổi bật</h2>
          <Link to="/products" style={{
            display: 'flex', 
            alignItems: 'center', 
            gap: '0.5rem', 
            textDecoration: 'none', 
            color: 'var(--primary)', 
            fontWeight: '700',
            fontSize: '1rem'
          }}>
            Xem tất cả <ChevronRight size={18} />
          </Link>
        </div>
        
        {loading && <div className="loading"><p>Đang tải dữ liệu...</p></div>}
        {error && <div className="error"><p>{error}</p></div>}

        {!loading && !error && (
          <div className="grid">
            {featuredProducts.map(product => (
              <div
                key={product.productID}
                className="product-card"
                role="button"
                tabIndex={0}
                onClick={() => nav(`/product/${product.productToken || product.productID}`)}
                onKeyDown={(e) => {
                  if (e.key === 'Enter' || e.key === ' ') nav(`/product/${product.productToken || product.productID}`);
                }}
              >
                <div className="product-image">
                  {product.productImages && product.productImages.length > 0 ? (
                    <img
                      src={resolveMediaUrl(
                        product.productImages.find(img => img.isMainImage)?.imageURL || product.productImages[0]?.imageURL
                      )}
                      alt={product.productName}
                    />
                  ) : (
                    <div style={{width: '100%', height: '100%', display: 'flex', alignItems: 'center', justifyContent: 'center', color: '#ccc'}}>No Image</div>
                  )}
                  <button
                    type="button"
                    className={`wishlist-btn ${isWished(product.productID) ? 'wished' : ''}`}
                    title={isWished(product.productID) ? 'Bỏ yêu thích' : 'Yêu thích'}
                    onClick={(e) => {
                      e.stopPropagation();
                      if (!isAuthenticated) {
                        nav('/login');
                        return;
                      }
                      toggle(product.productID);
                    }}
                  >
                    <Heart size={18} />
                  </button>
                </div>
                <div className="product-info">
                  <span className="product-cat">{product.category?.categoryName || 'Sản phẩm'}</span>
                  <h3 className="product-name">{product.productName}</h3>
                  <div className="product-price">
                    {formatPrice(product.price)}
                    <span> / {product.unit || 'Kg'}</span>
                  </div>
                  <button className="btn-add" onClick={(e) => { e.stopPropagation(); addToCart(product); }}>
                    <ShoppingCart size={18} /> Thêm vào giỏ
                  </button>
                </div>
              </div>
            ))}
          </div>
        )}
      </section>
      

      <section className="our-roots-section">
        <div className="container">
          <div className="roots-grid">
            <div className="roots-image-side">
              <div className="roots-img-wrapper">
                <img
                  src={resolveMediaUrl(
                    homeSettings?.roots?.imageUrl ||
                      'https://lh3.googleusercontent.com/aida-public/AB6AXuDsj_dBOI4I0rXNR9uejFIaPEYVYQLiGunw26FXWSFWv8bh-uXHvGgsQsg_XTphaN30FjcrZ-zZvN1zLeAy9-L0P21Vb5NEEbJZ-udrnGjuUD8oXHa4P3CgVcJ44tFQXwszRhO4rqxV3sGWuBfqtJ7aAcKYwZpFTiIEiEn6Q0bK0gDvCvPdtucaAkTpSSL_YANkAVAhLYv5EFW-rtmR0wFVAIEamv0iDUPhzmDHsk6HgLEDPQgOGkgMEv47w-wVzGBjlAicFc822N8',
                  )}
                  alt="FreshFood Farm"
                />
              </div>
            </div>
            <div className="roots-content-side">
              <span className="roots-subheading">{homeSettings?.roots?.subheading || 'OUR ROOTS'}</span>
              <h2 className="roots-title">{homeSettings?.roots?.title || 'Lớn lên với niềm đam mê,được truyền tải bằng trái tim.'}</h2>
              
              <div className="roots-text">
                <p>
                  {homeSettings?.roots?.paragraph1 ||
                    'Từ những ngày đầu tiên tại nông trại hữu cơ nhỏ, chúng tôi luôn tin rằng thực phẩm tốt nhất là thực phẩm được nuôi dưỡng bởi tự nhiên và sự chăm sóc từ tâm.'}
                </p>
                <p>
                  {homeSettings?.roots?.paragraph2 ||
                    'Mỗi sản phẩm tại FreshFood đều trải qua quy trình kiểm soát nghiêm ngặt từ hạt giống đến khi trao tận tay khách hàng. Không hóa chất, không thuốc trừ sâu - chỉ có sự tinh khiết tuyệt đối cho sức khỏe gia đình bạn.'}
                </p>
              </div>

              <div className="roots-stats">
                <div className="stat-item">
                  <span className="stat-value">{homeSettings?.roots?.stat1Value || '100%'}</span>
                  <span className="stat-label">{homeSettings?.roots?.stat1Label || 'Organic Certified'}</span>
                </div>
                <div className="stat-item">
                  <span className="stat-value">{homeSettings?.roots?.stat2Value || '24h'}</span>
                  <span className="stat-label">{homeSettings?.roots?.stat2Label || 'Farm to Door'}</span>
                </div>
              </div>
            </div>
          </div>
        </div>
      </section>

      {/* Seasonal Collections */}
      <section className="seasonal-collections">
        <div className="seasonal-inner">
          <header className="seasonal-header">
            <h2>{homeSettings?.seasonal?.heading || 'Bộ sưu tập theo mùa'}</h2>
            <p>
              {homeSettings?.seasonal?.subheading ||
                `Đón mùa vụ tươi ngon nhất trong năm. Khám phá những bộ sưu tập được
              tuyển chọn theo mùa vụ hiện tại.`}
            </p>
          </header>
          <div className="seasonal-grid">
            {(homeSettings?.seasonal?.cards?.length ? homeSettings.seasonal.cards : [
              { title: 'The Spring Greens', imageUrl: 'https://images.pexels.com/photos/60597/dahlia-red-blossom-bloom-60597.jpeg' },
              { title: 'Earthy Roots', imageUrl: 'https://images.pexels.com/photos/1301856/pexels-photo-1301856.jpeg' },
              { title: 'Sun-Kissed Fruits', imageUrl: 'https://images.pexels.com/photos/1132047/pexels-photo-1132047.jpeg' },
            ]).slice(0, 3).map((c, idx) => (
              <article key={`${c.title}-${idx}`} className="seasonal-card">
                <div
                  className="seasonal-image"
                  style={{
                    backgroundImage: `url('${resolveMediaUrl(c.imageUrl)}')`,
                  }}
                >
                  <div className="seasonal-overlay" />
                  <h3 className="seasonal-title">{c.title}</h3>
                </div>
              </article>
            ))}
          </div>
        </div>
      </section>

      {/* Testimonials */}
      <section className="home-testimonials">
        <div className="container">
          <div className="testimonials-grid">
            <div className="testimonials-left">
              <h2>Được yêu thích bởi những người đam mê ẩm thực.</h2>
              <div className="testimonials-list">
                {topReviews.map(r => (
                  <article key={r.reviewID} className="testimonial-quote">
                    <div className="quote-mark">“</div>
                    <p className="quote-text">{r.comment || 'Sản phẩm rất tươi và chất lượng. Sẽ ủng hộ dài lâu!'}</p>
                    <div className="quote-author">
                      {r.avatarUrl && !avatarErrorReviewIds.has(r.reviewID) ? (
                        <img
                          className="avatar-img"
                          src={resolveMediaUrl(r.avatarUrl)}
                          alt={r.userName || 'Khách hàng'}
                          loading="lazy"
                          decoding="async"
                          onError={() => {
                            setAvatarErrorReviewIds(prev => {
                              const next = new Set(prev);
                              next.add(r.reviewID);
                              return next;
                            }); 
                          }}
                        />
                      ) : (
                        <div className="avatar">
                          {r.userName?.trim()?.split(' ').slice(-1)[0]?.slice(0, 1).toUpperCase() || 'K'}
                        </div>
                      )}
                      <div>
                        <div className="author-name">{r.userName || 'Khách hàng'}</div>
                        <div className="author-role">Khách hàng</div>
                      </div>
                    </div>
                  </article>
                ))}
              </div>
            </div>

            <div className="testimonials-right">
              <div className="testimonial-image-card">
                <div className="rating-pill">
                  {renderStars(reviewSummary.averageRating)}
                  <div className="rating-meta">
                    <div className="rating-line">
                      Rated <strong>{reviewSummary.averageRating.toFixed(1)}/5</strong>
                    </div>
                    <div className="rating-sub">
                      based on <strong>{reviewSummary.totalReviews.toLocaleString('en-US')}</strong> reviews
                    </div>
                  </div>
                </div>
                <img
                  src="https://lh3.googleusercontent.com/aida-public/AB6AXuBirokZdFAzZZHGCQxtGm5s6Dd16kPvFKbD4GxmQgYlVJOJb6fdpJhnvHk9ZNm0Ip7k9MqLL715kfQWhp1k-Kj4Qo39P4BXWOrBdTzvTEUsOX5cshYX-NXsBQGNpGMhc74Q1r5gPZa0p_wvgbAf0KLSTBDj5g_8C7c9CnvzlGrNRM1txgm5W2jMLM6-ABD2xIiMnlG34okZxfGLWgeyvE65yqwR5sDxXq1wkhAC2f6kSAPUToP7F-pI5-6I85o3I2smifYiV12s-IU"
                  alt="Khách hàng đánh giá FreshFood"
                />
              </div>
            </div>
          </div>
        </div>
      </section>

    </main>
  );
};
