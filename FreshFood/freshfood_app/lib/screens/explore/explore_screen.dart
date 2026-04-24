import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_html/flutter_html.dart' hide Marker;
import 'package:flutter_map/flutter_map.dart';
import 'package:freshfood_app/api/api_client.dart';
import 'package:freshfood_app/config/api_config.dart';
import 'package:freshfood_app/models/blog_comment.dart';
import 'package:freshfood_app/models/blog_post.dart';
import 'package:freshfood_app/screens/account/auth/auth_login_screen.dart';
import 'package:freshfood_app/state/nav_state.dart';
import 'package:freshfood_app/state/auth_state.dart';
import 'package:latlong2/latlong.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Container(
          margin: const EdgeInsets.fromLTRB(16, 14, 16, 10),
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            color: theme.colorScheme.surfaceContainerHighest,
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A).withValues(alpha: 0.06),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: TabBar(
            controller: _tabs,
            dividerColor: Colors.transparent,
            indicator: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: const Color(0xFF62BF39),
            ),
            indicatorSize: TabBarIndicatorSize.tab,
            indicatorPadding: const EdgeInsets.all(2),
            labelColor: Colors.white,
            unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
            labelStyle: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w900, letterSpacing: 0.2),
            unselectedLabelStyle: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w800, letterSpacing: 0.2),
            tabs: const [
              Tab(height: 44, text: 'Giới thiệu'),
              Tab(height: 44, text: 'Liên hệ'),
              Tab(height: 44, text: 'Blog'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabs,
            children: const [
              _AboutTab(),
              _ContactTab(),
              _BlogTab(),
            ],
          ),
        ),
      ],
    );
  }
}

class _AboutTab extends StatelessWidget {
  const _AboutTab();

  static const _heroImg =
      "https://lh3.googleusercontent.com/aida-public/AB6AXuDccBjkLs0J4eFMJl_vl2znjjfbFkRMWUZcCfF4zOFN7W_YtjKgUyAYHzpbVmiL-V1q3Jqca5AxeDl_dOCPM-VvaFFosTrYY2_EwSR3QpzVnSt6mhCdKqL2sol9EwK90EIXoy38eokkJLqCAKRtmSY8IGvtnacheqAVXQPfXxwDQ56ylfgvprqFqhWicbcI1Hqg2U4JBAISr7q6cLkxDxFAG4apDNq4HEJcaXEHrfzSMS-13nx4QbZVCTaBVwKdYCbEKdNdakn6tzU";
  static const _splitImg =
      "https://lh3.googleusercontent.com/aida-public/AB6AXuAWh3QiYSfkvCuDExh6UYaNRelFE5e2bHYEpjn_ueLT761t9B9pvimqSNqvOK4LBbDPnJkRz4IlB9Mb_Oy51ackQuHXcuZ8b15VKh4IG482AcBzj7NJi90Nr1DIdxT8Ht6cdVVv25Pbou75ZfrkQYMck7Ebt41pvylmR56d3XwdBg7ZVANi5NenhlJFbwMmQDPLTyJqpYHGfMFo0kLFlAXIQAjZAw0qZg5VH8s4RAxbMSDzAVOVZuGCF7Q_ONsK_w6jbtgzd29l-JY";
  static const _floatImg =
      "https://lh3.googleusercontent.com/aida-public/AB6AXuARP7dIJJ_Vi4WadMl3hcOwJRfNMpfCiYO_HvZa7sQNW1gr9p2sTPak6_vUrK2TYqSs0DrS2cNc0h_w4dPRov9OxSYQFUnpySy4bxeu-qOhL333Gv0XH4z_-T-izEcQfo7DxVP40qUp_jezusdwhme4nGxg-Lmy0X0r4riOCiwpu85ZK23lDUylc7IqQIlp5TRwrlQEZSGc2-R1i8z1tCV61pCTCUiiegULq13ct99rzilpplrE5bzhY3yZN7j8c4g1u5ZG1SRXR4Y";

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        // Hero (match AboutPage.tsx)
        SizedBox(
          height: 260,
          child: Stack(
            fit: StackFit.expand,
            children: [
              CachedNetworkImage(imageUrl: _heroImg, fit: BoxFit.cover),
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color.fromRGBO(0, 0, 0, 0.35), Color.fromRGBO(0, 0, 0, 0.25)],
                  ),
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
                  child: Stack(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(999),
                              color: Colors.white.withValues(alpha: 0.14),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
                            ),
                            child: const Text('Organic • Safe • Fast',
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Bắt nguồn từ Chất lượng,\nDẫn dắt bởi Tự nhiên',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.headlineSmall
                                ?.copyWith(color: Colors.white, fontWeight: FontWeight.w900, height: 1.06),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'FreshFood chọn lọc theo mùa, ưu tiên quy trình bền vững và giao nhanh để bạn luôn nhận được sản phẩm tươi ngon.',
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium
                                ?.copyWith(color: Colors.white.withValues(alpha: 0.92), height: 1.25, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: const [
                            _Pill(text: 'Nguồn gốc rõ ràng'),
                            _Pill(text: 'Đóng gói tiêu chuẩn'),
                            _Pill(text: 'Giao đúng hẹn'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Split: copy + images
              LayoutBuilder(
                builder: (context, c) {
                  final twoCols = c.maxWidth >= 720;
                  final copy = _Card(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('FRESHFOOD',
                            style: theme.textTheme.bodySmall
                                ?.copyWith(letterSpacing: 1.2, fontWeight: FontWeight.w900, color: const Color(0xFF62BF39))),
                        const SizedBox(height: 8),
                        Text('Thực phẩm sạch cho tương lai là hữu thịnh.',
                            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900, height: 1.1)),
                        const SizedBox(height: 10),
                        Text(
                          'FreshFood được hình thành từ niềm tin rằng thực phẩm an toàn phải dễ tiếp cận và đáng tin. '
                          'Chúng tôi làm việc với nông trại đối tác, ưu tiên thu hoạch đúng vụ, hạn chế trung gian và rút ngắn thời gian vận chuyển.',
                          style: theme.textTheme.bodyMedium?.copyWith(color: const Color(0xFF475569), height: 1.35),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Mỗi lô hàng được phân loại, đóng gói theo tiêu chuẩn và ghi nhận quy cách bảo quản để bạn luôn an tâm khi lựa chọn.',
                          style: theme.textTheme.bodyMedium?.copyWith(color: const Color(0xFF475569), height: 1.35),
                        ),
                        const SizedBox(height: 12),
                        _MiniCard(
                          icon: Icons.spa_rounded,
                          title: 'Nguồn hàng theo mùa',
                          sub: 'Tươi ngon, đúng vụ, vị ngon tự nhiên',
                        ),
                        const SizedBox(height: 10),
                        _MiniCard(
                          icon: Icons.eco_rounded,
                          title: 'Ưu tiên bền vững',
                          sub: 'Tôn trọng đất, nước và hệ sinh thái',
                        ),
                      ],
                    ),
                  );

                  final media = _Card(
                    padding: EdgeInsets.zero,
                    child: SizedBox(
                      height: twoCols ? 340 : 320,
                      child: Stack(
                        children: [
                          Positioned.fill(child: ClipRRect(borderRadius: BorderRadius.circular(18), child: CachedNetworkImage(imageUrl: _splitImg, fit: BoxFit.cover))),
                          Positioned(
                            right: 14,
                            bottom: 14,
                            child: Container(
                              width: twoCols ? 160 : 140,
                              height: twoCols ? 140 : 120,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(color: Colors.white.withValues(alpha: 0.6), width: 2),
                                boxShadow: [
                                  BoxShadow(color: const Color(0xFF0F172A).withValues(alpha: 0.16), blurRadius: 18, offset: const Offset(0, 12)),
                                ],
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: CachedNetworkImage(imageUrl: _floatImg, fit: BoxFit.cover),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );

                  if (!twoCols) {
                    return Column(
                      children: [
                        copy,
                        const SizedBox(height: 12),
                        media,
                      ],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: copy),
                      const SizedBox(width: 12),
                      Expanded(child: media),
                    ],
                  );
                },
              ),

              const SizedBox(height: 12),

              // Core values
              _Card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Giá trị cốt lõi', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: const [
                        _ValueCard(icon: Icons.verified_rounded, title: 'Chất lượng hàng đầu', sub: 'Tuyển chọn theo mùa, kiểm tra lô hàng và đóng gói chuẩn trước khi giao.'),
                        _ValueCard(icon: Icons.forest_rounded, title: 'Canh tác bền vững', sub: 'Ưu tiên quy trình thân thiện môi trường và gìn giữ hệ sinh thái địa phương.'),
                        _ValueCard(icon: Icons.groups_rounded, title: 'Hỗ trợ cộng đồng', sub: 'Kết nối nông trại và khách hàng với mức giá hợp lý, minh bạch và công bằng.'),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Sustainability dark block
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  color: const Color(0xFF0F172A),
                  boxShadow: [
                    BoxShadow(color: const Color(0xFF0F172A).withValues(alpha: 0.20), blurRadius: 26, offset: const Offset(0, 14)),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Cam kết bền vững', style: theme.textTheme.titleLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 10),
                    Text(
                      'Chúng tôi giảm thiểu lãng phí trong đóng gói, tối ưu tuyến giao và ưu tiên đối tác có quy trình canh tác bền vững. '
                      'Mục tiêu là tạo ra chuỗi cung ứng lành mạnh cho cả người dùng và môi trường.',
                      style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white.withValues(alpha: 0.88), height: 1.35),
                    ),
                    const SizedBox(height: 12),
                    const _SustainItem(text: 'Bao bì thân thiện hơn'),
                    const _SustainItem(text: 'Tối ưu giao nhận'),
                    const _SustainItem(text: 'Hợp tác nhà vườn lâu dài'),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: const [
                        _TagCard(tag: 'RECYCLE', text: 'Phân loại & tái sử dụng'),
                        _TagCard(tag: 'GREEN', text: 'Nông nghiệp bền vững'),
                        _TagCard(tag: 'TRACE', text: 'Ghi nhận lô hàng & nguồn gốc'),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // CTA
              _Card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Sẵn sàng thưởng thức sự', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
                    Text('khác biệt từ thiên nhiên?', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
                    const SizedBox(height: 8),
                    Text(
                      'Khám phá đợt thu hoạch hàng tuần của chúng tôi được tuyển chọn từ các trang trại độc lập địa phương.',
                      style: theme.textTheme.bodyMedium?.copyWith(color: const Color(0xFF475569), height: 1.35),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 46,
                      child: ElevatedButton(
                        onPressed: () => NavState.tabIndex.value = 1,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF62BF39),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          textStyle: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                        child: const Text('Mua ngay'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  final String text;
  const _Pill({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: Colors.white.withValues(alpha: 0.16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_circle_outline, size: 18, color: Colors.white),
          const SizedBox(width: 6),
          Text(text, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}

class _MiniCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String sub;
  const _MiniCard({required this.icon, required this.title, required this.sub});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: theme.colorScheme.surfaceContainerHighest,
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: const Color(0xFF62BF39).withValues(alpha: 0.12),
            ),
            child: Icon(icon, color: const Color(0xFF62BF39)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w900)),
                const SizedBox(height: 2),
                Text(sub, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant, height: 1.25)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ValueCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String sub;
  const _ValueCard({required this.icon, required this.title, required this.sub});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 240, maxWidth: 420),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: theme.colorScheme.surfaceContainerHighest,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: const Color(0xFF62BF39).withValues(alpha: 0.12),
              ),
              child: Icon(icon, color: const Color(0xFF62BF39)),
            ),
            const SizedBox(height: 10),
            Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            Text(sub, style: theme.textTheme.bodyMedium?.copyWith(color: const Color(0xFF475569), height: 1.35)),
          ],
        ),
      ),
    );
  }
}

class _SustainItem extends StatelessWidget {
  final String text;
  const _SustainItem({required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          const Icon(Icons.check_circle_rounded, size: 18, color: Color(0xFF62BF39)),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white.withValues(alpha: 0.9), fontWeight: FontWeight.w700))),
        ],
      ),
    );
  }
}

