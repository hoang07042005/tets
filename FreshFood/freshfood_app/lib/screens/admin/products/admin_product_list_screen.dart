import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:freshfood_app/api/api_client.dart';
import 'package:freshfood_app/config/api_config.dart';
import 'package:freshfood_app/l10n/app_localizations.dart';
import 'package:freshfood_app/models/admin_product.dart';
import 'package:freshfood_app/models/category.dart';
import 'package:freshfood_app/screens/admin/products/admin_product_upsert_screen.dart';
import 'package:freshfood_app/state/auth_state.dart';
import 'package:freshfood_app/ui/formatters.dart';

class AdminProductListScreen extends StatefulWidget {
  const AdminProductListScreen({super.key});

  @override
  State<AdminProductListScreen> createState() => _AdminProductListScreenState();
}

class _AdminProductListScreenState extends State<AdminProductListScreen> {
  final _api = ApiClient();

  bool _loading = true;
  String? _err;
  AdminProductsPage? _page;

  List<Category> _categories = const <Category>[];
  int _pageNo = 1;
  final int _pageSize = 10;
  int? _categoryId;
  String _status = 'all'; // all | Active | Inactive

  final _qCtl = TextEditingController();
  Timer? _debounce;

  bool get _isAdmin => (AuthState.currentUser.value?.role ?? '').trim().toLowerCase() == 'admin';

  @override
  void initState() {
    super.initState();
    _qCtl.addListener(_onQChanged);
    _bootstrap();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _qCtl.removeListener(_onQChanged);
    _qCtl.dispose();
    super.dispose();
  }

