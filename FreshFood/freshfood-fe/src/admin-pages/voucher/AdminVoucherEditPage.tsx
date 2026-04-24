import { useNavigate, useParams } from 'react-router-dom';
import { AdminVoucherForm } from './AdminVoucherForm';

export function AdminVoucherEditPage() {
  const nav = useNavigate();
  const { id } = useParams();
  const idOrToken = String(id || '').trim();
  const numericId = Number(idOrToken);
  const hasNumericId =
    Number.isFinite(numericId) && numericId > 0 && String(Math.trunc(numericId)) === idOrToken;
  const voucherId = hasNumericId ? numericId : null;
  const voucherToken = !hasNumericId && idOrToken ? idOrToken : null;

  return (
    <AdminVoucherForm
      mode="edit"
      voucherId={voucherId ?? undefined}
      voucherToken={voucherToken ?? undefined}
      onClose={() => nav('/admin/vouchers')}
      onSaved={() => nav('/admin/vouchers')}
    />
  );
}

