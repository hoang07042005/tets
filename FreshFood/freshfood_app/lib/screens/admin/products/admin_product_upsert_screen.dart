import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'package:freshfood_app/api/api_client.dart';
import 'package:freshfood_app/config/api_config.dart';
import 'package:freshfood_app/l10n/app_localizations.dart';
import 'package:freshfood_app/models/admin_product_detail.dart';
import 'package:freshfood_app/models/admin_supplier.dart';
import 'package:freshfood_app/models/category.dart';

class AdminProductUpsertScreen extends StatefulWidget {
  final int? productId;
  final String? productToken;
  final String? seedProductName;

  const AdminProductUpsertScreen.create({super.key, this.seedProductName})
      : productId = null,
        productToken = null;

  const AdminProductUpsertScreen.edit({super.key, required this.productId, this.productToken, this.seedProductName});

  bool get isEdit => (productId != null && productId! > 0) || ((productToken ?? '').trim().isNotEmpty);

  @override
  State<AdminProductUpsertScreen> createState() => _AdminProductUpsertScreenState();
}

class _AdminProductUpsertScreenState extends State<AdminProductUpsertScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameCtl = TextEditingController();
  final _skuCtl = TextEditingController();
  final _priceCtl = TextEditingController();
  final _discountCtl = TextEditingController();
  final _stockCtl = TextEditingController();
  final _unitCtl = TextEditingController(text: 'kg');
  final _descCtl = TextEditingController();
  final _originCtl = TextEditingController();
  final _storageCtl = TextEditingController();
  final _certCtl = TextEditingController();
  final _mfgCtl = TextEditingController();
  final _expCtl = TextEditingController();

  int? _categoryId;
  int? _supplierId;
  String _status = 'Active';

  bool _loading = true;
  bool _saving = false;
  String? _err;

  List<Category> _categories = const [];
  List<AdminSupplierRow> _suppliers = const [];
  AdminProductDetail? _detail;

  List<AdminProductImage> _existingImages = const [];
  List<XFile> _newFiles = const [];
  int _newMainIndex = 0;

  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _nameCtl.text = (widget.seedProductName ?? '').trim();
    _load();
  }

  @override
  void dispose() {
    _nameCtl.dispose();
    _skuCtl.dispose();
    _priceCtl.dispose();
    _discountCtl.dispose();
    _stockCtl.dispose();
    _unitCtl.dispose();
    _descCtl.dispose();
    _originCtl.dispose();
    _storageCtl.dispose();
    _certCtl.dispose();
    _mfgCtl.dispose();
    _expCtl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _err = null;
    });
    try {
      final api = ApiClient.instance;
      final futures = <Future<dynamic>>[
        api.getAdminCategories(),
        api.getAdminSuppliersPage(page: 1, pageSize: 200, tab: 'all'),
      ];
      if (widget.isEdit) {
        futures.add(
          widget.productId != null
              ? api.getAdminProduct(widget.productId!)
              : api.getAdminProductByToken(widget.productToken ?? ''),
        );
      }

      final res = await Future.wait(futures);
      final cats = (res[0] as List<Category>?) ?? const <Category>[];
      final supPage = res[1] as AdminSuppliersPage?;
      final sups = supPage?.items ?? const <AdminSupplierRow>[];

      AdminProductDetail? d;
      if (widget.isEdit) {
        d = res.length >= 3 ? (res[2] as AdminProductDetail?) : null;
      }

      if (!mounted) return;
      setState(() {
        _categories = cats;
        _suppliers = sups;
      });

      if (widget.isEdit) {
        if (d == null) throw Exception('Không tải được dữ liệu sản phẩm.');
        _applyDetail(d);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _err = 'Không tải được dữ liệu. Vui lòng thử lại.';
      });
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _applyDetail(AdminProductDetail d) {
    setState(() {
      _detail = d;
      _nameCtl.text = d.productName;
      _skuCtl.text = d.sku;
      _categoryId = d.categoryId;
      _supplierId = d.supplierId;
      _status = (d.status.trim().toLowerCase() == 'inactive') ? 'Inactive' : 'Active';
      _priceCtl.text = '${d.price}';
      _discountCtl.text = d.discountPrice == null ? '' : '${d.discountPrice}';
      _stockCtl.text = '${d.stockQuantity}';
      _unitCtl.text = d.unit;
      _descCtl.text = d.description;
      _originCtl.text = d.origin;
      _storageCtl.text = d.storageInstructions;
      _certCtl.text = d.certifications;
      _mfgCtl.text = _toYmd(d.manufacturedDate);
      _expCtl.text = _toYmd(d.expiryDate);
      _existingImages = d.images;
    });
  }

  String _toYmd(DateTime? d) {
    if (d == null) return '';
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '$y-$m-$dd';
  }

  num? _parseMoney(String s) {
    final raw = s.trim();
    if (raw.isEmpty) return null;
    final normalized = raw.replaceAll('.', '').replaceAll(',', '.');
    return num.tryParse(normalized);
  }

  int? _parseInt(String s) {
    final raw = s.trim();
    if (raw.isEmpty) return null;
    return int.tryParse(raw);
  }

  Future<void> _pickDate({required TextEditingController target, DateTime? initial}) async {
    final now = DateTime.now();
    final init = initial ?? DateTime(now.year, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: init,
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year + 20),
    );
    if (picked == null) return;
    target.text = _toYmd(picked);
  }

  Future<void> _pickImages() async {
    try {
      final picked = await _picker.pickMultiImage(imageQuality: 85);
      if (picked.isEmpty) return;
      if (!mounted) return;
      setState(() {
        final next = [..._newFiles, ...picked].take(10).toList();
        _newFiles = next;
        if (_newMainIndex >= next.length) _newMainIndex = 0;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _err = 'Không chọn được ảnh. Vui lòng thử lại.');
    }
  }

  Future<void> _setMainExisting(int imageId) async {
    final productId = _detail?.productId ?? widget.productId;
    if (productId == null || productId <= 0) return;
    setState(() => _err = null);
    try {
      await ApiClient.instance.adminSetMainProductImage(productId: productId, imageId: imageId);
      if (!mounted) return;
      setState(() {
        _existingImages = _existingImages.map((x) => AdminProductImage(imageId: x.imageId, imageUrl: x.imageUrl, isMainImage: x.imageId == imageId)).toList();
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _err = 'Không đặt được ảnh chính.');
    }
  }

  Future<void> _deleteExisting(int imageId) async {
    final productId = _detail?.productId ?? widget.productId;
    if (productId == null || productId <= 0) return;
    setState(() => _err = null);
    try {
      await ApiClient.instance.adminDeleteProductImage(productId: productId, imageId: imageId);
      if (!mounted) return;
      setState(() {
        _existingImages = _existingImages.where((x) => x.imageId != imageId).toList();
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _err = 'Không xóa được ảnh.');
    }
  }

  Future<void> _save() async {
    final t = AppLocalizations.of(context);
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final name = _nameCtl.text.trim();
    final price = _parseMoney(_priceCtl.text);
    final stock = _parseInt(_stockCtl.text);
    if (price == null || price < 0) {
      setState(() => _err = t.tr(vi: 'Giá không hợp lệ.', en: 'Invalid price.'));
      return;
    }
    if (stock == null || stock < 0) {
      setState(() => _err = t.tr(vi: 'Tồn kho không hợp lệ.', en: 'Invalid stock.'));
      return;
    }

    num? discount;
    if (_discountCtl.text.trim().isNotEmpty) {
      final d = _parseMoney(_discountCtl.text);
      if (d != null && d >= 0) discount = d;
    }

    setState(() {
      _saving = true;
      _err = null;
    });

    try {
      final api = ApiClient.instance;
      AdminProductDetail saved;

      final payload = {
        'productName': name,
        'categoryId': _categoryId,
        'supplierId': _supplierId,
        'status': _status,
        'price': price,
        'discountPrice': discount,
        'stockQuantity': stock,
        'unit': _unitCtl.text.trim().isEmpty ? 'kg' : _unitCtl.text.trim(),
        'description': _descCtl.text.trim(),
        'manufacturedDate': _mfgCtl.text.trim(),
        'expiryDate': _expCtl.text.trim(),
        'origin': _originCtl.text.trim(),
        'storageInstructions': _storageCtl.text.trim(),
        'certifications': _certCtl.text.trim(),
      };

      if (widget.isEdit) {
        final pid = _detail?.productId ?? widget.productId;
        if (pid == null || pid <= 0) throw Exception('Missing product id');
        saved = await api.adminUpdateProduct(
          pid,
          productName: payload['productName'] as String,
          categoryId: payload['categoryId'] as int?,
          supplierId: payload['supplierId'] as int?,
          status: payload['status'] as String,
          price: payload['price'] as num,
          discountPrice: payload['discountPrice'] as num?,
          stockQuantity: payload['stockQuantity'] as int,
          unit: payload['unit'] as String,
          description: payload['description'] as String,
          manufacturedDate: (payload['manufacturedDate'] as String).trim().isEmpty ? null : payload['manufacturedDate'] as String,
          expiryDate: (payload['expiryDate'] as String).trim().isEmpty ? null : payload['expiryDate'] as String,
          origin: payload['origin'] as String,
          storageInstructions: payload['storageInstructions'] as String,
          certifications: payload['certifications'] as String,
        );
      } else {
        saved = await api.adminCreateProduct(
          productName: payload['productName'] as String,
          categoryId: payload['categoryId'] as int?,
          supplierId: payload['supplierId'] as int?,
          status: payload['status'] as String,
          price: payload['price'] as num,
          discountPrice: payload['discountPrice'] as num?,
          stockQuantity: payload['stockQuantity'] as int,
          unit: payload['unit'] as String,
          description: payload['description'] as String,
          manufacturedDate: (payload['manufacturedDate'] as String).trim().isEmpty ? null : payload['manufacturedDate'] as String,
          expiryDate: (payload['expiryDate'] as String).trim().isEmpty ? null : payload['expiryDate'] as String,
          origin: payload['origin'] as String,
          storageInstructions: payload['storageInstructions'] as String,
          certifications: payload['certifications'] as String,
        );
      }

      if (!mounted) return;
      _applyDetail(saved);

      if (_newFiles.isNotEmpty) {
        final pid = saved.productId;
        await api.adminUploadProductImages(
          productId: pid,
          filePaths: _newFiles.map((x) => x.path).toList(),
          mainIndex: _newMainIndex,
        );
        final refreshed = await api.getAdminProduct(pid);
        if (refreshed != null && mounted) {
          _applyDetail(refreshed);
        }
        if (mounted) {
          setState(() {
            _newFiles = const [];
            _newMainIndex = 0;
          });
        }
      }

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        final msg = '$e'.replaceFirst('Exception: ', '').trim();
        if (msg.isNotEmpty && msg.length < 220) {
          _err = msg;
        } else {
          _err = widget.isEdit
              ? t.tr(vi: 'Không cập nhật được sản phẩm. Kiểm tra dữ liệu và thử lại.', en: 'Failed to update product. Please try again.')
              : t.tr(vi: 'Không tạo được sản phẩm. Kiểm tra dữ liệu và thử lại.', en: 'Failed to create product. Please try again.');
        }
      });
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final isEdit = widget.isEdit;
    final title = isEdit ? t.tr(vi: 'Sửa sản phẩm', en: 'Edit product') : t.tr(vi: 'Thêm sản phẩm', en: 'Add product');

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                  if (_err != null && _err!.trim().isNotEmpty)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: cs.errorContainer,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: cs.error.withValues(alpha: 0.25)),
                      ),
                      child: Text(_err!, style: TextStyle(color: cs.onErrorContainer, fontWeight: FontWeight.w800)),
                    ),
                  if (_err != null) const SizedBox(height: 12),

                  _Card(
                    title: t.tr(vi: 'Thông tin cơ bản', en: 'Basic info'),
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _nameCtl,
                          decoration: InputDecoration(labelText: t.tr(vi: 'Tên sản phẩm', en: 'Product name')),
                          textInputAction: TextInputAction.next,
                          validator: (v) => (v ?? '').trim().isEmpty ? t.tr(vi: 'Bắt buộc.', en: 'Required.') : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _skuCtl,
                          decoration: InputDecoration(
                            labelText: t.tr(vi: 'Mã SKU', en: 'SKU'),
                            hintText: isEdit ? 'FF-PRD-...' : t.tr(vi: 'Tự sinh sau khi lưu', en: 'Auto generated after save'),
                          ),
                          enabled: false,
                          readOnly: true,
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          value: _status,
                          items: [
                            DropdownMenuItem(value: 'Active', child: Text(t.tr(vi: 'Đang bán', en: 'Active'))),
                            DropdownMenuItem(value: 'Inactive', child: Text(t.tr(vi: 'Tạm ẩn', en: 'Inactive'))),
                          ],
                          onChanged: _saving ? null : (v) => setState(() => _status = (v ?? 'Active')),
                          decoration: InputDecoration(labelText: t.tr(vi: 'Trạng thái', en: 'Status')),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<int?>(
                          value: _categoryId,
                          items: [
                            DropdownMenuItem<int?>(value: null, child: Text(t.tr(vi: '— Chọn danh mục —', en: '— Select category —'))),
                            ..._categories.map(
                              (c) => DropdownMenuItem<int?>(
                                value: c.id,
                                child: Text(c.name, overflow: TextOverflow.ellipsis),
                              ),
                            ),
                          ],
                          onChanged: _saving ? null : (v) => setState(() => _categoryId = v),
                          isExpanded: true,
                          decoration: InputDecoration(labelText: t.tr(vi: 'Danh mục', en: 'Category')),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<int?>(
                          value: _supplierId,
                          items: [
                            DropdownMenuItem<int?>(value: null, child: Text(t.tr(vi: '— Chọn nhà cung cấp —', en: '— Select supplier —'))),
                            ..._suppliers.map(
                              (s) => DropdownMenuItem<int?>(
                                value: s.supplierId,
                                child: Text(s.supplierName, overflow: TextOverflow.ellipsis),
                              ),
                            ),
                          ],
                          onChanged: _saving ? null : (v) => setState(() => _supplierId = v),
                          isExpanded: true,
                          decoration: InputDecoration(labelText: t.tr(vi: 'Nhà cung cấp', en: 'Supplier')),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),
                  _Card(
                    title: t.tr(vi: 'Giá & tồn kho', en: 'Price & stock'),
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _priceCtl,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(labelText: t.tr(vi: 'Giá (VND)', en: 'Price (VND)')),
                          validator: (v) => (_parseMoney(v ?? '') == null) ? t.tr(vi: 'Giá không hợp lệ.', en: 'Invalid price.') : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _discountCtl,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: t.tr(vi: 'Giá giảm (tuỳ chọn)', en: 'Discount price (optional)'),
                            helperText: t.tr(vi: 'Bỏ trống nếu không giảm giá.', en: 'Leave empty if no discount.'),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _stockCtl,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(labelText: t.tr(vi: 'Tồn kho', en: 'Stock quantity')),
                          validator: (v) => (_parseInt(v ?? '') == null) ? t.tr(vi: 'Tồn kho không hợp lệ.', en: 'Invalid stock.') : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _unitCtl,
                          decoration: InputDecoration(labelText: t.tr(vi: 'Đơn vị (kg, hộp...)', en: 'Unit (kg, box...)')),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),
                  _Card(
                    title: t.tr(vi: 'Mô tả', en: 'Description'),
                    child: TextFormField(
                      controller: _descCtl,
                      maxLines: 6,
                      decoration: InputDecoration(
                        labelText: t.tr(vi: 'Mô tả sản phẩm', en: 'Product description'),
                        alignLabelWithHint: true,
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),
                  _Card(
                    title: t.tr(vi: 'Thông tin tươi', en: 'Fresh info'),
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _mfgCtl,
                          readOnly: true,
                          onTap: _saving ? null : () => _pickDate(target: _mfgCtl, initial: _detail?.manufacturedDate),
                          decoration: InputDecoration(
                            labelText: t.tr(vi: 'Ngày sản xuất', en: 'Manufactured date'),
                            suffixIcon: const Icon(Icons.calendar_today_outlined),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _expCtl,
                          readOnly: true,
                          onTap: _saving ? null : () => _pickDate(target: _expCtl, initial: _detail?.expiryDate),
                          decoration: InputDecoration(
                            labelText: t.tr(vi: 'Hạn sử dụng', en: 'Expiry date'),
                            suffixIcon: const Icon(Icons.calendar_today_outlined),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _originCtl,
                          decoration: InputDecoration(labelText: t.tr(vi: 'Xuất xứ', en: 'Origin')),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _storageCtl,
                          maxLines: 3,
                          decoration: InputDecoration(
                            labelText: t.tr(vi: 'Hướng dẫn bảo quản', en: 'Storage instructions'),
                            alignLabelWithHint: true,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _certCtl,
                          decoration: InputDecoration(labelText: t.tr(vi: 'Chứng nhận', en: 'Certifications')),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),
                  _Card(
                    title: t.tr(vi: 'Hình ảnh', en: 'Images'),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (_existingImages.isNotEmpty) ...[
                          Text(t.tr(vi: 'Ảnh hiện tại', en: 'Existing images'), style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900)),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: _existingImages.map((img) {
                              final isMain = img.isMainImage;
                              final url = ApiConfig.resolveMediaUrl(img.imageUrl);
                              return _ImageTile(
                                imageUrl: url,
                                isMain: isMain,
                                onMain: _saving ? null : () => _setMainExisting(img.imageId),
                                onDelete: _saving ? null : () => _deleteExisting(img.imageId),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 12),
                        ],

                        Text(t.tr(vi: 'Ảnh mới (tối đa 10)', en: 'New images (max 10)'),
                            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900)),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: (_saving) ? null : _pickImages,
                          icon: const Icon(Icons.image_outlined),
                          label: Text(t.tr(vi: 'Chọn ảnh', en: 'Pick images')),
                        ),
                        if (_newFiles.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Text(t.tr(vi: 'Chọn ảnh chính cho lần upload', en: 'Choose main image for upload'),
                              style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: List.generate(_newFiles.length, (i) {
                              final f = _newFiles[i];
                              return _LocalImageTile(
                                file: f,
                                isMain: i == _newMainIndex,
                                onMain: _saving ? null : () => setState(() => _newMainIndex = i),
                                onDelete: _saving
                                    ? null
                                    : () {
                                        setState(() {
                                          final next = [..._newFiles]..removeAt(i);
                                          _newFiles = next;
                                          if (_newMainIndex == i) _newMainIndex = 0;
                                          if (_newMainIndex > i) _newMainIndex -= 1;
                                        });
                                      },
                              );
                            }),
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),
                  FilledButton.icon(
                    onPressed: (_saving) ? null : _save,
                    icon: _saving
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.save_outlined),
                    label: Text(isEdit ? t.tr(vi: 'Cập nhật sản phẩm', en: 'Update product') : t.tr(vi: 'Tạo sản phẩm', en: 'Create product')),
                  ),
                  const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
    );
  }
}

class _Card extends StatelessWidget {
  final String title;
  final Widget child;
  const _Card({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _ImageTile extends StatelessWidget {
  final String imageUrl;
  final bool isMain;
  final VoidCallback? onMain;
  final VoidCallback? onDelete;
  const _ImageTile({required this.imageUrl, required this.isMain, required this.onMain, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return SizedBox(
      width: 96,
      child: Column(
        children: [
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: AspectRatio(
                  aspectRatio: 1,
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: cs.surfaceContainerHighest,
                      alignment: Alignment.center,
                      child: Icon(Icons.broken_image_outlined, color: cs.onSurfaceVariant),
                    ),
                  ),
                ),
              ),
              Positioned(
                right: 6,
                top: 6,
                child: InkWell(
                  onTap: onDelete,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(color: cs.surface.withValues(alpha: 0.85), borderRadius: BorderRadius.circular(999)),
                    child: Icon(Icons.close_rounded, size: 16, color: cs.onSurface),
                  ),
                ),
              ),
              if (isMain)
                Positioned(
                  left: 6,
                  top: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                    decoration: BoxDecoration(
                      color: cs.primary.withValues(alpha: 0.92),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text('MAIN', style: theme.textTheme.labelSmall?.copyWith(color: cs.onPrimary, fontWeight: FontWeight.w900)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          TextButton(
            onPressed: onMain,
            child: Text(isMain ? 'Main' : 'Set main', style: const TextStyle(fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
  }
}

class _LocalImageTile extends StatelessWidget {
  final XFile file;
  final bool isMain;
  final VoidCallback? onMain;
  final VoidCallback? onDelete;
  const _LocalImageTile({required this.file, required this.isMain, required this.onMain, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return SizedBox(
      width: 96,
      child: Column(
        children: [
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: AspectRatio(
                  aspectRatio: 1,
                  child: Image.file(
                    File(file.path),
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: cs.surfaceContainerHighest,
                      alignment: Alignment.center,
                      child: Icon(Icons.image_outlined, color: cs.onSurfaceVariant),
                    ),
                  ),
                ),
              ),
              Positioned(
                right: 6,
                top: 6,
                child: InkWell(
                  onTap: onDelete,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(color: cs.surface.withValues(alpha: 0.85), borderRadius: BorderRadius.circular(999)),
                    child: Icon(Icons.close_rounded, size: 16, color: cs.onSurface),
                  ),
                ),
              ),
              if (isMain)
                Positioned(
                  left: 6,
                  top: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                    decoration: BoxDecoration(color: cs.primary.withValues(alpha: 0.92), borderRadius: BorderRadius.circular(999)),
                    child: Text('MAIN', style: theme.textTheme.labelSmall?.copyWith(color: cs.onPrimary, fontWeight: FontWeight.w900)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          TextButton(
            onPressed: onMain,
            child: Text(isMain ? 'Main' : 'Set main', style: const TextStyle(fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
  }
}

