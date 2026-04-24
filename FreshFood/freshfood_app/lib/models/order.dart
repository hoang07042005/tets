class Order {
  final int orderId;
  final String? orderCode;
  final String? orderToken;
  final int userId;
  final int? shippingMethodId;
  final String? status;
  final DateTime? orderDate;
  final num totalAmount;
  final String? shippingAddress;
  final List<OrderLine> lines;
  final List<OrderPayment> payments;
  final List<OrderShipment> shipments;

  const Order({
    required this.orderId,
    required this.orderCode,
    required this.orderToken,
    required this.userId,
    required this.shippingMethodId,
    required this.status,
    required this.orderDate,
    required this.totalAmount,
    required this.shippingAddress,
    required this.lines,
    required this.payments,
    required this.shipments,
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    int _i(dynamic v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;
    num _n(dynamic v) => v is num ? v : num.tryParse('$v') ?? 0;
    DateTime? _dt(dynamic v) {
      if (v is String && v.trim().isNotEmpty) return DateTime.tryParse(v);
      return null;
    }

    final linesRaw = json['orderDetails'] ?? json['OrderDetails'];
    final lines = <OrderLine>[];
    if (linesRaw is List) {
      for (final e in linesRaw) {
        if (e is Map) lines.add(OrderLine.fromJson(Map<String, dynamic>.from(e)));
      }
    }

    final payRaw = json['payments'] ?? json['Payments'];
    final payments = <OrderPayment>[];
    if (payRaw is List) {
      for (final e in payRaw) {
        if (e is Map) payments.add(OrderPayment.fromJson(Map<String, dynamic>.from(e)));
      }
    }

    final shipRaw = json['shipments'] ?? json['Shipments'];
    final shipments = <OrderShipment>[];
    if (shipRaw is List) {
      for (final e in shipRaw) {
        if (e is Map) shipments.add(OrderShipment.fromJson(Map<String, dynamic>.from(e)));
      }
    }

    return Order(
      orderId: _i(json['orderID'] ?? json['OrderID'] ?? json['orderId']),
      orderCode: (json['orderCode'] ?? json['OrderCode'])?.toString(),
      orderToken: (json['orderToken'] ?? json['OrderToken'])?.toString(),
      userId: _i(json['userID'] ?? json['UserID'] ?? json['userId']),
      shippingMethodId: (() {
        final raw = json['shippingMethodID'] ?? json['ShippingMethodID'] ?? json['shippingMethodId'];
        if (raw == null) return null;
        final v = raw is num ? raw.toInt() : int.tryParse('$raw');
        return (v == null || v <= 0) ? null : v;
      })(),
      status: (json['status'] ?? json['Status'])?.toString(),
      orderDate: _dt(json['orderDate'] ?? json['OrderDate']),
      totalAmount: _n(json['totalAmount'] ?? json['TotalAmount']),
      shippingAddress: (json['shippingAddress'] ?? json['ShippingAddress'])?.toString(),
      lines: lines,
      payments: payments,
      shipments: shipments,
    );
  }
}

class OrderLine {
  final int orderDetailId;
  final int productId;
  final int quantity;
  final num unitPrice;
  final String? productName;
  final String? productToken;
  final String? imageUrl;

  const OrderLine({
    required this.orderDetailId,
    required this.productId,
    required this.quantity,
    required this.unitPrice,
    required this.productName,
    required this.productToken,
    required this.imageUrl,
  });

  factory OrderLine.fromJson(Map<String, dynamic> json) {
    int _i(dynamic v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;
    num _n(dynamic v) => v is num ? v : num.tryParse('$v') ?? 0;

    final p = json['product'] ?? json['Product'];
    Map<String, dynamic>? pm;
    if (p is Map) pm = Map<String, dynamic>.from(p);

    final imgs = pm?['productImages'] ?? pm?['ProductImages'];
    String? img;
    if (imgs is List && imgs.isNotEmpty) {
      final main = imgs.where((e) => e is Map && ((e['isMainImage'] ?? e['IsMainImage']) == true)).toList();
      final pick = (main.isNotEmpty ? main.first : imgs.first);
      if (pick is Map) {
        img = (pick['imageURL'] ?? pick['ImageURL'] ?? pick['imageUrl'])?.toString();
      }
    }

    return OrderLine(
      orderDetailId: _i(json['orderDetailID'] ?? json['OrderDetailID'] ?? json['id']),
      productId: _i(json['productID'] ?? json['ProductID'] ?? json['productId']),
      quantity: _i(json['quantity'] ?? json['Quantity']),
      unitPrice: _n(json['unitPrice'] ?? json['UnitPrice']),
      productName: (pm?['productName'] ?? pm?['ProductName'])?.toString(),
      productToken: (pm?['productToken'] ?? pm?['ProductToken'])?.toString(),
      imageUrl: img,
    );
  }
}

class OrderPayment {
  final int paymentId;
  final String? paymentMethod;
  final String? status;
  final DateTime? paymentDate;

  const OrderPayment({required this.paymentId, required this.paymentMethod, required this.status, required this.paymentDate});

  factory OrderPayment.fromJson(Map<String, dynamic> json) {
    int _i(dynamic v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;
    DateTime? _dt(dynamic v) => (v is String && v.trim().isNotEmpty) ? DateTime.tryParse(v) : null;
    return OrderPayment(
      paymentId: _i(json['paymentID'] ?? json['PaymentID'] ?? json['id']),
      paymentMethod: (json['paymentMethod'] ?? json['PaymentMethod'])?.toString(),
      status: (json['status'] ?? json['Status'])?.toString(),
      paymentDate: _dt(json['paymentDate'] ?? json['PaymentDate']),
    );
  }
}

class OrderShipment {
  final int shipmentId;
  final String? status;
  final String? trackingNumber;
  final String? carrier;
  final DateTime? shippedDate;
  final DateTime? estimatedDeliveryDate;
  final DateTime? actualDeliveryDate;

  const OrderShipment({
    required this.shipmentId,
    required this.status,
    required this.trackingNumber,
    required this.carrier,
    required this.shippedDate,
    required this.estimatedDeliveryDate,
    required this.actualDeliveryDate,
  });

  factory OrderShipment.fromJson(Map<String, dynamic> json) {
    int _i(dynamic v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;
    DateTime? _dt(dynamic v) => (v is String && v.trim().isNotEmpty) ? DateTime.tryParse(v) : null;

    String? _s(dynamic v) {
      final t = v == null ? '' : v.toString();
      final out = t.trim();
      return out.isEmpty ? null : out;
    }

    return OrderShipment(
      shipmentId: _i(json['shipmentID'] ?? json['ShipmentID'] ?? json['id']),
      status: _s(json['status'] ?? json['Status']),
      trackingNumber: _s(
        json['trackingNumber'] ??
            json['TrackingNumber'] ??
            json['trackingCode'] ??
            json['TrackingCode'] ??
            json['trackingNo'] ??
            json['TrackingNo'],
      ),
      carrier: _s(
        json['carrier'] ??
            json['Carrier'] ??
            json['carrierName'] ??
            json['CarrierName'] ??
            json['shippingPartner'] ??
            json['ShippingPartner'] ??
            json['deliveryPartner'] ??
            json['DeliveryPartner'] ??
            json['shipper'] ??
            json['Shipper'],
      ),
      shippedDate: _dt(json['shippedDate'] ?? json['ShippedDate']),
      estimatedDeliveryDate: _dt(json['estimatedDeliveryDate'] ?? json['EstimatedDeliveryDate']),
      actualDeliveryDate: _dt(json['actualDeliveryDate'] ?? json['ActualDeliveryDate']),
    );
  }
}

