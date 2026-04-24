import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:freshfood_app/api/api_client.dart';
import 'package:freshfood_app/config/api_config.dart';
import 'package:freshfood_app/models/product.dart';
import 'package:freshfood_app/screens/account/auth/auth_login_screen.dart';
import 'package:freshfood_app/state/auth_state.dart';
import 'package:freshfood_app/state/cart_state.dart';
import 'package:freshfood_app/state/nav_state.dart';
import 'package:freshfood_app/state/wishlist_state.dart';
import 'package:freshfood_app/ui/formatters.dart';
import 'package:image_picker/image_picker.dart';

class ProductDetailScreen extends StatefulWidget {
  final String tokenOrId;
  const ProductDetailScreen({super.key, required this.tokenOrId});

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  final _api = ApiClient();
  Product? _product;
  List<Product> _related = const [];
  String _activeImg = '';
  int _qty = 1;
  bool _loading = true;
  String? _error;

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
      final p = await _api.getProductByTokenOrId(widget.tokenOrId);
      if (!mounted) return;
      setState(() => _product = p);
      if (p == null) {
        setState(() => _error = 'Không tìm thấy sản phẩm.');
        return;
      }

      final main = p.mainImageUrl ?? (p.images.isNotEmpty ? p.images.first.imageUrl : null);
      setState(() {
        _activeImg = ApiConfig.resolveMediaUrl(main);
        _qty = 1;
      });

      // Related products: same category (fallback all)
      final catId = p.categoryId;
      List<Product> rel = const [];
      if (catId != null) {
        rel = await _api.getProducts(categoryId: catId);
        rel = rel.where((x) => x.id != p.id).take(6).toList();
      }
      if (rel.isEmpty) {
        final all = await _api.getProducts();
        rel = all.where((x) => x.id != p.id).take(6).toList();
      }
      if (!mounted) return;
      setState(() => _related = rel);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Không thể tải sản phẩm.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = _product;

    return Scaffold(
      // No AppBar (per requirement). This route is full-screen so it also hides NavigationBar beneath.
      body: SafeArea(
        top: false,
        bottom: false,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_error!, style: theme.textTheme.bodyLarge),
                          const SizedBox(height: 10),
                          FilledButton(onPressed: _load, child: const Text('Thử lại')),
                        ],
                      ),
                    ),
                  )
                : p == null
                    ? const SizedBox.shrink()
                    : CustomScrollView(
                        slivers: [
                          SliverToBoxAdapter(
                            child: Stack(
                              children: [
                                _HeroGallery(
                                  images: p.images,
                                  activeUrl: _activeImg,
                                  onPick: (url) => setState(() => _activeImg = url),
                                ),
                                Positioned(
                                  left: 14,
                                  top: MediaQuery.of(context).padding.top + 12,
                                  child: _RoundIcon(
                                    icon: Icons.arrow_back_rounded,
                                    onTap: () => Navigator.of(context).maybePop(),
                                  ),
                                ),
                                Positioned(
                                  right: 14,
                                  top: MediaQuery.of(context).padding.top + 12,
                                  child: ValueListenableBuilder<Set<int>>(
                                    valueListenable: WishlistState.productIdSet,
                                    builder: (context, set, _) {
                                      final wished = set.contains(p.id);
                                      return _RoundIcon(
                                        icon: wished ? Icons.favorite : Icons.favorite_border,
                                        color: wished ? const Color(0xFFEF4444) : const Color(0xFF111827),
                                        onTap: () async {
                                          try {
                                            await WishlistState.toggle(p.id);
                                          } catch (e) {
                                            if (!context.mounted) return;
                                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
                                          }
                                        },
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                              child: _InfoSection(
                                product: p,
                                qty: _qty,
                                onDec: () => setState(() => _qty = (_qty - 1).clamp(1, 9999)),
                                onInc: () {
                                  final max = (p.stockQuantity ?? 9999);
                                  setState(() => _qty = (_qty + 1).clamp(1, max <= 0 ? 1 : max));
                                },
                                onAdd: () {
                                  final stock = p.stockQuantity ?? 9999;
                                  if (stock <= 0) return;
                                  CartState.addProduct(p, quantity: _qty);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Đã thêm $_qty sản phẩm vào giỏ')),
                                  );
                                },
                              ),
                            ),
                          ),
                          if (_hasFreshSpec(p))
                            SliverToBoxAdapter(
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                                child: _FreshSpecCard(product: p),
                              ),
                            ),
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                              child: _WhySection(),
                            ),
                          ),
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                              child: _RelatedSection(related: _related),
                            ),
                          ),
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                              child: _ReviewsSection(productId: p.id, reviews: _parseReviews(p.reviewsRaw)),
                            ),
                          ),
                        ],
                      ),
      ),
    );
  }
}

