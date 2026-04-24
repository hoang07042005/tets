import 'package:flutter/material.dart';
import 'package:freshfood_app/api/api_client.dart';
import 'package:freshfood_app/screens/account/auth/auth_login_screen.dart';
import 'package:freshfood_app/screens/account/auth/auth_reset_password_screen.dart';
import 'package:freshfood_app/l10n/app_localizations.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _api = ApiClient();
  final _emailCtl = TextEditingController();
  bool _loading = false;
  bool _done = false;
  String? _devToken;
  String? _error;

  @override
  void dispose() {
    _emailCtl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    final t = AppLocalizations.of(context);
    final email = _emailCtl.text.trim();
    if (email.isEmpty) {
      setState(() => _error = t.tr(vi: 'Vui lòng nhập email.', en: 'Please enter your email.'));
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      _devToken = null;
    });
    try {
      final token = await _api.forgotPassword(email: email);
      if (!mounted) return;
      setState(() {
        _done = true;
        _devToken = token;
      });
    } catch (e) {
      setState(() => _error = '$e'.replaceFirst('Exception: ', '').trim());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _openReset({String? token}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ResetPasswordScreen(
          initialEmail: _emailCtl.text.trim(),
          initialToken: token,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = AppLocalizations.of(context);
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
          children: [
            Row(
              children: [
                Image.asset('assets/freshfood-app.png', width: 26, height: 26),
                const SizedBox(width: 8),
                Text(
                  'FRESHFOOD',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900, letterSpacing: 1.2, color: const Color(0xFF62BF39)),
                ),
                const Spacer(),
                IconButton(onPressed: () => Navigator.of(context).maybePop(), icon: const Icon(Icons.close_rounded)),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                color: const Color(0xFF62BF39).withValues(alpha: 0.06),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t.tr(vi: 'Khôi phục mật khẩu', en: 'Recover password'), style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900, height: 1.1)),
                  const SizedBox(height: 8),
                  Text(
                    t.tr(vi: 'Nhập email để nhận mã đặt lại mật khẩu.', en: 'Enter your email to receive a reset code.'),
                    style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant, height: 1.35),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: theme.colorScheme.outlineVariant),
                color: theme.colorScheme.surface,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(t.tr(vi: 'Quên mật khẩu', en: 'Forgot password'), style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 6),
                  Text(
                    t.tr(vi: 'Chúng tôi sẽ gửi hướng dẫn (dev: có thể trả về mã).', en: "We'll send instructions (dev: may return the code)."),
                    style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 14),
                  if (_error != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        color: const Color(0xFFEF4444).withValues(alpha: 0.08),
                      ),
                      child: Text(_error!, style: theme.textTheme.bodyMedium?.copyWith(color: const Color(0xFFB91C1C), fontWeight: FontWeight.w800)),
                    ),
                  if (_error != null) const SizedBox(height: 12),
                  if (_done)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            color: const Color(0xFF62BF39).withValues(alpha: 0.10),
                          ),
                          child: Text(
                            t.tr(
                              vi: 'Nếu email tồn tại trong hệ thống, bạn sẽ nhận được mã đặt lại trong vài phút.',
                              en: 'If the email exists, you will receive a reset code within a few minutes.',
                            ),
                            style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w800),
                          ),
                        ),
                        if ((_devToken ?? '').trim().isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Text(
                            t.tr(vi: 'Mã (dev):', en: 'Code (dev):'),
                            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant, fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 6),
                          SelectableText(_devToken!, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w900)),
                          const SizedBox(height: 10),
                          SizedBox(
                            height: 46,
                            child: ElevatedButton(
                              onPressed: () => _openReset(token: _devToken),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF62BF39),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                textStyle: const TextStyle(fontWeight: FontWeight.w900),
                              ),
                              child: Text(t.tr(vi: 'Đặt lại mật khẩu ngay', en: 'Reset password now')),
                            ),
                          ),
                        ],
                        const SizedBox(height: 10),
                        TextButton(
                          onPressed: () => Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const AuthLoginScreen())),
                          child: Text(t.tr(vi: 'Quay lại đăng nhập', en: 'Back to sign in'), style: const TextStyle(fontWeight: FontWeight.w900)),
                        ),
                      ],
                    )
                  else ...[
                    _Field(
                      label: t.tr(vi: 'ĐỊA CHỈ EMAIL', en: 'EMAIL ADDRESS'),
                      controller: _emailCtl,
                      hint: 'hello@freshfood.com',
                      icon: Icons.mail_outline,
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _loading ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF62BF39),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          textStyle: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                        child: Text(_loading ? t.tr(vi: 'Đang gửi…', en: 'Sending…') : t.tr(vi: 'Gửi mã đặt lại →', en: 'Send reset code →')),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _openReset,
                      child: Text(
                        t.tr(vi: 'Đã có mã? Đặt lại mật khẩu', en: 'Already have a code? Reset password'),
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final TextInputType? keyboardType;
  final bool obscureText;
  const _Field({
    required this.label,
    required this.controller,
    required this.hint,
    required this.icon,
    this.keyboardType,
    this.obscureText = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w900, color: theme.colorScheme.onSurfaceVariant, letterSpacing: 0.6)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          obscureText: obscureText,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon),
            filled: true,
            fillColor: theme.colorScheme.surfaceContainerHighest,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: theme.colorScheme.outlineVariant),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFF62BF39), width: 1.6),
            ),
          ),
        ),
      ],
    );
  }
}

