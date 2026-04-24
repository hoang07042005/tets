class AdminLowStockProduct {
  final int productId;
  final String productName;
  final int stockQuantity;
  final String? unit;
  final num price;
  final num? discountPrice;
  final String? thumbUrl;

  const AdminLowStockProduct({
    required this.productId,
    required this.productName,
    required this.stockQuantity,
    required this.price,
    this.unit,
    this.discountPrice,
    this.thumbUrl,
  });

  factory AdminLowStockProduct.fromJson(Map<String, dynamic> json) {
    int i(String k) {
      final v = json[k];
      if (v is num) return v.toInt();
      return int.tryParse('$v') ?? 0;
    }

    num n(String k) {
      final v = json[k];
      if (v is num) return v;
      return num.tryParse('$v') ?? 0;
    }

    String? s(String k) {
      final v = json[k];
      if (v == null) return null;
      final out = v.toString();
      return out.trim().isEmpty ? null : out;
    }

    return AdminLowStockProduct(
      productId: i('productID'),
      productName: (json['productName'] ?? '').toString(),
      stockQuantity: i('stockQuantity'),
      unit: s('unit'),
      price: n('price'),
      discountPrice: json['discountPrice'] == null ? null : n('discountPrice'),
      thumbUrl: s('thumbUrl'),
    );
  }
}

