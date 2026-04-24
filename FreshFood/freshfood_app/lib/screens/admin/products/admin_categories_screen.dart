import 'package:flutter/material.dart';
import 'package:freshfood_app/api/api_client.dart';
import 'package:freshfood_app/l10n/app_localizations.dart';
import 'package:freshfood_app/models/category.dart';
import 'package:freshfood_app/state/auth_state.dart';

class AdminCategoriesScreen extends StatefulWidget {
  const AdminCategoriesScreen({super.key});

  @override
  State<AdminCategoriesScreen> createState() => _AdminCategoriesScreenState();
}

class _AdminCategoriesScreenState extends State<AdminCategoriesScreen> {
  final _api = ApiClient();
  bool _loading = true;
  String? _err;
  List<Category> _items = const <Category>[];

  bool get _isAdmin => (AuthState.currentUser.value?.role ?? '').trim().toLowerCase() == 'admin';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final token = (AuthState.token.value ?? '').trim();
    if (token.isEmpty || !_isAdmin) {
      setState(() {
        _loading = false;
        _err = 'Vui lòng đăng nhập tài khoản Admin.';
        _items = const <Category>[];
      });
      return;
    }
    setState(() {
      _loading = true;
      _err = null;
    });
    try {
      final x = await _api.getAdminCategories();
      if (!mounted) return;
      setState(() => _items = x);
    } catch (e) {
      if (!mounted) return;
      setState(() => _err = '$e'.replaceFirst('Exception: ', '').trim());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openUpsert({Category? existing}) async {
    final t = AppLocalizations.of(context);
    final res = await showModalBottomSheet<_CatUpsertResult?>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _CatUpsertSheet(existing: existing),
    );
    if (res == null) return;
    try {
      if (existing == null) {
        await _api.adminCreateCategory(categoryName: res.name, description: res.description);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.tr(vi: 'Đã tạo danh mục.', en: 'Category created.'))));
      } else {
        await _api.adminUpdateCategory(categoryId: existing.id, categoryName: res.name, description: res.description);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.tr(vi: 'Đã cập nhật danh mục.', en: 'Category updated.'))));
      }
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'.replaceFirst('Exception: ', '').trim())));
    }
  }

  Future<void> _delete(Category x) async {
    final t = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.tr(vi: 'Xóa danh mục?', en: 'Delete category?')),
        content: Text('${x.name}\n\n${t.tr(vi: 'Thao tác này không thể hoàn tác.', en: 'This action cannot be undone.')}'),
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
      await _api.adminDeleteCategory(x.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.tr(vi: 'Đã xóa.', en: 'Deleted.'))));
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'.replaceFirst('Exception: ', '').trim())));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(t.tr(vi: 'Danh mục', en: 'Categories')),
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
            if (_loading)
              const Padding(padding: EdgeInsets.symmetric(vertical: 28), child: Center(child: CircularProgressIndicator()))
            else if (_err != null)
              Text(_err!, style: theme.textTheme.bodyMedium?.copyWith(color: const Color(0xFFB91C1C), fontWeight: FontWeight.w800))
            else if (_items.isEmpty)
              _Empty(
                title: t.tr(vi: 'Chưa có danh mục.', en: 'No categories.'),
                subtitle: t.tr(vi: 'Bấm nút + để thêm.', en: 'Tap + to add.'),
              )
            else
              ..._items.map((c) => _CatCard(
                    c: c,
                    onEdit: () => _openUpsert(existing: c),
                    onDelete: () => _delete(c),
                  )),
          ],
        ),
      ),
    );
  }
}

class _CatCard extends StatelessWidget {
  final Category c;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const _CatCard({required this.c, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon danh mục trang trí
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.folder_open_rounded, color: theme.colorScheme.primary, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        c.name,
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (c.description.trim().isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          c.description.trim(),
                          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant, height: 1.3),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Khu vực hành động
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.2),
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
              border: Border(top: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3))),
            ),
            child: Row(
              children: [
                _ActionBtn(
                  label: 'Sửa',
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
                const Icon(Icons.chevron_right_rounded, size: 18, color: Colors.grey),
              ],
            ),
          ),
        ],
      ),
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
            child: const Icon(Icons.category_outlined, color: Color(0xFF62BF39)),
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

class _CatUpsertResult {
  final String name;
  final String description;
  const _CatUpsertResult({required this.name, required this.description});
}

class _CatUpsertSheet extends StatefulWidget {
  final Category? existing;
  const _CatUpsertSheet({required this.existing});

  @override
  State<_CatUpsertSheet> createState() => _CatUpsertSheetState();
}

class _CatUpsertSheetState extends State<_CatUpsertSheet> {
  late final TextEditingController _name;
  late final TextEditingController _desc;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.existing?.name ?? '');
    _desc = TextEditingController(text: widget.existing?.description ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _desc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEdit = widget.existing != null;
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
                    child: Icon(isEdit ? Icons.edit_note_rounded : Icons.create_new_folder_rounded, color: theme.colorScheme.primary),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isEdit ? 'Sửa danh mục' : 'Thêm danh mục mới',
                          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                        ),
                        Text(
                          isEdit ? 'Cập nhật phân loại hàng hóa của bạn' : 'Phân loại hàng hóa để khách hàng dễ tìm kiếm',
                          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              
              _Input(controller: _name, label: 'Tên danh mục *', icon: Icons.category_rounded),
              const SizedBox(height: 16),
              _Input(controller: _desc, label: 'Mô tả ngắn', icon: Icons.description_rounded, maxLines: 4),

              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: FilledButton(
                  onPressed: () {
                    final name = _name.text.trim();
                    if (name.isEmpty) return;
                    Navigator.of(context).pop(_CatUpsertResult(name: name, description: _desc.text.trim()));
                  },
                  style: FilledButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                  child: Text(isEdit ? 'Cập nhật danh mục' : 'Tạo danh mục', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
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
}

class _Input extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final int maxLines;
  const _Input({required this.controller, required this.label, required this.icon, this.maxLines = 1});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return TextField(
      controller: controller,
      maxLines: maxLines,
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

