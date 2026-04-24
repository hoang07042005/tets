class AdminProductRow {
  final int productId;
  final String productToken;
  final String productName;
  final String sku;
  final String? categoryName;
  final int? categoryId;
  final String? supplierName;
  final String? imageUrl;
  final num price;
  final num? discountPrice;
  final int stockQuantity;
  final String? unit;
  final String status; // Active | Inactive
  final bool isOnSale;
  final bool isLowStock;

  const AdminProductRow({
    required this.productId,
    required this.productToken,
    required this.productName,
    required this.sku,
    required this.price,
    required this.stockQuantity,
    required this.status,
    required this.isOnSale,
    required this.isLowStock,
    this.categoryName,
    this.categoryId,
    this.supplierName,
    this.imageUrl,
    this.discountPrice,
    this.unit,
  });

  static int _i(dynamic v) {
    if (v is num) return v.toInt();
    return int.tryParse('$v') ?? 0;
  }

  static num _n(dynamic v) {
    if (v is num) return v;
    return num.tryParse('$v') ?? 0;
  }

  static bool _b(dynamic v) {
    if (v is bool) return v;
    final s = '$v'.trim().toLowerCase();
    return s == 'true' || s == '1' || s == 'yes';
  }

  static String? _s(dynamic v) {
    if (v == null) return null;
    final out = v.toString().trim();
    return out.isEmpty ? null : out;
  }

  factory AdminProductRow.fromJson(Map<String, dynamic> json) {
    return AdminProductRow(
      productId: _i(json['productID'] ?? json['ProductID'] ?? json['productId']),
      productToken: (json['productToken'] ?? json['ProductToken'] ?? '').toString(),
      productName: (json['productName'] ?? json['ProductName'] ?? '').toString(),
      sku: (json['sku'] ?? json['Sku'] ?? '').toString(),
      categoryName: _s(json['categoryName'] ?? json['CategoryName']),
      categoryId: (json['categoryID'] ?? json['CategoryID']) == null ? null : _i(json['categoryID'] ?? json['CategoryID']),
      supplierName: _s(json['supplierName'] ?? json['SupplierName']),
      imageUrl: _s(json['imageUrl'] ?? json['ImageUrl']),
      price: _n(json['price'] ?? json['Price']),
      discountPrice: (json['discountPrice'] ?? json['DiscountPrice']) == null ? null : _n(json['discountPrice'] ?? json['DiscountPrice']),
      stockQuantity: _i(json['stockQuantity'] ?? json['StockQuantity']),
      unit: _s(json['unit'] ?? json['Unit']),
      status: (json['status'] ?? json['Status'] ?? 'Active').toString(),
      isOnSale: _b(json['isOnSale'] ?? json['IsOnSale']),
      isLowStock: _b(json['isLowStock'] ?? json['IsLowStock']),
    );
  }
}

class AdminProductStats {
  final int total;
  final int outOfStock;
  final int onSale;
  final num inventoryValue;

  const AdminProductStats({
    required this.total,
    required this.outOfStock,
    required this.onSale,
    required this.inventoryValue,
  });

  static int _i(dynamic v) {
    if (v is num) return v.toInt();
    return int.tryParse('$v') ?? 0;
  }

  static num _n(dynamic v) {
    if (v is num) return v;
    return num.tryParse('$v') ?? 0;
  }

  factory AdminProductStats.fromJson(Map<String, dynamic> json) {
    return AdminProductStats(
      total: _i(json['total'] ?? json['Total']),
      outOfStock: _i(json['outOfStock'] ?? json['OutOfStock']),
      onSale: _i(json['onSale'] ?? json['OnSale']),
      inventoryValue: _n(json['inventoryValue'] ?? json['InventoryValue']),
    );
  }
}

class AdminProductsPage {
  final List<AdminProductRow> items;
  final int totalCount;
  final int page;
  final int pageSize;
  final AdminProductStats stats;

  const AdminProductsPage({
    required this.items,
    required this.totalCount,
    required this.page,
    required this.pageSize,
    required this.stats,
  });

  static int _i(dynamic v) {
    if (v is num) return v.toInt();
    return int.tryParse('$v') ?? 0;
  }

  factory AdminProductsPage.fromJson(Map<String, dynamic> json) {
    final raw = json['items'];
    final items = <AdminProductRow>[];
    if (raw is List) {
      for (final e in raw) {
        if (e is Map) items.add(AdminProductRow.fromJson(Map<String, dynamic>.from(e)));
      }
    }
    final statsRaw = json['stats'];
    final stats = statsRaw is Map ? AdminProductStats.fromJson(Map<String, dynamic>.from(statsRaw)) : const AdminProductStats(total: 0, outOfStock: 0, onSale: 0, inventoryValue: 0);
    return AdminProductsPage(
      items: items,
      totalCount: _i(json['totalCount'] ?? json['TotalCount']),
      page: _i(json['page'] ?? json['Page']),
      pageSize: _i(json['pageSize'] ?? json['PageSize']),
      stats: stats,
    );
  }
}

