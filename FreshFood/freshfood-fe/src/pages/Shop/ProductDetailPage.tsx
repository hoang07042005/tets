import { useState, useEffect } from 'react';
import { useNavigate, useParams, Link } from 'react-router-dom';
import { apiService, resolveMediaUrl } from '../../services/api';
import { Product, Review } from '../../types';
import { useCart } from '../../context/CartContext';
import { useAuth } from '../../context/AuthContext';
import { useWishlist } from '../../context/WishlistContext';
import { Plus, Minus, ShoppingBasket, ChevronRight, Truck, CheckCircle2, Heart, ShieldCheck, MapPin, ShoppingCart, Calendar, ClipboardList, Award } from 'lucide-react';

const LIFESTYLE_IMAGES = [
  'https://atvstp.org.vn/wp-content/uploads/2018/12/thoi-quen-an-cai-loai-rau-song-khong-he-tot-nhu-nhung-nguoi-tieu-dung-dang-nghi-1024x631.jpg',
  'https://defarm.vn/wp-content/uploads/2021/07/Uu-Diem-Cua-San-Pham-Sach-Tren-Thi-Truong-Hien-Nay.jpg',
  'https://defarm.vn/wp-content/uploads/2021/07/Nhuoc-Diem-Cua-San-Pham-Sach.jpg',
] as const;

function fmtDateVi(iso: string) {
  const d = new Date(iso);
  if (Number.isNaN(d.getTime())) return '';
  return d.toLocaleDateString('vi-VN', { day: 'numeric', month: 'long', year: 'numeric' });
}

function relativeTimeVi(iso: string) {
  const d = new Date(iso);
  if (Number.isNaN(d.getTime())) return '';
  const sec = Math.floor((Date.now() - d.getTime()) / 1000);
  if (sec < 45) return 'Vừa xong';
  if (sec < 3600) return `${Math.floor(sec / 60)} phút trước`;
  if (sec < 86400) return `${Math.floor(sec / 3600)} giờ trước`;
  if (sec < 604800) return `${Math.floor(sec / 86400)} ngày trước`;
  return fmtDateVi(iso);
}