bool _hasFreshSpec(Product p) {
  return p.manufacturedDate != null ||
      p.expiryDate != null ||
      (p.origin ?? '').trim().isNotEmpty ||
      (p.storageInstructions ?? '').trim().isNotEmpty ||
      (p.certifications ?? '').trim().isNotEmpty;
}

class ReviewItem {
  final int id;
  final int rating;
  final String? comment;
  final String? adminReply;
  final DateTime? reviewDate;
  final String? userName;
  final String? avatarUrl;
  final List<String> imageUrls;

  const ReviewItem({
    required this.id,
    required this.rating,
    this.comment,
    this.adminReply,
    this.reviewDate,
    this.userName,
    this.avatarUrl,
    this.imageUrls = const [],
  });

  static ReviewItem fromJson(Map<String, dynamic> json) {
    final idRaw = json['reviewID'] ?? json['ReviewID'] ?? 0;
    final id = idRaw is num ? idRaw.toInt() : int.tryParse('$idRaw') ?? 0;

    final ratingRaw = json['rating'] ?? json['Rating'] ?? 0;
    final rating = ratingRaw is num ? ratingRaw.toInt() : int.tryParse('$ratingRaw') ?? 0;

    final commentRaw = json['comment'] ?? json['Comment'];
    final comment = commentRaw == null ? null : (commentRaw is String ? commentRaw : '$commentRaw');

    final replyRaw = json['adminReply'] ?? json['AdminReply'];
    final adminReply = replyRaw == null ? null : (replyRaw is String ? replyRaw : '$replyRaw');

    final dateRaw = json['reviewDate'] ?? json['ReviewDate'];
    DateTime? reviewDate;
    if (dateRaw is String && dateRaw.trim().isNotEmpty) reviewDate = DateTime.tryParse(dateRaw);

    String? userName;
    String? avatarUrl;
    final user = json['user'] ?? json['User'];
    if (user is Map) {
      final u = Map<String, dynamic>.from(user);
      final n = u['fullName'] ?? u['FullName'] ?? u['userName'] ?? u['UserName'];
      userName = n == null ? null : (n is String ? n : '$n');
      final a = u['avatarUrl'] ?? u['AvatarUrl'] ?? u['avatarURL'] ?? u['AvatarURL'];
      avatarUrl = a == null ? null : (a is String ? a : '$a');
    } else {
      final n = json['userName'] ?? json['UserName'];
      userName = n == null ? null : (n is String ? n : '$n');
      final a = json['avatarUrl'] ?? json['AvatarUrl'] ?? json['avatarURL'] ?? json['AvatarURL'];
      avatarUrl = a == null ? null : (a is String ? a : '$a');
    }

    final imagesRaw = json['reviewImages'] ?? json['ReviewImages'] ?? json['images'] ?? json['Images'];
    final tmp = <Map<String, dynamic>>[];
    if (imagesRaw is List) {
      for (final item in imagesRaw) {
        if (item is Map) tmp.add(Map<String, dynamic>.from(item));
      }
    }
    tmp.sort((a, b) {
      final sa = a['sortOrder'] ?? a['SortOrder'] ?? 0;
      final sb = b['sortOrder'] ?? b['SortOrder'] ?? 0;
      final ia = sa is num ? sa.toInt() : int.tryParse('$sa') ?? 0;
      final ib = sb is num ? sb.toInt() : int.tryParse('$sb') ?? 0;
      return ia.compareTo(ib);
    });
    final imageUrls = tmp
        .map((m) => m['imageUrl'] ?? m['imageURL'] ?? m['ImageURL'] ?? m['ImageUrl'])
        .where((x) => x != null)
        .map((x) => ApiConfig.resolveMediaUrl(x is String ? x : '$x'))
        .where((u) => u.trim().isNotEmpty)
        .take(3)
        .toList(growable: false);

    return ReviewItem(
      id: id,
      rating: rating,
      comment: comment,
      adminReply: adminReply,
      reviewDate: reviewDate,
      userName: userName,
      avatarUrl: avatarUrl,
      imageUrls: imageUrls,
    );
  }
}

List<ReviewItem> _parseReviews(List<dynamic> raw) {
  final out = <ReviewItem>[];
  for (final item in raw) {
    if (item is Map) out.add(ReviewItem.fromJson(Map<String, dynamic>.from(item)));
  }
  return out;
}

