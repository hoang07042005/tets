import { useEffect, useMemo, useState } from 'react';
import { useNavigate, useParams } from 'react-router-dom';
import { AdminProductForm } from './AdminProductForm';
import { apiService } from '../../services/api';
import type { Category } from '../../types';

export function AdminProductEditPage() {
  const navigate = useNavigate();
  const params = useParams();
  const idOrToken = String(params.id || '').trim();
  const productId = useMemo(() => {
    const n = Number(idOrToken);
    return Number.isFinite(n) && n > 0 && String(Math.trunc(n)) === idOrToken ? n : null;
  }, [idOrToken]);
  const productToken = useMemo(() => (productId == null && idOrToken ? idOrToken : undefined), [productId, idOrToken]);

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

  if (!idOrToken) {
    return (
      <div className="prod-admin">
        <div className="prod-admin-err">ID sản phẩm không hợp lệ.</div>
      </div>
    );
  }

  return (
    <div className="prod-admin">
      <div className="prod-admin-kicker">Admin catalog</div>
      <header className="prod-admin-head">
        <div>
          <h1 className="prod-admin-title">Sửa sản phẩm</h1>
          <p className="prod-admin-sub muted">Cập nhật thông tin, giá, tồn kho và mô tả.</p>
        </div>
      </header>

      <AdminProductForm
        mode="edit"
        productId={productId ?? undefined}
        productToken={productToken}
        categories={categories}
        suppliers={suppliers}
        onClose={() => navigate('/admin/products')}
        onSaved={() => navigate('/admin/products')}
      />
    </div>
  );
}

