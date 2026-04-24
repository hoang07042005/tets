import 'package:flutter/material.dart';
import 'package:freshfood_app/api/api_client.dart';
import 'package:freshfood_app/screens/account/auth/auth_forgot_password_screen.dart';
import 'package:freshfood_app/l10n/app_localizations.dart';

class ResetPasswordScreen extends StatefulWidget {
  final String? initialEmail;
  final String? initialToken;
  const ResetPasswordScreen({super.key, this.initialEmail, this.initialToken});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
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
      setState(() => _error = t.tr(vi: 'Vui lòng nhập email và mã đặt lại.', en: 'Please enter email and reset code.'));
      return;
    }
    if (p1.length < 6) {
      setState(() => _error = t.tr(vi: 'Mật khẩu mới phải từ 6 ký tự.', en: 'New password must be at least 6 characters.'));
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
      await _api.resetPassword(email: email, token: token, newPassword: p1);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t.tr(vi: 'Đặt lại mật khẩu thành công. Vui lòng đăng nhập.', en: 'Password reset successfully. Please sign in.'))),
      );
      Navigator.of(context).popUntil((r) => r.isFirst);
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
                  Text(t.tr(vi: 'Đặt lại mật khẩu', en: 'Reset password'), style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900, height: 1.1)),
                  const SizedBox(height: 8),
                  Text(
                    t.tr(vi: 'Nhập mã đặt lại và mật khẩu mới.', en: 'Enter the reset code and your new password.'),
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
                  Text(t.tr(vi: 'Tạo mật khẩu mới', en: 'Create a new password'), style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 6),
                  Text(
                    t.tr(vi: 'Mã đặt lại có thời hạn 15 phút.', en: 'Reset code expires in 15 minutes.'),
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
                    label: t.tr(vi: 'MÃ ĐẶT LẠI', en: 'RESET CODE'),
                    controller: _tokenCtl,
                    hint: t.tr(vi: 'Dán mã vào đây', en: 'Paste the code here'),
                    icon: Icons.lock_outline,
                  ),
                  const SizedBox(height: 12),
                  _Field(label: t.tr(vi: 'MẬT KHẨU MỚI', en: 'NEW PASSWORD'), controller: _pwdCtl, hint: '••••••••', icon: Icons.key_outlined, obscureText: true),
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
                      child: Text(_loading ? t.tr(vi: 'Đang cập nhật…', en: 'Updating…') : t.tr(vi: 'Đặt lại mật khẩu →', en: 'Reset password →')),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const ForgotPasswordScreen())),
                        child: Text(t.tr(vi: 'Gửi lại mã', en: 'Resend code'), style: const TextStyle(fontWeight: FontWeight.w900)),
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