class _HeroGallery extends StatelessWidget {
  final List<ProductImage> images;
  final String activeUrl;
  final ValueChanged<String> onPick;
  const _HeroGallery({required this.images, required this.activeUrl, required this.onPick});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final resolved = images.map((x) => ApiConfig.resolveMediaUrl(x.imageUrl)).where((u) => u.isNotEmpty).toList();
    final hero = activeUrl.isNotEmpty ? activeUrl : (resolved.isNotEmpty ? resolved.first : '');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AspectRatio(
          aspectRatio: 1.0,
          child: hero.isEmpty
              ? Container(
                  color: theme.colorScheme.surfaceContainerHighest,
                  child: const Icon(Icons.image_not_supported),
                )
              : CachedNetworkImage(
                  imageUrl: hero,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(color: theme.colorScheme.surfaceContainerHighest),
                  errorWidget: (_, __, ___) => Container(
                    color: theme.colorScheme.surfaceContainerHighest,
                    child: const Icon(Icons.broken_image),
                  ),
                ),
        ),
        if (resolved.length > 1)
          SizedBox(
            height: 78,
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              scrollDirection: Axis.horizontal,
              itemCount: resolved.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, i) {
                final url = resolved[i];
                final active = url == hero;
                return InkWell(
                  onTap: () => onPick(url),
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    width: 64,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: active ? const Color(0xFF62BF39) : theme.colorScheme.outlineVariant, width: active ? 2 : 1),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: CachedNetworkImage(
                      imageUrl: url,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(color: theme.colorScheme.surfaceContainerHighest),
                      errorWidget: (_, __, ___) => Container(color: theme.colorScheme.surfaceContainerHighest, child: const Icon(Icons.broken_image, size: 18)),
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

class _RoundIcon extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color? color;
  const _RoundIcon({required this.icon, required this.onTap, this.color});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final iconColor = color ?? theme.colorScheme.onSurface;
    return Material(
      color: theme.colorScheme.surface.withValues(alpha: 0.92),
      shape: const CircleBorder(),
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 42,
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          child: Icon(icon, color: iconColor),
        ),
      ),
    );
  }
}

class _InfoSection extends StatelessWidget {
  final Product product;
  final int qty;
  final VoidCallback onDec;
  final VoidCallback onInc;
  final VoidCallback onAdd;
  const _InfoSection({required this.product, required this.qty, required this.onDec, required this.onInc, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final unit = (product.unit ?? 'kg').trim().isEmpty ? 'kg' : (product.unit ?? 'kg').trim();
    final hasDiscount = product.discountPrice != null && product.discountPrice! < product.price;
    final sell = hasDiscount ? product.discountPrice! : product.price;
    final stock = product.stockQuantity ?? 0;
    final lead = (product.description ?? '').trim().isNotEmpty
        ? product.description!.trim()
        : 'Nông sản được thu hoạch và đóng gói cẩn thận, giữ trọn độ tươi và dinh dưỡng cho bữa ăn gia đình bạn.';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF62BF39).withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            (product.categoryName ?? 'Sản phẩm').toUpperCase(),
            style: theme.textTheme.labelSmall?.copyWith(color: const Color(0xFF62BF39), fontWeight: FontWeight.w900, letterSpacing: 0.8),
          ),
        ),
        const SizedBox(height: 10),
        Text(product.name, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900, height: 1.1)),
        const SizedBox(height: 10),
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.end,
          spacing: 10,
          runSpacing: 6,
          children: [
            Text(Formatters.vnd(sell), style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900, color: Color(0xFFE67E22))),
            if (hasDiscount)
              Text(
                Formatters.vnd(product.price),
                style: theme.textTheme.titleSmall?.copyWith(
                  color: Color(0xFFE67E22),
                  decoration: TextDecoration.lineThrough,
                  fontWeight: FontWeight.w800,
                ),
              ),
            Text('/ $unit', style: theme.textTheme.titleSmall?.copyWith(color: const Color(0xFF6B7280), fontWeight: FontWeight.w900)),
          ],
        ),
        const SizedBox(height: 10),
        Text(lead, style: theme.textTheme.bodyMedium?.copyWith(color: const Color(0xFF4B5563), height: 1.5)),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: (stock > 0 ? const Color(0xFF62BF39) : const Color(0xFFEF4444)).withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            stock > 0 ? 'Còn $stock' : 'Hết hàng',
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w900,
              color: stock > 0 ? const Color(0xFF62BF39) : const Color(0xFFEF4444),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            _QtyBox(qty: qty, onDec: onDec, onInc: onInc, canDec: qty > 1, canInc: stock <= 0 ? false : qty < stock),
            const SizedBox(width: 12),
            Expanded(
              child: SizedBox(
                height: 46,
                child: ElevatedButton.icon(
                  onPressed: stock > 0 ? onAdd : null,
                  icon: const Icon(Icons.shopping_cart_outlined, size: 20, color: Colors.white),
                  label: Text(stock > 0 ? 'Thêm vào giỏ hàng' : 'Hết hàng'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF62BF39),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: theme.colorScheme.surfaceContainerHighest,
                    disabledForegroundColor: const Color(0xFF9AA0A6),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    textStyle: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: const [
            _HintChip(icon: Icons.local_shipping_outlined, text: 'Giao nhanh trong ngày'),
            _HintChip(icon: Icons.verified_outlined, text: 'Nguồn gốc rõ ràng'),
          ],
        ),
      ],
    );
  }
}

