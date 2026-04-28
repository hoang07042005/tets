import 'package:flutter/material.dart';
import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:freshfood_app/l10n/app_localizations.dart';
import 'package:freshfood_app/shell/app_shell.dart';
import 'package:freshfood_app/screens/account/auth/auth_guest_set_password_screen.dart';
import 'package:freshfood_app/screens/onboarding/onboarding_screen.dart';
import 'package:freshfood_app/screens/payment/payment_result_screen.dart';
import 'package:freshfood_app/api/api_client.dart';
import 'package:freshfood_app/state/auth_state.dart';
import 'package:freshfood_app/state/cart_state.dart';
import 'package:freshfood_app/state/locale_state.dart' as locale_state;
import 'package:freshfood_app/state/wishlist_state.dart';
import 'package:freshfood_app/state/theme_state.dart';
import 'package:freshfood_app/state/maintenance_state.dart';
import 'package:freshfood_app/screens/system/maintenance_screen.dart';
import 'package:freshfood_app/state/app_navigator.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final bootResults = await Future.wait<dynamic>([
    AuthState.restore(),
    CartState.restore(),
    ThemeState.restore(),
    locale_state.LocaleState.restore(),
    SharedPreferences.getInstance(),
  ]);
  final prefs = bootResults[4] as SharedPreferences;
  final onboarded = prefs.getBool('freshfood_onboarded') ?? false;

  WishlistState.bindToAuth();
  // ignore: discarded_futures
  WishlistState.refreshIds();
  runApp(MyApp(onboarded: onboarded));
}

class MyApp extends StatefulWidget {
  final bool onboarded;
  const MyApp({super.key, required this.onboarded});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  StreamSubscription<Uri>? _sub;
  String? _lastHandledDeepLink;
  DateTime? _lastHandledAt;

  static const _dlKey = 'freshfood_last_deeplink';
  static const _dlAtKey = 'freshfood_last_deeplink_at_ms';

