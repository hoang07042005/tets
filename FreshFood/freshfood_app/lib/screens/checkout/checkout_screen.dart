import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/services.dart';
import 'package:freshfood_app/api/api_client.dart';
import 'package:freshfood_app/config/api_config.dart';
import 'package:freshfood_app/models/shipping_method.dart';
import 'package:freshfood_app/models/user_address.dart';
import 'package:freshfood_app/models/voucher.dart';
import 'package:freshfood_app/screens/account/auth/auth_forgot_password_screen.dart';
import 'package:freshfood_app/screens/account/auth/auth_login_screen.dart';
import 'package:freshfood_app/screens/account/auth/auth_register_screen.dart';
import 'package:freshfood_app/state/auth_state.dart';
import 'package:freshfood_app/state/cart_state.dart';
import 'package:freshfood_app/ui/formatters.dart';
import 'package:url_launcher/url_launcher.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  static const _moneyColor = Color(0xFFE67E22);
  static const _primary = Color(0xFF62BF39);
  final _api = ApiClient();

  final _fullNameCtl = TextEditingController();
  final _emailCtl = TextEditingController();
  final _phoneCtl = TextEditingController();
  final _addressCtl = TextEditingController();
  final _noteCtl = TextEditingController();

  String _payment = 'COD';
  bool _loading = false;
  String? _err;
  bool _placing = false;
  String? _checkoutIdempotencyKey;

  List<ShippingMethod> _shippingMethods = const [];
  int? _shippingMethodId;

  List<UserAddress> _savedAddresses = const [];
  String _addressSource = 'custom'; // saved | custom
  int? _selectedAddressId;

  final _voucherCtl = TextEditingController();
  ValidateVoucherResult? _voucherApplied;
  String? _voucherErr;
  bool _voucherApplying = false;
  List<Voucher> _activeVouchers = const [];

  @override
  void initState() {
    super.initState();
    _prefillFromUser();
    Future<void>.delayed(Duration.zero, _load);
  }

  void _prefillFromUser() {
    final u = AuthState.currentUser.value;
    _fullNameCtl.text = (u?.fullName ?? '').trim();
    _emailCtl.text = (u?.email ?? '').trim();
    _phoneCtl.text = (u?.phone ?? '').trim();
    _addressCtl.text = (u?.address ?? '').trim();
  }

  Future<void> _load() async {
    final user = AuthState.currentUser.value;
    setState(() {
      _loading = true;
      _err = null;
    });
    try {
      final results = await Future.wait([
        _api.getShippingMethods(),
        if (user != null) _api.getUserAddresses(user.userId) else Future.value(const <UserAddress>[]),
        if (user != null) _api.getActiveVouchers(userId: user.userId) else Future.value(const <Voucher>[]),
      ]);
      if (!mounted) return;

      final sms = results[0] as List<ShippingMethod>;
      final addrs = results[1] as List<UserAddress>;
      final vouchers = results[2] as List<Voucher>;

      _shippingMethods = sms;
      _shippingMethodId = (_shippingMethodId ?? (sms.isNotEmpty ? sms.first.methodId : null));

      if (user != null) {
        _savedAddresses = addrs;
        _activeVouchers = vouchers;
        if (addrs.isNotEmpty) {
          final def = addrs.firstWhere((a) => a.isDefault, orElse: () => addrs.first);
          _addressSource = 'saved';
          _selectedAddressId = def.userAddressId;
          _fullNameCtl.text = def.recipientName;
          _emailCtl.text = (user.email).trim();
          _phoneCtl.text = (def.phone ?? user.phone ?? '').trim();
          _addressCtl.text = def.addressLine;
        } else {
          _addressSource = 'custom';
          _selectedAddressId = null;
          _prefillFromUser();
        }
      } else {
        _savedAddresses = const [];
        _activeVouchers = const [];
        _addressSource = 'custom';
        _selectedAddressId = null;
      }
    } catch (e) {
      if (!mounted) return;
      _err = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _fullNameCtl.dispose();
    _emailCtl.dispose();
    _phoneCtl.dispose();
    _addressCtl.dispose();
    _noteCtl.dispose();
    _voucherCtl.dispose();
    super.dispose();
  }

  ShippingMethod? get _selectedShipping {
    final id = _shippingMethodId;
    if (id == null) return null;
    for (final sm in _shippingMethods) {
      if (sm.methodId == id) return sm;
    }
    return null;
  }

  bool get _isFreeShipEligible => _subtotal >= 200000;

  num get _shippingCost {
    if (_isFreeShipEligible) return 0;
    return _selectedShipping?.baseCost ?? 0;
  }

  num get _subtotal => CartState.subtotal();

  int get _tax {
    final base = (_voucherApplied?.subtotalAfterDiscount ?? _subtotal);
    return (base * 0.015).round();
  }

  num get _grandTotal {
    if (_voucherApplied != null) {
      // backend already includes shipping in grandTotal
      return _voucherApplied!.grandTotal;
    }
    return _subtotal + _shippingCost + _tax;
  }

  Future<void> _applyVoucher() async {
    final user = AuthState.currentUser.value;
    if (user == null) {
      setState(() => _voucherErr = 'Đăng nhập để áp dụng voucher.');
      // Offer quick navigation to auth screens, similar to web behavior.
      // ignore: discarded_futures
      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Cần đăng nhập', style: TextStyle(fontWeight: FontWeight.w900)),
          content: const Text('Bạn cần đăng nhập để áp dụng voucher.', style: TextStyle(fontWeight: FontWeight.w700)),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Để sau')),
            OutlinedButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AuthLoginScreen()));
              },
              child: const Text('Đăng nhập'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AuthRegisterScreen()));
              },
              child: const Text('Đăng ký'),
            ),
          ],
        ),
      );
      return;
    }
    final code = _voucherCtl.text.trim();
    if (code.isEmpty) {
      setState(() => _voucherErr = 'Vui lòng nhập mã giảm giá.');
      return;
    }
    try {
      setState(() {
        _voucherErr = null;
        _voucherApplied = null;
        _voucherApplying = true;
      });
      final res = await _api.validateVoucher(userId: user.userId, code: code, subtotal: _subtotal, shipping: _shippingCost);
      if (!mounted) return;
      setState(() => _voucherApplied = res);
    } catch (e) {
      if (!mounted) return;
      setState(() => _voucherErr = e.toString());
    } finally {
      if (mounted) setState(() => _voucherApplying = false);
    }
  }

  void _removeVoucher() {
    setState(() {
      _voucherApplied = null;
      _voucherErr = null;
      _voucherCtl.clear();
    });
  }

  Future<void> _placeOrder() async {
    if (_placing) return;
    final lines = CartState.lines.value;
    if (lines.isEmpty) return;

    final u = AuthState.currentUser.value;
    final isAuthed = u != null && u.userId > 0;
    final pay = _payment.trim().toUpperCase();

    // Online payment is allowed for guest too (public payment URL endpoints use orderCode).

    final fullName = _fullNameCtl.text.trim();
    final email = _emailCtl.text.trim();
    final phone = _phoneCtl.text.trim();
    final address = _addressCtl.text.trim();

    final needManual = !isAuthed || _addressSource == 'custom' || _savedAddresses.isEmpty;
    if (needManual) {
      if (fullName.isEmpty || email.isEmpty || phone.isEmpty || address.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vui lòng điền đầy đủ thông tin nhận hàng.')));
        return;
      }
    } else {
      if ((_selectedAddressId ?? 0) <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vui lòng chọn một địa chỉ đã lưu.')));
        return;
      }
    }

    final shippingText = needManual ? '$fullName - $phone - $email - $address' : '';
    final items = lines
        .map((x) => OrderItemDraft(productId: x.productId, quantity: x.quantity))
        .where((x) => x.productId > 0 && x.quantity > 0)
        .toList(growable: false);

    try {
      setState(() {
        _placing = true;
        _err = null;
      });

      _checkoutIdempotencyKey ??= '${DateTime.now().microsecondsSinceEpoch}-${lines.length}-${u?.userId ?? 0}';

      final res = await _api.createOrder(
        userId: isAuthed ? u.userId : null,
        guestCheckout: isAuthed ? null : GuestCheckoutDraft(fullName: fullName, email: email, phone: phone),
        shippingAddress: shippingText,
        shippingAddressId: (!needManual && isAuthed) ? _selectedAddressId : null,
        shippingMethodId: _shippingMethodId,
        paymentMethod: pay,
        voucherCode: (_voucherApplied?.code ?? _voucherCtl.text.trim()).trim().isEmpty ? null : (_voucherApplied?.code ?? _voucherCtl.text.trim()),
        items: items,
        idempotencyKey: _checkoutIdempotencyKey,
      );

      if (!mounted) return;

      if (pay == 'COD') {
        _checkoutIdempotencyKey = null;
        CartState.clear();
        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Đặt hàng thành công'),
            content: Text(
              isAuthed
                  ? (res.orderCode == null || res.orderCode!.trim().isEmpty ? 'Đơn hàng của bạn đã được tạo.' : 'Mã đơn: ${res.orderCode}')
                  : 'Đơn hàng của bạn đã được tạo.\n\nHệ thống sẽ tạo tài khoản gắn với email bạn vừa nhập và gửi email có nút "Tạo mật khẩu" (link + mã riêng, hiệu lực 48 giờ) để kích hoạt tài khoản. Đây không phải luồng "Quên mật khẩu".',
            ),
            actions: [
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.of(this.context).pop();
                },
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF62BF39), foregroundColor: Colors.white),
                child: const Text('OK'),
              ),
            ],
          ),
        );
        return;
      }

      // Online payment: create payment URL then open gateway.
      final orderId = res.orderId;
      final orderCode = (res.orderCode ?? '').trim();
      String url;
      if (pay == 'VNPAY') {
        url = await _api.createVnPayPaymentUrl(orderId: orderId, orderCode: orderCode);
      } else if (pay == 'MOMO') {
        url = await _api.createMomoPaymentUrl(orderId: orderId, orderCode: orderCode);
      } else {
        url = '';
      }

      if (!mounted) return;

      if (url.trim().isEmpty) {
        throw Exception('Không tạo được link thanh toán.');
      }

      final uri = Uri.tryParse(url);
      if (uri == null) {
        await Clipboard.setData(ClipboardData(text: url));
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Link thanh toán không hợp lệ. Đã copy vào clipboard.')));
        return;
      }

      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok) {
        await Clipboard.setData(ClipboardData(text: url));
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Không mở được trang thanh toán. Đã copy link.')));
      } else {
        _checkoutIdempotencyKey = null;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đang mở cổng thanh toán…')));
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _err = e.toString());
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_err!)));
    } finally {
      if (mounted) setState(() => _placing = false);
    }
  }

  void _setAddressSource(String v) {
    final user = AuthState.currentUser.value;
    setState(() {
      _addressSource = v;
      _voucherApplied = null; // totals may change later in real flow
    });
    if (v == 'custom') {
      if (user != null) _prefillFromUser();
    } else {
      final sel = _savedAddresses.where((a) => a.userAddressId == _selectedAddressId).toList();
      final addr = sel.isNotEmpty ? sel.first : (_savedAddresses.isNotEmpty ? _savedAddresses.first : null);
      if (addr != null) {
        setState(() => _selectedAddressId = addr.userAddressId);
        _fullNameCtl.text = addr.recipientName;
        _emailCtl.text = (user?.email ?? '').trim();
        _phoneCtl.text = (addr.phone ?? user?.phone ?? '').trim();
        _addressCtl.text = addr.addressLine;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = AuthState.currentUser.value;
    final lines = CartState.lines.value;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Checkout'),
        actions: [
          IconButton(onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh), tooltip: 'Tải lại'),
          const SizedBox(width: 6),
        ],
      ),
      body: lines.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.shopping_cart_outlined, size: 56, color: theme.colorScheme.outline),
                    const SizedBox(height: 12),
                    Text('Giỏ hàng trống', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
                    const SizedBox(height: 6),
                    Text('Hãy thêm sản phẩm trước khi checkout.', style: theme.textTheme.bodyMedium?.copyWith(color: const Color(0xFF64748B))),
                  ],
                ),
              ),
            )
          : LayoutBuilder(
              builder: (context, c) {
                final wide = c.maxWidth >= 900;
                final gap = wide ? 16.0 : 14.0;
                final left = _CheckoutLeft(
                  theme: theme,
                  user: user,
                  loading: _loading,
                  err: _err,
                  freeShipEligible: _isFreeShipEligible,
                  addressSource: _addressSource,
                  savedAddresses: _savedAddresses,
                  selectedAddressId: _selectedAddressId,
                  onAddressSourceChanged: _setAddressSource,
                  onSelectAddress: (id) {
                    final addr = _savedAddresses.firstWhere((a) => a.userAddressId == id);
                    setState(() => _selectedAddressId = id);
                    _fullNameCtl.text = addr.recipientName;
                    _emailCtl.text = (user?.email ?? '').trim();
                    _phoneCtl.text = (addr.phone ?? user?.phone ?? '').trim();
                    _addressCtl.text = addr.addressLine;
                  },
                  fullNameCtl: _fullNameCtl,
                  emailCtl: _emailCtl,
                  phoneCtl: _phoneCtl,
                  addressCtl: _addressCtl,
                  noteCtl: _noteCtl,
                  shippingMethods: _shippingMethods,
                  shippingMethodId: _shippingMethodId,
                  onSelectShipping: (id) => setState(() {
                    _shippingMethodId = id;
                    _voucherApplied = null;
                  }),
                  payment: _payment,
                  onPaymentChanged: (v) => setState(() => _payment = v),
                );

                final right = _CheckoutSummary(
                  theme: theme,
                  lines: lines,
                  shippingLabel: _selectedShipping == null
                      ? '—'
                      : '${_selectedShipping!.methodName}${_selectedShipping!.estimatedDays == null ? '' : ' · ${_selectedShipping!.estimatedDays} ngày'}',
                  shippingCost: _shippingCost,
                  freeShipEligible: _isFreeShipEligible,
                  subtotal: _subtotal,
                  tax: _voucherApplied?.taxAfterDiscount ?? _tax,
                  voucherApplied: _voucherApplied,
                  voucherCtl: _voucherCtl,
                  voucherErr: _voucherErr,
                  onApplyVoucher: _applyVoucher,
                  onRemoveVoucher: _removeVoucher,
                  voucherApplying: _voucherApplying,
                  activeVouchers: _activeVouchers,
                  isAuthed: user != null,
                  grandTotal: _grandTotal,
                  placing: _placing,
                  onPlaceOrder: _placeOrder,
                );

                if (!wide) {
                  return SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        left,
                        SizedBox(height: gap),
                        right,
                      ],
                    ),
                  );
                }

                return SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 7, child: left),
                      SizedBox(width: gap),
                      Expanded(flex: 5, child: right),
                    ],
                  ),
                );
              },
            ),
    );
  }
}

