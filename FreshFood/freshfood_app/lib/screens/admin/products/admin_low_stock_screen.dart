import 'package:flutter/material.dart';
import 'package:freshfood_app/api/api_client.dart';
import 'package:freshfood_app/config/api_config.dart';
import 'package:freshfood_app/l10n/app_localizations.dart';
import 'package:freshfood_app/models/admin_low_stock_product.dart';
import 'package:freshfood_app/models/admin_recent_import.dart';
import 'package:freshfood_app/ui/formatters.dart';
import 'package:freshfood_app/state/auth_state.dart';

class AdminLowStockScreen extends StatefulWidget {
  const AdminLowStockScreen({super.key});

  @override
  State<AdminLowStockScreen> createState() => _AdminLowStockScreenState();
}

class _AdminLowStockScreenState extends State<AdminLowStockScreen> {
  final _api = ApiClient();
  bool _loading = true;
  bool _importsLoading = true;
  String? _err;
  List<AdminLowStockProduct> _items = const <AdminLowStockProduct>[];
  List<AdminRecentImport> _imports = const <AdminRecentImport>[];

  final Map<int, TextEditingController> _qtyCtls = <int, TextEditingController>{};
  final Map<int, TextEditingController> _noteCtls = <int, TextEditingController>{};
  final Map<int, bool> _importing = <int, bool>{};

  int _threshold = 10;
  TextEditingController? _thresholdCtl;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  @override
  void dispose() {
    _thresholdCtl?.dispose();
    for (final c in _qtyCtls.values) {
      c.dispose();
    }
    for (final c in _noteCtls.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadAll() async {
    final token = (AuthState.token.value ?? '').trim();
    if (token.isEmpty) {
      setState(() {
        _loading = false;
        _importsLoading = false;
        _err = 'Vui lòng đăng nhập tài khoản Admin.';
        _items = const <AdminLowStockProduct>[];
        _imports = const <AdminRecentImport>[];
      });
      return;
    }

    setState(() {
      _loading = true;
      _importsLoading = true;
      _err = null;
    });
    try {
      final results = await Future.wait<dynamic>([
        _api.getAdminLowStock(threshold: _threshold, take: 10),
        _api.getAdminRecentImports(take: 6),
      ]);
      if (!mounted) return;
      setState(() {
        _items = (results[0] as List<AdminLowStockProduct>);
        _imports = (results[1] as List<AdminRecentImport>);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _err = '$e'.replaceFirst('Exception: ', '').trim());
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _importsLoading = false;
        });
      }
    }
  }

