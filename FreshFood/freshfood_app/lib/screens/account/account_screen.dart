import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:freshfood_app/config/api_config.dart';
import 'package:freshfood_app/screens/admin/home_settings_screen.dart';
import 'package:freshfood_app/screens/admin/orders/admin_orders_screen.dart';
import 'package:freshfood_app/screens/admin/products/admin_products_screen.dart';
import 'package:freshfood_app/screens/account/auth/auth_login_screen.dart';
import 'package:freshfood_app/screens/account/order/orders_screen.dart';
import 'package:freshfood_app/screens/account/profile_screen.dart';
import 'package:freshfood_app/screens/account/settings_screen.dart';
import 'package:freshfood_app/screens/account/wishlist_screen.dart';
import 'package:freshfood_app/l10n/app_localizations.dart';
import 'package:freshfood_app/state/auth_state.dart';

class AccountTab extends StatelessWidget {
  const AccountTab({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = AppLocalizations.of(context);
    return ValueListenableBuilder<AuthUser?>(
      valueListenable: AuthState.currentUser,
      builder: (context, user, _) {
        if (user == null) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(t.tr(vi: 'Tài khoản', en: 'Account'), style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
                const SizedBox(height: 10),
                Text(t.tr(vi: 'Bạn chưa đăng nhập.', en: 'You are not signed in.'), style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AuthLoginScreen())),
                  child: Text(t.tr(vi: 'Đăng nhập', en: 'Sign in')),
                ),
              ],
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.all(16),
          child: ListView(
            children: [
              _ProfileHeaderCard(user: user),
              const SizedBox(height: 14),
              _AccountItem(
                icon: Icons.person_outline,
                title: t.tr(vi: 'Hồ sơ', en: 'Profile'),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ProfileScreen())),
              ),
              _AccountItem(
                icon: Icons.receipt_long_outlined,
                title: t.tr(vi: 'Đơn hàng', en: 'Orders'),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const _OrdersScreen())),
              ),
              _AccountItem(
                icon: Icons.favorite_border,
                title: t.tr(vi: 'Yêu thích', en: 'Wishlist'),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const _WishlistScreen())),
              ),
              if ((user.role).trim().toLowerCase() == 'admin')
                _AccountItem(
                  icon: Icons.home_outlined,
                  title: t.tr(vi: 'Thiết lập trang chủ', en: 'Home settings'),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const HomeSettingsScreen())),
                ),
              if ((user.role).trim().toLowerCase() == 'admin')
                _AccountItem(
                  icon: Icons.production_quantity_limits_outlined,
                  title: t.tr(vi: 'Quản lý sản phẩm', en: 'Product management'),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AdminProductsScreen())),
                ),
              if ((user.role).trim().toLowerCase() == 'admin')
                _AccountItem(
                  icon: Icons.receipt_long_outlined,
                  title: t.tr(vi: 'Quản lý đơn hàng', en: 'Order management'),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AdminOrdersScreen())),
                ),
              _AccountItem(
                icon: Icons.settings_outlined,
                title: t.settings,
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const _SettingsScreen())),
              ),
              const SizedBox(height: 10),
              _AccountItem(
                icon: Icons.logout_rounded,
                title: t.tr(vi: 'Đăng xuất', en: 'Sign out'),
                danger: true,
                onTap: () async {
                  await AuthState.signOut();
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AccountItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final bool danger;
  const _AccountItem({required this.icon, required this.title, required this.onTap, this.danger = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = danger ? const Color(0xFFEF4444) : theme.colorScheme.onSurface;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            // border: Border.all(color: theme.colorScheme.outlineVariant),
            color: theme.colorScheme.surface,
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: danger ? const Color(0xFFEF4444).withValues(alpha: 0.08) : const Color(0xFF62BF39).withValues(alpha: 0.10),
                ),
                child: Icon(icon, color: danger ? const Color(0xFFEF4444) : const Color(0xFF62BF39)),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900, color: color))),
              Icon(Icons.chevron_right_rounded, color: danger ? const Color(0xFFEF4444) : theme.colorScheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileHeaderCard extends StatelessWidget {
  final AuthUser user;
  const _ProfileHeaderCard({required this.user});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = AppLocalizations.of(context);

    final name = user.fullName.trim().isEmpty ? 'User' : user.fullName.trim();
    final email = user.email.trim();
    final avatarUrl = ApiConfig.resolveMediaUrl(user.avatarUrl);
    final isAdmin = user.role.trim().toLowerCase() == 'admin';
    final roleText = isAdmin ? t.tr(vi: 'QUẢN TRỊ VIÊN', en: 'Admin') : t.tr(vi: 'KHÁCH HÀNG', en: 'Customer');
    final roleBg = isAdmin ? const Color(0xFF62BF39).withValues(alpha: 0.12) : const Color(0xFF10B981).withValues(alpha: 0.12);
    final roleBorder = isAdmin ? const Color(0xFF62BF39).withValues(alpha: 0.30) : const Color(0xFF10B981).withValues(alpha: 0.30);
    final roleFg = isAdmin ? const Color(0xFF62BF39) : const Color(0xFF047857);

    Widget avatar() {
      final initials = name.trim().isNotEmpty ? name.trim().characters.first.toUpperCase() : 'U';
      final showFallbackRing = avatarUrl.isEmpty;
      return Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: showFallbackRing ? Border.all(color: const Color(0xFF62BF39), width: 2) : null,
        ),
        clipBehavior: Clip.antiAlias,
        child: avatarUrl.isEmpty
            ? Center(child: Text(initials, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)))
            : CachedNetworkImage(
                imageUrl: avatarUrl,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(color: theme.colorScheme.surfaceContainerHighest),
                errorWidget: (_, __, ___) => Center(child: Text(initials, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18))),
              ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: theme.colorScheme.surface,
        border: Border.all(color: theme.colorScheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          avatar(),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
                if (email.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(email, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant, fontWeight: FontWeight.w700)),
                ],
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        color: roleBg,
                        border: Border.all(color: roleBorder),
                      ),
                      child: Text(
                        roleText,
                        style: TextStyle(fontWeight: FontWeight.w900, color: roleFg, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(Icons.verified_rounded, color: theme.colorScheme.onSurfaceVariant),
        ],
      ),
    );
  }
}

class _OrdersScreen extends StatelessWidget {
  const _OrdersScreen();

  @override
  Widget build(BuildContext context) {
    return const OrdersScreen();
  }
}

class _WishlistScreen extends StatelessWidget {
  const _WishlistScreen();

  @override
  Widget build(BuildContext context) {
    return const WishlistScreen();
  }
}

class _SettingsScreen extends StatelessWidget {
  const _SettingsScreen();
  @override
  Widget build(BuildContext context) {
    return const SettingsScreen();
  }
}