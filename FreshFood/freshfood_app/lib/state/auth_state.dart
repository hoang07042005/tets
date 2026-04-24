import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthUser {
  final int userId;
  final String fullName;
  final String email;
  final String role;
  final String? phone;
  final String? address;
  final String? avatarUrl;

  const AuthUser({
    required this.userId,
    required this.fullName,
    required this.email,
    required this.role,
    this.phone,
    this.address,
    this.avatarUrl,
  });

  Map<String, dynamic> toJson() => {
        'userId': userId,
        'fullName': fullName,
        'email': email,
        'role': role,
        'phone': phone,
        'address': address,
        'avatarUrl': avatarUrl,
      };

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    final idRaw = json['userId'] ?? 0;
    final userId = idRaw is num ? idRaw.toInt() : int.tryParse('$idRaw') ?? 0;
    final fullName = (json['fullName'] ?? '').toString();
    final email = (json['email'] ?? '').toString();
    final role = (json['role'] ?? 'Customer').toString();
    final phone = json['phone']?.toString();
    final address = json['address']?.toString();
    final avatarUrl = json['avatarUrl']?.toString();
    return AuthUser(
      userId: userId,
      fullName: fullName,
      email: email,
      role: role,
      phone: phone,
      address: address,
      avatarUrl: avatarUrl,
    );
  }
}

class AuthState {
  AuthState._();

  static final ValueNotifier<AuthUser?> currentUser = ValueNotifier<AuthUser?>(null);
  static final ValueNotifier<String?> token = ValueNotifier<String?>(null);
  static final ValueNotifier<DateTime?> tokenExpiresAt = ValueNotifier<DateTime?>(null);

  static bool get isLoggedIn => currentUser.value != null;

  static const _kUser = 'freshfood_auth_user';
  static const _kToken = 'freshfood_auth_token';
  static const _kExp = 'freshfood_auth_exp';

  static Future<void> restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final u = prefs.getString(_kUser);
      final t = prefs.getString(_kToken);
      final e = prefs.getString(_kExp);
      if (u == null || t == null || e == null) return;
      final exp = DateTime.tryParse(e);
      if (exp == null) return;
      if (DateTime.now().isAfter(exp)) {
        await signOut();
        return;
      }
      currentUser.value = AuthUser.fromJson(jsonDecode(u) as Map<String, dynamic>);
      token.value = t;
      tokenExpiresAt.value = exp;
    } catch (_) {
      // ignore restore errors
    }
  }

  static Future<void> signIn({
    required AuthUser user,
    required String jwt,
    required int expiresInSeconds,
    bool remember = true,
  }) async {
    currentUser.value = user;
    token.value = jwt;
    tokenExpiresAt.value = DateTime.now().add(Duration(seconds: expiresInSeconds.clamp(60, 60 * 60 * 24 * 30)));
    if (!remember) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kUser, jsonEncode(user.toJson()));
      await prefs.setString(_kToken, jwt);
      await prefs.setString(_kExp, tokenExpiresAt.value!.toIso8601String());
    } catch (_) {
      // ignore
    }
  }

  static Future<void> signOut() async {
    currentUser.value = null;
    token.value = null;
    tokenExpiresAt.value = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kUser);
      await prefs.remove(_kToken);
      await prefs.remove(_kExp);
    } catch (_) {
      // ignore
    }
  }
}

