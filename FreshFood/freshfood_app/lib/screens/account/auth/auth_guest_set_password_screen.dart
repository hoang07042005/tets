import 'package:flutter/material.dart';
import 'package:freshfood_app/api/api_client.dart';
import 'package:freshfood_app/screens/account/auth/auth_forgot_password_screen.dart';
import 'package:freshfood_app/screens/account/auth/auth_login_screen.dart';
import 'package:freshfood_app/l10n/app_localizations.dart';

/// Trang từ link email sau đơn hàng khách — không dùng luồng "Quên mật khẩu".
class GuestSetPasswordScreen extends StatefulWidget {
  final String? initialEmail;
  final String? initialToken;
  const GuestSetPasswordScreen({super.key, this.initialEmail, this.initialToken});

  @override
  State<GuestSetPasswordScreen> createState() => _GuestSetPasswordScreenState();
}

class _GuestSetPasswordScreenState extends State<GuestSetPasswordScreen> {
  final _api = ApiClient();
  late final TextEditingController _emailCtl;
  late final TextEditingController _tokenCtl;
  final _pwdCtl = TextEditingController();
  final _pwd2Ctl = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _emailCtl = TextEditingController(text: (widget.initialEmail ?? '').trim());
    _tokenCtl = TextEditingController(text: (widget.initialToken ?? '').trim());
  }

  @override
  void dispose() {
    _emailCtl.dispose();
    _tokenCtl.dispose();
    _pwdCtl.dispose();
    _pwd2Ctl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    final t = AppLocalizations.of(context);
    final email = _emailCtl.text.trim();
    final token = _tokenCtl.text.trim();
    final p1 = _pwdCtl.text;
    final p2 = _pwd2Ctl.text;
    if (email.isEmpty || token.isEmpty) {
      setState(() => _error = t.tr(vi: 'Vui lòng nhập email và mã từ email.', en: 'Please enter email and the code from the email.'));
      return;
    }
    if (p1.length < 6) {
      setState(() => _error = t.tr(vi: 'Mật khẩu phải có ít nhất 6 ký tự.', en: 'Password must be at least 6 characters.'));
      return;
    }
    if (p1 != p2) {
      setState(() => _error = t.tr(vi: 'Mật khẩu xác nhận không khớp.', en: 'Passwords do not match.'));
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await _api.setInitialPassword(email: email, token: token, newPassword: p1);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t.tr(vi: 'Đã tạo mật khẩu thành công. Bạn có thể đăng nhập.', en: 'Password created successfully. You can now sign in.'))),
      );
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const AuthLoginScreen()));
    } catch (e) {
      setState(() => _error = '$e'.replaceFirst('Exception: ', '').trim());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
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
                Text('FRESHFOOD', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900, letterSpacing: 1.2, color: const Color(0xFF62BF39))),
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
                  Text(t.tr(vi: 'Tạo mật khẩu', en: 'Create password'), style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900, height: 1.1)),
                  const SizedBox(height: 8),
                  Text(
                    t.tr(
                      vi: 'Kích hoạt tài khoản sau khi đặt hàng — dùng mã trong email chúng tôi đã gửi.',
                      en: "Activate your account after checkout — use the code in the email we sent.",
                    ),
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
                  Text(
                    t.tr(vi: 'Đặt mật khẩu cho tài khoản của bạn', en: 'Set a password for your account'),
                    style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    t.tr(vi: 'Liên kết có hiệu lực 48 giờ.', en: 'This link is valid for 48 hours.'),
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
                  _Field(label: 'EMAIL', controller: _emailCtl, hint: 'hello@freshfood.com', icon: Icons.mail_outline, keyboardType: TextInputType.emailAddress),
                  const SizedBox(height: 12),
                  _Field(
                    label: t.tr(vi: 'MÃ TỪ EMAIL', en: 'CODE FROM EMAIL'),
                    controller: _tokenCtl,
                    hint: t.tr(vi: 'Đã điền sẵn nếu bạn mở đúng link', en: 'Auto-filled if you opened the correct link'),
                    icon: Icons.lock_outline,
                  ),
                  const SizedBox(height: 12),
                  _Field(
                    label: t.tr(vi: 'MẬT KHẨU', en: 'PASSWORD'),
                    controller: _pwdCtl,
                    hint: t.tr(vi: 'Tối thiểu 6 ký tự', en: 'At least 6 characters'),
                    icon: Icons.key_outlined,
                    obscureText: true,
                  ),
                  const SizedBox(height: 12),
                  _Field(label: t.tr(vi: 'XÁC NHẬN MẬT KHẨU', en: 'CONFIRM PASSWORD'), controller: _pwd2Ctl, hint: '••••••••', icon: Icons.key_outlined, obscureText: true),
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
                      child: Text(_loading ? t.tr(vi: 'Đang lưu…', en: 'Saving…') : t.tr(vi: 'Tạo mật khẩu →', en: 'Create password →')),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 10,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ForgotPasswordScreen())),
                        child: Text(t.tr(vi: 'Không dùng được link / cần mã mới', en: 'Link not working / need a new code'), style: const TextStyle(fontWeight: FontWeight.w900)),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const AuthLoginScreen())),
                        child: Text(t.tr(vi: 'Đăng nhập', en: 'Sign in'), style: const TextStyle(fontWeight: FontWeight.w900)),
                      ),
                    ],
                  ),
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

