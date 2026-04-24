import 'package:flutter/material.dart';
import 'package:freshfood_app/api/api_client.dart';
import 'package:freshfood_app/screens/account/auth/auth_forgot_password_screen.dart';
import 'package:freshfood_app/screens/account/auth/auth_register_screen.dart';
import 'package:freshfood_app/l10n/app_localizations.dart';
import 'package:freshfood_app/state/auth_state.dart';

class AuthLoginScreen extends StatefulWidget {
  const AuthLoginScreen({super.key});

  @override
  State<AuthLoginScreen> createState() => _AuthLoginScreenState();
}

class _AuthLoginScreenState extends State<AuthLoginScreen> {
  final _api = ApiClient();
  final _emailCtl = TextEditingController();
  final _pwdCtl = TextEditingController();
  bool _remember = true;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _emailCtl.dispose();
    _pwdCtl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    final t = AppLocalizations.of(context);
    final email = _emailCtl.text.trim();
    final pwd = _pwdCtl.text;
    if (email.isEmpty || pwd.isEmpty) {
      setState(() => _error = t.tr(vi: 'Vui lòng nhập email và mật khẩu.', en: 'Please enter email and password.'));
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await _api.login(email: email, password: pwd);
      await AuthState.signIn(user: res.user, jwt: res.token, expiresInSeconds: res.expiresInSeconds, remember: _remember);
      if (!mounted) return;
      Navigator.of(context).pop();
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
                IconButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: const Icon(Icons.close_rounded),
                  tooltip: t.tr(vi: 'Đóng', en: 'Close'),
                ),
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
                    t.tr(vi: 'Từ nông trại đến bàn ăn,\nchọn lọc tinh hoa.', en: 'From farm to table,\nhandpicked goodness.'),
                    style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900, height: 1.1),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    t.tr(
                      vi: 'Tham gia cộng đồng yêu thực phẩm sạch, canh tác bền vững và theo mùa.',
                      en: 'Join a community that loves clean, seasonal, sustainable food.',
                    ),
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
                  Text(t.tr(vi: 'Chào mừng trở lại', en: 'Welcome back'), style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 6),
                  Text(
                    t.tr(vi: 'Đăng nhập để tiếp tục mua sắm cùng FreshFood.', en: 'Sign in to continue shopping with FreshFood.'),
                    style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            color: const Color(0xFF62BF39).withValues(alpha: 0.12),
                          ),
                          child: Text(
                            t.tr(vi: 'Đăng nhập', en: 'Sign in'),
                            style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF62BF39)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const AuthRegisterScreen())),
                          style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                          child: Text(t.tr(vi: 'Đăng ký', en: 'Sign up'), style: const TextStyle(fontWeight: FontWeight.w900)),
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
                      child: Text(_error!, style: theme.textTheme.bodyMedium?.copyWith(color: const Color(0xFFB91C1C), fontWeight: FontWeight.w800)),
                    ),
                  if (_error != null) const SizedBox(height: 12),
                  _Field(
                    label: t.tr(vi: 'ĐỊA CHỈ EMAIL', en: 'EMAIL ADDRESS'),
                    controller: _emailCtl,
                    hint: 'hello@freshfood.com',
                    icon: Icons.mail_outline,
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 12),
                  _Field(
                    label: t.tr(vi: 'MẬT KHẨU', en: 'PASSWORD'),
                    controller: _pwdCtl,
                    hint: '••••••••',
                    icon: Icons.lock_outline,
                    obscureText: true,
                  ),
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: () => setState(() => _remember = !_remember),
                    borderRadius: BorderRadius.circular(12),
                    child: Row(
                      children: [
                        Checkbox(
                          value: _remember,
                          onChanged: (v) => setState(() => _remember = v ?? true),
                          activeColor: const Color(0xFF62BF39),
                        ),
                        Expanded(
                          child: Text(
                            t.tr(vi: 'Ghi nhớ đăng nhập trong 24 giờ', en: 'Remember for 24 hours'),
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 2),
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    runAlignment: WrapAlignment.center,
                    spacing: 8,
                    runSpacing: 0,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ForgotPasswordScreen())),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                          minimumSize: const Size(0, 36),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(t.tr(vi: 'Quên mật khẩu?', en: 'Forgot password?'), style: const TextStyle(fontWeight: FontWeight.w900)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
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
                      child: Text(
                        _loading ? t.tr(vi: 'Đang đăng nhập…', en: 'Signing in…') : t.tr(vi: 'Đăng nhập →', en: 'Sign in →'),
                      ),
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
