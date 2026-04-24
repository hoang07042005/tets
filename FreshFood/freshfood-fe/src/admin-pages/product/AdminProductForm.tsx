import { useEffect, useMemo, useRef, useState } from 'react';
import { ImagePlus, X } from 'lucide-react';
import type { Category, Product } from '../../types';
import { apiService, resolveMediaUrl } from '../../services/api';

type SupplierOption = { id: number; name: string };

type Mode = 'create' | 'edit';

type Props = {
  mode: Mode;
  productId?: number;
  productToken?: string;
  seedProductName?: string;
  categories: Category[];
  suppliers: SupplierOption[];
  onClose: () => void;
  onSaved: () => void;
};

export function AdminProductForm({ mode, productId, productToken, seedProductName, categories, suppliers, onClose, onSaved }: Props) {
  const [name, setName] = useState(seedProductName ?? '');
  const [sku, setSku] = useState<string>('');
  const [resolvedProductId, setResolvedProductId] = useState<number | null>(productId ?? null);
  const [categoryId, setCategoryId] = useState<number | ''>('');
  const [supplierId, setSupplierId] = useState<number | ''>('');
  const [status, setStatus] = useState<'Active' | 'Inactive'>('Active');
  const [price, setPrice] = useState('');
  const [discount, setDiscount] = useState('');
  const [stock, setStock] = useState('');
  const [unit, setUnit] = useState('kg');
  const [description, setDescription] = useState('');
  const [manufacturedDate, setManufacturedDate] = useState('');
  const [expiryDate, setExpiryDate] = useState('');
  const [origin, setOrigin] = useState('');
  const [storageInstructions, setStorageInstructions] = useState('');
  const [certifications, setCertifications] = useState('');
  const [saving, setSaving] = useState(false);
  const [loading, setLoading] = useState(mode === 'edit');
  const [err, setErr] = useState<string | null>(null);

  const fileInputRef = useRef<HTMLInputElement | null>(null);
  const [existingImages, setExistingImages] = useState<{ imageID: number; imageURL: string; isMainImage: boolean }[]>([]);
  const [newFiles, setNewFiles] = useState<File[]>([]);
  const [newMainIndex, setNewMainIndex] = useState<number>(0);

  const newPreviews = useMemo(() => newFiles.map((f) => URL.createObjectURL(f)), [newFiles]);

  useEffect(() => {
    return () => {
      newPreviews.forEach((u) => URL.revokeObjectURL(u));
    };
  }, [newPreviews]);

  useEffect(() => {
    if (mode !== 'edit' || (!productId && !productToken)) {
      setLoading(false);
      return;
    }

    let cancelled = false;

    (async () => {
      try {
        const full: Product | null = productId
          ? await apiService.getAdminProduct(productId)
          : productToken
            ? await apiService.getAdminProductByToken(productToken)
            : null;
        if (!full || cancelled) return;
        setResolvedProductId(full.productID ?? productId ?? null);
        setName(full.productName ?? '');
        setSku(full.sku ?? '');
        setCategoryId(full.categoryID ?? '');
        setSupplierId(full.supplierID ?? '');
        setStatus((full.status === 'Inactive' ? 'Inactive' : 'Active') as 'Active' | 'Inactive');
        setPrice(String(full.price ?? ''));
        setDiscount(full.discountPrice != null ? String(full.discountPrice) : '');
        setStock(String(full.stockQuantity ?? ''));
        setUnit(full.unit || 'kg');
        setDescription(full.description ?? '');
        const toYmd = (iso?: string | null) => {
          if (!iso) return '';
          const d = new Date(iso);
          if (Number.isNaN(d.getTime())) return '';
          return d.toISOString().slice(0, 10);
        };
        setManufacturedDate(toYmd(full.manufacturedDate));
        setExpiryDate(toYmd(full.expiryDate));
        setOrigin(full.origin ?? '');
        setStorageInstructions(full.storageInstructions ?? '');
        setCertifications(full.certifications ?? '');
        const imgs = (full.productImages || []).map((pi) => ({
          imageID: pi.imageID,
          imageURL: pi.imageURL,
          isMainImage: !!pi.isMainImage,
        }));
        setExistingImages(imgs);
      } catch {
        if (!cancelled) setErr('Không tải được dữ liệu sản phẩm.');
      } finally {
        if (!cancelled) setLoading(false);
      }
    })();

    return () => {
      cancelled = true;
    };
  }, [mode, productId, productToken]);

  const onSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!name.trim()) return;

    const parsedPrice = Number(String(price).replace(/\./g, '').replace(',', '.'));
    const parsedStock = parseInt(stock, 10);

    if (!Number.isFinite(parsedPrice) || parsedPrice < 0) {
      setErr('Giá không hợp lệ.');
      return;
    }
    if (!Number.isFinite(parsedStock) || parsedStock < 0) {
      setErr('Tồn kho không hợp lệ.');
      return;
    }

    let parsedDiscount: number | null = null;
    if (discount.trim()) {
      const d = Number(discount.replace(/\./g, '').replace(',', '.'));
      if (Number.isFinite(d) && d >= 0) parsedDiscount = d;
    }

    const md = manufacturedDate.trim() || null;
    const ed = expiryDate.trim() || null;
    const freshPayload = {
      manufacturedDate: md,
      expiryDate: ed,
      origin: origin.trim() || null,
      storageInstructions: storageInstructions.trim() || null,
      certifications: certifications.trim() || null,
    };

    setSaving(true);
    setErr(null);
    try {
      let savedProductId = resolvedProductId ?? productId ?? null;
      if (mode === 'edit' && savedProductId) {
        const p = await apiService.adminUpdateProduct(savedProductId, {
          productName: name.trim(),
          categoryID: categoryId === '' ? null : categoryId,
          supplierID: supplierId === '' ? null : supplierId,
          status,
          price: parsedPrice,
          discountPrice: parsedDiscount,
          stockQuantity: parsedStock,
          unit: unit.trim() || 'kg',
          description: description.trim() || undefined,
          ...freshPayload,
        });
        if (!p) throw new Error('Cập nhật thất bại');
      } else {
        const p = await apiService.adminCreateProduct({
          productName: name.trim(),
          categoryID: categoryId === '' ? null : categoryId,
          supplierID: supplierId === '' ? null : supplierId,
          status,
          price: parsedPrice,
          discountPrice: parsedDiscount,
          stockQuantity: parsedStock,
          unit: unit.trim() || 'kg',
          description: description.trim() || undefined,
          ...freshPayload,
        });
        if (!p) throw new Error('Tạo thất bại');
        savedProductId = p.productID;
        setResolvedProductId(p.productID);
      }

      // Upload images if any
      if (savedProductId && newFiles.length > 0) {
        await apiService.adminUploadProductImages(savedProductId, newFiles, newMainIndex);
      }

      onSaved();
    } catch (e: unknown) {
      setErr(
        mode === 'edit'
          ? 'Không cập nhật được sản phẩm. Kiểm tra dữ liệu và thử lại.'
          : 'Không tạo được sản phẩm. Kiểm tra dữ liệu và thử lại.',
      );
    } finally {
      setSaving(false);
    }
  };

  const onPickFiles = (files: FileList | null) => {
    if (!files) return;
    const picked = Array.from(files).filter((f) => (f.type || '').startsWith('image/'));
    if (picked.length === 0) return;
    const next = [...newFiles, ...picked].slice(0, 10);
    setNewFiles(next);
    if (newMainIndex >= next.length) setNewMainIndex(0);
  };

  const removeNewFile = (idx: number) => {
    const next = newFiles.filter((_, i) => i !== idx);
    setNewFiles(next);
    if (newMainIndex === idx) setNewMainIndex(0);
    else if (newMainIndex > idx) setNewMainIndex((x) => x - 1);
  };

  const setMainExisting = async (imageId: number) => {
    const id = resolvedProductId ?? productId;
    if (!id) return;
    const ok = await apiService.adminSetMainProductImage(id, imageId);
    if (!ok) {
      setErr('Không đặt được ảnh chính.');
      return;
    }
    setExistingImages((imgs) => imgs.map((x) => ({ ...x, isMainImage: x.imageID === imageId })));
  };

  const deleteExisting = async (imageId: number) => {
    const id = resolvedProductId ?? productId;
    if (!id) return;
    const ok = await apiService.adminDeleteProductImage(id, imageId);
    if (!ok) {
      setErr('Không xóa được ảnh.');
      return;
    }
    setExistingImages((imgs) => imgs.filter((x) => x.imageID !== imageId));
  };

  return (
    <form className="prod-edit" onSubmit={onSubmit}>
      {loading ? (
        <div className="prod-admin-td-muted">Đang tải dữ liệu…</div>
      ) : (
        <>
          <div className="prod-edit-grid">
            <div className="prod-edit-left">
              <section className="prod-card">
                <div className="prod-card-title">Thông tin cơ bản</div>
                <div className="prod-card-body prod-two-col">
                  <div>
                    <label className="prod-admin-label">Tên sản phẩm</label>
                    <input className="prod-admin-input" value={name} onChange={(e) => setName(e.target.value)} required />
                  </div>
                  <div>
                    <label className="prod-admin-label">Mã SKU</label>
                    <input
                      className="prod-admin-input"
                      value={mode === 'edit' ? (sku || 'FF-PRD-...') : 'Tự sinh sau khi lưu'}
                      readOnly
                      disabled
                    />
                  </div>
                  <div>
                    <label className="prod-admin-label">Trạng thái</label>
                    <select className="prod-admin-input" value={status} onChange={(e) => setStatus(e.target.value as 'Active' | 'Inactive')}>
                      <option value="Active">Hoạt động</option>
                      <option value="Inactive">Ngừng hoạt động</option>
                    </select>
                  </div>
                  <div>
                    <label className="prod-admin-label">Danh mục</label>
                    <select
                      className="prod-admin-input"
                      value={categoryId === '' ? '' : String(categoryId)}
                      onChange={(e) => setCategoryId(e.target.value === '' ? '' : Number(e.target.value))}
                    >
                      <option value="">— Chọn —</option>
                      {categories.map((c) => (
                        <option key={c.categoryID} value={c.categoryID}>
                          {c.categoryName}
                        </option>
                      ))}
                    </select>
                  </div>
                  <div>
                    <label className="prod-admin-label">Nhà cung cấp</label>
                    <select
                      className="prod-admin-input"
                      value={supplierId === '' ? '' : String(supplierId)}
                      onChange={(e) => setSupplierId(e.target.value === '' ? '' : Number(e.target.value))}
                    >
                      <option value="">— Chọn —</option>
                      {suppliers.map((s) => (
                        <option key={s.id} value={s.id}>
                          {s.name}
                        </option>
                      ))}
                    </select>
                  </div>
                </div>
              </section>

              <section className="prod-card">
                <div className="prod-card-title">Giá &amp; Tồn kho</div>
                <div className="prod-card-body prod-four-col">
                  <div>
                    <label className="prod-admin-label">Giá bán</label>
                    <input className="prod-admin-input" inputMode="numeric" value={price} onChange={(e) => setPrice(e.target.value)} required />
                  </div>
                  <div>
                    <label className="prod-admin-label">Giá khuyến mãi</label>
                    <input className="prod-admin-input" inputMode="numeric" value={discount} onChange={(e) => setDiscount(e.target.value)} />
                  </div>
                  <div>
                    <label className="prod-admin-label">Tồn kho</label>
                    <input className="prod-admin-input" inputMode="numeric" value={stock} onChange={(e) => setStock(e.target.value)} required />
                  </div>
                  <div>
                    <label className="prod-admin-label">Đơn vị</label>
                    <input className="prod-admin-input" value={unit} onChange={(e) => setUnit(e.target.value)} />
                  </div>
                </div>
              </section>

              <section className="prod-card">
                <div className="prod-card-title">Mô tả chi tiết sản phẩm</div>
                <div className="prod-card-body">
                  <textarea
                    className="prod-admin-input prod-admin-textarea"
                    rows={8}
                    placeholder="Nhập mô tả sản phẩm, công dụng… (cách bảo quản có thể ghi thêm ở mục Đặc tả tươi bên dưới)"
                    value={description}
                    onChange={(e) => setDescription(e.target.value)}
                  />
                </div>
              </section>

              <section className="prod-card">
                <div className="prod-card-title">Đặc tả tươi / thực phẩm</div>
                <div className="prod-card-body prod-two-col">
                  <div>
                    <label className="prod-admin-label">Ngày sản xuất / thu hoạch (NSX)</label>
                    <input
                      className="prod-admin-input"
                      type="date"
                      value={manufacturedDate}
                      onChange={(e) => setManufacturedDate(e.target.value)}
                    />
                  </div>
                  <div>
                    <label className="prod-admin-label">Hạn sử dụng (HSD)</label>
                    <input className="prod-admin-input" type="date" value={expiryDate} onChange={(e) => setExpiryDate(e.target.value)} />
                  </div>
                  <div className="prod-span-2" style={{ gridColumn: '1 / -1' }}>
                    <label className="prod-admin-label">Nguồn gốc</label>
                    <input
                      className="prod-admin-input"
                      value={origin}
                      onChange={(e) => setOrigin(e.target.value)}
                      placeholder="VD: Đà Lạt, Lâm Đồng / Nhà cung cấp X"
                    />
                  </div>
                  <div className="prod-span-2" style={{ gridColumn: '1 / -1' }}>
                    <label className="prod-admin-label">Cách bảo quản</label>
                    <textarea
                      className="prod-admin-input prod-admin-textarea"
                      rows={3}
                      value={storageInstructions}
                      onChange={(e) => setStorageInstructions(e.target.value)}
                      placeholder="VD: Bảo quản 2–6°C, dùng trong 48h sau khi mở túi…"
                    />
                  </div>
                  <div className="prod-span-2" style={{ gridColumn: '1 / -1' }}>
                    <label className="prod-admin-label">Chứng nhận</label>
                    <input
                      className="prod-admin-input"
                      value={certifications}
                      onChange={(e) => setCertifications(e.target.value)}
                      placeholder="VD: Organic, VietGAP, GlobalGAP (phân cách bằng dấu phẩy)"
                    />
                  </div>
                </div>
              </section>
            </div>

            <aside className="prod-edit-right">
              <section className="prod-card">
                <div className="prod-card-title">Hình ảnh sản phẩm</div>
                <div className="prod-card-body">
                  <input
                    ref={fileInputRef}
                    className="prod-admin-file"
                    type="file"
                    accept="image/*"
                    multiple
                    onChange={(e) => onPickFiles(e.target.files)}
                  />

                  <div className="prod-drop" onClick={() => fileInputRef.current?.click()} role="button" tabIndex={0}>
                    <div className="prod-drop-ico">
                      <ImagePlus size={20} aria-hidden />
                    </div>
                    <div className="prod-drop-text">Kéo thả ảnh vào đây</div>
                    <div className="muted prod-drop-hint">PNG, JPG tối đa 5MB</div>
                    <button type="button" className="prod-drop-btn" onClick={() => fileInputRef.current?.click()}>
                      Chọn tệp
                    </button>
                  </div>

                  <div className="prod-thumb-header muted">
                    Ảnh đã tải lên ({existingImages.length + newFiles.length}/10)
                  </div>

                  <div className="prod-thumb-row">
                    {existingImages.map((img) => (
                      <button
                        type="button"
                        key={img.imageID}
                        className={`prod-thumb ${img.isMainImage ? 'is-main' : ''}`}
                        title={img.isMainImage ? 'Ảnh chính' : 'Chọn làm ảnh chính'}
                        onClick={() => setMainExisting(img.imageID)}
                      >
                        <img src={resolveMediaUrl(img.imageURL)} alt="" />
                        <span className="prod-thumb-main-dot" />
                        <span
                          className="prod-thumb-x"
                          onClick={(e) => {
                            e.stopPropagation();
                            deleteExisting(img.imageID);
                          }}
                        >
                          <X size={12} aria-hidden />
                        </span>
                      </button>
                    ))}

                    {newPreviews.map((url, idx) => (
                      <button
                        type="button"
                        key={url}
                        className={`prod-thumb ${newMainIndex === idx ? 'is-main' : ''}`}
                        title={newMainIndex === idx ? 'Ảnh chính' : 'Chọn làm ảnh chính'}
                        onClick={() => setNewMainIndex(idx)}
                      >
                        <img src={url} alt="" />
                        <span className="prod-thumb-main-dot" />
                        <span
                          className="prod-thumb-x"
                          onClick={(e) => {
                            e.stopPropagation();
                            removeNewFile(idx);
                          }}
                        >
                          <X size={12} aria-hidden />
                        </span>
                      </button>
                    ))}

                    <button
                      type="button"
                      className="prod-thumb prod-thumb-add"
                      onClick={() => fileInputRef.current?.click()}
                      title="Thêm ảnh"
                    >
                      <span>+</span>
                    </button>
                  </div>
                </div>
              </section>
            </aside>
          </div>

          {err && <div className="prod-admin-err">{err}</div>}

          <div className="prod-edit-actions">
            <button type="button" className="prod-admin-btn-ghost" onClick={onClose}>
              Hủy
            </button>
            <button type="submit" className="prod-admin-btn-primary" disabled={saving}>
              {saving ? 'Đang lưu…' : mode === 'edit' ? 'Lưu sản phẩm' : 'Lưu sản phẩm'}
            </button>
          </div>
        </>
      )}
    </form>
  );
}

