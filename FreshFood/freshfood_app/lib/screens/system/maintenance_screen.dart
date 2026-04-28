import 'package:flutter/material.dart';
import 'package:freshfood_app/api/api_client.dart';
import 'package:freshfood_app/screens/account/auth/auth_login_screen.dart';
import 'package:freshfood_app/state/auth_state.dart';
import 'package:freshfood_app/state/maintenance_state.dart';
import 'package:freshfood_app/state/app_navigator.dart';

class MaintenanceScreen extends StatefulWidget {
  const MaintenanceScreen({super.key});

  @override
  State<MaintenanceScreen> createState() => _MaintenanceScreenState();
}

class _MaintenanceScreenState extends State<MaintenanceScreen> {
  bool _checking = false;

  Future<void> _retry() async {
    if (_checking) return;
    setState(() => _checking = true);
    try {
      // Any public endpoint is fine. If maintenance is still ON, middleware returns 503.
      await ApiClient.instance.getHomePageSettings();
      MaintenanceState.exit();
    } catch (_) {
      // keep maintenance screen
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.build_circle, size: 64, color: cs.primary),
                  const SizedBox(height: 16),
                  Text(
                    'Hệ thống đang bảo trì',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  ValueListenableBuilder<String?>(
                    valueListenable: MaintenanceState.message,
                    builder: (_, msg, __) {
                      final text = (msg ?? '').trim().isEmpty
                          ? 'Chúng tôi đang tiến hành nâng cấp hệ thống. Vui lòng quay lại sau.'
                          : msg!.trim();
                      return Text(
                        text,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: cs.onSurfaceVariant),
                        textAlign: TextAlign.center,
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton(
                          onPressed: _checking ? null : _retry,
                          child: Text(_checking ? 'Đang kiểm tra...' : 'Thử lại'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () async {
                            MaintenanceState.allowAdminLogin();
                            // Wait a frame so the maintenance overlay is removed (bypassOverlay = true)
                            // before pushing the login route.
                            await WidgetsBinding.instance.endOfFrame;

                            final nav = AppNavigator.rootKey.currentState;
                            if (nav == null) {
                              AppNavigator.messengerKey.currentState?.showSnackBar(
                                const SnackBar(content: Text('Không thể mở màn hình đăng nhập. Vui lòng thử lại.')),
                              );
                              return;
                            }

                            await nav.push(MaterialPageRoute(builder: (_) => const AuthLoginScreen()));

                            // If user didn't become admin, keep maintenance overlay enabled.
                            final role = (AuthState.currentUser.value?.role ?? '').trim().toLowerCase();
                            final isAdmin = role == 'admin';
                            if (!isAdmin) {
                              MaintenanceState.disallowAdminLogin();
                            }
                          },
                          child: const Text('Đăng nhập Admin'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