class _QtyBox extends StatelessWidget {
  final int qty;
  final VoidCallback onDec;
  final VoidCallback onInc;
  final bool canDec;
  final bool canInc;
  const _QtyBox({required this.qty, required this.onDec, required this.onInc, required this.canDec, required this.canInc});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      height: 46,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outlineVariant),
        color: theme.colorScheme.surface,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: canDec ? onDec : null,
            icon: const Icon(Icons.remove_rounded),
            splashRadius: 22,
          ),
          Text('$qty', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
          IconButton(
            onPressed: canInc ? onInc : null,
            icon: const Icon(Icons.add_rounded),
            splashRadius: 22,
          ),
        ],
      ),
    );
  }
}

class _HintChip extends StatelessWidget {
  final IconData icon;
  final String text;
  const _HintChip({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: const Color(0xFF62BF39).withValues(alpha: 0.08),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: const Color(0xFF62BF39)),
          const SizedBox(width: 8),
          Text(text, style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w900, color: theme.colorScheme.onSurface)),
        ],
      ),
    );
  }
}

class _FreshSpecCard extends StatelessWidget {
  final Product product;
  const _FreshSpecCard({required this.product});

  String _fmtDate(DateTime? d) {
    if (d == null) return '';
    return '${d.day}/${d.month}/${d.year}';
  }

  List<String> _certTags(String s) {
    return s
        .split(RegExp(r'[,;]+'))
        .map((x) => x.trim())
        .where((x) => x.isNotEmpty)
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final certs = _certTags((product.certifications ?? '').trim());

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.colorScheme.outlineVariant),
        color: theme.colorScheme.surface,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Thông tin về nông sản', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 12),
          if (product.manufacturedDate != null || product.expiryDate != null)
            Row(
              children: [
                Expanded(
                  child: _SpecField(
                    icon: Icons.calendar_today_outlined,
                    label: 'Ngày thu hoạch',
                    value: _fmtDate(product.manufacturedDate),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _SpecField(
                    icon: Icons.calendar_today_outlined,
                    label: 'HSD',
                    value: _fmtDate(product.expiryDate),
                  ),
                ),
              ],
            ),
          if ((product.origin ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            _SpecField(icon: Icons.place_outlined, label: 'Nguồn gốc', value: product.origin!.trim()),
          ],
          if ((product.storageInstructions ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            _SpecField(icon: Icons.inventory_2_outlined, label: 'Cách bảo quản', value: product.storageInstructions!.trim()),
          ],
          if (certs.isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.emoji_events_outlined, size: 20, color: Color(0xFF62BF39)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Chứng nhận', style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w900, color: const Color(0xFF6B7280))),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final t in certs)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(999),
                                color: const Color(0xFF62BF39).withValues(alpha: 0.10),
                              ),
                              child: Text(t, style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF62BF39))),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _SpecField extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _SpecField({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: const Color(0xFF62BF39)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w900, color: const Color(0xFF6B7280))),
              const SizedBox(height: 4),
              Text(value, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w900)),
            ],
          ),
        ),
      ],
    );
  }
}

class _WhySection extends StatefulWidget {
  const _WhySection();

  @override
  State<_WhySection> createState() => _WhySectionState();
}

class _WhySectionState extends State<_WhySection> {
  static const _images = <String>[
    'https://atvstp.org.vn/wp-content/uploads/2018/12/thoi-quen-an-cai-loai-rau-song-khong-he-tot-nhu-nhung-nguoi-tieu-dung-dang-nghi-1024x631.jpg',
    'https://defarm.vn/wp-content/uploads/2021/07/Uu-Diem-Cua-San-Pham-Sach-Tren-Thi-Truong-Hien-Nay.jpg',
    'https://defarm.vn/wp-content/uploads/2021/07/Nhuoc-Diem-Cua-San-Pham-Sach.jpg',
  ];

