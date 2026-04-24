import 'package:flutter/foundation.dart';

class NavState {
  NavState._();

  /// 0: Home, 1: Products, 2: Deals, 3: More, 4: Account
  static final ValueNotifier<int> tabIndex = ValueNotifier<int>(0);
}

