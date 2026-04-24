class AdminSupplierRow {
  final int supplierId;
  final String supplierName;
  final String? supplierCode;
  final String? contactName;
  final String? phone;
  final String? email;
  final String? address;
  final String status;
  final bool isVerified;
  final String? imageUrl;
  final int productCount;

  const AdminSupplierRow({
    required this.supplierId,
    required this.supplierName,
    required this.status,
    required this.isVerified,
    required this.productCount,
    this.supplierCode,
    this.contactName,
    this.phone,
    this.email,
    this.address,
    this.imageUrl,
  });

  static String? _s(dynamic v) {
    if (v == null) return null;
    final out = v.toString().trim();
    return out.isEmpty ? null : out;
  }

  static int _i(dynamic v) {
    if (v is num) return v.toInt();
    return int.tryParse('$v') ?? 0;
  }

  static bool _b(dynamic v) {
    if (v is bool) return v;
    final s = '$v'.trim().toLowerCase();
    return s == 'true' || s == '1' || s == 'yes';
  }

  factory AdminSupplierRow.fromJson(Map<String, dynamic> json) {
    return AdminSupplierRow(
      supplierId: _i(json['supplierID'] ?? json['SupplierID'] ?? json['supplierId']),
      supplierName: (json['supplierName'] ?? json['SupplierName'] ?? '').toString(),
      supplierCode: _s(json['supplierCode'] ?? json['SupplierCode']),
      contactName: _s(json['contactName'] ?? json['ContactName']),
      phone: _s(json['phone'] ?? json['Phone']),
      email: _s(json['email'] ?? json['Email']),
      address: _s(json['address'] ?? json['Address']),
      status: (json['status'] ?? json['Status'] ?? 'Active').toString(),
      isVerified: _b(json['isVerified'] ?? json['IsVerified'] ?? false),
      imageUrl: _s(json['imageUrl'] ?? json['ImageUrl']),
      productCount: _i(json['productCount'] ?? json['ProductCount']),
    );
  }
}

class AdminSupplierStats {
  final int total;
  final int verified;
  final int inTransaction;
  final int newThisMonth;

  const AdminSupplierStats({
    required this.total,
    required this.verified,
    required this.inTransaction,
    required this.newThisMonth,
  });

  static int _i(dynamic v) {
    if (v is num) return v.toInt();
    return int.tryParse('$v') ?? 0;
  }

  factory AdminSupplierStats.fromJson(Map<String, dynamic> json) {
    return AdminSupplierStats(
      total: _i(json['total'] ?? json['Total']),
      verified: _i(json['verified'] ?? json['Verified']),
      inTransaction: _i(json['inTransaction'] ?? json['InTransaction']),
      newThisMonth: _i(json['newThisMonth'] ?? json['NewThisMonth']),
    );
  }
}

class AdminSuppliersPage {
  final List<AdminSupplierRow> items;
  final int totalCount;
  final int page;
  final int pageSize;
  final AdminSupplierStats stats;

  const AdminSuppliersPage({
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

  factory AdminSuppliersPage.fromJson(Map<String, dynamic> json) {
    final raw = json['items'];
    final items = <AdminSupplierRow>[];
    if (raw is List) {
      for (final e in raw) {
        if (e is Map) items.add(AdminSupplierRow.fromJson(Map<String, dynamic>.from(e)));
      }
    }
    final statsRaw = json['stats'];
    final stats = statsRaw is Map ? AdminSupplierStats.fromJson(Map<String, dynamic>.from(statsRaw)) : const AdminSupplierStats(total: 0, verified: 0, inTransaction: 0, newThisMonth: 0);
    return AdminSuppliersPage(
      items: items,
      totalCount: _i(json['totalCount'] ?? json['TotalCount']),
      page: _i(json['page'] ?? json['Page']),
      pageSize: _i(json['pageSize'] ?? json['PageSize']),
      stats: stats,
    );
  }
}

class AdminSupplierUpsert {
  final String supplierName;
  final String contactName;
  final String phone;
  final String email;
  final String address;
  final String supplierCode;
  final String imageUrl;
  final String status;
  final bool isVerified;

  const AdminSupplierUpsert({
    required this.supplierName,
    this.contactName = '',
    this.phone = '',
    this.email = '',
    this.address = '',
    this.supplierCode = '',
    this.imageUrl = '',
    this.status = 'Pending',
    this.isVerified = false,
  });

  Map<String, dynamic> toJson() => {
        'supplierName': supplierName.trim(),
        'contactName': contactName.trim(),
        'phone': phone.trim(),
        'email': email.trim(),
        'address': address.trim(),
        'supplierCode': supplierCode.trim(),
        'imageUrl': imageUrl.trim(),
        'status': status.trim(),
        'isVerified': isVerified,
      };
}

