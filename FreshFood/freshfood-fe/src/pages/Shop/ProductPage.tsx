import React, { useState, useEffect, useMemo, useRef } from 'react';
import { useNavigate } from 'react-router-dom';
import { apiService, resolveMediaUrl, type ShopProductSort } from '../../services/api';
import { Product, Category } from '../../types';
import { useCart } from '../../context/CartContext';
import {
  Leaf,
  ShieldCheck,
  MapPin,
  ChevronDown,
  ChevronLeft,
  ChevronRight,
  Star,
  Heart,
  Search,
  ShoppingCart,
  SlidersHorizontal,
} from 'lucide-react';
import { useWishlist } from '../../context/WishlistContext';
import { useAuth } from '../../context/AuthContext';

export const ProductPage = () => {
  const [products, setProducts] = useState<Product[]>([]);
  const [allProducts, setAllProducts] = useState<Product[]>([]);
  const [categories, setCategories] = useState<Category[]>([]);
  const [selectedCat, setSelectedCat] = useState<number | null>(null);
  const [searchTerm, setSearchTerm] = useState('');
  const [loading, setLoading] = useState(true);
  /** Chỉ làm mờ lưới khi đã có dữ liệu — tránh thay cả khối nội dung (nhảy scroll khi kéo giá). */
  const [gridRefreshing, setGridRefreshing] = useState(false);
  /** Bật = không gửi min/max lên API */
  const [priceUnlimited, setPriceUnlimited] = useState(true);
  const [priceMinK, setPriceMinK] = useState(10);
  const [priceMaxK, setPriceMaxK] = useState(1000);
  const [activeCerts, setActiveCerts] = useState<string[]>([]);
  const [currentPage, setCurrentPage] = useState(1);
  const [sortBy, setSortBy] = useState<ShopProductSort>('newest');
  const [sortOpen, setSortOpen] = useState(false);
  const itemsPerPage = 18;
  const { addToCart } = useCart();
  const { isAuthenticated } = useAuth();
  const { isWished, toggle } = useWishlist();
  const navigate = useNavigate();
  const productsRef = useRef<Product[]>([]);
  productsRef.current = products;
  const sortMenuRef = useRef<HTMLDivElement | null>(null);

  /** Mobile: panel lọc thu gọn — ưu tiên lưới sản phẩm; mở bằng nút "Bộ lọc". */
  const [shopMobileLayout, setShopMobileLayout] = useState(false);
  const [mobileFiltersOpen, setMobileFiltersOpen] = useState(false);

  useEffect(() => {
    const mq = window.matchMedia('(max-width: 900px)');
    const sync = () => {
      const narrow = mq.matches;
      setShopMobileLayout(narrow);
      if (!narrow) setMobileFiltersOpen(false);
    };
    sync();
    mq.addEventListener('change', sync);
    return () => mq.removeEventListener('change', sync);
  }, []);

  useEffect(() => {
    if (!sortOpen) return;
    const onDown = (e: MouseEvent) => {
      if (!sortMenuRef.current) return;
      if (!sortMenuRef.current.contains(e.target as Node)) setSortOpen(false);
    };
    window.addEventListener('mousedown', onDown);
    return () => window.removeEventListener('mousedown', onDown);
  }, [sortOpen]);

  useEffect(() => {
    setSortOpen(false);
  }, [shopMobileLayout]);

  const sortOptions = useMemo(
    () =>
      [
        { value: 'newest', label: 'Mới nhất' },
        { value: 'bestsellers', label: 'Bán chạy' },
        { value: 'priceAsc', label: 'Giá tăng dần' },
        { value: 'priceDesc', label: 'Giá giảm dần' },
        { value: 'nameAsc', label: 'Tên A–Z' },
      ] as Array<{ value: ShopProductSort; label: string }>,
    [],
  );

  const sortLabel = useMemo(() => {
    return sortOptions.find((o) => o.value === sortBy)?.label ?? 'Mới nhất';
  }, [sortBy, sortOptions]);

  const activeFilterCount = useMemo(() => {
    let n = 0;
    if (selectedCat !== null) n += 1;
    if (!priceUnlimited) n += 1;
    n += activeCerts.length;
    return n;
  }, [selectedCat, priceUnlimited, activeCerts]);

  useEffect(() => {
    const loadInit = async () => {
      try {
        const [cats, allProds] = await Promise.all([
          apiService.getCategories(),
          apiService.getProducts()
        ]);
        setCategories(cats);
        setAllProducts(allProds);
      } catch (error) {
        console.error('Error init ShopPage:', error);
      }
    };
    loadInit();
  }, []);

  useEffect(() => {
    const ac = new AbortController();
    const loadProducts = async () => {
      const hadData = productsRef.current.length > 0;
      if (hadData) setGridRefreshing(true);
      else setLoading(true);
      try {
        const data = await apiService.getProducts({
          categoryId: selectedCat === null ? undefined : selectedCat,
          searchTerm: searchTerm.trim() || undefined,
          sort: sortBy,
          minPrice: priceUnlimited ? undefined : priceMinK * 1000,
          maxPrice: priceUnlimited ? undefined : priceMaxK * 1000,
          signal: ac.signal,
        });
        if (ac.signal.aborted) return;
        setProducts(data);
        setCurrentPage(1);
      } catch (error) {
        if (error instanceof Error && error.name === 'AbortError') return;
        console.error('Error loading products:', error);
        setProducts([]);
      } finally {
        if (!ac.signal.aborted) {
          setLoading(false);
          setGridRefreshing(false);
        }
      }
    };
    loadProducts();
    return () => ac.abort();
  }, [selectedCat, searchTerm, sortBy, priceUnlimited, priceMinK, priceMaxK]);

  // Tính toán bộ đếm danh mục dựa trên danh sách TẤT CẢ sản phẩm
  const categoryCounts = useMemo(() => {
    const counts: Record<number, number> = {};
    allProducts.forEach(p => {
      if (p.categoryID) {
        counts[p.categoryID] = (counts[p.categoryID] || 0) + 1;
      }
    });
    return counts;
  }, [allProducts]);

  /** Giá bán hiệu dụng — cùng logic với API Products. */
  const sellingPriceVnd = (p: Product) => {
    const v = p.discountPrice != null && p.discountPrice < p.price ? p.discountPrice : p.price;
    return Number(v);
  };

  // Lọc client-side: khoảng giá (khớp ngay với thanh; tránh lệch API/debounce) + chứng chỉ
  const filteredProducts = useMemo(() => {
    let list = products;
    if (!priceUnlimited) {
      const lo = priceMinK * 1000;
      const hi = priceMaxK * 1000;
      list = list.filter((p) => {
        const v = sellingPriceVnd(p);
        return v >= lo && v <= hi;
      });
    }
    if (activeCerts.length === 0) return list;
    return list.filter((p) => {
      const nameLower = p.productName.toLowerCase();
      return activeCerts.some(
        (cert) =>
          (cert === 'Hữu cơ' &&
            (nameLower.includes('tomato') || nameLower.includes('cà chua') || nameLower.includes('organic'))) ||
          (cert === 'Địa phương' &&
            (nameLower.includes('carrot') || nameLower.includes('cà rốt') || nameLower.includes('local'))) ||
          cert === 'Chứng nhận',
      );
    });
  }, [products, activeCerts, priceUnlimited, priceMinK, priceMaxK]);

  /** Trần thanh trượt: đơn vị "k" = nghìn đồng (×1000 khi gửi API). Làm tròn lên theo chục nghìn. */
  const maxPriceK = useMemo(() => {
    if (allProducts.length === 0) return 1000;
    const max = Math.max(
      0,
      ...allProducts.map((p) => {
        const d = p.discountPrice != null && p.discountPrice < p.price ? p.discountPrice : p.price;
        return Number(d ?? 0);
      }),
    );
    const k = Math.ceil(max / 1000);
    const rounded = Math.ceil(k / 10) * 10;
    // Trước đây nhầm Math.max(1000, …) → trần tối thiểu 1.000.000đ, lọc sai.
    return Math.max(10, rounded || 10);
  }, [allProducts]);

  useEffect(() => {
    setPriceMinK((p) => Math.min(Math.max(Math.min(p, maxPriceK), 10), maxPriceK));
    setPriceMaxK((p) => Math.min(Math.max(p, 10), maxPriceK));
  }, [maxPriceK]);

  const setMinK = (v: number) => {
    const next = Math.min(Math.max(Math.round(v), 10), maxPriceK);
    setPriceMinK(next);
    setPriceMaxK((mx) => (mx < next ? next : mx));
  };

  const setMaxK = (v: number) => {
    const next = Math.min(Math.max(Math.round(v), 10), maxPriceK);
    setPriceMaxK(next);
    setPriceMinK((mn) => (mn > next ? next : mn));
  };

  // Pagination (thứ tự đã sort từ API)
  const totalPages = Math.ceil(filteredProducts.length / itemsPerPage);
  const paginatedProducts = filteredProducts.slice((currentPage - 1) * itemsPerPage, currentPage * itemsPerPage);

  const goToPage = (page: number) => {
    const next = Math.min(Math.max(page, 1), Math.max(totalPages, 1));
    setCurrentPage(next);
    window.scrollTo({ top: 0, behavior: 'smooth' });
  };

  const pageItems = useMemo(() => {
    // UI giống ảnh: hiển thị tối đa 5 trang, ưu tiên cụm quanh trang hiện tại
    const maxButtons = 5;
    if (totalPages <= maxButtons) return Array.from({ length: totalPages }, (_, i) => i + 1);
    const half = Math.floor(maxButtons / 2);
    let start = currentPage - half;
    let end = currentPage + half;
    if (start < 1) {
      start = 1;
      end = maxButtons;
    }
    if (end > totalPages) {
      end = totalPages;
      start = totalPages - maxButtons + 1;
    }
    return Array.from({ length: end - start + 1 }, (_, i) => start + i);
  }, [currentPage, totalPages]);

  const formatMoney = (n: number) => new Intl.NumberFormat('vi-VN').format(n);

  const discountPercent = (p: Product): number | null => {
    if (p.discountPrice == null || p.discountPrice >= p.price) return null;
    const pct = Math.round((1 - p.discountPrice / p.price) * 100);
    return pct > 0 ? pct : null;
  };

  const ratingSummary = (p: Product): { avg: number; count: number } | null => {
    const rc = Number((p as any).reviewCount ?? 0);
    const ar = Number((p as any).averageRating ?? NaN);
    if (Number.isFinite(rc) && rc > 0 && Number.isFinite(ar)) {
      return { avg: ar, count: rc };
    }
    const rs = Array.isArray(p.reviews) ? p.reviews : [];
    const count = rs.length;
    if (count <= 0) return null;
    const sum = rs.reduce((acc, r) => acc + (Number(r.rating) || 0), 0);
    const avg = sum / count;
    return { avg: Number.isFinite(avg) ? avg : 0, count };
  };

  const renderStars = (avg: number) => {
    const full = Math.max(0, Math.min(5, Math.round(avg)));
    return (
      <div className="rating-stars" aria-label={`Đánh giá ${full}/5`}>
        {Array.from({ length: 5 }).map((_, i) => (
          <Star
            key={i}
            size={14}
            strokeWidth={2}
            className={i < full ? 'shop-star shop-star--on' : 'shop-star shop-star--off'}
            fill={i < full ? 'currentColor' : 'none'}
            aria-hidden
          />
        ))}
      </div>
    );
  };

  const toggleCert = (cert: string) => {
    setActiveCerts(prev => prev.includes(cert) ? prev.filter(c => c !== cert) : [...prev, cert]);
  };

  return (
    <div className="shop-page">
      <div className="shop-layout">
        <div className="shop-sidebar-column">
          {shopMobileLayout ? (
            <button
              type="button"
              id="shop-filter-trigger-btn"
              className={`shop-filter-trigger ${mobileFiltersOpen ? 'shop-filter-trigger--open' : ''}`}
              onClick={() => setMobileFiltersOpen((v) => !v)}
              aria-expanded={mobileFiltersOpen}
              aria-controls="shop-product-filters"
            >
              <span className="shop-filter-trigger__row">
                <span className="shop-filter-trigger__main">
                  <SlidersHorizontal size={18} aria-hidden />
                  <span className="shop-filter-trigger__label">Bộ lọc</span>
                  {activeFilterCount > 0 ? (
                    <span className="shop-filter-trigger__badge">{activeFilterCount}</span>
                  ) : null}
                </span>
                <ChevronDown className="shop-filter-trigger__chev" size={18} aria-hidden />
              </span>
              <span className="shop-filter-trigger__meta">
                {activeFilterCount > 0 ? `${activeFilterCount} tiêu chí đang áp dụng` : 'Danh mục · giá · tiêu chuẩn nông sản'}
              </span>
            </button>
          ) : null}

          {/* Sidebar - Lọc */}
          <aside
            id="shop-product-filters"
            className={`shop-sidebar ${shopMobileLayout && !mobileFiltersOpen ? 'shop-sidebar--mobile-collapsed' : ''}`}
            aria-hidden={shopMobileLayout ? !mobileFiltersOpen : undefined}
          >
          <div className="sidebar-heading">Danh mục</div>
          <div style={{display: 'flex', flexDirection: 'column', gap: '0.4rem'}}>
            <div 
              className={`sidebar-row-item ${selectedCat === null ? 'active' : ''}`}
              onClick={() => setSelectedCat(null)}
            >
              <span>Tất cả sản phẩm</span>
              <span>{allProducts.length}</span>
            </div>
            {categories.map(cat => (
              <div 
                key={cat.categoryID}
                className={`sidebar-row-item ${selectedCat === cat.categoryID ? 'active' : ''}`}
                onClick={() => setSelectedCat(cat.categoryID)}
              >
                <span>{cat.categoryName}</span>
                <span>{categoryCounts[cat.categoryID] || 0}</span>
              </div>
            ))}
          </div>

          <div className="sidebar-heading">
            Khoảng giá (theo giá bán){' '}
            {priceUnlimited ? (
              <span style={{ color: '#6b7280', fontWeight: 800 }}>(tất cả)</span>
            ) : (
              <span style={{ color: '#6b7280', fontWeight: 800 }}>
                ({new Intl.NumberFormat('vi-VN').format(priceMinK * 1000)}đ –{' '}
                {new Intl.NumberFormat('vi-VN').format(priceMaxK * 1000)}đ)
              </span>
            )}
          </div>
          <div className="shop-price-range">
            <label className="shop-price-range__toggle">
              <input
                type="checkbox"
                checked={priceUnlimited}
                onChange={(e) => {
                  const on = e.target.checked;
                  setPriceUnlimited(on);
                  if (!on) {
                    setPriceMinK(10);
                    setPriceMaxK(maxPriceK);
                  }
                  setCurrentPage(1);
                }}
              />
              Không lọc theo khoảng giá
            </label>
            {!priceUnlimited ? (
              <>
                <div className="shop-price-range__field">
                  <div className="shop-price-range__label-row">
                    <span>Từ</span>
                    <strong>{new Intl.NumberFormat('vi-VN').format(priceMinK * 1000)}đ</strong>
                  </div>
                  <input
                    type="range"
                    min={10}
                    max={maxPriceK}
                    step={10}
                    value={priceMinK}
                    onChange={(e) => setMinK(Number(e.target.value))}
                    className="shop-price-range__slider"
                  />
                </div>
                <div className="shop-price-range__field">
                  <div className="shop-price-range__label-row">
                    <span>Đến</span>
                    <strong>{new Intl.NumberFormat('vi-VN').format(priceMaxK * 1000)}đ</strong>
                  </div>
                  <input
                    type="range"
                    min={priceMinK}
                    max={maxPriceK}
                    step={10}
                    value={priceMaxK}
                    onChange={(e) => setMaxK(Number(e.target.value))}
                    className="shop-price-range__slider"
                  />
                </div>
                <p className="shop-price-range__hint">
                  Áp dụng theo <strong>giá đang bán</strong> (ưu tiên giá khuyến mãi nếu có).
                </p>
              </>
            ) : null}
            <div className="shop-price-range__axis">
              <span>10.000đ</span>
              <span>{new Intl.NumberFormat('vi-VN').format(maxPriceK * 1000)}đ</span>
            </div>
          </div>

          <div className="sidebar-heading">Tiêu chuẩn nông sản</div>
          <div className="cert-pills">
            <div className={`cert-pill ${activeCerts.includes('Hữu cơ') ? 'active' : ''}`} onClick={() => toggleCert('Hữu cơ')}>
              <Leaf size={14} /> Hữu cơ
            </div>
            <div className={`cert-pill ${activeCerts.includes('Chứng nhận') ? 'active' : ''}`} onClick={() => toggleCert('Chứng nhận')}>
              <ShieldCheck size={14} /> Chứng nhận
            </div>
            <div className={`cert-pill ${activeCerts.includes('Địa phương') ? 'active' : ''}`} onClick={() => toggleCert('Địa phương')}>
              <MapPin size={14} /> Đặc sản vùng miền
            </div>
          </div>

          
        </aside>
        </div>

        {/* Content - Sản phẩm */}
        <main className="shop-main">
          <div className="shop-title-section shop-title-section--responsive">
            <div>
              <h1 style={{margin: 0}}>Thực phẩm sạch – Tươi ngon mỗi ngày</h1>
              <p style={{marginTop: '0.5rem'}}>
                Có <strong>{filteredProducts.length}</strong> nông sản tươi ngon cho bạn lựa chọn.
              </p>
            </div>
            <div className="shop-actions">
              <div className="shop-search" role="search" aria-label="Tìm kiếm sản phẩm">
                <Search size={16} aria-hidden />
                <input
                  value={searchTerm}
                  onChange={(e) => {
                    setSearchTerm(e.target.value);
                    setCurrentPage(1);
                  }}
                  placeholder="Tìm theo tên sản phẩm…"
                />
                {searchTerm.trim() ? (
                  <button
                    type="button"
                    className="shop-search__clear"
                    onClick={() => setSearchTerm('')}
                    aria-label="Xóa tìm kiếm"
                    title="Xóa"
                  >
                    ×
                  </button>
                ) : null}
              </div>

              <div className="shop-sort">
                <span style={{color: '#999'}}>Sắp xếp theo:</span> 
                <div className="user-menu shop-sort-menu" ref={sortMenuRef}>
                  <button
                    type="button"
                    className="user-menu-trigger shop-sort-trigger"
                    onClick={() => setSortOpen((v) => !v)}
                    aria-haspopup="menu"
                    aria-expanded={sortOpen}
                    title={`Sắp xếp: ${sortLabel}`}
                  >
                    <span className="shop-sort-trigger__label">{sortLabel}</span>
                    <ChevronDown size={18} className={`user-caret ${sortOpen ? 'open' : ''}`} />
                  </button>

                  {sortOpen && (
                    <div className="user-menu-dropdown shop-sort-dropdown" role="menu">
                      {sortOptions.map((opt) => {
                        const active = opt.value === sortBy;
                        return (
                          <button
                            key={opt.value}
                            type="button"
                            className="user-menu-item"
                            role="menuitem"
                            onClick={() => {
                              setSortBy(opt.value);
                              setCurrentPage(1);
                              setSortOpen(false);
                            }}
                            aria-current={active ? 'true' : undefined}
                            style={{
                              fontWeight: active ? 900 : undefined,
                            }}
                          >
                            {opt.label}
                          </button>
                        );
                      })}
                    </div>
                  )}
                </div>
              </div>
            </div>
          </div>

          {loading && products.length === 0 ? (
            <div style={{ textAlign: 'center', padding: '5rem' }}>Đang chuẩn bị nông sản tươi ngon...</div>
          ) : filteredProducts.length === 0 && !gridRefreshing ? (
            <div style={{ textAlign: 'center', padding: '5rem', background: '#fcfcfc', borderRadius: '20px' }}>
              <h3>Không tìm thấy sản phẩm</h3>
              <p style={{ color: '#888' }}>Thử điều chỉnh thanh giá hoặc bộ lọc danh mục bạn nhé.</p>
              <button
                type="button"
                onClick={() => {
                  setSelectedCat(null);
                  setPriceUnlimited(true);
                  setPriceMinK(10);
                  setPriceMaxK(maxPriceK);
                  setActiveCerts([]);
                  setSearchTerm('');
                  setSortBy('newest');
                }}
                className="btn-primary"
                style={{ marginTop: '1.5rem' }}
              >
                Xóa tất cả bộ lọc
              </button>
            </div>
          ) : (
            <>
              <div className="shop-main-results">
                {gridRefreshing ? (
                  <div className="shop-grid-refresh-overlay" aria-live="polite">
                    <span className="shop-grid-refresh-label">Đang lọc…</span>
                  </div>
                ) : null}
                <div className="shop-grid">
                {paginatedProducts.map((product) => {
                  const pct = discountPercent(product);
                  const onSale = pct != null;
                  const sellPrice = onSale ? product.discountPrice! : product.price;
                  const catLabel = (product.category?.categoryName || 'Sản phẩm').toUpperCase();
                  const stockQty = product.stockQuantity ?? 0;
                  const outOfStock = stockQty <= 0;
                  const rs = ratingSummary(product);

                  return (
                    <article
                      key={product.productID}
                      className="shop-product-card"
                      onClick={() => navigate(`/product/${product.productToken || product.productID}`)}
                      onKeyDown={(e) => {
                        if (e.key === 'Enter' || e.key === ' ') {
                          e.preventDefault();
                          navigate(`/product/${product.productToken || product.productID}`);
                        }
                      }}
                      role="link"
                      tabIndex={0}
                      aria-label={`Xem ${product.productName}`}
                    >
                      <div className="shop-product-card__media">
                        <img
                          src={resolveMediaUrl(product.productImages?.[0]?.imageURL)}
                          alt=""
                          loading="lazy"
                          decoding="async"
                        />
                        {pct != null ? <span className="shop-product-card__discount">-{pct}%</span> : null}
                        <button
                          type="button"
                          className={`shop-product-card__wishlist ${isWished(product.productID) ? 'is-active' : ''}`}
                          title={isWished(product.productID) ? 'Bỏ yêu thích' : 'Yêu thích'}
                          aria-pressed={isWished(product.productID)}
                          onClick={(e) => {
                            e.stopPropagation();
                            if (!isAuthenticated) {
                              navigate('/login');
                              return;
                            }
                            toggle(product.productID);
                          }}
                        >
                          <Heart size={18} strokeWidth={2} fill={isWished(product.productID) ? 'currentColor' : 'none'} />
                        </button>
                      </div>
                      <div className="shop-product-card__body">
                        <p className="shop-product-card__cat">{catLabel}</p>
                        <h3 className="shop-product-card__title">{product.productName}</h3>
                        {rs ? (
                          <div className="shop-product-card__rating">
                            {renderStars(rs.avg)}
                            <span className="shop-product-card__rating-meta">
                              {rs.avg.toFixed(1)} ({rs.count})
                            </span>
                          </div>
                        ) : null}
                        <div className="shop-product-card__footer">
                          <div className="shop-product-card__prices">
                            <div className="shop-product-card__price-stack">
                              <span className="shop-product-card__price-main">{formatMoney(sellPrice)} đ</span>
                              <div className="shop-product-card__price-meta">
                                {/* <span className="shop-product-card__currency-mark">₫</span> */}
                                {/* <span className="shop-product-card__unit-suffix">
                                  / {(product.unit || 'kg').trim()}
                                </span> */}
                              </div>
                              {onSale ? (
                                <div className="shop-product-card__price-old">
                                  {formatMoney(product.price)}
                                  <span className="shop-product-card__currency-old"> ₫</span>
                                </div>
                              ) : null}
                            </div>
                          </div>
                          {outOfStock ? (
                            <button
                              type="button"
                              className="shop-product-card__cart-btn shop-product-card__cart-btn--out"
                              disabled
                              onClick={(e) => e.stopPropagation()}
                              aria-label="Hết hàng"
                            >
                              Hết hàng
                            </button>
                          ) : (
                            <button
                              type="button"
                              className="shop-product-card__cart-btn"
                              onClick={(e) => {
                                e.stopPropagation();
                                addToCart(product);
                              }}
                            >
                              <ShoppingCart size={18} strokeWidth={2.25} aria-hidden />
                              Thêm vào giỏ
                            </button>
                          )}
                        </div>
                      </div>
                    </article>
                  );
                })}
                </div>
              </div>

              {/* Phân trang */}
              {totalPages > 1 && (
                <nav
                  className="shop-pager"
                  aria-label="Phân trang"
                  style={{
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'center',
                    gap: '10px',
                    padding: '22px 0 10px',
                  }}
                >
                  <button
                    type="button"
                    onClick={() => goToPage(currentPage - 1)}
                    disabled={currentPage <= 1}
                    aria-label="Trang trước"
                    style={{
                      width: 38,
                      height: 38,
                      borderRadius: 999,
                      border: '1px solid #e5e7eb',
                      background: '#fff',
                      color: '#6b7280',
                      display: 'grid',
                      placeItems: 'center',
                      cursor: currentPage <= 1 ? 'not-allowed' : 'pointer',
                      opacity: currentPage <= 1 ? 0.5 : 1,
                    }}
                  >
                    <ChevronLeft size={18} aria-hidden />
                  </button>

                  {pageItems.map((p) => {
                    const active = p === currentPage;
                    return (
                      <button
                        key={p}
                        type="button"
                        onClick={() => goToPage(p)}
                        aria-label={`Trang ${p}`}
                        aria-current={active ? 'page' : undefined}
                        style={{
                          width: 38,
                          height: 38,
                          borderRadius: 999,
                          border: active ? '1px solid var(--primary)' : '1px solid #e5e7eb',
                          background: active ? 'var(--primary)' : '#fff',
                          color: active ? '#fff' : '#111827',
                          fontWeight: 800,
                          display: 'grid',
                          placeItems: 'center',
                          cursor: 'pointer',
                        }}
                      >
                        {p}
                      </button>
                    );
                  })}

                  <button
                    type="button"
                    onClick={() => goToPage(currentPage + 1)}
                    disabled={currentPage >= totalPages}
                    aria-label="Trang sau"
                    style={{
                      width: 38,
                      height: 38,
                      borderRadius: 999,
                      border: '1px solid #e5e7eb',
                      background: '#fff',
                      color: '#6b7280',
                      display: 'grid',
                      placeItems: 'center',
                      cursor: currentPage >= totalPages ? 'not-allowed' : 'pointer',
                      opacity: currentPage >= totalPages ? 0.5 : 1,
                    }}
                  >
                    <ChevronRight size={18} aria-hidden />
                  </button>
                </nav>
              )}
            </>
          )}
        </main>
      </div>
    </div>
  );
};
