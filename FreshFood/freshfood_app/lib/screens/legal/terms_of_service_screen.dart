import 'package:flutter/material.dart';
import 'package:freshfood_app/l10n/app_localizations.dart';

class TermsOfServiceScreen extends StatelessWidget {
  const TermsOfServiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = AppLocalizations.of(context);

    final keys = <String, GlobalKey>{
      'gioi-thieu-chung': GlobalKey(),
      'tai-khoan-nguoi-dung': GlobalKey(),
      'chinh-sach-mua-hang': GlobalKey(),
      'thanh-toan': GlobalKey(),
      'giao-nhan': GlobalKey(),
      'doi-tra-boi-thuong': GlobalKey(),
      'quyen-so-huu-tri-tue': GlobalKey(),
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
            expandedHeight: 210,
            foregroundColor: Colors.white,
            backgroundColor: const Color(0xFF62BF39),
            title: Text(t.tr(vi: 'Điều khoản dịch vụ', en: 'Terms of service')),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF16A34A), Color(0xFF62BF39), Color(0xFF0EA5E9)],
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
                            t.tr(vi: 'CHÍNH SÁCH / DỊCH VỤ', en: 'LEGAL / SERVICE'),
                            style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.6, fontSize: 12),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          t.tr(
                            vi: 'Chào mừng bạn đến với FreshFood.',
                            en: 'Welcome to FreshFood.',
                          ),
                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 22, height: 1.15),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          t.tr(vi: 'Cập nhật lần cuối: 13/04/2026', en: 'Last updated: 13/04/2026'),
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
                    items: const [
                      _TocItem(id: 'gioi-thieu-chung', label: 'Giới thiệu chung', num: '01'),
                      _TocItem(id: 'tai-khoan-nguoi-dung', label: 'Tài khoản người dùng', num: '02'),
                      _TocItem(id: 'chinh-sach-mua-hang', label: 'Chính sách mua hàng', num: '03'),
                      _TocItem(id: 'thanh-toan', label: 'Thanh toán', num: '04'),
                      _TocItem(id: 'giao-nhan', label: 'Giao nhận', num: '05'),
                      _TocItem(id: 'doi-tra-boi-thuong', label: 'Đổi trả và bồi thường', num: '06'),
                      _TocItem(id: 'quyen-so-huu-tri-tue', label: 'Quyền sở hữu trí tuệ', num: '07'),
                    ],
                    onTap: go,
                  ),
                  const SizedBox(height: 14),
                  _Section(
                    key: keys['gioi-thieu-chung'],
                    num: '01',
                    title: 'Giới thiệu chung',
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'FreshFood là nền tảng thương mại điện tử chuyên cung cấp thực phẩm tươi sạch. Điều khoản này quy định quyền '
                          'và nghĩa vụ của người dùng khi truy cập và sử dụng website.',
                          style: TextStyle(height: 1.4),
                        ),
                        SizedBox(height: 10),
                        Text(
                          'Chúng tôi có thể cập nhật nội dung theo thời gian. Phiên bản mới sẽ có hiệu lực kể từ thời điểm được đăng tải trên website.',
                          style: TextStyle(height: 1.4),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _Section(
                    key: keys['tai-khoan-nguoi-dung'],
                    num: '02',
                    title: 'Tài khoản người dùng',
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _Li(text: 'Bạn chịu trách nhiệm bảo mật thông tin đăng nhập và mọi hoạt động phát sinh từ tài khoản.'),
                        _Li(text: 'Thông tin cung cấp cần chính xác và được cập nhật khi có thay đổi.'),
                        _Li(text: 'FreshFood có thể tạm khóa/đình chỉ tài khoản nếu có dấu hiệu gian lận hoặc vi phạm điều khoản.'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _Section(
                    key: keys['chinh-sach-mua-hang'],
                    num: '03',
                    title: 'Chính sách mua hàng',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _Block(
                          title: 'Xác nhận đơn hàng',
                          body: const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Đơn hàng được ghi nhận khi bạn hoàn tất thao tác đặt hàng. Với thanh toán online, đơn hàng chỉ được xác nhận '
                                'khi hệ thống ghi nhận trạng thái thanh toán thành công.',
                                style: TextStyle(height: 1.4),
                              ),
                              SizedBox(height: 10),
                              _Li(text: 'Thông tin giao nhận cần đầy đủ để tránh giao thất bại.'),
                              _Li(text: 'Khuyến mãi/voucher áp dụng theo điều kiện hiển thị tại trang thanh toán.'),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        _Block(
                          title: 'Tình trạng hàng hóa',
                          body: const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Sản phẩm thực phẩm có thể thay đổi theo mùa vụ. Chúng tôi luôn cố gắng đảm bảo chất lượng và cung cấp thông tin minh bạch.',
                                style: TextStyle(height: 1.4),
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Nếu phát sinh thiếu hàng, chúng tôi sẽ liên hệ để thay thế/hoàn tiền theo thỏa thuận.',
                                style: TextStyle(fontWeight: FontWeight.w800, height: 1.4),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _Section(
                    key: keys['thanh-toan'],
                    num: '04',
                    title: 'Thanh toán',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Chúng tôi hỗ trợ các hình thức thanh toán phổ biến:', style: TextStyle(height: 1.4)),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: const [
                            _Chip(text: 'Thanh toán khi nhận hàng (COD)'),
                            _Chip(text: 'Thanh toán online'),
                            _Chip(text: 'Ví/Ngân hàng'),
                            _Chip(text: 'Voucher/Khuyến mãi'),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _Section(
                    key: keys['giao-nhan'],
                    num: '05',
                    title: 'Giao nhận',
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Chúng tôi cố gắng giao đúng hẹn, tuy nhiên thời gian giao có thể thay đổi do điều kiện vận chuyển.',
                          style: TextStyle(fontWeight: FontWeight.w900, height: 1.4),
                        ),
                        SizedBox(height: 10),
                        Text(
                          'Vui lòng kiểm tra hàng khi nhận. Nếu có vấn đề về chất lượng/thiếu hàng, hãy phản hồi sớm để chúng tôi hỗ trợ nhanh nhất.',
                          style: TextStyle(height: 1.4),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _Section(
                    key: keys['doi-tra-boi-thuong'],
                    num: '06',
                    title: 'Đổi trả và bồi thường',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _Block(
                          title: 'Chính sách đổi trả',
                          kicker: 'Đổi/Trả theo quy trình',
                          body: const Text(
                            'Bạn có thể tạo yêu cầu hoàn hàng/hoàn tiền theo hướng dẫn trên website. Chúng tôi sẽ kiểm duyệt và phản hồi trong thời gian sớm nhất.',
                            style: TextStyle(height: 1.4),
                          ),
                        ),
                        const SizedBox(height: 10),
                        _Block(
                          title: 'Chính sách hoàn tiền',
                          kicker: 'Hoàn tiền minh bạch',
                          body: const Text(
                            'Hoàn tiền được xử lý theo phương thức thanh toán và trạng thái yêu cầu. Trường hợp cần chứng từ, admin sẽ cập nhật để bạn theo dõi.',
                            style: TextStyle(height: 1.4),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _Section(
                    key: keys['quyen-so-huu-tri-tue'],
                    num: '07',
                    title: 'Quyền sở hữu trí tuệ',
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Nội dung, hình ảnh, giao diện và các tài nguyên trên FreshFood thuộc sở hữu của FreshFood hoặc bên cấp phép. '
                          'Bạn không được sao chép hay khai thác thương mại khi chưa có sự cho phép.',
                          style: TextStyle(height: 1.4),
                        ),
                        SizedBox(height: 10),
                        Text('Cần hỗ trợ? Vui lòng truy cập /contact.', style: TextStyle(fontWeight: FontWeight.w800, height: 1.4)),
                      ],
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
  final String num;
  const _TocItem({required this.id, required this.label, required this.num});
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
                  label: Text('${it.num} · ${it.label}', style: const TextStyle(fontWeight: FontWeight.w800)),
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
                width: 42,
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

class _Block extends StatelessWidget {
  final String title;
  final String? kicker;
  final Widget body;
  const _Block({required this.title, this.kicker, required this.body});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: theme.colorScheme.surfaceContainerHighest,
        border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.55)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (kicker != null)
            Text(kicker!, style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w900, color: const Color(0xFF16A34A))),
          Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          DefaultTextStyle(style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant) ?? const TextStyle(), child: body),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String text;
  const _Chip({required this.text});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: theme.colorScheme.surfaceContainerHighest,
        border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.w900)),
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

