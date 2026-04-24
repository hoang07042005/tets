import 'package:flutter/material.dart';
import 'package:freshfood_app/l10n/app_localizations.dart';
import 'package:freshfood_app/screens/admin/products/admin_low_stock_screen.dart';
import 'package:freshfood_app/screens/admin/products/admin_product_list_screen.dart';
import 'package:freshfood_app/screens/admin/products/admin_suppliers_screen.dart';
import 'package:freshfood_app/screens/admin/products/admin_categories_screen.dart';
import 'package:freshfood_app/state/auth_state.dart';

class AdminProductsScreen extends StatelessWidget {
  const AdminProductsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = AppLocalizations.of(context);
    final user = AuthState.currentUser.value;
    final isAdmin = (user?.role ?? '').trim().toLowerCase() == 'admin';

    if (!isAdmin) {
      return Scaffold(
        appBar: AppBar(title: Text(t.tr(vi: 'Quản lý sản phẩm', en: 'Product management'))),
        body: Center(child: Text(t.tr(vi: 'Bạn không có quyền truy cập.', en: 'You do not have permission.'))),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(t.tr(vi: 'Quản lý sản phẩm', en: 'Product Management'), style: const TextStyle(fontWeight: FontWeight.w900)),
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t.tr(vi: 'Chào quản trị viên,', en: 'Hello Admin,'),
                    style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.w800, fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    t.tr(vi: 'Hôm nay bạn muốn quản lý gì?', en: 'What do you want to manage today?'),
                    style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900, color: const Color(0xFF1E293B)),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 0.85,
                children: [
                  _GridItem(
                    icon: Icons.inventory_2_rounded,
                    title: t.tr(vi: 'Tồn kho', en: 'Inventory'),
                    subtitle: t.tr(vi: 'Theo dõi sắp hết hàng', en: 'Track low stock'),
                    color: const Color(0xFF62BF39),
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AdminLowStockScreen())),
                  ),
                  _GridItem(
                    icon: Icons.view_list_rounded,
                    title: t.tr(vi: 'Sản phẩm', en: 'Products'),
                    subtitle: t.tr(vi: 'Danh sách & Chi tiết', en: 'List & Details'),
                    color: Colors.blueAccent,
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AdminProductListScreen())),
                  ),
                  _GridItem(
                    icon: Icons.local_shipping_rounded,
                    title: t.tr(vi: 'Nhà cung cấp', en: 'Suppliers'),
                    subtitle: t.tr(vi: 'Đối tác FreshFood', en: 'Partners'),
                    color: Colors.orange,
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AdminSuppliersScreen())),
                  ),
                  _GridItem(
                    icon: Icons.category_rounded,
                    title: t.tr(vi: 'Danh mục', en: 'Categories'),
                    subtitle: t.tr(vi: 'Phân loại sản phẩm', en: 'Product types'),
                    color: Colors.purple,
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AdminCategoriesScreen())),
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

class _GridItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _GridItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4)),
          ],
          border: Border.all(color: Colors.grey.shade100),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(16)),
              child: Icon(icon, color: color, size: 28),
            ),
            const Spacer(),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Color(0xFF1E293B))),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(color: Colors.grey.shade500, fontSize: 11, fontWeight: FontWeight.w600, height: 1.2),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
