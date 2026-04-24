import { useMemo, useState } from 'react';
import { ChevronDown, Search, ShieldCheck, MessageCircle, PhoneCall } from 'lucide-react';
import { Link } from 'react-router-dom';
import faqBannerArt from '../../assets/faq/faq-banner-art.svg';

type FaqCategoryId = 'orders' | 'quality' | 'payments' | 'account';

type FaqItem = {
  id: string;
  q: string;
  a: string;
  keywords?: string[];
};

type FaqCategory = {
  id: FaqCategoryId;
  label: string;
  items: FaqItem[];
};

const FAQ_CATEGORIES: FaqCategory[] = [
  {
    id: 'orders',
    label: 'Đơn hàng & Giao hàng',
    items: [
      {
        id: 'track-order',
        q: 'Tôi có thể theo dõi đơn hàng của mình không?',
        a: 'Có. Bạn vào mục Đơn hàng trong tài khoản để xem trạng thái xử lý và giao hàng. Với một số đơn, hệ thống sẽ hiển thị mã vận đơn khi có.',
        keywords: ['theo dõi', 'đơn hàng', 'tracking', 'vận đơn'],
      },
      {
        id: 'delivery-time',
        q: 'Thời gian giao hàng mất bao lâu?',
        a: 'Thời gian giao phụ thuộc khu vực và phương thức vận chuyển. Thông thường nội thành có thể giao trong ngày; các khu vực khác từ 1–3 ngày.',
        keywords: ['giao hàng', 'thời gian', 'bao lâu'],
      },
      {
        id: 'shipping-fee',
        q: 'Phí vận chuyển được tính như thế nào?',
        a: 'Phí vận chuyển được tính ở bước Thanh toán. Một số đơn đạt mức tối thiểu có thể được miễn phí vận chuyển tùy chương trình.',
        keywords: ['phí', 'ship', 'vận chuyển', 'freeship'],
      },
    ],
  },
  {
    id: 'quality',
    label: 'Sản phẩm & Chất lượng',
    items: [
      {
        id: 'organic',
        q: 'Chứng nhận hữu cơ là gì?',
        a: 'Sản phẩm hữu cơ được trồng theo quy trình hạn chế hóa chất, ưu tiên canh tác bền vững. Tùy nhà cung cấp, chứng nhận có thể khác nhau.',
        keywords: ['hữu cơ', 'organic', 'chứng nhận'],
      },
      {
        id: 'origin',
        q: 'Nguồn gốc trang trại',
        a: 'FreshFood ưu tiên nguồn gốc rõ ràng. Thông tin nhà cung cấp/trang trại được hiển thị trên trang chi tiết sản phẩm khi có.',
        keywords: ['nguồn gốc', 'trang trại', 'nhà cung cấp'],
      },
      {
        id: 'storage',
        q: 'Làm thế nào để bảo quản thực phẩm lâu nhất?',
        a: 'Bạn nên rửa sạch và để ráo, bọc kín hoặc dùng hộp kín trước khi bảo quản. Với rau lá, có thể bọc giấy thấm để giữ tươi lâu hơn.',
        keywords: ['bảo quản', 'tươi lâu', 'lưu trữ'],
      },
    ],
  },
  {
    id: 'payments',
    label: 'Thanh toán & Hoàn tiền',
    items: [
      {
        id: 'payment-methods',
        q: 'Tôi có thể thanh toán bằng những cách nào?',
        a: 'Bạn có thể thanh toán COD hoặc qua cổng thanh toán (nếu hệ thống đang bật). Danh sách phương thức hiển thị ở bước Checkout.',
        keywords: ['thanh toán', 'cod', 'vnpay'],
      },
      {
        id: 'refund',
        q: 'Tôi có được hoàn tiền không?',
        a: 'Trong trường hợp sản phẩm lỗi/không đúng mô tả, bạn có thể gửi yêu cầu hoàn/đổi. Đội ngũ sẽ xác minh và xử lý theo chính sách.',
        keywords: ['hoàn tiền', 'đổi trả', 'refund'],
      },
    ],
  },
  {
    id: 'account',
    label: 'Tài khoản',
    items: [
      {
        id: 'reset-password',
        q: 'Tôi quên mật khẩu thì làm sao?',
        a: 'Hiện hệ thống đang hỗ trợ đăng ký/đăng nhập cơ bản. Nếu bạn quên mật khẩu, hãy liên hệ hỗ trợ để được trợ giúp.',
        keywords: ['quên mật khẩu', 'reset', 'tài khoản'],
      },
      {
        id: 'update-profile',
        q: 'Tôi có thể cập nhật thông tin cá nhân không?',
        a: 'Có. Bạn vào trang Hồ sơ để cập nhật tên, số điện thoại và địa chỉ (nếu hệ thống cho phép).',
        keywords: ['hồ sơ', 'profile', 'cập nhật'],
      },
    ],
  },
];

function normalize(s: string) {
  return (s || '').toLowerCase().trim();
}

function includesAllTokens(text: string, q: string) {
  const tokens = normalize(q).split(/\s+/).filter(Boolean);
  const t = normalize(text);
  return tokens.every((tok) => t.includes(tok));
}

