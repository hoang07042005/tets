import 'dart:math';
import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:freshfood_app/api/api_client.dart';
import 'package:freshfood_app/config/api_config.dart';
import 'package:freshfood_app/models/home_settings.dart';
import 'package:freshfood_app/models/product.dart';
import 'package:freshfood_app/models/review.dart';
import 'package:freshfood_app/models/voucher.dart';
import 'package:freshfood_app/screens/account/order/order_track_screen.dart';
import 'package:freshfood_app/screens/product/product_detail_screen.dart';
import 'package:freshfood_app/l10n/app_localizations.dart';
import 'package:freshfood_app/state/auth_state.dart';
import 'package:freshfood_app/state/cart_state.dart';
import 'package:freshfood_app/state/nav_state.dart';
import 'package:freshfood_app/state/wishlist_state.dart';
import 'package:freshfood_app/ui/formatters.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _api = ApiClient();

  bool _loading = true;
  String? _error;
  String? _prefsWarning;
  List<Product> _products = const [];
  List<Voucher> _vouchers = const [];
  List<RecentReview> _recentReviews = const [];
  ReviewSummary _reviewSummary = const ReviewSummary(averageRating: 0, totalReviews: 0);
  HomePageSettings? _homeSettings;

  final _trackOrderCtl = TextEditingController();
  final _trackPhoneCtl = TextEditingController();

  Set<String> _savedVoucherCodes = <String>{};
  String? _copiedCode;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _trackOrderCtl.dispose();
    _trackPhoneCtl.dispose();
    super.dispose();
  }

  Future<void> _loadReviews() async {
    try {
      final results = await Future.wait([
        _api.getRecentReviews(take: 5),
        _api.getReviewSummary(),
      ]);
      if (!mounted) return;
      setState(() {
        _recentReviews = results[0] as List<RecentReview>;
        _reviewSummary = results[1] as ReviewSummary;
      });
    } catch (_) {
      // ignore: non-critical
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _prefsWarning = null;
    });
    try {
      final userId = AuthState.currentUser.value?.userId;
      final results = await Future.wait([
        SharedPreferences.getInstance(),
        _api.getProducts(),
        _api.getActiveVouchers(userId: userId),
        _api.getHomePageSettings(),
      ]);

      final prefs = results[0] as SharedPreferences;
      final saved = prefs.getStringList('freshfood_saved_vouchers') ?? const <String>[];
      final prods = results[1] as List<Product>;
      final vouchers = results[2] as List<Voucher>;
      final homeCfg = results[3] as HomePageSettings?;
      setState(() {
        _products = prods;
        _vouchers = vouchers;
        _homeSettings = homeCfg;
        _savedVoucherCodes = saved.map((e) => e.trim()).where((e) => e.isNotEmpty).toSet();
      });
    } catch (e) {
      setState(() {
        _error = 'Không tải được dữ liệu.';
      });
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }

    // Lazy-load reviews after the primary UI is visible.
    // ignore: discarded_futures
    _loadReviews();
  }

  List<Product> get _featured {
    if (_products.isEmpty) return const [];
    final copy = [..._products];
    copy.shuffle(Random());
    return copy.take(8).toList(growable: false);
  }

  List<RecentReview> get _topReviews {
    final list = [..._recentReviews];
    list.sort((a, b) {
      final r = (b.rating) - (a.rating);
      if (r != 0) return r;
      final tA = a.reviewDate?.millisecondsSinceEpoch ?? 0;
      final tB = b.reviewDate?.millisecondsSinceEpoch ?? 0;
      return tB - tA;
    });
    return list.take(2).toList(growable: false);
  }

  Future<void> _toggleSaveVoucher(String code) async {
    final c = code.trim();
    if (c.isEmpty) return;
    final next = {..._savedVoucherCodes};
    if (next.contains(c)) {
      next.remove(c);
    } else {
      next.add(c);
    }
    setState(() => _savedVoucherCodes = next);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('freshfood_saved_vouchers', next.toList(growable: false));
    } catch (_) {
      // ignore; still allow UI to work without persistence
    }
  }

  Future<void> _copyVoucher(String code) async {
    final c = code.trim();
    if (c.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: c));
    if (!mounted) return;
    setState(() => _copiedCode = c);
    await Future<void>.delayed(const Duration(milliseconds: 1600));
    if (!mounted) return;
    setState(() => _copiedCode = null);
  }

  Widget _sectionTitle(BuildContext context, String title, {Widget? trailing}) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
        if (trailing != null) trailing,
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = AppLocalizations.of(context);
    final hero = _homeSettings?.hero;
    final roots = _homeSettings?.roots;
    final seasonal = _homeSettings?.seasonal;
    final featured = _featured;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_prefsWarning != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: theme.colorScheme.surfaceContainerHighest,
              ),
              child: Text(_prefsWarning!, style: theme.textTheme.bodySmall),
            ),
            const SizedBox(height: 10),
          ],
          _HeroSection(hero: hero),
          const SizedBox(height: 14),

          // Vouchers
          _sectionTitle(context, t.tr(vi: 'Mã giảm giá', en: 'Vouchers')),
          const SizedBox(height: 6),
          if (_copiedCode != null)
            Text(
              t.tr(vi: 'Đã sao chép: $_copiedCode', en: 'Copied: $_copiedCode'),
              style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.primary),
            ),
          const SizedBox(height: 10),
          SizedBox(
            // Keep this tall enough for small devices / larger text scale.
            height: 165,
            child: _loading
                ? const Center(child: LinearProgressIndicator())
                : _VoucherMarquee(
                    vouchers: _vouchers,
                    isSaved: (code) => _savedVoucherCodes.contains(code),
                    onCopy: _copyVoucher,
                    onToggleSave: _toggleSaveVoucher,
                  ),
          ),

          const SizedBox(height: 18),
          // Featured products
          _sectionTitle(
            context,
            t.tr(vi: 'Sản phẩm nổi bật', en: 'Featured products'),
            trailing: TextButton(onPressed: () {}, child: Text(t.tr(vi: 'Xem tất cả >', en: 'View all >'))),
          ),

          if (_error != null) ...[
            const SizedBox(height: 8),
            _ErrorCard(message: _error!, onRetry: _load),
          ],

          const SizedBox(height: 10),
          if (_loading)
            const Center(child: Padding(padding: EdgeInsets.symmetric(vertical: 24), child: CircularProgressIndicator()))
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: featured.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                // Taller tiles to avoid overflow (bigger image + button).
                childAspectRatio: 0.62,
              ),
              itemBuilder: (context, i) => _ProductCard(
                product: featured[i],
                onTap: () {
                  final token = featured[i].productToken?.trim();
                  final idOrToken = (token != null && token.isNotEmpty) ? token : '${featured[i].id}';
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => ProductDetailScreen(tokenOrId: idOrToken)));
                },
                onAddToCart: () => CartState.addProduct(featured[i]),
              ),
            ),

          const SizedBox(height: 40),
          // Our roots
          _RootsSection(roots: roots),

          const SizedBox(height: 40),
          // Seasonal
          _SeasonalSection(seasonal: seasonal),

          const SizedBox(height: 50),
          // Testimonials
          _TestimonialsSection(topReviews: _topReviews, summary: _reviewSummary),

          const SizedBox(height: 18),
          _QuickTrackCard(
            t: t,
            orderController: _trackOrderCtl,
            phoneController: _trackPhoneCtl,
            onSubmit: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => OrderTrackScreen(
                    initialOrderCode: _trackOrderCtl.text.trim(),
                    initialPhone: _trackPhoneCtl.text.trim(),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _QuickTrackCard extends StatelessWidget {
  final AppLocalizations t;
  final TextEditingController orderController;
  final TextEditingController phoneController;
  final VoidCallback onSubmit;

  const _QuickTrackCard({
    required this.t,
    required this.orderController,
    required this.phoneController,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: cs.shadow.withValues(alpha: 0.06), blurRadius: 16, offset: const Offset(0, 8)),
        ],
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: cs.primary.withValues(alpha: 0.22)),
                ),
                child: Icon(Icons.local_shipping_rounded, color: cs.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                t.tr(vi: 'Tra cứu nhanh vận đơn', en: 'Quick tracking'),
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900, color: cs.onSurface),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            t.tr(vi: 'Nhập mã đơn và SĐT để xem trạng thái giao hàng.', en: 'Enter order code and phone to track.'),
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: orderController,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: cs.onSurface),
                  decoration: InputDecoration(
                    hintText: t.tr(vi: 'Mã đơn hàng', en: 'Order ID'),
                    prefixIcon: Icon(Icons.tag_rounded, size: 18, color: cs.onSurfaceVariant),
                    filled: true,
                    fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.55),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: cs.outlineVariant)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: cs.outlineVariant)),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: cs.primary.withValues(alpha: 0.8), width: 1.3),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: cs.onSurface),
                  decoration: InputDecoration(
                    hintText: t.tr(vi: 'Số điện thoại', en: 'Phone'),
                    prefixIcon: Icon(Icons.phone_iphone_rounded, size: 18, color: cs.onSurfaceVariant),
                    filled: true,
                    fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.55),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: cs.outlineVariant)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: cs.outlineVariant)),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: cs.primary.withValues(alpha: 0.8), width: 1.3),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: cs.primary,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(color: cs.primary.withValues(alpha: 0.28), blurRadius: 8, offset: const Offset(0, 4)),
                  ],
                ),
                child: IconButton(
                  onPressed: onSubmit,
                  icon: Icon(Icons.search_rounded, color: cs.onPrimary),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroSection extends StatelessWidget {
  final HomeHeroSettings? hero;
  const _HeroSection({required this.hero});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final eyebrow = hero?.eyebrow?.trim().isNotEmpty == true ? hero!.eyebrow!.trim() : 'FRESH FROM THE FARM';
    final title = hero?.title?.trim().isNotEmpty == true ? hero!.title!.trim() : 'Thực phẩm sạch cho';
    final highlight = hero?.highlight?.trim().isNotEmpty == true ? hero!.highlight!.trim() : 'cuộc sống xanh';
    final subtitle = hero?.subtitle?.trim().isNotEmpty == true
        ? hero!.subtitle!.trim()
        : 'Mang tinh hoa của đất mẹ đến bàn ăn gia đình bạn. Tươi mới, an toàn và bền vững.';
    final imageUrl = ApiConfig.resolveMediaUrl(
      hero?.imageUrl ??
          'https://lh3.googleusercontent.com/aida-public/AB6AXuAn0_mNhh8RAPtDRh5dXiS0PwqdeokDtFRsYYdHuwNzUd8DUP-XK0LCy3fRsasW6dte8-HP5n76MS78rIwCFlIXB_KoyZHUcublemfM8U8s7E-DaT3kwb8Rf-aUW6_ffI3mA1DBRY8A1prT7MxWir9RavBVLMd5uwlQbf2244qVhU9tRG5QKHw5liPbu7L1kboFE0LcFFVg3M20VNc2Z_BT8h-MijK_VjDfGHRrclE6pjmN0dn1X4iVzSCCAvJ7wP8rqExns9kIZA8',
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: AspectRatio(
            // Reduce hero height (less tall than 4/5)
            aspectRatio: 16 / 13,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(color: theme.colorScheme.surfaceContainerHighest),
                  errorWidget: (_, __, ___) => Container(
                    color: theme.colorScheme.surfaceContainerHighest,
                    child: const Icon(Icons.broken_image),
                  ),
                ),
                // Light overlay for readability
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        const Color(0xFF0B2A12).withValues(alpha: 0.22),
                        const Color(0xFF1B5E20).withValues(alpha: 0.10),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.55, 1.0],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Spacer(),
                      Text(eyebrow, style: theme.textTheme.labelMedium?.copyWith(color: Colors.white70)),
                      const SizedBox(height: 10),
                      Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: '$title\n',
                              style: const TextStyle(color: Colors.white),
                            ),
                            TextSpan(
                              text: highlight,
                              style: const TextStyle(color: Color(0xFF62BF39)),
                            ),
                          ],
                        ),
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          height: 1.08,
                          fontSize: 30,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        subtitle,
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white, height: 1.3),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          FilledButton(
                            onPressed: () {
                              final href = hero?.primaryCtaHref?.trim() ?? '';
                              // For now we map common web hrefs to tabs.
                              if (href == '/products') {
                                NavState.tabIndex.value = 1;
                                return;
                              }
                              // Default action: go to Products tab.
                              NavState.tabIndex.value = 1;
                            },
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF62BF39),
                              foregroundColor: Colors.white,
                            ),
                            child: Text(hero?.primaryCtaText?.trim().isNotEmpty == true ? hero!.primaryCtaText!.trim() : 'Khám phá ngay'),
                          ),
                          const SizedBox(width: 10),
                          OutlinedButton(
                            onPressed: () {},
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: BorderSide(color: Colors.white.withValues(alpha: 0.7)),
                            ),
                            child: Text(hero?.secondaryCtaText?.trim().isNotEmpty == true ? hero!.secondaryCtaText!.trim() : 'View Story'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _FeaturePill(
                icon: Icons.local_shipping_outlined,
                title: hero?.feature1Title?.trim().isNotEmpty == true ? hero!.feature1Title!.trim() : 'Giao hàng trong 2h',
                sub: hero?.feature1Sub?.trim().isNotEmpty == true ? hero!.feature1Sub!.trim() : 'Nhanh chóng & tiện lợi',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _FeaturePill(
                icon: Icons.verified_user_outlined,
                title: hero?.feature2Title?.trim().isNotEmpty == true ? hero!.feature2Title!.trim() : 'Đảm bảo ATVSTP',
                sub: hero?.feature2Sub?.trim().isNotEmpty == true ? hero!.feature2Sub!.trim() : 'Kiểm duyệt nghiêm ngặt',
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _FeaturePill extends StatelessWidget {
  final IconData icon;
  final String title;
  final String sub;

  const _FeaturePill({required this.icon, required this.title, required this.sub});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        // No border; softer background.
        color: const Color(0xFF62BF39).withValues(alpha: 0.08),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: theme.colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  final Product product;
  final VoidCallback onTap;
  final VoidCallback onAddToCart;

  const _ProductCard({required this.product, required this.onTap, required this.onAddToCart});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final img = ApiConfig.resolveMediaUrl(product.mainImageUrl);
    final d = product.discountPrice;
    final hasDiscount = d != null && d > 0 && d < product.price;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: theme.colorScheme.surface,
          border: Border.all(color: theme.colorScheme.outlineVariant),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 16,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Fixed aspect-ratio image area for consistent cropping across products.
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
              child: AspectRatio(
                aspectRatio: 4 / 3,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: Container(
                        color: theme.colorScheme.surfaceContainerHighest,
                        child: img.isEmpty
                            ? const Icon(Icons.image_not_supported)
                            : CachedNetworkImage(
                                imageUrl: img,
                                fit: BoxFit.cover,
                                alignment: Alignment.center,
                                placeholder: (_, __) => Container(color: theme.colorScheme.surfaceContainerHighest),
                                errorWidget: (_, __, ___) => const Icon(Icons.broken_image),
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
                  ],
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.categoryName ?? 'Sản phẩm',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.primary),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      product.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
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
                                Formatters.vnd(d),
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
                      height: 38,
                      child: ElevatedButton.icon(
                        onPressed: onAddToCart,
                        icon: const Icon(Icons.shopping_cart_outlined, size: 18, color: Colors.white),
                        label: const Text('Thêm vào giỏ'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF62BF39),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
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
    );
  }
}

class _VoucherCard extends StatelessWidget {
  final Voucher voucher;
  final bool saved;
  final VoidCallback onCopy;
  final VoidCallback onSave;

  const _VoucherCard({required this.voucher, required this.saved, required this.onCopy, required this.onSave});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isPercent = (voucher.discountType ?? '').toLowerCase() == 'percentage';
    final title = isPercent ? 'Giảm ${voucher.discountValue.toStringAsFixed(0)}%' : 'Giảm ${Formatters.vnd(voucher.discountValue)}';
    final minOrder = 'Đơn từ ${Formatters.vnd(voucher.minOrderAmount)}';
    final exp = voucher.expiryDate == null ? 'Không giới hạn' : '${voucher.expiryDate!.day}/${voucher.expiryDate!.month}/${voucher.expiryDate!.year}';

    return Container(
      width: 260,
      height: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        // No border; softer background like feature pills.
        color: const Color(0xFFBDFDCC).withValues(alpha: 0.08),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.local_offer, color: theme.colorScheme.primary, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                voucher.code,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 4),
              Text(
                minOrder,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall,
              ),
              Text(
                'HSD: $exp',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onCopy,
                  icon: const Icon(Icons.copy, size: 18),
                  label: const Text('Sao chép'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF111111),
                    side: BorderSide(color: theme.colorScheme.outlineVariant),
                    backgroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    visualDensity: VisualDensity.compact,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              FilledButton(
                onPressed: onSave,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF10DF6F).withValues(alpha: 0.18),
                  foregroundColor: const Color(0xFF62BF39),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  visualDensity: VisualDensity.compact,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(saved ? 'Đã lưu' : 'Lưu'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _VoucherMarquee extends StatefulWidget {
  final List<Voucher> vouchers;
  final bool Function(String code) isSaved;
  final Future<void> Function(String code) onCopy;
  final Future<void> Function(String code) onToggleSave;

  const _VoucherMarquee({
    required this.vouchers,
    required this.isSaved,
    required this.onCopy,
    required this.onToggleSave,
  });

  @override
  State<_VoucherMarquee> createState() => _VoucherMarqueeState();
}

class _VoucherMarqueeState extends State<_VoucherMarquee> {
  final _controller = ScrollController();
  Timer? _timer;
  bool _userInteracting = false;

  static const _gap = 12.0;
  static const _cardWidth = 260.0;
  static const _speedPxPerTick = 1.2;
  static const _tick = Duration(milliseconds: 16);

  double get _oneLoopWidth {
    final n = widget.vouchers.length;
    if (n == 0) return 0;
    return n * _cardWidth + (n - 1) * _gap;
  }

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void didUpdateWidget(covariant _VoucherMarquee oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.vouchers.length != widget.vouchers.length) {
      // Reset to avoid weird jumps when list size changes.
      if (_controller.hasClients) _controller.jumpTo(0);
    }
  }

  void _start() {
    _timer?.cancel();
    _timer = Timer.periodic(_tick, (_) {
      if (!mounted || _userInteracting) return;
      if (!_controller.hasClients) return;
      final loop = _oneLoopWidth;
      if (loop <= 0) return;
      final next = _controller.offset + _speedPxPerTick;
      if (next >= loop) {
        _controller.jumpTo(next - loop);
      } else {
        _controller.jumpTo(next);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final list = widget.vouchers;
    if (list.isEmpty) {
      return const SizedBox.shrink();
    }

    // Duplicate to create a seamless marquee.
    final doubled = [...list, ...list];

    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n is ScrollStartNotification) _userInteracting = true;
        if (n is ScrollEndNotification) _userInteracting = false;
        return false;
      },
      child: SingleChildScrollView(
        controller: _controller,
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: [
            for (int i = 0; i < doubled.length; i++) ...[
              SizedBox(
                width: _cardWidth,
                child: _VoucherCard(
                  voucher: doubled[i],
                  saved: widget.isSaved(doubled[i].code),
                  onCopy: () => widget.onCopy(doubled[i].code),
                  onSave: () => widget.onToggleSave(doubled[i].code),
                ),
              ),
              if (i != doubled.length - 1) const SizedBox(width: _gap),
            ],
          ],
        ),
      ),
    );
  }
}

class _RootsSection extends StatelessWidget {
  final HomeRootsSettings? roots;
  const _RootsSection({required this.roots});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    String pick(String? v, String fallback) => (v ?? '').trim().isNotEmpty ? v!.trim() : fallback;

    final sub = pick(roots?.subheading, 'OUR ROOTS');
    final title = pick(roots?.title, 'Lớn lên với niềm đam mê, được truyền tải bằng trái tim.');
    final p1 = (roots?.paragraph1 ?? '').trim().isNotEmpty
        ? roots!.paragraph1!.trim()
        :
        'Từ những ngày đầu tại nông trại hữu cơ nhỏ, chúng tôi luôn tin rằng thực phẩm tốt nhất là thực phẩm được nuôi dưỡng bởi tự nhiên.';
    final p2 = (roots?.paragraph2 ?? '').trim().isNotEmpty
        ? roots!.paragraph2!.trim()
        :
        'Mỗi sản phẩm FreshFood đều trải qua kiểm soát nghiêm ngặt. Không hóa chất, không thuốc trừ sâu — chỉ sự tinh khiết cho gia đình bạn.';
    final img = ApiConfig.resolveMediaUrl(
      (roots?.imageUrl ?? '').trim().isNotEmpty
          ? roots!.imageUrl!.trim()
          : 'https://lh3.googleusercontent.com/aida-public/AB6AXuDsj_dBOI4I0rXNR9uejFIaPEYVYQLiGunw26FXWSFWv8bh-uXHvGgsQsg_XTphaN30FjcrZ-zZvN1zLeAy9-L0P21Vb5NEEbJZ-udrnGjuUD8oXHa4P3CgVcJ44tFQXwszRhO4rqxV3sGWuBfqtJ7aAcKYwZpFTiIEiEn6Q0bK0gDvCvPdtucaAkTpSSL_YANkAVAhLYv5EFW-rtmR0wFVAIEamv0iDUPhzmDHsk6HgLEDPQgOGkgMEv47w-wVzGBjlAicFc822N8',
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
          color: const Color(0xFFBDFDCC).withValues(alpha: 0.08)
       
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(sub, style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.primary)),
          const SizedBox(height: 6),
          Text(title, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: CachedNetworkImage(
                imageUrl: img,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(color: theme.colorScheme.surfaceContainerHighest),
                errorWidget: (_, __, ___) => Container(color: theme.colorScheme.surfaceContainerHighest, child: const Icon(Icons.broken_image)),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(p1, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 10),
          Text(p2, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _StatTile(
                  value: pick(roots?.stat1Value, '100%'),
                  label: pick(roots?.stat1Label, 'Organic Certified'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatTile(
                  value: pick(roots?.stat2Value, '24h'),
                  label: pick(roots?.stat2Label, 'Farm to Door'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String value;
  final String label;
  const _StatTile({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: theme.colorScheme.surfaceContainerHighest,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 2),
          Text(label, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _SeasonalSection extends StatelessWidget {
  final HomeSeasonalSettings? seasonal;
  const _SeasonalSection({required this.seasonal});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    String pick(String? v, String fallback) => (v ?? '').trim().isNotEmpty ? v!.trim() : fallback;

    final heading = pick(seasonal?.heading, 'Bộ sưu tập theo mùa');
    final sub = pick(
      seasonal?.subheading,
      'Đón mùa vụ tươi ngon nhất trong năm. Khám phá những bộ sưu tập được tuyển chọn theo mùa vụ hiện tại.',
    );
    final cards = (seasonal?.cards.isNotEmpty == true)
        ? seasonal!.cards.take(3).toList(growable: false)
        : const [
            HomeSeasonalCard(title: 'The Spring Greens', imageUrl: 'https://images.pexels.com/photos/60597/dahlia-red-blossom-bloom-60597.jpeg'),
            HomeSeasonalCard(title: 'Earthy Roots', imageUrl: 'https://images.pexels.com/photos/1301856/pexels-photo-1301856.jpeg'),
            HomeSeasonalCard(title: 'Sun-Kissed Fruits', imageUrl: 'https://images.pexels.com/photos/1132047/pexels-photo-1132047.jpeg'),
          ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(heading, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
        const SizedBox(height: 6),
        Text(sub, style: theme.textTheme.bodyMedium),
        const SizedBox(height: 12),
        SizedBox(
          height: 140,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: cards.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, i) {
              final c = cards[i];
              final img = ApiConfig.resolveMediaUrl(c.imageUrl);
              return Container(
                width: 240,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: theme.colorScheme.outlineVariant),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CachedNetworkImage(
                        imageUrl: img,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => Container(color: theme.colorScheme.surfaceContainerHighest),
                        errorWidget: (_, __, ___) => Container(color: theme.colorScheme.surfaceContainerHighest, child: const Icon(Icons.broken_image)),
                      ),
                      Container(color: Colors.black.withValues(alpha: 0.25)),
                      Positioned(
                        left: 12,
                        right: 12,
                        bottom: 12,
                        child: Text(
                          c.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w900),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        )
      ],
    );
  }
}


class _TestimonialsSection extends StatelessWidget {
  final List<RecentReview> topReviews;
  final ReviewSummary summary;
  const _TestimonialsSection({required this.topReviews, required this.summary});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Được yêu thích bởi\nnhững người đam mê\nẩm thực.',
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w900,
            height: 1.05,
            fontSize: 34,
          ),
        ),
        const SizedBox(height: 14),
        for (final r in topReviews) ...[
          _TestimonialQuote(review: r),
          const SizedBox(height: 18),
        ],
        Row(
          children: [
            _Stars(rating: summary.averageRating),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Rated ${summary.averageRating.toStringAsFixed(1)}/5 • ${summary.totalReviews} reviews',
                style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700, color: const Color(0xFF4B5563)),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _TestimonialQuote extends StatelessWidget {
  final RecentReview review;
  const _TestimonialQuote({required this.review});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = (review.userName ?? 'Khách hàng').trim().isEmpty ? 'Khách hàng' : (review.userName ?? 'Khách hàng').trim();
    final avatarUrl = ApiConfig.resolveMediaUrl(review.avatarUrl);
    final comment = (review.comment ?? '').trim().isNotEmpty ? review.comment!.trim() : 'Sản phẩm rất tươi và chất lượng. Sẽ ủng hộ dài lâu!';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '“',
              style: theme.textTheme.headlineMedium?.copyWith(
                color: const Color(0xFF62BF39),
                fontWeight: FontWeight.w900,
                height: 1,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                comment,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF6B7280),
                  fontStyle: FontStyle.italic,
                  height: 1.45,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: theme.colorScheme.primaryContainer,
              foregroundColor: theme.colorScheme.onPrimaryContainer,
              backgroundImage: avatarUrl.isEmpty ? null : CachedNetworkImageProvider(avatarUrl),
              child: avatarUrl.isEmpty ? Text(name.characters.first.toUpperCase()) : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 2),
                  Text('Khách hàng', style: theme.textTheme.bodySmall?.copyWith(color: const Color(0xFF94A3B8))),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Stars extends StatelessWidget {
  final double rating;
  const _Stars({required this.rating});

  @override
  Widget build(BuildContext context) {
    final full = rating.isNaN ? 0 : rating.round().clamp(0, 5);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        5,
        (i) => Icon(i < full ? Icons.star : Icons.star_border, size: 16, color: Colors.amber),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorCard({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: theme.colorScheme.errorContainer,
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: theme.colorScheme.onErrorContainer),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onErrorContainer),
            ),
          ),
          const SizedBox(width: 10),
          TextButton(onPressed: onRetry, child: const Text('Thử lại')),
        ],
      ),
    );
  }
}

