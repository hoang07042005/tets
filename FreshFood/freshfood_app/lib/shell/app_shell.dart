import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:freshfood_app/screens/account/account_screen.dart';
import 'package:freshfood_app/screens/account/auth/auth_login_screen.dart';
import 'package:freshfood_app/config/api_config.dart';
import 'package:freshfood_app/screens/deals/deals_screen.dart';
import 'package:freshfood_app/screens/explore/explore_screen.dart';
import 'package:freshfood_app/screens/home/home_screen.dart';
import 'package:freshfood_app/screens/product/products_screen.dart';
import 'package:freshfood_app/screens/cart/cart_screen.dart';
import 'package:freshfood_app/state/auth_state.dart';
import 'package:freshfood_app/state/cart_state.dart';
import 'package:freshfood_app/state/nav_state.dart';
import 'package:freshfood_app/l10n/app_localizations.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;
  late final VoidCallback _navListener;
  final Set<int> _visitedTabs = <int>{0};

  @override
  void initState() {
    super.initState();
    _index = NavState.tabIndex.value;
    _navListener = () {
      final i = NavState.tabIndex.value;
      if (!mounted) return;
      if (i == _index) return;
      setState(() {
        _index = i;
        _visitedTabs.add(i);
      });
    };
    NavState.tabIndex.addListener(_navListener);
  }

  Widget _buildTab(int index) {
    switch (index) {
      case 0:
        return const HomeScreen();
      case 1:
        return const ProductsScreen();
      case 2:
        return const DealsScreen();
      case 3:
        return const ExploreScreen();
      case 4:
        return const AccountTab();
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  void dispose() {
    NavState.tabIndex.removeListener(_navListener);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 64,
        titleSpacing: 16,
        title: Row(
          children: [
            Image.asset(
              'assets/freshfood-app.png',
              width: 36,
              height: 36,
              fit: BoxFit.contain,
            ),
            const SizedBox(width: 8),
            Text(
              'FreshFood',
              style: theme.textTheme.titleLarge?.copyWith(
                color: const Color(0xFF62BF39),
                fontWeight: FontWeight.w900,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
        actions: [
          ValueListenableBuilder<int>(
            valueListenable: CartState.itemCount,
            builder: (context, count, _) {
              return IconButton(
                onPressed: () {
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CartScreen()));
                },
                tooltip: t.cart,
                icon: Badge(
                  isLabelVisible: count > 0,
                  backgroundColor: const Color(0xFFFF8A00),
                  label: Text(
                    count.toString(),
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  child: const Icon(Icons.shopping_cart_outlined, color: Color(0xFF62BF39)),
                ),
              );
            },
          ),
          const SizedBox(width: 6),
          ValueListenableBuilder<AuthUser?>(
            valueListenable: AuthState.currentUser,
            builder: (context, user, _) {
              if (user == null) {
                return Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: InkWell(
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AuthLoginScreen())),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(20),
                        // border: Border.all(color: theme.colorScheme.outlineVariant),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.person_outline, color: Color(0xFF62BF39)),
                          SizedBox(width: 4),
                          Icon(Icons.keyboard_arrow_right_rounded, color: Color(0xFF62BF39)),
                        ],
                      ),
                    ),
                  ),
                );
              }

              final initials = user.fullName.trim().isNotEmpty ? user.fullName.trim().characters.first.toUpperCase() : 'U';
              final avatarUrl = ApiConfig.resolveMediaUrl(user.avatarUrl);
              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: InkWell(
                  onTap: () => NavState.tabIndex.value = 4,
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(6, 6, 8, 6),
                    // decoration: BoxDecoration(
                    //   color: theme.colorScheme.surface,
                    //   borderRadius: BorderRadius.circular(20),
                    //   // border: Border.all(color: theme.colorScheme.outlineVariant),
                    // ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            // border: Border.all(color: const Color(0xFF62BF39), width: 2),
                          ),
                          child: CircleAvatar(
                            radius: 18,
                            backgroundColor: theme.colorScheme.primaryContainer,
                            foregroundColor: theme.colorScheme.onPrimaryContainer,
                            backgroundImage: avatarUrl.isEmpty ? null : CachedNetworkImageProvider(avatarUrl),
                            child: avatarUrl.isEmpty ? Text(initials) : null,
                          ),
                        ),
                        // const SizedBox(width: 6),
                        // const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF62BF39)),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: Stack(
        children: List<Widget>.generate(5, (i) {
          if (!_visitedTabs.contains(i)) return const SizedBox.shrink();
          final active = i == _index;
          return Offstage(
            offstage: !active,
            child: TickerMode(
              enabled: active,
              child: _buildTab(i),
            ),
          );
        }),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) {
          setState(() {
            _index = i;
            _visitedTabs.add(i);
          });
          NavState.tabIndex.value = i;
        },
        destinations: [
          NavigationDestination(icon: const Icon(Icons.home_outlined), selectedIcon: const Icon(Icons.home), label: t.navHome),
          NavigationDestination(icon: const Icon(Icons.storefront_outlined), selectedIcon: const Icon(Icons.storefront), label: t.navProducts),
          NavigationDestination(icon: const Icon(Icons.local_offer_outlined), selectedIcon: const Icon(Icons.local_offer), label: t.navDeals),
          NavigationDestination(icon: const Icon(Icons.grid_view_outlined), selectedIcon: const Icon(Icons.grid_view), label: t.navExplore),
          NavigationDestination(icon: const Icon(Icons.person_outline), selectedIcon: const Icon(Icons.person), label: t.navAccount),
        ],
      ),
    );
  }
}
  