  int _idx = 0;

  @override
  void initState() {
    super.initState();
    Future.doWhile(() async {
      await Future<void>.delayed(const Duration(seconds: 60));
      if (!mounted) return false;
      setState(() => _idx = (_idx + 1) % _images.length);
      return true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final img = _images[_idx];
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: const Color(0xFF62BF39).withValues(alpha: 0.06),
      ),
      child: LayoutBuilder(
        builder: (context, c) {
          final narrow = c.maxWidth < 360;
          final imageWidget = Container(
            width: narrow ? double.infinity : 118,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: theme.colorScheme.outlineVariant),
              color: theme.colorScheme.surface,
            ),
            clipBehavior: Clip.antiAlias,
            child: AspectRatio(
              aspectRatio: narrow ? (16 / 10) : 1,
              child: CachedNetworkImage(
                imageUrl: img,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(color: theme.colorScheme.surfaceContainerHighest),
                errorWidget: (_, __, ___) => Container(
                  color: theme.colorScheme.surfaceContainerHighest,
                  child: const Icon(Icons.broken_image),
                ),
              ),
            ),
          );

          final items = const [
            _WhyItem(
              icon: Icons.verified_outlined,
              title: 'Nguồn dinh dưỡng\ndồi dào',
              sub: 'Giàu vitamin và khoáng chất, hỗ trợ bữa ăn lành mạnh mỗi ngày.',
            ),
            _WhyItem(
              icon: Icons.place_outlined,
              title: 'Trang trại địa\nphương',
              sub: 'Ưu tiên nguồn gốc rõ ràng, rút ngắn thời gian từ vườn đến bếp.',
            ),
            _WhyItem(
              icon: Icons.check_circle_outline,
              title: 'Chế biến đa dạng',
              sub: 'Phù hợp xào, luộc, salad hay sinh tố tùy khẩu vị cả nhà.',
            ),
          ];

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Tại sao bạn sẽ yêu thích?', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
              const SizedBox(height: 12),
              if (narrow) ...[
                imageWidget,
                const SizedBox(height: 12),
                for (final w in items) ...[
                  w,
                  const SizedBox(height: 12),
                ],
              ] else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (var i = 0; i < items.length; i++) ...[
                            items[i],
                            if (i != items.length - 1) const SizedBox(height: 12),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    imageWidget,
                  ],
                ),
            ],
          );
        },
      ),
    );
  }
}

class _WhyItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String sub;
  const _WhyItem({required this.icon, required this.title, required this.sub});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: theme.colorScheme.surface,
            border: Border.all(color: const Color(0xFF62BF39).withValues(alpha: 0.35)),
          ),
          child: Icon(icon, color: const Color(0xFF62BF39)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900, height: 1.05),
              ),
              const SizedBox(height: 4),
              Text(
                sub,
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant, height: 1.35),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RelatedSection extends StatelessWidget {
  final List<Product> related;
  const _RelatedSection({required this.related});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text('Sản phẩm liên quan', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900))),
            TextButton(
              onPressed: () {
                NavState.tabIndex.value = 1;
                Navigator.of(context).popUntil((r) => r.isFirst);
              },
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF62BF39),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                textStyle: const TextStyle(fontWeight: FontWeight.w900),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Xem tất cả'),
                  SizedBox(width: 6),
                  Icon(Icons.chevron_right_rounded, size: 20),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (related.isEmpty)
          Text('Đang cập nhật sản phẩm cùng loại…', style: theme.textTheme.bodyMedium?.copyWith(color: const Color(0xFF6B7280)))
        else
          SizedBox(
            height: 252,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: related.length.clamp(0, 6),
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, i) {
                final p = related[i];
                return _RelatedCard(product: p);
              },
            ),
          ),
      ],
    );
  }
}

class _RelatedCard extends StatelessWidget {
  final Product product;
  const _RelatedCard({required this.product});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final img = ApiConfig.resolveMediaUrl(product.mainImageUrl);
    final hasDiscount = product.discountPrice != null && product.discountPrice! < product.price;
    final sell = hasDiscount ? product.discountPrice! : product.price;

