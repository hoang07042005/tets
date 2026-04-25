import { Product, Category, RecentReview, ReviewSummary, Order, WishlistItem, Voucher, AdminDashboardDto, AdminLowStockProduct, AdminRecentImport, AdminSuppliersPage, AdminSupplierRow, AdminProductsPage, AdminUsersPage, AdminUserRow, AdminContactMessagesPage, AdminContactMessageDetail, AdminOrdersPage, AdminOrderDetail, ShippingMethod, ReturnRequest, BlogPost, BlogComment, ServerCartDto, UserAddress, PublicOrderTrack, HomePageSettings } from '../types';

export const API_ORIGIN = 'https://tets-1-c1v4.onrender.com';
const API_BASE_URL = `${API_ORIGIN}/api`;
const AUTH_STORAGE_KEY = 'freshfood_auth';
const baseFetch: typeof globalThis.fetch = globalThis.fetch.bind(globalThis);

function readAuthToken(): string | null {
    try {
        const raw = localStorage.getItem(AUTH_STORAGE_KEY);
        if (!raw) return null;
        const parsed = JSON.parse(raw) as { token?: string; expiresAt?: number };
        if (!parsed?.token || typeof parsed.token !== 'string') return null;
        if (typeof parsed.expiresAt === 'number' && Date.now() >= parsed.expiresAt) return null;
        const t = parsed.token.trim();
        return t ? t : null;
    } catch {
        return null;
    }
}

async function authFetch(input: RequestInfo | URL, init?: RequestInit): Promise<Response> {
    const token = readAuthToken();
    if (!token) return baseFetch(input, init);
    const headers = new Headers(init?.headers || undefined);
    if (!headers.has('Authorization')) headers.set('Authorization', `Bearer ${token}`);
    return baseFetch(input, { ...(init || {}), headers });
}

// Shadow fetch in this module so all existing calls automatically attach JWT when available.
// eslint-disable-next-line @typescript-eslint/no-shadow
const fetch = authFetch;

export type ShopProductSort = 'newest' | 'priceAsc' | 'priceDesc' | 'nameAsc' | 'bestsellers';

export type GetProductsQuery = {
    categoryId?: number;
    searchTerm?: string;
    minPrice?: number;
    maxPrice?: number;
    sort?: ShopProductSort;
    signal?: AbortSignal;
};

/** Lấy chuỗi lỗi từ body JSON ProblemDetails hoặc plain text. */
export function parseApiErrorBody(text: string, fallback: string): string {
    const t = (text || '').trim();
    if (!t) return fallback;
    if (t.startsWith('{')) {
        try {
            const j = JSON.parse(t) as Record<string, unknown>;
            const d = j.detail ?? j.title ?? j.Detail ?? j.Title;
            if (typeof d === 'string' && d.trim()) return d.trim();
        } catch {
            /* ignore */
        }
    }
    try {
        if ((t.startsWith('"') && t.endsWith('"')) || (t.startsWith("'") && t.endsWith("'"))) {
            return JSON.parse(t) as string;
        }
    } catch {
        /* ignore */
    }
    return t;
}

