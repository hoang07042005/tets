import { useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { AdminProductForm } from './AdminProductForm';
import { apiService } from '../../services/api';
import type { Category } from '../../types';

export function AdminProductCreatePage() {
  const navigate = useNavigate();
  const [categories, setCategories] = useState<Category[]>([]);
  const [suppliers, setSuppliers] = useState<{ id: number; name: string }[]>([]);

  useEffect(() => {
    let cancelled = false;
    (async () => {
      try {
        const [cats, supRes] = await Promise.all([
          apiService.getAdminCategories(),
          apiService.getAdminSuppliersPage({ page: 1, pageSize: 200, tab: 'all' }),
        ]);
        if (cancelled) return;
        setCategories(Array.isArray(cats) ? cats : []);
        const items = supRes?.items ?? [];
        setSuppliers(items.map((s) => ({ id: s.supplierID, name: s.supplierName })));
      } catch {
        if (!cancelled) {
          setCategories([]);
          setSuppliers([]);
        }
      }
    })();
    return () => {
      cancelled = true;
    };
  }, []);

  return (
    <div className="prod-admin">
      <div className="prod-admin-kicker">Admin catalog</div>
      <header className="prod-admin-head">
        <div>
          <h1 className="prod-admin-title">Thêm sản phẩm</h1>
          <p className="prod-admin-sub muted">Tạo sản phẩm mới cho cửa hàng.</p>
        </div>
      </header>

      <AdminProductForm
        mode="create"
        categories={categories}
        suppliers={suppliers}
        onClose={() => navigate('/admin/products')}
        onSaved={() => navigate('/admin/products')}
      />
    </div>
  );
}

