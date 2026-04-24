import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:freshfood_app/api/api_client.dart';
import 'package:freshfood_app/l10n/app_localizations.dart';
import 'package:freshfood_app/models/public_order_track.dart';

class OrderTrackScreen extends StatefulWidget {
  final String? initialOrderCode;
  final String? initialPhone;
  const OrderTrackScreen({super.key, this.initialOrderCode, this.initialPhone});

  @override
  State<OrderTrackScreen> createState() => _OrderTrackScreenState();
}

class _OrderTrackScreenState extends State<OrderTrackScreen> {
  final _api = ApiClient.instance;
  final _formKey = GlobalKey<FormState>();
  final _codeCtl = TextEditingController();
  final _phoneCtl = TextEditingController();

  bool _loading = false;
  String? _err;
  PublicOrderTrack? _result;

  @override
  void initState() {
    super.initState();
    _codeCtl.text = (widget.initialOrderCode ?? '').trim();
    _phoneCtl.text = (widget.initialPhone ?? '').trim();
    if (_codeCtl.text.isNotEmpty && _phoneCtl.text.isNotEmpty) {
      // ignore: discarded_futures
      _track();
    }
  }

  @override
  void dispose() {
    _codeCtl.dispose();
    _phoneCtl.dispose();
    super.dispose();
  }

  String _statusLabel(AppLocalizations t, String s) {
    final x = s.trim().toLowerCase();
    if (x == 'completed' || x == 'delivered') return t.tr(vi: 'Hoàn tất / Đã giao', en: 'Completed / Delivered');
    if (x == 'shipping' || x == 'intransit' || x == 'in_transit') return t.tr(vi: 'Đang giao hàng', en: 'Shipping');
    if (x == 'preparing' || x == 'preparing_goods' || x == 'packing') return t.tr(vi: 'Chuẩn bị hàng', en: 'Preparing');
    if (x == 'processing') return t.tr(vi: 'Đã xác nhận', en: 'Confirmed');
    if (x == 'pending') return t.tr(vi: 'Chờ xử lý', en: 'Pending');
    return s.trim().isEmpty ? '—' : s.trim();
  }

  String? _partnerTrackingUrl(String carrier, String trackingNumber) {
    final t = trackingNumber.trim();
    if (t.isEmpty) return null;
    final c = carrier.toLowerCase();
    if (c.contains('ghn') || c.contains('giao hàng nhanh')) {
      return 'https://donhang.ghn.vn/?order_code=${Uri.encodeComponent(t)}';
    }
    if (c.contains('ghtk') || c.contains('giao hàng tiết kiệm')) {
      return 'https://i.ghtk.vn/${Uri.encodeComponent(t)}';
    }
    return null;
  }

  String _fmtDateTimeVi(DateTime d) {
    final local = d.toLocal();
    String two(int x) => x.toString().padLeft(2, '0');
    return '${two(local.day)}/${two(local.month)}/${local.year} ${two(local.hour)}:${two(local.minute)}';
  }

