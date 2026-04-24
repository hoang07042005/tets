import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:freshfood_app/api/api_client.dart';
import 'package:freshfood_app/config/api_config.dart';
import 'package:freshfood_app/models/order.dart';
import 'package:freshfood_app/models/return_request.dart';
import 'package:freshfood_app/models/shipping_method.dart';
import 'package:freshfood_app/state/auth_state.dart';
import 'package:freshfood_app/ui/formatters.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class OrderDetailScreen extends StatefulWidget {
  final String idOrToken;
  const OrderDetailScreen({super.key, required this.idOrToken});

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  final _api = ApiClient();
  final _picker = ImagePicker();
  bool _loading = true;
  bool _acting = false;
  String? _err;
  String? _payMsg;
  Order? _order;
  ReturnRequest? _rr;
  ShippingMethod? _shippingMethod;

  @override
  void initState() {
    super.initState();
    _load();
  }

  bool get _isNumeric => int.tryParse(widget.idOrToken.trim()) != null;

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _err = null;
    });
    try {
      final o = _isNumeric ? await _api.getOrder(int.parse(widget.idOrToken.trim())) : await _api.getOrderByToken(widget.idOrToken);
      if (!mounted) return;
      setState(() => _order = o);

      // Shipping method (BaseCost / EstimatedDays) - to avoid hardcoded 30k.
      try {
        final methods = await _api.getShippingMethods();
        if (!mounted) return;
        final mid = o?.shippingMethodId;
        ShippingMethod? picked;
        if (mid != null) {
          for (final m in methods) {
            if (m.methodId == mid) {
              picked = m;
              break;
            }
          }
        }
        picked ??= methods.isEmpty ? null : methods.reduce((a, b) => (a.baseCost <= b.baseCost) ? a : b);
        setState(() => _shippingMethod = picked);
      } catch (_) {
        setState(() => _shippingMethod = null);
      }

      final u = AuthState.currentUser.value;
      if (o != null && u != null) {
        try {
          final rr = await _api.getOrderReturnRequest(orderId: o.orderId, userId: u.userId);
          if (!mounted) return;
          setState(() => _rr = rr);
        } catch (_) {
          // ignore
        }
      } else {
        setState(() => _rr = null);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _err = 'Không tải được chi tiết đơn hàng.\nLỗi: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _code(Order o) {
    final c = (o.orderCode ?? '').trim();
    if (c.isNotEmpty) return c.startsWith('#') ? c : '#$c';
    return '#FF-${o.orderId.toString().padLeft(5, '0')}';
  }

  String _statusLabel(String? status) {
    final s = (status ?? '').trim().toLowerCase();
    if (s == 'paid') return 'Đã thanh toán';
    if (s == 'delivered') return 'Đã giao';
    if (s == 'returnpending') return 'Chờ duyệt hoàn hàng';
    if (s == 'refundpending') return 'Chờ hoàn tiền';
    if (s == 'returned') return 'Hoàn hàng';
    if (s == 'refunded') return 'Đã hoàn tiền';
    if (s == 'intransit' || s == 'in_transit' || s == 'shipping' || s == 'shipped') return 'Đang giao';
    if (s == 'processing') return 'Đang xử lý';
    if (s == 'pending') return 'Đã đặt hàng';
    if (s == 'cancelled' || s == 'canceled') return 'Đã hủy';
    if (s == 'failed') return 'Thất bại';
    if (s == 'completed') return 'Hoàn thành';
    return status?.trim().isEmpty == false ? status!.trim() : 'Đang xử lý';
  }

  bool _isCancelled(Order o) {
    final s = (o.status ?? '').trim().toLowerCase();
    return s == 'cancelled' || s == 'canceled' || s == 'failed';
  }

  bool _delivered(Order o) {
    final s = (o.status ?? '').trim().toLowerCase();
    if (s == 'delivered' || s == 'completed') return true;
    final shipped = o.shipments.any((sh) {
      final ss = (sh.status ?? '').trim().toLowerCase();
      return ss == 'delivered' || sh.actualDeliveryDate != null;
    });
    return shipped;
  }

  bool _canCancel(Order o) {
    if (_isCancelled(o)) return false;
    final s = (o.status ?? '').trim().toLowerCase();
    if (s == 'shipping' || s == 'intransit' || s == 'in_transit' || s == 'delivered' || s == 'completed') return false;
    if (s == 'returned' || s == 'refunded' || s == 'returnpending' || s == 'refundpending') return false;
    final shippedByShipment = o.shipments.any((sh) {
      final ss = (sh.status ?? '').trim().toLowerCase();
      return ss == 'shipping' || ss == 'intransit' || ss == 'in_transit' || ss == 'delivered' || sh.shippedDate != null || sh.actualDeliveryDate != null;
    });
    if (shippedByShipment) return false;
    return s == 'pending' || s == 'processing' || s.isEmpty;
  }

  bool _canConfirmReceived(Order o) {
    final s = (o.status ?? '').trim().toLowerCase();
    if (s == 'completed') return false;
    return _delivered(o);
  }

  num _subtotal(Order o) => o.lines.fold<num>(0, (s, x) => s + (x.unitPrice * x.quantity));

  String _fmtDate(DateTime? d) {
    if (d == null) return '';
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  String _fmtDateTime(DateTime? d) {
    if (d == null) return '';
    return '${_fmtDate(d)} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  ({String method, String status, bool ok, bool isCod}) _paymentUi(Order o) {
    final p = o.payments.isEmpty ? null : o.payments.first;
    final m = (p?.paymentMethod ?? '').trim().toUpperCase();
    final st = (p?.status ?? '').trim().toLowerCase();
    final methodLabel = m == 'VNPAY'
        ? 'VNPay'
        : m == 'MOMO'
            ? 'MoMo'
            : m == 'COD'
                ? 'Thanh toán khi nhận hàng'
                : (p?.paymentMethod ?? '—');
    final statusLabel = (st == 'paid' || st == 'success')
        ? 'Thành công'
        : st == 'pending'
            ? 'Chờ thanh toán'
            : (p?.status ?? '—');
    final ok = st == 'paid' || st == 'success';
    final isCod = m == 'COD' || methodLabel == 'Thanh toán khi nhận hàng';
    return (method: methodLabel, status: statusLabel, ok: ok, isCod: isCod);
  }

  bool _canConfirmCodPaid(Order o) {
    if (_isCancelled(o)) return false;
    final pay = o.payments.isEmpty ? null : o.payments.first;
    final method = (pay?.paymentMethod ?? '').trim().toUpperCase();
    final status = (pay?.status ?? '').trim().toLowerCase();
    final isCod = method == 'COD' || _paymentUi(o).isCod;
    final isPending = status.isEmpty || status == 'pending';
    final payOk = status == 'paid' || status == 'success';
    return isCod && isPending && !payOk;
  }

  ({int step, bool cancelled, bool delivered, bool completed, bool returnMode}) _progress(Order o) {
    final st = (o.status ?? '').trim().toLowerCase();
    final cancelled = st == 'cancelled' || st == 'canceled' || st == 'failed';
    final completed = st == 'completed';
    final delivered = _delivered(o);
    final shipped = o.shipments.any((s) {
      final ss = (s.status ?? '').trim().toLowerCase();
      return ss == 'shipping' || ss == 'intransit' || ss == 'in_transit' || ss == 'delivered' || s.shippedDate != null;
    }) ||
        st == 'shipping' ||
        st == 'intransit' ||
        st == 'in_transit' ||
        st == 'shipped';

    final returnMode = (st == 'returnpending' || st == 'refundpending' || st == 'returned' || st == 'refunded') || _rr != null;

    if (cancelled) return (step: 0, cancelled: true, delivered: delivered, completed: completed, returnMode: returnMode);

    // 0 placed, 1 confirmed, 2 preparing, 3 shipping, 4 delivered, 5 completed/return
    var step = 0;
    if (st == 'pending' || st.isEmpty) step = 0;
    if (st == 'processing' || st == 'paid') step = 1;
    // backend may use packing/preparing
    if (st == 'preparing' || st == 'preparing_goods' || st == 'packing') step = 2;
    if (shipped) step = 3;
    if (delivered) step = 4;
    if (completed || returnMode) step = 5;
    return (step: step, cancelled: false, delivered: delivered, completed: completed, returnMode: returnMode);
  }

  Future<void> _doCancel() async {
    final u = AuthState.currentUser.value;
    final o = _order;
    if (u == null || o == null) return;

    final reasonCtl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Hủy đơn hàng?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Bạn có chắc muốn hủy đơn này không?'),
              const SizedBox(height: 12),
              TextField(
                controller: reasonCtl,
                decoration: const InputDecoration(hintText: 'Lý do (tuỳ chọn)'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Không')),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFFEF4444), foregroundColor: Colors.white),
              child: const Text('Hủy đơn'),
            ),
          ],
        );
      },
    );
    if (ok != true) return;

    setState(() => _acting = true);
    try {
      final next = await _api.cancelOrder(orderId: o.orderId, userId: u.userId, reason: reasonCtl.text.trim().isEmpty ? null : reasonCtl.text.trim());
      if (!mounted) return;
      if (next != null) setState(() => _order = next);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã hủy đơn hàng.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  Future<void> _doConfirmReceived() async {
    final u = AuthState.currentUser.value;
    final o = _order;
    if (u == null || o == null) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận đã nhận hàng?'),
        content: const Text('Hãy xác nhận khi bạn đã nhận đủ hàng đúng như đơn đặt.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Để sau')),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF62BF39), foregroundColor: Colors.white),
            child: const Text('Xác nhận'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _acting = true);
    try {
      final next = await _api.confirmReceived(orderId: o.orderId, userId: u.userId);
      if (!mounted) return;
      if (next != null) setState(() => _order = next);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã xác nhận nhận hàng.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  Future<void> _doConfirmCodPaid() async {
    final o = _order;
    if (o == null) return;
    if (_acting) return;
    setState(() {
      _acting = true;
      _payMsg = null;
    });
    try {
      final next = await _api.confirmCodPaid(orderId: o.orderId);
      if (!mounted) return;
      if (next != null) {
        setState(() {
          _order = next;
          _payMsg = 'Đã xác nhận thanh toán.';
        });
      } else {
        setState(() => _payMsg = 'Xác nhận thất bại.');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _payMsg = '$e'.replaceFirst('Exception: ', '').trim());
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  bool _canRequestReturn(Order o) {
    // Backend only allows when Order.Status == Delivered (not Completed).
    final st = (o.status ?? '').trim().toLowerCase();
    if (st != 'delivered') return false;
    if (_rr != null && (_rr!.status).trim().toLowerCase() != 'rejected') return false;
    return true;
  }

  Future<void> _openReturnForm(Order o) async {
    final u = AuthState.currentUser.value;
    if (u == null) return;

    final reasonCtl = TextEditingController();
    final pickedImages = <XFile>[];
    XFile? pickedVideo;
    bool submitting = false;
    final allowedImageExt = <String>{'.jpg', '.jpeg', '.png', '.webp', '.gif', '.jfif'};
    final allowedVideoExt = <String>{'.mp4', '.mov', '.webm', '.m4v'};

    Future<void> pickImages(StateSetter setM) async {
      final xs = await _picker.pickMultiImage(imageQuality: 88);
      if (xs.isEmpty) return;
      final accepted = <XFile>[];
      final rejected = <String>[];
      for (final f in xs) {
        final path = f.path;
        final dot = path.lastIndexOf('.');
        final ext = (dot >= 0 ? path.substring(dot).toLowerCase() : '');
        if (ext.isEmpty || !allowedImageExt.contains(ext)) {
          rejected.add(ext.isEmpty ? '(không rõ đuôi)' : ext);
          continue;
        }
        accepted.add(f);
      }
      if (rejected.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ảnh không hỗ trợ: ${rejected.toSet().join(', ')}. Chỉ nhận: ${allowedImageExt.join(', ')}')),
        );
      }
      if (accepted.isEmpty) return;
      setM(() {
        pickedImages.addAll(accepted);
        if (pickedImages.length > 6) pickedImages.removeRange(6, pickedImages.length);
      });
    }

    Future<void> pickVideo(StateSetter setM) async {
      final v = await _picker.pickVideo(source: ImageSource.gallery);
      if (v == null) return;
      final path = v.path;
      final dot = path.lastIndexOf('.');
      final ext = (dot >= 0 ? path.substring(dot).toLowerCase() : '');
      if (ext.isEmpty || !allowedVideoExt.contains(ext)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Video không hỗ trợ ($ext). Chỉ nhận: ${allowedVideoExt.join(', ')}')),
        );
        return;
      }
      try {
        final f = File(path);
        final bytes = await f.length();
        // Backend limit: ~70MB
        if (bytes > 70 * 1024 * 1024) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Video quá lớn (tối đa ~70MB). Vui lòng chọn video ngắn hơn.')),
          );
          return;
        }
      } catch (_) {
        // ignore; server will validate
      }
      setM(() => pickedVideo = v);
    }

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final theme = Theme.of(context);
        final bottom = MediaQuery.of(context).viewInsets.bottom;
        return StatefulBuilder(
          builder: (context, setM) {
            Future<void> submit() async {
              final reason = reasonCtl.text.trim();
              if (reason.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vui lòng nhập lý do hoàn hàng.')));
                return;
              }
              // Validate images against backend allow-list.
              for (final im in pickedImages) {
                final path = im.path;
                final dot = path.lastIndexOf('.');
                final ext = (dot >= 0 ? path.substring(dot).toLowerCase() : '');
                if (ext.isEmpty || !allowedImageExt.contains(ext)) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Ảnh không hỗ trợ ($ext). Chỉ nhận: ${allowedImageExt.join(', ')}')),
                  );
                  return;
                }
              }
              if (pickedVideo != null) {
                final path = pickedVideo!.path;
                final dot = path.lastIndexOf('.');
                final ext = (dot >= 0 ? path.substring(dot).toLowerCase() : '');
                if (ext.isEmpty || !allowedVideoExt.contains(ext)) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Video không hỗ trợ ($ext). Chỉ nhận: ${allowedVideoExt.join(', ')}')),
                  );
                  return;
                }
                try {
                  final bytes = await File(path).length();
                  if (bytes > 70 * 1024 * 1024) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Video quá lớn (tối đa ~70MB).')),
                    );
                    return;
                  }
                } catch (_) {
                  // ignore
                }
              }
              setM(() => submitting = true);
              try {
                await _api.createOrderReturnRequest(
                  orderId: o.orderId,
                  userId: u.userId,
                  reason: reason,
                  imageFilePaths: pickedImages.map((e) => e.path).toList(growable: false),
                  videoFilePath: pickedVideo?.path,
                );
                if (!context.mounted) return;
                Navigator.of(context).pop();
                ScaffoldMessenger.of(this.context).showSnackBar(const SnackBar(content: Text('Đã gửi yêu cầu hoàn hàng.')));
                // reload return request state
                // ignore: discarded_futures
                _load();
              } catch (e) {
                if (!context.mounted) return;
                showDialog<void>(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('Không gửi được yêu cầu'),
                    content: SelectableText('$e'),
                    actions: [
                      TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Đóng')),
                    ],
                  ),
                );
              } finally {
                if (context.mounted) setM(() => submitting = false);
              }
            }

            return Padding(
              padding: EdgeInsets.only(bottom: bottom),
              child: Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
                ),
                child: SafeArea(
                  top: false,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text('Yêu cầu hoàn hàng', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
                            ),
                            IconButton(onPressed: submitting ? null : () => Navigator.of(context).pop(), icon: const Icon(Icons.close)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Vui lòng mô tả lý do và đính kèm hình ảnh (tối đa 6).',
                          style: theme.textTheme.bodyMedium?.copyWith(color: const Color(0xFF64748B), fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: reasonCtl,
                          maxLines: 4,
                          decoration: InputDecoration(
                            hintText: 'Lý do hoàn hàng...',
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: submitting ? null : () => pickImages(setM),
                                icon: const Icon(Icons.photo_library_outlined),
                                label: const Text('Thêm ảnh'),
                                style: OutlinedButton.styleFrom(
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: submitting ? null : () => pickVideo(setM),
                                icon: const Icon(Icons.videocam_outlined),
                                label: Text(pickedVideo == null ? 'Thêm video' : 'Đã chọn video'),
                                style: OutlinedButton.styleFrom(
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (pickedVideo != null)
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              color: const Color(0xFFF8FAFC),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.movie_outlined, color: Color(0xFF64748B)),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    pickedVideo!.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w900),
                                  ),
                                ),
                                TextButton(
                                  onPressed: submitting ? null : () => setM(() => pickedVideo = null),
                                  child: const Text('Bỏ chọn', style: TextStyle(fontWeight: FontWeight.w900)),
                                ),
                              ],
                            ),
                          ),
                        if (pickedImages.isNotEmpty)
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              for (int i = 0; i < pickedImages.length; i++)
                                Stack(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(14),
                                      child: Image.file(
                                        // ignore: avoid_slow_async_io
                                        File(pickedImages[i].path),
                                        width: 86,
                                        height: 86,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                    Positioned(
                                      right: 6,
                                      top: 6,
                                      child: InkWell(
                                        onTap: submitting
                                            ? null
                                            : () => setM(() {
                                                  pickedImages.removeAt(i);
                                                }),
                                        borderRadius: BorderRadius.circular(999),
                                        child: Container(
                                          width: 26,
                                          height: 26,
                                          decoration: BoxDecoration(
                                            color: Colors.black.withValues(alpha: 0.55),
                                            borderRadius: BorderRadius.circular(999),
                                          ),
                                          child: const Icon(Icons.close, color: Colors.white, size: 16),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          height: 46,
                          child: FilledButton(
                            onPressed: submitting ? null : submit,
                            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF62BF39), foregroundColor: Colors.white),
                            child: submitting
                                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Text('Gửi yêu cầu', style: TextStyle(fontWeight: FontWeight.w900)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Chi tiết đơn hàng')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _err != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_err!, style: theme.textTheme.bodyLarge),
                        const SizedBox(height: 10),
                        FilledButton(onPressed: _load, child: const Text('Thử lại')),
                      ],
                    ),
                  ),
                )
              : _order == null
                  ? const SizedBox.shrink()
                  : _buildBody(context, _order!),
    );
  }

  Widget _buildBody(BuildContext context, Order o) {
    final theme = Theme.of(context);
    final subtotal = _subtotal(o);
    final baseShipping = _shippingMethod?.baseCost ?? 30000;
    final shipping = subtotal >= 200000 ? 0 : baseShipping;
    final tax = (subtotal * 0.015).round();
    final grand = o.totalAmount; // trust backend for discounts/voucher/shipping/tax consistency

    final st = _statusLabel(o.status);
    final pay = _paymentUi(o);
    final prog = _progress(o);
    final canCancel = _canCancel(o);
    final canRecv = _canConfirmReceived(o);
    final canReturn = _canRequestReturn(o);
    final canConfirmPaid = _canConfirmCodPaid(o);
    final primaryShipment = o.shipments.isEmpty ? null : o.shipments.first;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Header
        _SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text('Chi tiết đơn hàng', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900))),
                  _StatusPill(label: st, tone: _toneOfStatus(o.status)),
                ],
              ),
              const SizedBox(height: 8),
              Text('Mã đơn: ${_code(o)}', style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w900)),
              if (o.orderDate != null) ...[
                const SizedBox(height: 4),
                Text('Đặt lúc ${_fmtDateTime(o.orderDate)}', style: theme.textTheme.bodyMedium?.copyWith(color: const Color(0xFF64748B), fontWeight: FontWeight.w700)),
              ],
              if (pay.ok) ...[
                const SizedBox(height: 4),
                Text('Đã thanh toán', style: theme.textTheme.bodyMedium?.copyWith(color: const Color(0xFF16A34A), fontWeight: FontWeight.w900)),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Progress
        _SectionCard(
          title: 'Tiến trình',
          child: _ProgressStepper(
            step: prog.step,
            cancelled: prog.cancelled,
            returnMode: prog.returnMode,
            times: _ProgressTimes(
              placedAt: o.orderDate,
              shippedAt: primaryShipment?.shippedDate,
              deliveredAt: primaryShipment?.actualDeliveryDate,
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Payment
        _SectionCard(
          title: 'Thanh toán',
          child: Column(
            children: [
              if ((_payMsg ?? '').trim().isNotEmpty) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    color: const Color(0xFF2ECC71).withValues(alpha: 0.10),
                  ),
                  child: Text(_payMsg!, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w900)),
                ),
                const SizedBox(height: 12),
              ],
              _MetaRow(label: 'Phương thức', value: pay.method),
              const SizedBox(height: 8),
              _MetaRow(label: 'Trạng thái', value: pay.status),
              if (canConfirmPaid) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton(
                    onPressed: _acting ? null : _doConfirmCodPaid,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2ECC71),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      textStyle: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    child: Text(_acting ? 'Đang xác nhận...' : 'Xác nhận đã thanh toán'),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Shipping / Tracking
        _SectionCard(
          title: 'Vận chuyển',
          child: Column(
            children: [
              _MetaRow(label: 'Phí vận chuyển', value: shipping == 0 ? 'Miễn phí' : Formatters.vnd(shipping)),
              if (_shippingMethod != null) ...[
                const SizedBox(height: 8),
                _MetaRow(label: 'Gói vận chuyển', value: _shippingMethod!.methodName),
                if ((_shippingMethod!.estimatedDays ?? 0) > 0) ...[
                  const SizedBox(height: 8),
                  _MetaRow(label: 'Dự kiến (ngày)', value: '${_shippingMethod!.estimatedDays}'),
                ],
              ],
              if (primaryShipment != null) ...[
                const SizedBox(height: 8),
                _MetaRow(
                  label: 'Đơn vị vận chuyển',
                  value: (primaryShipment.carrier ?? '').trim().isEmpty ? '—' : primaryShipment.carrier!.trim(),
                ),
                const SizedBox(height: 8),
                _MetaRow(
                  label: 'Mã vận đơn',
                  value: (primaryShipment.trackingNumber ?? '').trim().isEmpty ? '—' : primaryShipment.trackingNumber!.trim(),
                ),
                if ((primaryShipment.status ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _MetaRow(label: 'Trạng thái vận chuyển', value: primaryShipment.status!.trim()),
                ],
                if (primaryShipment.estimatedDeliveryDate != null) ...[
                  const SizedBox(height: 8),
                  _MetaRow(label: 'Dự kiến giao', value: _fmtDate(primaryShipment.estimatedDeliveryDate)),
                ],
                if (primaryShipment.actualDeliveryDate != null) ...[
                  const SizedBox(height: 8),
                  _MetaRow(label: 'Đã giao lúc', value: _fmtDateTime(primaryShipment.actualDeliveryDate)),
                ],
              ],
              if (primaryShipment == null)
                Text('Chưa có thông tin vận chuyển.', style: theme.textTheme.bodyMedium?.copyWith(color: const Color(0xFF64748B))),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Address
        if ((o.shippingAddress ?? '').trim().isNotEmpty) ...[
          _SectionCard(
            title: 'Thông tin người nhận và địa chỉ giao hàng',
            child: Text(o.shippingAddress!.trim(), style: theme.textTheme.bodyMedium?.copyWith(color: const Color(0xFF475569), height: 1.25)),
          ),
          const SizedBox(height: 12),
        ],

        // Items
        _SectionCard(
          title: 'Sản phẩm',
          child: Column(children: [for (final x in o.lines) _LineTile(line: x)]),
        ),
        const SizedBox(height: 12),

        // Summary
        _SectionCard(
          title: 'Tóm tắt',
          child: Column(
            children: [
              _SumRow(label: 'Tạm tính', value: Formatters.vnd(subtotal)),
              const SizedBox(height: 8),
              _SumRow(label: 'Vận chuyển', value: shipping == 0 ? 'Miễn phí' : Formatters.vnd(shipping)),
              const SizedBox(height: 8),
              _SumRow(label: 'Thuế (1.5%)', value: Formatters.vnd(tax)),
              const Divider(height: 20),
              _SumRow(
                label: 'Tổng thanh toán',
                value: Formatters.vnd(grand),
                valueStyle: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900, color: const Color(0xFFE67E22)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        if (_rr != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _SectionCard(
              title: 'Hoàn hàng / hoàn tiền',
              child: _ReturnRequestView(rr: _rr!),
            ),
          ),

        if (_acting) const Center(child: Padding(padding: EdgeInsets.symmetric(vertical: 8), child: CircularProgressIndicator())),
        if (!_acting && (canCancel || canRecv || canReturn))
          Row(
            children: [
              if (canReturn)
                Expanded(
                  child: FilledButton(
                    onPressed: () => _openReturnForm(o),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF0F172A),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('Hoàn hàng', style: TextStyle(fontWeight: FontWeight.w900)),
                  ),
                ),
              if (canReturn && (canCancel || canRecv)) const SizedBox(width: 10),
              if (canCancel)
                Expanded(
                  child: OutlinedButton(
                    onPressed: _doCancel,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFEF4444),
                      side: const BorderSide(color: Color(0xFFEF4444)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('Hủy đơn', style: TextStyle(fontWeight: FontWeight.w900)),
                  ),
                ),
              if (canCancel && canRecv) const SizedBox(width: 10),
              if (canRecv)
                Expanded(
                  child: FilledButton(
                    onPressed: _doConfirmReceived,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF62BF39),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('Đã nhận hàng', style: TextStyle(fontWeight: FontWeight.w900)),
                  ),
                ),
            ],
          ),
        const SizedBox(height: 24),
      ],
    );
  }
}

class _LineTile extends StatelessWidget {
  final OrderLine line;
  const _LineTile({required this.line});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final img = ApiConfig.resolveMediaUrl(line.imageUrl);
    final name = (line.productName ?? 'Sản phẩm').trim();
    final total = line.unitPrice * line.quantity;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: theme.colorScheme.surface,
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        child: Row(
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), color: theme.colorScheme.surfaceContainerHighest),
              clipBehavior: Clip.antiAlias,
              child: img.isEmpty ? const Icon(Icons.image_not_supported, color: Color(0xFF64748B)) : CachedNetworkImage(imageUrl: img, fit: BoxFit.cover),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, maxLines: 2, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 4),
                  Text('SL: ${line.quantity}', style: theme.textTheme.bodySmall?.copyWith(color: const Color(0xFF64748B), fontWeight: FontWeight.w800)),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(Formatters.vnd(total), style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900, color: const Color(0xFFE67E22))),
                const SizedBox(height: 2),
                Text('${Formatters.vnd(line.unitPrice)} x ${line.quantity}',
                    style: theme.textTheme.bodySmall?.copyWith(color: const Color(0xFF94A3B8), fontWeight: FontWeight.w800)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SumRow extends StatelessWidget {
  final String label;
  final String value;
  final TextStyle? valueStyle;
  const _SumRow({required this.label, required this.value, this.valueStyle});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(child: Text(label, style: theme.textTheme.bodyMedium?.copyWith(color: const Color(0xFF64748B), fontWeight: FontWeight.w800))),
        Text(value, style: valueStyle ?? theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w900)),
      ],
    );
  }
}

