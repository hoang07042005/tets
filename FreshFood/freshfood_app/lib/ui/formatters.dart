import 'package:intl/intl.dart';

class Formatters {
  static final _vnd = NumberFormat.currency(locale: 'vi_VN', symbol: '₫');

  static String vnd(num value) => _vnd.format(value);
}