class _Field extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final TextInputType? keyboardType;
  final int minLines;
  final int maxLines;
  final bool enabled;
  const _Field({
    required this.label,
    required this.controller,
    this.keyboardType,
    this.minLines = 1,
    this.maxLines = 1,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w900, color: theme.colorScheme.onSurfaceVariant)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          enabled: enabled,
          keyboardType: keyboardType,
          minLines: minLines,
          maxLines: maxLines,
          decoration: InputDecoration(
            filled: true,
            fillColor: theme.colorScheme.surfaceContainerHighest,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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

class _PayOption extends StatelessWidget {
  final String value;
  final String groupValue;
  final String title;
  final ValueChanged<String> onChanged;
  const _PayOption({required this.value, required this.groupValue, required this.title, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return RadioListTile<String>(
      value: value,
      groupValue: groupValue,
      onChanged: (v) => onChanged(v ?? value),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
      dense: true,
      contentPadding: EdgeInsets.zero,
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  const _SummaryRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(child: Text(label, style: theme.textTheme.bodyMedium?.copyWith(color: const Color(0xFF64748B), fontWeight: FontWeight.w700))),
        Text(value, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w900, color: const Color(0xFFE67E22))),
      ],
    );
  }
}

class _CheckoutLeft extends StatelessWidget {
  final ThemeData theme;
  final AuthUser? user;
  final bool loading;
  final String? err;
  final bool freeShipEligible;

  final String addressSource;
  final List<UserAddress> savedAddresses;
  final int? selectedAddressId;
  final ValueChanged<String> onAddressSourceChanged;
  final ValueChanged<int> onSelectAddress;

  final TextEditingController fullNameCtl;
  final TextEditingController emailCtl;
  final TextEditingController phoneCtl;
  final TextEditingController addressCtl;
  final TextEditingController noteCtl;

  final List<ShippingMethod> shippingMethods;
  final int? shippingMethodId;
  final ValueChanged<int> onSelectShipping;

  final String payment;
  final ValueChanged<String> onPaymentChanged;

  const _CheckoutLeft({
    required this.theme,
    required this.user,
    required this.loading,
    required this.err,
    required this.freeShipEligible,
    required this.addressSource,
    required this.savedAddresses,
    required this.selectedAddressId,
    required this.onAddressSourceChanged,
    required this.onSelectAddress,
    required this.fullNameCtl,
    required this.emailCtl,
    required this.phoneCtl,
    required this.addressCtl,
    required this.noteCtl,
    required this.shippingMethods,
    required this.shippingMethodId,
    required this.onSelectShipping,
    required this.payment,
    required this.onPaymentChanged,
  });

  Widget _card({required String title, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 18, offset: const Offset(0, 12))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasSaved = user != null && savedAddresses.isNotEmpty;
    final disableManual = hasSaved && addressSource == 'saved';
    final isGuest = user == null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (err != null) ...[
          Text(err!, style: theme.textTheme.bodyMedium?.copyWith(color: const Color(0xFFB91C1C), fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
        ],
        _card(
          title: 'Thông tin nhận hàng',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (isGuest) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    color: const Color(0xFF62BF39).withValues(alpha: 0.10),
                    border: Border.all(color: const Color(0xFF62BF39).withValues(alpha: 0.28)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Bạn đang đặt hàng với tư cách khách', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900)),
                      const SizedBox(height: 6),
                      Text(
                        'Sau khi đặt hàng thành công, hệ thống sẽ tạo tài khoản gắn với email bạn nhập và gửi email có nút "Tạo mật khẩu" (link + mã riêng, hiệu lực 48 giờ) — đây là bước kích hoạt lần đầu, không phải "Quên mật khẩu".',
                        style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant, height: 1.35),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 10,
                        runSpacing: 6,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ForgotPasswordScreen())),
                            style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6)),
                            child: const Text('Quên mật khẩu', style: TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF62BF39))),
                          ),
                          TextButton(
                            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AuthRegisterScreen())),
                            style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6)),
                            child: const Text('Đăng ký', style: TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF62BF39))),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
              if (hasSaved) ...[
                Container(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.9)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.location_on_outlined, size: 18),
                          const SizedBox(width: 6),
                          Text('Địa chỉ giao hàng', style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w900)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      RadioListTile<String>(
                        value: 'saved',
                        groupValue: addressSource,
                        onChanged: (_) => onAddressSourceChanged('saved'),
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact,
                        title: const Text('Dùng địa chỉ đã lưu', style: TextStyle(fontWeight: FontWeight.w800)),
                      ),
                      if (addressSource == 'saved') ...[
                        Padding(
                          padding: const EdgeInsets.only(left: 26, top: 2, bottom: 2),
                          child: Column(
                            children: [
                              for (final a in savedAddresses) ...[
                                _SavedAddressTile(
                                  addr: a,
                                  selected: a.userAddressId == selectedAddressId,
                                  onTap: () => onSelectAddress(a.userAddressId),
                                  compact: true,
                                ),
                                const SizedBox(height: 8),
                              ],
                            ],
                          ),
                        ),
                      ],
                      RadioListTile<String>(
                        value: 'custom',
                        groupValue: addressSource,
                        onChanged: (_) => onAddressSourceChanged('custom'),
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact,
                        title: const Text('Nhập địa chỉ khác (một lần)', style: TextStyle(fontWeight: FontWeight.w800)),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Quản lý sổ địa chỉ tại Cài đặt.',
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
              _Field(label: 'Họ và tên', controller: fullNameCtl),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: _Field(label: 'Email', controller: emailCtl, keyboardType: TextInputType.emailAddress, enabled: !disableManual)),
                  const SizedBox(width: 10),
                  Expanded(child: _Field(label: 'Số điện thoại', controller: phoneCtl, keyboardType: TextInputType.phone, enabled: !disableManual)),
                ],
              ),
              const SizedBox(height: 10),
              _Field(label: 'Địa chỉ', controller: addressCtl, minLines: 2, maxLines: 3, enabled: !disableManual),
              const SizedBox(height: 10),
              _Field(label: 'Ghi chú (tùy chọn)', controller: noteCtl, minLines: 2, maxLines: 4),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _card(
          title: 'Phương thức giao hàng',
          child: loading
              ? const Center(child: Padding(padding: EdgeInsets.symmetric(vertical: 10), child: CircularProgressIndicator()))
              : (shippingMethods.isEmpty
                  ? Text('Chưa có phương thức giao hàng.', style: theme.textTheme.bodyMedium?.copyWith(color: const Color(0xFF64748B)))
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Phương thức vận chuyển',
                          style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w900, color: const Color(0xFF64748B)),
                        ),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<int>(
                          value: shippingMethodId,
                          isExpanded: true,
                          items: shippingMethods
                              .map(
                                (sm) => DropdownMenuItem<int>(
                                  value: sm.methodId,
                                  child: Text(
                                    '${sm.methodName} · ${freeShipEligible ? 'Freeship' : (sm.baseCost <= 0 ? '—' : Formatters.vnd(sm.baseCost))}${sm.estimatedDays == null ? '' : ' · ${sm.estimatedDays} ngày'}',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              )
                              .toList(growable: false),
                          selectedItemBuilder: (context) {
                            return shippingMethods
                                .map(
                                  (sm) => Align(
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      '${sm.methodName} · ${freeShipEligible ? 'Freeship' : (sm.baseCost <= 0 ? '—' : Formatters.vnd(sm.baseCost))}${sm.estimatedDays == null ? '' : ' · ${sm.estimatedDays} ngày'}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                )
                                .toList(growable: false);
                          },
                          onChanged: (v) {
                            final id = v ?? (shippingMethods.isNotEmpty ? shippingMethods.first.methodId : null);
                            if (id != null) onSelectShipping(id);
                          },
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: theme.colorScheme.surfaceContainerHighest,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.9)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFF62BF39), width: 1.6),
                            ),
                          ),
                          icon: const Icon(Icons.keyboard_arrow_down_rounded),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Freeship áp dụng khi tạm tính ≥ 200.000đ (trước VAT).',
                          style: theme.textTheme.bodySmall?.copyWith(color: const Color(0xFF64748B), fontWeight: FontWeight.w700),
                        ),
                      ],
                    )),
        ),
        const SizedBox(height: 14),
        _card(
          title: 'Phương thức thanh toán',
          child: LayoutBuilder(
            builder: (context, c) {
              final w = c.maxWidth;
              final itemW = w >= 420 ? (w - 12 * 2) / 3 : (w - 12) / 2;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: itemW,
                    child: _PayLogoOption(
                      method: 'COD',
                      selected: payment == 'COD',
                      onTap: () => onPaymentChanged('COD'),
                    ),
                  ),
                  SizedBox(
                    width: itemW,
                    child: _PayLogoOption(
                      method: 'VNPAY',
                      selected: payment == 'VNPAY',
                      onTap: () => onPaymentChanged('VNPAY'),
                    ),
                  ),
                  SizedBox(
                    width: itemW,
                    child: _PayLogoOption(
                      method: 'MOMO',
                      selected: payment == 'MOMO',
                      onTap: () => onPaymentChanged('MOMO'),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _CheckoutSummary extends StatelessWidget {
  final ThemeData theme;
  final List<CartLine> lines;
  final String shippingLabel;
  final num shippingCost;
  final bool freeShipEligible;
  final num subtotal;
  final num tax;
  final ValidateVoucherResult? voucherApplied;
  final TextEditingController voucherCtl;
  final String? voucherErr;
  final VoidCallback onApplyVoucher;
  final VoidCallback onRemoveVoucher;
  final bool voucherApplying;
  final List<Voucher> activeVouchers;
  final bool isAuthed;
  final num grandTotal;
  final VoidCallback onPlaceOrder;
  final bool placing;

  const _CheckoutSummary({
    required this.theme,
    required this.lines,
    required this.shippingLabel,
    required this.shippingCost,
    required this.freeShipEligible,
    required this.subtotal,
    required this.tax,
    required this.voucherApplied,
    required this.voucherCtl,
    required this.voucherErr,
    required this.onApplyVoucher,
    required this.onRemoveVoucher,
    required this.voucherApplying,
    required this.activeVouchers,
    required this.isAuthed,
    required this.grandTotal,
    required this.onPlaceOrder,
    required this.placing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 18, offset: const Offset(0, 12))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text('Tóm tắt đơn hàng', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(999), color: theme.colorScheme.surfaceContainerHighest),
                child: Text('${lines.length}', style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w900)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 260),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: lines.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) => _SummaryLine(line: lines[i]),
            ),
          ),
          const SizedBox(height: 12),
          _SumRow(label: 'Tạm tính', value: Formatters.vnd(subtotal)),
          const SizedBox(height: 6),
          _SumRow(
            label: 'Giao hàng',
            value: freeShipEligible ? 'Miễn phí' : (shippingCost <= 0 ? '—' : Formatters.vnd(shippingCost)),
            hint: shippingLabel,
          ),
          const SizedBox(height: 6),
          if (voucherApplied != null) ...[
            _SumRow(label: 'Giảm giá (${voucherApplied!.code})', value: '-${Formatters.vnd(voucherApplied!.discountAmount)}'),
            const SizedBox(height: 6),
          ],
          _SumRow(label: 'Thuế (ước tính)', value: Formatters.vnd(tax)),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: Text('Tổng cộng', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900))),
              Text(Formatters.vnd(grandTotal), style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900, color: _CheckoutScreenState._moneyColor)),
            ],
          ),
          const SizedBox(height: 12),
          Text('Voucher', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: voucherCtl,
                  decoration: InputDecoration(
                    hintText: 'Nhập mã giảm giá…',
                    filled: true,
                    fillColor: theme.colorScheme.surfaceContainerHighest,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: theme.colorScheme.outlineVariant),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: _CheckoutScreenState._primary, width: 1.6),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                height: 46,
                child: ElevatedButton(
                  onPressed: (voucherApplying || !isAuthed) ? null : onApplyVoucher,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _CheckoutScreenState._primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    textStyle: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  child: voucherApplying
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Áp dụng'),
                ),
              ),
            ],
          ),
          if (!isAuthed) ...[
            const SizedBox(height: 6),
            Text(
              'Bạn cần đăng nhập để áp dụng voucher.',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant, fontWeight: FontWeight.w700),
            ),
          ],
          if (activeVouchers.isNotEmpty) ...[
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final v in activeVouchers.take(12)) ...[
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ActionChip(
                        label: Text(v.code, style: const TextStyle(fontWeight: FontWeight.w900)),
                        onPressed: () {
                          voucherCtl.text = v.code;
                          onApplyVoucher();
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
          if (voucherErr != null) ...[
            const SizedBox(height: 8),
            Text(voucherErr!, style: theme.textTheme.bodyMedium?.copyWith(color: const Color(0xFFB91C1C), fontWeight: FontWeight.w800)),
          ],
          if (voucherApplied != null) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: onRemoveVoucher,
                icon: const Icon(Icons.close_rounded, size: 18),
                label: const Text('Gỡ voucher', style: TextStyle(fontWeight: FontWeight.w900)),
              ),
            ),
          ],
          const SizedBox(height: 14),
          SizedBox(
            height: 50,
            child: ElevatedButton(
              onPressed: placing ? null : onPlaceOrder,
              style: ElevatedButton.styleFrom(
                backgroundColor: _CheckoutScreenState._primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                textStyle: const TextStyle(fontWeight: FontWeight.w900),
              ),
              child: Text(placing ? 'Đang đặt hàng…' : 'Đặt hàng'),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryLine extends StatelessWidget {
  final CartLine line;
  const _SummaryLine({required this.line});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final img = ApiConfig.resolveMediaUrl(line.imageUrl);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            width: 44,
            height: 44,
            child: img.isEmpty ? Container(color: theme.colorScheme.surfaceContainerHighest) : CachedNetworkImage(imageUrl: img, fit: BoxFit.cover),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(line.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w900)),
              const SizedBox(height: 2),
              Text('x${line.quantity}', style: theme.textTheme.bodySmall?.copyWith(color: const Color(0xFF64748B), fontWeight: FontWeight.w800)),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Text(
          Formatters.vnd(line.sellingPrice * line.quantity),
          style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w900, color: _CheckoutScreenState._moneyColor),
        ),
      ],
    );
  }
}