  void _onQChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      setState(() => _pageNo = 1);
      _load();
    });
  }

  Future<void> _bootstrap() async {
    setState(() {
      _loading = true;
      _err = null;
    });
    try {
      final results = await Future.wait<dynamic>([
        _api.getAdminCategories(),
        _api.getAdminProductsPage(page: _pageNo, pageSize: _pageSize, q: _qCtl.text, categoryId: _categoryId, status: _status),
      ]);
      if (!mounted) return;
      setState(() {
        _categories = (results[0] as List<Category>);
        _page = (results[1] as AdminProductsPage);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _err = '$e'.replaceFirst('Exception: ', '').trim());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _load() async {
    final token = (AuthState.token.value ?? '').trim();
    if (token.isEmpty || !_isAdmin) {
      setState(() {
        _loading = false;
        _err = 'Vui lòng đăng nhập tài khoản Admin.';
        _page = null;
      });
      return;
    }

    setState(() {
      _loading = true;
      _err = null;
    });
    try {
      final p = await _api.getAdminProductsPage(
        page: _pageNo,
        pageSize: _pageSize,
        q: _qCtl.text,
        categoryId: _categoryId,
        status: _status,
      );
      if (!mounted) return;
      setState(() => _page = p);
    } catch (e) {
      if (!mounted) return;
      setState(() => _err = '$e'.replaceFirst('Exception: ', '').trim());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _delete(AdminProductRow r) async {
    final t = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(t.tr(vi: 'Xóa sản phẩm?', en: 'Delete product?'), style: const TextStyle(fontWeight: FontWeight.w900)),
        content: Text('${r.productName}\n\n${t.tr(vi: 'Thao tác này không thể hoàn tác.', en: 'This action cannot be undone.')}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(t.tr(vi: 'Hủy', en: 'Cancel'), style: const TextStyle(color: Colors.grey))),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFEF4444), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(t.tr(vi: 'Xóa', en: 'Delete')),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _api.adminDeleteProduct(r.productId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.tr(vi: 'Đã xóa.', en: 'Deleted.'))));
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'.replaceFirst('Exception: ', '').trim())));
    }
  }

  Future<void> _openMenu(AdminProductRow r) async {
    final t = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (_) => SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(color: const Color(0xFF62BF39).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.inventory_2_rounded, color: Color(0xFF62BF39)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(r.productName, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16), maxLines: 1, overflow: TextOverflow.ellipsis),
                        Text('SKU: ${r.sku}', style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.copy_rounded),
              title: Text(t.tr(vi: 'Sao chép SKU', en: 'Copy SKU'), style: const TextStyle(fontWeight: FontWeight.w700)),
              onTap: () => Navigator.pop(context, 'copy'),
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: Text(t.tr(vi: 'Sửa sản phẩm', en: 'Edit product'), style: const TextStyle(fontWeight: FontWeight.w700)),
              onTap: () => Navigator.pop(context, 'edit'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444)),
              title: Text(t.tr(vi: 'Xóa', en: 'Delete'), style: const TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.w900)),
              onTap: () => Navigator.pop(context, 'delete'),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
    if (!mounted) return;
    if (action == 'copy') {
      await Clipboard.setData(ClipboardData(text: r.sku));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.tr(vi: 'Đã sao chép SKU.', en: 'SKU copied.'))));
    } else if (action == 'edit') {
      final ok = await Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (_) => AdminProductUpsertScreen.edit(productId: r.productId, productToken: r.productToken)),
      );
      if (!mounted) return;
      if (ok == true) await _load();
    } else if (action == 'delete') {
      await _delete(r);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = AppLocalizations.of(context);
    final p = _page;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: Text(t.tr(vi: 'Sản phẩm', en: 'Products'), style: const TextStyle(fontWeight: FontWeight.w900)),
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        actions: [
          IconButton(
            onPressed: _loading ? null : _bootstrap,
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: _bootstrap,
            color: const Color(0xFF62BF39),
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
                      border: Border(bottom: BorderSide(color: theme.colorScheme.outlineVariant)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (p != null) _Stats(stats: p.stats),
                        const SizedBox(height: 20),
                        _SearchBox(controller: _qCtl, t: t),
                        const SizedBox(height: 16),
                        _Filters(
                          categories: _categories,
                          categoryId: _categoryId,
                          status: _status,
                          onCategoryChanged: (id) {
                            setState(() {
                              _categoryId = id;
                              _pageNo = 1;
                            });
                            _load();
                          },
                          onStatusChanged: (s) {
                            setState(() {
                              _status = s;
                              _pageNo = 1;
                            });
                            _load();
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                if (_loading && p == null)
                  const SliverFillRemaining(child: Center(child: CircularProgressIndicator(color: Color(0xFF62BF39))))
                else if (_err != null)
                  SliverFillRemaining(
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.error_outline_rounded, size: 48, color: Color(0xFFEF4444)),
                          const SizedBox(height: 12),
                          Text(_err!, style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFFEF4444))),
                          TextButton(onPressed: _bootstrap, child: const Text('Thử lại')),
                        ],
                      ),
                    ),
                  )
                else if (p == null || p.items.isEmpty)
                  SliverFillRemaining(
                    child: _Empty(
                      title: t.tr(vi: 'Không có sản phẩm.', en: 'No products.'),
                      subtitle: t.tr(vi: 'Thử đổi bộ lọc hoặc tìm kiếm.', en: 'Try filters or search.'),
                    ),
                  )
                else ...[
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          if (index == p.items.length) {
                            return _Pager(
                              page: p.page,
                              pageSize: p.pageSize,
                              totalCount: p.totalCount,
                              onPrev: p.page <= 1
                                  ? null
                                  : () {
                                      setState(() => _pageNo = (_pageNo - 1).clamp(1, 9999));
                                      _load();
                                    },
                              onNext: (p.page * p.pageSize) >= p.totalCount
                                  ? null
                                  : () {
                                      setState(() => _pageNo = _pageNo + 1);
                                      _load();
                                    },
                            );
                          }
                          return _ProductCard(r: p.items[index], onMenu: () => _openMenu(p.items[index]));
                        },
                        childCount: p.items.length + 1,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (_loading && p != null)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: LinearProgressIndicator(minHeight: 2, backgroundColor: Colors.transparent, color: const Color(0xFF62BF39).withValues(alpha: 0.5)),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final ok = await Navigator.of(context).push<bool>(
            MaterialPageRoute(builder: (_) => const AdminProductUpsertScreen.create()),
          );
          if (!mounted) return;
          if (ok == true) await _bootstrap();
        },
        backgroundColor: const Color(0xFF62BF39),
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: Text(t.tr(vi: 'Thêm sản phẩm', en: 'Add product'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}

class _SearchBox extends StatelessWidget {
  final TextEditingController controller;
  final AppLocalizations t;
  const _SearchBox({required this.controller, required this.t});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: TextField(
        controller: controller,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        decoration: InputDecoration(
          hintText: t.tr(vi: 'Tìm theo tên, SKU...', en: 'Search name, SKU...'),
          hintStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 14),
          prefixIcon: Icon(Icons.search_rounded, color: theme.colorScheme.onSurfaceVariant),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }
}

class _Stats extends StatelessWidget {
  final AdminProductStats stats;
  const _Stats({required this.stats});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _StatItem(label: 'Tất cả', value: '${stats.total}', color: const Color(0xFF62BF39)),
          const SizedBox(width: 12),
          _StatItem(label: 'Hết hàng', value: '${stats.outOfStock}', color: const Color(0xFFEF4444)),
          const SizedBox(width: 12),
          _StatItem(label: 'Giảm giá', value: '${stats.onSale}', color: const Color(0xFFEC4899)),
          const SizedBox(width: 12),
          _StatItem(label: 'Tồn kho', value: Formatters.vnd(stats.inventoryValue), color: theme.colorScheme.primary),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _StatItem({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 12)),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 18)),
        ],
      ),
    );
  }
}

