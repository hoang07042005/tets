import { useEffect, useMemo, useState } from 'react';
import type { Voucher } from '../../types';
import { apiService } from '../../services/api';

type Mode = 'create' | 'edit';

type Props = {
  mode: Mode;
  voucherId?: number;
  voucherToken?: string;
  onClose: () => void;
  onSaved: () => void;
};

function toInputDateTimeLocal(iso?: string | null): string {
  if (!iso) return '';
  const d = new Date(iso);
  if (Number.isNaN(d.getTime())) return '';
  const pad = (n: number) => String(n).padStart(2, '0');
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}T${pad(d.getHours())}:${pad(d.getMinutes())}`;
}

function fromInputDateTimeLocal(v: string): string | null {
  const s = (v || '').trim();
  if (!s) return null;
  const d = new Date(s);
  if (Number.isNaN(d.getTime())) return null;
  return d.toISOString();
}

export function AdminVoucherForm({ mode, voucherId, voucherToken, onClose, onSaved }: Props) {
  const [code, setCode] = useState('');
  const [discountType, setDiscountType] = useState<'Percentage' | 'Flat'>('Percentage');
  const [discountValue, setDiscountValue] = useState('');
  const [minOrderAmount, setMinOrderAmount] = useState('');
  const [expiryLocal, setExpiryLocal] = useState('');
  const [isActive, setIsActive] = useState(true);
  const [loading, setLoading] = useState(mode === 'edit');
  const [saving, setSaving] = useState(false);
  const [err, setErr] = useState<string | null>(null);

  const title = useMemo(() => (mode === 'edit' ? 'Sửa voucher' : 'Thêm voucher'), [mode]);

  useEffect(() => {
    if (mode !== 'edit' || (!voucherId && !voucherToken)) {
      setLoading(false);
      return;
    }

    let cancelled = false;
    (async () => {
      try {
        const v: Voucher | null = voucherId
          ? await apiService.getAdminVoucher(voucherId)
          : await apiService.getAdminVoucherByToken(String(voucherToken || '').trim());
        if (!v || cancelled) return;
        setCode(v.code ?? '');
        setDiscountType(((v.discountType || 'Percentage') as any) === 'Flat' ? 'Flat' : 'Percentage');
        setDiscountValue(String(v.discountValue ?? ''));
        setMinOrderAmount(String(v.minOrderAmount ?? ''));
        setExpiryLocal(toInputDateTimeLocal(v.expiryDate));
        setIsActive(!!v.isActive);
      } catch {
        if (!cancelled) setErr('Không tải được voucher.');
      } finally {
        if (!cancelled) setLoading(false);
      }
    })();

    return () => {
      cancelled = true;
    };
  }, [mode, voucherId]);

  const onSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    const c = code.trim().toUpperCase();
    if (!c) {
      setErr('Vui lòng nhập mã voucher.');
      return;
    }

    const dv = Number(discountValue.replace(/\./g, '').replace(',', '.'));
    const mo = Number(minOrderAmount.replace(/\./g, '').replace(',', '.'));
    if (!Number.isFinite(dv) || dv < 0) {
      setErr('Giá trị giảm không hợp lệ.');
      return;
    }
    if (!Number.isFinite(mo) || mo < 0) {
      setErr('Đơn tối thiểu không hợp lệ.');
      return;
    }
    if (discountType === 'Percentage' && dv > 100) {
      setErr('Giảm theo % không thể > 100.');
      return;
    }

    setSaving(true);
    setErr(null);
    try {
      const payload = {
        code: c,
        discountType,
        discountValue: dv,
        minOrderAmount: mo,
        expiryDate: fromInputDateTimeLocal(expiryLocal),
        isActive,
      };

      if (mode === 'edit' && voucherId) {
        const updated = await apiService.adminUpdateVoucher(voucherId, payload);
        if (!updated) throw new Error('Cập nhật thất bại');
      } else {
        const created = await apiService.adminCreateVoucher(payload);
        if (!created) throw new Error('Tạo mới thất bại');
      }

      onSaved();
    } catch (e: any) {
      setErr(e?.message || (mode === 'edit' ? 'Không cập nhật được voucher.' : 'Không tạo được voucher.'));
    } finally {
      setSaving(false);
    }
  };

  return (
    <form className="admin-card" onSubmit={onSubmit}>
      <div className="admin-card-title">{title}</div>
      <div className="muted" style={{ marginTop: 6 }}>
        Tạo/sửa voucher ở trang riêng (không thao tác trực tiếp trên trang danh sách).
      </div>

      {loading ? (
        <div className="prod-admin-td-muted" style={{ padding: '1rem 0' }}>
          Đang tải…
        </div>
      ) : (
        <>
          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12, marginTop: 16 }}>
            <div style={{ gridColumn: '1 / -1' }}>
              <label className="prod-admin-label">Mã voucher</label>
              <input className="prod-admin-input" value={code} onChange={(e) => setCode(e.target.value)} placeholder="VD: FRESH10" required />
            </div>

            <div>
              <label className="prod-admin-label">Loại giảm</label>
              <select className="prod-admin-input" value={discountType} onChange={(e) => setDiscountType(e.target.value === 'Flat' ? 'Flat' : 'Percentage')}>
                <option value="Percentage">Percentage (%)</option>
                <option value="Flat">Flat (VNĐ)</option>
              </select>
            </div>

            <div>
              <label className="prod-admin-label">{discountType === 'Percentage' ? 'Giảm (%)' : 'Giảm (VNĐ)'}</label>
              <input className="prod-admin-input" inputMode="numeric" value={discountValue} onChange={(e) => setDiscountValue(e.target.value)} required />
            </div>

            <div>
              <label className="prod-admin-label">Đơn tối thiểu (VNĐ)</label>
              <input className="prod-admin-input" inputMode="numeric" value={minOrderAmount} onChange={(e) => setMinOrderAmount(e.target.value)} />
            </div>

            <div>
              <label className="prod-admin-label">Hết hạn</label>
              <input className="prod-admin-input" type="datetime-local" value={expiryLocal} onChange={(e) => setExpiryLocal(e.target.value)} />
              <div className="muted" style={{ fontSize: 12, marginTop: 6 }}>
                Để trống nếu không giới hạn thời gian.
              </div>
            </div>

            <div style={{ gridColumn: '1 / -1', display: 'flex', gap: 10, alignItems: 'center', marginTop: 4 }}>
              <input id="voucher-active" type="checkbox" checked={isActive} onChange={(e) => setIsActive(e.target.checked)} />
              <label htmlFor="voucher-active" style={{ userSelect: 'none' }}>
                Kích hoạt voucher
              </label>
            </div>
          </div>

          {err && <div className="prod-admin-err" style={{ marginTop: 12 }}>{err}</div>}

          <div style={{ display: 'flex', gap: 10, justifyContent: 'flex-end', marginTop: 18 }}>
            <button type="button" className="prod-admin-btn-ghost" onClick={onClose}>
              Hủy
            </button>
            <button type="submit" className="prod-admin-btn-primary" disabled={saving}>
              {saving ? 'Đang lưu…' : 'Lưu'}
            </button>
          </div>
        </>
      )}
    </form>
  );
}

