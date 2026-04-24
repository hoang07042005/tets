class ShippingMethod {
  final int methodId;
  final String methodName;
  final num baseCost;
  final int? estimatedDays;

  const ShippingMethod({
    required this.methodId,
    required this.methodName,
    required this.baseCost,
    required this.estimatedDays,
  });

  factory ShippingMethod.fromJson(Map<String, dynamic> json) {
    final idRaw = json['methodID'] ?? json['MethodID'] ?? json['methodId'];
    final id = idRaw is num ? idRaw.toInt() : int.tryParse('$idRaw') ?? 0;
    final costRaw = json['baseCost'] ?? json['BaseCost'] ?? 0;
    final cost = costRaw is num ? costRaw : num.tryParse('$costRaw') ?? 0;
    final daysRaw = json['estimatedDays'] ?? json['EstimatedDays'];
    final days = daysRaw == null ? null : (daysRaw is num ? daysRaw.toInt() : int.tryParse('$daysRaw'));
    return ShippingMethod(
      methodId: id,
      methodName: (json['methodName'] ?? json['MethodName'] ?? '').toString(),
      baseCost: cost,
      estimatedDays: days,
    );
  }
}

