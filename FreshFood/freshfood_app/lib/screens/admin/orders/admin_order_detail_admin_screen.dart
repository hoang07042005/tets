import 'package:flutter/material.dart';

import 'package:freshfood_app/api/api_client.dart';
import 'package:freshfood_app/config/api_config.dart';
import 'package:freshfood_app/l10n/app_localizations.dart';
import 'package:freshfood_app/models/admin_order.dart';
import 'package:freshfood_app/state/auth_state.dart';
import 'package:freshfood_app/ui/formatters.dart';

class AdminOrderDetailAdminScreen extends StatefulWidget {
  final String idOrToken;
  const AdminOrderDetailAdminScreen({super.key, required this.idOrToken});

  @override
  State<AdminOrderDetailAdminScreen> createState() => _AdminOrderDetailAdminScreenState();
}

class _AdminOrderDetailAdminScreenState extends State<AdminOrderDetailAdminScreen> {
  final _api = ApiClient.instance;
  AdminOrderDetail? _data;
  bool _loading = true;
  bool _saving = false;
  String? _err;
  String _status = 'Pending';

  final Map<int, TextEditingController> _carrierCtl = {};
  final Map<int, TextEditingController> _trackingCtl = {};

  bool get _isAdmin => (AuthState.currentUser.value?.role ?? '').trim().toLowerCase() == 'admin';