enum _StatusTone { good, info, warn, bad, neutral }

_StatusTone _toneOfStatus(String? status) {
  final s = (status ?? '').trim().toLowerCase();
  if (s == 'delivered' || s == 'completed' || s == 'paid') return _StatusTone.good;
  if (s == 'shipping' || s == 'intransit' || s == 'in_transit' || s == 'shipped') return _StatusTone.info;
  if (s == 'cancelled' || s == 'canceled' || s == 'failed') return _StatusTone.bad;
  if (s == 'returnpending' || s == 'refundpending' || s == 'returned' || s == 'refunded') return _StatusTone.warn;
  return _StatusTone.neutral;
}

class _StatusPill extends StatelessWidget {
  final String label;
  final _StatusTone tone;
  const _StatusPill({required this.label, required this.tone});

  Color get _fg {
    switch (tone) {
      case _StatusTone.good:
        return const Color(0xFF16A34A);
      case _StatusTone.info:
        return const Color(0xFF2563EB);
      case _StatusTone.warn:
        return const Color(0xFF7C3AED);
      case _StatusTone.bad:
        return const Color(0xFFEF4444);
      case _StatusTone.neutral:
        return const Color(0xFFB45309);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fg = _fg;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: fg.withValues(alpha: 0.10),
      ),
      child: Text(label, style: TextStyle(color: fg, fontWeight: FontWeight.w900)),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String? title;
  final Widget child;
  const _SectionCard({this.title, required this.child});

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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Text(title!, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
            const SizedBox(height: 10),
          ],
          child,
        ],
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  final String label;
  final String value;
  const _MetaRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant, fontWeight: FontWeight.w800),
          ),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
        ),
      ],
    );
  }
}

