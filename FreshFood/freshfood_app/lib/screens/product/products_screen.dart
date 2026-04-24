import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:freshfood_app/api/api_client.dart';
import 'package:freshfood_app/config/api_config.dart';
import 'package:freshfood_app/models/category.dart';
import 'package:freshfood_app/models/product.dart';
import 'package:freshfood_app/screens/product/product_detail_screen.dart';
import 'package:freshfood_app/l10n/app_localizations.dart';
import 'package:freshfood_app/state/cart_state.dart';
import 'package:freshfood_app/state/wishlist_state.dart';
import 'package:freshfood_app/ui/formatters.dart';

enum ProductSort { newest, priceAsc, priceDesc, nameAsc }

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  final _api = ApiClient();
  final _searchCtl = TextEditingController();

  List<Category> _categories = const [];
  List<Product> _allProducts = const [];
  List<Product> _products = const [];

  bool _loading = true;
  bool _gridRefreshing = false;
  String? _error;

  int? _selectedCatId;
  ProductSort _sortBy = ProductSort.newest;

  bool _priceUnlimited = true;
  double _priceMinK = 10;
  double _priceMaxK = 1000;
  double _maxPriceK = 1000;

  final List<String> _activeCerts = [];

  int _page = 1;
  static const int _itemsPerPage = 18;

  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _searchCtl.addListener(() {
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 350), () {
        if (!mounted) return;
        // Search is client-side to avoid calling API on every keystroke.
        setState(() => _page = 1);
      });
    });
    _loadInit();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtl.dispose();
    super.dispose();
  }

  Future<void> _loadInit() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _api.getCategories(),
        _api.getProducts(),
      ]);

      final cats = (results[0] as List<Category>);
      final all = (results[1] as List<Product>);
      if (!mounted) return;

      setState(() {
        _categories = cats;
        _allProducts = all;
        _products = List<Product>.from(all);
        _page = 1;
      });

      _syncPriceBounds();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Không tải được dữ liệu.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  double _sellingPriceVnd(Product p) {
    final d = p.discountPrice;
    if (d != null && d < p.price) return d;
    return p.price;
  }

  void _syncPriceBounds() {
    if (_allProducts.isEmpty) {
      setState(() {
        _priceMinK = 10;
        _priceMaxK = 1000;
        _maxPriceK = 1000;
      });
      return;
    }
    final maxVnd = _allProducts.map(_sellingPriceVnd).fold<double>(0, (mx, v) => v > mx ? v : mx);
    final k = (maxVnd / 1000).ceil().toDouble();
    final rounded = ((k / 10).ceil() * 10).clamp(10, 1000000).toDouble();
    setState(() {
      _maxPriceK = rounded;
      _priceMinK = _priceMinK.clamp(10, rounded);
      _priceMaxK = _priceMaxK.clamp(10, rounded);
      if (_priceMinK > _priceMaxK) _priceMinK = _priceMaxK;
    });
  }

  Future<void> _loadProducts() async {
    final t = AppLocalizations.of(context);
    final hadData = _products.isNotEmpty;
    setState(() {
      _error = null;
      _gridRefreshing = hadData;
      if (!hadData) _loading = true;
    });
    try {
      final list = await _api.getProducts(
        categoryId: _selectedCatId,
      );
      if (!mounted) return;
      setState(() {
        _products = List<Product>.from(list);
        _page = 1;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = t.tr(vi: 'Không tải được sản phẩm.', en: 'Failed to load products.');
        _products = const [];
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _gridRefreshing = false;
        });
      }
    }
  }

  Map<int, int> get _categoryCounts {
    final counts = <int, int>{};
    for (final p in _allProducts) {
      if (p.categoryId != null) counts[p.categoryId!] = (counts[p.categoryId!] ?? 0) + 1;
    }
    return counts;
  }

  int get _activeFilterCount {
    var n = 0;
    if (_selectedCatId != null) n += 1;
    if (!_priceUnlimited) n += 1;
    n += _activeCerts.length;
    return n;
  }

  List<Product> get _filtered {
    var list = List<Product>.from(_products);

    final q = _searchCtl.text.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list.where((p) => p.name.toLowerCase().contains(q)).toList();
    }

    if (!_priceUnlimited) {
      final lo = _priceMinK * 1000;
      final hi = _priceMaxK * 1000;
      list = list.where((p) {
        final v = _sellingPriceVnd(p);
        return v >= lo && v <= hi;
      }).toList();
    }

    if (_activeCerts.isNotEmpty) {
      list = list.where((p) {
        final name = p.name.toLowerCase();
        return _activeCerts.any((cert) {
          if (cert == 'Hữu cơ') return name.contains('organic') || name.contains('hữu cơ') || name.contains('cà chua');
          if (cert == 'Địa phương') return name.contains('local') || name.contains('địa phương') || name.contains('cà rốt');
          return cert == 'Chứng nhận';
        });
      }).toList();
    }

    list.sort((a, b) {
      switch (_sortBy) {
        case ProductSort.priceAsc:
          return _sellingPriceVnd(a).compareTo(_sellingPriceVnd(b));
        case ProductSort.priceDesc:
          return _sellingPriceVnd(b).compareTo(_sellingPriceVnd(a));
        case ProductSort.nameAsc:
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        case ProductSort.newest:
          return (b.id).compareTo(a.id);
      }
    });

    return list;
  }

  Future<void> _openFilters() async {
    final theme = Theme.of(context);
    final beforeCat = _selectedCatId;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(8))),
      builder: (context) {
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
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text('Bộ lọc', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
                          const Spacer(),
                          if (_activeFilterCount > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFF62BF39).withValues(alpha: 0.10),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text('$_activeFilterCount', style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF62BF39))),
                            ),
                          const SizedBox(width: 8),
                          IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            tooltip: 'Đóng',
                            icon: const Icon(Icons.close_rounded),
                            visualDensity: VisualDensity.compact,
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Text('Danh mục', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
                      const SizedBox(height: 10),
                      _CatRow(
                        title: 'Tất cả sản phẩm',
                        count: _allProducts.length,
                        active: _selectedCatId == null,
                        onTap: () => setLocal(() => _selectedCatId = null),
                      ),
                      for (final c in _categories)
                        _CatRow(
                          title: c.name,
                          count: _categoryCounts[c.id] ?? 0,
                          active: _selectedCatId == c.id,
                          onTap: () => setLocal(() => _selectedCatId = c.id),
                        ),
                      const SizedBox(height: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Khoảng giá (theo giá bán)',
                            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 2),
                          Align(
                            alignment: Alignment.centerRight,
                            child: Text(
                              _priceUnlimited
                                  ? '(tất cả)'
                                  : '(${Formatters.vnd((_priceMinK * 1000).roundToDouble())}đ – ${Formatters.vnd((_priceMaxK * 1000).roundToDouble())}đ)',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(color: const Color(0xFF6B7280), fontWeight: FontWeight.w900),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      CheckboxListTile(
                        value: _priceUnlimited,
                        onChanged: (v) {
                          final on = v ?? true;
                          setLocal(() {
                            _priceUnlimited = on;
                            if (!on) {
                              _priceMinK = 10;
                              _priceMaxK = _maxPriceK;
                              if (_priceMaxK < _priceMinK) _priceMaxK = _priceMinK;
                            }
                            _page = 1;
                          });
                        },
                        contentPadding: EdgeInsets.zero,
                        activeColor: const Color(0xFF62BF39),
                        checkColor: Colors.white,
                        title: const Text('Không lọc theo khoảng giá'),
                      ),
                      if (!_priceUnlimited) ...[
                        const SizedBox(height: 6),
                        _RangeRow(label: 'Từ', valueVnd: (_priceMinK * 1000).round()),
                        RangeSlider(
                          values: RangeValues(_priceMinK, _priceMaxK),
                          min: 10,
                          max: _maxPriceK <= 10 ? 1000 : _maxPriceK,
                          divisions: ((_maxPriceK <= 10 ? 1000 : _maxPriceK) / 10).round().clamp(1, 10000),
                          activeColor: const Color(0xFF62BF39),
                          onChanged: (v) {
                            setLocal(() {
                              _priceMinK = v.start.roundToDouble();
                              _priceMaxK = v.end.roundToDouble();
                              if (_priceMinK > _priceMaxK) _priceMinK = _priceMaxK;
                            });
                          },
                        ),
                        _RangeRow(label: 'Đến', valueVnd: (_priceMaxK * 1000).round()),
                        const SizedBox(height: 6),
                        Text(
                          'Áp dụng theo giá đang bán (ưu tiên giá khuyến mãi nếu có).',
                          style: theme.textTheme.bodySmall?.copyWith(color: const Color(0xFF6B7280)),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Text('10.000đ', style: theme.textTheme.bodySmall?.copyWith(color: const Color(0xFF94A3B8), fontWeight: FontWeight.w800)),
                            const Spacer(),
                            Text(
                              '${Formatters.vnd((_maxPriceK * 1000).roundToDouble())}đ',
                              style: theme.textTheme.bodySmall?.copyWith(color: const Color(0xFF94A3B8), fontWeight: FontWeight.w800),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 16),
                      Text('Tiêu chuẩn nông sản', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          _CertPill(
                            label: 'Hữu cơ',
                            icon: Icons.eco_outlined,
                            active: _activeCerts.contains('Hữu cơ'),
                            onTap: () => setLocal(() => _toggleCert('Hữu cơ')),
                          ),
                          _CertPill(
                            label: 'Chứng nhận',
                            icon: Icons.verified_outlined,
                            active: _activeCerts.contains('Chứng nhận'),
                            onTap: () => setLocal(() => _toggleCert('Chứng nhận')),
                          ),
                          _CertPill(
                            label: 'Địa phương',
                            icon: Icons.place_outlined,
                            active: _activeCerts.contains('Địa phương'),
                            onTap: () => setLocal(() => _toggleCert('Địa phương')),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                setLocal(() {
                                  _selectedCatId = null;
                                  _priceUnlimited = true;
                                  _activeCerts.clear();
                                  _syncPriceBounds();
                                });
                              },
                              style: OutlinedButton.styleFrom(
                                foregroundColor: theme.colorScheme.onSurface,
                                side: BorderSide(color: theme.colorScheme.outlineVariant),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                backgroundColor: theme.colorScheme.surface,
                              ),
                              child: const Text('Xóa bộ lọc'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton(
                              onPressed: () async {
                                Navigator.of(context).pop();
                                if (!mounted) return;
                                // Price/certs/sort are client-side; only reload from API when category changes.
                                if (beforeCat != _selectedCatId) {
                                  await _loadProducts();
                                } else {
                                  setState(() => _page = 1);
                                }
                              },
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFF62BF39),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                              child: const Text('Áp dụng'),
                            ),
                          ),
                        ],
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
  }

  void _toggleCert(String cert) {
    if (_activeCerts.contains(cert)) {
      _activeCerts.remove(cert);
    } else {
      _activeCerts.add(cert);
    }
    setState(() {
      _page = 1;
    });
  }

  String get _sortLabel {
    switch (_sortBy) {
      case ProductSort.newest:
        return 'Mới nhất';
      case ProductSort.priceAsc:
        return 'Giá tăng dần';
      case ProductSort.priceDesc:
        return 'Giá giảm dần';
      case ProductSort.nameAsc:
        return 'Tên A–Z';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filtered = _filtered;
    final totalPages = (filtered.length / _itemsPerPage).ceil().clamp(1, 1000000);
    final start = (_page - 1) * _itemsPerPage;
    final end = (start + _itemsPerPage).clamp(0, filtered.length);
    final paged = (start >= filtered.length || start < 0) ? const <Product>[] : filtered.sublist(start, end);

    return RefreshIndicator(
      onRefresh: _loadInit,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Thực phẩm sạch –\nTươi ngon mỗi ngày',
                      style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900, height: 1.05),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Có ${filtered.length} nông sản tươi ngon cho bạn lựa chọn.',
                      style: theme.textTheme.bodyMedium?.copyWith(color: const Color(0xFF4B5563), fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              IconButton(
                onPressed: _openFilters,
                tooltip: 'Bộ lọc',
                icon: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    const Icon(Icons.tune_rounded),
                    if (_activeFilterCount > 0)
                      Positioned(
                        right: -6,
                        top: -6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF8A00),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            '$_activeFilterCount',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 11),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _SearchField(
                  controller: _searchCtl,
                  hint: 'Tìm theo tên sản phẩm…',
                ),
              ),
              const SizedBox(width: 10),
              PopupMenuButton<ProductSort>(
                tooltip: 'Sắp xếp',
                onSelected: (v) => setState(() {
                  _sortBy = v;
                  _page = 1;
                }),
                itemBuilder: (context) => const [
                  PopupMenuItem(value: ProductSort.newest, child: Text('Mới nhất')),
                  PopupMenuItem(value: ProductSort.priceAsc, child: Text('Giá tăng dần')),
                  PopupMenuItem(value: ProductSort.priceDesc, child: Text('Giá giảm dần')),
                  PopupMenuItem(value: ProductSort.nameAsc, child: Text('Tên A–Z')),
                ],
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: theme.colorScheme.outlineVariant),
                    color: theme.colorScheme.surface,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_sortLabel, style: const TextStyle(fontWeight: FontWeight.w900)),
                      const SizedBox(width: 6),
                      const Icon(Icons.keyboard_arrow_down_rounded),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (_loading && _products.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 60),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            _ErrorBox(message: _error!, onRetry: _loadInit)
          else if (filtered.isEmpty && !_gridRefreshing)
            _EmptyBox(
              onClear: () {
                setState(() {
                  _selectedCatId = null;
                  _priceUnlimited = true;
                  _activeCerts.clear();
                  _sortBy = ProductSort.newest;
                  _page = 1;
                });
                _searchCtl.clear();
                _syncPriceBounds();
                _loadProducts();
              },
            )
          else
            Stack(
              children: [
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: paged.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    // Slightly taller tiles to avoid overflow on smaller devices.
                    childAspectRatio: 0.62,
                  ),
                  itemBuilder: (context, i) {
                    final p = paged[i];
                    return _ShopProductCard(
                      product: p,
                      onTap: () {
                        final token = p.productToken?.trim();
                        final idOrToken = (token != null && token.isNotEmpty) ? token : '${p.id}';
                        Navigator.of(context).push(MaterialPageRoute(builder: (_) => ProductDetailScreen(tokenOrId: idOrToken)));
                      },
                      onAddToCart: () => CartState.addProduct(p),
                    );
                  },
                ),
                if (_gridRefreshing)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Container(
                        alignment: Alignment.topCenter,
                        padding: const EdgeInsets.only(top: 16),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surface,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: theme.colorScheme.outlineVariant),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 12,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: const Text('Đang lọc…', style: TextStyle(fontWeight: FontWeight.w900)),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          if (!_loading && _error == null && filtered.isNotEmpty) ...[
            const SizedBox(height: 18),
            _Pager(
              page: _page,
              totalPages: totalPages,
              onPrev: _page <= 1 ? null : () => setState(() => _page -= 1),
              onNext: _page >= totalPages ? null : () => setState(() => _page += 1),
            ),
          ],
        ],
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  const _SearchField({required this.controller, required this.hint});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return TextField(
      controller: controller,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: const Icon(Icons.search),
        suffixIcon: ValueListenableBuilder<TextEditingValue>(
          valueListenable: controller,
          builder: (context, v, _) {
            if (v.text.trim().isEmpty) return const SizedBox.shrink();
            return IconButton(
              tooltip: 'Xóa',
              onPressed: controller.clear,
              icon: const Icon(Icons.close_rounded),
            );
          },
        ),
        filled: true,
        fillColor: theme.colorScheme.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF62BF39), width: 1.5),
        ),
      ),
    );
  }
}

