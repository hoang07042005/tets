import { useEffect, useMemo, useState } from 'react';
import { useCart } from '../../context/CartContext';
import { apiService, resolveMediaUrl } from '../../services/api';
import { Link, useNavigate } from 'react-router-dom';
import { CheckCircle, CreditCard, Truck, ArrowLeft, User, Mail, MapPin } from 'lucide-react';
import { useAuth } from '../../context/AuthContext';
import type { ShippingMethod, UserAddress } from '../../types';

type OnlinePayMethod = 'VNPAY' | 'MOMO';
type PendingOnlinePaymentDraft = {
  orderId: number;
  method: OnlinePayMethod;
  cartSig: string;
  total: number;
  createdAt: number; // epoch ms
};

const PENDING_ONLINE_PAYMENT_KEY = 'freshfood_pending_online_payment_v1';

export const CheckoutPage = () => {
  const { cart, totalItems, totalPrice, clearCart } = useCart();
  const { user, isAuthenticated } = useAuth();
  const navigate = useNavigate();
  const [loading, setLoading] = useState(false);
  const [success, setSuccess] = useState(false);
  /** Đặt hàng không đăng nhập — gợi ý tạo mật khẩu sau. */
  const [successWasGuest, setSuccessWasGuest] = useState(false);
  const [paymentMethod, setPaymentMethod] = useState<'COD' | 'VNPAY' | 'MOMO'>('COD');
  const [shippingMethods, setShippingMethods] = useState<ShippingMethod[]>([]);
  const [shippingMethodId, setShippingMethodId] = useState<number | null>(null);
  const [voucherCode, setVoucherCode] = useState('');
  const [voucherErr, setVoucherErr] = useState<string | null>(null);
  const [voucherApplied, setVoucherApplied] = useState<{
    code: string;
    discountAmount: number;
    subtotalAfterDiscount: number;
    taxAfterDiscount: number;
    grandTotal: number;
  } | null>(null);
  const savedVoucherCodes = useMemo(() => {
    try {
      const raw = localStorage.getItem('freshfood_saved_vouchers');
      const arr = raw ? (JSON.parse(raw) as string[]) : [];
      return Array.isArray(arr) ? arr.filter(Boolean) : [];
    } catch {
      return [];
    }
  }, []);
  const [availableSavedVoucherCodes, setAvailableSavedVoucherCodes] = useState<string[]>(savedVoucherCodes);

  useEffect(() => {
    // Nếu đã đăng nhập: lọc bỏ mã đã dùng / hết hạn bằng API
    if (!isAuthenticated || !user || savedVoucherCodes.length === 0) {
      setAvailableSavedVoucherCodes(savedVoucherCodes);
      return;
    }

    let cancelled = false;
    (async () => {
      try {
        const active = await apiService.getActiveVouchers(user.userID);
        const activeCodes = new Set((active || []).map(v => (v.code || '').trim()).filter(Boolean));
        const filtered = savedVoucherCodes.filter(c => activeCodes.has(c));
        if (!cancelled) setAvailableSavedVoucherCodes(filtered);
      } catch {
        // Nếu lỗi API thì fallback: vẫn hiển thị mã đã lưu (validate sẽ chặn khi áp dụng)
        if (!cancelled) setAvailableSavedVoucherCodes(savedVoucherCodes);
      }
    })();

    return () => {
      cancelled = true;
    };
  }, [isAuthenticated, user?.userID, savedVoucherCodes]);

  useEffect(() => {
    let cancelled = false;
    (async () => {
      try {
        const sms = await apiService.getShippingMethods();
        if (cancelled) return;
        setShippingMethods(sms || []);
        if (!shippingMethodId && sms && sms.length > 0) {
          setShippingMethodId(sms[0].methodID);
        }
      } catch {
        if (!cancelled) setShippingMethods([]);
      }
    })();
    return () => {
      cancelled = true;
    };
  }, []);

  const [savedAddresses, setSavedAddresses] = useState<UserAddress[]>([]);
  /** Đã đăng nhập và có ít nhất một địa chỉ lưu → chọn saved | custom */
  const [addressSource, setAddressSource] = useState<'saved' | 'custom'>('custom');
  const [selectedAddressId, setSelectedAddressId] = useState<number | null>(null);

  useEffect(() => {
    if (!isAuthenticated || !user) {
      setSavedAddresses([]);
      setAddressSource('custom');
      setSelectedAddressId(null);
      return;
    }

    let cancelled = false;
    (async () => {
      try {
        const list = await apiService.getUserAddresses(user.userID);
        if (cancelled) return;
        setSavedAddresses(list);
        if (list.length > 0) {
          const def = list.find((a) => a.isDefault) ?? list[0];
          setAddressSource('saved');
          setSelectedAddressId(def.userAddressID);
          setFormData((fd) => ({
            ...fd,
            fullName: def.recipientName || user.fullName || '',
            email: user.email || '',
            phone: def.phone || user.phone || '',
            address: def.addressLine || '',
          }));
        } else {
          setAddressSource('custom');
          setSelectedAddressId(null);
          setFormData((fd) => ({
            ...fd,
            fullName: user.fullName || '',
            email: user.email || '',
            phone: user.phone || '',
            address: user.address || '',
          }));
        }
      } catch {
        if (cancelled) return;
        setSavedAddresses([]);
        setAddressSource('custom');
        setSelectedAddressId(null);
        setFormData((fd) => ({
          ...fd,
          fullName: user.fullName || '',
          email: user.email || '',
          phone: user.phone || '',
          address: user.address || '',
        }));
      }
    })();

    return () => {
      cancelled = true;
    };
  }, [isAuthenticated, user?.userID]);

  const [formData, setFormData] = useState({
    fullName: '',
    phone: '',
    email: '',
    address: '',
    notes: ''
  });

  const loadPendingOnlineDraft = (): PendingOnlinePaymentDraft | null => {
    try {
      const raw = localStorage.getItem(PENDING_ONLINE_PAYMENT_KEY);
      if (!raw) return null;
      const j = JSON.parse(raw) as Partial<PendingOnlinePaymentDraft>;
      if (!j || typeof j.orderId !== 'number' || j.orderId <= 0) return null;
      if (j.method !== 'VNPAY' && j.method !== 'MOMO') return null;
      if (typeof j.cartSig !== 'string' || !j.cartSig) return null;
      if (typeof j.total !== 'number' || !Number.isFinite(j.total)) return null;
      if (typeof j.createdAt !== 'number' || !Number.isFinite(j.createdAt)) return null;
      return j as PendingOnlinePaymentDraft;
    } catch {
      return null;
    }
  };

  const savePendingOnlineDraft = (draft: PendingOnlinePaymentDraft) => {
    try {
      localStorage.setItem(PENDING_ONLINE_PAYMENT_KEY, JSON.stringify(draft));
    } catch {
      // ignore
    }
  };

  const clearPendingOnlineDraft = () => {
    try {
      localStorage.removeItem(PENDING_ONLINE_PAYMENT_KEY);
    } catch {
      // ignore
    }
  };

  const handleChange = (e: React.ChangeEvent<HTMLInputElement | HTMLTextAreaElement>) => {
    setFormData({ ...formData, [e.target.name]: e.target.value });
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    const asGuest = !isAuthenticated || !user;
    setLoading(true);

    try {
      const needManualAddress = asGuest || addressSource === 'custom';
      if (needManualAddress) {
        if (
          !formData.fullName.trim() ||
          !formData.email.trim() ||
          !formData.phone.trim() ||
          !formData.address.trim()
        ) {
          alert('Vui lòng điền đầy đủ thông tin nhận hàng.');
          setLoading(false);
          return;
        }
      } else if (!user || !selectedAddressId) {
        alert('Chọn một địa chỉ đã lưu hoặc chọn nhập địa chỉ mới.');
        setLoading(false);
        return;
      }

      const shippingAddress = needManualAddress
        ? `${formData.fullName.trim()} - ${formData.phone.trim()} - ${formData.email.trim()} - ${formData.address.trim()}`
        : '';

      const orderData = {
        ...(asGuest
          ? {
              guestCheckout: {
                fullName: formData.fullName.trim(),
                email: formData.email.trim(),
                phone: formData.phone.trim(),
              },
            }
          : { userID: user!.userID }),
        shippingAddress,
        ...(!asGuest && !needManualAddress && selectedAddressId
          ? { shippingAddressId: selectedAddressId }
          : {}),
        shippingMethodID: shippingMethodId ?? undefined,
        paymentMethod,
        voucherCode: !asGuest && voucherApplied?.code ? voucherApplied.code : undefined,
        items: cart.map(item => ({
          productID: item.product.productID,
          quantity: item.quantity
        }))
      };

      // For online payments, reuse the latest pending online order if cart is unchanged.
      if (!asGuest && (paymentMethod === 'VNPAY' || paymentMethod === 'MOMO')) {
        const draft = loadPendingOnlineDraft();
        const maxAgeMs = 1000 * 60 * 60 * 6; // 6 hours
        const stillFresh = draft && Date.now() - draft.createdAt <= maxAgeMs;
        const sameCart = draft && draft.cartSig === cartSig && Math.abs((draft.total ?? 0) - grandTotal) < 0.01;
        const sameMethod = draft && draft.method === paymentMethod;

        if (draft && stillFresh && sameCart && sameMethod) {
          try {
            const ord = await apiService.getOrder(draft.orderId);
            const st = (ord?.status || '').trim().toLowerCase();
            const latest = (ord?.payments || []).slice().sort((a, b) => (a.paymentDate || '').localeCompare(b.paymentDate || '')).pop();
            const paid = ['paid', 'success'].includes((latest?.status || '').trim().toLowerCase());
            const orderDone = st && st !== 'pending'; // after payment success we switch to Processing

            if (!paid && !orderDone) {
              if (paymentMethod === 'VNPAY') {
                const url = await apiService.createVnPayPaymentUrl(Number(draft.orderId));
                window.location.href = url;
                return;
              }
              if (paymentMethod === 'MOMO') {
                const r = await apiService.createMomoPaymentUrl(Number(draft.orderId), 'method');
                const url = r.paymentUrl || r.deeplink || r.qrCodeUrl;
                if (!url) {
                  const extra =
                    r.resultCode != null || r.message
                      ? ` (resultCode=${r.resultCode ?? 'N/A'}${r.message ? `, message=${r.message}` : ''})`
                      : '';
                  throw new Error(`Không lấy được link thanh toán MoMo.${extra}`);
                }
                window.location.href = url;
                return;
              }
            } else {
              // Draft is no longer valid (already paid/processing) -> clear it.
              clearPendingOnlineDraft();
            }
          } catch {
            // If can't validate, fall through to create a new order.
          }
        }
      }

      const createdOrder = await apiService.createOrder(orderData);
      const createdOrderCode =
        (createdOrder?.orderCode ?? createdOrder?.OrderCode ?? createdOrder?.order_code ?? createdOrder?.orderCODE ?? '').toString().trim();

      if (paymentMethod === 'VNPAY') {
        const orderId = createdOrder.orderID ?? createdOrder.orderId ?? createdOrder.OrderID ?? createdOrder.OrderId;
        if (asGuest) {
          if (!createdOrderCode) throw new Error('Thiếu mã đơn hàng để tạo link thanh toán.');
          const url = await apiService.createVnPayPaymentUrlPublic(createdOrderCode);
          window.location.href = url;
          return;
        }
        if (!orderId) throw new Error('Missing orderId from API');
        savePendingOnlineDraft({ orderId: Number(orderId), method: 'VNPAY', cartSig, total: grandTotal, createdAt: Date.now() });
        const url = await apiService.createVnPayPaymentUrl(Number(orderId));
        window.location.href = url;
        return;
      }

      if (paymentMethod === 'MOMO') {
        const orderId = createdOrder.orderID ?? createdOrder.orderId ?? createdOrder.OrderID ?? createdOrder.OrderId;
        if (asGuest) {
          if (!createdOrderCode) throw new Error('Thiếu mã đơn hàng để tạo link thanh toán.');
          const r = await apiService.createMomoPaymentUrlPublic(createdOrderCode, 'method');
          const url = r.paymentUrl || r.deeplink || r.qrCodeUrl;
          if (!url) {
            const extra =
              r.resultCode != null || r.message
                ? ` (resultCode=${r.resultCode ?? 'N/A'}${r.message ? `, message=${r.message}` : ''})`
                : '';
            throw new Error(`Không lấy được link thanh toán MoMo.${extra}`);
          }
          window.location.href = url;
          return;
        }
        if (!orderId) throw new Error('Missing orderId from API');
        savePendingOnlineDraft({ orderId: Number(orderId), method: 'MOMO', cartSig, total: grandTotal, createdAt: Date.now() });
        // MoMo AIO: redirect to MoMo-hosted "choose payment method" page (Wallet/ATM/Credit...)
        const r = await apiService.createMomoPaymentUrl(Number(orderId), 'method');
        const url = r.paymentUrl || r.deeplink || r.qrCodeUrl;
        if (!url) {
          const extra =
            r.resultCode != null || r.message
              ? ` (resultCode=${r.resultCode ?? 'N/A'}${r.message ? `, message=${r.message}` : ''})`
              : '';
          throw new Error(`Không lấy được link thanh toán MoMo.${extra}`);
        }
        window.location.href = url;
        return;
      }

      setSuccessWasGuest(asGuest);
      setSuccess(true);
      clearCart();
      clearPendingOnlineDraft();
    } catch (error) {
      const msg = error instanceof Error ? error.message : 'Đã xảy ra lỗi khi đặt hàng. Vui lòng thử lại.';
      alert(msg);
      console.error(error);
    } finally {
      setLoading(false);
    }
  };

  const formatPrice = (price: number) => {
    return new Intl.NumberFormat('vi-VN', { style: 'currency', currency: 'VND' }).format(price);
  };

  // Keep totals consistent with Cart page
  const subtotal = totalPrice;
  const selectedShipping = useMemo(() => shippingMethods.find(sm => sm.methodID === shippingMethodId) || null, [shippingMethods, shippingMethodId]);
  const shipping = subtotal >= 200000 ? 0 : (selectedShipping?.baseCost ?? 30000);
  const estimatedTax = Math.round(subtotal * 0.015);
  const displayTax = voucherApplied?.taxAfterDiscount ?? estimatedTax;
  const grandTotal = voucherApplied?.grandTotal ?? (subtotal + shipping + estimatedTax);

  const cartSig = useMemo(() => {
    // Stable signature for "same cart" detection (sorted items).
    const items = (cart || [])
      .map((x) => ({ id: x.product.productID, q: x.quantity }))
      .sort((a, b) => a.id - b.id);
    return JSON.stringify({
      items,
      shippingMethodId: shippingMethodId ?? null,
      voucher: voucherApplied?.code ?? null,
      // Total is used to prevent reusing when pricing changed.
      total: grandTotal,
      // User scope (avoid cross-account reuse in shared browser).
      userId: user?.userID ?? null,
      guestEmail: !isAuthenticated ? (formData.email || '').trim().toLowerCase() : null
    });
  }, [cart, shippingMethodId, voucherApplied?.code, grandTotal, user?.userID, isAuthenticated, formData.email]);

  if (success) {
    return (
      <div className="empty-state" style={{ padding: '5rem 2rem', textAlign: 'center' }}>
        <CheckCircle size={80} color="var(--primary)" style={{ marginBottom: '1.5rem' }} />
        <h2>Đặt hàng thành công!</h2>
        <p>Cảm ơn bạn đã tin tưởng FreshFood. Đơn hàng của bạn đang được xử lý.</p>
        {successWasGuest ? (
          <div
            style={{
              maxWidth: 500,
              margin: '1.15rem auto 0',
              padding: '1.1rem 1.2rem',
              borderRadius: 12,
              border: '1px solid rgba(46, 204, 113, 0.35)',
              background: 'rgba(46, 204, 113, 0.08)',
              color: '#1f2937',
              lineHeight: 1.55,
              fontSize: '0.98rem',
              textAlign: 'left',
            }}
          >
            <strong>Chúng tôi đã tạo tài khoản cho bạn.</strong>
            <p style={{ margin: '0.55rem 0 0' }}>
              Vui lòng <strong>kiểm tra hộp thư email</strong> (và thư mục spam) vừa nhập lúc đặt hàng. Email có nút{' '}
              <strong>Tạo mật khẩu</strong> — đó là liên kết riêng, <strong>không phải</strong> trang “Quên mật khẩu”.
            </p>
            <p style={{ margin: '0.5rem 0 0', fontSize: '0.9rem', color: '#4b5563' }}>
              Nếu không thấy email: đợi vài phút hoặc dùng{' '}
              <Link to="/forgot-password" style={{ color: 'var(--primary)', fontWeight: 800 }}>
                Quên mật khẩu
              </Link>{' '}
              cùng email để nhận link khác. Bạn cũng có thể{' '}
              <Link to="/register" style={{ color: 'var(--primary)', fontWeight: 800 }}>
                đăng ký
              </Link>{' '}
              cùng email để gộp tài khoản và đặt mật khẩu tại form đăng ký.
            </p>
          </div>
        ) : null}
        <button className="btn-primary" style={{ marginTop: '2rem' }} onClick={() => navigate('/')}>
          Tiếp tục mua sắm
        </button>
      </div>
    );
  }

  if (cart.length === 0) {
    return <div className="empty-state" style={{padding: '5rem 2rem', textAlign: 'center'}}><h2>Giỏ hàng trống</h2><button onClick={() => navigate('/')} className="btn-primary">Quay lại cửa hàng</button></div>;
  }

  return (
    <div className="checkout-page">
      <div className="checkout-topbar">
        <button className="checkout-back" type="button" onClick={() => navigate(-1)} aria-label="Quay lại">
          <ArrowLeft />
        </button>
        <h1 className="checkout-title">Thanh toán</h1>
        <p className="muted" style={{ fontSize: '0.9rem', margin: '0.35rem 0 0', maxWidth: 560, lineHeight: 1.5 }}>
          {isAuthenticated
            ? 'Kiểm tra thông tin nhận hàng và hoàn tất đơn.'
            : 'Đặt hàng không cần đăng nhập. Sau đơn thành công, hệ thống tạo tài khoản theo email bạn nhập và gửi email có nút Tạo mật khẩu (xem ô bên dưới).'}
        </p>
      </div>

      <div className="checkout-layout">
        {/* Left Side: Forms */}
        <div className="checkout-form-section">
          {/* Shipping Card */}
          <div className="checkout-card">
            <h2><Truck className="text-primary" /> Thông tin nhận hàng</h2>
            {!isAuthenticated ? (
              <div
                role="note"
                style={{
                  marginBottom: '1.1rem',
                  padding: '0.85rem 1rem',
                  borderRadius: 12,
                  border: '1px solid rgba(46, 204, 113, 0.35)',
                  background: 'rgba(46, 204, 113, 0.08)',
                  fontSize: '0.88rem',
                  lineHeight: 1.55,
                  color: '#1f2937',
                  textAlign: 'left',
                }}
              >
                <strong style={{ display: 'block', marginBottom: '0.35rem' }}>Bạn đang đặt hàng với tư cách khách</strong>
                Sau khi đặt hàng thành công, chúng tôi <strong>tạo tài khoản</strong> gắn với <strong>email</strong> bạn nhập bên dưới và gửi
                email có nút <strong>Tạo mật khẩu</strong> (liên kết + mã riêng, hiệu lực 48 giờ) — đó là cách bạn đặt mật khẩu lần đầu,{' '}
                <strong>không phải</strong> trang “Quên mật khẩu”. Nếu không nhận được thư, bạn vẫn có thể dùng{' '}
                <Link to="/forgot-password" style={{ color: 'var(--primary)', fontWeight: 800 }}>
                  Quên mật khẩu
                </Link>{' '}
                hoặc{' '}
                <Link to="/register" style={{ color: 'var(--primary)', fontWeight: 800 }}>
                  đăng ký
                </Link>{' '}
                cùng email.
              </div>
            ) : null}
            {isAuthenticated && user && savedAddresses.length > 0 ? (
              <div
                style={{
                  marginBottom: '1rem',
                  padding: '0.9rem 1rem',
                  borderRadius: 12,
                  border: '1px solid rgba(17,24,39,0.1)',
                  background: '#fafafa',
                }}
              >
                <div style={{ fontWeight: 800, marginBottom: '0.65rem', display: 'flex', alignItems: 'center', gap: '0.4rem' }}>
                  <MapPin size={18} /> Địa chỉ giao hàng
                </div>
                <label style={{ display: 'flex', alignItems: 'flex-start', gap: '0.5rem', cursor: 'pointer', marginBottom: '0.5rem' }}>
                  <input
                    type="radio"
                    name="addr-src"
                    checked={addressSource === 'saved'}
                    onChange={() => {
                      setAddressSource('saved');
                      const def = savedAddresses.find((a) => a.isDefault) ?? savedAddresses[0];
                      if (def) {
                        setSelectedAddressId(def.userAddressID);
                        if (user) {
                          setFormData((fd) => ({
                            ...fd,
                            fullName: def.recipientName || user.fullName || '',
                            email: user.email || '',
                            phone: def.phone || user.phone || '',
                            address: def.addressLine || '',
                          }));
                        }
                      }
                    }}
                  />
                  <span style={{ fontSize: '0.92rem', lineHeight: 1.45 }}>Dùng địa chỉ đã lưu</span>
                </label>
                {addressSource === 'saved' ? (
                  <div style={{ marginLeft: '1.5rem', display: 'flex', flexDirection: 'column', gap: '0.45rem' }}>
                    {savedAddresses.map((a) => (
                      <label
                        key={a.userAddressID}
                        style={{
                          display: 'flex',
                          gap: '0.5rem',
                          alignItems: 'flex-start',
                          cursor: 'pointer',
                          padding: '0.5rem 0.65rem',
                          borderRadius: 10,
                          border:
                            selectedAddressId === a.userAddressID
                              ? '1px solid rgba(46, 204, 113, 0.55)'
                              : '1px solid rgba(17,24,39,0.08)',
                          background: selectedAddressId === a.userAddressID ? 'rgba(46, 204, 113, 0.08)' : '#fff',
                        }}
                      >
                        <input
                          type="radio"
                          name="saved-addr"
                          checked={selectedAddressId === a.userAddressID}
                          onChange={() => {
                            setSelectedAddressId(a.userAddressID);
                            if (user) {
                              setFormData((fd) => ({
                                ...fd,
                                fullName: a.recipientName || user.fullName || '',
                                email: user.email || '',
                                phone: a.phone || user.phone || '',
                                address: a.addressLine || '',
                              }));
                            }
                          }}
                        />
                        <span style={{ fontSize: '0.88rem', lineHeight: 1.45 }}>
                          {(a.label || 'Địa chỉ').trim()}
                          {a.isDefault ? (
                            <span style={{ marginLeft: '0.35rem', color: 'var(--primary-dark)', fontWeight: 800 }}>(Mặc định)</span>
                          ) : null}
                          <br />
                          <span style={{ color: '#4b5563' }}>
                            {a.recipientName}
                            {a.phone ? ` · ${a.phone}` : ''} — {a.addressLine}
                          </span>
                        </span>
                      </label>
                    ))}
                  </div>
                ) : null}
                <label style={{ display: 'flex', alignItems: 'flex-start', gap: '0.5rem', cursor: 'pointer', marginTop: '0.55rem' }}>
                  <input
                    type="radio"
                    name="addr-src"
                    checked={addressSource === 'custom'}
                    onChange={() => {
                      setAddressSource('custom');
                      const sel = savedAddresses.find((x) => x.userAddressID === selectedAddressId);
                      setFormData((fd) => ({
                        ...fd,
                        fullName: sel?.recipientName || user.fullName || '',
                        phone: sel?.phone || user.phone || '',
                        email: user.email || '',
                        address: sel?.addressLine || user.address || '',
                      }));
                    }}
                  />
                  <span style={{ fontSize: '0.92rem', lineHeight: 1.45 }}>Nhập địa chỉ khác (một lần)</span>
                </label>
                <p className="muted" style={{ margin: '0.65rem 0 0', fontSize: '0.82rem' }}>
                  Quản lý sổ địa chỉ tại{' '}
                  <Link to="/profile" style={{ color: 'var(--primary)', fontWeight: 800 }}>
                    Hồ sơ
                  </Link>
                  .
                </p>
              </div>
            ) : null}
            <form id="checkout-form" onSubmit={handleSubmit} className="form-grid">
              <div className="input-wrapper full-width">
                <User className="input-icon" size={20} />
                <input 
                  type="text" name="fullName" placeholder="Họ và tên người nhận" required={!isAuthenticated || addressSource === 'custom'}
                  value={formData.fullName} onChange={handleChange}
                  disabled={Boolean(isAuthenticated && addressSource === 'saved' && savedAddresses.length > 0)}
                />
              </div>
              <div className="input-wrapper">
                <Mail className="input-icon" size={20} />
                <input 
                  type="email" name="email" placeholder="Địa chỉ Email" required={!isAuthenticated || addressSource === 'custom'}
                  value={formData.email} onChange={handleChange}
                  disabled={Boolean(isAuthenticated && addressSource === 'saved' && savedAddresses.length > 0)}
                />
              </div>
              <div className="input-wrapper">
                <Truck className="input-icon" size={20} />
                <input 
                  type="text" name="phone" placeholder="Số điện thoại" required={!isAuthenticated || addressSource === 'custom'}
                  value={formData.phone} onChange={handleChange}
                  disabled={Boolean(isAuthenticated && addressSource === 'saved' && savedAddresses.length > 0)}
                />
              </div>
              <div className="input-wrapper full-width">
                <CreditCard className="input-icon" size={20} />
                <input 
                  type="text" name="address" placeholder="Địa chỉ giao hàng chi tiết" required={!isAuthenticated || addressSource === 'custom'}
                  value={formData.address} onChange={handleChange}
                  disabled={Boolean(isAuthenticated && addressSource === 'saved' && savedAddresses.length > 0)}
                />
              </div>
              <div className="input-wrapper full-width">
                <User className="input-icon textarea-icon" size={20} />
                <textarea 
                  name="notes" placeholder="Ghi chú đơn hàng (Ví dụ: Giao giờ hành chính...)" rows={3}
                  value={formData.notes} onChange={handleChange}
                  style={{paddingLeft: '3rem'}}
                ></textarea>
              </div>
            </form>
            <div className="checkout-shipping-method">
              <div className="checkout-shipping-label">Phương thức vận chuyển</div>
              <select
                value={shippingMethodId ?? ''}
                onChange={(e) => {
                  const v = Number(e.target.value);
                  setShippingMethodId(Number.isFinite(v) ? v : null);
                  setVoucherApplied(null);
                  setVoucherErr(null);
                }}
                style={{ width: '100%', height: '44px', borderRadius: '12px', border: '1px solid #ddd', padding: '0 0.9rem', background: '#fff' }}
              >
                {shippingMethods.length === 0 ? (
                  <option value="">(Chưa có phương thức vận chuyển)</option>
                ) : (
                  shippingMethods.map((sm) => (
                    <option key={sm.methodID} value={sm.methodID}>
                      {sm.methodName} · {subtotal >= 200000 ? 'Freeship' : formatPrice(Number(sm.baseCost))}{sm.estimatedDays ? ` · ${sm.estimatedDays} ngày` : ''}
                    </option>
                  ))
                )}
              </select>
              <div className="checkout-shipping-note">
                Freeship áp dụng khi tạm tính ≥ 200.000đ (trước VAT).
              </div>
            </div>
          </div>

          {/* Payment Card */}
          <div className="checkout-card">
            <h2><CreditCard className="text-primary" /> Phương thức thanh toán</h2>
            <div className="checkout-payments">
              <div
                className={`payment-option ${paymentMethod === 'COD' ? 'active' : ''}`}
                onClick={() => {
                  setPaymentMethod('COD');
                }}
                style={{ cursor: 'pointer' }}
              >
                <div
                  className="payment-option__indicator"
                  aria-hidden="true"
                  style={{
                    width: '20px',
                    height: '20px',
                    borderRadius: '50%',
                    border: paymentMethod === 'COD' ? '5px solid var(--primary)' : '2px solid #ddd',
                    background: 'white',
                  }}
                />
                <div className="payment-option__content">
                  <div className="payment-logo payment-logo--img">
                    <img src="/logo-COD.png" alt="COD" loading="lazy" decoding="async" />
                  </div>
                  <span className="sr-only">Thanh toán khi nhận hàng (COD)</span>
                </div>
              </div>
              <div
                className={`payment-option ${paymentMethod === 'VNPAY' ? 'active' : ''}`}
                onClick={() => {
                  setPaymentMethod('VNPAY');
                }}
                style={{ cursor: 'pointer' }}
              >
                <div
                  className="payment-option__indicator"
                  aria-hidden="true"
                  style={{
                    width: '20px',
                    height: '20px',
                    borderRadius: '50%',
                    border: paymentMethod === 'VNPAY' ? '5px solid var(--primary)' : '2px solid #ddd',
                    background: 'white',
                  }}
                />
                <div className="payment-option__content">
                  <div className="payment-logo payment-logo--img">
                    <img src="/vnpay-logo.png" alt="VNPay" loading="lazy" decoding="async" />
                  </div>
                  <span className="sr-only">VNPay</span>
                </div>
              </div>

              <div
                className={`payment-option ${paymentMethod === 'MOMO' ? 'active' : ''}`}
                onClick={() => {
                  setPaymentMethod('MOMO');
                }}
                style={{ cursor: 'pointer' }}
              >
                <div
                  className="payment-option__indicator"
                  aria-hidden="true"
                  style={{
                    width: '20px',
                    height: '20px',
                    borderRadius: '50%',
                    border: paymentMethod === 'MOMO' ? '5px solid var(--primary)' : '2px solid #ddd',
                    background: 'white',
                  }}
                />
                <div className="payment-option__content">
                  <div className="payment-logo payment-logo--img">
                    <img src="/logo-momo.png" alt="MoMo" loading="lazy" decoding="async" />
                  </div>
                  <span className="sr-only">MoMo</span>
                </div>
              </div>

            </div>
          </div>
        </div>

        {/* Right Side: Order Summary */}
        <aside className="order-summary-sticky">
          <div className="checkout-card checkout-summary-card">
            <h2 className="checkout-summary-title">
              Tóm tắt đơn hàng ({totalItems})
            </h2>
            <div className="checkout-summary-items-scroll">
              {cart.map(item => (
                <div key={item.product.productID} style={{display: 'flex', gap: '1rem', marginBottom: '1rem', alignItems: 'center'}}>
                  <div style={{width: '50px', height: '50px', borderRadius: '8px', overflow: 'hidden', border: '1px solid #eee', flexShrink: 0}}>
                    <img
                      src={resolveMediaUrl(item.product.productImages?.[0]?.imageURL)}
                      alt={item.product.productName}
                      style={{ width: '100%', height: '100%', objectFit: 'cover' }}
                    />
                  </div>
                  <div style={{flex: 1}}>
                    <p style={{fontSize: '0.9rem', fontWeight: '600', margin: 0, lineHeight: 1.2}}>{item.product.productName}</p>
                    <p style={{fontSize: '0.8rem', color: '#888', margin: 0}}>SL: {item.quantity}</p>
                  </div>
                  <span style={{fontSize: '0.9rem', fontWeight: '600'}}>{formatPrice(item.product.price * item.quantity)}</span>
                </div>
              ))}
            </div>

            <div className="summary-item">
              <span>Tạm tính</span>
              <span>{formatPrice(subtotal)}</span>
            </div>
            <div className="summary-item">
              <span>Phí vận chuyển</span>
              {shipping === 0 ? (
                <span style={{color: 'var(--primary)', fontWeight: '600'}}>Miễn phí</span>
              ) : (
                <span>{formatPrice(shipping)}</span>
              )}
            </div>
            {voucherApplied && (
              <div className="summary-item">
                <span>Giảm giá ({voucherApplied.code})</span>
                <span style={{ color: 'var(--primary-dark)', fontWeight: 900 }}>
                  -{formatPrice(voucherApplied.discountAmount)}
                </span>
              </div>
            )}
            <div className="summary-item">
              <span>Thuế (ước tính)</span>
              <span>{formatPrice(displayTax)}</span>
            </div>

            <div className="checkout-voucher-block">
              {isAuthenticated && user ? (
                <>
                  <div className="checkout-voucher-row">
                    <input
                      className="checkout-voucher-input"
                      value={voucherCode}
                      onChange={(e) => {
                        setVoucherCode(e.target.value);
                        setVoucherErr(null);
                      }}
                      placeholder="Nhập mã giảm giá"
                    />
                    <button
                      type="button"
                      className="btn-primary checkout-voucher-apply"
                      onClick={async () => {
                        const code = voucherCode.trim();
                        if (!code) {
                          setVoucherErr('Vui lòng nhập mã.');
                          return;
                        }
                        try {
                          const res = await apiService.validateVoucher({
                            userID: user.userID,
                            code,
                            subtotal,
                            shipping,
                            tax: estimatedTax
                          });
                          setVoucherApplied({
                            code: res.code ?? code,
                            discountAmount: Number(res.discountAmount ?? 0),
                            subtotalAfterDiscount: Number(res.subtotalAfterDiscount ?? subtotal),
                            taxAfterDiscount: Number(res.taxAfterDiscount ?? estimatedTax),
                            grandTotal: Number(res.grandTotal ?? grandTotal)
                          });
                          setVoucherErr(null);
                        } catch (e) {
                          setVoucherApplied(null);
                          setVoucherErr(e instanceof Error ? e.message : 'Voucher không hợp lệ.');
                        }
                      }}
                    >
                      Áp dụng
                    </button>
                  </div>

                  {availableSavedVoucherCodes.length > 0 && (
                    <div style={{ marginTop: '0.65rem' }}>
                      <div style={{ fontSize: '0.85rem', fontWeight: 900, color: '#111827', marginBottom: '0.35rem' }}>
                        Mã đã lưu
                      </div>
                      <div style={{ display: 'flex', flexWrap: 'wrap', gap: '0.5rem' }}>
                        {availableSavedVoucherCodes.map((c) => (
                          <button
                            key={c}
                            type="button"
                            onClick={() => {
                              setVoucherApplied(null);
                              setVoucherErr(null);
                              setVoucherCode(c);
                            }}
                            style={{
                              borderRadius: '999px',
                              border: '1px solid rgba(17,24,39,0.12)',
                              padding: '0.35rem 0.7rem',
                              background: 'rgba(46, 204, 113, 0.10)',
                              color: 'var(--primary-dark)',
                              fontWeight: 950,
                              cursor: 'pointer'
                            }}
                          >
                            {c}
                          </button>
                        ))}
                      </div>
                    </div>
                  )}

                  {voucherErr && <div style={{ marginTop: '0.6rem', color: '#b91c1c', fontWeight: 700 }}>{voucherErr}</div>}
                  {voucherApplied && (
                    <div style={{ marginTop: '0.6rem', color: 'var(--primary-dark)', fontWeight: 800 }}>
                      Đã áp dụng <strong>{voucherApplied.code}</strong> · Giảm {formatPrice(voucherApplied.discountAmount)}
                      <button
                        type="button"
                        onClick={() => {
                          setVoucherApplied(null);
                          setVoucherErr(null);
                        }}
                        style={{
                          marginLeft: '0.6rem',
                          border: 'none',
                          background: 'transparent',
                          color: '#6b7280',
                          fontWeight: 900,
                          cursor: 'pointer',
                          textDecoration: 'underline'
                        }}
                      >
                        Bỏ
                      </button>
                    </div>
                  )}
                </>
              ) : (
                <p className="muted" style={{ margin: 0, fontSize: '0.88rem', lineHeight: 1.45 }}>
                  Đăng nhập để áp dụng mã giảm giá (voucher gắn với tài khoản).
                </p>
              )}
            </div>
            
            <div className="summary-total">
              <div>
                <p style={{margin: 0, fontSize: '0.9rem', color: '#888'}}>Tổng cộng</p>
                <strong style={{fontSize: '1.8rem', color: 'var(--accent)'}}>{formatPrice(grandTotal)}</strong>
              </div>
            </div>

            <button 
              type="submit" 
              form="checkout-form"
              className="btn-primary" 
              style={{marginTop: '1.5rem', width: '100%', height: '55px', boxShadow: '0 8px 20px rgba(52, 152, 219, 0.2)'}}
              disabled={loading}
            >
              {loading ? 'Đang xử lý...' : 'XÁC NHẬN ĐẶT HÀNG'}
            </button>
            <p style={{ textAlign: 'center', fontSize: '0.75rem', color: '#aaa', marginTop: '1rem', lineHeight: 1.45 }}>
              Bằng cách nhấn nút, bạn đồng ý với{' '}
              <a className="auth-legal-link" href="/terms" target="_blank" rel="noreferrer">
                Điều khoản dịch vụ
              </a>{' '}
              và{' '}
              <a className="auth-legal-link" href="/privacy" target="_blank" rel="noreferrer">
                Chính sách bảo mật
              </a>{' '}
              của chúng tôi.
              {!isAuthenticated ? (
                <>
                  <br />
                  <span style={{ color: '#6b7280' }}>
                    (Khách: đồng ý tạo tài khoản theo email trên form và nhận email hướng dẫn Tạo mật khẩu.)
                  </span>
                </>
              ) : null}
            </p>
          </div>
        </aside>
      </div>
    </div>
  );
};
