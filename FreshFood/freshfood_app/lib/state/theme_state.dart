import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeState {
  ThemeState._();

  static const _kThemeMode = 'freshfood_theme_mode'; // light | dark | system

  static final ValueNotifier<ThemeMode> themeMode = ValueNotifier<ThemeMode>(ThemeMode.light);

  static Future<void> restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = (prefs.getString(_kThemeMode) ?? '').trim().toLowerCase();
      if (raw == 'dark') themeMode.value = ThemeMode.dark;
      else if (raw == 'system') themeMode.value = ThemeMode.system;
      else themeMode.value = ThemeMode.light;
    } catch (_) {
      // ignore
    }
  }

  static Future<void> setMode(ThemeMode mode) async {
    themeMode.value = mode;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = mode == ThemeMode.dark
          ? 'dark'
          : mode == ThemeMode.system
              ? 'system'
              : 'light';
      await prefs.setString(_kThemeMode, raw);
    } catch (_) {
      // ignore
    }
  }
}

