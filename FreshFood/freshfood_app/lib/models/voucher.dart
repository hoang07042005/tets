class Voucher {
  final int id;
  final String code;
  final String? discountType;
  final double discountValue;
  final double minOrderAmount;
  final DateTime? expiryDate;

  const Voucher({
    required this.id,
    required this.code,
    required this.discountValue,
    required this.minOrderAmount,
    this.discountType,
    this.expiryDate,
  });

  factory Voucher.fromJson(Map<String, dynamic> json) {
    final idRaw = json['voucherID'] ?? json['VoucherID'] ?? 0;
    final id = idRaw is num ? idRaw.toInt() : int.tryParse('$idRaw') ?? 0;

    final codeRaw = json['code'] ?? json['Code'] ?? '';
    final code = (codeRaw is String ? codeRaw : '$codeRaw').trim();

    final discountTypeRaw = json['discountType'] ?? json['DiscountType'];
    final discountType = discountTypeRaw == null ? null : (discountTypeRaw is String ? discountTypeRaw : '$discountTypeRaw');

    final dvRaw = json['discountValue'] ?? json['DiscountValue'] ?? 0;
    final discountValue = dvRaw is num ? dvRaw.toDouble() : double.tryParse('$dvRaw') ?? 0.0;

    final minRaw = json['minOrderAmount'] ?? json['MinOrderAmount'] ?? 0;
    final minOrderAmount = minRaw is num ? minRaw.toDouble() : double.tryParse('$minRaw') ?? 0.0;

    final expRaw = json['expiryDate'] ?? json['ExpiryDate'];
    DateTime? expiryDate;
    if (expRaw is String && expRaw.trim().isNotEmpty) {
      expiryDate = DateTime.tryParse(expRaw);
    }

    return Voucher(
      id: id,
      code: code,
      discountType: discountType,
      discountValue: discountValue,
      minOrderAmount: minOrderAmount,
      expiryDate: expiryDate,
    );
  }
}