  Future<void> _refreshLowStock() async {
    setState(() {
      _loading = true;
      _err = null;
    });
    try {
      final x = await _api.getAdminLowStock(threshold: _threshold, take: 10);
      if (!mounted) return;
      setState(() => _items = x);
    } catch (e) {
      if (!mounted) return;
      setState(() => _err = '$e'.replaceFirst('Exception: ', '').trim());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _refreshImports() async {
    setState(() => _importsLoading = true);
    try {
      final x = await _api.getAdminRecentImports(take: 6);
      if (!mounted) return;
      setState(() => _imports = x);
    } catch (_) {
      if (!mounted) return;
      setState(() => _imports = const <AdminRecentImport>[]);
    } finally {
      if (mounted) setState(() => _importsLoading = false);
    }
  }

  TextEditingController _qtyCtl(int productId) => _qtyCtls.putIfAbsent(productId, () => TextEditingController());
  TextEditingController _noteCtl(int productId) => _noteCtls.putIfAbsent(productId, () => TextEditingController());

  Future<void> _doImport(AdminLowStockProduct p) async {
    final pid = p.productId;
    final qty = int.tryParse(_qtyCtl(pid).text.trim()) ?? 0;
    if (qty <= 0) return;

    setState(() => _importing[pid] = true);
    try {
      await _api.adminImportStock(productId: pid, quantity: qty, note: _noteCtl(pid).text);
      _qtyCtl(pid).text = '';
      _noteCtl(pid).text = '';
      await _refreshLowStock();
      await _refreshImports();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã nhập kho.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'.replaceFirst('Exception: ', '').trim())));
    } finally {
      if (mounted) setState(() => _importing[pid] = false);
    }
  }

  String _stockBadgeText(int qty) => qty == 0 ? 'Hết hàng' : 'Còn $qty';
  String _stockHintText(int qty) {
    final veryLow = qty <= (0.3 * _threshold).floor().clamp(1, 999999);
    if (qty == 0) return 'Hết hàng';
    if (veryLow) return 'Rất thấp';
    return 'Sắp hết';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = AppLocalizations.of(context);
    _thresholdCtl ??= TextEditingController(text: '$_threshold');

    return Scaffold(
      appBar: AppBar(
        title: Text(t.tr(vi: 'Theo dõi tồn kho', en: 'Low stock')),
        actions: [
          IconButton(
            onPressed: (_loading || _importsLoading) ? null : _loadAll,
            tooltip: t.tr(vi: 'Tải lại', en: 'Refresh'),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadAll,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                color: theme.colorScheme.surface,
                boxShadow: [
                  BoxShadow(
                    color: theme.shadowColor.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
                border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(Icons.analytics_rounded, color: theme.colorScheme.primary, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Text('Cấu hình cảnh báo', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Sản phẩm sẽ hiện ở đây khi tồn kho ≤ ngưỡng bên dưới.',
                    style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Text('Ngưỡng:', style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w900)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            trackHeight: 4,
                            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                            overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
                          ),
                          child: Slider(
                            value: _threshold.toDouble(),
                            min: 0,
                            max: 200,
                            divisions: 200,
                            label: '$_threshold',
                            onChanged: (v) => setState(() {
                              _threshold = v.round();
                              _thresholdCtl?.text = '$_threshold';
                            }),
                            onChangeEnd: (_) => _refreshLowStock(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 60,
                        child: TextField(
                          key: ValueKey('threshold:$_threshold'),
                          controller: _thresholdCtl,
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w900),
                          onSubmitted: (x) {
                            final v = int.tryParse(x.trim()) ?? _threshold;
                            setState(() {
                              _threshold = v.clamp(0, 9999);
                              _thresholdCtl?.text = '$_threshold';
                            });
                            _refreshLowStock();
                          },
                          decoration: InputDecoration(
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(vertical: 8),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  ),
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
              Text(_err!, style: theme.textTheme.bodyMedium?.copyWith(color: const Color(0xFFB91C1C), fontWeight: FontWeight.w800))
            else if (_items.isEmpty)
              _Empty(
                icon: Icons.warning_amber_rounded,
                title: 'Không có sản phẩm sắp hết',
                subtitle: 'Tăng ngưỡng nếu bạn muốn xem rộng hơn.',
              )
            else
              ..._items.map((p) => _RowCard(
                    p: p,
                    threshold: _threshold,
                    qtyCtl: _qtyCtl(p.productId),
                    noteCtl: _noteCtl(p.productId),
                    importing: _importing[p.productId] == true,
                    onImport: () => _doImport(p),
                    badgeText: _stockBadgeText(p.stockQuantity),
                    hintText: _stockHintText(p.stockQuantity),
                  )),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                color: theme.colorScheme.surface,
                boxShadow: [
                  BoxShadow(
                    color: theme.shadowColor.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
                border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.secondary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(Icons.history_rounded, color: theme.colorScheme.secondary, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Text('Vừa nhập hàng', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (_importsLoading)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (_imports.isEmpty)
                    const _Empty(
                      icon: Icons.inventory_2_outlined,
                      title: 'Chưa có lần nhập nào',
                      subtitle: 'Dữ liệu sẽ hiện ở đây khi bạn thực hiện nhập hàng.',
                    )
                  else
                    ..._imports.map((x) => _ImportRow(x: x)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RowCard extends StatefulWidget {
  final AdminLowStockProduct p;
  final int threshold;
  final TextEditingController qtyCtl;
  final TextEditingController noteCtl;
  final bool importing;
  final VoidCallback onImport;
  final String badgeText;
  final String hintText;

  const _RowCard({
    required this.p,
    required this.threshold,
    required this.qtyCtl,
    required this.noteCtl,
    required this.importing,
    required this.onImport,
    required this.badgeText,
    required this.hintText,
  });

  @override
  State<_RowCard> createState() => _RowCardState();
}

class _RowCardState extends State<_RowCard> {
  void _updateQty(int delta) {
    final current = int.tryParse(widget.qtyCtl.text) ?? 0;
    final next = (current + delta).clamp(0, 9999);
    setState(() {
      widget.qtyCtl.text = next == 0 ? '' : '$next';
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final thumb = ApiConfig.resolveMediaUrl(widget.p.thumbUrl);
    final price = widget.p.discountPrice ?? widget.p.price;
    final unit = (widget.p.unit ?? '').trim();
    final veryLow = widget.p.stockQuantity <= (0.3 * widget.threshold).floor().clamp(1, 999999);
    
    // Màu sắc theo trạng thái
    final statusColor = widget.p.stockQuantity == 0 
        ? const Color(0xFFEF4444) // Đỏ: Hết hàng
        : (veryLow ? const Color(0xFFF97316) : const Color(0xFFF59E0B)); // Cam/Vàng: Sắp hết
    
    final canImport = (int.tryParse(widget.qtyCtl.text.trim()) ?? 0) > 0 && !widget.importing;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: theme.colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Column(
          children: [
            // Phần trên: Thông tin sản phẩm
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Hero(
                    tag: 'prod_${widget.p.productId}',
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        color: theme.colorScheme.surfaceContainerHighest,
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: thumb.isEmpty
                            ? Icon(Icons.image_not_supported_outlined, color: theme.colorScheme.onSurfaceVariant)
                            : Image.network(
                                thumb,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Icon(Icons.broken_image_outlined, color: theme.colorScheme.onSurfaceVariant),
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.p.productName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${Formatters.vnd(price)}${unit.isEmpty ? '' : ' / $unit'}',
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            color: statusColor.withValues(alpha: 0.1),
                          ),
                          child: Text(
                            '${widget.badgeText} • ${widget.hintText}',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: statusColor,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            // Phần dưới: Khu vực hành động (Nhập kho)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.15),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      // Bộ chọn số lượng dạng Pill hiện đại
                      Expanded(
                        flex: 4,
                        child: Container(
                          height: 48,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surface,
                            borderRadius: BorderRadius.circular(14),
                            // border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6)),
                          ),
                          child: Row(
                            children: [
                              _QtyBtn(icon: Icons.remove_rounded, onTap: () => _updateQty(-1)),
                              Expanded(
                                child: TextField(
                                  controller: widget.qtyCtl,
                                  keyboardType: TextInputType.number,
                                  textAlign: TextAlign.center,
                                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900, color: theme.colorScheme.primary),
                                  decoration: const InputDecoration(
                                    isDense: true,
                                    border: InputBorder.none,
                                    hintText: '0',
                                    contentPadding: EdgeInsets.zero,
                                  ),
                                  onChanged: (v) => setState(() {}),
                                ),
                              ),
                              _QtyBtn(icon: Icons.add_rounded, onTap: () => _updateQty(1)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Nút Nhập kho nổi bật
                      Expanded(
                        flex: 5,
                        child: SizedBox(
                          height: 48,
                          child: FilledButton(
                            onPressed: canImport ? widget.onImport : null,
                            style: FilledButton.styleFrom(
                              backgroundColor: canImport ? theme.colorScheme.primary : theme.colorScheme.surfaceContainerHighest,
                              foregroundColor: canImport ? theme.colorScheme.onPrimary : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              elevation: canImport ? 2 : 0,
                              padding: EdgeInsets.zero,
                            ),
                            child: widget.importing
                                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                                : Text(
                                    'Nhập kho',
                                    style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w900, letterSpacing: 0.5),
                                  ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Ô Ghi chú tối giản
                  TextField(
                    controller: widget.noteCtl,
                    style: theme.textTheme.bodyMedium,
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                      hintText: 'Thêm ghi chú nếu cần...',
                      hintStyle: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4)),
                      filled: true,
                      fillColor: theme.colorScheme.surface.withValues(alpha: 0.5),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: theme.colorScheme.primary.withValues(alpha: 0.5)),
                      ),
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

class _QtyBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _QtyBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(10),
        child: Icon(icon, size: 20, color: theme.colorScheme.primary),
      ),
    );
  }
}


class _ImportRow extends StatelessWidget {
  final AdminRecentImport x;
  const _ImportRow({required this.x});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final thumb = ApiConfig.resolveMediaUrl(x.thumbUrl);
    final unit = (x.unit ?? '').trim();
    final ts = x.logDate == null 
        ? '' 
        : '${x.logDate!.day.toString().padLeft(2, '0')}/${x.logDate!.month.toString().padLeft(2, '0')} ${x.logDate!.hour.toString().padLeft(2, '0')}:${x.logDate!.minute.toString().padLeft(2, '0')}';

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Ảnh nhỏ bo tròn
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: 44,
              height: 44,
              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              child: thumb.isEmpty
                  ? Icon(Icons.image_not_supported_outlined, color: theme.colorScheme.onSurfaceVariant, size: 18)
                  : Image.network(
                      thumb,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Icon(Icons.broken_image_outlined, color: theme.colorScheme.onSurfaceVariant, size: 18),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        x.productName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w900),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(ts, style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant, fontSize: 10)),
                  ],
                ),
                const SizedBox(height: 4),
                // Thông tin nhập hàng dạng chip nhỏ
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    _InfoChip(
                      label: '+${x.importedQuantity} ${unit.isEmpty ? '' : unit}',
                      color: theme.colorScheme.primary,
                    ),
                    _InfoChip(
                      label: 'Tồn: ${x.stockQuantity} ${unit.isEmpty ? '' : unit}',
                      color: theme.colorScheme.onSurfaceVariant,
                      isOutline: true,
                    ),
                  ],
                ),
                if ((x.note ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    '“${x.note!.trim()}”',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontStyle: FontStyle.italic,
                      color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
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

class _InfoChip extends StatelessWidget {
  final String label;
  final Color color;
  final bool isOutline;
  const _InfoChip({required this.label, required this.color, this.isOutline = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: isOutline ? Colors.transparent : color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: isOutline ? Border.all(color: color.withValues(alpha: 0.2)) : null,
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w900,
          fontSize: 10,
        ),
      ),
    );
  }
}


class _Empty extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const _Empty({required this.icon, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.2),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: theme.colorScheme.primary.withValues(alpha: 0.1),
            ),
            child: Icon(icon, color: theme.colorScheme.primary, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900)),
                const SizedBox(height: 2),
                Text(subtitle, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
