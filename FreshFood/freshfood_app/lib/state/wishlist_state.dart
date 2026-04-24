import 'package:flutter/foundation.dart';
import 'package:freshfood_app/api/api_client.dart';
import 'package:freshfood_app/state/auth_state.dart';

class WishlistState {
  WishlistState._();

  static final ValueNotifier<Set<int>> productIdSet = ValueNotifier<Set<int>>(<int>{});
  static final ValueNotifier<bool> loading = ValueNotifier<bool>(false);

  static VoidCallback? _authListener;

  static bool isWished(int productId) => productIdSet.value.contains(productId);

  static void bindToAuth() {
    _authListener ??= () {
      final u = AuthState.currentUser.value;
      if (u == null) {
        productIdSet.value = <int>{};
        return;
      }
      // ignore: discarded_futures
      refreshIds();
    };
    AuthState.currentUser.removeListener(_authListener!);
    AuthState.currentUser.addListener(_authListener!);
  }

  static Future<void> refreshIds() async {
    final u = AuthState.currentUser.value;
    if (u == null) {
      productIdSet.value = <int>{};
      return;
    }
    loading.value = true;
    try {
      final api = ApiClient();
      final ids = await api.getWishlistIds(u.userId);
      productIdSet.value = ids.toSet();
    } finally {
      loading.value = false;
    }
  }

  static Future<bool> toggle(int productId) async {
    final u = AuthState.currentUser.value;
    if (u == null) throw Exception('Bạn cần đăng nhập để dùng Yêu thích.');

    final api = ApiClient();
    // Optimistic toggle for snappy UI.
    final cur = Set<int>.from(productIdSet.value);
    final had = cur.contains(productId);
    if (had) {
      cur.remove(productId);
    } else {
      cur.add(productId);
    }
    productIdSet.value = cur;

    try {
      final wished = await api.toggleWishlist(userId: u.userId, productId: productId);
      if (wished == null) return !had;
      final next = Set<int>.from(productIdSet.value);
      if (wished) {
        next.add(productId);
      } else {
        next.remove(productId);
      }
      productIdSet.value = next;
      return wished;
    } catch (_) {
      // rollback
      final rollback = Set<int>.from(productIdSet.value);
      if (had) {
        rollback.add(productId);
      } else {
        rollback.remove(productId);
      }
      productIdSet.value = rollback;
      rethrow;
    }
  }
}

