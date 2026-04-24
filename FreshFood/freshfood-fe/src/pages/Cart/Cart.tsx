import { Trash2, Plus, Minus, ArrowLeft, ArrowRight, ShieldCheck } from 'lucide-react';
import { useCart } from '../../context/CartContext';
import { useNavigate } from 'react-router-dom';
import { resolveMediaUrl } from '../../services/api';

export const CartPage = () => {
  const { cart, removeFromCart, updateQuantity, totalPrice, totalItems } = useCart();
  const navigate = useNavigate();

  const formatPrice = (price: number) => {
    return new Intl.NumberFormat('vi-VN', { style: 'currency', currency: 'VND' }).format(price);
  };

  const subtotal = totalPrice;
  const estimatedTax = Math.round(subtotal * 0.015);
  // Shipping is chosen at Checkout (shipping method selection),
  // so Cart only shows subtotal + estimated VAT.
  const grandTotal = subtotal + estimatedTax;

  if (cart.length === 0) {
    return (
      <div className="empty-state" style={{padding: '5rem 2rem', textAlign: 'center'}}>
        <h2>Giỏ hàng của bạn đang trống</h2>
        <p>Hãy dạo quanh cửa hàng và chọn những thực phẩm tươi ngon nhất nhé!</p>
        <button className="btn-primary" style={{marginTop: '2rem'}} onClick={() => navigate('/')}>
          Quay lại cửa hàng
        </button>
      </div>
    );
  }

  return (
    <div className="cart-page">
      <div className="container">
        <div className="cart-header">
          <button className="cart-back" onClick={() => navigate(-1)} aria-label="Quay lại">
            <ArrowLeft />
          </button>
          <div>
            <h1 className="cart-title">Giỏ hàng</h1>
            <p className="cart-subtitle">{totalItems} sản phẩm đang chờ được giao từ nông trại đến bếp của bạn.</p>
          </div>
        </div>

        <div className="cart-layout">
          <section className="cart-items-card">
            {cart.map(item => {
              const img = resolveMediaUrl(item.product.productImages?.[0]?.imageURL);
              const subtitle = `${item.product.category?.categoryName || 'Fresh'} • ${item.quantity} ${item.product.unit || 'items'}`;
              const unitPrice =
                typeof item.product.discountPrice === 'number' && item.product.discountPrice > 0
                  ? item.product.discountPrice
                  : item.product.price;
              const originalUnitPrice = item.product.price;
              const hasDiscount = unitPrice !== originalUnitPrice;
              const lineTotal = unitPrice * item.quantity;
              const originalLineTotal = originalUnitPrice * item.quantity;
              return (
                <div key={item.product.productID} className="cart-item-row">
                  <div className="cart-item-left">
                    <div className="cart-item-img">
                      {img ? <img src={img} alt={item.product.productName} /> : null}
                    </div>
                    <div className="cart-item-meta">
                      <div className="cart-item-name">{item.product.productName}</div>
                      <div className="cart-item-sub">{subtitle}</div>
                    </div>
                  </div>

                  <div className="cart-item-right">
                    <div className="cart-qty-pill" aria-label="Số lượng">
                      <button
                        type="button"
                        onClick={() => updateQuantity(item.product.productID, item.quantity - 1)}
                        disabled={item.quantity <= 1}
                        aria-label="Giảm"
                      >
                        <Minus size={16} />
                      </button>
                      <span>{item.quantity}</span>
                      <button
                        type="button"
                        onClick={() => updateQuantity(item.product.productID, item.quantity + 1)}
                        aria-label="Tăng"
                      >
                        <Plus size={16} />
                      </button>
                    </div>

                    <div className="cart-item-price">
                      <div className="cart-item-price-total">{formatPrice(lineTotal)}</div>
                    </div>

                    <button
                      type="button"
                      className="cart-remove"
                      onClick={() => removeFromCart(item.product.productID)}
                    >
                      <Trash2 size={14} />
                      
                    </button>
                  </div>
                </div>
              );
            })}

            <div className="cart-bottom-row">
              <button className="cart-continue" type="button" onClick={() => navigate('/products')}>
                <ArrowLeft size={16} />
                Tiếp tục mua sắm
              </button>
              
            </div>
          </section>

          <aside className="cart-summary">
            <div className="summary-card">
              <h2>Tóm tắt đơn hàng.</h2>

              <div className="summary-lines">
                <div className="summary-line">
                  <span>Tạm tính</span>
                  <span>{formatPrice(subtotal)}</span>
                </div>
                <div className="summary-line">
                  <span>Thuế (ước tính)</span>
                  <span>{formatPrice(estimatedTax)}</span>
                </div>
              </div>

              <div className="summary-total">
                <span>Tổng cộng</span>
                <span>{formatPrice(grandTotal)}</span>
              </div>

              <button className="summary-checkout" type="button" onClick={() => navigate('/checkout')}>
                Checkout <ArrowRight size={18} />
              </button>

              <p className="summary-legal">
                Bằng cách tiếp tục thanh toán, bạn đồng ý với{' '}
                <a className="auth-legal-link" href="/terms" target="_blank" rel="noreferrer">
                  điều khoản dịch vụ
                </a>{' '}
                và{' '}
                <a className="auth-legal-link" href="/privacy" target="_blank" rel="noreferrer">
                  chính sách bảo mật
                </a>{' '}
                của FreshFood.
              </p>
            </div>

            <div className="guarantee-card">
              <div className="guarantee-icon">
                <ShieldCheck size={18} />
              </div>
              <div>
                <div className="guarantee-title">Đảm bảo chất lượng</div>
                <div className="guarantee-sub">Nếu bất kỳ sản phẩm nào không tươi ngon khi nhận hàng, chúng tôi sẽ hoàn tiền hoặc đổi sản phẩm khác ngay lập tức.</div>
              </div>
            </div>
          </aside>
        </div>
      </div>
    </div>
  );
};
