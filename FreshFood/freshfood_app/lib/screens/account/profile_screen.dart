import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:freshfood_app/api/api_client.dart';
import 'package:freshfood_app/config/api_config.dart';
import 'package:freshfood_app/l10n/app_localizations.dart';
import 'package:freshfood_app/state/auth_state.dart';
import 'package:image_picker/image_picker.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _api = ApiClient();
  final _picker = ImagePicker();

  late final TextEditingController _firstNameCtl;
  late final TextEditingController _lastNameCtl;
  late final TextEditingController _emailCtl;
  late final TextEditingController _phoneCtl;
  late final TextEditingController _addressCtl;

  bool _saving = false;
  String? _msg;
  bool _msgOk = true;

  XFile? _pickedAvatar;

  @override
  void initState() {
    super.initState();
    final u = AuthState.currentUser.value;
    final parts = _splitName(u?.fullName ?? '');
    _firstNameCtl = TextEditingController(text: parts.$1);
    _lastNameCtl = TextEditingController(text: parts.$2);
    _emailCtl = TextEditingController(text: u?.email ?? '');
    _phoneCtl = TextEditingController(text: u?.phone ?? '');
    _addressCtl = TextEditingController(text: u?.address ?? '');
  }

  @override
  void dispose() {
    _firstNameCtl.dispose();
    _lastNameCtl.dispose();
    _emailCtl.dispose();
    _phoneCtl.dispose();
    _addressCtl.dispose();
    super.dispose();
  }

  (String, String) _splitName(String s) {
    final t = s.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (t.isEmpty) return ('', '');
    final parts = t.split(' ');
    if (parts.length == 1) return (parts[0], '');
    return (parts.first, parts.sublist(1).join(' '));
  }

  String _fullNameFromParts() {
    final f = _firstNameCtl.text.trim();
    final l = _lastNameCtl.text.trim();
    return ('$f $l').trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  Future<void> _pickAvatar() async {
    final f = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 90);
    if (f == null) return;
    setState(() {
      _pickedAvatar = f;
      _msg = null;
    });
  }

  Future<void> _save() async {
    final user = AuthState.currentUser.value;
    if (user == null) return;
    final t = AppLocalizations.of(context);
    final fullName = _fullNameFromParts();
    if (fullName.isEmpty) {
      setState(() {
        _msg = t.tr(vi: 'Vui lòng nhập họ và tên.', en: 'Please enter your full name.');
        _msgOk = false;
      });
      return;
    }

    setState(() {
      _saving = true;
      _msg = null;
      _msgOk = true;
    });

    try {
      final alsoUploadAvatar = _pickedAvatar != null;
      if (_pickedAvatar != null) {
        await _api.uploadAvatar(user.userId, _pickedAvatar!.path);
      }
      await _api.updateProfile(
        user.userId,
        fullName: fullName,
        phone: _phoneCtl.text.trim().isEmpty ? null : _phoneCtl.text.trim(),
        address: _addressCtl.text.trim().isEmpty ? null : _addressCtl.text.trim(),
      );

      final fresh = await _api.getAccountUser(user.userId);
      await AuthState.signIn(
        user: fresh,
        jwt: AuthState.token.value ?? '',
        expiresInSeconds: AuthState.tokenExpiresAt.value == null
            ? 3600
            : (AuthState.tokenExpiresAt.value!.difference(DateTime.now()).inSeconds).clamp(60, 3600 * 24 * 30).toInt(),
        remember: true,
      );

      if (!mounted) return;
      setState(() {
        _pickedAvatar = null;
        _msg = alsoUploadAvatar ? t.tr(vi: 'Đã lưu thông tin và avatar.', en: 'Saved profile and avatar.') : t.tr(vi: 'Đã lưu thông tin tài khoản.', en: 'Saved profile info.');
        _msgOk = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _msg = '$e'.replaceFirst('Exception: ', '').trim();
        _msgOk = false;
      });
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = AppLocalizations.of(context);
    final user = AuthState.currentUser.value;
    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: Text(t.tr(vi: 'Hồ sơ', en: 'Profile'))),
        body: Center(child: Text(t.tr(vi: 'Bạn chưa đăng nhập.', en: 'You are not signed in.'))),
      );
    }

    final avatarUrl = ApiConfig.resolveMediaUrl(user.avatarUrl);
    final previewFile = _pickedAvatar == null ? null : File(_pickedAvatar!.path);
    final initials = user.fullName.trim().isEmpty ? 'U' : user.fullName.trim().characters.first.toUpperCase();

    return Scaffold(
      appBar: AppBar(title: Text(t.tr(vi: 'Hồ sơ', en: 'Profile'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              color: theme.colorScheme.surface,
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
                InkWell(
                  onTap: _pickAvatar,
                  borderRadius: BorderRadius.circular(999),
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFF62BF39), width: 2),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: previewFile != null
                        ? Image.file(previewFile, fit: BoxFit.cover)
                        : (avatarUrl.isNotEmpty
                            ? CachedNetworkImage(imageUrl: avatarUrl, fit: BoxFit.cover)
                            : Center(child: Text(initials, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 22)))),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(user.fullName, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
                      const SizedBox(height: 4),
                      Text(user.email, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: _pickAvatar,
                        icon: const Icon(Icons.image_outlined, size: 18),
                        label: Text(_pickedAvatar == null ? t.tr(vi: 'Chọn ảnh', en: 'Choose photo') : t.tr(vi: 'Đổi ảnh', en: 'Change photo')),
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          side: BorderSide(color: theme.colorScheme.outlineVariant),
                        ),
                      ),
                      Text(
                        t.tr(vi: 'JPG/PNG/WebP · tối đa 3MB', en: 'JPG/PNG/WebP · up to 3MB'),
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              color: theme.colorScheme.surface,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0F172A).withValues(alpha: 0.06),
                  blurRadius: 18,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(t.tr(vi: 'Thông tin liên hệ', en: 'Contact information'), style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
                const SizedBox(height: 10),
                if (_msg != null) _MsgBanner(text: _msg!, ok: _msgOk),
                if (_msg != null) const SizedBox(height: 12),
                LayoutBuilder(
                  builder: (context, c) {
                    final twoCols = c.maxWidth >= 520;
                    final gap = twoCols ? 12.0 : 0.0;
                    return Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _NiceField(
                                label: 'First Name',
                                hintText: 'First name',
                                controller: _firstNameCtl,
                                textInputAction: TextInputAction.next,
                              ),
                            ),
                            SizedBox(width: gap),
                            if (twoCols)
                              Expanded(
                                child: _NiceField(
                                  label: 'Last Name',
                                  hintText: 'Last name',
                                  controller: _lastNameCtl,
                                ),
                              ),
                          ],
                        ),
                        if (!twoCols) const SizedBox(height: 12),
                        if (!twoCols)
                          _NiceField(
                            label: 'Last Name',
                            hintText: 'Last name',
                            controller: _lastNameCtl,
                          ),
                        const SizedBox(height: 12),
                        _NiceField(
                          label: 'Email Address',
                          controller: _emailCtl,
                          enabled: false,
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _NiceField(
                                label: 'Phone Number',
                                hintText: 'Phone number',
                                controller: _phoneCtl,
                                keyboardType: TextInputType.phone,
                              ),
                            ),
                            SizedBox(width: gap),
                            if (twoCols)
                              Expanded(
                                child: _NiceField(
                                  label: 'Địa chỉ',
                                  hintText: 'Số nhà, đường, phường…',
                                  controller: _addressCtl,
                                ),
                              ),
                          ],
                        ),
                        if (!twoCols) const SizedBox(height: 12),
                        if (!twoCols)
                          _NiceField(
                            label: 'Địa chỉ',
                            hintText: 'Số nhà, đường, phường…',
                            controller: _addressCtl,
                          ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Cập nhật số điện thoại/địa chỉ để đặt hàng nhanh hơn.',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: theme.colorScheme.onSurfaceVariant, fontWeight: FontWeight.w700, height: 1.25),
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      height: 44,
                      child: ElevatedButton(
                        onPressed: _saving ? null : _save,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF62BF39),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          textStyle: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                        child: Text(_saving ? 'Đang lưu…' : 'Lưu'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
        ],
      ),
    );
  }
}