  Future<void> _track() async {
    final t = AppLocalizations.of(context);
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final code = _codeCtl.text.trim();
    final phone = _phoneCtl.text.trim();
    setState(() {
      _loading = true;
      _err = null;
      _result = null;
    });
    try {
      final data = await _api.trackOrder(orderCode: code, phone: phone);
      if (!mounted) return;
      if (data == null) {
        setState(() {
          _err = t.tr(
            vi: 'Không tìm thấy đơn hàng. Kiểm tra mã đơn và số điện thoại đã dùng khi đặt hàng.',
            en: 'Order not found. Please check the order code and phone number.',
          );
        });
        return;
      }
      setState(() => _result = data);
    } catch (e) {
      if (!mounted) return;
      final msg = '$e'.replaceFirst('Exception: ', '').trim();
      setState(() => _err = msg.isEmpty ? t.tr(vi: 'Tra cứu thất bại.', en: 'Tracking failed.') : msg);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(t.tr(vi: 'Tra cứu vận đơn', en: 'Track order'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: cs.outlineVariant),
            ),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  Text(
                    t.tr(
                      vi: 'Nhập mã đơn hàng và số điện thoại đã dùng khi đặt (khớp tài khoản khách hàng).',
                      en: 'Enter your order code and the phone number used for checkout.',
                    ),
                    style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _codeCtl,
                          decoration: InputDecoration(
                            hintText: t.tr(vi: 'Mã đơn hàng', en: 'Order code'),
                          ),
                          validator: (v) => (v ?? '').trim().isEmpty ? t.tr(vi: 'Bắt buộc', en: 'Required') : null,
                          textInputAction: TextInputAction.next,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          controller: _phoneCtl,
                          decoration: InputDecoration(
                            hintText: t.tr(vi: 'Số điện thoại', en: 'Phone number'),
                          ),
                          keyboardType: TextInputType.phone,
                          validator: (v) => (v ?? '').trim().isEmpty ? t.tr(vi: 'Bắt buộc', en: 'Required') : null,
                          onFieldSubmitted: (_) => _track(),
                        ),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        width: 48,
                        height: 48,
                        child: FilledButton(
                          onPressed: _loading ? null : _track,
                          style: FilledButton.styleFrom(
                            padding: EdgeInsets.zero,
                            backgroundColor: const Color(0xFF22C55E),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          child: _loading
                              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.search_rounded),
                        ),
                      ),
                    ],
                  ),
                  if (_err != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: cs.errorContainer,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: cs.error.withValues(alpha: 0.25)),
                      ),
                      child: Text(_err!, style: TextStyle(color: cs.onErrorContainer, fontWeight: FontWeight.w800)),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          Text(t.tr(vi: 'Kết quả', en: 'Result'), style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          if (_loading && _result == null)
            const Center(child: Padding(padding: EdgeInsets.symmetric(vertical: 20), child: CircularProgressIndicator()))
          else if (_result == null)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.6)),
              ),
              child: Text(
                _err != null
                    ? t.tr(vi: 'Chưa có dữ liệu hiển thị. Kiểm tra thông báo ở trên.', en: 'No data to show. Please check the message above.')
                    : t.tr(vi: 'Nhập mã đơn và số điện thoại, sau đó bấm Tra cứu.', en: 'Enter order code and phone, then press Search.'),
                style: theme.textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant, fontWeight: FontWeight.w700),
              ),
            )
          else
            _ResultCard(
              data: _result!,
              statusLabel: (s) => _statusLabel(t, s),
              fmtDate: _fmtDateTimeVi,
              partnerUrl: _partnerTrackingUrl,
              t: t,
            ),
        ],
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  final PublicOrderTrack data;
  final String Function(String) statusLabel;
  final String Function(DateTime) fmtDate;
  final String? Function(String, String) partnerUrl;
  final AppLocalizations t;
  const _ResultCard({required this.data, required this.statusLabel, required this.fmtDate, required this.partnerUrl, required this.t});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cs.outlineVariant),
        boxShadow: [BoxShadow(color: cs.shadow.withValues(alpha: 0.06), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _KV(t: t, label: t.tr(vi: 'Mã đơn', en: 'Order'), value: data.orderCode, mono: true, onCopy: () => Clipboard.setData(ClipboardData(text: data.orderCode))),
          const SizedBox(height: 8),
          _KV(t: t, label: t.tr(vi: 'Trạng thái đơn', en: 'Order status'), value: statusLabel(data.status)),
          const SizedBox(height: 8),
          _KV(t: t, label: t.tr(vi: 'Đặt lúc', en: 'Placed at'), value: fmtDate(data.orderDate)),
          const SizedBox(height: 12),
          for (final s in data.shipments) ...[
            Builder(builder: (context) {
              final ext = partnerUrl(s.carrier, s.trackingNumber);
              Future<void> openExternal() async {
                if (ext == null) return;
                final uri = Uri.tryParse(ext);
                if (uri == null) return;
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }

              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.6)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '${t.tr(vi: 'Vận đơn', en: 'Shipment')} #${s.shipmentId}',
                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 10),
                    _KV(t: t, label: t.tr(vi: 'Đối tác', en: 'Carrier'), value: s.carrier.trim().isEmpty ? '—' : s.carrier.trim()),
                    const SizedBox(height: 8),
                    _KV(
                      t: t,
                      label: t.tr(vi: 'Mã vận đơn', en: 'Tracking number'),
                      value: s.trackingNumber.trim().isEmpty ? '—' : s.trackingNumber.trim(),
                      mono: true,
                      onCopy: s.trackingNumber.trim().isEmpty ? null : () => Clipboard.setData(ClipboardData(text: s.trackingNumber.trim())),
                    ),
                    const SizedBox(height: 8),
                    _KV(t: t, label: t.tr(vi: 'Trạng thái giao', en: 'Shipment status'), value: s.status.trim().isEmpty ? '—' : s.status.trim()),
                    if (s.shippedDate != null) ...[
                      const SizedBox(height: 8),
                      _KV(t: t, label: t.tr(vi: 'Gửi hàng', en: 'Shipped'), value: fmtDate(s.shippedDate!)),
                    ],
                    if (s.actualDeliveryDate != null) ...[
                      const SizedBox(height: 8),
                      _KV(t: t, label: t.tr(vi: 'Giao xong', en: 'Delivered'), value: fmtDate(s.actualDeliveryDate!)),
                    ],
                    if (ext != null) ...[
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: openExternal,
                        icon: const Icon(Icons.open_in_new_rounded),
                        label: Text(t.tr(vi: 'Mở tra cứu đối tác', en: 'Open carrier tracking')),
                      ),
                    ],
                  ],
                ),
              );
            }),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

class _KV extends StatelessWidget {
  final AppLocalizations t;
  final String label;
  final String value;
  final bool mono;
  final VoidCallback? onCopy;
  const _KV({required this.t, required this.label, required this.value, this.mono = false, this.onCopy});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 108,
          child: Text(label, style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant, fontWeight: FontWeight.w800)),
        ),
        Expanded(
          child: Text(
            value,
            style: (mono ? theme.textTheme.bodyMedium?.copyWith(fontFamily: 'monospace') : theme.textTheme.bodyMedium)
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
        if (onCopy != null) ...[
          const SizedBox(width: 6),
          InkWell(
            onTap: onCopy,
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Icon(Icons.copy_rounded, size: 16, color: cs.onSurfaceVariant),
            ),
          ),
        ],
      ],
    );
  }
}

