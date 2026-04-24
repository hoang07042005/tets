import 'package:flutter/material.dart';
import 'package:freshfood_app/api/api_client.dart';
import 'package:freshfood_app/screens/account/auth/auth_login_screen.dart';
import 'package:freshfood_app/l10n/app_localizations.dart';

class AuthRegisterScreen extends StatefulWidget {
  const AuthRegisterScreen({super.key});

  @override
  State<AuthRegisterScreen> createState() => _AuthRegisterScreenState();
}

class _AuthRegisterScreenState extends State<AuthRegisterScreen> {
  final _api = ApiClient();
  final _nameCtl = TextEditingController();
  final _emailCtl = TextEditingController();
  final _phoneCtl = TextEditingController();
  final _pwdCtl = TextEditingController();
  final _pwd2Ctl = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _nameCtl.dispose();
    _emailCtl.dispose();
    _phoneCtl.dispose();
    _pwdCtl.dispose();
    _pwd2Ctl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    final t = AppLocalizations.of(context);
    final fullName = _nameCtl.text.trim();
    final email = _emailCtl.text.trim();
    final phone = _phoneCtl.text.trim();
    final pwd = _pwdCtl.text;
    final pwd2 = _pwd2Ctl.text;
    if (fullName.isEmpty || email.isEmpty || phone.isEmpty || pwd.isEmpty) {
      setState(() => _error = t.tr(vi: 'Vui lòng nhập đầy đủ thông tin.', en: 'Please fill in all required fields.'));
      return;
    }
    if (pwd != pwd2) {
      setState(() => _error = t.tr(vi: 'Mật khẩu xác nhận không khớp.', en: 'Passwords do not match.'));
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await _api.register(fullName: fullName, email: email, phone: phone, password: pwd);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t.tr(vi: 'Đăng ký thành công! Vui lòng đăng nhập.', en: 'Sign up successful! Please sign in.'))),
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
                Text(
                  'FreshFood',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900, color: const Color(0xFF62BF39)),
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
                  Text(
                    t.tr(vi: 'Bắt nguồn từ\nthiên nhiên thuần khiết.', en: 'Rooted in\npure nature.'),
                    style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900, height: 1.1),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    t.tr(vi: 'Tham gia cùng chúng tôi để khám phá thực phẩm hữu cơ tươi ngon nhất.', en: 'Join us to discover the freshest organic foods.'),
                    style: theme.textTheme.bodyMedium?.copyWith(color: const Color(0xFF4B5563), height: 1.35),
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
                  Text(t.tr(vi: 'Tạo tài khoản mới', en: 'Create a new account'), style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 6),
                  Text(
                    t.tr(vi: 'Bắt đầu hành trình sống xanh cùng chúng tôi hôm nay.', en: 'Start your green journey with us today.'),
                    style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const AuthLoginScreen())),
                          style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                          child: Text(t.tr(vi: 'Đăng nhập', en: 'Sign in'), style: const TextStyle(fontWeight: FontWeight.w900)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            color: const Color(0xFF62BF39).withValues(alpha: 0.12),
                          ),
                          child: Text(
                            t.tr(vi: 'Đăng ký', en: 'Sign up'),
                            style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF62BF39)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  if (_error != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        color: const Color(0xFFEF4444).withValues(alpha: 0.08),
                      ),
                      child: Text(
                        _error!,
                        style: theme.textTheme.bodyMedium?.copyWith(color: const Color(0xFFB91C1C), fontWeight: FontWeight.w800),
                      ),
                    ),
                  if (_error != null) const SizedBox(height: 12),
                  _Field(label: t.tr(vi: 'HỌ VÀ TÊN', en: 'FULL NAME'), controller: _nameCtl, hint: t.tr(vi: 'Nguyễn Văn A', en: 'John Doe'), icon: Icons.person_outline),
                  const SizedBox(height: 12),
                  _Field(label: 'EMAIL', controller: _emailCtl, hint: 'email@freshfood.com', icon: Icons.mail_outline, keyboardType: TextInputType.emailAddress),
                  const SizedBox(height: 12),
                  _Field(label: t.tr(vi: 'SỐ ĐIỆN THOẠI', en: 'PHONE NUMBER'), controller: _phoneCtl, hint: '0901 234 567', icon: Icons.phone_outlined, keyboardType: TextInputType.phone),
                  const SizedBox(height: 12),
                  _Field(label: t.tr(vi: 'MẬT KHẨU', en: 'PASSWORD'), controller: _pwdCtl, hint: '••••••••', icon: Icons.lock_outline, obscureText: true),
                  const SizedBox(height: 12),
                  _Field(label: t.tr(vi: 'XÁC NHẬN MẬT KHẨU', en: 'CONFIRM PASSWORD'), controller: _pwd2Ctl, hint: '••••••••', icon: Icons.lock_outline, obscureText: true),
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
                      child: Text(_loading ? t.tr(vi: 'Đang xử lý…', en: 'Processing…') : t.tr(vi: 'Đăng ký ngay', en: 'Create account')),
                    ),
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
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w900, color: const Color(0xFF6B7280), letterSpacing: 0.6),
        ),
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

