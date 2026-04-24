class AdminRecentImport {
  final int logId;
  final int productId;
  final String productName;
  final int importedQuantity;
  final int stockQuantity;
  final String? unit;
  final DateTime? logDate;
  final String? note;
  final String? thumbUrl;

  const AdminRecentImport({
    required this.logId,
    required this.productId,
    required this.productName,
    required this.importedQuantity,
    required this.stockQuantity,
    this.unit,
    this.logDate,
    this.note,
    this.thumbUrl,
  });

  factory AdminRecentImport.fromJson(Map<String, dynamic> json) {
    int i(String k) {
      final v = json[k];
      if (v is num) return v.toInt();
      return int.tryParse('$v') ?? 0;
    }

    String? s(String k) {
      final v = json[k];
      if (v == null) return null;
      final out = v.toString();
      return out.trim().isEmpty ? null : out;
    }

    DateTime? dt(String k) {
      final v = json[k];
      if (v == null) return null;
      return DateTime.tryParse(v.toString());
    }

    return AdminRecentImport(
      logId: i('logID'),
      productId: i('productID'),
      productName: (json['productName'] ?? '').toString(),
      importedQuantity: i('importedQuantity'),
      stockQuantity: i('stockQuantity'),
      unit: s('unit'),
      logDate: dt('logDate'),
      note: s('note'),
      thumbUrl: s('thumbUrl'),
    );
  }
}

