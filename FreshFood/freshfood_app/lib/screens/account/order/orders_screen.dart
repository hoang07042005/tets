import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:freshfood_app/api/api_client.dart';
import 'package:freshfood_app/config/api_config.dart';
import 'package:freshfood_app/models/order.dart';
import 'package:freshfood_app/screens/account/order/order_detail_screen.dart';
import 'package:freshfood_app/screens/account/auth/auth_login_screen.dart';
import 'package:freshfood_app/l10n/app_localizations.dart';
import 'package:freshfood_app/state/auth_state.dart';
import 'package:freshfood_app/ui/formatters.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

enum _OrderTab { all, processing, shipping, delivered, returned, cancelled }

class _OrdersScreenState extends State<OrdersScreen> {
  final _api = ApiClient();
  bool _loading = true;
  String? _err;
  List<Order> _orders = const <Order>[];
  _OrderTab _tab = _OrderTab.all;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final u = AuthState.currentUser.value;
    if (u == null) {
      setState(() {
        _loading = false;
        _orders = const <Order>[];
      });
      return;
    }
    setState(() {
      _loading = true;
      _err = null;
    });
    try {
      final xs = await _api.getUserOrders(u.userId);
      xs.sort((a, b) => (b.orderDate?.millisecondsSinceEpoch ?? 0) - (a.orderDate?.millisecondsSinceEpoch ?? 0));
      if (!mounted) return;
      setState(() => _orders = xs);
    } catch (e) {
      if (!mounted) return;
      setState(() => _err = 'Không tải được đơn hàng.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _statusLabel(AppLocalizations t, String? status) {
    final s = (status ?? '').trim().toLowerCase();
    if (s == 'paid') return t.tr(vi: 'Đã thanh toán', en: 'Paid');
    if (s == 'delivered') return t.tr(vi: 'Đã giao', en: 'Delivered');
    if (s == 'returnpending') return t.tr(vi: 'Chờ duyệt hoàn hàng', en: 'Return pending');
    if (s == 'refundpending') return t.tr(vi: 'Chờ hoàn tiền', en: 'Refund pending');
    if (s == 'returned') return t.tr(vi: 'Hoàn hàng', en: 'Returned');
    if (s == 'refunded') return t.tr(vi: 'Đã hoàn tiền', en: 'Refunded');
    if (s == 'intransit' || s == 'in_transit' || s == 'shipping' || s == 'shipped') return t.tr(vi: 'Đang giao', en: 'Shipping');
    if (s == 'processing') return t.tr(vi: 'Đang xử lý', en: 'Processing');
    if (s == 'pending') return t.tr(vi: 'Đã đặt hàng', en: 'Order placed');
    if (s == 'cancelled' || s == 'canceled') return t.tr(vi: 'Đã hủy', en: 'Cancelled');
    if (s == 'failed') return t.tr(vi: 'Thất bại', en: 'Failed');
    if (s == 'completed') return t.tr(vi: 'Hoàn thành', en: 'Completed');
    return status?.trim().isEmpty == false ? status!.trim() : t.tr(vi: 'Đang xử lý', en: 'Processing');
  }

  Color _statusColor(String? status) {
    final s = (status ?? '').trim().toLowerCase();
    if (s == 'delivered' || s == 'completed' || s == 'paid') return const Color(0xFF16A34A);
    if (s == 'cancelled' || s == 'canceled' || s == 'failed') return const Color(0xFFEF4444);
    if (s == 'returned' || s == 'refunded' || s == 'returnpending' || s == 'refundpending') return const Color(0xFF7C3AED);
    if (s == 'shipping' || s == 'intransit' || s == 'in_transit' || s == 'shipped') return const Color(0xFF2563EB);
    return const Color(0xFFB45309);
  }

  bool _matchTab(Order o) {
    final s = (o.status ?? '').trim().toLowerCase();
    switch (_tab) {
      case _OrderTab.all:
        return true;
      case _OrderTab.processing:
        return s == 'pending' || s == 'processing' || s == 'paid';
      case _OrderTab.shipping:
        return s == 'shipping' || s == 'intransit' || s == 'in_transit' || s == 'shipped';
      case _OrderTab.delivered:
        return s == 'delivered' || s == 'completed';
      case _OrderTab.returned:
        return s == 'returnpending' || s == 'refundpending' || s == 'returned' || s == 'refunded';
      case _OrderTab.cancelled:
        return s == 'cancelled' || s == 'canceled' || s == 'failed';
    }
  }

  int _countTab(_OrderTab tab) {
    final old = _tab;
    _tab = tab;
    final c = _orders.where(_matchTab).length;
    _tab = old;
    return c;
  }

  String _code(Order o) {
    final c = (o.orderCode ?? '').trim();
    if (c.isNotEmpty) return c.startsWith('#') ? c : '#$c';
    return '#FF-${o.orderId.toString().padLeft(5, '0')}';
  }

  String _dateLabel(DateTime? dt) {
    final d = dt;
    if (d == null) return '';
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = AppLocalizations.of(context);
    final u = AuthState.currentUser.value;

    if (u == null) {
      return Scaffold(
        appBar: AppBar(title: Text(t.tr(vi: 'Đơn hàng', en: 'Orders'))),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(t.tr(vi: 'Bạn chưa đăng nhập', en: 'You are not signed in'), style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              Text(t.tr(vi: 'Vui lòng đăng nhập để xem đơn hàng.', en: 'Please sign in to view your orders.'), style: theme.textTheme.bodyMedium?.copyWith(color: const Color(0xFF64748B))),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AuthLoginScreen())),
                style: FilledButton.styleFrom(backgroundColor: const Color(0xFF62BF39), foregroundColor: Colors.white),
                child: Text(t.tr(vi: 'Đăng nhập', en: 'Sign in')),
              ),
            ],
          ),
        ),
      );
    }

    final shown = _orders.where(_matchTab).toList(growable: false);

    return Scaffold(
      appBar: AppBar(title: Text(t.tr(vi: 'Đơn hàng', en: 'Orders'))),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(t.tr(vi: 'Lịch sử đơn hàng', en: 'Order history'), style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            Text(
              t.tr(
                vi: 'Xem các đơn hàng gần đây và theo dõi hành trình nông sản tươi đến tận cửa nhà bạn.',
                en: 'View recent orders and track the journey of fresh produce to your doorstep.',
              ),
              style: theme.textTheme.bodyMedium?.copyWith(color: const Color(0xFF64748B), fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 14),
            _Tabs(
              value: _tab,
              counts: {
                _OrderTab.all: _countTab(_OrderTab.all),
                _OrderTab.processing: _countTab(_OrderTab.processing),
                _OrderTab.shipping: _countTab(_OrderTab.shipping),
                _OrderTab.delivered: _countTab(_OrderTab.delivered),
                _OrderTab.returned: _countTab(_OrderTab.returned),
                _OrderTab.cancelled: _countTab(_OrderTab.cancelled),
              },
              onChanged: (t) => setState(() => _tab = t),
            ),
            const SizedBox(height: 14),
            if (_loading)
              const Padding(padding: EdgeInsets.symmetric(vertical: 40), child: Center(child: CircularProgressIndicator()))
            else if (_err != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Text(_err!, style: theme.textTheme.bodyMedium?.copyWith(color: const Color(0xFFB91C1C), fontWeight: FontWeight.w800)),
              )
            else if (_orders.isEmpty)
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  color: theme.colorScheme.surface,
                  border: Border.all(color: theme.colorScheme.outlineVariant),
                ),
                child: Column(
                  children: [
                    Icon(Icons.inventory_2_outlined, size: 44, color: const Color(0xFF94A3B8).withValues(alpha: 0.9)),
                    const SizedBox(height: 10),
                    Text(t.tr(vi: 'Chưa có đơn hàng', en: 'No orders yet'), style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
                    const SizedBox(height: 6),
                    Text(t.tr(vi: 'Bạn chưa đặt đơn nào. Hãy mua sắm ngay!', en: "You haven't placed any orders. Start shopping now!"), style: theme.textTheme.bodyMedium?.copyWith(color: const Color(0xFF64748B))),
                  ],
                ),
              )
            else if (shown.isEmpty)
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  color: theme.colorScheme.surface,
                  border: Border.all(color: theme.colorScheme.outlineVariant),
                ),
                child: Text(t.tr(vi: 'Không có đơn ở trạng thái này.', en: 'No orders in this status.'), style: theme.textTheme.bodyMedium),
              )
            else
              ...shown.map((o) {
                final firstImg = o.lines.isEmpty ? '' : ApiConfig.resolveMediaUrl(o.lines.first.imageUrl);
                final st = _statusLabel(t, o.status);
                final stColor = _statusColor(o.status);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: InkWell(
                    onTap: () async {
                      final idOrToken = (o.orderToken ?? '').trim().isNotEmpty ? o.orderToken!.trim() : '${o.orderId}';
                      await Navigator.of(context).push(MaterialPageRoute(builder: (_) => OrderDetailScreen(idOrToken: idOrToken)));
                      // refresh in case user cancels/confirms received
                      // ignore: discarded_futures
                      _load();
                    },
                    borderRadius: BorderRadius.circular(18),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        color: theme.colorScheme.surface,
                        border: Border.all(color: theme.colorScheme.outlineVariant),
                        boxShadow: [
                          BoxShadow(color: const Color(0xFF0F172A).withValues(alpha: 0.06), blurRadius: 16, offset: const Offset(0, 10)),
                        ],
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 46,
                                height: 46,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(14),
                                  color: theme.colorScheme.surfaceContainerHighest,
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: firstImg.isEmpty
                                    ? const Icon(Icons.local_shipping_outlined, color: Color(0xFF64748B))
                                    : CachedNetworkImage(imageUrl: firstImg, fit: BoxFit.cover),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(_code(o), style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
                                    const SizedBox(height: 2),
                                    Text('Đặt ngày: ${_dateLabel(o.orderDate)}',
                                        style: theme.textTheme.bodySmall?.copyWith(color: const Color(0xFF64748B), fontWeight: FontWeight.w700)),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(999),
                                  color: stColor.withValues(alpha: 0.10),
                                ),
                                child: Text(st, style: TextStyle(color: stColor, fontWeight: FontWeight.w900)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: Text('TỔNG THANH TOÁN',
                                    style: theme.textTheme.bodySmall?.copyWith(color: const Color(0xFF94A3B8), fontWeight: FontWeight.w900)),
                              ),
                              Text(
                                Formatters.vnd(o.totalAmount),
                                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900, color: const Color(0xFFE67E22)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Xem chi tiết →',
                              style: theme.textTheme.bodyMedium?.copyWith(color: const Color(0xFF62BF39), fontWeight: FontWeight.w900),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            const SizedBox(height: 18),
          ],
        ),
      ),
    );
  }
}