class _Input extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final IconData icon;
  final bool obscure;
  final TextInputType? keyboardType;
  const _Input({
    required this.label,
    required this.controller,
    required this.icon,
    this.obscure = false,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w900, color: theme.colorScheme.onSurfaceVariant, letterSpacing: 0.4)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          obscureText: obscure,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            prefixIcon: Icon(icon),
            filled: true,
            fillColor: theme.colorScheme.surfaceContainerHighest,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: theme.colorScheme.outlineVariant),
            ),
            disabledBorder: OutlineInputBorder(
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

class _NiceField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final bool enabled;
  final String? hintText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  const _NiceField({
    required this.label,
    required this.controller,
    this.enabled = true,
    this.hintText,
    this.keyboardType,
    this.textInputAction,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w900,
            color: theme.colorScheme.onSurfaceVariant,
            letterSpacing: 0.35,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          enabled: enabled,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          decoration: InputDecoration(
            hintText: hintText,
            filled: true,
            fillColor: theme.colorScheme.surfaceContainerHighest,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: theme.colorScheme.outlineVariant),
            ),
            disabledBorder: OutlineInputBorder(
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

class _MsgBanner extends StatelessWidget {
  final String text;
  final bool ok;
  const _MsgBanner({required this.text, required this.ok});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bg = ok ? const Color(0xFF62BF39).withValues(alpha: 0.10) : const Color(0xFFEF4444).withValues(alpha: 0.10);
    final fg = ok ? const Color(0xFF166534) : const Color(0xFFB91C1C);
    final icon = ok ? Icons.check_circle_outline : Icons.error_outline;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), color: bg),
      child: Row(
        children: [
          Icon(icon, color: fg),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodyMedium?.copyWith(color: fg, fontWeight: FontWeight.w800, height: 1.25),
            ),
          ),
        ],
      ),
    );
  }
}

