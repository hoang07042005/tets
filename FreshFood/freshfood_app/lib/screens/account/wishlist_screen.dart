import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:freshfood_app/api/api_client.dart';
import 'package:freshfood_app/config/api_config.dart';
import 'package:freshfood_app/models/product.dart';
import 'package:freshfood_app/screens/product/product_detail_screen.dart';
import 'package:freshfood_app/state/auth_state.dart';
import 'package:freshfood_app/state/nav_state.dart';
import 'package:freshfood_app/state/wishlist_state.dart';
import 'package:freshfood_app/l10n/app_localizations.dart';
import 'package:freshfood_app/ui/formatters.dart';

class WishlistScreen extends StatefulWidget {
  const WishlistScreen({super.key});

  @override
  State<WishlistScreen> createState() => _WishlistScreenState();
}

class _WishlistScreenState extends State<WishlistScreen> {
  final _api = ApiClient();
  bool _loading = true;
  String? _err;
  List<Product> _items = const <Product>[];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final t = AppLocalizations.of(context);
    final u = AuthState.currentUser.value;
    if (u == null) {
      setState(() {
        _loading = false;
        _items = const <Product>[];
      });
      return;
    }

    setState(() {
      _loading = true;
      _err = null;
    });
    try {
      final xs = await _api.getWishlistProducts(u.userId);
      if (!mounted) return;
      setState(() => _items = xs);
      // keep ids in sync for hearts across app
      // ignore: discarded_futures
      WishlistState.refreshIds();
    } catch (e) {
      if (!mounted) return;
      setState(() => _err = t.tr(vi: 'Không tải được danh sách yêu thích.', en: 'Failed to load wishlist.'));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _continueShopping() {
    NavState.tabIndex.value = 1; // Products tab
    Navigator.of(context).pop();
  }

  void _removeLocal(int productId) {
    setState(() => _items = _items.where((x) => x.id != productId).toList(growable: false));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = AppLocalizations.of(context);
    final u = AuthState.currentUser.value;

    return Scaffold(
      appBar: AppBar(title: Text(t.tr(vi: 'Yêu thích', en: 'Wishlist'))),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(t.tr(vi: 'Yêu thích', en: 'Wishlist'), style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
                      const SizedBox(height: 6),
                      Text(
                        t.tr(vi: 'Những sản phẩm bạn đã lưu để mua sau.', en: 'Products you saved to buy later.'),
                        style: theme.textTheme.bodyMedium?.copyWith(color: const Color(0xFF64748B), fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton(
                  onPressed: _continueShopping,
                  style: FilledButton.styleFrom(backgroundColor: const Color(0xFF62BF39), foregroundColor: Colors.white),
                  child: Text(t.tr(vi: 'Tiếp tục mua sắm', en: 'Continue shopping')),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (u == null)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  color: theme.colorScheme.surface,
                  border: Border.all(color: theme.colorScheme.outlineVariant),
                ),
                child: Column(
                  children: [
                    Icon(Icons.favorite_border, size: 46, color: const Color(0xFF94A3B8).withValues(alpha: 0.9)),
                    const SizedBox(height: 10),
                    Text(t.tr(vi: 'Bạn chưa đăng nhập', en: 'You are not signed in'), style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
                    const SizedBox(height: 6),
                    Text(
                      t.tr(vi: 'Vui lòng đăng nhập để xem danh sách yêu thích.', en: 'Please sign in to view your wishlist.'),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(color: const Color(0xFF64748B)),
                    ),
                  ],
                ),
              )
            else if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_err != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Text(_err!, style: theme.textTheme.bodyMedium?.copyWith(color: const Color(0xFFB91C1C), fontWeight: FontWeight.w800)),
              )
            else if (_items.isEmpty)
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  color: theme.colorScheme.surface,
                  border: Border.all(color: theme.colorScheme.outlineVariant),
                ),
                child: Column(
                  children: [
                    Icon(Icons.favorite_border, size: 44, color: const Color(0xFF94A3B8).withValues(alpha: 0.9)),
                    const SizedBox(height: 10),
                    Text(t.tr(vi: 'Chưa có sản phẩm yêu thích', en: 'No saved products'), style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
                    const SizedBox(height: 6),
                    Text(
                      t.tr(vi: 'Hãy bấm vào icon trái tim để lưu sản phẩm.', en: 'Tap the heart icon to save products.'),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(color: const Color(0xFF64748B)),
                    ),
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
                    itemBuilder: (context, i) => _WishlistCard(
                      product: _items[i],
                      onTap: () {
                        final p = _items[i];
                        final token = p.productToken?.trim();
                        final idOrToken = (token != null && token.isNotEmpty) ? token : '${p.id}';
                        Navigator.of(context).push(MaterialPageRoute(builder: (_) => ProductDetailScreen(tokenOrId: idOrToken)));
                      },
                      onUnwished: _removeLocal,
                    ),
                  );
                },
              ),
            const SizedBox(height: 18),
          ],
        ),
      ),
    );
  }
}

class _WishlistCard extends StatelessWidget {
  final Product product;
  final VoidCallback onTap;
  final void Function(int productId) onUnwished;
  const _WishlistCard({required this.product, required this.onTap, required this.onUnwished});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final unit = (product.unit ?? '').trim();
    final hasSale = product.discountPrice != null && product.discountPrice! < product.price;
    final sell = hasSale ? product.discountPrice! : product.price;
    final img = ApiConfig.resolveMediaUrl(product.mainImageUrl);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: theme.colorScheme.surface,
          border: Border.all(color: theme.colorScheme.outlineVariant),
          boxShadow: [
            BoxShadow(color: const Color(0xFF0F172A).withValues(alpha: 0.08), blurRadius: 18, offset: const Offset(0, 10)),
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
                        : CachedNetworkImage(
                            imageUrl: img,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => Container(color: theme.colorScheme.surfaceContainerHighest),
                            errorWidget: (_, __, ___) =>
                                Container(color: theme.colorScheme.surfaceContainerHighest, child: const Icon(Icons.broken_image)),
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
                              final next = await WishlistState.toggle(product.id);
                              if (!next) onUnwished(product.id);
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
                              color: theme.colorScheme.surface.withValues(alpha: 0.92),
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
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    (product.categoryName ?? 'SẢN PHẨM').trim().isEmpty ? 'SẢN PHẨM' : (product.categoryName ?? 'SẢN PHẨM').toUpperCase(),
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
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              spacing: 4,
                              runSpacing: 0,
                              crossAxisAlignment: WrapCrossAlignment.end,
                              children: [
                                FittedBox(
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
                        child: ElevatedButton(
                          onPressed: onTap,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF62BF39),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            textStyle: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.visibility_outlined, size: 18, color: Colors.white),
                              SizedBox(width: 6),
                              Text('Xem'),
                            ],
                          ),
                        ),
                      ),
                    ],
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