class _ProgressTimes {
  final DateTime? placedAt;
  final DateTime? shippedAt;
  final DateTime? deliveredAt;
  const _ProgressTimes({required this.placedAt, required this.shippedAt, required this.deliveredAt});
}

class _ProgressStepper extends StatelessWidget {
  final int step;
  final bool cancelled;
  final bool returnMode;
  final _ProgressTimes times;
  const _ProgressStepper({required this.step, required this.cancelled, required this.returnMode, required this.times});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final items = <({String title, String time})>[
      (title: 'Đã đặt hàng', time: _fmt(times.placedAt)),
      (title: 'Đã xác nhận', time: step >= 1 ? _fmt(times.placedAt) : ''),
      (title: 'Đang chuẩn bị', time: step >= 2 ? _fmt(times.placedAt) : ''),
      (title: 'Đang giao', time: step >= 3 ? _fmt(times.shippedAt) : ''),
      (title: 'Đã giao', time: step >= 4 ? _fmt(times.deliveredAt) : ''),
      (title: returnMode ? 'Hoàn hàng' : 'Hoàn thành', time: step >= 5 ? _fmt(times.deliveredAt) : ''),
    ];

    return Column(
      children: [
        for (var i = 0; i < items.length; i++)
          _StepRow(
            title: items[i].title,
            time: items[i].time,
            active: cancelled ? i == 0 : i <= step,
            isLast: i == items.length - 1,
            danger: cancelled && i == 0,
          ),
        if (cancelled)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(
              'Đơn hàng đã bị hủy / thất bại.',
              style: theme.textTheme.bodyMedium?.copyWith(color: cs.error, fontWeight: FontWeight.w800),
            ),
          ),
      ],
    );
  }

  String _fmt(DateTime? d) {
    if (d == null) return '';
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }
}

