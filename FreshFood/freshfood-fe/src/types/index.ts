export interface Category {
    categoryID: number;
    categoryName: string;
    description?: string;
    products?: Product[];
}

export interface Supplier {
    supplierID: number;
    supplierName: string;
    contactName?: string;
    phone?: string;
    email?: string;
    address?: string;
    supplierCode?: string | null;
    imageUrl?: string | null;
    status?: string;
    isVerified?: boolean;
    createdAt?: string;
}

export interface AdminSupplierRow {
    supplierID: number;
    supplierName: string;
    supplierCode?: string | null;
    contactName?: string | null;
    phone?: string | null;
    email?: string | null;
    address?: string | null;
    status: string;
    isVerified: boolean;
    imageUrl?: string | null;
    productCount: number;
}

export interface AdminSupplierStats {
    total: number;
    verified: number;
    inTransaction: number;
    newThisMonth: number;
}

export interface AdminSuppliersPage {
    items: AdminSupplierRow[];
    totalCount: number;
    page: number;
    pageSize: number;
    stats: AdminSupplierStats;
}

export interface AdminProductRow {
    productID: number;
    productToken?: string | null;
    productName: string;
    sku: string;
    categoryName?: string | null;
    categoryID?: number | null;
    supplierName?: string | null;
    imageUrl?: string | null;
    price: number;
    discountPrice?: number | null;
    stockQuantity: number;
    unit?: string | null;
    /** Active | Inactive */
    status: string;
    isOnSale: boolean;
    isLowStock: boolean;
}

export interface AdminProductStats {
    total: number;
    outOfStock: number;
    onSale: number;
    inventoryValue: number;
}

export interface AdminProductsPage {
    items: AdminProductRow[];
    totalCount: number;
    page: number;
    pageSize: number;
    stats: AdminProductStats;
}

export interface AdminUserStats {
    total: number;
    admins: number;
    customers: number;
    locked: number;
}

export interface AdminUserRow {
    userID: number;
    fullName: string;
    email: string;
    phone?: string | null;
    avatarUrl?: string | null;
    role: string;
    createdAt: string;
    isLocked: boolean;
    orderCount: number;
}

export interface AdminUsersPage {
    items: AdminUserRow[];
    totalCount: number;
    page: number;
    pageSize: number;
    stats: AdminUserStats;
}

/** Tin gửi từ form liên hệ (admin danh sách). */
export interface AdminContactMessageRow {
    contactMessageID: number;
    name: string;
    email: string;
    subject: string;
    messagePreview: string;
    createdAt: string;
    /** New | Processing | Replied */
    status: string;
    isUrgent: boolean;
}

export interface AdminContactMessagesPage {
    items: AdminContactMessageRow[];
    totalCount: number;
    page: number;
    pageSize: number;
}

export interface AdminContactMessageDetail {
    contactMessageID: number;
    name: string;
    email: string;
    subject: string;
    message: string;
    createdAt: string;
    status: string;
    isUrgent: boolean;
}

/** Địa chỉ giao hàng đã lưu (sổ địa chỉ). */
export interface UserAddress {
    userAddressID: number;
    label?: string | null;
    recipientName: string;
    phone?: string | null;
    addressLine: string;
    isDefault: boolean;
    createdAt: string;
}

export interface AdminOrderRow {
    orderID: number;
    orderToken?: string | null;
    orderCode: string;
    customerName: string;
    customerEmail: string;
    orderDate: string;
    totalAmount: number;
    status: string;
}

export interface AdminOrdersStats {
    dailyRevenue: number;
    shippingCount: number;
    pendingCount: number;
}

export interface AdminOrdersPage {
    items: AdminOrderRow[];
    totalCount: number;
    page: number;
    pageSize: number;
    stats: AdminOrdersStats;
}

export interface AdminOrderItem {
    productID: number;
    productName: string;
    sku?: string | null;
    thumbUrl?: string | null;
    quantity: number;
    unitPrice: number;
    lineTotal: number;
}

export interface AdminOrderCustomer {
    userID: number;
    fullName: string;
    email: string;
    phone?: string | null;
    avatarUrl?: string | null;
}

export interface AdminOrderPayment {
    method?: string | null;
    status?: string | null;
    amount: number;
    paymentDate: string;
}

export interface AdminShipmentRow {
    shipmentID: number;
    trackingNumber?: string | null;
    carrier?: string | null;
    shippedDate?: string | null;
    estimatedDeliveryDate?: string | null;
    actualDeliveryDate?: string | null;
    status?: string | null;
}

