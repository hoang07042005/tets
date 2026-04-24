class UserAddress {
  final int userAddressId;
  final String? label;
  final String recipientName;
  final String? phone;
  final String addressLine;
  final bool isDefault;
  final String? createdAt;

  const UserAddress({
    required this.userAddressId,
    required this.label,
    required this.recipientName,
    required this.phone,
    required this.addressLine,
    required this.isDefault,
    required this.createdAt,
  });

  factory UserAddress.fromJson(Map<String, dynamic> json) {
    final idRaw = json['userAddressID'] ?? json['UserAddressID'] ?? json['userAddressId'] ?? json['userAddressID'];
    final id = idRaw is num ? idRaw.toInt() : int.tryParse('$idRaw') ?? 0;
    return UserAddress(
      userAddressId: id,
      label: json['label']?.toString() ?? json['Label']?.toString(),
      recipientName: (json['recipientName'] ?? json['RecipientName'] ?? '').toString(),
      phone: json['phone']?.toString() ?? json['Phone']?.toString(),
      addressLine: (json['addressLine'] ?? json['AddressLine'] ?? '').toString(),
      isDefault: (json['isDefault'] ?? json['IsDefault']) == true,
      createdAt: json['createdAt']?.toString() ?? json['CreatedAt']?.toString(),
    );
  }
}