    return InkWell(
      onTap: () {
        final token = product.productToken?.trim();
        final idOrToken = (token != null && token.isNotEmpty) ? token : '${product.id}';
        Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => ProductDetailScreen(tokenOrId: idOrToken)));
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 150,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.colorScheme.outlineVariant),
          color: theme.colorScheme.surface,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: AspectRatio(
                // Taller image area (match web cards)
                aspectRatio: 1,
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
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
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
                  const SizedBox(height: 4),
                  Text(
                    product.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w900, height: 1.1),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    Formatters.vnd(sell),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900, color: const Color(0xFFE67E22)),
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

class _ReviewsSection extends StatefulWidget {
  final int productId;
  final List<ReviewItem> reviews;
  const _ReviewsSection({required this.productId, required this.reviews});

  @override
  State<_ReviewsSection> createState() => _ReviewsSectionState();
}

class _ReviewsSectionState extends State<_ReviewsSection> {
  final _picker = ImagePicker();
  final _api = ApiClient();

  late List<ReviewItem> _reviews;
  bool _hasLocal = false;

  @override
  void initState() {
    super.initState();
    _reviews = List<ReviewItem>.from(widget.reviews);
  }

  @override
  void didUpdateWidget(covariant _ReviewsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_hasLocal) return;
    if (!identical(oldWidget.reviews, widget.reviews)) {
      _reviews = List<ReviewItem>.from(widget.reviews);
    }
  }

  String _relative(DateTime? d) {
    if (d == null) return '';
    final sec = DateTime.now().difference(d).inSeconds;
    if (sec < 45) return 'Vừa xong';
    if (sec < 3600) return '${(sec / 60).floor()} phút trước';
    if (sec < 86400) return '${(sec / 3600).floor()} giờ trước';
    if (sec < 604800) return '${(sec / 86400).floor()} ngày trước';
    return '${d.day}/${d.month}/${d.year}';
  }

  Future<void> _openAllReviewsSheet(BuildContext context) async {
    final theme = Theme.of(context);
    final reviews = _reviews;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (sheetContext) {
        return SafeArea(
          top: false,
          child: DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.92,
            minChildSize: 0.55,
            maxChildSize: 0.98,
            builder: (context, scrollCtl) {
              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
                child: Column(
                  children: [
                    Container(
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(color: const Color(0xFFE2E8F0), borderRadius: BorderRadius.circular(999)),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Tất cả đánh giá (${reviews.length})',
                            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(sheetContext).pop(),
                          icon: const Icon(Icons.close),
                          tooltip: 'Đóng',
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: ListView.separated(
                        controller: scrollCtl,
                        itemCount: reviews.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, i) => _ReviewCard(review: reviews[i], time: _relative(reviews[i].reviewDate)),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final reviews = _reviews;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text('Đánh giá sản phẩm', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900))),
            TextButton(
              onPressed: () => _openReviewForm(context),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF62BF39),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                textStyle: const TextStyle(fontWeight: FontWeight.w900),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Viết đánh giá'),
                  SizedBox(width: 6),
                  Icon(Icons.edit_outlined, size: 18),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (reviews.isEmpty)
          Text('Chưa có đánh giá nào. Hãy là người đầu tiên!', style: theme.textTheme.bodyMedium?.copyWith(color: const Color(0xFF6B7280)))
        else
          Column(
            children: [
              for (final r in reviews.take(10)) ...[
                _ReviewCard(review: r, time: _relative(r.reviewDate)),
                const SizedBox(height: 12),
              ],
              if (reviews.length > 10)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: () => _openAllReviewsSheet(context),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF62BF39),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                      textStyle: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    child: const Text('Xem tất cả đánh giá'),
                  ),
                ),
            ],
          ),
      ],
    );
  }

  Future<void> _openReviewForm(BuildContext context) async {
    final theme = Theme.of(context);
    final commentCtl = TextEditingController();
    var rating = 5;
    var images = <XFile>[];
    var sending = false;
    String? err;

    Future<void> pickImages() async {
      final picked = await _picker.pickMultiImage(imageQuality: 85);
      if (picked.isEmpty) return;
      images = [...images, ...picked].take(3).toList(growable: true);
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
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
                      Text('Viết đánh giá', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
                      const SizedBox(height: 12),
                      if (err != null) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            color: const Color(0xFFEF4444).withValues(alpha: 0.08),
                          ),
                          child: Text(err!, style: theme.textTheme.bodyMedium?.copyWith(color: const Color(0xFFB91C1C), fontWeight: FontWeight.w800)),
                        ),
                        const SizedBox(height: 12),
                      ],
                      Text('Số sao', style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w900, color: theme.colorScheme.onSurfaceVariant)),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<int>(
                        value: rating,
                        items: const [5, 4, 3, 2, 1].map((x) => DropdownMenuItem(value: x, child: Text('$x sao'))).toList(growable: false),
                        onChanged: sending ? null : (v) => setLocal(() => rating = v ?? 5),
                        decoration: InputDecoration(
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text('Nhận xét (tùy chọn)', style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w900, color: const Color(0xFF6B7280))),
                      const SizedBox(height: 6),
                      TextField(
                        controller: commentCtl,
                        maxLines: 4,
                        enabled: !sending,
                        decoration: InputDecoration(
                          hintText: 'Ví dụ: chất lượng, độ tươi, đóng gói…',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Ảnh minh họa (tối đa 3)',
                              style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w900, color: const Color(0xFF6B7280)),
                            ),
                          ),
                          Text('${images.length}/3', style: theme.textTheme.bodySmall?.copyWith(color: const Color(0xFF94A3B8), fontWeight: FontWeight.w900)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: (sending || images.length >= 3)
                            ? null
                            : () async {
                                await pickImages();
                                if (!context.mounted) return;
                                setLocal(() {});
                              },
                        icon: const Icon(Icons.image_outlined),
                        label: const Text('Chọn ảnh'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF111827),
                          side: BorderSide(color: theme.colorScheme.outlineVariant),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                      if (images.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            for (var i = 0; i < images.length; i++) ...[
                              Expanded(
                                child: Stack(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: AspectRatio(
                                        aspectRatio: 1,
                                        child: Image.file(
                                          File(images[i].path),
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) => Container(color: theme.colorScheme.surfaceContainerHighest),
                                        ),
                                      ),
                                    ),
                                    Positioned(
                                      top: 6,
                                      right: 6,
                                      child: InkWell(
                                        onTap: () => setLocal(() => images.removeAt(i)),
                                        borderRadius: BorderRadius.circular(999),
                                        child: Container(
                                          padding: const EdgeInsets.all(6),
                                          decoration: BoxDecoration(
                                            color: Colors.black.withValues(alpha: 0.65),
                                            borderRadius: BorderRadius.circular(999),
                                          ),
                                          child: const Icon(Icons.close_rounded, size: 16, color: Colors.white),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (i != images.length - 1) const SizedBox(width: 8),
                            ],
                          ],
                        ),
                      ],
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        height: 46,
                        child: ElevatedButton(
                          onPressed: sending
                              ? null
                              : () async {
                                  setLocal(() {
                                    sending = true;
                                    err = null;
                                  });

                                  final u = AuthState.currentUser.value;
                                  if (u == null) {
                                    if (!context.mounted) return;
                                    Navigator.of(context).pop();
                                    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AuthLoginScreen()));
                                    return;
                                  }

                                  final productId = widget.productId;
                                  if (productId <= 0) {
                                    setLocal(() {
                                      sending = false;
                                      err = 'Không xác định được sản phẩm để đánh giá.';
                                    });
                                    return;
                                  }

                                  try {
                                    final imageUrls = images.isEmpty ? const <String>[] : await _api.uploadReviewImages(images.map((x) => x.path).toList());
                                    final res = await _api.createReview(
                                      productId: productId,
                                      userId: u.userId,
                                      rating: rating,
                                      comment: commentCtl.text.trim().isEmpty ? null : commentCtl.text.trim(),
                                      imageUrls: imageUrls,
                                    );

                                    final idRaw = res['reviewID'] ?? res['ReviewID'] ?? res['reviewId'] ?? res['id'];
                                    final id = idRaw is num ? idRaw.toInt() : int.tryParse('$idRaw') ?? 0;

                                    if (!context.mounted) return;
                                    Navigator.of(context).pop();

                                    final next = ReviewItem(
                                      id: id <= 0 ? DateTime.now().millisecondsSinceEpoch : id,
                                      rating: rating,
                                      comment: commentCtl.text.trim().isEmpty ? null : commentCtl.text.trim(),
                                      adminReply: null,
                                      reviewDate: DateTime.now(),
                                      userName: u.fullName,
                                      avatarUrl: u.avatarUrl,
                                      imageUrls: imageUrls,
                                    );
                                    setState(() {
                                      _hasLocal = true;
                                      _reviews = [next, ..._reviews];
                                    });

                                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã gửi đánh giá.')));
                                  } catch (e) {
                                    setLocal(() {
                                      sending = false;
                                      err = '$e'.replaceFirst('Exception: ', '').trim();
                                    });
                                  } finally {
                                    if (context.mounted) {
                                      setLocal(() => sending = false);
                                    }
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF62BF39),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            textStyle: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                          child: sending
                              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Text('Gửi đánh giá'),
                        ),
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

    commentCtl.dispose();
  }
}

