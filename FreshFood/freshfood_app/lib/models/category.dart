class Category {
  final int id;
  final String name;
  final String description;

  const Category({
    required this.id,
    required this.name,
    this.description = '',
  });

  factory Category.fromJson(Map<String, dynamic> json) {
    final idRaw = json['categoryID'] ?? json['CategoryID'] ?? 0;
    final id = idRaw is num ? idRaw.toInt() : int.tryParse('$idRaw') ?? 0;
    final nameRaw = json['categoryName'] ?? json['CategoryName'] ?? '';
    final name = (nameRaw is String ? nameRaw : '$nameRaw').trim();
    final descRaw = json['description'] ?? json['Description'] ?? '';
    final description = (descRaw is String ? descRaw : '$descRaw').trim();
    return Category(id: id, name: name, description: description);
  }

  Map<String, dynamic> toJson() => {
        'categoryID': id,
        'categoryName': name,
        'description': description,
      };
}