class _Tabs extends StatelessWidget {
  final _OrderTab value;
  final Map<_OrderTab, int> counts;
  final ValueChanged<_OrderTab> onChanged;
  const _Tabs({required this.value, required this.counts, required this.onChanged});

  String _label(_OrderTab t) {
    switch (t) {
      case _OrderTab.all:
        return 'Tất cả';
      case _OrderTab.processing:
        return 'Đang xử lý';
      case _OrderTab.shipping:
        return 'Đang giao';
      case _OrderTab.delivered:
        return 'Đã giao';
      case _OrderTab.returned:
        return 'Hoàn hàng';
      case _OrderTab.cancelled:
        return 'Đã hủy';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final items = _OrderTab.values;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final t in items) ...[
            _TabPill(
              label: _label(t),
              count: counts[t] ?? 0,
              active: t == value,
              onTap: () => onChanged(t),
            ),
            const SizedBox(width: 8),
          ],
          // keep right padding
          const SizedBox(width: 2),
        ],
      ),
    );
  }
}

class _TabPill extends StatelessWidget {
  final String label;
  final int count;
  final bool active;
  final VoidCallback onTap;
  const _TabPill({required this.label, required this.count, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final bg = active ? const Color(0xFF62BF39) : const Color(0xFFF1F5F9);
    final fg = active ? Colors.white : const Color(0xFF111827);
    final badgeBg = active ? Colors.white.withValues(alpha: 0.18) : const Color(0xFFE2E8F0);
    final badgeFg = active ? Colors.white : const Color(0xFF475569);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          color: bg,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: TextStyle(color: fg, fontWeight: FontWeight.w900)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                color: badgeBg,
              ),
              child: Text('$count', style: TextStyle(color: badgeFg, fontWeight: FontWeight.w900, fontSize: 12)),
            ),
          ],
        ),
      ),
    );
  }
}