class _TagCard extends StatelessWidget {
  final String tag;
  final String text;
  const _TagCard({required this.tag, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Colors.white.withValues(alpha: 0.06),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              color: Colors.white.withValues(alpha: 0.10),
            ),
            child: Text(tag, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 0.6, fontSize: 12)),
          ),
          const SizedBox(height: 8),
          Text(text, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String text;
  final bool isLink;
  const _InfoCard({required this.icon, required this.title, required this.text, this.isLink = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 240, maxWidth: 420),
      child: _Card(
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: const Color(0xFF62BF39).withValues(alpha: 0.12),
              ),
              child: Icon(icon, color: const Color(0xFF62BF39)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 4),
                  Text(
                    text,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: isLink ? const Color(0xFF62BF39) : const Color(0xFF475569),
                      fontWeight: isLink ? FontWeight.w800 : FontWeight.w600,
                      height: 1.25,
                    ),
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

class _ContactTab extends StatefulWidget {
  const _ContactTab();

  @override
  State<_ContactTab> createState() => _ContactTabState();
}

class _ContactTabState extends State<_ContactTab> {
  final _api = ApiClient();
  final _nameCtl = TextEditingController();
  final _emailCtl = TextEditingController();
  final _subjectCtl = TextEditingController();
  final _messageCtl = TextEditingController();

  bool _sending = false;
  String? _msg;
  bool _ok = true;
  bool _success = false;

  static const _heroImg =
      'https://lh3.googleusercontent.com/aida-public/AB6AXuBs5dSP4Xp-IWBr5s8sXdxhf_dNSjq5bu2GxkQT-2X9gMnLtf97bxb1EncYdsreUQaNKPKZZKFFz5kffrys5-aDS2BgtzOFSno0xkGwHkqQtE6MT2qgV7fj5KotENgu_qp0EU5BHE5h0fR4pQf3_ayEF_IaUe3VJBWi4oXmfrGMI87yDyHfJFwVzMPv3UFTYu1Y7ib81IAZrUKAxGLmTdWlD1zKuCkcCcDAqimPsoyQIIr8DWWWo3n-qMnTlgWOxWsW1MQRCAouGKk';
  static const _mapLink = 'https://www.openstreetmap.org/?mlat=10.776&mlon=106.700#map=16/10.776/106.700';
  static const _addr = '123 Đường Nông Nghiệp Xanh, Quận 1, TP. Hồ Chí Minh';
  static const _phone = '1900 1234 56';
  static const _email = 'hello@freshfood.vn';
  static final _office = LatLng(10.776, 106.700);

  @override
  void dispose() {
    _nameCtl.dispose();
    _emailCtl.dispose();
    _subjectCtl.dispose();
    _messageCtl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final name = _nameCtl.text.trim();
    final email = _emailCtl.text.trim();
    final subject = _subjectCtl.text.trim();
    final message = _messageCtl.text.trim();

    if (name.isEmpty || email.isEmpty || subject.isEmpty || message.isEmpty) {
      setState(() {
        _msg = 'Vui lòng nhập đầy đủ thông tin.';
        _ok = false;
      });
      return;
    }

    setState(() {
      _sending = true;
      _msg = null;
      _ok = true;
    });

    try {
      final id = await _api.submitContactMessage(name: name, email: email, subject: subject, message: message);
      if (!mounted) return;
      setState(() {
        _msg = id > 0 ? 'Đã gửi liên hệ (ID: $id).' : 'Đã gửi liên hệ.';
        _ok = true;
        _success = true;
      });
      _subjectCtl.clear();
      _messageCtl.clear();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _msg = '$e'.replaceFirst('Exception: ', '').trim();
        _ok = false;
      });
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (_success) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: _Card(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_circle_rounded, size: 72, color: Color(0xFF62BF39)),
                const SizedBox(height: 10),
                Text('Cảm ơn bạn đã liên hệ!', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
                const SizedBox(height: 6),
                Text(
                  'Chúng tôi đã nhận được tin nhắn của bạn và sẽ phản hồi sớm nhất có thể.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(color: const Color(0xFF64748B), height: 1.35),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 46,
                  child: ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _success = false;
                        _msg = null;
                      });
                      _nameCtl.clear();
                      _emailCtl.clear();
                      _subjectCtl.clear();
                      _messageCtl.clear();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF62BF39),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      textStyle: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    child: const Text('Gửi tin nhắn mới'),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        // Hero (match ContactPage.tsx)
        SizedBox(
          height: 250,
          child: Stack(
            fit: StackFit.expand,
            children: [
              CachedNetworkImage(imageUrl: _heroImg, fit: BoxFit.cover),
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      Color.fromRGBO(15, 40, 20, 0.72),
                      Color.fromRGBO(15, 40, 20, 0.35),
                      Color.fromRGBO(20, 50, 25, 0.25),
                    ],
                  ),
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(999),
                          color: Colors.white.withValues(alpha: 0.14),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.20)),
                        ),
                        child: const Text('KẾT NỐI VỚI CHÚNG TÔI', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 0.6, fontSize: 12)),
                      ),
                      const SizedBox(height: 10),
                      Text('Liên hệ với chúng tôi', style: theme.textTheme.headlineSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 8),
                      Text(
                        'Chúng tôi luôn sẵn sàng lắng nghe góp ý, hợp tác hoặc hỗ trợ bạn — hãy để lại lời nhắn bên dưới.',
                        style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white.withValues(alpha: 0.92), height: 1.25, fontWeight: FontWeight.w600),
                      ),
                      const Spacer(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: const [
                  _InfoCard(icon: Icons.place_outlined, title: 'Địa chỉ', text: _addr),
                  _InfoCard(icon: Icons.phone_outlined, title: 'Điện thoại', text: _phone),
                  _InfoCard(icon: Icons.mail_outline, title: 'Email', text: _email, isLink: true),
                ],
              ),
              const SizedBox(height: 12),
              LayoutBuilder(
                builder: (context, c) {
                  final twoCols = c.maxWidth >= 820;
                  final form = _Card(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text('Gửi lời nhắn cho chúng tôi', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
                        const SizedBox(height: 6),
                        Text('Điền biểu mẫu — đội ngũ FreshFood thường phản hồi trong vòng 24 giờ làm việc.',
                            style: theme.textTheme.bodyMedium?.copyWith(color: const Color(0xFF64748B), height: 1.3)),
                        const SizedBox(height: 12),
                        if (_msg != null) _Banner(text: _msg!, ok: _ok),
                        if (_msg != null) const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(child: _Field(label: 'Họ và tên', controller: _nameCtl, hint: 'Nguyễn Văn A')),
                            const SizedBox(width: 12),
                            Expanded(child: _Field(label: 'Địa chỉ Email', controller: _emailCtl, hint: 'example@email.com', keyboardType: TextInputType.emailAddress)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _Field(label: 'Chủ đề', controller: _subjectCtl, hint: 'Hợp tác, Hỗ trợ đơn hàng…'),
                        const SizedBox(height: 12),
                        _Field(label: 'Tin nhắn của bạn', controller: _messageCtl, hint: 'Bạn cần hỗ trợ điều gì?', maxLines: 5),
                        const SizedBox(height: 14),
                        SizedBox(
                          height: 46,
                          child: ElevatedButton.icon(
                            onPressed: _sending ? null : _send,
                            icon: const Icon(Icons.send_rounded),
                            label: Text(_sending ? 'Đang gửi...' : 'Gửi tin nhắn'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF62BF39),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              textStyle: const TextStyle(fontWeight: FontWeight.w900),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );

                  final map = _Card(
                    padding: EdgeInsets.zero,
                    child: SizedBox(
                      height: 420,
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(18),
                              child: FlutterMap(
                                options: MapOptions(
                                  initialCenter: _office,
                                  initialZoom: 16,
                                  interactionOptions: const InteractionOptions(flags: InteractiveFlag.all),
                                ),
                                children: [
                                  TileLayer(
                                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                    userAgentPackageName: 'freshfood_app',
                                  ),
                                  MarkerLayer(
                                    markers: [
                                      Marker(
                                        point: _office,
                                        width: 48,
                                        height: 48,
                                        child: Container(
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: Colors.white,
                                            boxShadow: [
                                              BoxShadow(
                                                color: const Color(0xFF0F172A).withValues(alpha: 0.22),
                                                blurRadius: 14,
                                                offset: const Offset(0, 8),
                                              ),
                                            ],
                                          ),
                                          child: const Center(
                                            child: Icon(Icons.location_on_rounded, color: Color(0xFF62BF39), size: 30),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Positioned(
                            left: 14,
                            top: 14,
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(14),
                                color: Colors.white,
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF0F172A).withValues(alpha: 0.10),
                                    blurRadius: 14,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: const Icon(Icons.restaurant_rounded, color: Color(0xFF62BF39)),
                            ),
                          ),
                          Positioned(
                            left: 14,
                            right: 14,
                            bottom: 14,
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(18),
                                color: Colors.white,
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF0F172A).withValues(alpha: 0.10),
                                    blurRadius: 14,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('Văn phòng FreshFood', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
                                        const SizedBox(height: 4),
                                        Text(_addr, style: theme.textTheme.bodyMedium?.copyWith(color: const Color(0xFF64748B))),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  SizedBox(
                                    height: 40,
                                    child: OutlinedButton(
                                      onPressed: () async {
                                        await Clipboard.setData(const ClipboardData(text: _mapLink));
                                        if (!context.mounted) return;
                                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã copy link bản đồ.')));
                                      },
                                      style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                                      child: const Text('Copy link', style: TextStyle(fontWeight: FontWeight.w900)),
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

                  if (!twoCols) {
                    return Column(
                      children: [
                        form,
                        const SizedBox(height: 12),
                        map,
                      ],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: form),
                      const SizedBox(width: 12),
                      Expanded(child: map),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _BlogTab extends StatefulWidget {
  const _BlogTab();

  @override
  State<_BlogTab> createState() => _BlogTabState();
}

class _BlogTabState extends State<_BlogTab> {
  final _api = ApiClient();
  final _searchCtl = TextEditingController();
  Timer? _debounce;

  static const int _gridPageSize = 4;
  static const _heroImg =
      'https://lh3.googleusercontent.com/aida-public/AB6AXuDXzR-1ceHXfMCSsB1OUo2HcM-2_sXYb-zrZaEmNWeBA5N9CZd9XoZgGIajhKAdjYvbDe3uB7Iq-XrfFakwf52tj01ZMm4TYpq7OMv3WIHsaYhzBCLB2aucueZagwNib76rGBRdRnFBHERRrDWvKGIN3d_aGAZZf7i6az9910lPeiEbsmBu4rogew9ZOrOZxNacq2OqeaOw9iGPgUXyKo5GtP25wEdlCxFO_M2nSQdg3nTPerZ4KrrpxtyUo9p0PHeQ_2UWmE0Ue_A';
  static const _cats = <String, String>{
    'all': 'Tất cả',
    'knowledge': 'Kiến thức',
    'recipe': 'Công thức nấu ăn',
    'farm': 'Chuyện nông trại',
    'lifestyle': 'Lối sống',
  };

  String _category = 'all';
  int _page = 1;
  String _q = '';
  bool _loading = true;
  String? _err;
  List<BlogPostListItem> _items = const [];

  @override
  void initState() {
    super.initState();
    _searchCtl.addListener(() {
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 350), () {
        final next = _searchCtl.text.trim();
        if (!mounted) return;
        if (next == _q) return;
        setState(() {
          _q = next;
          _page = 1;
        });
        _load(q: next.isEmpty ? null : next);
      });
    });
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtl.dispose();
    super.dispose();
  }

  int _hash(String s) {
    var h = 0;
    for (final c in s.codeUnits) {
      h = (h * 31 + c) & 0x7fffffff;
    }
    return h;
  }

  String _postCategory(String slug) {
    const keys = ['knowledge', 'recipe', 'farm', 'lifestyle'];
    if (slug.trim().isEmpty) return 'knowledge';
    return keys[_hash(slug) % keys.length];
  }

  List<BlogPostListItem> get _sortedFiltered {
    final list = List<BlogPostListItem>.from(_items);
    list.sort((a, b) {
      final ta = (a.publishedAt ?? DateTime.fromMillisecondsSinceEpoch(0)).millisecondsSinceEpoch;
      final tb = (b.publishedAt ?? DateTime.fromMillisecondsSinceEpoch(0)).millisecondsSinceEpoch;
      return tb.compareTo(ta);
    });
    if (_category == 'all') return list;
    return list.where((p) => _postCategory(p.slug) == _category).toList();
  }

  Future<void> _load({String? q}) async {
    setState(() {
      _loading = true;
      _err = null;
    });
    try {
      final list = await _api.getBlogPosts(q: q);
      if (!mounted) return;
      setState(() => _items = list);
    } catch (e) {
      if (!mounted) return;
      setState(() => _err = 'Không tải được blog.\nAPI: ${ApiConfig.apiOrigin}\nLỗi: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filtered = _sortedFiltered;
    final featured = filtered.isEmpty ? null : filtered.first;
    final grid = filtered.length <= 1 ? const <BlogPostListItem>[] : filtered.sublist(1);
    final totalPages = (grid.isEmpty) ? 1 : (grid.length / _gridPageSize).ceil();
    final safePage = _page.clamp(1, totalPages);
    final start = (safePage - 1) * _gridPageSize;
    final end = (start + _gridPageSize).clamp(0, grid.length);
    final slice = (start < end) ? grid.sublist(start, end) : const <BlogPostListItem>[];

    return RefreshIndicator(
      onRefresh: () => _load(q: _q.trim().isEmpty ? null : _q.trim()),
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          // Hero (similar to web)
          Container(
            height: 250,
            margin: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: const Color(0xFF0F172A),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0F172A).withValues(alpha: 0.14),
                  blurRadius: 22,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CachedNetworkImage(imageUrl: _heroImg, fit: BoxFit.cover),
                Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color.fromRGBO(15, 23, 42, 0.74),
                        Color.fromRGBO(15, 23, 42, 0.35),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(999),
                          color: Colors.white.withValues(alpha: 0.14),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
                        ),
                        child: const Text('Chuyện từ đất mẹ', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Kinh nghiệm & Câu chuyện\nLan tỏa lối sống xanh',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w900, height: 1.05),
                      ),
                      const SizedBox(height: 12),
                      _SearchBox(
                        controller: _searchCtl,
                        onSearch: () => _load(q: _searchCtl.text.trim().isEmpty ? null : _searchCtl.text.trim()),
                        filledColor: Colors.white.withValues(alpha: 0.12),
                        borderColor: Colors.white.withValues(alpha: 0.18),
                        hintColor: Colors.white.withValues(alpha: 0.75),
                        iconColor: Colors.white.withValues(alpha: 0.9),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Category filters (like web)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                for (final e in _cats.entries) ...[
                  _FilterChip(
                    label: e.value,
                    active: _category == e.key,
                    onTap: () {
                      if (!mounted) return;
                      setState(() {
                        _category = e.key;
                        _page = 1;
                      });
                    },
                  ),
                  const SizedBox(width: 10),
                ]
              ],
            ),
          ),
          const SizedBox(height: 12),

          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 28),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_err != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              child: Text(_err!, style: theme.textTheme.bodyMedium?.copyWith(color: const Color(0xFFB91C1C), fontWeight: FontWeight.w800)),
            )
          else if (filtered.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Column(
                children: [
                  Icon(Icons.article_outlined, size: 46, color: const Color(0xFF94A3B8).withValues(alpha: 0.9)),
                  const SizedBox(height: 10),
                  Text(
                    _q.isNotEmpty
                        ? 'Không tìm thấy bài viết phù hợp.'
                        : (_category != 'all' ? 'Không có bài trong mục này.' : 'Chưa có bài viết nào.'),
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  Text('Hãy quay lại sau nhé.', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                ],
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
              child: Column(
                children: [
                  if (featured != null) ...[
                    _FeaturedBlogCard(
                      post: featured,
                      categoryLabel: _cats[_postCategory(featured.slug)] ?? 'Blog',
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => BlogDetailScreen(slug: featured.slug))),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (grid.isEmpty)
                    Text('Chỉ có một bài trong danh sách hiện tại.', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant))
                  else ...[
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 1,
                        mainAxisSpacing: 12,
                        childAspectRatio: 0.92,
                      ),
                      itemCount: slice.length,
                      itemBuilder: (context, i) {
                        final p = slice[i];
                        return _BlogCard(
                          post: p,
                          categoryLabel: _cats[_postCategory(p.slug)] ?? 'Blog',
                          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => BlogDetailScreen(slug: p.slug))),
                        );
                      },
                    ),
                    if (totalPages > 1) ...[
                      const SizedBox(height: 12),
                      _Pager(
                        page: safePage,
                        totalPages: totalPages,
                        onPrev: safePage <= 1 ? null : () => setState(() => _page = safePage - 1),
                        onNext: safePage >= totalPages ? null : () => setState(() => _page = safePage + 1),
                        onPick: (n) => setState(() => _page = n),
                      ),
                    ],
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class BlogDetailScreen extends StatefulWidget {
  final String slug;
  const BlogDetailScreen({super.key, required this.slug});

  @override
  State<BlogDetailScreen> createState() => _BlogDetailScreenState();
}

class _BlogDetailScreenState extends State<BlogDetailScreen> {
  final _api = ApiClient();
  bool _loading = true;
  String? _err;
  BlogPostDetail? _post;

  bool _loadingRelated = false;
  List<BlogPostListItem> _related = const [];

  bool _loadingComments = false;
  bool _sendingComment = false;
  String? _commentErr;
  List<BlogComment> _comments = const [];
  final _commentCtl = TextEditingController();
  final _commentFocus = FocusNode();
  BlogComment? _replyTo;
  bool _composeOpen = false;

  List<BlogComment> _previewComments({int rootLimit = 10}) {
    final byParent = <int, List<BlogComment>>{};
    final roots = <BlogComment>[];
    for (final c in _comments) {
      final pid = c.parentCommentId;
      if (pid == null) {
        roots.add(c);
      } else {
        (byParent[pid] ??= <BlogComment>[]).add(c);
      }
    }
    final pickedRoots = roots.take(rootLimit).toList(growable: false);
    final out = <BlogComment>[];
    for (final r in pickedRoots) {
      out.add(r);
      final reps = byParent[r.id];
      if (reps != null && reps.isNotEmpty) out.addAll(reps);
    }
    return out;
  }

  Future<void> _openAllCommentsSheet() async {
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);
        final sheetCtl = TextEditingController();
        final sheetFocus = FocusNode();
        BlogComment? sheetReplyTo;
        var sheetComposeOpen = false;
        var sheetSending = false;
        String? sheetErr;
        final sheetOpenReplies = <int, bool>{..._openReplies};

        Future<void> sheetSend() async {
          final user = AuthState.currentUser.value;
          if (user == null) {
            Navigator.of(sheetContext).push(MaterialPageRoute(builder: (_) => const AuthLoginScreen()));
            return;
          }
          final txt = sheetCtl.text.trim();
          if (txt.isEmpty) {
            // keep it lightweight; no banner needed
            return;
          }
          if (sheetSending) return;
          try {
            sheetErr = null;
            sheetSending = true;
            (sheetContext as Element).markNeedsBuild();
            await _api.createBlogComment(
              slug: widget.slug,
              userId: user.userId,
              content: txt,
              parentCommentId: sheetReplyTo?.id,
            );
            sheetCtl.clear();
            sheetReplyTo = null;
            sheetComposeOpen = false;
            if (mounted) {
              await _loadComments(silent: true);
              if (mounted) setState(() {});
            }
          } catch (e) {
            sheetErr = e.toString();
          } finally {
            sheetSending = false;
            if (sheetContext.mounted) (sheetContext as Element).markNeedsBuild();
          }
        }

        return SafeArea(
          top: false,
          child: StatefulBuilder(
            builder: (context, setLocal) {
              return DraggableScrollableSheet(
                expand: false,
                initialChildSize: 0.92,
                minChildSize: 0.55,
                maxChildSize: 0.98,
                builder: (context, scrollCtl) {
                  final open = sheetComposeOpen || sheetReplyTo != null;
                  return Padding(
                    padding: EdgeInsets.fromLTRB(16, 10, 16, 14 + MediaQuery.of(context).viewInsets.bottom),
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
                                'Tất cả bình luận (${_comments.length})',
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
                          child: ListView(
                            controller: scrollCtl,
                            children: [
                              if (_loadingComments)
                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  child: Text('Đang tải…', style: theme.textTheme.bodyMedium?.copyWith(color: const Color(0xFF64748B))),
                                )
                              else if (_comments.isEmpty)
                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  child: Text(
                                    'Chưa có bình luận. Hãy là người đầu tiên chia sẻ!',
                                    style: theme.textTheme.bodyMedium?.copyWith(color: const Color(0xFF64748B)),
                                  ),
                                )
                              else
                                ..._buildCommentTreeFrom(
                                  theme,
                                  _comments,
                                  onReplyTap: (root) {
                                    setLocal(() {
                                      sheetReplyTo = root;
                                      sheetComposeOpen = true;
                                    });
                                    Future<void>.delayed(Duration.zero, () => sheetFocus.requestFocus());
                                  },
                                  openReplies: sheetOpenReplies,
                                  onToggleReplies: (rootId, nextOpen) {
                                    setLocal(() => sheetOpenReplies[rootId] = nextOpen);
                                  },
                                ),
                              const SizedBox(height: 12),
                              ValueListenableBuilder<AuthUser?>(
                                valueListenable: AuthState.currentUser,
                                builder: (context, u, _) {
                                  if (u == null) {
                                    return Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            'Bạn cần đăng nhập để bình luận.',
                                            style: theme.textTheme.bodyMedium
                                                ?.copyWith(color: const Color(0xFF64748B), fontWeight: FontWeight.w700),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        SizedBox(
                                          height: 40,
                                          child: ElevatedButton(
                                            onPressed: () => Navigator.of(sheetContext)
                                                .push(MaterialPageRoute(builder: (_) => const AuthLoginScreen())),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: const Color(0xFF62BF39),
                                              foregroundColor: Colors.white,
                                              elevation: 0,
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                              textStyle: const TextStyle(fontWeight: FontWeight.w900),
                                            ),
                                            child: const Text('Đăng nhập'),
                                          ),
                                        ),
                                      ],
                                    );
                                  }

                                  if (!open) {
                                    return Align(
                                      alignment: Alignment.centerLeft,
                                      child: SizedBox(
                                        height: 40,
                                        child: OutlinedButton.icon(
                                          onPressed: () {
                                            setLocal(() => sheetComposeOpen = true);
                                            Future<void>.delayed(Duration.zero, () => sheetFocus.requestFocus());
                                          },
                                          icon: const Icon(Icons.edit_outlined, size: 18, color: Color(0xFF62BF39)),
                                          label: const Text('Viết bình luận',
                                              style: TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF62BF39))),
                                          style: OutlinedButton.styleFrom(side: BorderSide.none),
                                        ),
                                      ),
                                    );
                                  }

                                  return Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      if (sheetReplyTo != null)
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                'Đang trả lời ${sheetReplyTo!.userName}',
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: theme.textTheme.bodyMedium
                                                    ?.copyWith(fontWeight: FontWeight.w900, color: const Color(0xFF62BF39)),
                                              ),
                                            ),
                                            TextButton(
                                              onPressed: () => setLocal(() => sheetReplyTo = null),
                                              child: const Text('Hủy', style: TextStyle(fontWeight: FontWeight.w900)),
                                            ),
                                          ],
                                        )
                                      else
                                        Align(
                                          alignment: Alignment.centerRight,
                                          child: TextButton(
                                            onPressed: () => setLocal(() => sheetComposeOpen = false),
                                            child: const Text('Ẩn', style: TextStyle(fontWeight: FontWeight.w900)),
                                          ),
                                        ),
                                      const SizedBox(height: 6),
                                      if (sheetErr != null) ...[
                                        Text(sheetErr!,
                                            style: theme.textTheme.bodyMedium
                                                ?.copyWith(color: const Color(0xFFB91C1C), fontWeight: FontWeight.w800)),
                                        const SizedBox(height: 10),
                                      ],
                                      TextField(
                                        controller: sheetCtl,
                                        focusNode: sheetFocus,
                                        minLines: 3,
                                        maxLines: 6,
                                        decoration: InputDecoration(
                                          hintText: 'Viết bình luận của bạn tại đây...',
                                          filled: true,
                                          fillColor: theme.colorScheme.surfaceContainerHighest,
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                          enabledBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(14),
                                            borderSide: BorderSide(color: theme.colorScheme.outlineVariant),
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(14),
                                            borderSide: const BorderSide(color: Color(0xFF62BF39), width: 1.6),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      Align(
                                        alignment: Alignment.centerRight,
                                        child: SizedBox(
                                          height: 44,
                                          child: ElevatedButton(
                                            onPressed: sheetSending ? null : () async {
                                              setLocal(() {});
                                              await sheetSend();
                                              if (context.mounted) setLocal(() {});
                                            },
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: const Color(0xFF62BF39),
                                              foregroundColor: Colors.white,
                                              elevation: 0,
                                              padding: const EdgeInsets.symmetric(horizontal: 16),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                              textStyle: const TextStyle(fontWeight: FontWeight.w900),
                                            ),
                                            child: Text(sheetSending ? 'Đang gửi…' : 'Gửi bình luận'),
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
                  );
                },
              );
            },
          ),
        );
      },
    );
  }
  Timer? _commentsPoll;
  int _commentsSig = 0;
  final Map<int, bool> _openReplies = <int, bool>{};

  String _sanitizeHtml(String html) {
    final s = html.trim();
    if (s.isEmpty) return s;
    // Backend content can include inline CSS like `font-feature-settings`
    // which may crash some flutter_html CSS parsing. Strip inline styles.
    return s
        .replaceAll(RegExp(r'\sstyle="[^"]*"'), '')
        .replaceAll(RegExp(r"\sstyle='[^']*'"), '');
  }

  @override
  void initState() {
    super.initState();
    _load();
    _loadComments();
    _commentsPoll = Timer.periodic(const Duration(seconds: 4), (_) async {
      if (!mounted) return;
      if (_sendingComment) return;
      // If page is open, keep comments fresh like "realtime".
      await _loadComments(silent: true);
    });
  }

  @override
  void dispose() {
    _commentsPoll?.cancel();
    _commentCtl.dispose();
    _commentFocus.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _err = null;
    });
    try {
      final p = await _api.getBlogPostBySlug(widget.slug);
      if (!mounted) return;
      setState(() => _post = p);
    } catch (e) {
      if (!mounted) return;
      setState(() => _err = 'Không tải được bài viết.\nAPI: ${ApiConfig.apiOrigin}\nLỗi: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  int _hash(String s) {
    var h = 0;
    for (final c in s.codeUnits) {
      h = (h * 31 + c) & 0x7fffffff;
    }
    return h;
  }

  String _postCategory(String slug) {
    const keys = ['knowledge', 'recipe', 'farm', 'lifestyle'];
    if (slug.trim().isEmpty) return 'knowledge';
    return keys[_hash(slug) % keys.length];
  }

  String _timeAgoVi(DateTime d) {
    final now = DateTime.now().toUtc();
    final dt = d.isUtc ? d : d.toUtc();
    final sec = now.difference(dt).inSeconds;
    if (sec < 45) return 'Vừa xong';
    if (sec < 3600) return '${(sec / 60).floor()} phút trước';
    if (sec < 86400) return '${(sec / 3600).floor()} giờ trước';
    if (sec < 604800) return '${(sec / 86400).floor()} ngày trước';
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }

  Future<void> _loadRelated() async {
    if (_post == null) return;
    setState(() {
      _loadingRelated = true;
      _related = const [];
    });
    try {
      final all = await _api.getBlogPosts();
      if (!mounted) return;
      final cat = _postCategory(_post!.slug);
      final list = all
          .where((p) => p.slug.trim().isNotEmpty && p.slug != _post!.slug)
          .toList()
        ..sort((a, b) {
          final ta = (a.publishedAt ?? DateTime.fromMillisecondsSinceEpoch(0)).millisecondsSinceEpoch;
          final tb = (b.publishedAt ?? DateTime.fromMillisecondsSinceEpoch(0)).millisecondsSinceEpoch;
          return tb.compareTo(ta);
        });
      final sameCat = list.where((p) => _postCategory(p.slug) == cat).toList();
      final pick = (sameCat.length >= 3 ? sameCat : list).take(3).toList();
      setState(() => _related = pick);
    } catch (_) {
      if (!mounted) return;
      setState(() => _related = const []);
    } finally {
      if (mounted) setState(() => _loadingRelated = false);
    }
  }

  int _sigOf(List<BlogComment> rows) {
    var h = 17;
    for (final c in rows) {
      h = (h * 31 + c.id) & 0x7fffffff;
      h = (h * 31 + c.createdAt.millisecondsSinceEpoch) & 0x7fffffff;
    }
    return h;
  }

  Future<void> _loadComments({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loadingComments = true;
        _commentErr = null;
      });
    }
    try {
      final rows = await _api.getBlogCommentsBySlug(widget.slug);
      if (!mounted) return;
      final sig = _sigOf(rows);
      if (sig == _commentsSig) return;
      setState(() {
        _comments = rows;
        _commentsSig = sig;
      });
    } catch (e) {
      if (!mounted) return;
      if (!silent) setState(() => _commentErr = '$e'.replaceFirst('Exception: ', '').trim());
    } finally {
      if (!silent && mounted) setState(() => _loadingComments = false);
    }
  }

  Future<void> _sendComment() async {
    final user = AuthState.currentUser.value;
    if (user == null) {
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AuthLoginScreen()));
      return;
    }
    final txt = _commentCtl.text.trim();
    if (txt.isEmpty) return;

    setState(() {
      _sendingComment = true;
      _commentErr = null;
    });
    try {
      await _api.createBlogComment(
        slug: widget.slug,
        userId: user.userId,
        content: txt,
        parentCommentId: _replyTo?.id,
      );
      if (!mounted) return;
      _commentCtl.clear();
      setState(() {
        _replyTo = null;
        _composeOpen = false;
      });
      await _loadComments();
    } catch (e) {
      if (!mounted) return;
      setState(() => _commentErr = '$e'.replaceFirst('Exception: ', '').trim());
    } finally {
      if (mounted) setState(() => _sendingComment = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Blog')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : (_err != null)
              ? Center(child: Padding(padding: const EdgeInsets.all(16), child: Text(_err!)))
              : (_post == null)
                  ? const Center(child: Text('Không tìm thấy bài viết.'))
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        if ((_post!.coverImageUrl ?? '').trim().isNotEmpty) ...[
                          ClipRRect(
                            borderRadius: BorderRadius.circular(18),
                            child: CachedNetworkImage(
                              imageUrl: ApiConfig.resolveMediaUrl(_post!.coverImageUrl),
                              height: 200,
                              fit: BoxFit.cover,
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                        Text(_post!.title, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900, height: 1.05)),
                        const SizedBox(height: 8),
                        if ((_post!.excerpt ?? '').trim().isNotEmpty)
                          Text(_post!.excerpt!, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant, height: 1.35)),
                        const SizedBox(height: 14),
                        _Card(
                          child: Html(
                            data: _sanitizeHtml(_post!.content),
                            style: {
                              'body': Style(
                                margin: Margins.zero,
                                padding: HtmlPaddings.zero,
                                color: theme.colorScheme.onSurface,
                                lineHeight: const LineHeight(1.35),
                                fontSize: FontSize(theme.textTheme.bodyMedium?.fontSize ?? 14),
                                fontWeight: FontWeight.w500,
                              ),
                              'p': Style(margin: Margins.only(bottom: 10)),
                              'h1': Style(fontSize: FontSize.xLarge, fontWeight: FontWeight.w900),
                              'h2': Style(fontSize: FontSize.large, fontWeight: FontWeight.w900),
                              'h3': Style(fontSize: FontSize.medium, fontWeight: FontWeight.w900),
                              'li': Style(margin: Margins.only(bottom: 6)),
                              'a': Style(color: const Color(0xFF62BF39), fontWeight: FontWeight.w800),
                              'blockquote': Style(
                                padding: HtmlPaddings.symmetric(horizontal: 12, vertical: 10),
                                backgroundColor: const Color(0xFF62BF39).withValues(alpha: 0.10),
                                border: Border(left: BorderSide(color: const Color(0xFF62BF39), width: 3)),
                                margin: Margins.only(bottom: 12),
                              ),
                            },
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Related posts (like web)
                        Row(
                          children: [
                            Expanded(child: Text('Bài viết liên quan', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900))),
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(),
                              child: const Text('Quay lại'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        if (_related.isEmpty && !_loadingRelated)
                          FutureBuilder<void>(
                            future: Future<void>(() async {
                              await Future<void>.delayed(const Duration(milliseconds: 1));
                              if (mounted) await _loadRelated();
                            }),
                            builder: (context, _) => const SizedBox.shrink(),
                          )
                        else if (_loadingRelated)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 14),
                            child: Center(child: CircularProgressIndicator()),
                          )
                        else
                          SizedBox(
                            height: 210,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: _related.length,
                              separatorBuilder: (_, __) => const SizedBox(width: 12),
                              itemBuilder: (context, i) => _RelatedPostCard(post: _related[i]),
                            ),
                          ),

                        const SizedBox(height: 16),

                        // Comments (match web)
                        Row(
                          children: [
                            Text('Bình luận', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(999),
                                color: theme.colorScheme.surfaceContainerHighest,
                              ),
                              child: Text(
                                '${_comments.length}',
                                style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w900, color: theme.colorScheme.onSurfaceVariant),
                              ),
                            ),
                            const Spacer(),
                            ValueListenableBuilder<AuthUser?>(
                              valueListenable: AuthState.currentUser,
                              builder: (context, u, _) {
                                if (u == null) return const SizedBox.shrink();
                                final open = _composeOpen || _replyTo != null;
                                if (open) return const SizedBox.shrink();
                                return SizedBox(
                                  height: 40,
                                  child: OutlinedButton.icon(
                                    onPressed: () {
                                      setState(() => _composeOpen = true);
                                      Future<void>.delayed(Duration.zero, () => _commentFocus.requestFocus());
                                    },
                                    icon: const Icon(Icons.edit_outlined, size: 18, color: Color(0xFF62BF39)),
                                    label: const Text('Viết bình luận', style: TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF62BF39))),
                                    style: OutlinedButton.styleFrom(
                                      side: BorderSide.none,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        if (_loadingComments)
                          Text('Đang tải…', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant))
                        else if (_comments.isEmpty)
                          Text('Chưa có bình luận. Hãy là người đầu tiên chia sẻ!', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant))
                        else
                          ..._buildCommentTreeFrom(theme, _previewComments(rootLimit: 10)),

                        if (!_loadingComments && _comments.length > 10) ...[
                          const SizedBox(height: 4),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton(
                              onPressed: _openAllCommentsSheet,
                              child: const Text('Xem tất cả bình luận', style: TextStyle(fontWeight: FontWeight.w900)),
                            ),
                          ),
                        ],

                        // const SizedBox(height: 14),
                        // Text('Để lại bình luận của bạn', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
                        const SizedBox(height: 10),
                        if (_commentErr != null)
                          Text(_commentErr!, style: theme.textTheme.bodyMedium?.copyWith(color: const Color(0xFFB91C1C), fontWeight: FontWeight.w800)),
                        if (_commentErr != null) const SizedBox(height: 10),
                        ValueListenableBuilder<AuthUser?>(
                          valueListenable: AuthState.currentUser,
                          builder: (context, u, _) {
                            if (u == null) {
                              return Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      'Bạn cần đăng nhập để bình luận.',
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(color: const Color(0xFF64748B), fontWeight: FontWeight.w700),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  SizedBox(
                                    height: 40,
                                    child: ElevatedButton(
                                      onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AuthLoginScreen())),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF62BF39),
                                        foregroundColor: Colors.white,
                                        elevation: 0,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                        textStyle: const TextStyle(fontWeight: FontWeight.w900),
                                      ),
                                      child: const Text('Đăng nhập'),
                                    ),
                                  ),
                                ],
                              );
                            }

                            final open = _composeOpen || _replyTo != null;
                            if (!open) {
                              return const SizedBox.shrink();
                            }

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (_replyTo != null)
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          'Đang trả lời ${_replyTo!.userName}',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w900, color: const Color(0xFF62BF39)),
                                        ),
                                      ),
                                      TextButton(
                                        onPressed: () => setState(() => _replyTo = null),
                                        child: const Text('Hủy', style: TextStyle(fontWeight: FontWeight.w900)),
                                      ),
                                    ],
                                  )
                                else
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: TextButton(
                                      onPressed: () => setState(() => _composeOpen = false),
                                      child: const Text('Ẩn', style: TextStyle(fontWeight: FontWeight.w900)),
                                    ),
                                  ),
                                const SizedBox(height: 6),
                                Text('Bình luận',
                                    style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w900, color: const Color(0xFF64748B))),
                                const SizedBox(height: 6),
                                TextField(
                                  controller: _commentCtl,
                                  focusNode: _commentFocus,
                                  minLines: 4,
                                  maxLines: 6,
                                  decoration: InputDecoration(
                                    hintText: 'Viết bình luận của bạn tại đây...',
                                    filled: true,
                                    fillColor: theme.colorScheme.surfaceContainerHighest,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      borderSide: BorderSide(color: theme.colorScheme.outlineVariant),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      borderSide: const BorderSide(color: Color(0xFF62BF39), width: 1.6),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: SizedBox(
                                    height: 44,
                                    child: ElevatedButton(
                                      onPressed: _sendingComment ? null : _sendComment,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF62BF39),
                                        foregroundColor: Colors.white,
                                        elevation: 0,
                                        padding: const EdgeInsets.symmetric(horizontal: 16),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                        textStyle: const TextStyle(fontWeight: FontWeight.w900),
                                      ),
                                      child: Text(_sendingComment ? 'Đang gửi…' : 'Gửi bình luận'),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
    );
  }

  List<Widget> _buildCommentTreeFrom(
    ThemeData theme,
    List<BlogComment> comments, {
    void Function(BlogComment root)? onReplyTap,
    Map<int, bool>? openReplies,
    void Function(int rootId, bool nextOpen)? onToggleReplies,
  }) {
    final byParent = <int, List<BlogComment>>{};
    final roots = <BlogComment>[];
    for (final c in comments) {
      final pid = c.parentCommentId;
      if (pid == null) {
        roots.add(c);
      } else {
        (byParent[pid] ??= <BlogComment>[]).add(c);
      }
    }
    // keep newest-first like API
    final out = <Widget>[];
    for (final r in roots) {
      final replies = byParent[r.id] ?? const <BlogComment>[];
      final openMap = openReplies ?? _openReplies;
      final isOpen = openMap[r.id] ?? false;
      out.add(_CommentTile(
        comment: r,
        isReply: false,
        timeLabel: _timeAgoVi(r.createdAt),
        replyCount: replies.length,
        repliesOpen: isOpen,
        onToggleReplies: replies.isEmpty
            ? null
            : () {
                if (onToggleReplies != null) {
                  onToggleReplies(r.id, !isOpen);
                  return;
                }
                setState(() {
                  _openReplies[r.id] = !isOpen;
                });
              },
        onReply: () {
          if (onReplyTap != null) {
            onReplyTap(r);
            return;
          }
          setState(() {
            _replyTo = r;
            _composeOpen = true;
          });
          Future<void>.delayed(Duration.zero, () => _commentFocus.requestFocus());
        },
      ));
      if (isOpen && replies.isNotEmpty) {
        out.add(const SizedBox(height: 8));
        out.add(
          Container(
            margin: const EdgeInsets.only(left: 14),
            padding: const EdgeInsets.only(left: 10),
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(
                  color: theme.colorScheme.outlineVariant.withValues(alpha: 0.7),
                  width: 2,
                ),
              ),
            ),
            child: Column(
              children: [
                for (final rep in replies) ...[
                  _CommentTile(
                    comment: rep,
                    isReply: true,
                    timeLabel: _timeAgoVi(rep.createdAt),
                    replyCount: 0,
                    repliesOpen: false,
                    onToggleReplies: null,
                    onReply: () {
                      if (onReplyTap != null) {
                        onReplyTap(r);
                        return;
                      }
                      setState(() {
                        _replyTo = r;
                        _composeOpen = true;
                      });
                      Future<void>.delayed(Duration.zero, () => _commentFocus.requestFocus());
                    },
                  ),
                  const SizedBox(height: 6),
                ],
              ],
            ),
          ),
        );
      }
      out.add(const SizedBox(height: 6));
    }
    return out;
  }
}

