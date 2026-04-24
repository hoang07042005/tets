import 'package:flutter/material.dart';
import 'package:freshfood_app/l10n/app_localizations.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = AppLocalizations.of(context);

    final keys = <String, GlobalKey>{
      'muc-dich': GlobalKey(),
      'pham-vi': GlobalKey(),
      'thoi-gian-luu': GlobalKey(),
      'doi-tuong': GlobalKey(),
      'dia-chi': GlobalKey(),
      'tiep-can': GlobalKey(),
      'cam-ket': GlobalKey(),
    };

    Future<void> go(String id) async {
      final k = keys[id];
      final c = k?.currentContext;
      if (c == null) return;
      await Scrollable.ensureVisible(c, duration: const Duration(milliseconds: 280), curve: Curves.easeOutCubic);
    }

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 220,
            foregroundColor: Colors.white,
            backgroundColor: const Color(0xFF62BF39),
            title: Text(t.tr(vi: 'Chính sách bảo mật', en: 'Privacy policy')),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF1FA85A), Color(0xFF62BF39), Color(0xFF0EA5E9)],
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 58, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(999),
                            color: Colors.white.withValues(alpha: 0.18),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
                          ),
                          child: Text(
                            t.tr(vi: 'CHÍNH SÁCH / BẢO MẬT', en: 'LEGAL / PRIVACY'),
                            style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.6, fontSize: 12),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          t.tr(
                            vi: 'Cam kết bảo vệ dữ liệu cá nhân của bạn.',
                            en: 'We are committed to protecting your personal data.',
                          ),
                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 22, height: 1.15),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          t.tr(
                            vi: 'Cập nhật lần cuối: 13/04/2026',
                            en: 'Last updated: 13/04/2026',
                          ),
                          style: TextStyle(fontWeight: FontWeight.w800, color: Colors.white.withValues(alpha: 0.92)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Toc(
                    theme: theme,
                    title: t.tr(vi: 'Mục lục', en: 'Contents'),
                    items: [
                      _TocItem(id: 'muc-dich', label: 'Mục đích thu thập thông tin cá nhân'),
                      _TocItem(id: 'pham-vi', label: 'Phạm vi sử dụng thông tin'),
                      _TocItem(id: 'thoi-gian-luu', label: 'Thời gian lưu trữ'),
                      _TocItem(id: 'doi-tuong', label: 'Đối tượng tiếp cận'),
                      _TocItem(id: 'dia-chi', label: 'Địa chỉ đơn vị thu thập'),
                      _TocItem(id: 'tiep-can', label: 'Phương thức tiếp cận và chỉnh sửa dữ liệu'),
                      _TocItem(id: 'cam-ket', label: 'Cam kết bảo mật thông tin'),
                    ],
                    onTap: go,
                  ),
                  const SizedBox(height: 14),
                  _Section(
                    key: keys['muc-dich'],
                    num: '1.',
                    title: 'Mục đích thu thập thông tin cá nhân',
                    child: Column(
                      children: const [
                        _Bullet(title: 'Xử lý đơn hàng', subtitle: 'Giao nhận, xuất hóa đơn và hỗ trợ sau mua.'),
                        _Bullet(title: 'Nâng cao trải nghiệm', subtitle: 'Gợi ý sản phẩm, lịch sử đơn, wishlist.'),
                        _Bullet(title: 'An toàn hệ thống', subtitle: 'Phòng chống gian lận, bảo mật tài khoản.'),
                        _Bullet(title: 'Thông báo cần thiết', subtitle: 'Email/SMS cập nhật trạng thái đơn hàng khi cần.'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _Section(
                    key: keys['pham-vi'],
                    num: '2.',
                    title: 'Phạm vi sử dụng thông tin',
                    child: _ThreeCol(
                      leftTitle: 'Collected',
                      left: 'Thông tin bạn cung cấp khi đăng ký/đặt hàng.',
                      midTitle: 'Use-case',
                      mid: 'Xác thực, giao hàng, hỗ trợ, hoàn tiền/đổi trả.',
                      rightTitle: 'Policy',
                      right: 'Không bán dữ liệu. Chia sẻ tối thiểu với đối tác liên quan.',
                    ),
                  ),
                  const SizedBox(height: 12),
                  _Section(
                    key: keys['thoi-gian-luu'],
                    num: '3.',
                    title: 'Thời gian lưu trữ',
                    child: const Text(
                      'Dữ liệu được lưu trong thời gian cần thiết để cung cấp dịch vụ và đáp ứng nghĩa vụ pháp lý (đơn hàng, hóa đơn, đối soát). '
                      'Bạn có thể yêu cầu xoá dữ liệu trong phạm vi pháp luật cho phép.',
                      style: TextStyle(height: 1.4),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _Section(
                    key: keys['doi-tuong'],
                    num: '4.',
                    title: 'Đối tượng tiếp cận',
                    child: const Text(
                      'Nhân sự vận hành, đối tác vận chuyển và cổng thanh toán có thể tiếp cận dữ liệu tối thiểu để thực hiện dịch vụ. '
                      'Ngoài ra, chúng tôi chỉ cung cấp dữ liệu khi có yêu cầu hợp lệ từ cơ quan có thẩm quyền.',
                      style: TextStyle(height: 1.4),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _Section(
                    key: keys['dia-chi'],
                    num: '5.',
                    title: 'Địa chỉ đơn vị thu thập',
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _Li(text: 'FreshFood — Nền tảng thương mại điện tử thực phẩm tươi sạch.'),
                        _Li(text: 'Email hỗ trợ: support@freshfood.com'),
                        _Li(text: 'Trang liên hệ: /contact'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _Section(
                    key: keys['tiep-can'],
                    num: '6.',
                    title: 'Phương thức tiếp cận và chỉnh sửa dữ liệu',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _Card(
                          color: const Color(0xFF62BF39).withValues(alpha: 0.10),
                          title: 'Tự thực hiện',
                          body: const Text('Bạn có thể xem và cập nhật một số thông tin trong trang Tài khoản.', style: TextStyle(height: 1.35)),
                        ),
                        const SizedBox(height: 10),
                        _Card(
                          color: theme.colorScheme.surfaceContainerHighest,
                          title: 'Yêu cầu hỗ trợ',
                          body: const Text('Nếu cần xoá dữ liệu hoặc chỉnh sửa thông tin đặc biệt, hãy liên hệ đội hỗ trợ.', style: TextStyle(height: 1.35)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _Section(
                    key: keys['cam-ket'],
                    num: '7.',
                    title: 'Cam kết bảo mật thông tin',
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        color: theme.colorScheme.surfaceContainerHighest,
                        border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6)),
                      ),
                      child: const Text(
                        'FreshFood áp dụng các biện pháp bảo mật phù hợp để bảo vệ dữ liệu, bao gồm kiểm soát truy cập, mã hoá khi cần thiết và quy trình xử lý sự cố. '
                        'Chúng tôi không chia sẻ dữ liệu ngoài phạm vi nêu trong chính sách này.',
                        style: TextStyle(fontWeight: FontWeight.w800, height: 1.4),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TocItem {
  final String id;
  final String label;
  const _TocItem({required this.id, required this.label});
}

class _Toc extends StatelessWidget {
  final ThemeData theme;
  final String title;
  final List<_TocItem> items;
  final Future<void> Function(String id) onTap;
  const _Toc({required this.theme, required this.title, required this.items, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: theme.colorScheme.surface,
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final it in items)
                ActionChip(
                  label: Text(it.label, style: const TextStyle(fontWeight: FontWeight.w800)),
                  onPressed: () => onTap(it.id),
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  side: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6)),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String num;
  final String title;
  final Widget child;
  const _Section({super.key, required this.num, required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: theme.colorScheme.surface,
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: const Color(0xFF62BF39).withValues(alpha: 0.12),
                ),
                child: Text(num, style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF62BF39))),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900, height: 1.2))),
            ],
          ),
          const SizedBox(height: 12),
          DefaultTextStyle(
            style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant) ?? const TextStyle(),
            child: child,
          ),
        ],
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  final String title;
  final String subtitle;
  const _Bullet({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: const Color(0xFF62BF39).withValues(alpha: 0.12),
            ),
            child: const Icon(Icons.check_rounded, size: 18, color: Color(0xFF62BF39)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900)),
                const SizedBox(height: 2),
                Text(subtitle, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant, height: 1.35)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ThreeCol extends StatelessWidget {
  final String leftTitle;
  final String left;
  final String midTitle;
  final String mid;
  final String rightTitle;
  final String right;
  const _ThreeCol({
    required this.leftTitle,
    required this.left,
    required this.midTitle,
    required this.mid,
    required this.rightTitle,
    required this.right,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget col(String h, String p) {
      return Expanded(
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: theme.colorScheme.surfaceContainerHighest,
            border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.55)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(h, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900)),
              const SizedBox(height: 6),
              Text(p, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant, height: 1.35)),
            ],
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, c) {
        final wide = c.maxWidth >= 720;
        if (wide) {
          return Row(
            children: [
              col(leftTitle, left),
              const SizedBox(width: 10),
              col(midTitle, mid),
              const SizedBox(width: 10),
              col(rightTitle, right),
            ],
          );
        }
        return Column(
          children: [
            Row(children: [col(leftTitle, left)]),
            const SizedBox(height: 10),
            Row(children: [col(midTitle, mid)]),
            const SizedBox(height: 10),
            Row(children: [col(rightTitle, right)]),
          ],
        );
      },
    );
  }
}

class _Card extends StatelessWidget {
  final Color color;
  final String title;
  final Widget body;
  const _Card({required this.color, required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: color,
        border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.55)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          DefaultTextStyle(style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant) ?? const TextStyle(), child: body),
        ],
      ),
    );
  }
}

class _Li extends StatelessWidget {
  final String text;
  const _Li({required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(fontWeight: FontWeight.w900)),
          Expanded(child: Text(text, style: theme.textTheme.bodyMedium?.copyWith(height: 1.35))),
        ],
      ),
    );
  }
}