// Giải quyết URL ảnh khi backend lưu dạng relative: "/product-images/..."
export function resolveMediaUrl(url?: string | null): string {
    if (!url) return '';
    const u = url.trim();
    if (!u) return '';
    if (/^https?:\/\//i.test(u)) return u;
    if (u.startsWith('/')) return `${API_ORIGIN}${u}`;
    return `${API_ORIGIN}/${u}`;
}

export const apiService = {
    async getHomePageSettings(): Promise<HomePageSettings | null> {
        const response = await fetch(`${API_BASE_URL}/HomePage`);
        return response.ok ? response.json() : null;
    },

    async getAdminHomePageSettings(): Promise<HomePageSettings | null> {
        const response = await fetch(`${API_BASE_URL}/Admin/HomePage`);
        return response.ok ? response.json() : null;
    },

    async adminUpdateHomePageSettings(input: HomePageSettings): Promise<boolean> {
        const response = await fetch(`${API_BASE_URL}/Admin/HomePage`, {
            method: 'PUT',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(input),
        });
        return response.ok;
    },

    async adminUploadHomeImage(file: File): Promise<{ imageUrl: string } | null> {
        const fd = new FormData();
        fd.append('file', file, file.name || 'home.jpg');
        const response = await fetch(`${API_BASE_URL}/Admin/HomePage/UploadImage`, {
            method: 'POST',
            body: fd,
        });
        if (!response.ok) {
            const msg = await response.text();
            throw new Error(msg || 'Upload ảnh thất bại');
        }
        return await response.json();
    },
    async getBlogPosts(input?: { q?: string }): Promise<BlogPost[]> {
        const params = new URLSearchParams();
        if (input?.q) params.set('q', input.q);
        const qs = params.toString() ? `?${params.toString()}` : '';
        const response = await fetch(`${API_BASE_URL}/BlogPosts${qs}`);
        return response.ok ? response.json() : [];
    },

    async getBlogPostBySlug(slug: string): Promise<BlogPost | null> {
        const response = await fetch(`${API_BASE_URL}/BlogPosts/${encodeURIComponent(slug)}`);
        return response.ok ? response.json() : null;
    },

    async getBlogCommentsBySlug(slug: string): Promise<BlogComment[]> {
        const response = await fetch(`${API_BASE_URL}/BlogPosts/${encodeURIComponent(slug)}/Comments`);
        return response.ok ? response.json() : [];
    },

    async createBlogCommentBySlug(slug: string, input: { userID: number; content: string; parentCommentID?: number | null }): Promise<BlogComment | null> {
        const response = await fetch(`${API_BASE_URL}/BlogPosts/${encodeURIComponent(slug)}/Comments`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(input),
        });
        if (!response.ok) {
            const msg = await response.text();
            throw new Error(msg || 'Gửi bình luận thất bại');
        }
        return await response.json();
    },

    // ---------------------------
    // Admin BlogPosts (CRUD)
    // ---------------------------
    async getAdminBlogPosts(input?: { q?: string; published?: boolean }): Promise<BlogPost[]> {
        const params = new URLSearchParams();
        if (input?.q) params.set('q', input.q);
        if (typeof input?.published === 'boolean') params.set('published', String(input.published));
        const qs = params.toString() ? `?${params.toString()}` : '';
        const response = await authFetch(`${API_BASE_URL}/Admin/BlogPosts${qs}`);
        if (!response.ok) throw new Error('Không tải được bài viết');
        return await response.json();
    },

    async getAdminBlogPost(id: number): Promise<BlogPost | null> {
        const response = await authFetch(`${API_BASE_URL}/Admin/BlogPosts/${id}`);
        return response.ok ? response.json() : null;
    },

    async getAdminBlogPostByToken(token: string): Promise<BlogPost | null> {
        const t = (token || '').trim();
        if (!t) return null;
        const response = await authFetch(`${API_BASE_URL}/Admin/BlogPosts/token/${encodeURIComponent(t)}`);
        return response.ok ? response.json() : null;
    },

    async getAdminProduct(id: number): Promise<Product | null> {
        const response = await authFetch(`${API_BASE_URL}/Admin/Products/${id}`);
        return response.ok ? response.json() : null;
    },

    async getAdminProductByToken(token: string): Promise<Product | null> {
        const t = (token || '').trim();
        if (!t) return null;
        const response = await authFetch(`${API_BASE_URL}/Admin/Products/token/${encodeURIComponent(t)}`);
        return response.ok ? response.json() : null;
    },

    async adminCreateBlogPost(input: {
        title: string;
        slug: string;
        excerpt?: string | null;
        content: string;
        coverImageUrl?: string | null;
        isPublished: boolean;
        publishedAt?: string | null;
    }): Promise<BlogPost | null> {
        const response = await fetch(`${API_BASE_URL}/Admin/BlogPosts`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(input),
        });
        if (!response.ok) return null;
        return await response.json();
    },

    async adminUpdateBlogPost(
        id: number,
        input: {
            title: string;
            slug: string;
            excerpt?: string | null;
            content: string;
            coverImageUrl?: string | null;
            isPublished: boolean;
            publishedAt?: string | null;
        },
    ): Promise<BlogPost | null> {
        const response = await fetch(`${API_BASE_URL}/Admin/BlogPosts/${id}`, {
            method: 'PUT',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(input),
        });
        if (!response.ok) return null;
        return await response.json();
    },

    async adminDeleteBlogPost(id: number): Promise<{ ok: boolean; message?: string }> {
        const response = await fetch(`${API_BASE_URL}/Admin/BlogPosts/${id}`, { method: 'DELETE' });
        if (response.ok) return { ok: true };
        const message = await response.text();
        return { ok: false, message: message || 'Xóa thất bại' };
    },

    async adminUploadBlogCover(file: File): Promise<{ coverImageUrl: string } | null> {
        const fd = new FormData();
        fd.append('file', file, file.name || 'cover.jpg');
        const response = await fetch(`${API_BASE_URL}/Admin/BlogPosts/UploadCover`, {
            method: 'POST',
            body: fd,
        });
        if (!response.ok) {
            const msg = await response.text();
            throw new Error(msg || 'Upload ảnh thất bại');
        }
        return await response.json();
    },

    async getAdminDashboard(range: 'week' | 'month' = 'week'): Promise<AdminDashboardDto> {
        const response = await fetch(`${API_BASE_URL}/Admin/dashboard?range=${encodeURIComponent(range)}`);
        if (!response.ok) throw new Error('Failed to load admin dashboard');
        return await response.json();
    },

    async getAdminUsersPage(input?: {
        page?: number;
        pageSize?: number;
        q?: string;
        role?: 'all' | 'admin' | 'customer';
        status?: 'all' | 'active' | 'locked';
    }): Promise<AdminUsersPage> {
        const page = input?.page ?? 1;
        const pageSize = input?.pageSize ?? 15;
        const params = new URLSearchParams();
        params.set('page', String(page));
        params.set('pageSize', String(pageSize));
        if (input?.q?.trim()) params.set('q', input.q.trim());
        if (input?.role && input.role !== 'all') params.set('role', input.role);
        if (input?.status && input.status !== 'all') params.set('status', input.status);
        const response = await fetch(`${API_BASE_URL}/Admin/Users?${params.toString()}`);
        if (!response.ok) throw new Error('Không tải được danh sách người dùng');
        return await response.json();
    },

    async getAdminContactMessagesPage(input?: {
        page?: number;
        pageSize?: number;
        q?: string;
        /** all | new | processing | replied */
        status?: 'all' | 'new' | 'processing' | 'replied';
    }): Promise<AdminContactMessagesPage> {
        const page = input?.page ?? 1;
        const pageSize = input?.pageSize ?? 15;
        const params = new URLSearchParams();
        params.set('page', String(page));
        params.set('pageSize', String(pageSize));
        if (input?.q?.trim()) params.set('q', input.q.trim());
        if (input?.status && input.status !== 'all') params.set('status', input.status);
        const response = await fetch(`${API_BASE_URL}/Admin/ContactMessages?${params.toString()}`);
        if (!response.ok) throw new Error('Không tải được tin liên hệ');
        return await response.json();
    },

    async adminPatchContactMessageStatus(id: number, status: 'New' | 'Processing' | 'Replied'): Promise<void> {
        const response = await fetch(`${API_BASE_URL}/Admin/ContactMessages/${id}/status`, {
            method: 'PATCH',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ status }),
        });
        if (!response.ok) {
            const msg = parseApiErrorBody(await response.text(), 'Cập nhật trạng thái thất bại');
            throw new Error(msg);
        }
    },

    async getAdminContactMessage(id: number): Promise<AdminContactMessageDetail | null> {
        const response = await fetch(`${API_BASE_URL}/Admin/ContactMessages/${id}`);
        return response.ok ? response.json() : null;
    },

    async adminReplyContactMessage(
        id: number,
        input: { subject: string; message: string; includeOriginal?: boolean },
    ): Promise<{ ok: boolean }> {
        const response = await fetch(`${API_BASE_URL}/Admin/ContactMessages/${id}/reply`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                subject: input.subject,
                message: input.message,
                includeOriginal: typeof input.includeOriginal === 'boolean' ? input.includeOriginal : true,
            }),
        });
        if (!response.ok) {
            const msg = parseApiErrorBody(await response.text(), 'Gửi email thất bại');
            throw new Error(msg);
        }
        return (await response.json()) as { ok: boolean };
    },

    async adminUpdateUserRole(userId: number, role: 'Admin' | 'Customer'): Promise<AdminUserRow | null> {
        const response = await fetch(`${API_BASE_URL}/Admin/Users/${userId}`, {
            method: 'PATCH',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ role }),
        });
        if (!response.ok) {
            const msg = await response.text();
            throw new Error(msg || 'Cập nhật vai trò thất bại');
        }
        return await response.json();
    },

    async adminSetUserLock(userId: number, isLocked: boolean): Promise<AdminUserRow | null> {
        const response = await fetch(`${API_BASE_URL}/Admin/Users/${userId}/lock`, {
            method: 'PATCH',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ isLocked }),
        });
        if (!response.ok) {
            const msg = await response.text();
            throw new Error(msg || 'Không cập nhật được trạng thái khóa');
        }
        return await response.json();
    },

    async adminDeleteUser(userId: number): Promise<{ ok: boolean; message?: string }> {
        const response = await fetch(`${API_BASE_URL}/Admin/Users/${userId}`, { method: 'DELETE' });
        if (response.ok) return { ok: true };
        const message = await response.text();
        return { ok: false, message: message || 'Xóa thất bại' };
    },
    async getAdminLowStock(input?: { threshold?: number; take?: number }): Promise<AdminLowStockProduct[]> {
        const threshold = input?.threshold ?? 10;
        const take = input?.take ?? 12;
        const response = await fetch(`${API_BASE_URL}/Admin/low-stock?threshold=${encodeURIComponent(String(threshold))}&take=${encodeURIComponent(String(take))}`);
        return response.ok ? response.json() : [];
    },

    async getAdminRecentImports(input?: { take?: number }): Promise<AdminRecentImport[]> {
        const take = input?.take ?? 6;
        const response = await fetch(`${API_BASE_URL}/Admin/inventory/recent-imports?take=${encodeURIComponent(String(take))}`);
        return response.ok ? response.json() : [];
    },

    async adminImportStock(productId: number, input: { quantity: number; note?: string }): Promise<{ productID: number; stockQuantity: number } | null> {
        const response = await fetch(`${API_BASE_URL}/Admin/Products/${productId}/stock/import`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ quantity: input.quantity, note: input.note ?? null }),
        });
        if (!response.ok) {
            const msg = await response.text();
            throw new Error(msg || 'Nhập kho thất bại');
        }
        return await response.json();
    },

    async getUserCart(userId: number): Promise<ServerCartDto | null> {
        const response = await fetch(`${API_BASE_URL}/Cart/user/${encodeURIComponent(String(userId))}`);
        return response.ok ? response.json() : null;
    },

    async replaceUserCart(userId: number, items: Array<{ productID: number; quantity: number }>): Promise<ServerCartDto | null> {
        const response = await fetch(`${API_BASE_URL}/Cart/user/${encodeURIComponent(String(userId))}`, {
            method: 'PUT',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(items || []),
        });
        if (!response.ok) {
            const msg = await response.text();
            throw new Error(parseApiErrorBody(msg, 'Cập nhật giỏ hàng thất bại'));
        }
        return await response.json();
    },
    /** Đọc danh mục (trang chủ, shop) — chỉ GET công khai. */
    async getCategories(): Promise<Category[]> {
        const response = await fetch(`${API_BASE_URL}/Categories`);
        return response.ok ? response.json() : [];
    },

    /** Admin: danh sách có kèm sản phẩm (sắp xếp theo tên). */
    async getAdminCategories(): Promise<Category[]> {
        const response = await fetch(`${API_BASE_URL}/Admin/Categories`);
        return response.ok ? response.json() : [];
    },

    async adminCreateCategory(input: { categoryName: string; description?: string }): Promise<Category | null> {
        const response = await fetch(`${API_BASE_URL}/Admin/Categories`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ categoryName: input.categoryName, description: input.description ?? '' }),
        });
        return response.ok ? response.json() : null;
    },

    async adminUpdateCategory(id: number, input: { categoryName: string; description?: string }): Promise<Category | null> {
        const response = await fetch(`${API_BASE_URL}/Admin/Categories/${id}`, {
            method: 'PUT',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ categoryID: id, categoryName: input.categoryName, description: input.description ?? '' }),
        });
        return response.ok ? response.json() : null;
    },

    async adminDeleteCategory(id: number): Promise<{ ok: boolean; message?: string }> {
        const response = await fetch(`${API_BASE_URL}/Admin/Categories/${id}`, { method: 'DELETE' });
        if (response.ok) return { ok: true };
        const message = await response.text();
        return { ok: false, message: message || 'Xóa thất bại' };
    },

    async getAdminSuppliersPage(input?: {
        page?: number;
        pageSize?: number;
        tab?: 'all' | 'pending' | 'paused';
        q?: string;
    }): Promise<AdminSuppliersPage> {
        const page = input?.page ?? 1;
        const pageSize = input?.pageSize ?? 10;
        const tab = input?.tab ?? 'all';
        const params = new URLSearchParams();
        params.set('page', String(page));
        params.set('pageSize', String(pageSize));
        params.set('tab', tab);
        if (input?.q) params.set('q', input.q);
        const response = await fetch(`${API_BASE_URL}/Admin/Suppliers?${params.toString()}`);
        if (!response.ok) throw new Error('Không tải được nhà cung cấp');
        return await response.json();
    },

    async adminCreateSupplier(input: {
        supplierName: string;
        contactName?: string;
        phone?: string;
        email?: string;
        address?: string;
        supplierCode?: string;
        imageUrl?: string;
        status?: string;
        isVerified?: boolean;
    }): Promise<AdminSupplierRow | null> {
        const response = await fetch(`${API_BASE_URL}/Admin/Suppliers`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                supplierName: input.supplierName,
                contactName: input.contactName ?? '',
                phone: input.phone ?? '',
                email: input.email ?? '',
                address: input.address ?? '',
                supplierCode: input.supplierCode ?? '',
                imageUrl: input.imageUrl ?? '',
                status: input.status ?? 'Pending',
                isVerified: input.isVerified ?? false,
            }),
        });
        return response.ok ? response.json() : null;
    },

    async adminUpdateSupplier(
        id: number,
        input: {
            supplierName: string;
            contactName?: string;
            phone?: string;
            email?: string;
            address?: string;
            supplierCode?: string;
            imageUrl?: string;
            status?: string;
            isVerified?: boolean;
        },
    ): Promise<AdminSupplierRow | null> {
        const response = await fetch(`${API_BASE_URL}/Admin/Suppliers/${id}`, {
            method: 'PUT',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                supplierName: input.supplierName,
                contactName: input.contactName ?? '',
                phone: input.phone ?? '',
                email: input.email ?? '',
                address: input.address ?? '',
                supplierCode: input.supplierCode ?? '',
                imageUrl: input.imageUrl ?? '',
                status: input.status ?? 'Active',
                isVerified: input.isVerified ?? false,
            }),
        });
        return response.ok ? response.json() : null;
    },

    async adminDeleteSupplier(id: number): Promise<{ ok: boolean; message?: string }> {
        const response = await fetch(`${API_BASE_URL}/Admin/Suppliers/${id}`, { method: 'DELETE' });
        if (response.ok) return { ok: true };
        const message = await response.text();
        return { ok: false, message: message || 'Xóa thất bại' };
    },

    async getAdminProductsPage(input?: {
        page?: number;
        pageSize?: number;
        q?: string;
        categoryId?: number;
        status?: 'Active' | 'Inactive' | 'all';
    }): Promise<AdminProductsPage> {
        const page = input?.page ?? 1;
        const pageSize = input?.pageSize ?? 10;
        const params = new URLSearchParams();
        params.set('page', String(page));
        params.set('pageSize', String(pageSize));
        if (input?.q) params.set('q', input.q);
        if (input?.categoryId != null && input.categoryId > 0) params.set('categoryId', String(input.categoryId));
        if (input?.status && input.status !== 'all') params.set('status', input.status);
        const response = await fetch(`${API_BASE_URL}/Admin/Products?${params.toString()}`);
        if (!response.ok) throw new Error('Không tải được danh sách sản phẩm');
        return await response.json();
    },

    async getAdminOrdersPage(input?: { page?: number; pageSize?: number; status?: string; q?: string }): Promise<AdminOrdersPage> {
        const page = input?.page ?? 1;
        const pageSize = input?.pageSize ?? 10;
        const params = new URLSearchParams();
        params.set('page', String(page));
        params.set('pageSize', String(pageSize));
        if (input?.status) params.set('status', input.status);
        if (input?.q) params.set('q', input.q);
        const response = await fetch(`${API_BASE_URL}/Admin/Orders?${params.toString()}`);
        if (!response.ok) throw new Error('Không tải được danh sách đơn hàng');
        return await response.json();
    },

    async getAdminOrderDetail(id: number): Promise<AdminOrderDetail> {
        const response = await fetch(`${API_BASE_URL}/Admin/Orders/${id}`);
        if (!response.ok) throw new Error('Không tải được chi tiết đơn hàng');
        return await response.json();
    },

    async getAdminOrderDetailByToken(token: string): Promise<AdminOrderDetail> {
        const response = await fetch(`${API_BASE_URL}/Admin/Orders/token/${encodeURIComponent(token)}`);
        if (!response.ok) throw new Error('Không tải được chi tiết đơn hàng');
        return await response.json();
    },

    async adminUpdateOrderStatus(id: number, status: string): Promise<boolean> {
        const response = await fetch(`${API_BASE_URL}/Admin/Orders/${id}/status`, {
            method: 'PUT',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ status })
        });
        return response.ok;
    },

    async adminCancelOrder(id: number, reason?: string | null): Promise<boolean> {
        const response = await fetch(`${API_BASE_URL}/Admin/Orders/${id}/cancel`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ reason: reason || null }),
        });
        if (!response.ok) {
            const msg = await response.text();
            throw new Error(msg || 'Hủy đơn thất bại.');
        }
        return true;
    },

    async adminUpdateShipmentDetails(
        shipmentId: number,
        input: { trackingNumber?: string | null; carrier?: string | null }
    ): Promise<boolean> {
        const response = await fetch(`${API_BASE_URL}/Admin/Shipments/${shipmentId}/details`, {
            method: 'PUT',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                trackingNumber: input.trackingNumber ?? null,
                carrier: input.carrier ?? null,
            }),
        });
        return response.ok;
    },

    /** Tra cứu vận đơn công khai: mã đơn + SĐT (khớp SĐT tài khoản đặt hàng). */
    async trackOrder(orderCode: string, phone: string): Promise<PublicOrderTrack | null> {
        const params = new URLSearchParams();
        params.set('orderCode', orderCode.trim());
        params.set('phone', phone.trim());
        const response = await fetch(`${API_BASE_URL}/Orders/track?${params.toString()}`);
        if (response.status === 404) return null;
        if (!response.ok) {
            const t = await response.text();
            throw new Error(parseApiErrorBody(t, 'Tra cứu thất bại'));
        }
        return response.json();
    },

    async adminCreateProduct(input: {
        productName: string;
        categoryID?: number | null;
        supplierID?: number | null;
        price: number;
        discountPrice?: number | null;
        stockQuantity: number;
        unit?: string;
        description?: string;
        manufacturedDate?: string | null;
        expiryDate?: string | null;
        origin?: string | null;
        storageInstructions?: string | null;
        certifications?: string | null;
        status?: 'Active' | 'Inactive';
    }): Promise<Product | null> {
        const response = await fetch(`${API_BASE_URL}/Admin/Products`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                productName: input.productName,
                categoryID: input.categoryID ?? null,
                supplierID: input.supplierID ?? null,
                price: input.price,
                discountPrice: input.discountPrice ?? null,
                stockQuantity: input.stockQuantity,
                unit: input.unit ?? 'kg',
                description: input.description ?? '',
                manufacturedDate: input.manufacturedDate ?? null,
                expiryDate: input.expiryDate ?? null,
                origin: input.origin ?? null,
                storageInstructions: input.storageInstructions ?? null,
                certifications: input.certifications ?? null,
                status: input.status ?? 'Active',
            }),
        });
        return response.ok ? response.json() : null;
    },

    async adminUpdateProduct(
        id: number,
        input: {
            productName: string;
            categoryID?: number | null;
            supplierID?: number | null;
            price: number;
            discountPrice?: number | null;
            stockQuantity: number;
            unit?: string;
            description?: string;
            manufacturedDate?: string | null;
            expiryDate?: string | null;
            origin?: string | null;
            storageInstructions?: string | null;
            certifications?: string | null;
            status?: 'Active' | 'Inactive';
        },
    ): Promise<Product | null> {
        const response = await fetch(`${API_BASE_URL}/Admin/Products/${id}`, {
            method: 'PUT',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                productName: input.productName,
                categoryID: input.categoryID ?? null,
                supplierID: input.supplierID ?? null,
                price: input.price,
                discountPrice: input.discountPrice ?? null,
                stockQuantity: input.stockQuantity,
                unit: input.unit ?? 'kg',
                description: input.description ?? '',
                manufacturedDate: input.manufacturedDate ?? null,
                expiryDate: input.expiryDate ?? null,
                origin: input.origin ?? null,
                storageInstructions: input.storageInstructions ?? null,
                certifications: input.certifications ?? null,
                status: input.status ?? null,
            }),
        });
        return response.ok ? response.json() : null;
    },

    async adminDeleteProduct(id: number): Promise<{ ok: boolean; message?: string }> {
        const response = await fetch(`${API_BASE_URL}/Products/${id}`, { method: 'DELETE' });
        if (response.ok) return { ok: true };
        const message = await response.text();
        return { ok: false, message: message || 'Xóa thất bại' };
    },

    async getProducts(
        categoryIdOrOpts?: number | GetProductsQuery,
        searchTerm?: string,
        signal?: AbortSignal,
    ): Promise<Product[]> {
        const opts: GetProductsQuery =
            typeof categoryIdOrOpts === 'object' && categoryIdOrOpts !== null
                ? categoryIdOrOpts
                : {
                    categoryId: categoryIdOrOpts,
                    searchTerm,
                    signal,
                };

        const params = new URLSearchParams();
        if (opts.categoryId !== undefined && opts.categoryId !== null) {
            params.append('categoryID', String(opts.categoryId));
        }
        if (opts.searchTerm) params.append('searchTerm', opts.searchTerm);
        if (opts.minPrice != null) params.append('minPrice', String(opts.minPrice));
        if (opts.maxPrice != null) params.append('maxPrice', String(opts.maxPrice));
        if (opts.sort) params.append('sort', opts.sort);

        try {
            const url = `${API_BASE_URL}/Products${params.toString() ? `?${params.toString()}` : ''}`;
            const response = await fetch(url, { signal: opts.signal });
            return response.ok ? response.json() : [];
        } catch (error) {
            if (error instanceof Error && error.name === 'AbortError') {
                throw error;
            }
            console.error('Error fetching products:', error);
            return [];
        }
    },

    async getPromotions(): Promise<Product[]> {
        const response = await fetch(`${API_BASE_URL}/Products/Promotions`);
        return response.ok ? response.json() : [];
    },

    async getProduct(id: number): Promise<Product | null> {
        const response = await fetch(`${API_BASE_URL}/Products/${id}`);
        return response.ok ? response.json() : null;
    },

    async getProductByToken(token: string): Promise<Product | null> {
        const response = await fetch(`${API_BASE_URL}/Products/token/${encodeURIComponent(token)}`);
        return response.ok ? response.json() : null;
    },

    async submitContactForm(contactData: {
        name: string;
        email: string;
        subject: string;
        message: string;
    }): Promise<{ contactMessageID: number }> {
        const response = await fetch(`${API_BASE_URL}/ContactMessages`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                name: contactData.name,
                email: contactData.email,
                subject: contactData.subject,
                message: contactData.message,
            }),
        });
        if (!response.ok) {
            const msg = await response.text();
            throw new Error(parseApiErrorBody(msg, 'Gửi tin nhắn thất bại'));
        }
        return await response.json();
    },

    async getUserAddresses(userId: number): Promise<UserAddress[]> {
        const response = await fetch(`${API_BASE_URL}/UserAddresses/user/${userId}`);
        if (!response.ok) throw new Error('Không tải được sổ địa chỉ');
        const raw = (await response.json()) as unknown[];
        return raw.map((r: any) => ({
            userAddressID: r.userAddressID ?? r.UserAddressID,
            label: r.label ?? r.Label ?? null,
            recipientName: r.recipientName ?? r.RecipientName ?? '',
            phone: r.phone ?? r.Phone ?? null,
            addressLine: r.addressLine ?? r.AddressLine ?? '',
            isDefault: Boolean(r.isDefault ?? r.IsDefault),
            createdAt: String(r.createdAt ?? r.CreatedAt ?? ''),
        }));
    },

    async createUserAddress(
        userId: number,
        body: { recipientName: string; phone?: string; addressLine: string; label?: string; isDefault?: boolean }
    ) {
        const response = await fetch(`${API_BASE_URL}/UserAddresses/user/${userId}`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                recipientName: body.recipientName,
                phone: body.phone,
                addressLine: body.addressLine,
                label: body.label,
                isDefault: body.isDefault ?? false,
            }),
        });
        if (!response.ok) {
            const msg = await response.text();
            throw new Error(parseApiErrorBody(msg, 'Không thêm được địa chỉ'));
        }
        return await response.json();
    },

    async updateUserAddress(
        addressId: number,
        userId: number,
        body: { recipientName: string; phone?: string; addressLine: string; label?: string; isDefault?: boolean }
    ) {
        const response = await fetch(
            `${API_BASE_URL}/UserAddresses/${addressId}?userId=${encodeURIComponent(String(userId))}`,
            {
                method: 'PUT',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({
                    recipientName: body.recipientName,
                    phone: body.phone,
                    addressLine: body.addressLine,
                    label: body.label,
                    isDefault: body.isDefault ?? false,
                }),
            }
        );
        if (!response.ok) {
            const msg = await response.text();
            throw new Error(parseApiErrorBody(msg, 'Không cập nhật được địa chỉ'));
        }
        return await response.json();
    },

    async deleteUserAddress(addressId: number, userId: number): Promise<void> {
        const response = await fetch(
            `${API_BASE_URL}/UserAddresses/${addressId}?userId=${encodeURIComponent(String(userId))}`,
            { method: 'DELETE' }
        );
        if (!response.ok) {
            const msg = await response.text();
            throw new Error(parseApiErrorBody(msg, 'Không xóa được địa chỉ'));
        }
    },

    async setDefaultUserAddress(addressId: number, userId: number) {
        const response = await fetch(
            `${API_BASE_URL}/UserAddresses/${addressId}/set-default?userId=${encodeURIComponent(String(userId))}`,
            { method: 'PUT' }
        );
        if (!response.ok) {
            const msg = await response.text();
            throw new Error(parseApiErrorBody(msg, 'Không đặt mặc định được'));
        }
        return await response.json();
    },

    async createOrder(orderData: {
        userID?: number;
        guestCheckout?: { fullName: string; email: string; phone: string };
        shippingAddress: string;
        shippingAddressId?: number;
        shippingMethodID?: number;
        paymentMethod?: string;
        voucherCode?: string;
        items: Array<{ productID: number; quantity: number }>;
    }): Promise<any> {
        const response = await fetch(`${API_BASE_URL}/Orders`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(orderData)
        });
        if (!response.ok) {
            const msg = await response.text();
            throw new Error(parseApiErrorBody(msg, 'Đặt hàng thất bại'));
        }
        return await response.json();
    },

    async getShippingMethods(): Promise<ShippingMethod[]> {
        const response = await fetch(`${API_BASE_URL}/ShippingMethods`);
        return response.ok ? response.json() : [];
    },

    async getActiveVouchers(userID?: number): Promise<Voucher[]> {
        const qs = userID ? `?userId=${encodeURIComponent(String(userID))}` : '';
        const response = await fetch(`${API_BASE_URL}/Vouchers/active${qs}`);
        return response.ok ? response.json() : [];
    },

    async validateVoucher(input: { userID: number; code: string; subtotal: number; shipping: number; tax: number }): Promise<any> {
        const response = await fetch(`${API_BASE_URL}/Vouchers/validate`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(input)
        });
        if (!response.ok) {
            const msg = await response.text();
            throw new Error(msg || 'Voucher invalid');
        }
        return await response.json();
    },

    // ---------------------------
    // Admin Vouchers (CRUD)
    // ---------------------------
    async getAdminVouchers(input?: { q?: string; active?: boolean }): Promise<Voucher[]> {
        const params = new URLSearchParams();
        if (input?.q) params.set('q', input.q);
        if (typeof input?.active === 'boolean') params.set('active', String(input.active));
        const qs = params.toString() ? `?${params.toString()}` : '';
        const response = await fetch(`${API_BASE_URL}/Admin/Vouchers${qs}`);
        if (!response.ok) throw new Error('Không tải được vouchers');
        return await response.json();
    },

    async getAdminVoucher(id: number): Promise<Voucher | null> {
        const response = await fetch(`${API_BASE_URL}/Admin/Vouchers/${id}`);
        return response.ok ? response.json() : null;
    },

    async getAdminVoucherByToken(token: string): Promise<Voucher | null> {
        const t = (token || '').trim();
        if (!t) return null;
        const response = await fetch(`${API_BASE_URL}/Admin/Vouchers/token/${encodeURIComponent(t)}`);
        return response.ok ? response.json() : null;
    },

    async adminCreateVoucher(input: {
        code: string;
        discountType?: string | null;
        discountValue: number;
        minOrderAmount: number;
        expiryDate?: string | null;
        isActive: boolean;
    }): Promise<Voucher | null> {
        const response = await fetch(`${API_BASE_URL}/Admin/Vouchers`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(input),
        });
        if (!response.ok) return null;
        return await response.json();
    },

    async adminUpdateVoucher(
        id: number,
        input: {
            code: string;
            discountType?: string | null;
            discountValue: number;
            minOrderAmount: number;
            expiryDate?: string | null;
            isActive: boolean;
        },
    ): Promise<Voucher | null> {
        const response = await fetch(`${API_BASE_URL}/Admin/Vouchers/${id}`, {
            method: 'PUT',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(input),
        });
        if (!response.ok) return null;
        return await response.json();
    },

    async adminDeleteVoucher(id: number): Promise<{ ok: boolean; message?: string }> {
        const response = await fetch(`${API_BASE_URL}/Admin/Vouchers/${id}`, { method: 'DELETE' });
        if (response.ok) return { ok: true };
        const message = await response.text();
        return { ok: false, message: message || 'Xóa thất bại' };
    },

    async createVnPayPaymentUrl(orderID: number): Promise<string> {
        const response = await fetch(`${API_BASE_URL}/VnPay/CreatePaymentUrl`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ orderID })
        });
        if (!response.ok) throw new Error('Failed to create VNPay payment url');
        const data = await response.json();
        return data.paymentUrl as string;
    },

    async createVnPayPaymentUrlPublic(orderCode: string): Promise<string> {
        const code = (orderCode || '').trim();
        if (!code) throw new Error('Thiếu mã đơn hàng.');
        const response = await fetch(`${API_BASE_URL}/VnPay/CreatePaymentUrlPublic`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ orderCode: code })
        });
        if (!response.ok) {
            const msg = parseApiErrorBody(await response.text(), 'Không tạo được link thanh toán VNPay');
            throw new Error(msg);
        }
        const data = await response.json();
        return data.paymentUrl as string;
    },

    async createMomoPaymentUrl(
        orderID: number,
        payMethod: 'method' | 'wallet' | 'atm' = 'method'
    ): Promise<{ paymentUrl?: string; qrCodeUrl?: string; deeplink?: string; resultCode?: number; message?: string }> {
        const response = await fetch(`${API_BASE_URL}/Momo/CreatePaymentUrl`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ orderID, payMethod })
        });
        if (!response.ok) {
            const msg = parseApiErrorBody(await response.text(), 'Không tạo được link thanh toán MoMo');
            throw new Error(msg);
        }
        const data = await response.json();
        return {
            paymentUrl: data.paymentUrl as string | undefined,
            qrCodeUrl: data.qrCodeUrl as string | undefined,
            deeplink: data.deeplink as string | undefined,
            resultCode: typeof data.resultCode === 'number' ? (data.resultCode as number) : undefined,
            message: data.message as string | undefined
        };
    },

    async createMomoPaymentUrlPublic(
        orderCode: string,
        payMethod: 'method' | 'wallet' | 'atm' = 'method'
    ): Promise<{ paymentUrl?: string; qrCodeUrl?: string; deeplink?: string; resultCode?: number; message?: string }> {
        const code = (orderCode || '').trim();
        if (!code) throw new Error('Thiếu mã đơn hàng.');
        const response = await fetch(`${API_BASE_URL}/Momo/CreatePaymentUrlPublic`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ orderCode: code, payMethod })
        });
        if (!response.ok) {
            const msg = parseApiErrorBody(await response.text(), 'Không tạo được link thanh toán MoMo');
            throw new Error(msg);
        }
        const data = await response.json();
        return {
            paymentUrl: data.paymentUrl as string | undefined,
            qrCodeUrl: data.qrCodeUrl as string | undefined,
            deeplink: data.deeplink as string | undefined,
            resultCode: typeof data.resultCode === 'number' ? (data.resultCode as number) : undefined,
            message: data.message as string | undefined
        };
    },

    async login(loginData: { email: string; password: string }): Promise<{ user: any; token: string; expiresInSeconds?: number }> {
        const response = await fetch(`${API_BASE_URL}/Account/login`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(loginData),
        });
        const text = await response.text();
        if (!response.ok) {
            throw new Error(parseApiErrorBody(text, 'Đăng nhập thất bại. Vui lòng thử lại.'));
        }
        if (!text.trim()) throw new Error('Phản hồi máy chủ không hợp lệ.');
        const j = JSON.parse(text) as any;
        return {
            user: j.user ?? j.User ?? j,
            token: j.token ?? j.Token ?? '',
            expiresInSeconds: j.expiresInSeconds ?? j.ExpiresInSeconds ?? undefined,
        };
    },

    async register(registerData: any): Promise<any> {
        const response = await fetch(`${API_BASE_URL}/Account/register`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(registerData)
        });
        if (!response.ok) throw new Error('Registration failed');
        return await response.json();
    },

    async forgotPassword(input: { email: string }): Promise<{ ok: boolean; token?: string }> {
        const response = await fetch(`${API_BASE_URL}/Account/forgot-password`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(input),
        });
        const text = await response.text();
        if (!response.ok) {
            throw new Error(parseApiErrorBody(text, 'Gửi yêu cầu thất bại.'));
        }
        if (!text.trim()) return { ok: true };
        return JSON.parse(text) as { ok: boolean; token?: string };
    },

    async resetPassword(input: { email: string; token: string; newPassword: string }): Promise<{ ok: boolean }> {
        const response = await fetch(`${API_BASE_URL}/Account/reset-password`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(input),
        });
        const text = await response.text();
        if (!response.ok) {
            throw new Error(parseApiErrorBody(text, 'Đặt lại mật khẩu thất bại.'));
        }
        if (!text.trim()) return { ok: true };
        return JSON.parse(text) as { ok: boolean };
    },

    /** Tài khoản khách sau đơn — token Purpose guest_activate (email), không dùng reset-password. */
    async setInitialPassword(input: { email: string; token: string; newPassword: string }): Promise<{ ok: boolean }> {
        const response = await fetch(`${API_BASE_URL}/Account/set-initial-password`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(input),
        });
        const text = await response.text();
        if (!response.ok) {
            throw new Error(parseApiErrorBody(text, 'Đặt mật khẩu thất bại.'));
        }
        if (!text.trim()) return { ok: true };
        return JSON.parse(text) as { ok: boolean };
    },

    async updateProfile(userID: number, input: { fullName: string; phone?: string; address?: string }): Promise<any> {
        const response = await fetch(`${API_BASE_URL}/Account/${userID}`, {
            method: 'PUT',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(input)
        });
        if (!response.ok) {
            const msg = await response.text();
            throw new Error(msg || 'Failed to update profile');
        }
        return await response.json();
    },

    async changePassword(input: { userID: number; currentPassword: string; newPassword: string }): Promise<any> {
        const response = await fetch(`${API_BASE_URL}/Account/change-password`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(input)
        });
        if (!response.ok) {
            const msg = await response.text();
            throw new Error(msg || 'Failed to change password');
        }
        return await response.json();
    },

    async uploadAvatar(userID: number, file: File): Promise<any> {
        const fd = new FormData();
        fd.append('file', file, file.name || 'avatar.jpg');
        const response = await fetch(`${API_BASE_URL}/Account/${userID}/avatar`, {
            method: 'POST',
            body: fd
        });
        if (!response.ok) {
            const msg = await response.text();
            throw new Error(msg || 'Failed to upload avatar');
        }
        return await response.json();
    },

    /** Đọc lại user từ DB (đủ avatarUrl sau upload). */
    async getAccountUser(userID: number): Promise<any> {
        const response = await fetch(`${API_BASE_URL}/Account/${userID}`);
        if (!response.ok) {
            const msg = await response.text();
            throw new Error(msg || 'Failed to load profile');
        }
        return await response.json();
    },

    async getRecentReviews(take: number = 3): Promise<RecentReview[]> {
        const params = new URLSearchParams();
        params.append('take', String(take));
        const response = await fetch(`${API_BASE_URL}/Reviews/Recent?${params.toString()}`);
        return response.ok ? response.json() : [];
    },

    async getReviewSummary(): Promise<ReviewSummary> {
        const response = await fetch(`${API_BASE_URL}/Reviews/Summary`);
        return response.ok ? response.json() : { averageRating: 0, totalReviews: 0 };
    },

    async createReview(input: { productID: number; userID: number; rating: number; comment?: string; imageUrls?: string[] }) {
        const response = await fetch(`${API_BASE_URL}/Reviews`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(input)
        });
        if (!response.ok) {
            const msg = await response.text();
            throw new Error(msg || 'Gửi đánh giá thất bại.');
        }
        return await response.json();
    },

    async uploadReviewImages(files: File[]): Promise<string[]> {
        if (!files || files.length === 0) return [];
        const fd = new FormData();
        files.slice(0, 3).forEach(f => fd.append('files', f));
        const response = await fetch(`${API_BASE_URL}/Reviews/UploadImages`, {
            method: 'POST',
            body: fd
        });
        if (!response.ok) {
            const msg = await response.text();
            throw new Error(msg || 'Upload ảnh đánh giá thất bại.');
        }
        return await response.json();
    },

    async adminUploadProductImages(productId: number, files: File[], mainIndex?: number): Promise<{ imageID: number; imageURL: string; isMainImage: boolean }[]> {
        if (!files || files.length === 0) return [];
        const fd = new FormData();
        files.slice(0, 10).forEach(f => fd.append('files', f));
        if (mainIndex != null && Number.isFinite(mainIndex)) fd.append('mainIndex', String(mainIndex));
        const response = await fetch(`${API_BASE_URL}/Admin/Products/${productId}/Images`, {
            method: 'POST',
            body: fd
        });
        if (!response.ok) {
            const msg = await response.text();
            throw new Error(msg || 'Failed to upload product images');
        }
        return await response.json();
    },

    async adminSetMainProductImage(productId: number, imageId: number): Promise<boolean> {
        const response = await fetch(`${API_BASE_URL}/Admin/Products/${productId}/Images/${imageId}/Main`, { method: 'PUT' });
        return response.ok;
    },

    async adminDeleteProductImage(productId: number, imageId: number): Promise<boolean> {
        const response = await fetch(`${API_BASE_URL}/Admin/Products/${productId}/Images/${imageId}`, { method: 'DELETE' });
        return response.ok;
    },

    async getUserOrders(userId: number): Promise<Order[]> {
        const response = await fetch(`${API_BASE_URL}/Orders/User/${userId}`);
        return response.ok ? response.json() : [];
    },

    async getOrder(id: number): Promise<Order | null> {
        const response = await fetch(`${API_BASE_URL}/Orders/${id}`);
        return response.ok ? response.json() : null;
    },

    async getOrderByToken(token: string): Promise<Order | null> {
        const response = await fetch(`${API_BASE_URL}/Orders/token/${encodeURIComponent(token)}`);
        return response.ok ? response.json() : null;
    },

    async getWishlist(userId: number): Promise<WishlistItem[]> {
        const response = await fetch(`${API_BASE_URL}/Wishlists/User/${userId}`);
        return response.ok ? response.json() : [];
    },

    async getWishlistIds(userId: number): Promise<number[]> {
        const response = await fetch(`${API_BASE_URL}/Wishlists/Ids/${userId}`);
        return response.ok ? response.json() : [];
    },

    async toggleWishlist(input: { userID: number; productID: number }): Promise<{ wished: boolean } | null> {
        const response = await fetch(`${API_BASE_URL}/Wishlists/Toggle`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(input)
        });
        return response.ok ? response.json() : null;
    },

    async confirmCodPaid(orderID: number): Promise<Order | null> {
        const response = await fetch(`${API_BASE_URL}/Orders/${orderID}/confirm-cod-paid`, {
            method: 'POST'
        });
        return response.ok ? response.json() : null;
    },

    async confirmOrderReceived(orderID: number, userID: number): Promise<Order | null> {
        const response = await fetch(`${API_BASE_URL}/Orders/${orderID}/confirm-received`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ userID })
        });
        return response.ok ? response.json() : null;
    },

    async cancelOrder(orderID: number, userID: number, reason?: string): Promise<Order | null> {
        const response = await fetch(`${API_BASE_URL}/Orders/${orderID}/cancel`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ userID, reason: reason || null })
        });
        if (!response.ok) {
            const msg = await response.text();
            throw new Error(msg || 'Hủy đơn thất bại.');
        }
        return await response.json();
    },

    async markOrderPaymentFailed(orderID: number, userID: number, provider: 'MOMO' | 'VNPAY', code?: string | null): Promise<Order | null> {
        const response = await fetch(`${API_BASE_URL}/Orders/${orderID}/mark-payment-failed`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ userID, provider, code: code || null }),
        });
        return response.ok ? response.json() : null;
    },

    async getOrderReturnRequest(orderID: number, userID: number): Promise<ReturnRequest | null> {
        const response = await fetch(`${API_BASE_URL}/Orders/${orderID}/return-request?userId=${encodeURIComponent(String(userID))}`);
        return response.ok ? response.json() : null;
    },

    async createOrderReturnRequest(orderID: number, userID: number, reason: string, files: File[], video?: File | null): Promise<{ returnRequestID: number } | null> {
        const fd = new FormData();
        fd.append('userId', String(userID));
        fd.append('reason', reason);
        (files || []).slice(0, 6).forEach(f => fd.append('files', f));
        if (video) fd.append('video', video);
        const response = await fetch(`${API_BASE_URL}/Orders/${orderID}/return-request`, {
            method: 'POST',
            body: fd
        });
        if (!response.ok) {
            const msg = await response.text();
            throw new Error(msg || 'Không tạo được yêu cầu hoàn hàng');
        }
        return await response.json();
    },

    async adminGetReturnRequestByOrder(orderID: number): Promise<ReturnRequest | null> {
        const response = await fetch(`${API_BASE_URL}/Admin/ReturnRequests/ByOrder/${orderID}`);
        return response.ok ? response.json() : null;
    },

    async adminUpdateReturnRequestStatus(returnRequestID: number, status: 'Pending' | 'Approved' | 'Rejected', adminNote?: string): Promise<boolean> {
        const response = await fetch(`${API_BASE_URL}/Admin/ReturnRequests/${returnRequestID}/Status`, {
            method: 'PUT',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ status, adminNote: adminNote || null })
        });
        return response.ok;
    },

    async adminUploadReturnRefundProof(returnRequestID: number, file: File, refundNote: string): Promise<{ refundProofUrl: string; refundNote?: string } | null> {
        const fd = new FormData();
        fd.append('file', file);
        fd.append('refundNote', refundNote);
        const response = await fetch(`${API_BASE_URL}/Admin/ReturnRequests/${returnRequestID}/RefundProof`, {
            method: 'POST',
            body: fd
        });
        if (!response.ok) {
            const msg = await response.text();
            throw new Error(msg || 'Upload ảnh chứng từ thất bại');
        }
        return await response.json();
    },

    async adminUpdateReturnRefundNote(returnRequestID: number, note: string): Promise<boolean> {
        const response = await fetch(`${API_BASE_URL}/Admin/ReturnRequests/${returnRequestID}/RefundNote`, {
            method: 'PUT',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ note })
        });
        return response.ok;
    }
    ,

    async adminGetRecentReturnRequests(take: number = 4): Promise<{ returnRequestID: number; orderID: number; orderToken: string; orderCode: string; userID: number; customerName: string; status: string; requestType: string; reason: string; createdAt: string }[]> {
        const params = new URLSearchParams();
        params.set('take', String(Math.max(1, Math.min(20, take || 4))));
        const response = await fetch(`${API_BASE_URL}/Admin/ReturnRequests/Recent?${params.toString()}`);
        return response.ok ? response.json() : [];
    }
    ,

    async adminGetReviews(params?: { status?: 'pending' | 'approved' | 'hidden' | 'deleted'; q?: string; skip?: number; take?: number }) {
        const qs = new URLSearchParams();
        if (params?.status) qs.set('status', params.status);
        if (params?.q) qs.set('q', params.q);
        if (typeof params?.skip === 'number') qs.set('skip', String(params.skip));
        if (typeof params?.take === 'number') qs.set('take', String(params.take));
        const response = await fetch(`${API_BASE_URL}/Admin/Reviews${qs.toString() ? `?${qs.toString()}` : ''}`);
        if (!response.ok) throw new Error('Failed to load reviews');
        return await response.json();
    },

    async adminApproveReview(reviewID: number, note?: string) {
        const response = await fetch(`${API_BASE_URL}/Admin/Reviews/${reviewID}/approve`, {
            method: 'PATCH',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ note: note ?? null })
        });
        if (!response.ok) throw new Error('Failed to approve review');
    },

    async adminHideReview(reviewID: number, note?: string) {
        const response = await fetch(`${API_BASE_URL}/Admin/Reviews/${reviewID}/hide`, {
            method: 'PATCH',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ note: note ?? null })
        });
        if (!response.ok) throw new Error('Failed to hide review');
    },

    async adminSetReviewPending(reviewID: number, note?: string) {
        const response = await fetch(`${API_BASE_URL}/Admin/Reviews/${reviewID}/pending`, {
            method: 'PATCH',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ note: note ?? null })
        });
        if (!response.ok) throw new Error('Failed to set pending review');
    },

    async adminSetReviewReply(reviewID: number, reply?: string) {
        const response = await fetch(`${API_BASE_URL}/Admin/Reviews/${reviewID}/reply`, {
            method: 'PATCH',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ reply: reply ?? null })
        });
        if (!response.ok) throw new Error('Failed to set review reply');
    },

    async adminDeleteReview(reviewID: number) {
        const response = await fetch(`${API_BASE_URL}/Admin/Reviews/${reviewID}`, { method: 'DELETE' });
        if (!response.ok) throw new Error('Failed to delete review');
    }

    ,

    async adminRestoreReview(reviewID: number) {
        const response = await fetch(`${API_BASE_URL}/Admin/Reviews/${reviewID}/restore`, { method: 'PATCH' });
        if (!response.ok) throw new Error('Failed to restore review');
    }

    ,

    async adminGetReviewStats(): Promise<{ total: number; pending: number; approved: number; hidden: number; deleted: number; replied: number; repliedPercent: number }> {
        const response = await fetch(`${API_BASE_URL}/Admin/Reviews/stats`);
        if (!response.ok) throw new Error('Failed to load review stats');
        return await response.json();
    },

    async getAiRecipeSuggestion(ingredients: string[]): Promise<string> {
        const response = await fetch(`${API_BASE_URL}/AI/suggest-recipe`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ ingredients }),
        });
        if (!response.ok) {
            const msg = await response.text();
            throw new Error(parseApiErrorBody(msg, 'Không thể lấy gợi ý từ AI'));
        }
        const data = await response.json();
        return data.suggestion || '';
    },
};