  @override
  void initState() {
    super.initState();
    final links = AppLinks();
    _sub = links.uriLinkStream.listen((uri) {
      // ignore: discarded_futures
      _handleDeepLink(uri);
    });
    // initial link (cold start)
    links.getInitialLink().then((uri) {
      if (uri != null) {
        // ignore: discarded_futures
        _handleDeepLink(uri);
      }
    });

    // Proactively probe a public endpoint once at startup so maintenance
    // mode is detected even if the first screen uses cached/offline data.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await ApiClient.instance.getHomePageSettings();
      } catch (_) {
        // ignore - maintenance detection is handled inside ApiClient wrapper (503)
      }
    });
  }

  Future<void> _handleDeepLink(Uri uri) async {
    if (uri.scheme != 'freshfood') return;

    // Avoid re-processing the same deep link on hot restart / reattach.
    final link = uri.toString();
    if (_lastHandledDeepLink == link) return;
    final now = DateTime.now();
    final withinMs = _lastHandledAt == null ? null : now.difference(_lastHandledAt!).inMilliseconds;
    if (withinMs != null && withinMs >= 0 && withinMs < 1500) {
      // defensive: ignore bursts
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final prev = (prefs.getString(_dlKey) ?? '').trim();
      final prevAtMs = prefs.getInt(_dlAtKey) ?? 0;
      final prevAt = prevAtMs > 0 ? DateTime.fromMillisecondsSinceEpoch(prevAtMs) : null;
      final recentlySame = prev.isNotEmpty && prev == link && prevAt != null && now.difference(prevAt).inSeconds < 60;
      if (recentlySame) return;
      await prefs.setString(_dlKey, link);
      await prefs.setInt(_dlAtKey, now.millisecondsSinceEpoch);
    } catch (_) {
      // ignore persistence errors
    }

    _lastHandledDeepLink = link;
    _lastHandledAt = now;

    if (uri.host == 'pay' && uri.path == '/return') {
      final valid = uri.queryParameters['valid'] ?? '';
      final code = (uri.queryParameters['code'] ?? '').trim();
      final orderId = (uri.queryParameters['orderId'] ?? '').trim();
      final orderCode = (uri.queryParameters['orderCode'] ?? '').trim();
      final ok = valid == '1' && (code == '00' || code == '0');

      if (ok) {
        // Backend clears DB cart on payment success (VNPay/MoMo),
        // so we must also clear local cart persistence.
        CartState.clear();
      }

      // Bring user back to root then show a dedicated result screen.
      AppNavigator.rootKey.currentState?.popUntil((r) => r.isFirst);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final nav = AppNavigator.rootKey.currentState;
        if (nav == null) return;
        nav.push(
          MaterialPageRoute(
            builder: (_) => PaymentResultScreen(
              success: ok,
              orderId: orderCode.isNotEmpty ? orderCode : (orderId.isEmpty ? null : orderId),
              code: code.isEmpty ? null : code,
            ),
          ),
        );
      });
      return;
    }

    if (uri.host == 'auth' && uri.path == '/guest-set-password') {
      final email = (uri.queryParameters['email'] ?? '').trim();
      final token = (uri.queryParameters['token'] ?? '').trim();
      AppNavigator.rootKey.currentState?.popUntil((r) => r.isFirst);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final nav = AppNavigator.rootKey.currentState;
        if (nav == null) return;
        nav.push(MaterialPageRoute(builder: (_) => GuestSetPasswordScreen(initialEmail: email, initialToken: token)));
      });
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Brand green (from your design): #2ECC71
    const seed = Color(0xFF62BF39);
    const lightBg = Colors.white;
    // Neutral dark palette (black/gray) instead of blue-gray.
    const darkBg = Color(0xFF0F1012);
    const darkSurface = Color(0xFF17181B);
    const darkSurface2 = Color(0xFF1F2125);
    const darkOutline = Color(0xFF2B2E34);

    // In Material 3, the seed color also tints "container" surfaces.
    // Keep green as primary, but make light surfaces more neutral (less green cast).
    final lightScheme = ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.light).copyWith(
      surface: lightBg,
      surfaceContainerHighest: const Color(0xFFF8FAFC),
      outlineVariant: const Color(0xFFE2E8F0),
    );
    final light = ThemeData(
      colorScheme: lightScheme,
      useMaterial3: true,
      scaffoldBackgroundColor: lightBg,
      canvasColor: lightBg,
      appBarTheme: const AppBarTheme(
        backgroundColor: lightBg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      cardTheme: const CardTheme(surfaceTintColor: Colors.transparent),
      bottomSheetTheme: const BottomSheetThemeData(surfaceTintColor: Colors.transparent),
      dialogTheme: const DialogTheme(surfaceTintColor: Colors.transparent),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: seed, width: 1.4)),
        hintStyle: const TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w700),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: lightBg,
        surfaceTintColor: Colors.transparent,
        indicatorColor: Colors.transparent, // don't tint active item background
        height: 68,
        labelTextStyle: WidgetStateProperty.resolveWith<TextStyle?>((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(color: seed, fontWeight: FontWeight.w800, fontSize: 11);
          }
          return const TextStyle(color: Color(0xFF7A7A7A), fontWeight: FontWeight.w600, fontSize: 11);
        }),
        iconTheme: WidgetStateProperty.resolveWith<IconThemeData?>((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: seed, size: 22);
          }
          return const IconThemeData(color: Color(0xFF7A7A7A), size: 22);
        }),
      ),
    );

    final dark = ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.dark).copyWith(
        surface: darkSurface,
        surfaceContainerHighest: darkSurface2,
        outlineVariant: darkOutline,
      ),
      useMaterial3: true,
      scaffoldBackgroundColor: darkBg,
      canvasColor: darkBg,
      appBarTheme: const AppBarTheme(
        backgroundColor: darkBg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      cardTheme: const CardTheme(surfaceTintColor: Colors.transparent, color: darkSurface),
      bottomSheetTheme: const BottomSheetThemeData(surfaceTintColor: Colors.transparent, backgroundColor: darkSurface),
      dialogTheme: const DialogTheme(surfaceTintColor: Colors.transparent, backgroundColor: darkSurface),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: darkSurface2,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: darkOutline)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: darkOutline)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: seed, width: 1.4)),
        hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontWeight: FontWeight.w700),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: darkBg,
        surfaceTintColor: Colors.transparent,
        indicatorColor: Colors.transparent,
        height: 68,
        labelTextStyle: WidgetStateProperty.resolveWith<TextStyle?>((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(color: seed, fontWeight: FontWeight.w800, fontSize: 11);
          }
          return const TextStyle(color: Color(0xFF94A3B8), fontWeight: FontWeight.w600, fontSize: 11);
        }),
        iconTheme: WidgetStateProperty.resolveWith<IconThemeData?>((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: seed, size: 22);
          }
          return const IconThemeData(color: Color(0xFF94A3B8), size: 22);
        }),
      ),
    );

    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeState.themeMode,
      builder: (context, mode, _) {
        return ValueListenableBuilder<Locale>(
          valueListenable: locale_state.LocaleState.locale,
          builder: (context, loc, __) {
            return MaterialApp(
              title: 'FreshFood',
              navigatorKey: AppNavigator.rootKey,
              scaffoldMessengerKey: AppNavigator.messengerKey,
              theme: light,
              darkTheme: dark,
              themeMode: mode,
              locale: loc,
              supportedLocales: AppLocalizations.supportedLocales,
              localizationsDelegates: const [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              builder: (context, child) {
                final base = child ?? const SizedBox.shrink();
                return ValueListenableBuilder<bool>(
                  valueListenable: MaintenanceState.isMaintenance,
                  builder: (_, isMaint, __) {
                    return ValueListenableBuilder<bool>(
                      valueListenable: MaintenanceState.bypassOverlay,
                      builder: (_, bypass, ___) {
                        return ValueListenableBuilder<AuthUser?>(
                          valueListenable: AuthState.currentUser,
                          builder: (_, user, ____) {
                            final role = (user?.role ?? '').trim().toLowerCase();
                            final isAdmin = role == 'admin';
                            final showOverlay = isMaint && !isAdmin && !bypass;
                            if (!showOverlay) return base;
                            return Stack(
                              children: [
                                base,
                                const Positioned.fill(child: MaintenanceScreen()),
                              ],
                            );
                          },
                        );
                      },
                    );
                  },
                );
              },
              home: widget.onboarded ? const AppShell() : const OnboardingScreen(),
            );
          },
        );
      },
    );
  }
}
