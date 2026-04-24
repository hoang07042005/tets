class ProductImage {
  final String imageUrl;
  final bool isMainImage;

  const ProductImage({required this.imageUrl, required this.isMainImage});

  factory ProductImage.fromJson(Map<String, dynamic> json) {
    final url = (json['imageURL'] ?? json['ImageURL'] ?? json['imageUrl'] ?? '') as String;
    final isMain = (json['isMainImage'] ?? json['IsMainImage'] ?? false) as bool;
    return ProductImage(imageUrl: url, isMainImage: isMain);
  }
}

class Product {
  final int id;
  final String name;
  final double price;
  final double? discountPrice;
  final String? unit;
  final String? productToken;
  final List<ProductImage> images;
  final int? categoryId;
  final String? categoryName;
  final String? description;
  final int? stockQuantity;
  final String? origin;
  final String? storageInstructions;
  final String? certifications;
  final DateTime? manufacturedDate;
  final DateTime? expiryDate;
  final List<dynamic> reviewsRaw;

  const Product({
    required this.id,
    required this.name,
    required this.price,
    required this.images,
    this.discountPrice,
    this.unit,
    this.productToken,
    this.categoryId,
    this.categoryName,
    this.description,
    this.stockQuantity,
    this.origin,
    this.storageInstructions,
    this.certifications,
    this.manufacturedDate,
    this.expiryDate,
    this.reviewsRaw = const [],
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    final idRaw = json['productID'] ?? json['ProductID'] ?? 0;
    final id = idRaw is num ? idRaw.toInt() : int.tryParse('$idRaw') ?? 0;
    final nameRaw = json['productName'] ?? json['ProductName'] ?? '';
    final name = (nameRaw is String ? nameRaw : '$nameRaw').trim();
    final priceRaw = json['price'] ?? json['Price'] ?? 0;
    final price = priceRaw is num ? priceRaw.toDouble() : double.tryParse('$priceRaw') ?? 0.0;
    final discountRaw = json['discountPrice'] ?? json['DiscountPrice'] ?? json['discount_price'] ?? json['Discount_Price'];
    final discountPrice = discountRaw == null ? null : (discountRaw is num ? discountRaw.toDouble() : double.tryParse('$discountRaw'));
    final unitRaw = json['unit'] ?? json['Unit'];
    final unit = unitRaw == null ? null : (unitRaw is String ? unitRaw : '$unitRaw');
    final tokenRaw = json['productToken'] ?? json['ProductToken'];
    final token = tokenRaw == null ? null : (tokenRaw is String ? tokenRaw : '$tokenRaw');

    final descRaw = json['description'] ?? json['Description'];
    final description = descRaw == null ? null : (descRaw is String ? descRaw : '$descRaw');

    final stockRaw = json['stockQuantity'] ?? json['StockQuantity'];
    final stockQuantity = stockRaw == null ? null : (stockRaw is num ? stockRaw.toInt() : int.tryParse('$stockRaw'));

    final originRaw = json['origin'] ?? json['Origin'];
    final origin = originRaw == null ? null : (originRaw is String ? originRaw : '$originRaw');

    final storageRaw = json['storageInstructions'] ?? json['StorageInstructions'];
    final storageInstructions = storageRaw == null ? null : (storageRaw is String ? storageRaw : '$storageRaw');

    final certRaw = json['certifications'] ?? json['Certifications'];
    final certifications = certRaw == null ? null : (certRaw is String ? certRaw : '$certRaw');

    DateTime? manufacturedDate;
    final manRaw = json['manufacturedDate'] ?? json['ManufacturedDate'];
    if (manRaw is String && manRaw.trim().isNotEmpty) manufacturedDate = DateTime.tryParse(manRaw);

    DateTime? expiryDate;
    final expRaw = json['expiryDate'] ?? json['ExpiryDate'];
    if (expRaw is String && expRaw.trim().isNotEmpty) expiryDate = DateTime.tryParse(expRaw);

    final catIdRaw = json['categoryID'] ?? json['CategoryID'] ?? json['categoryId'];
    int? categoryId;
    if (catIdRaw != null) {
      categoryId = catIdRaw is num ? catIdRaw.toInt() : int.tryParse('$catIdRaw');
    }

    final category = json['category'] ?? json['Category'];
    String? categoryName;
    if (category is Map) {
      final m = Map<String, dynamic>.from(category);
      final cidRaw = m['categoryID'] ?? m['CategoryID'] ?? m['categoryId'];
      if (categoryId == null && cidRaw != null) {
        categoryId = cidRaw is num ? cidRaw.toInt() : int.tryParse('$cidRaw');
      }
      final cnRaw = m['categoryName'] ?? m['CategoryName'];
      categoryName = cnRaw == null ? null : (cnRaw is String ? cnRaw : '$cnRaw');
    }

    final imagesRaw = json['productImages'] ?? json['ProductImages'];
    final images = <ProductImage>[];
    if (imagesRaw is List) {
      for (final item in imagesRaw) {
        if (item is Map) {
          images.add(ProductImage.fromJson(Map<String, dynamic>.from(item)));
        }
      }
    }

    final reviewsRaw = json['reviews'] ?? json['Reviews'];
    final reviews = reviewsRaw is List ? List<dynamic>.from(reviewsRaw) : const <dynamic>[];

    return Product(
      id: id,
      name: name,
      price: price,
      discountPrice: discountPrice,
      unit: unit,
      productToken: token,
      images: images,
      categoryId: categoryId,
      categoryName: categoryName,
      description: description,
      stockQuantity: stockQuantity,
      origin: origin,
      storageInstructions: storageInstructions,
      certifications: certifications,
      manufacturedDate: manufacturedDate,
      expiryDate: expiryDate,
      reviewsRaw: reviews,
    );
  }

  double get sellingPrice {
    final d = discountPrice;
    if (d == null) return price;
    if (d <= 0) return price;
    if (d >= price) return price;
    return d;
  }

  String? get mainImageUrl {
    if (images.isEmpty) return null;
    final main = images.where((x) => x.isMainImage).toList();
    if (main.isNotEmpty) return main.first.imageUrl;
    return images.first.imageUrl;
  }
}

