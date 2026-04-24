class AdminProductImage {
  final int imageId;
  final String imageUrl;
  final bool isMainImage;
  const AdminProductImage({required this.imageId, required this.imageUrl, required this.isMainImage});

  factory AdminProductImage.fromJson(Map<String, dynamic> json) {
    final idRaw = json['imageID'] ?? json['ImageID'] ?? 0;
    final id = idRaw is num ? idRaw.toInt() : int.tryParse('$idRaw') ?? 0;
    final url = (json['imageURL'] ?? json['ImageURL'] ?? json['imageUrl'] ?? '').toString();
    final mainRaw = json['isMainImage'] ?? json['IsMainImage'] ?? false;
    final main = mainRaw is bool ? mainRaw : ('$mainRaw'.trim().toLowerCase() == 'true');
    return AdminProductImage(imageId: id, imageUrl: url, isMainImage: main);
  }
}

class AdminProductDetail {
  final int productId;
  final String productToken;
  final String productName;
  final String sku;
  final int? categoryId;
  final int? supplierId;
  final num price;
  final num? discountPrice;
  final int stockQuantity;
  final String unit;
  final String description;
  final DateTime? manufacturedDate;
  final DateTime? expiryDate;
  final String origin;
  final String storageInstructions;
  final String certifications;
  final String status; // Active | Inactive
  final List<AdminProductImage> images;

  const AdminProductDetail({
    required this.productId,
    required this.productToken,
    required this.productName,
    required this.sku,
    required this.price,
    required this.stockQuantity,
    required this.unit,
    required this.description,
    required this.status,
    required this.images,
    this.discountPrice,
    this.categoryId,
    this.supplierId,
    this.manufacturedDate,
    this.expiryDate,
    this.origin = '',
    this.storageInstructions = '',
    this.certifications = '',
  });

  static int _i(dynamic v) {
    if (v is num) return v.toInt();
    return int.tryParse('$v') ?? 0;
  }

  static num _n(dynamic v) {
    if (v is num) return v;
    return num.tryParse('$v') ?? 0;
  }

  static String _s(dynamic v) => (v ?? '').toString();

  static DateTime? _dt(dynamic v) {
    if (v == null) return null;
    final s = v.toString().trim();
    if (s.isEmpty) return null;
    return DateTime.tryParse(s);
  }

  factory AdminProductDetail.fromJson(Map<String, dynamic> json) {
    final pid = _i(json['productID'] ?? json['ProductID'] ?? json['productId']);
    final token = _s(json['productToken'] ?? json['ProductToken']);
    final name = _s(json['productName'] ?? json['ProductName']).trim();
    final sku = _s(json['sku'] ?? json['Sku']).trim();
    final catIdRaw = json['categoryID'] ?? json['CategoryID'] ?? json['categoryId'];
    final supIdRaw = json['supplierID'] ?? json['SupplierID'] ?? json['supplierId'];
    final catId = catIdRaw == null ? null : _i(catIdRaw);
    final supId = supIdRaw == null ? null : _i(supIdRaw);

    final imagesRaw = json['productImages'] ?? json['ProductImages'];
    final images = <AdminProductImage>[];
    if (imagesRaw is List) {
      for (final item in imagesRaw) {
        if (item is Map) images.add(AdminProductImage.fromJson(Map<String, dynamic>.from(item)));
      }
    }

    return AdminProductDetail(
      productId: pid,
      productToken: token,
      productName: name,
      sku: sku,
      categoryId: catId,
      supplierId: supId,
      price: _n(json['price'] ?? json['Price']),
      discountPrice: (json['discountPrice'] ?? json['DiscountPrice']) == null ? null : _n(json['discountPrice'] ?? json['DiscountPrice']),
      stockQuantity: _i(json['stockQuantity'] ?? json['StockQuantity']),
      unit: (_s(json['unit'] ?? json['Unit']).trim().isEmpty ? 'kg' : _s(json['unit'] ?? json['Unit']).trim()),
      description: _s(json['description'] ?? json['Description']),
      manufacturedDate: _dt(json['manufacturedDate'] ?? json['ManufacturedDate']),
      expiryDate: _dt(json['expiryDate'] ?? json['ExpiryDate']),
      origin: _s(json['origin'] ?? json['Origin']),
      storageInstructions: _s(json['storageInstructions'] ?? json['StorageInstructions']),
      certifications: _s(json['certifications'] ?? json['Certifications']),
      status: _s(json['status'] ?? json['Status'] ?? 'Active').trim().isEmpty ? 'Active' : _s(json['status'] ?? json['Status']).trim(),
      images: images,
    );
  }
}

