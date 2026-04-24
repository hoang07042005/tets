import 'dart:async';

import 'package:flutter/material.dart';

import 'package:freshfood_app/api/api_client.dart';
import 'package:freshfood_app/l10n/app_localizations.dart';
import 'package:freshfood_app/models/admin_order.dart';
import 'package:freshfood_app/state/auth_state.dart';
import 'package:freshfood_app/ui/formatters.dart';

import 'admin_order_detail_admin_screen.dart';

class AdminOrdersScreen extends StatefulWidget {
  const AdminOrdersScreen({super.key});

  @override
  State<AdminOrdersScreen> createState() => _AdminOrdersScreenState();
}

class _AdminOrdersScreenState extends State<AdminOrdersScreen> with SingleTickerProviderStateMixin {
  final _api = ApiClient.instance;

  bool _loading = true;
  String? _err;
  AdminOrdersPage? _page;

  int _pageNo = 1;
  final int _pageSize = 8;
  String _status = 'all';
  final _qCtl = TextEditingController();
  Timer? _debounce;

  bool get _isAdmin => (AuthState.currentUser.value?.role ?? '').trim().toLowerCase() == 'admin';

  @override
  void initState() {
    super.initState();
    _qCtl.addListener(() {
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 350), () {
        _pageNo = 1;
        _load();
      });
    });
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _qCtl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _err = null;
    });
    try {
      final p = await _api.getAdminOrdersPage(page: _pageNo, pageSize: _pageSize, status: _status, q: _qCtl.text);
      if (!mounted) return;
      setState(() => _page = p);
    } catch (e) {
      if (!mounted) return;
      setState(() => _err = '$e'.replaceFirst('Exception: ', '').trim());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    if (!_isAdmin) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_person_rounded, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              Text(t.tr(vi: 'Bạn không có quyền truy cập.', en: 'Permission denied.'), 
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
            ],
          ),
        ),
      );
    }

    final p = _page;
    final items = p?.items ?? const <AdminOrderRow>[];
    final total = p?.totalCount ?? 0;
    final pageCount = (total <= 0) ? 1 : ((total + _pageSize - 1) ~/ _pageSize);
    final safePage = _pageNo.clamp(1, pageCount);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            floating: true,
            pinned: true,
            snap: true,
            expandedHeight: 120,
            backgroundColor: Colors.white,
            elevation: 0,
            surfaceTintColor: Colors.transparent,
            title: Text(t.tr(vi: 'Quản lý đơn hàng', en: 'Order Management'), 
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20, color: Color(0xFF1E293B))),
            actions: [
              IconButton(
                onPressed: _loading ? null : _load,
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.refresh_rounded, color: Color(0xFF64748B), size: 20),
                ),
              ),
              const SizedBox(width: 16),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Padding(
                padding: const EdgeInsets.fromLTRB(16, 100, 16, 0),
                child: _SearchBar(t: t, qCtl: _qCtl, cs: cs),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (p != null) _Stats(stats: p.stats),
                  const SizedBox(height: 20),
                  _StatusFilter(
                    current: _status,
                    onChanged: (v) {
                      setState(() {
                        _status = v;
                        _pageNo = 1;
                      });
                      _load();
                    },
                  ),
                  if (_err != null) ...[
                    const SizedBox(height: 16),
                    _ErrorBox(err: _err!, cs: cs),
                  ],
                ],
              ),
            ),
          ),
          if (_loading && p == null)
            const SliverFillRemaining(child: Center(child: CircularProgressIndicator()))
          else if (items.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.inbox_rounded, size: 64, color: cs.outlineVariant),
                    const SizedBox(height: 12),
                    Text(t.tr(vi: 'Không có đơn hàng nào', en: 'No orders found'), 
                      style: TextStyle(color: cs.onSurfaceVariant, fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    if (index >= items.length) return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: _Pager(
                        page: safePage,
                        pageCount: pageCount,
                        total: total,
                        pageSize: _pageSize,
                        onPrev: safePage <= 1 ? null : () { setState(() => _pageNo = safePage - 1); _load(); },
                        onNext: safePage >= pageCount ? null : () { setState(() => _pageNo = safePage + 1); _load(); },
                      ),
                    );
                    final o = items[index];
                    return _OrderCard(
                      o: o,
                      onTap: () async {
                        final ok = await Navigator.of(context).push<bool>(
                          MaterialPageRoute(builder: (_) => AdminOrderDetailAdminScreen(idOrToken: o.orderToken.isNotEmpty ? o.orderToken : '${o.orderId}')),
                        );
                        if (!mounted) return;
                        if (ok == true) await _load();
                      },
                    );
                  },
                  childCount: items.length + 1,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  final AppLocalizations t;
  final TextEditingController qCtl;
  final ColorScheme cs;
  const _SearchBar({required this.t, required this.qCtl, required this.cs});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(16),
      ),
      child: TextField(
        controller: qCtl,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
        decoration: InputDecoration(
          hintText: t.tr(vi: 'Tìm mã đơn, tên khách...', en: 'Search orders...'),
          hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontWeight: FontWeight.w600),
          prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF64748B), size: 20),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }
}

