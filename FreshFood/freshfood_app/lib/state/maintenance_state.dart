import 'package:flutter/foundation.dart';

class MaintenanceState {
  MaintenanceState._();

  static final ValueNotifier<bool> isMaintenance = ValueNotifier<bool>(false);
  static final ValueNotifier<String?> message = ValueNotifier<String?>(null);
  // Allow temporarily showing admin login UI while maintenance overlay is active.
  static final ValueNotifier<bool> bypassOverlay = ValueNotifier<bool>(false);

  static void enter({String? msg}) {
    isMaintenance.value = true;
    message.value = (msg ?? '').trim().isEmpty ? null : msg!.trim();
  }

  static void exit() {
    isMaintenance.value = false;
    message.value = null;
    bypassOverlay.value = false;
  }

  static void allowAdminLogin() {
    bypassOverlay.value = true;
  }

  static void disallowAdminLogin() {
    bypassOverlay.value = false;
  }
}