export interface AdminOrderDetail {
    orderID: number;
    orderCode: string;
    orderDate: string;
    status: string;
    pipelineStatus?: string;
    totalAmount: number;
    shippingMethodID?: number | null;
    shippingAddress: string;
    customer: AdminOrderCustomer;
    items: AdminOrderItem[];
    latestPayment?: AdminOrderPayment | null;
    shipments?: AdminShipmentRow[];
}

/** Kết quả tra cứu đơn công khai (api/Orders/track) */
export interface PublicOrderTrack {
    orderCode: string;
    status: string;
    orderDate: string;
    shipments: {
        shipmentID: number;
        trackingNumber?: string | null;
        carrier?: string | null;
        status?: string | null;
        shippedDate?: string | null;
        estimatedDeliveryDate?: string | null;
        actualDeliveryDate?: string | null;
    }[];
}

export interface ShippingMethod {
    methodID: number;
    methodName: string;
    baseCost: number;
    estimatedDays?: number | null;
}

export interface ReturnRequestImage {
    returnRequestImageID: number;
    imageUrl: string;
}

export interface ReturnRequest {
    returnRequestID: number;
    orderID: number;
    userID: number;
    status: 'Pending' | 'Approved' | 'Rejected' | string;
    requestType?: 'Return' | 'CancelRefund' | string;
    reason: string;
    adminNote?: string | null;
    videoUrl?: string | null;
    refundProofUrl?: string | null;
    /** Nội dung xác nhận đã chuyển khoản (kèm chứng từ) */
    refundNote?: string | null;
    createdAt: string;
    reviewedAt?: string | null;
    images: ReturnRequestImage[];
}

export interface ProductImage {
    imageID: number;
    productID: number;
    imageURL: string;
    isMainImage: boolean;
}

export interface Review {
    reviewID: number;
    productID: number;
    userID: number;
    rating: number;
    comment?: string;
    reviewDate: string;
    moderationStatus?: 'Pending' | 'Approved' | 'Hidden' | string;
    adminReply?: string | null;
    repliedAt?: string | null;
    user?: User;
    reviewImages?: ReviewImage[];
}

export interface AdminReviewRow {
    reviewID: number;
    productID: number;
    productToken?: string | null;
    productName: string;
    productSku?: string | null;
    productThumbUrl?: string | null;
    userID: number;
    userName: string;
    userAvatarUrl?: string | null;
    userEmail?: string | null;
    rating: number;
    comment?: string | null;
    reviewDate: string;
    imageUrls: string[];
    moderationStatus: 'Pending' | 'Approved' | 'Hidden' | string;
    moderatedAt?: string | null;
    moderationNote?: string | null;
    adminReply?: string | null;
    repliedAt?: string | null;
    isDeleted?: boolean;
    deletedAt?: string | null;
}

export interface AdminReviewListResponse {
    total: number;
    items: AdminReviewRow[];
}

export interface ReviewImage {
    reviewImageID: number;
    reviewID: number;
    imageUrl: string;
    sortOrder: number;
}

export interface ReviewSummary {
    averageRating: number;
    totalReviews: number;
}

export interface HomeHeroSettings {
    eyebrow: string;
    title: string;
    highlight: string;
    subtitle: string;
    imageUrl: string;
    primaryCtaText: string;
    primaryCtaHref: string;
    secondaryCtaText: string;
    secondaryCtaHref?: string | null;
    feature1Title: string;
    feature1Sub: string;
    feature2Title: string;
    feature2Sub: string;
}

export interface HomeRootsSettings {
    subheading: string;
    title: string;
    paragraph1: string;
    paragraph2: string;
    imageUrl: string;
    stat1Value: string;
    stat1Label: string;
    stat2Value: string;
    stat2Label: string;
}

export interface HomeSeasonalCardSettings {
    title: string;
    imageUrl: string;
}

export interface HomeSeasonalSettings {
    heading: string;
    subheading: string;
    cards: HomeSeasonalCardSettings[];
}

export interface HomePageSettings {
    hero: HomeHeroSettings;
    roots: HomeRootsSettings;
    seasonal: HomeSeasonalSettings;
}

export interface RecentReview {
    reviewID: number;
    productID: number;
    userID: number;
    userName: string;
    avatarUrl?: string | null;
    rating: number;
    comment?: string;
    reviewDate: string;
    imageUrls?: string[];
}