class _SumRow extends StatelessWidget {
  final String label;
  final String value;
  final String? hint;
  const _SumRow({required this.label, required this.value, this.hint});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: theme.textTheme.bodyMedium?.copyWith(color: const Color(0xFF64748B), fontWeight: FontWeight.w700)),
              if (hint != null && hint!.trim().isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(hint!, style: theme.textTheme.bodySmall?.copyWith(color: const Color(0xFF94A3B8), fontWeight: FontWeight.w700)),
              ],
            ],
          ),
        ),
        const SizedBox(width: 10),
        Text(value, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w900, color: _CheckoutScreenState._moneyColor)),
      ],
    );
  }
}

class _SavedAddressTile extends StatelessWidget {
  final UserAddress addr;
  final bool selected;
  final VoidCallback onTap;
  final bool compact;
  const _SavedAddressTile({required this.addr, required this.selected, required this.onTap, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = (addr.label ?? 'Địa chỉ').trim().isEmpty ? 'Địa chỉ' : (addr.label ?? 'Địa chỉ').trim();
    final phone = (addr.phone ?? '').trim();
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(compact ? 10 : 14),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: compact ? 10 : 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(compact ? 10 : 14),
          color: selected ? const Color(0xFF62BF39).withValues(alpha: 0.08) : theme.colorScheme.surfaceContainerHighest,
          border: Border.all(color: selected ? const Color(0xFF62BF39) : theme.colorScheme.outlineVariant),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(selected ? Icons.radio_button_checked : Icons.radio_button_off, color: selected ? const Color(0xFF62BF39) : const Color(0xFF94A3B8)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w900),
                        ),
                      ),
                      if (addr.isDefault)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(borderRadius: BorderRadius.circular(999), color: theme.colorScheme.surfaceContainerHighest),
                          child: Text('Mặc định',
                              style: TextStyle(fontWeight: FontWeight.w900, color: theme.colorScheme.onSurfaceVariant, fontSize: 12)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${addr.recipientName}${phone.isEmpty ? '' : ' · $phone'} — ${addr.addressLine}',
                    maxLines: compact ? 2 : 3,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant, fontWeight: FontWeight.w700),
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

class _PayLogoOption extends StatelessWidget {
  final String method; // COD | VNPAY | MOMO
  final bool selected;
  final VoidCallback onTap;
  const _PayLogoOption({required this.method, required this.selected, required this.onTap});

  String? get _asset {
    return switch (method) {
      'COD' => 'assets/payments/logo-COD.png',
      'VNPAY' => 'assets/payments/vnpay-logo.png',
      'MOMO' => 'assets/payments/logo-momo.png',
      _ => null,
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final asset = _asset;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        height: 90,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: theme.colorScheme.surface,
          border: Border.all(
            color: selected ? const Color(0xFF62BF39) : theme.colorScheme.outlineVariant,
            width: selected ? 1.8 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? const Color(0xFF62BF39) : const Color(0xFFCBD5E1),
                  width: selected ? 5 : 2,
                ),
                color: theme.colorScheme.surface,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                height: 70,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  // color: const Color(0xFFF8FAFC),
                ),
                child: asset == null
                    ? Text(method, style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.4))
                    : Image.asset(
                        asset,
                        height: 70,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => Text(method, style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.4)),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

