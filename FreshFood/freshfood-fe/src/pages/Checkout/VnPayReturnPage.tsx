import { useEffect, useMemo } from 'react';
import { useLocation, useNavigate } from 'react-router-dom';
import { CheckCircle, XCircle, ArrowLeft } from 'lucide-react';
import { useCart } from '../../context/CartContext';
import { apiService } from '../../services/api';
import { useAuth } from '../../context/AuthContext';

export const VnPayReturnPage = () => {
  const { search } = useLocation();
  const navigate = useNavigate();
  const { clearCart } = useCart();
  const { user } = useAuth();
  const clearPending = () => {
    try {
      localStorage.removeItem('freshfood_pending_online_payment_v1');
    } catch {
      // ignore
    }
  };

  const params = useMemo(() => new URLSearchParams(search), [search]);
  const orderCode = params.get('orderCode') || '';
  const code = params.get('code') || '';
  const valid = params.get('valid') === '1';
  const success = valid && code === '00';
  const orderId = params.get('orderId') || '';

  useEffect(() => {
    if (success) {
      clearCart();
      clearPending();
    }
  }, [success, clearCart]);

  useEffect(() => {
    // Fallback: nếu thanh toán fail nhưng chữ ký hợp lệ, đảm bảo BE đánh Failed + hoàn kho.
    const id = Number(orderId);
    const uid = user?.userID ?? 0;
    if (success) return;
    if (!valid) return;
    if (!Number.isFinite(id) || id <= 0) return;
    if (!Number.isFinite(uid) || uid <= 0) return;
    (async () => {
      try {
        await apiService.markOrderPaymentFailed(id, uid, 'VNPAY', code || null);
      } catch {
        // ignore
      }
    })();
    return () => {};
  }, [orderId, user?.userID, valid, success, code]);

  return (
    <div className="empty-state" style={{padding: '5rem 2rem', textAlign: 'center'}}>
      {success ? (
        <>
          <CheckCircle size={80} color="var(--primary)" style={{marginBottom: '1.5rem'}} />
          <h2>Thanh toán thành công!</h2>
          <p>Đơn hàng #{orderCode} đã được thanh toán qua VNPay.</p>
          <button className="btn-primary" style={{marginTop: '2rem'}} onClick={() => navigate('/')}>
            Tiếp tục mua sắm
          </button>
        </>
      ) : (
        <>
          <XCircle size={80} color="#e74c3c" style={{marginBottom: '1.5rem'}} />
          <h2>Thanh toán chưa thành công</h2>
          <p>
            {valid ? `Mã phản hồi: ${code}` : 'Chữ ký không hợp lệ hoặc dữ liệu trả về không đúng.'}
          </p>
          <div style={{marginTop: '2rem', display: 'flex', gap: '1rem', justifyContent: 'center', flexWrap: 'wrap'}}>
            <button className="btn-primary" onClick={() => navigate('/checkout')}>Quay lại thanh toán</button>
            <button className="btn-login" onClick={() => navigate('/cart')} style={{textDecoration: 'none'}}>
              <ArrowLeft size={16} /> Về giỏ hàng
            </button>
          </div>
        </>
      )}
    </div>
  );
};

