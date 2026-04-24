import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:freshfood_app/api/api_client.dart';
import 'package:freshfood_app/config/api_config.dart';
import 'package:freshfood_app/models/product.dart';
import 'package:freshfood_app/screens/product/product_detail_screen.dart';
import 'package:freshfood_app/state/cart_state.dart';
import 'package:freshfood_app/state/wishlist_state.dart';
import 'package:freshfood_app/ui/formatters.dart';

class DealsScreen extends StatefulWidget {
  const DealsScreen({super.key});

  @override
  State<DealsScreen> createState() => _DealsScreenState();
}

class _DealsScreenState extends State<DealsScreen> {
  final _api = ApiClient();
  bool _loading = true;
  String? _error;
  List<Product> _items = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await _api.getPromotions();
      if (!mounted) return;
      setState(() => _items = list);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Không tải được khuyến mãi.\nAPI: ${ApiConfig.apiOrigin}\nLỗi: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
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
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    color: const Color(0xFF62BF39).withValues(alpha: 0.12),
                  ),
                  child: const Icon(Icons.local_offer_rounded, color: Color(0xFF62BF39)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Ưu đãi từ FreshFood', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
                      const SizedBox(height: 4),
                      Text(
                        'Combo rau củ quả tươi, eat clean & detox — số lượng có hạn, ưu tiên đơn sớm.',
                        style: theme.textTheme.bodyMedium?.copyWith(color: const Color(0xFF64748B), height: 1.25),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    color: const Color(0xFF62BF39),
                  ),
                  child: const Text('HOT', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 36),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Text(_error!, style: theme.textTheme.bodyMedium?.copyWith(color: const Color(0xFFB91C1C), fontWeight: FontWeight.w800)),
            )
          else if (_items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 22),
              child: Column(
                children: [
                  Icon(Icons.local_offer_outlined, size: 46, color: const Color(0xFF94A3B8).withValues(alpha: 0.9)),
                  const SizedBox(height: 10),
                  Text('Hiện chưa có chương trình khuyến mãi', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 6),
                  Text('Quay lại sau để không bỏ lỡ combo và giá tốt nhé.', style: theme.textTheme.bodyMedium?.copyWith(color: const Color(0xFF64748B))),
                ],
              ),
            )
          else
            LayoutBuilder(
              builder: (context, c) {
                final w = c.maxWidth;
                final crossAxisCount = w >= 900
                    ? 3
                    : w >= 560
                        ? 2
                        : 2;
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.64,
                  ),
                  itemCount: _items.length,
                  itemBuilder: (context, i) {
                    final p = _items[i];
                    return _DealCard(
                      product: p,
                      onTap: () => Navigator.of(context)
                          .push(MaterialPageRoute(builder: (_) => ProductDetailScreen(tokenOrId: p.productToken ?? '${p.id}'))),
                      onAddToCart: () {
                        CartState.addProduct(p);
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Đã thêm "${p.name}" vào giỏ')));
                      },
                    );
                  },
                );
              },
            ),
          const SizedBox(height: 18),
        ],
      ),
    );
  }
}

class _DealCard extends StatelessWidget {
  final Product product;
  final VoidCallback onTap;
  final VoidCallback onAddToCart;
  const _DealCard({required this.product, required this.onTap, required this.onAddToCart});

  int? get _pct {
    final d = product.discountPrice;
    if (d == null) return null;
    if (product.price <= 0) return null;
    if (d >= product.price) return null;
    return (((product.price - d) / product.price) * 100).round().clamp(1, 99);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final unit = (product.unit ?? '').trim();
    final hasSale = product.discountPrice != null && product.discountPrice! < product.price;
    final sell = hasSale ? product.discountPrice! : product.price;
    final main = product.images.where((e) => e.isMainImage).toList();
    final img = ApiConfig.resolveMediaUrl((main.isNotEmpty ? main.first.imageUrl : (product.images.isNotEmpty ? product.images.first.imageUrl : '')));

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
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
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: img.isEmpty
                        ? Container(color: theme.colorScheme.surfaceContainerHighest)
                        : CachedNetworkImage(imageUrl: img, fit: BoxFit.cover),
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
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.92),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
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
                  if (_pct != null)
                    Positioned(
                      left: 10,
                      top: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(999),
                          color: const Color(0xFFEF4444),
                        ),
                        child: Text('-${_pct!}%', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    (product.categoryName ?? 'KHUYẾN MÃI').trim().isEmpty ? 'KHUYẾN MÃI' : (product.categoryName ?? 'KHUYẾN MÃI').toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(color: const Color(0xFF62BF39), fontWeight: FontWeight.w900, letterSpacing: 0.4),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    product.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900, height: 1.15),
                  ),
                  const SizedBox(height: 10),
                  LayoutBuilder(
                    builder: (context, c) {
                      final compactBtn = c.maxWidth < 190;
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
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
                                    )
                                  ],
                                ),
                                if (hasSale)
                                  FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      Formatters.vnd(product.price),
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        fontSize: 12,
                                        color: const Color(0xFF94A3B8),
                                        decoration: TextDecoration.lineThrough,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            height: 38,
                            child: compactBtn
                                ? ElevatedButton(
                                    onPressed: onAddToCart,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF62BF39),
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      padding: const EdgeInsets.symmetric(horizontal: 12),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                    ),
                                    child: const Icon(Icons.shopping_cart_outlined, size: 18, color: Colors.white),
                                  )
                                : ElevatedButton.icon(
                                    onPressed: onAddToCart,
                                    icon: const Icon(Icons.shopping_cart_outlined, size: 18, color: Colors.white),
                                    label: const Text('Thêm'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF62BF39),
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      padding: const EdgeInsets.symmetric(horizontal: 12),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                      textStyle: const TextStyle(fontWeight: FontWeight.w900),
                                    ),
                                  ),
                          ),
                        ],
                      );
                    },
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