class _ReviewCard extends StatelessWidget {
  final ReviewItem review;
  final String time;
  const _ReviewCard({required this.review, required this.time});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = (review.userName ?? 'Khách hàng').trim().isEmpty ? 'Khách hàng' : (review.userName ?? 'Khách hàng').trim();
    final avatarUrl = ApiConfig.resolveMediaUrl(review.avatarUrl);
    final comment = (review.comment ?? '').trim();
    final adminReply = (review.adminReply ?? '').trim();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outlineVariant),
        color: theme.colorScheme.surface,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: theme.colorScheme.primaryContainer,
            foregroundColor: theme.colorScheme.onPrimaryContainer,
            backgroundImage: avatarUrl.isEmpty ? null : CachedNetworkImageProvider(avatarUrl),
            child: avatarUrl.isEmpty ? Text(name.characters.first.toUpperCase()) : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(name, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w900))),
                    if (time.isNotEmpty)
                      Text(time, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant, fontWeight: FontWeight.w800)),
                  ],
                ),
                const SizedBox(height: 4),
                _StarsRow(rating: review.rating),
                if (comment.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(comment, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant, height: 1.4)),
                ],
                if (review.imageUrls.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _ReviewImages(urls: review.imageUrls),
                ],
                if (adminReply.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      color: const Color(0xFF62BF39).withValues(alpha: 0.08),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('FreshFood phản hồi', style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w900, color: const Color(0xFF62BF39))),
                        const SizedBox(height: 6),
                        Text(adminReply, style: theme.textTheme.bodyMedium?.copyWith(color: const Color(0xFF4B5563), height: 1.35)),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StarsRow extends StatelessWidget {
  final int rating;
  const _StarsRow({required this.rating});

  @override
  Widget build(BuildContext context) {
    final full = rating.clamp(0, 5);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        return Icon(i < full ? Icons.star : Icons.star_border, size: 16, color: Colors.amber);
      }),
    );
  }
}