class _StatusFilter extends StatelessWidget {
  final String current;
  final ValueChanged<String> onChanged;
  const _StatusFilter({required this.current, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final statuses = [
      {'id': 'all', 'vi': 'Tất cả', 'en': 'All'},
      {'id': 'Pending', 'vi': 'Chờ xử lý', 'en': 'Pending'},
      {'id': 'Processing', 'vi': 'Đã xác nhận', 'en': 'Confirmed'},
      {'id': 'Preparing', 'vi': 'Chuẩn bị', 'en': 'Preparing'},
      {'id': 'Shipping', 'vi': 'Đang giao', 'en': 'Shipping'},
      {'id': 'Delivered', 'vi': 'Đã giao', 'en': 'Delivered'},
      {'id': 'Completed', 'vi': 'Hoàn tất', 'en': 'Completed'},
      {'id': 'Cancelled', 'vi': 'Đã hủy', 'en': 'Cancelled'},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: statuses.map((s) {
          final isSelected = current == s['id'];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(s['vi']!, style: TextStyle(
                fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
                fontSize: 13,
              )),
              selected: isSelected,
              onSelected: (_) => onChanged(s['id']!),
              selectedColor: const Color(0xFF62BF39),
              labelStyle: TextStyle(color: isSelected ? Colors.white : const Color(0xFF64748B)),
              backgroundColor: Colors.white,
              checkmarkColor: Colors.white,
              side: BorderSide(color: isSelected ? Colors.transparent : const Color(0xFFE2E8F0)),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _Stats extends StatelessWidget {
  final AdminOrdersStats stats;
  const _Stats({required this.stats});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            label: 'DOANH THU',
            value: Formatters.vnd(stats.dailyRevenue),
            icon: Icons.payments_rounded,
            color: const Color(0xFFE67E22),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            label: 'ĐANG GIAO',
            value: '${stats.shippingCount}',
            icon: Icons.local_shipping_rounded,
            color: const Color(0xFF3B82F6),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            label: 'CHỜ DUYỆT',
            value: '${stats.pendingCount}',
            icon: Icons.pending_actions_rounded,
            color: const Color(0xFFF59E0B),
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _StatCard({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(height: 12),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: Color(0xFF1E293B))),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 10, color: Color(0xFF94A3B8))),
        ],
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  final AdminOrderRow o;
  final VoidCallback onTap;
  const _OrderCard({required this.o, required this.onTap});

  String _statusLabel(String s) {
    final x = s.trim().toLowerCase();
    if (x == 'paid') return 'Đã thanh toán';
    if (x == 'completed' || x == 'delivered') return 'Hoàn tất';
    if (x == 'shipping') return 'Đang giao';
    if (x == 'pending') return 'Chờ xử lý';
    if (x == 'processing') return 'Đã xác nhận';
    if (x == 'cancelled' || x == 'canceled') return 'Đã hủy';
    return s.trim();
  }

  Color _statusColor() {
    final x = o.status.trim().toLowerCase();
    if (x == 'paid' || x == 'completed' || x == 'delivered') return const Color(0xFF10B981);
    if (x == 'shipping') return const Color(0xFF3B82F6);
    if (x == 'cancelled' || x == 'canceled' || x == 'failed') return const Color(0xFFEF4444);
    if (x == 'pending') return const Color(0xFFF59E0B);
    return const Color(0xFF64748B);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _statusColor();
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 4))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(8)),
                    child: Text(o.orderCode, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: Color(0xFF1E293B))),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                    child: Text(_statusLabel(o.status), style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 11)),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: const Color(0xFFF1F5F9),
                    child: Text(o.customerName.isNotEmpty ? o.customerName[0].toUpperCase() : '?', 
                      style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF64748B))),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(o.customerName, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: Color(0xFF1E293B))),
                        const SizedBox(height: 2),
                        Text(Formatters.vnd(o.totalAmount), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: Color(0xFFE67E22))),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(o.orderDate.day.toString().padLeft(2, '0') + '/' + o.orderDate.month.toString().padLeft(2, '0'), 
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: Color(0xFF94A3B8))),
                      const SizedBox(height: 4),
                      const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Color(0xFFCBD5E1)),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  final String err;
  final ColorScheme cs;
  const _ErrorBox({required this.err, required this.cs});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFFCA5A5))),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: Color(0xFFDC2626), size: 20),
          const SizedBox(width: 8),
          Expanded(child: Text(err, style: const TextStyle(color: Color(0xFF991B1B), fontWeight: FontWeight.w800, fontSize: 13))),
        ],
      ),
    );
  }
}

class _Pager extends StatelessWidget {
  final int page;
  final int pageCount;
  final int total;
  final int pageSize;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;
  const _Pager({required this.page, required this.pageCount, required this.total, required this.pageSize, required this.onPrev, required this.onNext});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          onPressed: onPrev,
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: onPrev == null ? Colors.transparent : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Icon(Icons.chevron_left_rounded, color: onPrev == null ? const Color(0xFFCBD5E1) : const Color(0xFF1E293B)),
          ),
        ),
        const SizedBox(width: 16),
        Text('$page / $pageCount', style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF1E293B))),
        const SizedBox(width: 16),
        IconButton(
          onPressed: onNext,
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: onNext == null ? Colors.transparent : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Icon(Icons.chevron_right_rounded, color: onNext == null ? const Color(0xFFCBD5E1) : const Color(0xFF1E293B)),
          ),
        ),
      ],
    );
  }
}

