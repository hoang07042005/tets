import 'dart:async';

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:freshfood_app/api/api_client.dart';
import 'package:freshfood_app/config/api_config.dart';
import 'package:freshfood_app/l10n/app_localizations.dart';
import 'package:freshfood_app/models/admin_supplier.dart';
import 'package:freshfood_app/state/auth_state.dart';
import 'package:image_picker/image_picker.dart';

class AdminSuppliersScreen extends StatefulWidget {
  const AdminSuppliersScreen({super.key});

  @override
  State<AdminSuppliersScreen> createState() => _AdminSuppliersScreenState();
}

class _AdminSuppliersScreenState extends State<AdminSuppliersScreen> {
  final _api = ApiClient();

  bool _loading = true;
  String? _err;
  AdminSuppliersPage? _page;

  String _tab = 'all'; // all | pending | paused
  int _pageNo = 1;
  final int _pageSize = 10;

  final _qCtl = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _qCtl.addListener(_onQChanged);
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _qCtl.removeListener(_onQChanged);
    _qCtl.dispose();
    super.dispose();
  }

  void _onQChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      _pageNo = 1;
      _load();
    });
  }

  bool get _isAdmin => (AuthState.currentUser.value?.role ?? '').trim().toLowerCase() == 'admin';

  Future<void> _load() async {
    final token = (AuthState.token.value ?? '').trim();
    if (token.isEmpty || !_isAdmin) {
      setState(() {
        _loading = false;
        _err = 'Vui lòng đăng nhập tài khoản Admin.';
        _page = null;
      });
      return;
    }

    setState(() {
      _loading = true;
      _err = null;
    });
    try {
      final p = await _api.getAdminSuppliersPage(
        page: _pageNo,
        pageSize: _pageSize,
        tab: _tab,
        q: _qCtl.text,
      );
      if (!mounted) return;
      setState(() => _page = p);
    } catch (e) {
      if (!mounted) return;
      setState(() => _err = '$e'.replaceFirst('Exception: ', '').trim());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openUpsert({AdminSupplierRow? existing}) async {
    final t = AppLocalizations.of(context);
    final res = await showModalBottomSheet<_UpsertResult?>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => _UpsertSheet(existing: existing),
    );
    if (!mounted) return;
    if (res == null) return;

    try {
      if (existing == null) {
        await _api.adminCreateSupplier(res.input);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.tr(vi: 'Đã tạo nhà cung cấp.', en: 'Supplier created.'))));
      } else {
        await _api.adminUpdateSupplier(supplierId: existing.supplierId, input: res.input);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.tr(vi: 'Đã cập nhật nhà cung cấp.', en: 'Supplier updated.'))));
      }
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'.replaceFirst('Exception: ', '').trim())));
    }
  }

  Future<void> _delete(AdminSupplierRow x) async {
    final t = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.tr(vi: 'Xóa nhà cung cấp?', en: 'Delete supplier?')),
        content: Text('${x.supplierName}\n\n${t.tr(vi: 'Thao tác này không thể hoàn tác.', en: 'This action cannot be undone.')}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(t.tr(vi: 'Hủy', en: 'Cancel'))),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(t.tr(vi: 'Xóa', en: 'Delete')),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _api.adminDeleteSupplier(x.supplierId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.tr(vi: 'Đã xóa.', en: 'Deleted.'))));
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'.replaceFirst('Exception: ', '').trim())));
    }
  }

  void _updateTab(String t) {
    if (_tab == t) return;
    setState(() {
      _tab = t;
      _pageNo = 1;
    });
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = AppLocalizations.of(context);
    final p = _page;

    return Scaffold(
      appBar: AppBar(
        title: Text(t.tr(vi: 'Nhà cung cấp', en: 'Suppliers')),
        actions: [
          IconButton(
            onPressed: _loading ? null : _load,
            tooltip: t.tr(vi: 'Tải lại', en: 'Refresh'),
            icon: const Icon(Icons.refresh_rounded),
          ),
          IconButton(
            onPressed: _loading ? null : () => _openUpsert(),
            tooltip: t.tr(vi: 'Thêm', en: 'Add'),
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
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
                      Expanded(
                        child: TextField(
                          controller: _qCtl,
                          style: theme.textTheme.bodyMedium,
                          decoration: InputDecoration(
                            isDense: true,
                            prefixIcon: const Icon(Icons.search_rounded, size: 20),
                            hintText: 'Tìm nhà cung cấp...',
                            hintStyle: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5)),
                            filled: true,
                            fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                            suffixIcon: _qCtl.text.trim().isEmpty
                                ? null
                                : IconButton(
                                    onPressed: () {
                                      _qCtl.text = '';
                                      _pageNo = 1;
                                      _load();
                                    },
                                    icon: const Icon(Icons.close_rounded, size: 18),
                                  ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _StatusTab(label: 'Tất cả', selected: _tab == 'all', count: p?.stats.total, onTap: () => _updateTab('all')),
                        const SizedBox(width: 8),
                        _StatusTab(label: 'Chờ duyệt', selected: _tab == 'pending', count: p?.stats.verified == null ? null : (p!.stats.total - p.stats.verified), onTap: () => _updateTab('pending')),
                        const SizedBox(width: 8),
                        _StatusTab(label: 'Tạm dừng', selected: _tab == 'paused', onTap: () => _updateTab('paused')),
                      ],
                    ),
                  ),
                  if (p != null) ...[
                    const SizedBox(height: 16),
                    const Divider(height: 1),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _StatItem(label: 'Đã duyệt', value: '${p.stats.verified}', icon: Icons.verified_user_rounded, color: const Color(0xFF10B981)),
                        _StatItem(label: 'Giao dịch', value: '${p.stats.inTransaction}', icon: Icons.swap_horiz_rounded, color: theme.colorScheme.primary),
                        _StatItem(label: 'Tháng này', value: '${p.stats.newThisMonth}', icon: Icons.calendar_month_rounded, color: const Color(0xFFF59E0B)),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (_loading)
              const Padding(padding: EdgeInsets.symmetric(vertical: 28), child: Center(child: CircularProgressIndicator()))
            else if (_err != null)
              Text(_err!, style: theme.textTheme.bodyMedium?.copyWith(color: const Color(0xFFB91C1C), fontWeight: FontWeight.w800))
            else if (p == null || p.items.isEmpty)
              _Empty(title: t.tr(vi: 'Không có nhà cung cấp.', en: 'No suppliers.'), subtitle: t.tr(vi: 'Thử đổi tab hoặc tìm kiếm.', en: 'Try changing tabs or search.'))
            else ...[
              for (final x in p.items)
                _SupplierCard(
                  x: x,
                  onEdit: () => _openUpsert(existing: x),
                  onDelete: () => _delete(x),
                ),
              const SizedBox(height: 8),
              _Pager(
                page: p.page,
                pageSize: p.pageSize,
                totalCount: p.totalCount,
                onPrev: p.page <= 1
                    ? null
                    : () {
                        setState(() => _pageNo = (_pageNo - 1).clamp(1, 9999));
                        _load();
                      },
                onNext: (p.page * p.pageSize) >= p.totalCount
                    ? null
                    : () {
                        setState(() => _pageNo = _pageNo + 1);
                        _load();
                      },
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SupplierCard extends StatelessWidget {
  final AdminSupplierRow x;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const _SupplierCard({required this.x, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = x.status.trim().toLowerCase();
    final isPending = status == 'pending';
    final isPaused = status == 'paused';
    
    final statusColor = isPending
        ? const Color(0xFFF59E0B)
        : isPaused
            ? const Color(0xFF94A3B8)
            : const Color(0xFF10B981);

    final imgUrl = ApiConfig.resolveMediaUrl(x.imageUrl);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: theme.colorScheme.surface,
        border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Ảnh / Logo thực tế
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    width: 52,
                    height: 52,
                    color: statusColor.withValues(alpha: 0.1),
                    child: imgUrl.isEmpty
                        ? Icon(Icons.business_rounded, color: statusColor, size: 28)
                        : Image.network(
                            imgUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Icon(Icons.broken_image_rounded, color: statusColor, size: 24),
                          ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              x.supplierName,
                              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (x.isVerified) ...[
                            const SizedBox(width: 6),
                            const Icon(Icons.verified_rounded, color: Color(0xFF10B981), size: 18),
                          ],
                        ],
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 12,
                        runSpacing: 6,
                        children: [
                          _ContactInfo(icon: Icons.phone_rounded, label: x.phone?.trim() ?? 'N/A'),
                          _ContactInfo(icon: Icons.email_rounded, label: x.email?.trim() ?? 'N/A'),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (x.address?.trim().isNotEmpty == true)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.location_on_rounded, size: 14, color: theme.colorScheme.onSurfaceVariant),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      x.address!.trim(),
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 16),
          // Khu vực hành động
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.2),
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
            ),
            child: Row(
              children: [
                _ActionBtn(
                  label: 'Sửa hồ sơ',
                  icon: Icons.edit_note_rounded,
                  color: theme.colorScheme.primary,
                  onTap: onEdit,
                ),
                const SizedBox(width: 12),
                _ActionBtn(
                  label: 'Xóa',
                  icon: Icons.delete_sweep_rounded,
                  color: const Color(0xFFEF4444),
                  onTap: onDelete,
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    status.toUpperCase(),
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: statusColor),
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

class _ContactInfo extends StatelessWidget {
  final IconData icon;
  final String label;
  const _ContactInfo({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6)),
        const SizedBox(width: 4),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _ActionBtn({required this.label, required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: color.withValues(alpha: 0.2)),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 6),
            Text(label, style: theme.textTheme.labelMedium?.copyWith(color: color, fontWeight: FontWeight.w900)),
          ],
        ),
      ),
    );
  }
}

class _StatusTab extends StatelessWidget {
  final String label;
  final bool selected;
  final int? count;
  final VoidCallback onTap;
  const _StatusTab({required this.label, required this.selected, this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? theme.colorScheme.primary : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: theme.textTheme.labelLarge?.copyWith(
                color: selected ? theme.colorScheme.onPrimary : theme.colorScheme.onSurfaceVariant,
                fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
              ),
            ),
            if (count != null) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: selected ? theme.colorScheme.onPrimary.withValues(alpha: 0.2) : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: selected ? theme.colorScheme.onPrimary : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _StatItem({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(height: 6),
        Text(value, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
        Text(label, style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant, fontSize: 10)),
      ],
    );
  }
}

class _Pager extends StatelessWidget {
  final int page;
  final int pageSize;
  final int totalCount;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;
  const _Pager({required this.page, required this.pageSize, required this.totalCount, required this.onPrev, required this.onNext});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final from = totalCount == 0 ? 0 : ((page - 1) * pageSize + 1);
    final to = (page * pageSize).clamp(0, totalCount);
    return Row(
      children: [
        Expanded(child: Text('$from-$to / $totalCount', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant, fontWeight: FontWeight.w800))),
        IconButton(onPressed: onPrev, icon: const Icon(Icons.chevron_left_rounded)),
        IconButton(onPressed: onNext, icon: const Icon(Icons.chevron_right_rounded)),
      ],
    );
  }
}

class _Empty extends StatelessWidget {
  final String title;
  final String subtitle;
  const _Empty({required this.title, required this.subtitle});

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
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: const Color(0xFF62BF39).withValues(alpha: 0.10),
            ),
            child: const Icon(Icons.storefront_outlined, color: Color(0xFF62BF39)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900)),
                const SizedBox(height: 2),
                Text(subtitle, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _UpsertResult {
  final AdminSupplierUpsert input;
  const _UpsertResult(this.input);
}

class _UpsertSheet extends StatefulWidget {
  final AdminSupplierRow? existing;
  const _UpsertSheet({required this.existing});

  @override
  State<_UpsertSheet> createState() => _UpsertSheetState();
}

class _UpsertSheetState extends State<_UpsertSheet> {
  final _api = ApiClient();
  final _picker = ImagePicker();
  bool _uploading = false;
  String? _localPath;
  late final TextEditingController _name;
  late final TextEditingController _code;
  late final TextEditingController _contact;
  late final TextEditingController _phone;
  late final TextEditingController _email;
  late final TextEditingController _address;
  late final TextEditingController _imageUrl; // stores uploaded url path
  String _status = 'Pending';
  bool _verified = false;

  @override
  void initState() {
    super.initState();
    final x = widget.existing;
    _name = TextEditingController(text: x?.supplierName ?? '');
    _code = TextEditingController(text: x?.supplierCode ?? '');
    _contact = TextEditingController(text: x?.contactName ?? '');
    _phone = TextEditingController(text: x?.phone ?? '');
    _email = TextEditingController(text: x?.email ?? '');
    _address = TextEditingController(text: x?.address ?? '');
    _imageUrl = TextEditingController(text: x?.imageUrl ?? '');
    _status = (x?.status ?? 'Pending').trim().isEmpty ? 'Pending' : (x?.status ?? 'Pending').trim();
    _verified = x?.isVerified ?? false;
  }

  @override
  void dispose() {
    _name.dispose();
    _code.dispose();
    _contact.dispose();
    _phone.dispose();
    _email.dispose();
    _address.dispose();
    _imageUrl.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadImage() async {
    if (_uploading) return;
    try {
      final picked = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 88);
      if (picked == null) return;
      
      setState(() {
        _localPath = picked.path;
        _uploading = true;
      });

      final url = await _api.adminUploadSupplierImage(picked.path);
      if (!mounted) return;
      setState(() {
        _imageUrl.text = url;
        _uploading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _uploading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'.replaceFirst('Exception: ', '').trim())));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = AppLocalizations.of(context);
    final isEdit = widget.existing != null;
    final previewUrl = ApiConfig.resolveMediaUrl(_imageUrl.text);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(isEdit ? Icons.edit_note_rounded : Icons.add_business_rounded, color: theme.colorScheme.primary),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isEdit ? 'Sửa nhà cung cấp' : 'Thêm nhà cung cấp mới',
                          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                        ),
                        Text(
                          isEdit ? 'Cập nhật thông tin đối tác của bạn' : 'Mở rộng mạng lưới cung ứng của FreshFood',
                          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              
              // Khu vực chọn ảnh nổi bật
              Center(
                child: Stack(
                  children: [
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.2), width: 2),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(26),
                        child: _localPath != null
                            ? Image.file(File(_localPath!), fit: BoxFit.cover)
                            : previewUrl.isEmpty
                                ? Icon(Icons.business_rounded, size: 40, color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5))
                                : Image.network(
                                    previewUrl,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Icon(Icons.broken_image_rounded, size: 30, color: theme.colorScheme.error),
                                  ),
                      ),
                    ),
                    if (_uploading)
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(28),
                          ),
                          child: const Center(
                            child: SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            ),
                          ),
                        ),
                      ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: GestureDetector(
                        onTap: _uploading ? null : _pickAndUploadImage,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary,
                            shape: BoxShape.circle,
                            border: Border.all(color: theme.colorScheme.surface, width: 3),
                            boxShadow: [
                              BoxShadow(color: theme.colorScheme.shadow.withValues(alpha: 0.2), blurRadius: 8, offset: const Offset(0, 2)),
                            ],
                          ),
                          child: Icon(
                            Icons.camera_alt_rounded,
                            size: 16,
                            color: theme.colorScheme.onPrimary,
                          ),
                        ),
                      ),
                    ),
                    if ((previewUrl.isNotEmpty || _localPath != null) && !_uploading)
                      Positioned(
                        top: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: () => setState(() {
                            _imageUrl.text = '';
                            _localPath = null;
                          }),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.errorContainer,
                              shape: BoxShape.circle,
                              border: Border.all(color: theme.colorScheme.surface, width: 2),
                            ),
                            child: Icon(Icons.close_rounded, size: 12, color: theme.colorScheme.onErrorContainer),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  _uploading ? 'Đang tải lên...' : 'Logo nhà cung cấp',
                  style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant, fontWeight: FontWeight.w800),
                ),
              ),

              const SizedBox(height: 24),
              
              _FormGroup(
                title: 'Thông tin chung',
                children: [
                  _Input(controller: _name, label: 'Tên nhà cung cấp *', icon: Icons.business_rounded),
                ],
              ),
              
              const SizedBox(height: 20),
              _FormGroup(
                title: 'Liên hệ',
                children: [
                  _Input(controller: _contact, label: 'Người đại diện', icon: Icons.person_outline_rounded),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _Input(controller: _phone, label: 'Số điện thoại', icon: Icons.phone_android_rounded, keyboardType: TextInputType.phone)),
                      const SizedBox(width: 12),
                      Expanded(child: _Input(controller: _email, label: 'Email', icon: Icons.alternate_email_rounded, keyboardType: TextInputType.emailAddress)),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 20),
              _FormGroup(
                title: 'Địa chỉ',
                children: [
                  _Input(controller: _address, label: 'Địa chỉ chi tiết', icon: Icons.map_rounded, maxLines: 2),
                ],
              ),

              const SizedBox(height: 20),
              _FormGroup(
                title: 'Trạng thái & Xác minh',
                children: [
                  DropdownButtonFormField<String>(
                    value: _status,
                    decoration: _inputDeco(label: 'Trạng thái hoạt động', icon: Icons.info_outline_rounded, theme: theme),
                    items: const [
                      DropdownMenuItem(value: 'Pending', child: Text('Đang chờ (Pending)')),
                      DropdownMenuItem(value: 'Active', child: Text('Đang hoạt động (Active)')),
                      DropdownMenuItem(value: 'Paused', child: Text('Tạm dừng (Paused)')),
                    ],
                    onChanged: (v) => setState(() => _status = (v ?? 'Pending')),
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    value: _verified,
                    onChanged: (v) => setState(() => _verified = v),
                    title: Text('Đối tác đã xác minh', style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
                    subtitle: const Text('Hiện badge Verified trên hồ sơ', style: TextStyle(fontSize: 11)),
                    secondary: Icon(Icons.verified_user_rounded, color: _verified ? const Color(0xFF10B981) : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.3)),
                    contentPadding: EdgeInsets.zero,
                    activeColor: const Color(0xFF10B981),
                  ),
                ],
              ),

              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: FilledButton(
                  onPressed: () {
                    final name = _name.text.trim();
                    if (name.isEmpty) return;
                    final input = AdminSupplierUpsert(
                      supplierName: name,
                      supplierCode: _code.text.trim(),
                      contactName: _contact.text.trim(),
                      phone: _phone.text.trim(),
                      email: _email.text.trim(),
                      address: _address.text.trim(),
                      imageUrl: _imageUrl.text.trim(),
                      status: _status,
                      isVerified: _verified,
                    );
                    Navigator.of(context).pop(_UpsertResult(input));
                  },
                  style: FilledButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                  child: Text(isEdit ? 'Cập nhật hồ sơ' : 'Tạo nhà cung cấp', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Hủy bỏ', style: TextStyle(color: Colors.grey))),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDeco({required String label, required IconData icon, required ThemeData theme}) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, size: 20),
      labelStyle: const TextStyle(fontSize: 13),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: theme.colorScheme.outlineVariant)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: theme.colorScheme.primary, width: 2)),
    );
  }
}

class _FormGroup extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _FormGroup({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(title.toUpperCase(), style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.w900, letterSpacing: 1)),
        ),
        ...children,
      ],
    );
  }
}

class _Input extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final int maxLines;
  final TextInputType? keyboardType;
  const _Input({required this.controller, required this.label, required this.icon, this.maxLines = 1, this.keyboardType});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      style: theme.textTheme.bodyMedium,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20),
        labelStyle: const TextStyle(fontSize: 13),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: theme.colorScheme.outlineVariant)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: theme.colorScheme.primary, width: 2)),
      ),
    );
  }
}