  @override
  void dispose() {
    for (final c in _carrierCtl.values) {
      c.dispose();
    }
    for (final c in _trackingCtl.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    // Localizations (and Theme) are not ready until after the first frame;
    // _load uses AppLocalizations.of(context).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // ignore: discarded_futures
      _load();
    });
  }

  Future<void> _load() async {
    final t = AppLocalizations.of(context);
    if (!mounted) return;
    setState(() {
      _loading = true;
      _err = null;
    });
    try {
      final id = widget.idOrToken.trim();
      final numeric = int.tryParse(id);
      final d = (numeric != null && numeric > 0) ? await _api.getAdminOrderDetail(numeric) : await _api.getAdminOrderDetailByToken(id);
      if (!mounted) return;
      if (d == null) throw Exception(t.tr(vi: 'Không tải được dữ liệu đơn hàng.', en: 'Failed to load order data.'));
      setState(() {
        _data = d;
        _status = (d.pipelineStatus.trim().isEmpty ? d.status : d.pipelineStatus).trim();
      });
      for (final s in d.shipments) {
        _carrierCtl[s.shipmentId]?.dispose();
        _trackingCtl[s.shipmentId]?.dispose();
        _carrierCtl[s.shipmentId] = TextEditingController(text: s.carrier);
        _trackingCtl[s.shipmentId] = TextEditingController(text: s.trackingNumber);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _err = '$e'.replaceFirst('Exception: ', '').trim());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _saveStatus() async {
    final d = _data;
    if (d == null) return;
    final t = AppLocalizations.of(context);
    setState(() {
      _saving = true;
      _err = null;
    });
    try {
      await _api.adminUpdateOrderStatus(orderId: d.orderId, status: _status);
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.tr(vi: 'Đã cập nhật trạng thái đơn hàng.', en: 'Order status updated.'))));
    } catch (e) {
      if (!mounted) return;
      setState(() => _err = '$e'.replaceFirst('Exception: ', '').trim());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _cancel() async {
    final d = _data;
    if (d == null) return;
    final t = AppLocalizations.of(context);
    final reasonCtl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.tr(vi: 'Hủy đơn hàng', en: 'Cancel order'), style: const TextStyle(fontWeight: FontWeight.w900)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${t.tr(vi: 'Xác nhận hủy đơn', en: 'Confirm cancel')} ${d.orderCode}?', style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            TextField(
              controller: reasonCtl,
              decoration: InputDecoration(
                hintText: t.tr(vi: 'Lý do hủy đơn...', en: 'Cancel reason...'),
                filled: true,
                fillColor: Colors.grey.shade100,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(t.tr(vi: 'Quay lại', en: 'Back'))),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
            child: Text(t.tr(vi: 'Xác nhận hủy', en: 'Confirm cancel')),
          ),
        ],
      ),
    );
    if (ok != true) return;

    setState(() {
      _saving = true;
      _err = null;
    });
    try {
      await _api.adminCancelOrder(orderId: d.orderId, reason: reasonCtl.text);
      await _load();
    } catch (e) {
      if (!mounted) return;
      setState(() => _err = '$e'.replaceFirst('Exception: ', '').trim());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _saveShipment(int shipmentId) async {
    final t = AppLocalizations.of(context);
    setState(() {
      _saving = true;
      _err = null;
    });
    try {
      await _api.adminUpdateShipmentDetails(
        shipmentId: shipmentId,
        carrier: _carrierCtl[shipmentId]?.text,
        trackingNumber: _trackingCtl[shipmentId]?.text,
      );
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.tr(vi: 'Đã lưu thông tin vận chuyển.', en: 'Shipment details saved.'))));
    } catch (e) {
      if (!mounted) return;
      setState(() => _err = '$e'.replaceFirst('Exception: ', '').trim());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final d = _data;

    if (!_isAdmin) {
      return Scaffold(body: Center(child: Text(t.tr(vi: 'Quyền truy cập bị từ chối.', en: 'Permission denied.'))));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(d?.orderCode ?? t.tr(vi: 'Chi tiết đơn', en: 'Order details'), style: const TextStyle(fontWeight: FontWeight.w900)),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh_rounded)),
          const SizedBox(width: 8),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (_err != null) _ErrorBox(err: _err!),
                  if (d != null) ...[
                    _StatusHeader(status: d.pipelineStatus.isNotEmpty ? d.pipelineStatus : d.status),
                    const SizedBox(height: 20),
                    _AdminCard(
                      title: t.tr(vi: 'Cập nhật trạng thái', en: 'Update status'),
                      icon: Icons.edit_note_rounded,
                      child: Column(
                        children: [
                          DropdownButtonFormField<String>(
                            value: _status,
                            isExpanded: true,
                            items: [
                              DropdownMenuItem(value: 'Pending', child: Text(t.tr(vi: 'Chờ xử lý', en: 'Pending'))),
                              DropdownMenuItem(value: 'Processing', child: Text(t.tr(vi: 'Đã xác nhận', en: 'Confirmed'))),
                              DropdownMenuItem(value: 'Preparing', child: Text(t.tr(vi: 'Chuẩn bị hàng', en: 'Preparing'))),
                              DropdownMenuItem(value: 'Shipping', child: Text(t.tr(vi: 'Đang giao', en: 'Shipping'))),
                              DropdownMenuItem(value: 'Delivered', child: Text(t.tr(vi: 'Đã giao', en: 'Delivered'))),
                              DropdownMenuItem(value: 'Completed', child: Text(t.tr(vi: 'Hoàn tất', en: 'Completed'))),
                              DropdownMenuItem(value: 'Cancelled', child: Text(t.tr(vi: 'Đã hủy', en: 'Cancelled'))),
                            ],
                            onChanged: _saving ? null : (v) => setState(() => _status = (v ?? 'Pending')),
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: const Color(0xFFF1F5F9),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: FilledButton.icon(
                                  onPressed: _saving ? null : _saveStatus,
                                  icon: _saving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.check_circle_outline, size: 18),
                                  label: Text(t.tr(vi: 'Cập nhật', en: 'Update')),
                                  style: FilledButton.styleFrom(backgroundColor: const Color(0xFF62BF39), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _saving ? null : _cancel,
                                  icon: const Icon(Icons.cancel_outlined, size: 18, color: Color(0xFFEF4444)),
                                  label: Text(
                                    t.tr(vi: 'Hủy đơn', en: 'Cancel order'),
                                    style: const TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.w900),
                                  ),
                                  style: OutlinedButton.styleFrom(side: const BorderSide(color: Color(0xFFEF4444)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _AdminCard(
                      title: t.tr(vi: 'Thông tin đơn hàng', en: 'Order information'),
                      icon: Icons.info_outline_rounded,
                      child: Column(
                        children: [
                          _DetailRow(label: t.tr(vi: 'Ngày đặt', en: 'Order date'), value: _fmtDateTime(d.orderDate)),
                          _DetailRow(label: t.tr(vi: 'Tổng thanh toán', en: 'Total'), value: Formatters.vnd(d.totalAmount), isBold: true, color: const Color(0xFFE67E22)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _AdminCard(
                      title: t.tr(vi: 'Khách hàng', en: 'Customer'),
                      icon: Icons.person_outline_rounded,
                      child: Column(
                        children: [
                          _DetailRow(label: t.tr(vi: 'Họ tên', en: 'Full name'), value: d.customer.fullName),
                          _DetailRow(label: 'Email', value: d.customer.email),
                          _DetailRow(label: t.tr(vi: 'Số điện thoại', en: 'Phone'), value: d.customer.phone.isNotEmpty ? d.customer.phone : '—'),
                          _DetailRow(label: t.tr(vi: 'Địa chỉ nhận', en: 'Shipping address'), value: d.shippingAddress, isMultiLine: true),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _AdminCard(
                      title: t.tr(vi: 'Thanh toán & Vận chuyển', en: 'Payment & Shipping'),
                      icon: Icons.local_shipping_outlined,
                      child: Column(
                        children: [
                          _DetailRow(label: t.tr(vi: 'Thanh toán', en: 'Payment method'), value: d.latestPayment?.method ?? 'COD'),
                          _DetailRow(label: t.tr(vi: 'Trạng thái TT', en: 'Payment status'), value: d.latestPayment?.status ?? t.tr(vi: 'Chưa thanh toán', en: 'Unpaid')),
                          const Divider(height: 24),
                          if (d.shipments.isEmpty)
                            Text(
                              t.tr(vi: 'Chưa có thông tin vận đơn.', en: 'No shipment info yet.'),
                              style: const TextStyle(color: Color(0xFF64748B), fontSize: 13, fontWeight: FontWeight.w600),
                            )
                          else
                            ...d.shipments.map((s) => _ShipmentField(
                                  shipment: s,
                                  carrierCtl: _carrierCtl[s.shipmentId]!,
                                  trackingCtl: _trackingCtl[s.shipmentId]!,
                                  onSave: _saving ? null : () => _saveShipment(s.shipmentId),
                                )),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _AdminCard(
                      title: '${t.tr(vi: 'Danh sách sản phẩm', en: 'Items')} (${d.items.length})',
                      icon: Icons.shopping_bag_outlined,
                      child: Column(
                        children: d.items.map((it) => _OrderItemTile(it: it)).toList(),
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ],
              ),
            ),
    );
  }

  String _fmtDateTime(DateTime d) {
    final x = d.toLocal();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(x.day)}/${two(x.month)}/${x.year} ${two(x.hour)}:${two(x.minute)}';
  }
}

class _StatusHeader extends StatelessWidget {
  final String status;
  const _StatusHeader({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    String label = status;
    final s = status.toLowerCase();
    if (s.contains('completed') || s.contains('delivered') || s.contains('paid')) {
      color = const Color(0xFF10B981);
      label = 'Hoàn tất';
    } else if (s.contains('shipping')) {
      color = const Color(0xFF3B82F6);
      label = 'Đang giao';
    } else if (s.contains('pending')) {
      color = const Color(0xFFF59E0B);
      label = 'Chờ xử lý';
    } else if (s.contains('cancelled')) {
      color = const Color(0xFFEF4444);
      label = 'Đã hủy';
    } else {
      color = const Color(0xFF64748B);
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: const Icon(Icons.receipt_long_rounded, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Trạng thái hiện tại', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: Color(0xFF64748B))),
                Text(label, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20, color: color)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;
  const _AdminCard({required this.title, required this.icon, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 15, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: const Color(0xFF1E293B)),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: Color(0xFF1E293B))),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isBold;
  final Color? color;
  final bool isMultiLine;
  const _DetailRow({required this.label, required this.value, this.isBold = false, this.color, this.isMultiLine = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: isMultiLine ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: [
          SizedBox(width: 100, child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF94A3B8)))),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontWeight: isBold ? FontWeight.w900 : FontWeight.w800,
                fontSize: 14,
                color: color ?? const Color(0xFF1E293B),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ShipmentField extends StatelessWidget {
  final AdminShipment shipment;
  final TextEditingController carrierCtl;
  final TextEditingController trackingCtl;
  final VoidCallback? onSave;
  const _ShipmentField({required this.shipment, required this.carrierCtl, required this.trackingCtl, required this.onSave});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextField(
          controller: carrierCtl,
          decoration: const InputDecoration(labelText: 'Đơn vị vận chuyển', hintText: 'VD: Giao Hàng Nhanh...'),
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: trackingCtl,
                decoration: const InputDecoration(labelText: 'Mã vận đơn'),
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
              ),
            ),
            const SizedBox(width: 12),
            IconButton.filled(
              onPressed: onSave,
              icon: const Icon(Icons.save_rounded, size: 20),
              style: IconButton.styleFrom(backgroundColor: const Color(0xFF3B82F6), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            ),
          ],
        ),
      ],
    );
  }
}

class _OrderItemTile extends StatelessWidget {
  final AdminOrderItem it;
  const _OrderItemTile({required this.it});

  @override
  Widget build(BuildContext context) {
    final img = ApiConfig.resolveMediaUrl(it.thumbUrl);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 50,
              height: 50,
              color: const Color(0xFFF1F5F9),
              child: img.isEmpty ? const Icon(Icons.image_not_supported_rounded, color: Color(0xFF94A3B8)) : Image.network(img, fit: BoxFit.cover),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(it.productName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: Color(0xFF1E293B))),
                Text('x${it.quantity}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: Color(0xFF94A3B8))),
              ],
            ),
          ),
          Text(Formatters.vnd(it.lineTotal), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: Color(0xFF1E293B))),
        ],
      ),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  final String err;
  const _ErrorBox({required this.err});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFFCA5A5))),
      child: Text(err, style: const TextStyle(color: Color(0xFF991B1B), fontWeight: FontWeight.w800, fontSize: 13)),
    );
  }
}