class _Filters extends StatelessWidget {
  final List<Category> categories;
  final int? categoryId;
  final String status;
  final ValueChanged<int?> onCategoryChanged;
  final ValueChanged<String> onStatusChanged;

  const _Filters({
    required this.categories,
    required this.categoryId,
    required this.status,
    required this.onCategoryChanged,
    required this.onStatusChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('DANH MỤC', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: muted, letterSpacing: 1)),
        const SizedBox(height: 8),
        SizedBox(
          height: 38,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _FilterPill(
                label: 'Tất cả',
                selected: categoryId == null,
                onTap: () => onCategoryChanged(null),
              ),
              ...categories.map((c) => _FilterPill(
                    label: c.name,
                    selected: categoryId == c.id,
                    onTap: () => onCategoryChanged(c.id),
                  )),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text('TRẠNG THÁI', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: muted, letterSpacing: 1)),
        const SizedBox(height: 8),
        Row(
          children: [
            _FilterPill(label: 'Tất cả', selected: status == 'all', onTap: () => onStatusChanged('all')),
            _FilterPill(label: 'Hoạt động', selected: status == 'Active', onTap: () => onStatusChanged('Active')),
            _FilterPill(label: 'Ngừng bán', selected: status == 'Inactive', onTap: () => onStatusChanged('Inactive')),
          ],
        ),
      ],
    );
  }
}

