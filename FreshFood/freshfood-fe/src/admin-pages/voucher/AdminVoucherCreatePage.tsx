import { useNavigate } from 'react-router-dom';
import { AdminVoucherForm } from './AdminVoucherForm';

export function AdminVoucherCreatePage() {
  const nav = useNavigate();
  return <AdminVoucherForm mode="create" onClose={() => nav('/admin/vouchers')} onSaved={() => nav('/admin/vouchers')} />;
}

