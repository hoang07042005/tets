import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:freshfood_app/config/api_config.dart';
import 'package:freshfood_app/screens/checkout/checkout_screen.dart';
import 'package:freshfood_app/l10n/app_localizations.dart';
import 'package:freshfood_app/state/cart_state.dart';
import 'package:freshfood_app/ui/formatters.dart';

class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  static const _moneyColor = Color(0xFFE67E22);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(t.tr(vi: 'Giỏ hàng', en: 'Cart')),
        actions: [
          TextButton(
            onPressed: () {
              if (CartState.lines.value.isEmpty) return;
              showDialog<void>(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text(t.tr(vi: 'Xóa tất cả?', en: 'Clear cart?')),
                  content: Text(t.tr(vi: 'Bạn có chắc muốn xóa toàn bộ sản phẩm trong giỏ hàng không?', en: 'Remove all items from your cart?')),
                  actions: [
                    TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(t.tr(vi: 'Hủy', en: 'Cancel'))),
                    ElevatedButton(
                      onPressed: () {
                        CartState.clear();
                        Navigator.of(context).pop();
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF62BF39), foregroundColor: Colors.white),
                      child: Text(t.tr(vi: 'Xóa', en: 'Remove')),
                    ),
                  ],
                ),
              );
            },
            child: Text(t.tr(vi: 'Xóa hết', en: 'Clear'), style: const TextStyle(fontWeight: FontWeight.w900)),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ValueListenableBuilder<List<CartLine>>(
        valueListenable: CartState.lines,
        builder: (context, lines, _) {
          if (lines.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.shopping_cart_outlined, size: 56, color: theme.colorScheme.outline),
                    const SizedBox(height: 12),
                    Text(t.tr(vi: 'Giỏ hàng trống', en: 'Your cart is empty'), style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
                    const SizedBox(height: 6),
                    Text(
                      t.tr(vi: 'Hãy thêm sản phẩm để bắt đầu mua sắm.', en: 'Add items to start shopping.'),
                      style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            );
          }

          final sub = CartState.subtotal();
          final estTax = (sub * 0.015).round();
          final grand = sub + estTax;
          return Column(
            children: [
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                  itemCount: lines.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, i) => _CartLineTile(line: lines[i]),
                ),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  border: Border(top: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.8))),
                ),
                child: Column(
                  children: [
                    _MoneyRow(label: t.tr(vi: 'Tạm tính', en: 'Subtotal'), value: Formatters.vnd(sub), valueColor: _moneyColor),
                    const SizedBox(height: 6),
                    _MoneyRow(label: t.tr(vi: 'Thuế (ước tính)', en: 'Estimated tax'), value: Formatters.vnd(estTax), valueColor: _moneyColor),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(child: Text(t.tr(vi: 'Tổng cộng', en: 'Total'), style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900))),
                        Text(
                          Formatters.vnd(grand),
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900, color: _moneyColor),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CheckoutScreen()));
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF62BF39),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          textStyle: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                        child: Text(t.tr(vi: 'Thanh toán', en: 'Checkout')),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _CartLineTile extends StatelessWidget {
  final CartLine line;
  const _CartLineTile({required this.line});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = AppLocalizations.of(context);
    final img = ApiConfig.resolveMediaUrl(line.imageUrl);
    final unit = (line.unit ?? '').trim();
    final hasSale = line.discountPrice != null && line.discountPrice! < line.price;
    final sell = line.sellingPrice;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 16, offset: const Offset(0, 10)),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: SizedBox(
              width: 84,
              height: 84,
              child: img.isEmpty
                  ? Container(color: theme.colorScheme.surfaceContainerHighest)
                  : CachedNetworkImage(imageUrl: img, fit: BoxFit.cover),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        line.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
                      ),
                    ),
                    IconButton(
                      onPressed: () => CartState.remove(line.productId),
                      icon: const Icon(Icons.close_rounded),
                      tooltip: t.tr(vi: 'Xóa', en: 'Remove'),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              Formatters.vnd(sell),
                              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900, color: CartScreen._moneyColor),
                            ),
                            if (unit.isNotEmpty) ...[
                              const SizedBox(width: 6),
                              Text(
                                '/$unit',
                                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant, fontWeight: FontWeight.w800),
                              ),
                            ],
                            if (hasSale) ...[
                              const SizedBox(width: 10),
                              Text(
                                Formatters.vnd(line.price),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                  decoration: TextDecoration.lineThrough,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _QtyButton(
                      icon: Icons.remove_rounded,
                      onPressed: () => CartState.dec(line.productId),
                    ),
                    Container(
                      width: 40,
                      alignment: Alignment.center,
                      child: Text('${line.quantity}', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900)),
                    ),
                    _QtyButton(
                      icon: Icons.add_rounded,
                      onPressed: () => CartState.inc(line.productId),
                    ),
                    const Spacer(),
                    Text(
                      Formatters.vnd(sell * line.quantity),
                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900, color: CartScreen._moneyColor),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QtyButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  const _QtyButton({required this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 36,
      height: 36,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          padding: EdgeInsets.zero,
          side: BorderSide.none,
          backgroundColor: theme.colorScheme.surfaceContainerHighest,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: Icon(icon, size: 18, color: theme.colorScheme.onSurface),
      ),
    );
  }
}

class _MoneyRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  const _MoneyRow({required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(child: Text(label, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant, fontWeight: FontWeight.w700))),
        Text(value, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w900, color: valueColor)),
      ],
    );
  }
}