export interface Product {
    productID: number;
    productToken?: string | null;
    productName: string;
    sku?: string | null;
    categoryID?: number;
    category?: Category;
    supplierID?: number;
    supplier?: Supplier;
    price: number;
    discountPrice?: number;
    stockQuantity: number;
    unit?: string;
    description?: string;
    /** NSX — ngày sản xuất / thu hoạch */
    manufacturedDate?: string | null;
    /** HSD */
    expiryDate?: string | null;
    origin?: string | null;
    storageInstructions?: string | null;
    certifications?: string | null;
    /** Active | Inactive (public API chỉ trả Active) */
    status?: string | null;
    createdAt: string;
    productImages: ProductImage[];
    reviews: Review[];
    /** Average rating across approved reviews (from list endpoints) */
    averageRating?: number;
    /** Count of approved reviews (from list endpoints) */
    reviewCount?: number;
}

export interface User {
    userID: number;
    fullName: string;
    email: string;
    avatarUrl?: string | null;
    phone?: string;
    address?: string;
    role: string;
    createdAt: string;
}

export interface OrderDetail {
    orderDetailID: number;
    orderID: number;
    productID: number;
    quantity: number;
    unitPrice: number;
    product?: Product;
}

export interface Payment {
    paymentID: number;
    orderID: number;
    paymentDate: string;
    paymentMethod?: string | null;
    amount: number;
    status?: string | null;
}

export interface Shipment {
    shipmentID: number;
    orderID: number;
    trackingNumber?: string | null;
    carrier?: string | null;
    shippedDate?: string | null;
    estimatedDeliveryDate?: string | null;
    actualDeliveryDate?: string | null;
    status?: string | null;
}

export interface Order {
    orderID: number;
    orderToken?: string | null;
    orderCode?: string | null;
    userID: number;
    shippingMethodID?: number | null;
    orderDate: string;
    totalAmount: number;
    shippingAddress: string;
    status: string;
    orderDetails: OrderDetail[];
    payments?: Payment[];
    shipments?: Shipment[];
}

export interface Voucher {
    voucherID: number;
    voucherToken?: string | null;
    code: string;
    discountType?: string | null; // Percentage | Flat
    discountValue: number;
    minOrderAmount: number;
    expiryDate?: string | null;
    isActive: boolean;
}

export interface AdminDashboardKpi {
    key: 'revenue' | 'orders' | 'newCustomers' | 'stock' | string;
    label: string;
    value: number;
    unit?: string | null;
    deltaPercent: number;
}

export interface AdminRevenuePoint {
    label: string;
    value: number;
}

export interface AdminRecentOrder {
    orderID: number;
    orderCode: string;
    customerName: string;
    totalAmount: number;
    status: string;
    thumbUrl?: string | null;
}

export interface AdminDashboardDto {
    range: 'week' | 'month' | string;
    kpis: AdminDashboardKpi[];
    revenueSeries: AdminRevenuePoint[];
    recentOrders: AdminRecentOrder[];
}

export interface AdminLowStockProduct {
    productID: number;
    productName: string;
    stockQuantity: number;
    unit?: string | null;
    price: number;
    discountPrice?: number | null;
    thumbUrl?: string | null;
}

export interface AdminRecentImport {
    logID: number;
    productID: number;
    productName: string;
    importedQuantity: number;
    stockQuantity: number;
    unit?: string | null;
    logDate: string;
    note?: string | null;
    thumbUrl?: string | null;
}

export interface ServerCartItem {
    product: Product;
    quantity: number;
}

export interface ServerCartDto {
    cartID: number;
    userID: number;
    items: ServerCartItem[];
}

export interface WishlistItem {
    wishlistID: number;
    userID: number;
    productID: number;
    addedDate: string;
    product?: Product;
}

export interface BlogPost {
    blogPostID: number;
    blogPostToken?: string | null;
    title: string;
    slug: string;
    excerpt?: string | null;
    content?: string;
    coverImageUrl?: string | null;
    publishedAt?: string | null;
    viewCount?: number;
    isPublished?: boolean;
    createdAt?: string;
    updatedAt?: string | null;
}

export interface BlogComment {
    blogCommentID: number;
    blogPostID: number;
    userID: number;
    parentCommentID?: number | null;
    userName: string;
    avatarUrl?: string | null;
    content: string;
    createdAt: string;
}
