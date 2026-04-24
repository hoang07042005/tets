class AdminOrderRow {
  final int orderId;
  final String orderToken;
  final String orderCode;
  final String customerName;
  final String customerEmail;
  final DateTime orderDate;
  final num totalAmount;
  final String status;

  const AdminOrderRow({
    required this.orderId,
    required this.orderToken,
    required this.orderCode,
    required this.customerName,
    required this.customerEmail,
    required this.orderDate,
    required this.totalAmount,
    required this.status,
  });

  static int _i(dynamic v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;
  static num _n(dynamic v) => v is num ? v : num.tryParse('$v') ?? 0;
  static String _s(dynamic v) => (v ?? '').toString();
  static DateTime _dt(dynamic v) {
    final s = (v ?? '').toString().trim();
    return DateTime.tryParse(s) ?? DateTime.fromMillisecondsSinceEpoch(0);
  }

  factory AdminOrderRow.fromJson(Map<String, dynamic> json) {
    return AdminOrderRow(
      orderId: _i(json['orderID'] ?? json['OrderID']),
      orderToken: _s(json['orderToken'] ?? json['OrderToken']).trim(),
      orderCode: _s(json['orderCode'] ?? json['OrderCode']).trim(),
      customerName: _s(json['customerName'] ?? json['CustomerName']).trim(),
      customerEmail: _s(json['customerEmail'] ?? json['CustomerEmail']).trim(),
      orderDate: _dt(json['orderDate'] ?? json['OrderDate']),
      totalAmount: _n(json['totalAmount'] ?? json['TotalAmount']),
      status: _s(json['status'] ?? json['Status']).trim(),
    );
  }
}

class AdminOrdersStats {
  final num dailyRevenue;
  final int shippingCount;
  final int pendingCount;
  const AdminOrdersStats({required this.dailyRevenue, required this.shippingCount, required this.pendingCount});

  static num _n(dynamic v) => v is num ? v : num.tryParse('$v') ?? 0;
  static int _i(dynamic v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;

  factory AdminOrdersStats.fromJson(Map<String, dynamic> json) {
    return AdminOrdersStats(
      dailyRevenue: _n(json['dailyRevenue'] ?? json['DailyRevenue']),
      shippingCount: _i(json['shippingCount'] ?? json['ShippingCount']),
      pendingCount: _i(json['pendingCount'] ?? json['PendingCount']),
    );
  }
}

class AdminOrdersPage {
  final List<AdminOrderRow> items;
  final int totalCount;
  final int page;
  final int pageSize;
  final AdminOrdersStats stats;

  const AdminOrdersPage({
    required this.items,
    required this.totalCount,
    required this.page,
    required this.pageSize,
    required this.stats,
  });

  static int _i(dynamic v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;

  factory AdminOrdersPage.fromJson(Map<String, dynamic> json) {
    final itemsRaw = json['items'] ?? json['Items'];
    final out = <AdminOrderRow>[];
    if (itemsRaw is List) {
      for (final e in itemsRaw) {
        if (e is Map) out.add(AdminOrderRow.fromJson(Map<String, dynamic>.from(e)));
      }
    }
    final statsRaw = json['stats'] ?? json['Stats'];
    final stats = statsRaw is Map ? AdminOrdersStats.fromJson(Map<String, dynamic>.from(statsRaw)) : const AdminOrdersStats(dailyRevenue: 0, shippingCount: 0, pendingCount: 0);
    return AdminOrdersPage(
      items: out,
      totalCount: _i(json['totalCount'] ?? json['TotalCount']),
      page: _i(json['page'] ?? json['Page']),
      pageSize: _i(json['pageSize'] ?? json['PageSize']),
      stats: stats,
    );
  }
}

class AdminOrderCustomer {
  final int userId;
  final String fullName;
  final String email;
  final String phone;
  final String avatarUrl;

  const AdminOrderCustomer({
    required this.userId,
    required this.fullName,
    required this.email,
    required this.phone,
    required this.avatarUrl,
  });

  static int _i(dynamic v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;
  static String _s(dynamic v) => (v ?? '').toString();

  factory AdminOrderCustomer.fromJson(Map<String, dynamic> json) {
    return AdminOrderCustomer(
      userId: _i(json['userID'] ?? json['UserID']),
      fullName: _s(json['fullName'] ?? json['FullName']).trim(),
      email: _s(json['email'] ?? json['Email']).trim(),
      phone: _s(json['phone'] ?? json['Phone']).trim(),
      avatarUrl: _s(json['avatarUrl'] ?? json['AvatarUrl'] ?? json['avatarURL'] ?? json['AvatarURL']).trim(),
    );
  }
}

class AdminOrderItem {
  final int productId;
  final String productName;
  final String sku;
  final String thumbUrl;
  final int quantity;
  final num unitPrice;
  final num lineTotal;

  const AdminOrderItem({
    required this.productId,
    required this.productName,
    required this.sku,
    required this.thumbUrl,
    required this.quantity,
    required this.unitPrice,
    required this.lineTotal,
  });

  static int _i(dynamic v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;
  static num _n(dynamic v) => v is num ? v : num.tryParse('$v') ?? 0;
  static String _s(dynamic v) => (v ?? '').toString();

  factory AdminOrderItem.fromJson(Map<String, dynamic> json) {
    return AdminOrderItem(
      productId: _i(json['productID'] ?? json['ProductID']),
      productName: _s(json['productName'] ?? json['ProductName']).trim(),
      sku: _s(json['sku'] ?? json['Sku']).trim(),
      thumbUrl: _s(json['thumbUrl'] ?? json['ThumbUrl'] ?? json['thumbURL'] ?? json['ThumbURL']).trim(),
      quantity: _i(json['quantity'] ?? json['Quantity']),
      unitPrice: _n(json['unitPrice'] ?? json['UnitPrice']),
      lineTotal: _n(json['lineTotal'] ?? json['LineTotal']),
    );
  }
}

class AdminOrderPayment {
  final String method;
  final String status;
  final num amount;
  final DateTime paymentDate;
  const AdminOrderPayment({required this.method, required this.status, required this.amount, required this.paymentDate});

  static String _s(dynamic v) => (v ?? '').toString();
  static num _n(dynamic v) => v is num ? v : num.tryParse('$v') ?? 0;
  static DateTime _dt(dynamic v) {
    final s = (v ?? '').toString().trim();
    return DateTime.tryParse(s) ?? DateTime.fromMillisecondsSinceEpoch(0);
  }

  factory AdminOrderPayment.fromJson(Map<String, dynamic> json) {
    return AdminOrderPayment(
      method: _s(json['method'] ?? json['Method']).trim(),
      status: _s(json['status'] ?? json['Status']).trim(),
      amount: _n(json['amount'] ?? json['Amount']),
      paymentDate: _dt(json['paymentDate'] ?? json['PaymentDate']),
    );
  }
}

class AdminShipment {
  final int shipmentId;
  final String trackingNumber;
  final String carrier;
  final DateTime? shippedDate;
  final DateTime? estimatedDeliveryDate;
  final DateTime? actualDeliveryDate;
  final String status;

  const AdminShipment({
    required this.shipmentId,
    required this.trackingNumber,
    required this.carrier,
    required this.status,
    this.shippedDate,
    this.estimatedDeliveryDate,
    this.actualDeliveryDate,
  });

  static int _i(dynamic v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;
  static String _s(dynamic v) => (v ?? '').toString();
  static DateTime? _dt(dynamic v) {
    if (v == null) return null;
    final s = v.toString().trim();
    if (s.isEmpty) return null;
    return DateTime.tryParse(s);
  }

  factory AdminShipment.fromJson(Map<String, dynamic> json) {
    return AdminShipment(
      shipmentId: _i(json['shipmentID'] ?? json['ShipmentID']),
      trackingNumber: _s(json['trackingNumber'] ?? json['TrackingNumber']).trim(),
      carrier: _s(json['carrier'] ?? json['Carrier']).trim(),
      status: _s(json['status'] ?? json['Status']).trim(),
      shippedDate: _dt(json['shippedDate'] ?? json['ShippedDate']),
      estimatedDeliveryDate: _dt(json['estimatedDeliveryDate'] ?? json['EstimatedDeliveryDate']),
      actualDeliveryDate: _dt(json['actualDeliveryDate'] ?? json['ActualDeliveryDate']),
    );
  }
}

class AdminOrderDetail {
  final int orderId;
  final String orderCode;
  final DateTime orderDate;
  final String status;
  final String pipelineStatus;
  final num totalAmount;
  final String shippingAddress;
  final AdminOrderCustomer customer;
  final List<AdminOrderItem> items;
  final AdminOrderPayment? latestPayment;
  final List<AdminShipment> shipments;

  const AdminOrderDetail({
    required this.orderId,
    required this.orderCode,
    required this.orderDate,
    required this.status,
    required this.pipelineStatus,
    required this.totalAmount,
    required this.shippingAddress,
    required this.customer,
    required this.items,
    required this.latestPayment,
    required this.shipments,
  });

  static int _i(dynamic v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;
  static num _n(dynamic v) => v is num ? v : num.tryParse('$v') ?? 0;
  static String _s(dynamic v) => (v ?? '').toString();
  static DateTime _dt(dynamic v) {
    final s = (v ?? '').toString().trim();
    return DateTime.tryParse(s) ?? DateTime.fromMillisecondsSinceEpoch(0);
  }

  factory AdminOrderDetail.fromJson(Map<String, dynamic> json) {
    final custRaw = json['customer'] ?? json['Customer'];
    final customer = custRaw is Map ? AdminOrderCustomer.fromJson(Map<String, dynamic>.from(custRaw)) : const AdminOrderCustomer(userId: 0, fullName: '', email: '', phone: '', avatarUrl: '');

    final itemsRaw = json['items'] ?? json['Items'];
    final items = <AdminOrderItem>[];
    if (itemsRaw is List) {
      for (final e in itemsRaw) {
        if (e is Map) items.add(AdminOrderItem.fromJson(Map<String, dynamic>.from(e)));
      }
    }

    final payRaw = json['latestPayment'] ?? json['LatestPayment'];
    final pay = payRaw is Map ? AdminOrderPayment.fromJson(Map<String, dynamic>.from(payRaw)) : null;

    final shipsRaw = json['shipments'] ?? json['Shipments'];
    final ships = <AdminShipment>[];
    if (shipsRaw is List) {
      for (final e in shipsRaw) {
        if (e is Map) ships.add(AdminShipment.fromJson(Map<String, dynamic>.from(e)));
      }
    }

    return AdminOrderDetail(
      orderId: _i(json['orderID'] ?? json['OrderID']),
      orderCode: _s(json['orderCode'] ?? json['OrderCode']).trim(),
      orderDate: _dt(json['orderDate'] ?? json['OrderDate']),
      status: _s(json['status'] ?? json['Status']).trim(),
      pipelineStatus: _s(json['pipelineStatus'] ?? json['PipelineStatus']).trim(),
      totalAmount: _n(json['totalAmount'] ?? json['TotalAmount']),
      shippingAddress: _s(json['shippingAddress'] ?? json['ShippingAddress']).trim(),
      customer: customer,
      items: items,
      latestPayment: pay,
      shipments: ships,
    );
  }
}