class _FilterPill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _FilterPill({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bg = selected ? const Color(0xFF62BF39) : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35);
    final fg = selected ? Colors.white : theme.colorScheme.onSurface;
    final border = selected ? const Color(0xFF62BF39) : theme.colorScheme.outlineVariant;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: border),
            boxShadow: selected ? [BoxShadow(color: const Color(0xFF62BF39).withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 4))] : [],
          ),
          child: Text(
            label,
            style: TextStyle(color: fg, fontWeight: selected ? FontWeight.w900 : FontWeight.w700, fontSize: 13),
          ),
        ),
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  final AdminProductRow r;
  final VoidCallback onMenu;
  const _ProductCard({required this.r, required this.onMenu});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final img = ApiConfig.resolveMediaUrl(r.imageUrl);
    final unit = (r.unit ?? '').trim();
    final hasDiscount = (r.discountPrice ?? 0) > 0 && (r.discountPrice ?? 0) < r.price;
    final finalPrice = hasDiscount ? (r.discountPrice ?? r.price) : r.price;
    final isInactive = r.status.trim().toLowerCase() == 'inactive';
    final stockTone = r.stockQuantity <= 0 ? const Color(0xFFEF4444) : (r.isLowStock ? const Color(0xFFF59E0B) : const Color(0xFF10B981));
    final statusTone = isInactive ? const Color(0xFF64748B) : const Color(0xFF10B981);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: theme.colorScheme.shadow.withValues(alpha: 0.06), blurRadius: 10, offset: const Offset(0, 4)),
        ],
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      width: 80,
                      height: 80,
                      color: theme.colorScheme.surfaceContainerHighest,
                      child: img.isEmpty
                          ? Icon(Icons.image_not_supported_outlined, color: theme.colorScheme.onSurfaceVariant)
                          : Image.network(
                              img,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Icon(Icons.broken_image_outlined, color: theme.colorScheme.onSurfaceVariant),
                            ),
                    ),
                  ),
                  if (hasDiscount)
                    Positioned(
                      top: 4,
                      left: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: const Color(0xFFEC4899), borderRadius: BorderRadius.circular(6)),
                        child: const Text('SALE', style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w900)),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(r.productName, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
                        ),
                        GestureDetector(onTap: onMenu, child: Icon(Icons.more_horiz_rounded, color: theme.colorScheme.onSurfaceVariant)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text('SKU: ${r.sku}', style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      children: [
                        if (r.categoryName != null) _MiniTag(label: r.categoryName!, color: Colors.blueGrey),
                        if (r.supplierName != null) _MiniTag(label: r.supplierName!, color: Colors.orange),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (hasDiscount)
                    Text(
                      Formatters.vnd(r.price),
                      style: TextStyle(
                        color: theme.colorScheme.onSurface,
                        decoration: TextDecoration.lineThrough,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  Text(
                    Formatters.vnd(finalPrice),
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFFFF8A00),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: statusTone.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(width: 6, height: 6, decoration: BoxDecoration(color: statusTone, shape: BoxShape.circle)),
                    const SizedBox(width: 6),
                    Text(r.status == 'Active' ? 'Hoạt động' : 'Ngừng bán', style: TextStyle(color: statusTone, fontWeight: FontWeight.w900, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Tồn kho: ${r.stockQuantity} ${unit.isNotEmpty ? unit : 'sản phẩm'}',
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                        ),
                        if (r.isLowStock) const Icon(Icons.warning_amber_rounded, size: 14, color: Color(0xFFF59E0B)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: (r.stockQuantity <= 0 ? 0.0 : (r.stockQuantity / (r.isLowStock ? 20 : 100)).clamp(0.1, 1.0)).toDouble(),
                        backgroundColor: const Color(0xFFF1F5F9),
                        color: stockTone,
                        minHeight: 6,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniTag extends StatelessWidget {
  final String label;
  final Color color;
  const _MiniTag({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w800)),
    );
  }
}

class _Pager extends StatelessWidget {
  final int page;
  final int pageSize;
  final int totalCount;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;
  const _Pager({required this.page, required this.pageSize, required this.totalCount, required this.onPrev, required this.onNext});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final from = totalCount == 0 ? 0 : ((page - 1) * pageSize + 1);
    final to = (page * pageSize).clamp(0, totalCount);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '$from - $to / $totalCount sản phẩm',
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontWeight: FontWeight.w700, fontSize: 12),
            ),
          ),
          IconButton(
            onPressed: onPrev,
            icon: Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: onPrev == null ? theme.colorScheme.outlineVariant : theme.colorScheme.onSurface),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: onNext,
            icon: Icon(Icons.arrow_forward_ios_rounded, size: 18, color: onNext == null ? theme.colorScheme.outlineVariant : theme.colorScheme.onSurface),
          ),
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  final String title;
  final String subtitle;
  const _Empty({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              shape: BoxShape.circle,
              border: Border.all(color: theme.colorScheme.outlineVariant),
              boxShadow: [BoxShadow(color: theme.colorScheme.shadow.withValues(alpha: 0.06), blurRadius: 20)],
            ),
            child: const Icon(Icons.inventory_2_outlined, size: 64, color: Color(0xFF62BF39)),
          ),
          const SizedBox(height: 24),
          Text(title, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Text(subtitle, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