class _CatRow extends StatelessWidget {
  final String title;
  final int count;
  final bool active;
  final VoidCallback onTap;
  const _CatRow({required this.title, required this.count, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: active ? const Color(0xFF62BF39).withValues(alpha: 0.08) : Colors.transparent,
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: theme.textTheme.bodyMedium?.copyWith(fontWeight: active ? FontWeight.w900 : FontWeight.w700),
              ),
            ),
            Text(
              '$count',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w900,
                color: active ? const Color(0xFF62BF39) : const Color(0xFF6B7280),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RangeRow extends StatelessWidget {
  final String label;
  final int valueVnd;
  const _RangeRow({required this.label, required this.valueVnd});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Text(label, style: theme.textTheme.bodySmall?.copyWith(color: const Color(0xFF6B7280), fontWeight: FontWeight.w800)),
        const Spacer(),
        Text('${Formatters.vnd(valueVnd.toDouble())}đ', style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w900)),
      ],
    );
  }
}

class _CertPill extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;
  const _CertPill({required this.label, required this.icon, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          // Keep white background like the web design (even in dark mode).
          color: active ? const Color(0xFF62BF39).withValues(alpha: 0.12) : Colors.white,
          border: Border.all(color: active ? const Color(0xFF62BF39).withValues(alpha: 0.35) : theme.colorScheme.outlineVariant),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: active ? const Color(0xFF62BF39) : const Color(0xFF111827)),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(fontWeight: FontWeight.w900, color: active ? const Color(0xFF62BF39) : const Color(0xFF111827)),
            ),
          ],
        ),
      ),
    );
  }
}

