import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class AppLocalizations {
  final Locale locale;
  const AppLocalizations(this.locale);

  static const supportedLocales = <Locale>[Locale('vi'), Locale('en')];

  static AppLocalizations of(BuildContext context) {
    final v = Localizations.of<AppLocalizations>(context, AppLocalizations);
    return v ?? const AppLocalizations(Locale('vi'));
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  bool get isEn => locale.languageCode.toLowerCase() == 'en';

  String tr({required String vi, required String en}) => isEn ? en : vi;

  String get appName => isEn ? 'FreshFood' : 'FreshFood';

  // Bottom nav
  String get navHome => isEn ? 'Home' : 'Trang chủ';
  String get navProducts => isEn ? 'Products' : 'Sản phẩm';
  String get navDeals => isEn ? 'Deals' : 'Ưu đãi';
  String get navExplore => isEn ? 'Explore' : 'Thông tin';
  String get navAccount => isEn ? 'Account' : 'Tài khoản';

  // Common
  String get cart => isEn ? 'Cart' : 'Giỏ hàng';
  String get settings => isEn ? 'Settings' : 'Cài đặt';
  String get language => isEn ? 'Language' : 'Ngôn ngữ';
  String get vietnamese => isEn ? 'Vietnamese' : 'Tiếng Việt';
  String get english => isEn ? 'English' : 'English';
  String get darkMode => isEn ? 'Dark mode' : 'Giao diện tối';
  String get on => isEn ? 'On' : 'Đang bật';
  String get off => isEn ? 'Off' : 'Đang tắt';
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    final code = locale.languageCode.toLowerCase();
    return code == 'vi' || code == 'en';
  }

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return SynchronousFuture(AppLocalizations(locale));
  }

  @override
  bool shouldReload(covariant LocalizationsDelegate<AppLocalizations> old) => false;
}