class _RelatedPostCard extends StatelessWidget {
  final BlogPostListItem post;
  const _RelatedPostCard({required this.post});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cover = ApiConfig.resolveMediaUrl(post.coverImageUrl);
    return InkWell(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => BlogDetailScreen(slug: post.slug))),
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: 260,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: theme.colorScheme.surface,
          border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.65)),
        ),
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          height: 210,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (cover.isNotEmpty)
                CachedNetworkImage(imageUrl: cover, height: 108, fit: BoxFit.cover)
              else
                Container(
                  height: 108,
                  color: theme.colorScheme.surfaceContainerHighest,
                  child: const Icon(Icons.image_not_supported_outlined, color: Color(0xFF94A3B8)),
                ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        post.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900, height: 1.15),
                      ),
                      const SizedBox(height: 6),
                      if ((post.excerpt ?? '').trim().isNotEmpty)
                        Expanded(
                          child: Text(
                            post.excerpt!,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(color: const Color(0xFF64748B), height: 1.25, fontWeight: FontWeight.w700),
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

class _CommentTile extends StatelessWidget {
  final BlogComment comment;
  final String timeLabel;
  final VoidCallback onReply;
  final bool isReply;
  final int replyCount;
  final bool repliesOpen;
  final VoidCallback? onToggleReplies;
  const _CommentTile({
    required this.comment,
    required this.isReply,
    required this.timeLabel,
    required this.onReply,
    required this.replyCount,
    required this.repliesOpen,
    required this.onToggleReplies,
  });

  String _initials() {
    final parts = comment.userName.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
    if (parts.isEmpty) return 'U';
    final a = parts.first.characters.first.toUpperCase();
    final b = parts.length > 1 ? parts.last.characters.first.toUpperCase() : '';
    return '$a$b';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final avatar = ApiConfig.resolveMediaUrl(comment.avatarUrl);
    final bubbleBg = theme.colorScheme.surfaceContainerHighest;
    return Padding(
      padding: EdgeInsets.only(left: isReply ? 0 : 0),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: const Color(0xFF62BF39).withValues(alpha: 0.12),
                  backgroundImage: avatar.isEmpty ? null : CachedNetworkImageProvider(avatar),
                  child: avatar.isEmpty
                      ? Text(_initials(), style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF62BF39)))
                      : null,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: bubbleBg,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(comment.userName, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w900)),
                            const SizedBox(height: 4),
                            Text(
                              comment.content,
                              style: theme.textTheme.bodyMedium?.copyWith(color: const Color(0xFF475569), height: 1.3),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        runSpacing: 0,
                        children: [
                          Text(
                            timeLabel,
                            style: theme.textTheme.bodySmall?.copyWith(color: const Color(0xFF94A3B8), fontWeight: FontWeight.w800),
                          ),
                          if (!isReply && replyCount > 0 && onToggleReplies != null)
                            TextButton(
                              onPressed: onToggleReplies,
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                foregroundColor: const Color(0xFF64748B),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                visualDensity: VisualDensity.compact,
                              ),
                              child: Text(
                                repliesOpen ? 'Ẩn phản hồi' : 'Xem tất cả $replyCount phản hồi',
                                style: const TextStyle(fontWeight: FontWeight.w900),
                              ),
                            ),
                          TextButton(
                            onPressed: onReply,
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              visualDensity: VisualDensity.compact,
                            ),
                            child: const Text('Trả lời', style: TextStyle(fontWeight: FontWeight.w900)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}


class _BlogCard extends StatelessWidget {
  final BlogPostListItem post;
  final VoidCallback onTap;
  final String categoryLabel;
  const _BlogCard({required this.post, required this.onTap, required this.categoryLabel});

  String _dateLabel() {
    final d = post.publishedAt;
    if (d == null) return '';
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$day/$m/${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cover = ApiConfig.resolveMediaUrl(post.coverImageUrl);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: _Card(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (cover.isNotEmpty)
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                child: CachedNetworkImage(imageUrl: cover, height: 220, fit: BoxFit.cover),
              )
            else
              Container(
                height: 220,
                decoration: const BoxDecoration(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
                  color: Color(0xFFF1F5F9),
                ),
                child: const Icon(Icons.image_not_supported_outlined, color: Color(0xFF94A3B8)),
              ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    categoryLabel.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF62BF39),
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.4,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      if (_dateLabel().isNotEmpty)
                        Text(_dateLabel(),
                            style: theme.textTheme.bodySmall?.copyWith(color: const Color(0xFF64748B), fontWeight: FontWeight.w800)),
                      const Spacer(),
                      Text('${post.viewCount} views',
                          style: theme.textTheme.bodySmall?.copyWith(color: const Color(0xFF94A3B8), fontWeight: FontWeight.w800)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(post.title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900, height: 1.15)),
                  if ((post.excerpt ?? '').trim().isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      post.excerpt!,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(color: const Color(0xFF475569), height: 1.3),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeaturedBlogCard extends StatelessWidget {
  final BlogPostListItem post;
  final String categoryLabel;
  final VoidCallback onTap;
  const _FeaturedBlogCard({required this.post, required this.categoryLabel, required this.onTap});

  String _dateLabel() {
    final d = post.publishedAt;
    if (d == null) return '—';
    return '${d.day} Tháng ${d.month}, ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cover = ApiConfig.resolveMediaUrl(post.coverImageUrl);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: theme.colorScheme.surface,
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F172A).withValues(alpha: 0.08),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (cover.isNotEmpty)
              CachedNetworkImage(imageUrl: cover, height: 220, fit: BoxFit.cover)
            else
              Container(
                height: 220,
                color: theme.colorScheme.surfaceContainerHighest,
                child: const Icon(Icons.image_not_supported_outlined, color: Color(0xFF94A3B8)),
              ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    categoryLabel.toUpperCase(),
                    style: theme.textTheme.bodySmall?.copyWith(color: const Color(0xFF62BF39), fontWeight: FontWeight.w900, letterSpacing: 0.4),
                  ),
                  const SizedBox(height: 6),
                  Text(_dateLabel(), style: theme.textTheme.bodySmall?.copyWith(color: const Color(0xFF64748B), fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  Text(post.title, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900, height: 1.1)),
                  if ((post.excerpt ?? '').trim().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      post.excerpt!,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(color: const Color(0xFF475569), height: 1.3),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Text('Đọc tiếp →', style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w900, color: const Color(0xFF62BF39))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _FilterChip({required this.label, required this.active, required this.onTap});

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
          color: active ? const Color(0xFF62BF39) : theme.colorScheme.surfaceContainerHighest,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? Colors.white : theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w900,
          ),
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
  final void Function(int page) onPick;
  const _Pager({required this.page, required this.totalPages, required this.onPrev, required this.onNext, required this.onPick});

  List<int> _nums() {
    if (totalPages <= 7) return List<int>.generate(totalPages, (i) => i + 1);
    final s = <int>{1, totalPages, page, page - 1, page + 1}..removeWhere((x) => x < 1 || x > totalPages);
    final list = s.toList()..sort();
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final nums = _nums();
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(onPressed: onPrev, icon: const Icon(Icons.chevron_left_rounded)),
        for (var i = 0; i < nums.length; i++) ...[
          if (i > 0 && nums[i] - nums[i - 1] > 1)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 6),
              child: Text('…', style: TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF94A3B8))),
            ),
          InkWell(
            onTap: () => onPick(nums[i]),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 38,
              height: 38,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: nums[i] == page ? const Color(0xFF62BF39) : theme.colorScheme.surfaceContainerHighest,
              ),
              child: Center(
                child: Text(
                  '${nums[i]}',
                  style: TextStyle(
                    color: nums[i] == page ? Colors.white : theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ),
        ],
        IconButton(onPressed: onNext, icon: const Icon(Icons.chevron_right_rounded)),
      ],
    );
  }
}

class _SearchBox extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSearch;
  final Color? filledColor;
  final Color? borderColor;
  final Color? hintColor;
  final Color? iconColor;
  const _SearchBox({
    required this.controller,
    required this.onSearch,
    this.filledColor,
    this.borderColor,
    this.hintColor,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return TextField(
      controller: controller,
      textInputAction: TextInputAction.search,
      onSubmitted: (_) => onSearch(),
      decoration: InputDecoration(
        hintText: 'Tìm bài viết…',
        filled: true,
        fillColor: filledColor ?? const Color(0xFFF8FAFC),
        prefixIcon: Icon(Icons.search_rounded, color: iconColor),
        suffixIcon: IconButton(onPressed: onSearch, icon: Icon(Icons.arrow_forward_rounded, color: iconColor)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: borderColor ?? theme.colorScheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF62BF39), width: 1.6),
        ),
        hintStyle: TextStyle(color: hintColor),
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  final String text;
  final bool ok;
  const _Banner({required this.text, required this.ok});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bg = ok ? const Color(0xFF62BF39).withValues(alpha: 0.10) : const Color(0xFFEF4444).withValues(alpha: 0.10);
    final fg = ok ? const Color(0xFF166534) : const Color(0xFFB91C1C);
    final icon = ok ? Icons.check_circle_outline : Icons.error_outline;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), color: bg),
      child: Row(
        children: [
          Icon(icon, color: fg),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: theme.textTheme.bodyMedium?.copyWith(color: fg, fontWeight: FontWeight.w800, height: 1.25)),
          ),
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final String label;
  final String? hint;
  final TextEditingController controller;
  final TextInputType? keyboardType;
  final int maxLines;
  const _Field({
    required this.label,
    required this.controller,
    this.hint,
    this.keyboardType,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w900, color: theme.colorScheme.onSurfaceVariant, letterSpacing: 0.35)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: theme.colorScheme.surfaceContainerHighest,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: theme.colorScheme.outlineVariant),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFF62BF39), width: 1.6),
            ),
          ),
        ),
      ],
    );
  }
}

class _Card extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  const _Card({required this.child, this.padding = const EdgeInsets.all(14)});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: padding,
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
      child: child,
    );
  }
}

