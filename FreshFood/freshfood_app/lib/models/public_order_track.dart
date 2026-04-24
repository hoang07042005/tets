class PublicShipmentTrack {
  final int shipmentId;
  final String trackingNumber;
  final String carrier;
  final String status;
  final DateTime? shippedDate;
  final DateTime? actualDeliveryDate;

  const PublicShipmentTrack({
    required this.shipmentId,
    required this.trackingNumber,
    required this.carrier,
    required this.status,
    this.shippedDate,
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

  factory PublicShipmentTrack.fromJson(Map<String, dynamic> json) {
    return PublicShipmentTrack(
      shipmentId: _i(json['shipmentID'] ?? json['ShipmentID']),
      trackingNumber: _s(json['trackingNumber'] ?? json['TrackingNumber']).trim(),
      carrier: _s(json['carrier'] ?? json['Carrier']).trim(),
      status: _s(json['status'] ?? json['Status']).trim(),
      shippedDate: _dt(json['shippedDate'] ?? json['ShippedDate']),
      actualDeliveryDate: _dt(json['actualDeliveryDate'] ?? json['ActualDeliveryDate']),
    );
  }
}

class PublicOrderTrack {
  final String orderCode;
  final String status;
  final DateTime orderDate;
  final List<PublicShipmentTrack> shipments;

  const PublicOrderTrack({
    required this.orderCode,
    required this.status,
    required this.orderDate,
    required this.shipments,
  });

  static String _s(dynamic v) => (v ?? '').toString();
  static DateTime _dtRequired(dynamic v) {
    final s = (v ?? '').toString().trim();
    final parsed = DateTime.tryParse(s);
    return parsed ?? DateTime.fromMillisecondsSinceEpoch(0);
  }

  factory PublicOrderTrack.fromJson(Map<String, dynamic> json) {
    final shipsRaw = json['shipments'] ?? json['Shipments'];
    final ships = <PublicShipmentTrack>[];
    if (shipsRaw is List) {
      for (final e in shipsRaw) {
        if (e is Map) ships.add(PublicShipmentTrack.fromJson(Map<String, dynamic>.from(e)));
      }
    }
    return PublicOrderTrack(
      orderCode: _s(json['orderCode'] ?? json['OrderCode']).trim(),
      status: _s(json['status'] ?? json['Status']).trim(),
      orderDate: _dtRequired(json['orderDate'] ?? json['OrderDate']),
      shipments: ships,
    );
  }
}

