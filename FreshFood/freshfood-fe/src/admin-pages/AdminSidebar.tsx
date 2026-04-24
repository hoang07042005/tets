import {
  LayoutGrid,
  Leaf,
  Tag,
  FileText,
  ShoppingBag,
  Star,
  ChevronDown,
  ChevronRight,
  List,
  Package,
  FolderTree,
  Users,
  MessageSquare,
} from 'lucide-react';

export type AdminTabKey =
  | 'dashboard'
  | 'products-list'
  | 'products-supplier'
  | 'products-category'
  | 'blog'
  | 'vouchers'
  | 'orders'
  | 'home-settings'
  | 'reviews'
  | 'contact-messages'
  | 'users';

const productSubs: { key: Extract<AdminTabKey, 'products-list' | 'products-supplier' | 'products-category'>; label: string; Icon: typeof List }[] =
  [
    { key: 'products-list', label: 'Danh sách sản phẩm', Icon: List },
    { key: 'products-supplier', label: 'Nhà cung cấp', Icon: Package },
    { key: 'products-category', label: 'Danh mục', Icon: FolderTree },
  ];

export function isProductSubTab(tab: AdminTabKey): boolean {
  return tab === 'products-list' || tab === 'products-supplier' || tab === 'products-category';
}

type Props = {
  tab: AdminTabKey;
  onChange: (tab: AdminTabKey) => void;
  productsOpen: boolean;
  onProductsOpenChange: (open: boolean) => void;
};

export function AdminSidebar({ tab, onChange, productsOpen, onProductsOpenChange }: Props) {
  const productActive = isProductSubTab(tab);

  return (
    <aside className="admin-nav" aria-label="Admin sidebar">
      <nav className="admin-nav-list" aria-label="Admin menu">
        <button
          type="button"
          className={`admin-nav-item ${tab === 'dashboard' ? 'active' : ''}`}
          onClick={() => onChange('dashboard')}
          role="tab"
          aria-selected={tab === 'dashboard'}
        >
          <LayoutGrid className="admin-nav-icon" size={20} strokeWidth={1.75} aria-hidden />
          <span className="admin-nav-text">Tổng quan</span>
        </button>

        <button
          type="button"
          className={`admin-nav-item ${tab === 'home-settings' ? 'active' : ''}`}
          onClick={() => onChange('home-settings')}
          role="tab"
          aria-selected={tab === 'home-settings'}
        >
          <Leaf className="admin-nav-icon" size={20} strokeWidth={1.75} aria-hidden />
          <span className="admin-nav-text">Thiết lập trang chủ</span>
        </button>

        <button
          type="button"
          className={`admin-nav-item ${tab === 'orders' ? 'active' : ''}`}
          onClick={() => onChange('orders')}
          role="tab"
          aria-selected={tab === 'orders'}
        >
          <ShoppingBag className="admin-nav-icon" size={20} strokeWidth={1.75} aria-hidden />
          <span className="admin-nav-text">Đơn hàng</span>
        </button>

        <div className={`admin-nav-group ${productsOpen ? 'is-open' : ''}`}>
          <button
            type="button"
            className={`admin-nav-item admin-nav-item--parent ${productActive ? 'active' : ''}`}
            onClick={() => onProductsOpenChange(!productsOpen)}
            aria-expanded={productsOpen}
            aria-controls="admin-products-submenu"
            id="admin-products-trigger"
          >
            <Leaf className="admin-nav-icon" size={20} strokeWidth={1.75} aria-hidden />
            <span className="admin-nav-text">Sản phẩm</span>
            <span className="admin-nav-chevron" aria-hidden>
              {productsOpen ? <ChevronDown size={18} strokeWidth={2} /> : <ChevronRight size={18} strokeWidth={2} />}
            </span>
          </button>

          <div
            id="admin-products-submenu"
            className="admin-nav-submenu"
            role="group"
            aria-labelledby="admin-products-trigger"
            hidden={!productsOpen}
          >
            {productSubs.map(({ key, label, Icon }) => (
              <button
                key={key}
                type="button"
                className={`admin-nav-subitem ${tab === key ? 'active' : ''}`}
                onClick={() => onChange(key)}
                role="tab"
                aria-selected={tab === key}
              >
                <Icon className="admin-nav-subicon" size={18} strokeWidth={1.75} aria-hidden />
                <span>{label}</span>
              </button>
            ))}
          </div>
        </div>

        <button
          type="button"
          className={`admin-nav-item ${tab === 'reviews' ? 'active' : ''}`}
          onClick={() => onChange('reviews')}
          role="tab"
          aria-selected={tab === 'reviews'}
        >
          <Star className="admin-nav-icon" size={20} strokeWidth={1.75} aria-hidden />
          <span className="admin-nav-text">Đánh giá</span>
        </button>
        
        <button
          type="button"
          className={`admin-nav-item ${tab === 'vouchers' ? 'active' : ''}`}
          onClick={() => onChange('vouchers')}
          role="tab"
          aria-selected={tab === 'vouchers'}
        >
          <Tag className="admin-nav-icon" size={20} strokeWidth={1.75} aria-hidden />
          <span className="admin-nav-text">Vouchers</span>
        </button>

        <button
          type="button"
          className={`admin-nav-item ${tab === 'users' ? 'active' : ''}`}
          onClick={() => onChange('users')}
          role="tab"
          aria-selected={tab === 'users'}
        >
          <Users className="admin-nav-icon" size={20} strokeWidth={1.75} aria-hidden />
          <span className="admin-nav-text">Người dùng</span>
        </button>

        <button
          type="button"
          className={`admin-nav-item ${tab === 'blog' ? 'active' : ''}`}
          onClick={() => onChange('blog')}
          role="tab"
          aria-selected={tab === 'blog'}
        >
          <FileText className="admin-nav-icon" size={20} strokeWidth={1.75} aria-hidden />
          <span className="admin-nav-text">Blog</span>
        </button>



        <button
          type="button"
          className={`admin-nav-item ${tab === 'contact-messages' ? 'active' : ''}`}
          onClick={() => onChange('contact-messages')}
          role="tab"
          aria-selected={tab === 'contact-messages'}
        >
          <MessageSquare className="admin-nav-icon" size={20} strokeWidth={1.75} aria-hidden />
          <span className="admin-nav-text">Tin liên hệ</span>
        </button>
      </nav>
    </aside>
  );
}