export const FaqPage = () => {
  const [activeCat, setActiveCat] = useState<FaqCategoryId>('orders');
  const [search, setSearch] = useState('');
  const [openId, setOpenId] = useState<string | null>(null);

  const filteredCats = useMemo(() => {
    if (!search.trim()) return FAQ_CATEGORIES;
    return FAQ_CATEGORIES.map((c) => {
      const items = c.items.filter((it) => {
        const blob = [it.q, it.a, ...(it.keywords || [])].join(' ');
        return includesAllTokens(blob, search);
      });
      return { ...c, items };
    }).filter((c) => c.items.length > 0);
  }, [search]);

  const visibleCats = filteredCats.length > 0 ? filteredCats : FAQ_CATEGORIES;
  const current = visibleCats.find((c) => c.id === activeCat) ?? visibleCats[0];

  return (
    <main className="faq-page">
      <div className="container faq-shell">
        <header className="faq-hero">
          <div className="faq-hero__left">
            <h1 className="faq-hero__title">
              Câu hỏi <span>thường gặp</span>
            </h1>
            <p className="faq-hero__desc">
              Mọi thứ bạn cần biết khi mua nông sản tươi tại FreshFood. Tìm nhanh câu trả lời hoặc liên hệ nếu cần.
            </p>
          </div>
          <div className="faq-hero__right">
            <div className="faq-search">
              <Search size={18} aria-hidden />
              <input value={search} onChange={(e) => setSearch(e.target.value)} placeholder="Tìm kiếm câu hỏi…" />
            </div>
          </div>
        </header>

        <div className="faq-layout">
          <aside className="faq-side" aria-label="Danh mục FAQ">
            <div className="faq-side__title">Danh mục</div>
            <div className="faq-side__list">
              {FAQ_CATEGORIES.map((c) => (
                <button
                  key={c.id}
                  type="button"
                  className={`faq-side__item ${activeCat === c.id ? 'is-active' : ''}`}
                  onClick={() => setActiveCat(c.id)}
                >
                  <span>{c.label}</span>
                </button>
              ))}
            </div>

            <div className="faq-side__card">
              <div className="faq-side__card-title">Ưu đãi đổi trả</div>
              <div className="faq-side__card-sub">Chính sách đổi trả 100% hài lòng.</div>
              <Link to="/contact" className="faq-side__card-btn">
                Tìm hiểu thêm
              </Link>
            </div>
          </aside>

          <section className="faq-main" aria-label="Nội dung FAQ">
            <h2 className="faq-section-title">{current?.label}</h2>
            <div className="faq-accordion">
              {(current?.items || []).map((it) => {
                const isOpen = openId === it.id;
                return (
                  <div key={it.id} className={`faq-item ${isOpen ? 'is-open' : ''}`}>
                    <button
                      type="button"
                      className="faq-q"
                      onClick={() => setOpenId((prev) => (prev === it.id ? null : it.id))}
                      aria-expanded={isOpen}
                    >
                      <span>{it.q}</span>
                      <ChevronDown size={18} aria-hidden />
                    </button>
                    {isOpen ? <div className="faq-a">{it.a}</div> : null}
                  </div>
                );
              })}
              {current?.items?.length === 0 ? <div className="faq-empty">Không có câu hỏi phù hợp trong mục này.</div> : null}
            </div>

            <div className="faq-banner">
              <div className="faq-banner__left">
                <div className="faq-banner__kicker">
                  <ShieldCheck size={18} aria-hidden /> Chính sách đổi trả 100% hài lòng
                </div>
                <div className="faq-banner__title">Hoàn tiền/đổi sản phẩm nếu không tươi ngon</div>
                <div className="faq-banner__desc">
                  Nếu bất kỳ sản phẩm nào không đạt chất lượng khi nhận hàng, chúng tôi sẽ hoàn tiền hoặc đổi sản phẩm khác ngay.
                </div>
                <div className="faq-banner__actions">
                  <Link to="/contact" className="faq-pill faq-pill--primary">
                    Tìm hiểu thêm
                  </Link>
                  <Link to="/products" className="faq-pill">
                    Mua sắm ngay
                  </Link>
                </div>
              </div>
              <div className="faq-banner__art" aria-hidden>
                <img src={faqBannerArt} alt="" loading="lazy" decoding="async" />
              </div>
            </div>
          </section>
        </div>

        <section className="faq-contact">
          <div className="faq-contact__icon" aria-hidden>
            <MessageCircle size={18} />
          </div>
          <div className="faq-contact__text">
            <h3>Vẫn còn thắc mắc?</h3>
            <p>Đội ngũ hỗ trợ luôn sẵn sàng 24/7 để trả lời mọi câu hỏi của bạn.</p>
          </div>
          <div className="faq-contact__actions">
            <Link to="/contact" className="faq-contact__btn faq-contact__btn--primary">
              Liên hệ với chúng tôi
            </Link>
            <a className="faq-contact__btn" href="tel:0900000000">
              <PhoneCall size={16} aria-hidden /> Trò chuyện trực tiếp
            </a>
          </div>
        </section>
      </div>
    </main>
  );
};