class _Pager extends StatelessWidget {
  final int page;
  final int totalPages;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;
  const _Pager({required this.page, required this.totalPages, required this.onPrev, required this.onNext});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          onPressed: onPrev,
          icon: const Icon(Icons.chevron_left_rounded),
          color: theme.colorScheme.onSurfaceVariant,
          style: IconButton.styleFrom(
            backgroundColor: theme.colorScheme.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
            side: BorderSide(color: theme.colorScheme.outlineVariant),
          ),
        ),
        const SizedBox(width: 8),
        Text('$page / $totalPages', style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w900)),
        const SizedBox(width: 8),
        IconButton(
          onPressed: onNext,
          icon: const Icon(Icons.chevron_right_rounded),
          color: theme.colorScheme.onSurfaceVariant,
          style: IconButton.styleFrom(
            backgroundColor: theme.colorScheme.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
            side: BorderSide(color: theme.colorScheme.outlineVariant),
          ),
        ),
      ],
    );
  }
}

class _ErrorBox extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorBox({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outlineVariant),
        color: theme.colorScheme.surface,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(message, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 12),
          FilledButton(onPressed: onRetry, child: const Text('Thử lại')),
        ],
      ),
    );
  }
}

class _EmptyBox extends StatelessWidget {
  final VoidCallback onClear;
  const _EmptyBox({required this.onClear});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: theme.colorScheme.surface,
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        children: [
          Text('Không tìm thấy sản phẩm', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Text(
            'Thử điều chỉnh bộ lọc, khoảng giá hoặc tìm kiếm nhé.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(color: const Color(0xFF6B7280)),
          ),
          const SizedBox(height: 14),
          FilledButton(
            onPressed: onClear,
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF62BF39), foregroundColor: Colors.white),
            child: const Text('Xóa tất cả bộ lọc'),
          ),
        ],
      ),
    );
  }
}

