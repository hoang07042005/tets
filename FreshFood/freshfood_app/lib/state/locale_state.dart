import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocaleState {
  static final ValueNotifier<Locale> locale = ValueNotifier<Locale>(const Locale('vi'));

  static const _key = 'freshfood_locale';

  static Future<void> restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final code = (prefs.getString(_key) ?? '').trim().toLowerCase();
      if (code == 'en') locale.value = const Locale('en');
      if (code == 'vi') locale.value = const Locale('vi');
    } catch (_) {
      // ignore
    }
  }

  static Future<void> set(Locale next) async {
    locale.value = next;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, next.languageCode.toLowerCase());
    } catch (_) {
      // ignore
    }
  }
}

