import 'package:flutter/material.dart';

class PaymentResultScreen extends StatelessWidget {
  final bool success;
  final String? orderId;
  final String? code;

  const PaymentResultScreen({
    super.key,
    required this.success,
    required this.orderId,
    required this.code,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = success ? 'Thanh toán thành công' : 'Thanh toán chưa thành công';
    final subtitle = success
        ? 'Cảm ơn bạn! Đơn hàng của bạn đã được thanh toán.'
        : 'Bạn có thể thử lại hoặc chọn phương thức khác.';

    final pillBg = success ? const Color(0xFF62BF39).withValues(alpha: 0.12) : const Color(0xFFB91C1C).withValues(alpha: 0.10);
    final pillFg = success ? const Color(0xFF62BF39) : const Color(0xFFB91C1C);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kết quả thanh toán'),
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 18, offset: const Offset(0, 12)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(color: pillBg, borderRadius: BorderRadius.circular(999)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(success ? Icons.check_circle : Icons.error_outline, color: pillFg, size: 18),
                        const SizedBox(width: 8),
                        Text(success ? 'SUCCESS' : 'FAILED', style: TextStyle(fontWeight: FontWeight.w900, color: pillFg)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(title, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 8),
                  Text(subtitle, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 14),
                  if ((orderId ?? '').trim().isNotEmpty)
                    _kv(theme, 'Mã đơn', orderId!.trim()),
                  if ((code ?? '').trim().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _kv(theme, 'Mã phản hồi', code!.trim()),
                  ],
                ],
              ),
            ),
            const Spacer(),
            SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF62BF39),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  textStyle: const TextStyle(fontWeight: FontWeight.w900),
                ),
                child: const Text('Về trang chủ'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _kv(ThemeData theme, String k, String v) {
    return Row(
      children: [
        Expanded(child: Text(k, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant, fontWeight: FontWeight.w700))),
        const SizedBox(width: 12),
        Text(v, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w900)),
      ],
    );
  }
}