class _StepRow extends StatelessWidget {
  final String title;
  final String time;
  final bool active;
  final bool isLast;
  final bool danger;
  const _StepRow({required this.title, required this.time, required this.active, required this.isLast, required this.danger});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final dotColor = danger
        ? cs.error
        : active
            ? cs.primary
            : cs.outlineVariant.withValues(alpha: 0.9);
    final lineColor = active ? cs.primary.withValues(alpha: 0.28) : cs.outlineVariant.withValues(alpha: 0.7);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 26,
                color: lineColor,
              ),
          ],
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w900, color: cs.onSurface)),
                if (time.trim().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(time, style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant, fontWeight: FontWeight.w700)),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ReturnRequestView extends StatelessWidget {
  final ReturnRequest rr;
  const _ReturnRequestView({required this.rr});

  String _stLabel(String s) {
    final v = s.trim().toLowerCase();
    if (v == 'pending') return 'Chờ duyệt';
    if (v == 'approved') return 'Đã chấp nhận';
    if (v == 'rejected') return 'Đã từ chối';
    return s.trim().isEmpty ? '—' : s.trim();
  }

  Color _stColor(String s) {
    final v = s.trim().toLowerCase();
    if (v == 'approved') return const Color(0xFF16A34A);
    if (v == 'rejected') return const Color(0xFFEF4444);
    return const Color(0xFFB45309);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final st = _stLabel(rr.status);
    final stc = _stColor(rr.status);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(999), color: stc.withValues(alpha: 0.10)),
              child: Text(st, style: TextStyle(color: stc, fontWeight: FontWeight.w900)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                rr.requestType,
                style: theme.textTheme.bodyMedium?.copyWith(color: const Color(0xFF64748B), fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text('Lý do', style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w900)),
        const SizedBox(height: 4),
        Text(rr.reason, style: theme.textTheme.bodyMedium?.copyWith(color: const Color(0xFF475569), height: 1.25)),
        if ((rr.adminNote ?? '').trim().isNotEmpty) ...[
          const SizedBox(height: 10),
          Text('Phản hồi', style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text(rr.adminNote!.trim(), style: theme.textTheme.bodyMedium?.copyWith(color: const Color(0xFF475569), height: 1.25)),
        ],
        if (rr.images.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text('Hình ảnh', style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final im in rr.images)
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: CachedNetworkImage(
                    imageUrl: ApiConfig.resolveMediaUrl(im.imageUrl),
                    width: 86,
                    height: 86,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(width: 86, height: 86, color: const Color(0xFFF1F5F9)),
                    errorWidget: (_, __, ___) => Container(width: 86, height: 86, color: const Color(0xFFF1F5F9), child: const Icon(Icons.broken_image)),
                  ),
                ),
            ],
          ),
        ],
        if ((rr.refundProofUrl ?? '').trim().isNotEmpty) ...[
          const SizedBox(height: 10),
          Text('Chứng từ hoàn tiền', style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: CachedNetworkImage(
              imageUrl: ApiConfig.resolveMediaUrl(rr.refundProofUrl),
              height: 180,
              width: double.infinity,
              fit: BoxFit.cover,
              placeholder: (_, __) => Container(height: 180, color: const Color(0xFFF1F5F9)),
              errorWidget: (_, __, ___) => Container(height: 180, color: const Color(0xFFF1F5F9), child: const Icon(Icons.broken_image)),
            ),
          ),
          if ((rr.refundNote ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(rr.refundNote!.trim(), style: theme.textTheme.bodyMedium?.copyWith(color: const Color(0xFF475569))),
          ],
        ],
      ],
    );
  }
}