export const ProductDetailPage = () => {
  const { id } = useParams<{ id: string }>();
  const nav = useNavigate();
  const [product, setProduct] = useState<Product | null>(null);
  const [relatedProducts, setRelatedProducts] = useState<Product[]>([]);
  const [loading, setLoading] = useState(true);
  const [quantity, setQuantity] = useState(1);
  const [activeImg, setActiveImg] = useState<string>('');
  const { addToCart } = useCart();
  const { user, isAuthenticated } = useAuth();
  const { isWished, toggle } = useWishlist();
  const [reviews, setReviews] = useState<Review[]>([]);
  const [newRating, setNewRating] = useState(5);
  const [newComment, setNewComment] = useState('');
  const [newFiles, setNewFiles] = useState<File[]>([]);
  const [sendingReview, setSendingReview] = useState(false);
  const [lightboxImages, setLightboxImages] = useState<string[] | null>(null);
  const [lightboxIndex, setLightboxIndex] = useState<number>(0);
  const [lifestyleIdx, setLifestyleIdx] = useState(0);

  useEffect(() => {
    const t = window.setInterval(() => {
      setLifestyleIdx((i) => (i + 1) % LIFESTYLE_IMAGES.length);
    }, 60_000);
    return () => window.clearInterval(t);
  }, []);

  useEffect(() => {
      const loadData = async () => {
      if (!id) return;
      setLoading(true);
      try {
        const raw = String(id || '').trim();
        const n = Number(raw);
        const hasNumericId = Number.isFinite(n) && n > 0 && String(Math.trunc(n)) === raw;
        const data = hasNumericId ? await apiService.getProduct(n) : await apiService.getProductByToken(raw);
        if (data) {
          setProduct(data);
          const mainImgUrl =
            data.productImages?.find((x) => x.isMainImage)?.imageURL ||
            data.productImages?.[0]?.imageURL ||
            '';
          setActiveImg(resolveMediaUrl(mainImgUrl));
          setReviews(data.reviews || []);

          const related = await apiService.getProducts(data.categoryID);
          const inCategory = (related || []).filter((p) => p.productID !== data.productID).slice(0, 6);

          if (inCategory.length === 0) {
            const all = await apiService.getProducts();
            const fallback = (all || []).filter((p) => p.productID !== data.productID).slice(0, 6);
            setRelatedProducts(fallback);
          } else {
            setRelatedProducts(inCategory);
          }
        }
      } catch (error) {
        console.error('Error loading product details:', error);
      } finally {
        setLoading(false);
      }
    };
    loadData();
    window.scrollTo(0, 0);
  }, [id]);

  useEffect(() => {
    if (!product) return;
    if (activeImg) return;
    const mainImgUrl =
      product.productImages?.find((x) => x.isMainImage)?.imageURL ||
      product.productImages?.[0]?.imageURL ||
      '';
    if (!mainImgUrl) return;
    setActiveImg(resolveMediaUrl(mainImgUrl));
  }, [product?.productID, product?.productImages?.length, activeImg]);

  useEffect(() => {
    if (!lightboxImages || lightboxImages.length === 0) return;
    const onKeyDown = (e: KeyboardEvent) => {
      if (e.key === 'Escape') {
        setLightboxImages(null);
        return;
      }
      if (e.key === 'ArrowLeft') {
        setLightboxIndex((idx) => {
          const len = lightboxImages.length;
          return (idx - 1 + len) % len;
        });
      }
      if (e.key === 'ArrowRight') {
        setLightboxIndex((idx) => {
          const len = lightboxImages.length;
          return (idx + 1) % len;
        });
      }
    };
    window.addEventListener('keydown', onKeyDown);
    return () => window.removeEventListener('keydown', onKeyDown);
  }, [lightboxImages]);

  if (loading) return <div className="loading-state">Chờ một chút, nông sản tươi sắp hiện ra...</div>;
  if (!product) return <div className="error-state">Rất tiếc, không tìm thấy sản phẩm này.</div>;

  const formatPrice = (price: number) => {
    return new Intl.NumberFormat('vi-VN', { style: 'currency', currency: 'VND' }).format(price);
  };

  const categoryName = product.category?.categoryName || 'Sản phẩm';

  const hasFreshSpec = Boolean(
    product.manufacturedDate ||
      product.expiryDate ||
      (product.origin && product.origin.trim()) ||
      (product.storageInstructions && product.storageInstructions.trim()) ||
      (product.certifications && product.certifications.trim()),
  );

  const certTags = (product.certifications || '')
    .split(/[,;]+/)
    .map((s) => s.trim())
    .filter(Boolean);

  return (
    <div className="product-detail-page product-detail-page--editorial">
      {lightboxImages && lightboxImages.length > 0 && (
        <div
          className="review-lightbox"
          role="dialog"
          aria-modal="true"
          onClick={() => setLightboxImages(null)}
        >
          <div className="review-lightbox-inner" onClick={(e) => e.stopPropagation()}>
            <button className="review-lightbox-close" type="button" onClick={() => setLightboxImages(null)} aria-label="Đóng">
              ×
            </button>

            {lightboxImages.length > 1 && (
              <>
                <button
                  type="button"
                  className="review-lightbox-nav review-lightbox-prev"
                  onClick={() =>
                    setLightboxIndex((idx) => {
                      const len = lightboxImages.length;
                      return (idx - 1 + len) % len;
                    })
                  }
                  aria-label="Ảnh trước"
                >
                  ‹
                </button>
                <button
                  type="button"
                  className="review-lightbox-nav review-lightbox-next"
                  onClick={() =>
                    setLightboxIndex((idx) => {
                      const len = lightboxImages.length;
                      return (idx + 1) % len;
                    })
                  }
                  aria-label="Ảnh tiếp theo"
                >
                  ›
                </button>
                <div className="review-lightbox-counter">
                  {lightboxIndex + 1}/{lightboxImages.length}
                </div>
              </>
            )}

            <img className="review-lightbox-img" src={lightboxImages[lightboxIndex]} alt="Ảnh đánh giá" />
          </div>
        </div>
      )}

      <div className="container pd-container">
        <nav className="pd-breadcrumb" aria-label="Breadcrumb">
          <Link to="/">Trang chủ</Link>
          <ChevronRight size={14} aria-hidden />
          <Link to="/products">Sản phẩm</Link>
          <ChevronRight size={14} aria-hidden />
          <Link to="/products">{categoryName}</Link>
          <ChevronRight size={14} aria-hidden />
          <span className="pd-breadcrumb-current">{product.productName}</span>
        </nav>

        <article className="pd-article">
          <div className="pd-main">
            <div className="pd-main-media">
              <div className="pd-hero">
                <img src={activeImg} alt={product.productName} className="pd-hero-img" />
              </div>
              {product.productImages.length > 1 ? (
                <div className="pd-thumbs">
                  {product.productImages.map((img) => {
                    const url = resolveMediaUrl(img.imageURL);
                    return (
                      <button
                        key={img.imageID}
                        type="button"
                        className={`pd-thumb ${activeImg === url ? 'is-active' : ''}`}
                        onClick={() => setActiveImg(url)}
                        aria-label="Xem ảnh"
                      >
                        <img src={url} alt="" />
                      </button>
                    );
                  })}
                </div>
              ) : null}
            </div>

            <div className="pd-main-info">
              <header className="pd-article-header pd-info-header">
                <span className="pd-cat-badge">{categoryName.toUpperCase()}</span>
                <div className="pd-title-row">
                  <h1 className="pd-title">{product.productName}</h1>
                  <button
                    type="button"
                    className={`pd-wishlist ${isWished(product.productID) ? 'is-active' : ''}`}
                    title={isWished(product.productID) ? 'Bỏ yêu thích' : 'Yêu thích'}
                    aria-label={isWished(product.productID) ? 'Bỏ yêu thích' : 'Yêu thích'}
                    onClick={() => {
                      if (!isAuthenticated) {
                        nav('/login');
                        return;
                      }
                      toggle(product.productID);
                    }}
                  >
                    <Heart size={22} />
                  </button>
                </div>
              </header>

              <div className="pd-info-price" aria-label="Giá">
                <span className="pd-price-current">
                  {product.discountPrice && product.discountPrice < product.price
                    ? formatPrice(product.discountPrice)
                    : formatPrice(product.price)}
                </span>
                {product.discountPrice && product.discountPrice < product.price ? (
                  <span className="pd-price-old">{formatPrice(product.price)}</span>
                ) : null}
                <span className="pd-price-unit">/ {product.unit || 'kg'}</span>
              </div>

              <div className="pd-prose">
                <p className="pd-lead">
                  {product.description ||
                    'Nông sản được thu hoạch và đóng gói cẩn thận, giữ trọn độ tươi và dinh dưỡng cho bữa ăn gia đình bạn.'}
                </p>
              </div>

              <div className={`pd-stock pd-stock--inline ${product.stockQuantity > 0 ? 'in' : 'out'}`}>
                {product.stockQuantity > 0 ? `Còn ${product.stockQuantity}` : 'Hết hàng'}
              </div>

              <div className="pd-buy-bar" aria-label="Đặt mua">
                <div className="pd-buy-actions">
                  {(product.stockQuantity ?? 0) > 0 ? (
                    <>
                      <div className="qty-selector pd-qty">
                        <button type="button" disabled={quantity <= 1} onClick={() => setQuantity(Math.max(1, quantity - 1))} aria-label="Giảm">
                          <Minus size={18} />
                        </button>
                        <span>{quantity}</span>
                        <button
                          type="button"
                          disabled={quantity >= product.stockQuantity}
                          onClick={() => setQuantity(Math.min(product.stockQuantity, quantity + 1))}
                          aria-label="Tăng"
                        >
                          <Plus size={18} />
                        </button>
                      </div>
                      <button
                        type="button"
                        className="pd-btn-cart btn-add-to-cart-large"
                        onClick={() => addToCart(product, Math.min(quantity, product.stockQuantity))}
                      >
                        <ShoppingCart size={20} /> Thêm vào giỏ hàng
                      </button>
                    </>
                  ) : (
                    <button type="button" className="pd-btn-cart pd-btn-cart--out btn-add-to-cart-large" disabled aria-label="Hết hàng">
                      Hết hàng
                    </button>
                  )}
                </div>
              </div>

              <div className="pd-delivery-hint">
                <span className="pd-delivery-item">
                  <Truck size={15} /> Giao nhanh trong ngày
                </span>
                <span className="pd-delivery-item">
                  <CheckCircle2 size={15} /> Nguồn gốc rõ ràng
                </span>
              </div>
            </div>
          </div>

          {/* Khối riêng full-width (không nằm trong 2 cột trái/phải) */}
          {hasFreshSpec ? (
            <section className="pd-fresh-spec" aria-labelledby="pd-fresh-spec-heading">
              <h2 id="pd-fresh-spec-heading" className="pd-fresh-spec-title">
                Thông tin về nông sản
              </h2>
              <div className="pd-fresh-spec-body">
                {product.manufacturedDate || product.expiryDate ? (
                  <div className="pd-fresh-spec-dates" role="group" aria-label="Ngày thu hoạch và hạn sử dụng">
                    <div className="pd-fresh-spec-date-col">
                      {product.manufacturedDate ? (
                        <dl className="pd-fresh-spec-field">
                          <dt className="pd-fresh-spec-label">
                            <Calendar size={18} strokeWidth={2} aria-hidden /> Ngày thu hoạch
                          </dt>
                          <dd className="pd-fresh-spec-value">{fmtDateVi(product.manufacturedDate)}</dd>
                        </dl>
                      ) : null}
                    </div>
                    <div className="pd-fresh-spec-date-col">
                      {product.expiryDate ? (
                        <dl className="pd-fresh-spec-field">
                          <dt className="pd-fresh-spec-label">
                            <Calendar size={18} strokeWidth={2} aria-hidden /> HSD
                          </dt>
                          <dd className="pd-fresh-spec-value">{fmtDateVi(product.expiryDate)}</dd>
                        </dl>
                      ) : null}
                    </div>
                  </div>
                ) : null}

                {product.origin?.trim() ? (
                  <dl className="pd-fresh-spec-field pd-fresh-spec-field--block">
                    <dt className="pd-fresh-spec-label">
                      <MapPin size={18} strokeWidth={2} aria-hidden /> Nguồn gốc
                    </dt>
                    <dd className="pd-fresh-spec-value">{product.origin.trim()}</dd>
                  </dl>
                ) : null}

                {product.storageInstructions?.trim() ? (
                  <dl className="pd-fresh-spec-field pd-fresh-spec-field--block">
                    <dt className="pd-fresh-spec-label">
                      <ClipboardList size={18} strokeWidth={2} aria-hidden /> Cách bảo quản
                    </dt>
                    <dd className="pd-fresh-spec-value">{product.storageInstructions.trim()}</dd>
                  </dl>
                ) : null}

                {certTags.length > 0 ? (
                  <dl className="pd-fresh-spec-field pd-fresh-spec-field--block">
                    <dt className="pd-fresh-spec-label">
                      <Award size={18} strokeWidth={2} aria-hidden /> Chứng nhận
                    </dt>
                    <dd className="pd-fresh-spec-certs">
                      {certTags.map((t) => (
                        <span key={t} className="pd-cert-badge">
                          {t}
                        </span>
                      ))}
                    </dd>
                  </dl>
                ) : null}
              </div>
            </section>
          ) : null}

          <section className="pd-why" aria-labelledby="pd-why-heading">
            <div className="pd-why-copy">
              <h2 id="pd-why-heading">Tại sao bạn sẽ yêu thích?</h2>
              <div className="pd-feature-list">
                <div className="pd-feature">
                  <div className="pd-feature-ico">
                    <ShieldCheck size={22} />
                  </div>
                  <div>
                    <h3>Nguồn dinh dưỡng dồi dào</h3>
                    <p>Giàu vitamin và khoáng chất, hỗ trợ bữa ăn lành mạnh mỗi ngày.</p>
                  </div>
                </div>
                <div className="pd-feature">
                  <div className="pd-feature-ico">
                    <MapPin size={22} />
                  </div>
                  <div>
                    <h3>Trang trại địa phương</h3>
                    <p>Ưu tiên nguồn gốc rõ ràng, rút ngắn thời gian từ vườn đến bếp.</p>
                  </div>
                </div>
                <div className="pd-feature">
                  <div className="pd-feature-ico">
                    <CheckCircle2 size={22} />
                  </div>
                  <div>
                    <h3>Chế biến đa dạng</h3>
                    <p>Phù hợp xào, luộc, salad hay sinh tố tùy khẩu vị cả nhà.</p>
                  </div>
                </div>
              </div>
            </div>
            <div className="pd-why-media">
              <div className="pd-why-img-wrap">
                <img src={LIFESTYLE_IMAGES[lifestyleIdx]} alt="" />
              </div>
            </div>
          </section>
        </article>

        <section className="pd-related" aria-labelledby="pd-related-title">
          <h2 id="pd-related-title" className="pd-section-title">
            Sản phẩm liên quan
          </h2>
          <div className="pd-related-grid">
            {relatedProducts.length > 0 ? (
              relatedProducts.slice(0, 3).map((p) => (
                <Link key={p.productID} to={`/product/${p.productToken || p.productID}`} className="pd-related-card">
                  <div className="pd-related-img">
                    <img src={resolveMediaUrl(p.productImages?.[0]?.imageURL)} alt="" />
                  </div>
                  <span className="pd-related-cat">{(p.category?.categoryName || categoryName).toUpperCase()}</span>
                  <h3 className="pd-related-name">{p.productName}</h3>
                  <span className="pd-related-price">{formatPrice(p.discountPrice && p.discountPrice < p.price ? p.discountPrice : p.price)}</span>
                </Link>
              ))
            ) : (
              <p className="pd-related-empty">Đang cập nhật sản phẩm cùng loại…</p>
            )}
          </div>
          <div className="pd-related-more">
            <Link to="/products" className="pd-view-all">
              Xem tất cả sản phẩm <ChevronRight size={16} />
            </Link>
          </div>
        </section>

        <section className="pd-reviews" id="danh-gia" aria-labelledby="pd-reviews-title">
          <h2 id="pd-reviews-title" className="pd-section-title">
            Đánh giá sản phẩm
          </h2>

          <div className="pd-reviews-layout">
            <div className={`pd-reviews-list${reviews.length > 10 ? ' pd-reviews-list--scrollable' : ''}`}>
              {reviews.length === 0 ? (
                <p className="pd-reviews-empty">Chưa có đánh giá nào. Hãy là người đầu tiên!</p>
              ) : (
                reviews.map((r) => (
                  <article key={r.reviewID} className="pd-review-card">
                    <div className="pd-review-avatar">
                      {r.user?.avatarUrl ? (
                        <img src={resolveMediaUrl(r.user.avatarUrl)} alt="" />
                      ) : (
                        (r.user?.fullName?.[0] || 'K').toUpperCase()
                      )}
                    </div>
                    <div className="pd-review-body">
                      <div className="pd-review-top">
                        <span className="pd-review-name">{r.user?.fullName || `Khách #${r.userID}`}</span>
                        <span className="pd-review-time">{relativeTimeVi(r.reviewDate)}</span>
                      </div>
                      <div className="pd-review-stars" aria-label={`${r.rating} sao`}>
                        {'★'.repeat(r.rating)}
                        {'☆'.repeat(5 - r.rating)}
                      </div>
                      {r.comment ? <p className="pd-review-text">{r.comment}</p> : null}
                      {r.adminReply ? (
                        <div className="pd-review-admin-reply">
                          <div className="pd-review-admin-reply-head">FreshFood phản hồi</div>
                          <div className="pd-review-admin-reply-body">{r.adminReply}</div>
                        </div>
                      ) : null}
                      {r.reviewImages && r.reviewImages.length > 0 ? (
                        <div className="review-images pd-review-images">
                          {r.reviewImages
                            .slice()
                            .sort((a, b) => a.sortOrder - b.sortOrder)
                            .slice(0, 3)
                            .map((img, idx) => (
                              <img
                                key={img.reviewImageID}
                                src={resolveMediaUrl(img.imageUrl)}
                                alt=""
                                onClick={() => {
                                  const imgs = (r.reviewImages || [])
                                    .slice()
                                    .sort((a, b) => a.sortOrder - b.sortOrder)
                                    .slice(0, 3)
                                    .map((x) => resolveMediaUrl(x.imageUrl));
                                  setLightboxImages(imgs);
                                  setLightboxIndex(idx);
                                }}
                                style={{ cursor: 'zoom-in' }}
                              />
                            ))}
                        </div>
                      ) : null}
                    </div>
                  </article>
                ))
              )}
            </div>

            <div className="pd-review-form-wrap" id="review-form">
              <h3 className="pd-review-form-title">Viết đánh giá</h3>
              {!isAuthenticated ? (
                <div className="pd-review-guest">
                  <p>Đăng nhập để gửi đánh giá (sao và nhận xét) cho sản phẩm này.</p>
                  <Link className="btn-primary pd-login-link" to="/login">
                    Đăng nhập
                  </Link>
                </div>
              ) : (
                <div className="pd-review-form">
                  <label className="pd-field-label" htmlFor="pd-review-rating">
                    Số sao
                  </label>
                  <select id="pd-review-rating" className="pd-input pd-select" value={newRating} onChange={(e) => setNewRating(Number(e.target.value))}>
                    {[5, 4, 3, 2, 1].map((v) => (
                      <option key={v} value={v}>
                        {v} sao
                      </option>
                    ))}
                  </select>
                  <label className="pd-field-label" htmlFor="pd-review-text">
                    Nhận xét <span className="pd-optional">(tùy chọn)</span>
                  </label>
                  <textarea
                    id="pd-review-text"
                    className="pd-textarea"
                    value={newComment}
                    onChange={(e) => setNewComment(e.target.value)}
                    rows={4}
                    placeholder="Ví dụ: chất lượng, độ tươi, đóng gói…"
                  />
                  <label className="pd-field-label">
                    Ảnh minh họa <span className="pd-optional">(tối đa 3)</span>
                  </label>
                  <div className="review-upload-row">
                    <label className="review-upload-btn">
                      Chọn ảnh
                      <input
                        className="review-file-input"
                        type="file"
                        accept="image/*"
                        multiple
                        onChange={(e) => {
                          const files = Array.from(e.target.files || []);
                          setNewFiles(files.slice(0, 3));
                        }}
                      />
                    </label>
                    <span className="review-upload-meta">{newFiles.length === 0 ? 'Chưa chọn ảnh' : `Đã chọn ${newFiles.length}/3 ảnh`}</span>
                    {newFiles.length > 0 ? (
                      <button type="button" className="review-upload-clear" onClick={() => setNewFiles([])}>
                        Xóa
                      </button>
                    ) : null}
                  </div>
                  {newFiles.length > 0 ? (
                    <div className="review-images pd-new-files">
                      {newFiles.map((f, idx) => (
                        <img key={idx} src={URL.createObjectURL(f)} alt="" />
                      ))}
                    </div>
                  ) : null}
                  <button
                    type="button"
                    className="pd-submit-review"
                    disabled={sendingReview}
                    onClick={async () => {
                      if (!product || !user) return;
                      try {
                        setSendingReview(true);
                        const uploadedUrls = await apiService.uploadReviewImages(newFiles);
                        const created = await apiService.createReview({
                          productID: product.productID,
                          userID: user.userID,
                          rating: newRating,
                          comment: newComment,
                          imageUrls: uploadedUrls,
                        });
                        const status = String((created as any)?.moderationStatus || '').toLowerCase();
                        const refreshed = await apiService.getProduct(product.productID);
                        if (refreshed) {
                          setProduct(refreshed);
                          setReviews(refreshed.reviews || []);
                        }
                        setNewComment('');
                        setNewFiles([]);
                        setNewRating(5);
                        if (status === 'pending') {
                          alert('Đánh giá của bạn đã được gửi và đang chờ admin duyệt.');
                        } else {
                          alert('Cảm ơn bạn đã đánh giá sản phẩm.');
                        }
                      } catch (err: any) {
                        alert(err?.message || 'Gửi đánh giá thất bại. Vui lòng thử lại.');
                      } finally {
                        setSendingReview(false);
                      }
                    }}
                  >
                    {sendingReview ? 'Đang gửi…' : 'Gửi đánh giá'}
                  </button>
                </div>
              )}
            </div>
          </div>
        </section>
      </div>
    </div>
  );
};
