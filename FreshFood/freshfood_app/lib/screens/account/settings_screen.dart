import 'package:flutter/material.dart';
import 'package:freshfood_app/api/api_client.dart';
import 'package:freshfood_app/models/user_address.dart';
import 'package:freshfood_app/screens/account/auth/auth_login_screen.dart';
import 'package:freshfood_app/screens/legal/privacy_policy_screen.dart';
import 'package:freshfood_app/screens/legal/terms_of_service_screen.dart';
import 'package:freshfood_app/state/locale_state.dart';
import 'package:freshfood_app/state/auth_state.dart';
import 'package:freshfood_app/state/theme_state.dart';
import 'package:freshfood_app/l10n/app_localizations.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _api = ApiClient();
  bool _busyPwd = false;

  bool _addrLoading = false;
  bool _addrBusy = false;
  String? _addrMsg;
  List<UserAddress> _addrList = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadAddresses());
  }

  Future<void> _openChangePassword() async {
    final t = AppLocalizations.of(context);
    final user = AuthState.currentUser.value;
    if (user == null) {
      if (!mounted) return;
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AuthLoginScreen()));
      return;
    }
    final curCtl = TextEditingController();
    final newCtl = TextEditingController();
    final cfmCtl = TextEditingController();
    String? err;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      builder: (context) {
        final theme = Theme.of(context);
        return StatefulBuilder(
          builder: (context, setLocal) {
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 8,
                  bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(t.tr(vi: 'Đổi mật khẩu', en: 'Change password'), style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
                      const SizedBox(height: 12),
                      if (err != null)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            color: const Color(0xFFEF4444).withValues(alpha: 0.08),
                          ),
                          child:
                              Text(err!, style: theme.textTheme.bodyMedium?.copyWith(color: const Color(0xFFB91C1C), fontWeight: FontWeight.w800)),
                        ),
                      if (err != null) const SizedBox(height: 12),
                      _Input(label: t.tr(vi: 'Mật khẩu hiện tại', en: 'Current password'), controller: curCtl, icon: Icons.lock_outline, obscure: true),
                      const SizedBox(height: 12),
                      _Input(label: t.tr(vi: 'Mật khẩu mới', en: 'New password'), controller: newCtl, icon: Icons.key_outlined, obscure: true),
                      const SizedBox(height: 12),
                      _Input(label: t.tr(vi: 'Xác nhận mật khẩu mới', en: 'Confirm new password'), controller: cfmCtl, icon: Icons.key_outlined, obscure: true),
                      const SizedBox(height: 14),
                      SizedBox(
                        height: 46,
                        child: ElevatedButton(
                          onPressed: _busyPwd
                              ? null
                              : () async {
                                  setLocal(() => err = null);
                                  final cur = curCtl.text;
                                  final np = newCtl.text;
                                  final cp = cfmCtl.text;
                                  if (cur.trim().isEmpty || np.trim().isEmpty) {
                                    setLocal(() => err = t.tr(vi: 'Vui lòng nhập đầy đủ mật khẩu.', en: 'Please enter all password fields.'));
                                    return;
                                  }
                                  if (np.length < 6) {
                                    setLocal(() => err = t.tr(vi: 'Mật khẩu mới phải từ 6 ký tự.', en: 'New password must be at least 6 characters.'));
                                    return;
                                  }
                                  if (np != cp) {
                                    setLocal(() => err = t.tr(vi: 'Xác nhận mật khẩu không khớp.', en: 'Confirmation password does not match.'));
                                    return;
                                  }
                                  setState(() => _busyPwd = true);
                                  try {
                                    await _api.changePassword(user.userId, currentPassword: cur, newPassword: np);
                                    if (!context.mounted) return;
                                    Navigator.of(context).pop();
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text(t.tr(vi: 'Đổi mật khẩu thành công.', en: 'Password changed successfully.'))),
                                    );
                                  } catch (e) {
                                    setLocal(() => err = '$e'.replaceFirst('Exception: ', '').trim());
                                  } finally {
                                    if (mounted) setState(() => _busyPwd = false);
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF62BF39),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            textStyle: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                          child: Text(_busyPwd ? t.tr(vi: 'Đang lưu…', en: 'Saving…') : t.tr(vi: 'Lưu', en: 'Save')),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
    // Note: avoid disposing temporary controllers to prevent "used after disposed" during bottom-sheet animations.
  }

  Future<void> _loadAddresses() async {
    final user = AuthState.currentUser.value;
    if (user == null) return;
    setState(() {
      _addrLoading = true;
      _addrMsg = null;
    });
    try {
      final list = await _api.getUserAddresses(user.userId);
      if (!mounted) return;
      setState(() => _addrList = list);
    } catch (e) {
      if (!mounted) return;
      setState(() => _addrMsg = '$e'.replaceFirst('Exception: ', '').trim());
    } finally {
      if (mounted) setState(() => _addrLoading = false);
    }
  }

  Future<void> _openAddressEditor({UserAddress? existing}) async {
    final t = AppLocalizations.of(context);
    final user = AuthState.currentUser.value;
    if (user == null) {
      if (!mounted) return;
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AuthLoginScreen()));
      return;
    }

    final labelCtl = TextEditingController(text: existing?.label ?? '');
    final nameCtl = TextEditingController(text: existing?.recipientName ?? user.fullName);
    final phoneCtl = TextEditingController(text: existing?.phone ?? user.phone ?? '');
    final lineCtl = TextEditingController(text: existing?.addressLine ?? user.address ?? '');
    bool isDefault = existing?.isDefault ?? _addrList.isEmpty;
    String? err;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      builder: (context) {
        final theme = Theme.of(context);
        return StatefulBuilder(
          builder: (context, setLocal) {
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 8,
                  bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        existing == null ? t.tr(vi: 'Thêm địa chỉ', en: 'Add address') : t.tr(vi: 'Sửa địa chỉ', en: 'Edit address'),
                        style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 12),
                      if (err != null)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            color: const Color(0xFFEF4444).withValues(alpha: 0.08),
                          ),
                          child: Text(
                            err!,
                            style: theme.textTheme.bodyMedium?.copyWith(color: const Color(0xFFB91C1C), fontWeight: FontWeight.w800),
                          ),
                        ),
                      if (err != null) const SizedBox(height: 12),
                      _Input(label: t.tr(vi: 'Nhãn (tùy chọn)', en: 'Label (optional)'), controller: labelCtl, icon: Icons.bookmark_outline),
                      const SizedBox(height: 12),
                      _Input(label: t.tr(vi: 'Người nhận', en: 'Recipient'), controller: nameCtl, icon: Icons.person_outline),
                      const SizedBox(height: 12),
                      _Input(
                        label: t.tr(vi: 'Số điện thoại', en: 'Phone number'),
                        controller: phoneCtl,
                        icon: Icons.phone_outlined,
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: 12),
                      _Input(label: t.tr(vi: 'Địa chỉ chi tiết', en: 'Detailed address'), controller: lineCtl, icon: Icons.place_outlined),
                      const SizedBox(height: 10),
                      CheckboxListTile(
                        value: isDefault,
                        onChanged: (v) => setLocal(() => isDefault = v ?? false),
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        title: Text(t.tr(vi: 'Đặt làm địa chỉ mặc định', en: 'Set as default address'), style: const TextStyle(fontWeight: FontWeight.w800)),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 46,
                        child: ElevatedButton(
                          onPressed: _addrBusy
                              ? null
                              : () async {
                                  final name = nameCtl.text.trim();
                                  final line = lineCtl.text.trim();
                                  if (name.isEmpty || line.isEmpty) {
                                    setLocal(() => err = 'Vui lòng nhập người nhận và địa chỉ chi tiết.');
                                    return;
                                  }
                                  setState(() {
                                    _addrBusy = true;
                                    _addrMsg = null;
                                  });
                                  try {
                                    if (existing == null) {
                                      await _api.createUserAddress(
                                        user.userId,
                                        recipientName: name,
                                        phone: phoneCtl.text.trim().isEmpty ? null : phoneCtl.text.trim(),
                                        addressLine: line,
                                        label: labelCtl.text.trim().isEmpty ? null : labelCtl.text.trim(),
                                        isDefault: isDefault,
                                      );
                                    } else {
                                      await _api.updateUserAddress(
                                        existing.userAddressId,
                                        user.userId,
                                        recipientName: name,
                                        phone: phoneCtl.text.trim().isEmpty ? null : phoneCtl.text.trim(),
                                        addressLine: line,
                                        label: labelCtl.text.trim().isEmpty ? null : labelCtl.text.trim(),
                                        isDefault: isDefault,
                                      );
                                    }
                                    if (!context.mounted) return;
                                    Navigator.of(context).pop();
                                    await _loadAddresses();
                                  } catch (e) {
                                    setLocal(() => err = '$e'.replaceFirst('Exception: ', '').trim());
                                  } finally {
                                    if (mounted) setState(() => _addrBusy = false);
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF62BF39),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            textStyle: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                          child: Text(_addrBusy ? t.tr(vi: 'Đang lưu…', en: 'Saving…') : t.tr(vi: 'Lưu địa chỉ', en: 'Save address')),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 44,
                        child: OutlinedButton(
                          onPressed: _addrBusy ? null : () => Navigator.of(context).pop(),
                          style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                          child: Text(t.tr(vi: 'Hủy', en: 'Cancel'), style: const TextStyle(fontWeight: FontWeight.w900)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
    // Note: avoid disposing temporary controllers to prevent "used after disposed" during bottom-sheet animations.
  }

  Future<void> _deleteAddress(UserAddress a) async {
    final t = AppLocalizations.of(context);
    final user = AuthState.currentUser.value;
    if (user == null) {
      if (!mounted) return;
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AuthLoginScreen()));
      return;
    }
    final ok = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(t.tr(vi: 'Xóa địa chỉ?', en: 'Delete address?')),
            content: Text(t.tr(vi: 'Xóa "${(a.label ?? 'Địa chỉ').trim()}"?', en: 'Delete "${(a.label ?? 'Address').trim()}"?')),
            actions: [
              TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(t.tr(vi: 'Hủy', en: 'Cancel'))),
              TextButton(onPressed: () => Navigator.of(context).pop(true), child: Text(t.tr(vi: 'Xóa', en: 'Delete'))),
            ],
          ),
        ) ??
        false;
    if (!ok) return;

    setState(() {
      _addrBusy = true;
      _addrMsg = null;
    });
    try {
      await _api.deleteUserAddress(a.userAddressId, user.userId);
      await _loadAddresses();
    } catch (e) {
      if (!mounted) return;
      setState(() => _addrMsg = '$e'.replaceFirst('Exception: ', '').trim());
    } finally {
      if (mounted) setState(() => _addrBusy = false);
    }
  }

  Future<void> _setDefault(UserAddress a) async {
    final user = AuthState.currentUser.value;
    if (user == null) {
      if (!mounted) return;
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AuthLoginScreen()));
      return;
    }
    setState(() {
      _addrBusy = true;
      _addrMsg = null;
    });
    try {
      await _api.setDefaultUserAddress(a.userAddressId, user.userId);
      await _loadAddresses();
    } catch (e) {
      if (!mounted) return;
      setState(() => _addrMsg = '$e'.replaceFirst('Exception: ', '').trim());
    } finally {
      if (mounted) setState(() => _addrBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = AppLocalizations.of(context);
    final user = AuthState.currentUser.value;
    return Scaffold(
      appBar: AppBar(title: Text(t.settings)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(t.settings, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          ValueListenableBuilder<ThemeMode>(
            valueListenable: ThemeState.themeMode,
            builder: (context, mode, _) {
              final dark = mode == ThemeMode.dark;
              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  color: theme.colorScheme.surface,
                  border: Border.all(color: theme.colorScheme.outlineVariant),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        color: const Color(0xFF62BF39).withValues(alpha: 0.12),
                      ),
                      child: const Icon(Icons.dark_mode_outlined, color: Color(0xFF62BF39)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(t.darkMode, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
                          const SizedBox(height: 2),
                          Text(
                            dark ? t.on : t.off,
                            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: dark,
                      onChanged: (v) => ThemeState.setMode(v ? ThemeMode.dark : ThemeMode.light),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          ValueListenableBuilder<Locale>(
            valueListenable: LocaleState.locale,
            builder: (context, loc, _) {
              final code = loc.languageCode.toLowerCase();
              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  color: theme.colorScheme.surface,
                  border: Border.all(color: theme.colorScheme.outlineVariant),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        color: const Color(0xFF62BF39).withValues(alpha: 0.12),
                      ),
                      child: const Icon(Icons.language_outlined, color: Color(0xFF62BF39)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(t.language, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
                          const SizedBox(height: 2),
                          Text(
                            code == 'en' ? t.english : t.vietnamese,
                            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                    DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: code == 'en' ? 'en' : 'vi',
                        items: [
                          DropdownMenuItem(value: 'vi', child: Text(t.vietnamese)),
                          DropdownMenuItem(value: 'en', child: Text(t.english)),
                        ],
                        onChanged: (v) {
                          final next = (v ?? 'vi') == 'en' ? const Locale('en') : const Locale('vi');
                          LocaleState.set(next);
                        },
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 18),
          Text('Bảo mật', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              color: theme.colorScheme.surface,
              border: Border.all(color: theme.colorScheme.outlineVariant),
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    color: const Color(0xFF62BF39).withValues(alpha: 0.12),
                  ),
                  child: const Icon(Icons.lock_outline, color: Color(0xFF62BF39)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Đổi mật khẩu', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
                      const SizedBox(height: 2),
                      Text(
                        user == null ? 'Đăng nhập để đổi mật khẩu' : 'Cập nhật mật khẩu để tăng cường bảo mật',
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  height: 40,
                  child: OutlinedButton(
                    onPressed: _busyPwd ? null : _openChangePassword,
                    style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                    child: Text(t.tr(vi: 'Mở', en: 'Open'), style: const TextStyle(fontWeight: FontWeight.w900)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Text('Sổ địa chỉ giao hàng', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              color: theme.colorScheme.surface,
              border: Border.all(color: theme.colorScheme.outlineVariant),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        user == null ? 'Bạn chưa đăng nhập' : 'Quản lý địa chỉ',
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                      ),
                    ),
                    SizedBox(
                      height: 40,
                      width: 44,
                      child: IconButton(
                        onPressed: (user == null || _addrBusy || _addrLoading) ? null : () => _openAddressEditor(),
                        icon: const Icon(Icons.add_rounded),
                        style: IconButton.styleFrom(
                          backgroundColor: const Color(0xFF62BF39).withValues(alpha: 0.10),
                          foregroundColor: const Color(0xFF62BF39),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Lưu nhiều địa chỉ, đặt mặc định — khi thanh toán bạn có thể chọn nhanh địa chỉ đã lưu.',
                  style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant, height: 1.35),
                ),
                if (_addrMsg != null) const SizedBox(height: 10),
                if (_addrMsg != null) Text(_addrMsg!, style: theme.textTheme.bodySmall?.copyWith(color: const Color(0xFFB91C1C), fontWeight: FontWeight.w800)),
                const SizedBox(height: 12),
                if (user == null)
                  SizedBox(
                    height: 44,
                    child: FilledButton(
                      onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AuthLoginScreen())),
                      child: const Text('Đăng nhập'),
                    ),
                  )
                else if (_addrLoading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 10),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_addrList.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      t.tr(vi: 'Chưa có địa chỉ. Bấm + để thêm.', en: 'No addresses yet. Tap + to add one.'),
                      style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  )
                else
                  Column(
                    children: [
                      for (final a in _addrList) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            color: theme.colorScheme.surfaceContainerHighest,
                            border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      ((a.label ?? 'Địa chỉ').trim()).isEmpty
                                          ? t.tr(vi: 'Địa chỉ', en: 'Address')
                                          : (a.label ?? t.tr(vi: 'Địa chỉ', en: 'Address')).trim(),
                                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                                    ),
                                  ),
                                  if (a.isDefault)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(999),
                                        color: const Color(0xFF62BF39).withValues(alpha: 0.12),
                                      ),
                                      child: Text(
                                        t.tr(vi: 'Mặc định', en: 'Default'),
                                        style: const TextStyle(color: Color(0xFF62BF39), fontWeight: FontWeight.w900, fontSize: 12),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '${a.recipientName}${(a.phone ?? '').trim().isEmpty ? '' : ' · ${a.phone}'}',
                                style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant, fontWeight: FontWeight.w800),
                              ),
                              const SizedBox(height: 4),
                              Text(a.addressLine, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  if (!a.isDefault)
                                    OutlinedButton.icon(
                                      onPressed: _addrBusy ? null : () => _setDefault(a),
                                      icon: const Icon(Icons.star_outline, size: 18),
                                      label: Text(t.tr(vi: 'Mặc định', en: 'Default')),
                                      style: OutlinedButton.styleFrom(
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                        textStyle: const TextStyle(fontWeight: FontWeight.w900),
                                      ),
                                    ),
                                  OutlinedButton.icon(
                                    onPressed: _addrBusy ? null : () => _openAddressEditor(existing: a),
                                    icon: const Icon(Icons.edit_outlined, size: 18),
                                    label: Text(t.tr(vi: 'Sửa', en: 'Edit')),
                                    style: OutlinedButton.styleFrom(
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                      textStyle: const TextStyle(fontWeight: FontWeight.w900),
                                    ),
                                  ),
                                  OutlinedButton.icon(
                                    onPressed: _addrBusy ? null : () => _deleteAddress(a),
                                    icon: const Icon(Icons.delete_outline, size: 18),
                                    label: Text(t.tr(vi: 'Xóa', en: 'Delete')),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: const Color(0xFFB91C1C),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                      textStyle: const TextStyle(fontWeight: FontWeight.w900),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],
                    ],
                  ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Text(t.tr(vi: 'Pháp lý', en: 'Legal'), style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(14),
            // decoration: BoxDecoration(
            //   borderRadius: BorderRadius.circular(18),
            //   color: theme.colorScheme.surface,
            //   // border: Border.all(color: theme.colorScheme.outlineVariant),
            // ),
            child: Column(
              children: [
                _LegalItem(
                  icon: Icons.privacy_tip_outlined,
                  title: t.tr(vi: 'Chính sách bảo mật', en: 'Privacy policy'),
                  subtitle: t.tr(vi: 'Cam kết bảo vệ dữ liệu cá nhân.', en: 'How we protect your data.'),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen())),
                ),
                const SizedBox(height: 10),
                _LegalItem(
                  icon: Icons.article_outlined,
                  title: t.tr(vi: 'Điều khoản dịch vụ', en: 'Terms of service'),
                  subtitle: t.tr(vi: 'Quy định sử dụng dịch vụ FreshFood.', en: 'Rules for using FreshFood service.'),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TermsOfServiceScreen())),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LegalItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _LegalItem({required this.icon, required this.title, required this.subtitle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: theme.colorScheme.surfaceContainerHighest,
          border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6)),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: const Color(0xFF62BF39).withValues(alpha: 0.12),
              ),
              child: Icon(icon, color: const Color(0xFF62BF39)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: theme.colorScheme.onSurfaceVariant),
          ],
        ),
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