class _ReviewImages extends StatelessWidget {
  final List<String> urls;
  const _ReviewImages({required this.urls});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        for (var i = 0; i < urls.length; i++) ...[
          Expanded(
            child: InkWell(
              onTap: () {
                showDialog<void>(
                  context: context,
                  barrierColor: Colors.black.withValues(alpha: 0.85),
                  builder: (_) => _Lightbox(urls: urls, initialIndex: i),
                );
              },
              borderRadius: BorderRadius.circular(12),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: AspectRatio(
                  aspectRatio: 1,
                  child: CachedNetworkImage(
                    imageUrl: urls[i],
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(color: theme.colorScheme.surfaceContainerHighest),
                    errorWidget: (_, __, ___) => Container(color: theme.colorScheme.surfaceContainerHighest, child: const Icon(Icons.broken_image)),
                  ),
                ),
              ),
            ),
          ),
          if (i != urls.length - 1) const SizedBox(width: 8),
        ],
      ],
    );
  }
}

class _Lightbox extends StatefulWidget {
  final List<String> urls;
  final int initialIndex;
  const _Lightbox({required this.urls, required this.initialIndex});

  @override
  State<_Lightbox> createState() => _LightboxState();
}

class _LightboxState extends State<_Lightbox> {
  late final PageController _ctl;
  int _idx = 0;

  @override
  void initState() {
    super.initState();
    _idx = widget.initialIndex;
    _ctl = PageController(initialPage: _idx);
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: Container(color: Colors.transparent),
        ),
        Center(
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.68,
            child: PageView.builder(
              controller: _ctl,
              itemCount: widget.urls.length,
              onPageChanged: (i) => setState(() => _idx = i),
              itemBuilder: (context, i) {
                return InteractiveViewer(
                  child: CachedNetworkImage(imageUrl: widget.urls[i], fit: BoxFit.contain),
                );
              },
            ),
          ),
        ),
        Positioned(
          top: MediaQuery.of(context).padding.top + 14,
          right: 14,
          child: _RoundIcon(icon: Icons.close_rounded, onTap: () => Navigator.of(context).pop()),
        ),
        if (widget.urls.length > 1)
          Positioned(
            bottom: MediaQuery.of(context).padding.bottom + 18,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface, borderRadius: BorderRadius.circular(999)),
                child: Text('${_idx + 1}/${widget.urls.length}', style: const TextStyle(fontWeight: FontWeight.w900)),
              ),
            ),
          ),
      ],
    );
  }
}

