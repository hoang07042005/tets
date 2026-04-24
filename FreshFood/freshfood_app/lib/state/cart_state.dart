import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:freshfood_app/models/product.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CartState {
  CartState._();

  static const _kCart = 'cart_v1';

  static final ValueNotifier<List<CartLine>> lines = ValueNotifier<List<CartLine>>(const <CartLine>[]);
  static final ValueNotifier<int> itemCount = ValueNotifier<int>(0);

  static int _qtyTotal(List<CartLine> xs) => xs.fold<int>(0, (s, x) => s + x.quantity);

  static Future<void> restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kCart);
      if (raw == null || raw.trim().isEmpty) {
        lines.value = const <CartLine>[];
        itemCount.value = 0;
        return;
      }
      final decoded = jsonDecode(raw);
      if (decoded is! List) return;
      final next = <CartLine>[];
      for (final e in decoded) {
        if (e is Map) next.add(CartLine.fromJson(Map<String, dynamic>.from(e)));
      }
      lines.value = List<CartLine>.unmodifiable(next);
      itemCount.value = _qtyTotal(next);
    } catch (_) {
      // ignore (non-critical)
    }
  }

  static Future<void> _persist(List<CartLine> next) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kCart, jsonEncode(next.map((e) => e.toJson()).toList(growable: false)));
    } catch (_) {
      // ignore (non-critical)
    }
  }

  static void _set(List<CartLine> next) {
    lines.value = List<CartLine>.unmodifiable(next);
    itemCount.value = _qtyTotal(next);
    // fire-and-forget persistence
    // ignore: discarded_futures
    _persist(next);
  }

  static void addOne() {
    // Back-compat for old call sites; keep badge working even if product isn't provided.
    itemCount.value = itemCount.value + 1;
  }

  static void addProduct(Product p, {int quantity = 1}) {
    final q = quantity <= 0 ? 1 : quantity;
    final cur = List<CartLine>.from(lines.value);
    final idx = cur.indexWhere((x) => x.productId == p.id);
    if (idx >= 0) {
      cur[idx] = cur[idx].copyWith(quantity: cur[idx].quantity + q);
    } else {
      cur.add(CartLine.fromProduct(p, quantity: q));
    }
    _set(cur);
  }

  static void setQuantity(int productId, int quantity) {
    final q = quantity.clamp(0, 999);
    final cur = List<CartLine>.from(lines.value);
    final idx = cur.indexWhere((x) => x.productId == productId);
    if (idx < 0) return;
    if (q <= 0) {
      cur.removeAt(idx);
    } else {
      cur[idx] = cur[idx].copyWith(quantity: q);
    }
    _set(cur);
  }

  static void inc(int productId) {
    final cur = List<CartLine>.from(lines.value);
    final idx = cur.indexWhere((x) => x.productId == productId);
    if (idx < 0) return;
    cur[idx] = cur[idx].copyWith(quantity: cur[idx].quantity + 1);
    _set(cur);
  }

  static void dec(int productId) {
    final cur = List<CartLine>.from(lines.value);
    final idx = cur.indexWhere((x) => x.productId == productId);
    if (idx < 0) return;
    final nextQ = cur[idx].quantity - 1;
    if (nextQ <= 0) {
      cur.removeAt(idx);
    } else {
      cur[idx] = cur[idx].copyWith(quantity: nextQ);
    }
    _set(cur);
  }

  static void remove(int productId) {
    final cur = List<CartLine>.from(lines.value)..removeWhere((x) => x.productId == productId);
    _set(cur);
  }

  static void clear() => _set(const <CartLine>[]);

  static num subtotal() => lines.value.fold<num>(0, (s, x) => s + (x.sellingPrice * x.quantity));
}

class CartLine {
  final int productId;
  final String name;
  final num price;
  final num? discountPrice;
  final String? unit;
  final String? imageUrl;
  final int quantity;

  const CartLine({
    required this.productId,
    required this.name,
    required this.price,
    required this.discountPrice,
    required this.unit,
    required this.imageUrl,
    required this.quantity,
  });

  factory CartLine.fromProduct(Product p, {required int quantity}) {
    return CartLine(
      productId: p.id,
      name: p.name,
      price: p.price,
      discountPrice: p.discountPrice,
      unit: p.unit,
      imageUrl: p.mainImageUrl,
      quantity: quantity,
    );
  }

  num get sellingPrice {
    final d = discountPrice;
    final p = price;
    if (d == null) return p;
    if (d <= 0) return p;
    if (d >= p) return p;
    return d;
  }

  CartLine copyWith({int? quantity}) => CartLine(
        productId: productId,
        name: name,
        price: price,
        discountPrice: discountPrice,
        unit: unit,
        imageUrl: imageUrl,
        quantity: quantity ?? this.quantity,
      );

  factory CartLine.fromJson(Map<String, dynamic> json) {
    final pidRaw = json['productId'];
    final pid = pidRaw is num ? pidRaw.toInt() : int.tryParse('$pidRaw') ?? 0;
    final qRaw = json['quantity'];
    final q = qRaw is num ? qRaw.toInt() : int.tryParse('$qRaw') ?? 1;
    final priceRaw = json['price'];
    final price = priceRaw is num ? priceRaw : num.tryParse('$priceRaw') ?? 0;
    final dRaw = json['discountPrice'];
    final discountPrice = dRaw == null ? null : (dRaw is num ? dRaw : num.tryParse('$dRaw'));
    return CartLine(
      productId: pid,
      name: (json['name'] ?? '').toString(),
      price: price,
      discountPrice: discountPrice,
      unit: json['unit']?.toString(),
      imageUrl: json['imageUrl']?.toString(),
      quantity: q <= 0 ? 1 : q,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'productId': productId,
        'name': name,
        'price': price,
        'discountPrice': discountPrice,
        'unit': unit,
        'imageUrl': imageUrl,
        'quantity': quantity,
      };
}