class _ShopProductCard extends StatelessWidget {
  final Product product;
  final VoidCallback onTap;
  final VoidCallback onAddToCart;
  const _ShopProductCard({required this.product, required this.onTap, required this.onAddToCart});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final img = ApiConfig.resolveMediaUrl(product.images.isNotEmpty ? product.images.first.imageUrl : null);
    final unit = (product.unit ?? 'Kg').trim().isEmpty ? 'Kg' : (product.unit ?? 'Kg').trim();

    final hasDiscount = product.discountPrice != null && product.discountPrice! < product.price;
    final sell = hasDiscount ? product.discountPrice! : product.price;

    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Ink(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: theme.colorScheme.outlineVariant),
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
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                child: AspectRatio(
                  aspectRatio: 4 / 3,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: img.isEmpty
                            ? Container(
                                color: theme.colorScheme.surfaceContainerHighest,
                                child: const Icon(Icons.image_not_supported),
                              )
                            : CachedNetworkImage(
                                imageUrl: img,
                                fit: BoxFit.cover,
                                placeholder: (_, __) => Container(color: theme.colorScheme.surfaceContainerHighest),
                                errorWidget: (_, __, ___) => Container(
                                  color: theme.colorScheme.surfaceContainerHighest,
                                  child: const Icon(Icons.broken_image),
                                ),
                              ),
                      ),
                      Positioned(
                        right: 10,
                        top: 10,
                        child: ValueListenableBuilder<Set<int>>(
                          valueListenable: WishlistState.productIdSet,
                          builder: (context, set, _) {
                            final wished = set.contains(product.id);
                            return InkWell(
                              onTap: () async {
                                try {
                                  await WishlistState.toggle(product.id);
                                } catch (e) {
                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
                                }
                              },
                              borderRadius: BorderRadius.circular(999),
                              child: Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  // Keep white background like the web design (even in dark mode).
                                  color: Colors.white.withValues(alpha: 0.95),
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(color: theme.colorScheme.outlineVariant),
                                ),
                                child: Icon(
                                  wished ? Icons.favorite : Icons.favorite_border,
                                  size: 18,
                                  color: wished ? const Color(0xFFEF4444) : const Color(0xFF64748B),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 7, 12, 7),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        (product.categoryName ?? 'Sản phẩm').toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: const Color(0xFF62BF39),
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.6,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        product.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900, height: 1.15),
                      ),
                      const SizedBox(height: 4),
                      if (hasDiscount) ...[
                        Row(
                          children: [
                            Expanded(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  Formatters.vnd(sell),
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 17,
                                    color: const Color(0xFFE67E22),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            Formatters.vnd(product.price),
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontSize: 12,
                              color: const Color(0xFF9AA0A6),
                              decoration: TextDecoration.lineThrough,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ] else ...[
                        Row(
                          children: [
                            Expanded(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  Formatters.vnd(product.price),
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 17,
                                    color: const Color(0xFFE67E22),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      const Spacer(),
                      SizedBox(
                        width: double.infinity,
                        height: 34,
                        child: ElevatedButton.icon(
                          onPressed: onAddToCart,
                          icon: const Icon(Icons.shopping_cart_outlined, size: 17, color: Colors.white),
                          label: const Text('Thêm vào giỏ'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF62BF39),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5),
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

