import 'dart:convert';
import 'dart:async';
import 'dart:typed_data';

import 'package:freshfood_app/config/api_config.dart';
import 'package:freshfood_app/models/admin_low_stock_product.dart';
import 'package:freshfood_app/models/admin_order.dart';
import 'package:freshfood_app/models/admin_product.dart';
import 'package:freshfood_app/models/admin_product_detail.dart';
import 'package:freshfood_app/models/admin_recent_import.dart';
import 'package:freshfood_app/models/admin_supplier.dart';
import 'package:freshfood_app/models/category.dart';
import 'package:freshfood_app/models/blog_comment.dart';
import 'package:freshfood_app/models/blog_post.dart';
import 'package:freshfood_app/models/home_settings.dart';
import 'package:freshfood_app/models/product.dart';
import 'package:freshfood_app/models/public_order_track.dart';
import 'package:freshfood_app/models/review.dart';
import 'package:freshfood_app/models/order.dart';
import 'package:freshfood_app/models/return_request.dart';
import 'package:freshfood_app/models/user_address.dart';
import 'package:freshfood_app/models/voucher.dart';
import 'package:freshfood_app/models/shipping_method.dart';
import 'package:http/http.dart' as http;
import 'package:freshfood_app/state/auth_state.dart';
import 'package:freshfood_app/state/maintenance_state.dart';
import 'package:http_parser/http_parser.dart';

class _MaintenanceAwareClient extends http.BaseClient {
  final http.Client _inner;
  _MaintenanceAwareClient(this._inner);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final streamed = await _inner.send(request);
    if (streamed.statusCode != 503) return streamed;

    final Uint8List bytes = await streamed.stream.toBytes();
    try {
      final text = utf8.decode(bytes);
      if (text.contains('"isMaintenance":true') || text.contains('"isMaintenance": true')) {
        String? msg;
        try {
          final j = jsonDecode(text);
          if (j is Map) {
            final m = Map<String, dynamic>.from(j);
            final raw = m['message'] ?? m['Message'];
            if (raw != null) msg = raw.toString();
          }
        } catch (_) {
          // ignore JSON decode errors
        }
        MaintenanceState.enter(msg: msg);
      }
    } catch (_) {
      // ignore decode errors
    }

    // Re-create the stream because we consumed it.
    return http.StreamedResponse(
      Stream<List<int>>.fromIterable(<List<int>>[bytes]),
      streamed.statusCode,
      contentLength: bytes.length,
      request: streamed.request,
      headers: streamed.headers,
      isRedirect: streamed.isRedirect,
      persistentConnection: streamed.persistentConnection,
      reasonPhrase: streamed.reasonPhrase,
    );
  }

  @override
  void close() => _inner.close();
}

class ApiClient {
  final http.Client _client;

  static final http.Client _sharedClient = _MaintenanceAwareClient(http.Client());
  static final ApiClient _instance = ApiClient._internal(_sharedClient);

  factory ApiClient({http.Client? client}) {
    if (client != null) return ApiClient._internal(client);
    return _instance;
  }

  ApiClient._internal(http.Client client) : _client = client;

  static ApiClient get instance => _instance;

  static final Map<String, _CacheEntry> _memCache = <String, _CacheEntry>{};

  T? _cacheGet<T>(String key) {
    final e = _memCache[key];
    if (e == null) return null;
    if (DateTime.now().isAfter(e.expiresAt)) {
      _memCache.remove(key);
      return null;
    }
    final v = e.value;
    return v is T ? v : null;
  }

  void _cacheSet(String key, dynamic value, {required Duration ttl}) {
    _memCache[key] = _CacheEntry(value: value, expiresAt: DateTime.now().add(ttl));
  }

  Uri _u(String pathAndQuery) => Uri.parse('${ApiConfig.apiBaseUrl}$pathAndQuery');

  Map<String, String> _authHeaders({bool json = false}) {
    final h = <String, String>{};
    if (json) h['Content-Type'] = 'application/json';
    h['ngrok-skip-browser-warning'] = 'true';
    final t = AuthState.token.value;
    if (t != null && t.trim().isNotEmpty) {
      h['Authorization'] = 'Bearer $t';
    }
    return h;
  }

  Future<Map<String, dynamic>> _decodeJson(http.Response res) async {
    final body = jsonDecode(res.body);
    if (body is Map) return Map<String, dynamic>.from(body);
    return <String, dynamic>{'data': body};
  }

  String _errMsg(http.Response res) {
    try {
      final body = jsonDecode(res.body);
      if (body is String) return body;
      if (body is Map) {
        final m = Map<String, dynamic>.from(body);
        final msg = m['message'] ?? m['Message'] ?? m['error'] ?? m['Error'];
        if (msg != null) return '$msg';
      }
      return res.body.toString();
    } catch (_) {
      return res.body.toString();
    }
  }

  Future<LoginResult> login({required String email, required String password}) async {
    final res = await _client.post(
      _u('/Account/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception(_errMsg(res).isEmpty ? 'Đăng nhập thất bại.' : _errMsg(res));
    }
    final m = await _decodeJson(res);
    final userRaw = m['user'] ?? m['User'];
    final token = (m['token'] ?? m['Token'] ?? '').toString();
    final expRaw = m['expiresInSeconds'] ?? m['ExpiresInSeconds'] ?? 3600;
    final expiresIn = expRaw is num ? expRaw.toInt() : int.tryParse('$expRaw') ?? 3600;
    if (userRaw is! Map) throw Exception('Dữ liệu đăng nhập không hợp lệ.');
    final u = Map<String, dynamic>.from(userRaw);
    return LoginResult(user: AuthUser.fromJson({
      'userId': u['userID'] ?? u['UserID'] ?? u['userId'] ?? 0,
      'fullName': u['fullName'] ?? u['FullName'] ?? '',
      'email': u['email'] ?? u['Email'] ?? '',
      'role': u['role'] ?? u['Role'] ?? 'Customer',
      'phone': u['phone'] ?? u['Phone'],
      'address': u['address'] ?? u['Address'],
      'avatarUrl': u['avatarUrl'] ?? u['AvatarUrl'] ?? u['avatarURL'] ?? u['AvatarURL'],
    }), token: token, expiresInSeconds: expiresIn);
  }

  Future<AuthUser> register({required String fullName, required String email, required String phone, required String password}) async {
    final res = await _client.post(
      _u('/Account/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'fullName': fullName, 'email': email, 'phone': phone, 'password': password}),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception(_errMsg(res).isEmpty ? 'Đăng ký thất bại.' : _errMsg(res));
    }
    final body = jsonDecode(res.body);
    if (body is! Map) throw Exception('Dữ liệu đăng ký không hợp lệ.');
    final u = Map<String, dynamic>.from(body);
    return AuthUser.fromJson({
      'userId': u['userID'] ?? u['UserID'] ?? u['userId'] ?? 0,
      'fullName': u['fullName'] ?? u['FullName'] ?? '',
      'email': u['email'] ?? u['Email'] ?? '',
      'role': u['role'] ?? u['Role'] ?? 'Customer',
      'phone': u['phone'] ?? u['Phone'],
      'address': u['address'] ?? u['Address'],
      'avatarUrl': u['avatarUrl'] ?? u['AvatarUrl'] ?? u['avatarURL'] ?? u['AvatarURL'],
    });
  }

  Future<AuthUser> getAccountUser(int userId) async {
    final res = await _client.get(_u('/Account/$userId'), headers: _authHeaders());
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception(_errMsg(res).isEmpty ? 'Không tải được hồ sơ.' : _errMsg(res));
    }
    final body = jsonDecode(res.body);
    if (body is! Map) throw Exception('Dữ liệu hồ sơ không hợp lệ.');
    final u = Map<String, dynamic>.from(body);
    return AuthUser.fromJson({
      'userId': u['userID'] ?? u['UserID'] ?? u['userId'] ?? 0,
      'fullName': u['fullName'] ?? u['FullName'] ?? '',
      'email': u['email'] ?? u['Email'] ?? '',
      'role': u['role'] ?? u['Role'] ?? 'Customer',
      'phone': u['phone'] ?? u['Phone'],
      'address': u['address'] ?? u['Address'],
      'avatarUrl': u['avatarUrl'] ?? u['AvatarUrl'] ?? u['avatarURL'] ?? u['AvatarURL'],
    });
  }

  Future<AuthUser> updateProfile(int userId, {required String fullName, String? phone, String? address}) async {
    final res = await _client.put(
      _u('/Account/$userId'),
      headers: _authHeaders(json: true),
      body: jsonEncode({'fullName': fullName, 'phone': phone, 'address': address}),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception(_errMsg(res).isEmpty ? 'Cập nhật thất bại.' : _errMsg(res));
    }
    final body = jsonDecode(res.body);
    if (body is! Map) throw Exception('Dữ liệu cập nhật không hợp lệ.');
    final u = Map<String, dynamic>.from(body);
    return AuthUser.fromJson({
      'userId': u['userID'] ?? u['UserID'] ?? u['userId'] ?? 0,
      'fullName': u['fullName'] ?? u['FullName'] ?? '',
      'email': u['email'] ?? u['Email'] ?? '',
      'role': u['role'] ?? u['Role'] ?? 'Customer',
      'phone': u['phone'] ?? u['Phone'],
      'address': u['address'] ?? u['Address'],
      'avatarUrl': u['avatarUrl'] ?? u['AvatarUrl'] ?? u['avatarURL'] ?? u['AvatarURL'],
    });
  }

  Future<AuthUser> uploadAvatar(int userId, String filePath) async {
    final uri = Uri.parse('${ApiConfig.apiBaseUrl}/Account/$userId/avatar');
    final req = http.MultipartRequest('POST', uri);
    req.headers.addAll(_authHeaders());
    req.files.add(await http.MultipartFile.fromPath('file', filePath));
    final streamed = await req.send();
    final res = await http.Response.fromStream(streamed);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception(_errMsg(res).isEmpty ? 'Tải avatar thất bại.' : _errMsg(res));
    }
    final body = jsonDecode(res.body);
    if (body is! Map) throw Exception('Dữ liệu avatar không hợp lệ.');
    final u = Map<String, dynamic>.from(body);
    return AuthUser.fromJson({
      'userId': u['userID'] ?? u['UserID'] ?? u['userId'] ?? 0,
      'fullName': u['fullName'] ?? u['FullName'] ?? '',
      'email': u['email'] ?? u['Email'] ?? '',
      'role': u['role'] ?? u['Role'] ?? 'Customer',
      'phone': u['phone'] ?? u['Phone'],
      'address': u['address'] ?? u['Address'],
      'avatarUrl': u['avatarUrl'] ?? u['AvatarUrl'] ?? u['avatarURL'] ?? u['AvatarURL'],
    });
  }

  Future<void> changePassword(int userId, {required String currentPassword, required String newPassword}) async {
    final res = await _client.post(
      _u('/Account/change-password'),
      headers: _authHeaders(json: true),
      body: jsonEncode({'userID': userId, 'currentPassword': currentPassword, 'newPassword': newPassword}),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception(_errMsg(res).isEmpty ? 'Đổi mật khẩu thất bại.' : _errMsg(res));
    }
  }

  Future<String?> forgotPassword({required String email}) async {
    final res = await _client.post(
      _u('/Account/forgot-password'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email}),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception(_errMsg(res).isEmpty ? 'Gửi yêu cầu thất bại.' : _errMsg(res));
    }
    final m = await _decodeJson(res);
    final token = (m['token'] ?? m['Token'] ?? '').toString().trim();
    return token.isEmpty ? null : token;
  }

  Future<void> resetPassword({required String email, required String token, required String newPassword}) async {
    final res = await _client.post(
      _u('/Account/reset-password'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'token': token, 'newPassword': newPassword}),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception(_errMsg(res).isEmpty ? 'Đặt lại mật khẩu thất bại.' : _errMsg(res));
    }
  }

  Future<void> setInitialPassword({required String email, required String token, required String newPassword}) async {
    final res = await _client.post(
      _u('/Account/set-initial-password'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'token': token, 'newPassword': newPassword}),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception(_errMsg(res).isEmpty ? 'Đặt mật khẩu thất bại.' : _errMsg(res));
    }
  }

  Future<List<UserAddress>> getUserAddresses(int userId) async {
    final res = await _client.get(_u('/UserAddresses/user/$userId'), headers: _authHeaders());
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception(_errMsg(res).isEmpty ? 'Không tải được sổ địa chỉ.' : _errMsg(res));
    }
    final body = jsonDecode(res.body);
    if (body is! List) return const [];
    final out = <UserAddress>[];
    for (final item in body) {
      if (item is Map) out.add(UserAddress.fromJson(Map<String, dynamic>.from(item)));
    }
    return out;
  }

  Future<UserAddress> createUserAddress(
    int userId, {
    required String recipientName,
    String? phone,
    required String addressLine,
    String? label,
    bool isDefault = false,
  }) async {
    final res = await _client.post(
      _u('/UserAddresses/user/$userId'),
      headers: _authHeaders(json: true),
      body: jsonEncode({
        'recipientName': recipientName,
        'phone': phone,
        'addressLine': addressLine,
        'label': label,
        'isDefault': isDefault,
      }),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception(_errMsg(res).isEmpty ? 'Không thêm được địa chỉ.' : _errMsg(res));
    }
    final body = jsonDecode(res.body);
    if (body is! Map) throw Exception('Dữ liệu địa chỉ không hợp lệ.');
    return UserAddress.fromJson(Map<String, dynamic>.from(body));
  }

  Future<UserAddress> updateUserAddress(
    int addressId,
    int userId, {
    required String recipientName,
    String? phone,
    required String addressLine,
    String? label,
    bool isDefault = false,
  }) async {
    final uri = _u('/UserAddresses/$addressId').replace(queryParameters: {'userId': '$userId'});
    final res = await _client.put(
      uri,
      headers: _authHeaders(json: true),
      body: jsonEncode({
        'recipientName': recipientName,
        'phone': phone,
        'addressLine': addressLine,
        'label': label,
        'isDefault': isDefault,
      }),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception(_errMsg(res).isEmpty ? 'Không cập nhật được địa chỉ.' : _errMsg(res));
    }
    final body = jsonDecode(res.body);
    if (body is! Map) throw Exception('Dữ liệu địa chỉ không hợp lệ.');
    return UserAddress.fromJson(Map<String, dynamic>.from(body));
  }

  Future<void> deleteUserAddress(int addressId, int userId) async {
    final uri = _u('/UserAddresses/$addressId').replace(queryParameters: {'userId': '$userId'});
    final res = await _client.delete(uri, headers: _authHeaders());
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception(_errMsg(res).isEmpty ? 'Không xóa được địa chỉ.' : _errMsg(res));
    }
  }

  Future<void> setDefaultUserAddress(int addressId, int userId) async {
    final uri = _u('/UserAddresses/$addressId/set-default').replace(queryParameters: {'userId': '$userId'});
    final res = await _client.put(uri, headers: _authHeaders());
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception(_errMsg(res).isEmpty ? 'Không đặt mặc định được.' : _errMsg(res));
    }
  }

  Future<List<Category>> getCategories() async {
    final cached = _cacheGet<List<Category>>('categories');
    if (cached != null) return cached;
    final res = await _client.get(_u('/Categories'));
    if (res.statusCode < 200 || res.statusCode >= 300) return const [];
    final body = jsonDecode(res.body);
    if (body is! List) return const [];
    final out = <Category>[];
    for (final item in body) {
      if (item is Map) {
        out.add(Category.fromJson(Map<String, dynamic>.from(item)));
      }
    }
    _cacheSet('categories', out, ttl: const Duration(minutes: 10));
    return out;
  }

  Future<HomePageSettings?> getHomePageSettings() async {
    final cached = _cacheGet<HomePageSettings>('home_page_settings');
    if (cached != null) return cached;
    final res = await _client.get(_u('/HomePage'));
    if (res.statusCode < 200 || res.statusCode >= 300) return null;
    final body = jsonDecode(res.body);
    if (body is! Map) return null;
    final v = HomePageSettings.fromJson(Map<String, dynamic>.from(body));
    _cacheSet('home_page_settings', v, ttl: const Duration(minutes: 5));
    return v;
  }

  Future<HomePageSettings?> getAdminHomePageSettings() async {
    final res = await _client.get(_u('/Admin/HomePage'), headers: _authHeaders());
    if (res.statusCode < 200 || res.statusCode >= 300) return null;
    final body = jsonDecode(res.body);
    if (body is! Map) return null;
    return HomePageSettings.fromJson(Map<String, dynamic>.from(body));
  }

  Future<void> adminUpdateHomePageSettings(HomePageSettings input) async {
    final res = await _client.put(
      _u('/Admin/HomePage'),
      headers: _authHeaders(json: true),
      body: jsonEncode(input.toJson()),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception(_errMsg(res).isEmpty ? 'Lưu thiết lập trang chủ thất bại.' : _errMsg(res));
    }
    clearMemCache();
  }

  Future<String> adminUploadHomeImage(String filePath) async {
    final p = filePath.trim();
    if (p.isEmpty) throw Exception('File ảnh không hợp lệ.');
    final uri = Uri.parse('${ApiConfig.apiBaseUrl}/Admin/HomePage/UploadImage');
    final req = http.MultipartRequest('POST', uri);
    final token = (AuthState.token.value ?? '').trim();
    if (token.isNotEmpty) req.headers['Authorization'] = 'Bearer $token';
    req.files.add(await http.MultipartFile.fromPath('file', p));
    final streamed = await req.send();
    final res = await http.Response.fromStream(streamed);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception(_errMsg(res).isEmpty ? 'Upload ảnh thất bại.' : _errMsg(res));
    }
    final body = jsonDecode(res.body);
    if (body is! Map) throw Exception('Phản hồi upload không hợp lệ.');
    final url = (body['imageUrl'] ?? body['ImageUrl'] ?? '').toString();
    if (url.trim().isEmpty) throw Exception('Upload ảnh thất bại.');
    return url;
  }

  Future<List<AdminLowStockProduct>> getAdminLowStock({int threshold = 10, int take = 12}) async {
    final res = await _client.get(
      _u('/Admin/low-stock').replace(queryParameters: {'threshold': '$threshold', 'take': '$take'}),
      headers: _authHeaders(),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) return const <AdminLowStockProduct>[];
    final body = jsonDecode(res.body);
    if (body is! List) return const <AdminLowStockProduct>[];
    final out = <AdminLowStockProduct>[];
    for (final item in body) {
      if (item is Map) out.add(AdminLowStockProduct.fromJson(Map<String, dynamic>.from(item)));
    }
    return out;
  }

  Future<List<AdminRecentImport>> getAdminRecentImports({int take = 6}) async {
    final res = await _client.get(
      _u('/Admin/inventory/recent-imports').replace(queryParameters: {'take': '$take'}),
      headers: _authHeaders(),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) return const <AdminRecentImport>[];
    final body = jsonDecode(res.body);
    if (body is! List) return const <AdminRecentImport>[];
    final out = <AdminRecentImport>[];
    for (final item in body) {
      if (item is Map) out.add(AdminRecentImport.fromJson(Map<String, dynamic>.from(item)));
    }
    return out;
  }

  Future<int> adminImportStock({required int productId, required int quantity, String? note}) async {
    final res = await _client.post(
      _u('/Admin/Products/$productId/stock/import'),
      headers: _authHeaders(json: true),
      body: jsonEncode({'quantity': quantity, 'note': (note ?? '').trim().isEmpty ? null : note!.trim()}),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception(_errMsg(res).isEmpty ? 'Nhập kho thất bại.' : _errMsg(res));
    }
    final m = await _decodeJson(res);
    final stockRaw = m['stockQuantity'] ?? m['StockQuantity'];
    if (stockRaw is num) return stockRaw.toInt();
    return int.tryParse('$stockRaw') ?? 0;
  }

  Future<AdminSuppliersPage> getAdminSuppliersPage({
    int page = 1,
    int pageSize = 10,
    String tab = 'all', // all | pending | paused
    String? q,
  }) async {
    final params = <String, String>{
      'page': '${page < 1 ? 1 : page}',
      'pageSize': '${pageSize < 1 ? 10 : pageSize}',
      'tab': tab,
      if ((q ?? '').trim().isNotEmpty) 'q': q!.trim(),
    };
    final res = await _client.get(
      _u('/Admin/Suppliers').replace(queryParameters: params),
      headers: _authHeaders(),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception(_errMsg(res).isEmpty ? 'Không tải được nhà cung cấp.' : _errMsg(res));
    }
    final m = await _decodeJson(res);
    return AdminSuppliersPage.fromJson(m);
  }

  Future<AdminSupplierRow> adminCreateSupplier(AdminSupplierUpsert input) async {
    final res = await _client.post(
      _u('/Admin/Suppliers'),
      headers: _authHeaders(json: true),
      body: jsonEncode(input.toJson()),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception(_errMsg(res).isEmpty ? 'Tạo nhà cung cấp thất bại.' : _errMsg(res));
    }
    final m = await _decodeJson(res);
    return AdminSupplierRow.fromJson(m);
  }

  Future<AdminSupplierRow> adminUpdateSupplier({required int supplierId, required AdminSupplierUpsert input}) async {
    final res = await _client.put(
      _u('/Admin/Suppliers/$supplierId'),
      headers: _authHeaders(json: true),
      body: jsonEncode(input.toJson()),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception(_errMsg(res).isEmpty ? 'Cập nhật nhà cung cấp thất bại.' : _errMsg(res));
    }
    final m = await _decodeJson(res);
    return AdminSupplierRow.fromJson(m);
  }

  Future<void> adminDeleteSupplier(int supplierId) async {
    final res = await _client.delete(_u('/Admin/Suppliers/$supplierId'), headers: _authHeaders());
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception(_errMsg(res).isEmpty ? 'Xóa nhà cung cấp thất bại.' : _errMsg(res));
    }
  }

  Future<String> adminUploadSupplierImage(String filePath) async {
    final p = filePath.trim();
    if (p.isEmpty) throw Exception('File ảnh không hợp lệ.');
    final uri = Uri.parse('${ApiConfig.apiBaseUrl}/Admin/Suppliers/UploadImage');
    final req = http.MultipartRequest('POST', uri);
    final token = (AuthState.token.value ?? '').trim();
    if (token.isNotEmpty) req.headers['Authorization'] = 'Bearer $token';
    final ext = p.split('.').last.toLowerCase();
    MediaType? contentType;
    if (ext == 'png') {
      contentType = MediaType('image', 'png');
    } else if (ext == 'jpg' || ext == 'jpeg' || ext == 'jfif') {
      contentType = MediaType('image', 'jpeg');
    } else if (ext == 'gif') {
      contentType = MediaType('image', 'gif');
    } else if (ext == 'webp') {
      contentType = MediaType('image', 'webp');
    }

    req.files.add(await http.MultipartFile.fromPath('file', p, contentType: contentType));
    final streamed = await req.send();
    final res = await http.Response.fromStream(streamed);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception(_errMsg(res).isEmpty ? 'Upload ảnh thất bại.' : _errMsg(res));
    }
    final body = jsonDecode(res.body);
    if (body is! Map) throw Exception('Phản hồi upload không hợp lệ.');
    final url = (body['imageUrl'] ?? body['ImageUrl'] ?? '').toString();
    if (url.trim().isEmpty) throw Exception('Upload ảnh thất bại.');
    return url;
  }

  Future<List<Category>> getAdminCategories() async {
    final res = await _client.get(_u('/Admin/Categories'), headers: _authHeaders());
    if (res.statusCode < 200 || res.statusCode >= 300) return const <Category>[];
    final body = jsonDecode(res.body);
    if (body is! List) return const <Category>[];
    final out = <Category>[];
    for (final e in body) {
      if (e is Map) out.add(Category.fromJson(Map<String, dynamic>.from(e)));
    }
    return out;
  }

  Future<Category> adminCreateCategory({required String categoryName, String? description}) async {
    final res = await _client.post(
      _u('/Admin/Categories'),
      headers: _authHeaders(json: true),
      body: jsonEncode({'categoryName': categoryName.trim(), 'description': (description ?? '').trim()}),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception(_errMsg(res).isEmpty ? 'Tạo danh mục thất bại.' : _errMsg(res));
    }
    final m = await _decodeJson(res);
    return Category.fromJson(m);
  }

  Future<Category> adminUpdateCategory({required int categoryId, required String categoryName, String? description}) async {
    final res = await _client.put(
      _u('/Admin/Categories/$categoryId'),
      headers: _authHeaders(json: true),
      body: jsonEncode({'categoryID': categoryId, 'categoryName': categoryName.trim(), 'description': (description ?? '').trim()}),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception(_errMsg(res).isEmpty ? 'Cập nhật danh mục thất bại.' : _errMsg(res));
    }
    final m = await _decodeJson(res);
    return Category.fromJson(m);
  }

  Future<void> adminDeleteCategory(int categoryId) async {
    final res = await _client.delete(_u('/Admin/Categories/$categoryId'), headers: _authHeaders());
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception(_errMsg(res).isEmpty ? 'Xóa danh mục thất bại.' : _errMsg(res));
    }
  }

  Future<AdminProductsPage> getAdminProductsPage({
    int page = 1,
    int pageSize = 10,
    String? q,
    int? categoryId,
    String status = 'all', // all | Active | Inactive
  }) async {
    final params = <String, String>{
      'page': '${page < 1 ? 1 : page}',
      'pageSize': '${pageSize < 1 ? 10 : pageSize}',
      if ((q ?? '').trim().isNotEmpty) 'q': q!.trim(),
      if ((categoryId ?? 0) > 0) 'categoryId': '$categoryId',
      if (status.trim().isNotEmpty && status.trim().toLowerCase() != 'all') 'status': status.trim(),
    };
    final res = await _client.get(
      _u('/Admin/Products').replace(queryParameters: params),
      headers: _authHeaders(),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception(_errMsg(res).isEmpty ? 'Không tải được danh sách sản phẩm.' : _errMsg(res));
    }
    final m = await _decodeJson(res);
    return AdminProductsPage.fromJson(m);
  }

  Future<void> adminDeleteProduct(int productId) async {
    final res = await _client.delete(_u('/Products/$productId'), headers: _authHeaders());
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception(_errMsg(res).isEmpty ? 'Xóa sản phẩm thất bại.' : _errMsg(res));
    }
  }

  Future<AdminOrdersPage> getAdminOrdersPage({
    int page = 1,
    int pageSize = 8,
    String status = 'all', // all | Pending | Processing | ...
    String? q,
  }) async {
    final params = <String, String>{
      'page': '${page < 1 ? 1 : page}',
      'pageSize': '${pageSize < 1 ? 8 : pageSize}',
      if ((q ?? '').trim().isNotEmpty) 'q': q!.trim(),
      if (status.trim().isNotEmpty && status.trim().toLowerCase() != 'all') 'status': status.trim(),
    };
    final res = await _client.get(
      _u('/Admin/Orders').replace(queryParameters: params),
      headers: _authHeaders(),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception(_errMsg(res).isEmpty ? 'Không tải được đơn hàng.' : _errMsg(res));
    }
    final m = await _decodeJson(res);
    return AdminOrdersPage.fromJson(m);
  }

  Future<AdminOrderDetail?> getAdminOrderDetail(int orderId) async {
    final res = await _client.get(_u('/Admin/Orders/$orderId'), headers: _authHeaders());
    if (res.statusCode < 200 || res.statusCode >= 300) return null;
    final body = jsonDecode(res.body);
    if (body is! Map) return null;
    return AdminOrderDetail.fromJson(Map<String, dynamic>.from(body));
  }

  Future<AdminOrderDetail?> getAdminOrderDetailByToken(String token) async {
    final t = token.trim();
    if (t.isEmpty) return null;
    final res = await _client.get(_u('/Admin/Orders/token/${Uri.encodeComponent(t)}'), headers: _authHeaders());
    if (res.statusCode < 200 || res.statusCode >= 300) return null;
    final body = jsonDecode(res.body);
    if (body is! Map) return null;
    return AdminOrderDetail.fromJson(Map<String, dynamic>.from(body));
  }

  Future<void> adminUpdateOrderStatus({required int orderId, required String status}) async {
    final s = status.trim();
    final res = await _client.put(
      _u('/Admin/Orders/$orderId/status'),
      headers: _authHeaders(json: true),
      body: jsonEncode({'status': s}),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception(_errMsg(res).isEmpty ? 'Cập nhật trạng thái thất bại.' : _errMsg(res));
    }
  }

  Future<void> adminCancelOrder({required int orderId, String? reason}) async {
    final res = await _client.post(
      _u('/Admin/Orders/$orderId/cancel'),
      headers: _authHeaders(json: true),
      body: jsonEncode({'reason': (reason ?? '').trim().isEmpty ? null : reason!.trim()}),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception(_errMsg(res).isEmpty ? 'Hủy đơn thất bại.' : _errMsg(res));
    }
  }

  Future<void> adminUpdateShipmentDetails({required int shipmentId, String? trackingNumber, String? carrier}) async {
    final res = await _client.put(
      _u('/Admin/Shipments/$shipmentId/details'),
      headers: _authHeaders(json: true),
      body: jsonEncode({
        'trackingNumber': (trackingNumber ?? '').trim().isEmpty ? null : trackingNumber!.trim(),
        'carrier': (carrier ?? '').trim().isEmpty ? null : carrier!.trim(),
      }),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception(_errMsg(res).isEmpty ? 'Cập nhật vận đơn thất bại.' : _errMsg(res));
    }
  }

  Future<AdminProductDetail?> getAdminProduct(int productId) async {
    final res = await _client.get(_u('/Admin/Products/$productId'), headers: _authHeaders());
    if (res.statusCode < 200 || res.statusCode >= 300) return null;
    final body = jsonDecode(res.body);
    if (body is! Map) return null;
    return AdminProductDetail.fromJson(Map<String, dynamic>.from(body));
  }

  Future<AdminProductDetail?> getAdminProductByToken(String token) async {
    final t = token.trim();
    if (t.isEmpty) return null;
    final res = await _client.get(_u('/Admin/Products/token/${Uri.encodeComponent(t)}'), headers: _authHeaders());
    if (res.statusCode < 200 || res.statusCode >= 300) return null;
    final body = jsonDecode(res.body);
    if (body is! Map) return null;
    return AdminProductDetail.fromJson(Map<String, dynamic>.from(body));
  }

  Future<AdminProductDetail> adminCreateProduct({
    required String productName,
    int? categoryId,
    int? supplierId,
    required String status, // Active | Inactive
    required num price,
    num? discountPrice,
    required int stockQuantity,
    required String unit,
    String? description,
    String? manufacturedDate, // yyyy-MM-dd
    String? expiryDate, // yyyy-MM-dd
    String? origin,
    String? storageInstructions,
    String? certifications,
  }) async {
    final res = await _client.post(
      _u('/Admin/Products'),
      headers: _authHeaders(json: true),
      body: jsonEncode({
        'productName': productName.trim(),
        'categoryID': categoryId,
        'supplierID': supplierId,
        'status': status.trim(),
        'price': price,
        'discountPrice': discountPrice,
        'stockQuantity': stockQuantity,
        'unit': unit.trim(),
        'description': (description ?? '').trim(),
        'manufacturedDate': (manufacturedDate ?? '').trim().isEmpty ? null : manufacturedDate,
        'expiryDate': (expiryDate ?? '').trim().isEmpty ? null : expiryDate,
        'origin': (origin ?? '').trim(),
        'storageInstructions': (storageInstructions ?? '').trim(),
        'certifications': (certifications ?? '').trim(),
      }),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception(_errMsg(res).isEmpty ? 'Tạo sản phẩm thất bại.' : _errMsg(res));
    }
    final body = jsonDecode(res.body);
    if (body is! Map) throw Exception('Phản hồi tạo sản phẩm không hợp lệ.');
    return AdminProductDetail.fromJson(Map<String, dynamic>.from(body));
  }

  Future<AdminProductDetail> adminUpdateProduct(
    int productId, {
    required String productName,
    int? categoryId,
    int? supplierId,
    required String status, // Active | Inactive
    required num price,
    num? discountPrice,
    required int stockQuantity,
    required String unit,
    String? description,
    String? manufacturedDate, // yyyy-MM-dd
    String? expiryDate, // yyyy-MM-dd
    String? origin,
    String? storageInstructions,
    String? certifications,
  }) async {
    final res = await _client.put(
      _u('/Admin/Products/$productId'),
      headers: _authHeaders(json: true),
      body: jsonEncode({
        'productID': productId,
        'productName': productName.trim(),
        'categoryID': categoryId,
        'supplierID': supplierId,
        'status': status.trim(),
        'price': price,
        'discountPrice': discountPrice,
        'stockQuantity': stockQuantity,
        'unit': unit.trim(),
        'description': (description ?? '').trim(),
        'manufacturedDate': (manufacturedDate ?? '').trim().isEmpty ? null : manufacturedDate,
        'expiryDate': (expiryDate ?? '').trim().isEmpty ? null : expiryDate,
        'origin': (origin ?? '').trim(),
        'storageInstructions': (storageInstructions ?? '').trim(),
        'certifications': (certifications ?? '').trim(),
      }),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception(_errMsg(res).isEmpty ? 'Cập nhật sản phẩm thất bại.' : _errMsg(res));
    }
    final body = jsonDecode(res.body);
    if (body is! Map) throw Exception('Phản hồi cập nhật sản phẩm không hợp lệ.');
    return AdminProductDetail.fromJson(Map<String, dynamic>.from(body));
  }

  Future<List<AdminProductImage>> adminUploadProductImages({
    required int productId,
    required List<String> filePaths,
    int? mainIndex,
  }) async {
    if (filePaths.isEmpty) return const <AdminProductImage>[];
    final uri = _u('/Admin/Products/$productId/Images').replace(
      queryParameters: (mainIndex == null) ? null : <String, String>{'mainIndex': '$mainIndex'},
    );
    final req = http.MultipartRequest('POST', uri);
    req.headers.addAll(_authHeaders());

    for (final p in filePaths) {
      final ext = p.split('.').last.toLowerCase();
      MediaType? contentType;
      if (ext == 'png') {
        contentType = MediaType('image', 'png');
      } else if (ext == 'webp') {
        contentType = MediaType('image', 'webp');
      } else if (ext == 'gif') {
        contentType = MediaType('image', 'gif');
      } else {
        contentType = MediaType('image', 'jpeg');
      }
      req.files.add(await http.MultipartFile.fromPath('files', p, contentType: contentType));
    }

    if (mainIndex != null) {
      req.fields['mainIndex'] = '$mainIndex';
    }

    final streamed = await req.send();
    final res = await http.Response.fromStream(streamed);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception(_errMsg(res).isEmpty ? 'Upload ảnh sản phẩm thất bại.' : _errMsg(res));
    }
    final body = jsonDecode(res.body);
    if (body is! List) return const <AdminProductImage>[];
    final out = <AdminProductImage>[];
    for (final e in body) {
      if (e is Map) out.add(AdminProductImage.fromJson(Map<String, dynamic>.from(e)));
    }
    return out;
  }

  Future<void> adminSetMainProductImage({required int productId, required int imageId}) async {
    final res = await _client.put(_u('/Admin/Products/$productId/Images/$imageId/Main'), headers: _authHeaders());
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception(_errMsg(res).isEmpty ? 'Không đặt được ảnh chính.' : _errMsg(res));
    }
  }

  Future<void> adminDeleteProductImage({required int productId, required int imageId}) async {
    final res = await _client.delete(_u('/Admin/Products/$productId/Images/$imageId'), headers: _authHeaders());
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception(_errMsg(res).isEmpty ? 'Không xóa được ảnh.' : _errMsg(res));
    }
  }

  Future<List<Product>> getProducts({int? categoryId, String? searchTerm}) async {
    final params = <String, String>{};
    if (categoryId != null) params['categoryID'] = '$categoryId';
    if (searchTerm != null && searchTerm.trim().isNotEmpty) params['searchTerm'] = searchTerm.trim();

    final normalizedSearch = (searchTerm ?? '').trim();
    final allowCache = normalizedSearch.isEmpty;
    final cacheKey = allowCache ? 'products:cat=${categoryId ?? 0}' : null;
    if (allowCache && cacheKey != null) {
      final cached = _cacheGet<List<Product>>(cacheKey);
      if (cached != null) return cached;
    }

    final uri = _u('/Products').replace(queryParameters: params.isEmpty ? null : params);
    final res = await _client.get(uri);
    if (res.statusCode < 200 || res.statusCode >= 300) return const [];
    final body = jsonDecode(res.body);
    if (body is! List) return const [];
    final out = <Product>[];
    for (final item in body) {
      if (item is Map) {
        out.add(Product.fromJson(Map<String, dynamic>.from(item)));
      }
    }
    if (allowCache && cacheKey != null) {
      _cacheSet(cacheKey, out, ttl: const Duration(minutes: 2));
    }
    return out;
  }

  Future<ProductsMetaResult> getProductsMeta() async {
    final res = await _client.get(_u('/Products/Meta'));
    if (res.statusCode < 200 || res.statusCode >= 300) {
      return const ProductsMetaResult(totalCount: 0, categoryCounts: <int, int>{}, maxEffectivePrice: 0);
    }
    final body = jsonDecode(res.body);
    if (body is! Map) {
      return const ProductsMetaResult(totalCount: 0, categoryCounts: <int, int>{}, maxEffectivePrice: 0);
    }
    final m = Map<String, dynamic>.from(body);
    final totalRaw = m['totalCount'] ?? m['TotalCount'] ?? 0;
    final totalCount = totalRaw is num ? totalRaw.toInt() : int.tryParse('$totalRaw') ?? 0;

    final maxRaw = m['maxEffectivePrice'] ?? m['MaxEffectivePrice'] ?? 0;
    final maxEffectivePrice = maxRaw is num ? maxRaw.toDouble() : double.tryParse('$maxRaw') ?? 0;

    final countsRaw = m['categoryCounts'] ?? m['CategoryCounts'] ?? const [];
    final counts = <int, int>{};
    if (countsRaw is List) {
      for (final e in countsRaw) {
        if (e is! Map) continue;
        final em = Map<String, dynamic>.from(e);
        final idRaw = em['categoryID'] ?? em['CategoryID'] ?? em['categoryId'] ?? em['CategoryId'] ?? 0;
        final cRaw = em['count'] ?? em['Count'] ?? 0;
        final id = idRaw is num ? idRaw.toInt() : int.tryParse('$idRaw') ?? 0;
        final c = cRaw is num ? cRaw.toInt() : int.tryParse('$cRaw') ?? 0;
        if (id > 0) counts[id] = c;
      }
    }

    return ProductsMetaResult(totalCount: totalCount, categoryCounts: counts, maxEffectivePrice: maxEffectivePrice);
  }

  Future<ProductsPagedResult> getProductsPaged({
    int? categoryId,
    String? searchTerm,
    num? minPrice,
    num? maxPrice,
    String? sort,
    required int page,
    required int pageSize,
    bool? organic,
    bool? local,
    bool? certAny,
  }) async {
    final params = <String, String>{
      'page': '${page < 1 ? 1 : page}',
      'pageSize': '${pageSize < 1 ? 18 : pageSize}',
      if (categoryId != null) 'categoryID': '$categoryId',
      if ((searchTerm ?? '').trim().isNotEmpty) 'searchTerm': searchTerm!.trim(),
      if (minPrice != null) 'minPrice': '$minPrice',
      if (maxPrice != null) 'maxPrice': '$maxPrice',
      if ((sort ?? '').trim().isNotEmpty) 'sort': sort!.trim(),
      if (organic != null) 'organic': '$organic',
      if (local != null) 'local': '$local',
      if (certAny != null) 'certAny': '$certAny',
    };

    final res = await _client.get(_u('/Products/Paged').replace(queryParameters: params));
    if (res.statusCode < 200 || res.statusCode >= 300) {
      return const ProductsPagedResult(items: <Product>[], totalCount: 0);
    }
    final body = jsonDecode(res.body);
    if (body is! Map) return const ProductsPagedResult(items: <Product>[], totalCount: 0);
    final m = Map<String, dynamic>.from(body);
    final totalRaw = m['totalCount'] ?? m['TotalCount'] ?? 0;
    final totalCount = totalRaw is num ? totalRaw.toInt() : int.tryParse('$totalRaw') ?? 0;

    final itemsRaw = m['items'] ?? m['Items'] ?? const [];
    if (itemsRaw is! List) return ProductsPagedResult(items: const <Product>[], totalCount: totalCount);
    final items = <Product>[];
    for (final e in itemsRaw) {
      if (e is Map) items.add(Product.fromJson(Map<String, dynamic>.from(e)));
    }
    return ProductsPagedResult(items: items, totalCount: totalCount);
  }

  /// Tra cứu vận đơn công khai: mã đơn + SĐT đặt hàng (khớp SĐT tài khoản đặt hàng).
  /// GET: /api/Orders/track?orderCode=...&phone=...
  Future<PublicOrderTrack?> trackOrder({required String orderCode, required String phone}) async {
    final code = orderCode.trim();
    final p = phone.trim();
    if (code.isEmpty || p.isEmpty) return null;

    final uri = _u('/Orders/track').replace(queryParameters: {'orderCode': code, 'phone': p});
    final res = await _client.get(uri);
    if (res.statusCode == 404) return null;
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception(_errMsg(res).isEmpty ? 'Tra cứu thất bại.' : _errMsg(res));
    }
    final body = jsonDecode(res.body);
    if (body is! Map) return null;
    return PublicOrderTrack.fromJson(Map<String, dynamic>.from(body));
  }

  Future<List<Product>> getPromotions() async {
    final cached = _cacheGet<List<Product>>('products:promotions');
    if (cached != null) return cached;
    final res = await _client.get(_u('/Products/Promotions'));
    if (res.statusCode < 200 || res.statusCode >= 300) return const [];
    final body = jsonDecode(res.body);
    if (body is! List) return const [];
    final out = <Product>[];
    for (final item in body) {
      if (item is Map) out.add(Product.fromJson(Map<String, dynamic>.from(item)));
    }
    _cacheSet('products:promotions', out, ttl: const Duration(minutes: 2));
    return out;
  }

  static void clearMemCache() => _memCache.clear();

  Future<List<BlogPostListItem>> getBlogPosts({String? q}) async {
    final qs = (q == null || q.trim().isEmpty) ? '' : '?q=${Uri.encodeQueryComponent(q.trim())}';
    final res = await _client.get(_u('/BlogPosts$qs'));
    if (res.statusCode < 200 || res.statusCode >= 300) return const [];
    final body = jsonDecode(res.body);
    if (body is! List) return const [];
    final out = <BlogPostListItem>[];
    for (final item in body) {
      if (item is Map) out.add(BlogPostListItem.fromJson(Map<String, dynamic>.from(item)));
    }
    return out;
  }

  Future<BlogPostDetail?> getBlogPostBySlug(String slug) async {
    final s = slug.trim();
    if (s.isEmpty) return null;
    final res = await _client.get(_u('/BlogPosts/${Uri.encodeComponent(s)}'));
    if (res.statusCode < 200 || res.statusCode >= 300) return null;
    final body = jsonDecode(res.body);
    if (body is! Map) return null;
    return BlogPostDetail.fromJson(Map<String, dynamic>.from(body));
  }

  Future<List<BlogComment>> getBlogCommentsBySlug(String slug) async {
    final s = slug.trim();
    if (s.isEmpty) return const [];
    final res = await _client.get(_u('/BlogPosts/${Uri.encodeComponent(s)}/Comments'));
    if (res.statusCode < 200 || res.statusCode >= 300) return const [];
    final body = jsonDecode(res.body);
    if (body is! List) return const [];
    final out = <BlogComment>[];
    for (final item in body) {
      if (item is Map) out.add(BlogComment.fromJson(Map<String, dynamic>.from(item)));
    }
    return out;
  }

  Future<BlogComment> createBlogComment({
    required String slug,
    required int userId,
    required String content,
    int? parentCommentId,
  }) async {
    final s = slug.trim();
    if (s.isEmpty) throw Exception('Slug không hợp lệ.');
    final res = await _client.post(
      _u('/BlogPosts/${Uri.encodeComponent(s)}/Comments'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'userID': userId,
        'content': content,
        'parentCommentID': parentCommentId,
      }),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception(_errMsg(res).isEmpty ? 'Gửi bình luận thất bại.' : _errMsg(res));
    }
    final body = jsonDecode(res.body);
    if (body is! Map) throw Exception('Dữ liệu bình luận không hợp lệ.');
    return BlogComment.fromJson(Map<String, dynamic>.from(body));
  }

  Future<int> submitContactMessage({
    required String name,
    required String email,
    required String subject,
    required String message,
  }) async {
    final res = await _client.post(
      _u('/ContactMessages'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'name': name, 'email': email, 'subject': subject, 'message': message}),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception(_errMsg(res).isEmpty ? 'Gửi liên hệ thất bại.' : _errMsg(res));
    }
    final body = jsonDecode(res.body);
    if (body is Map) {
      final m = Map<String, dynamic>.from(body);
      final idRaw = m['contactMessageID'] ?? m['ContactMessageID'] ?? m['contactMessageId'];
      final id = idRaw is num ? idRaw.toInt() : int.tryParse('$idRaw') ?? 0;
      return id;
    }
    return 0;
  }

  Future<List<Voucher>> getActiveVouchers({int? userId}) async {
    final cacheKey = 'vouchers:active:user=${userId ?? 0}';
    final cached = _cacheGet<List<Voucher>>(cacheKey);
    if (cached != null) return cached;
    final uri = userId == null
        ? _u('/Vouchers/active')
        : _u('/Vouchers/active').replace(queryParameters: {'userId': '$userId'});
    final res = await _client.get(uri);
    if (res.statusCode < 200 || res.statusCode >= 300) return const [];
    final body = jsonDecode(res.body);
    if (body is! List) return const [];
    final out = <Voucher>[];
    for (final item in body) {
      if (item is Map) out.add(Voucher.fromJson(Map<String, dynamic>.from(item)));
    }
    _cacheSet(cacheKey, out, ttl: const Duration(minutes: 2));
    return out;
  }

  Future<List<ShippingMethod>> getShippingMethods() async {
    final cached = _cacheGet<List<ShippingMethod>>('shipping_methods');
    if (cached != null) return cached;
    final res = await _client.get(_u('/ShippingMethods'));
    if (res.statusCode < 200 || res.statusCode >= 300) return const [];
    final body = jsonDecode(res.body);
    if (body is! List) return const [];
    final out = <ShippingMethod>[];
    for (final item in body) {
      if (item is Map) out.add(ShippingMethod.fromJson(Map<String, dynamic>.from(item)));
    }
    _cacheSet('shipping_methods', out, ttl: const Duration(minutes: 10));
    return out;
  }

  Future<ValidateVoucherResult> validateVoucher({
    required int userId,
    required String code,
    required num subtotal,
    required num shipping,
  }) async {
    final c = code.trim();
    if (userId <= 0) throw Exception('User không hợp lệ.');
    if (c.isEmpty) throw Exception('Vui lòng nhập mã giảm giá.');
    final tax = (subtotal * 0.015).round();
    final res = await _client.post(
      _u('/Vouchers/validate'),
      headers: _authHeaders(json: true),
      body: jsonEncode({
        'userID': userId,
        'code': c,
        'subtotal': subtotal,
        'shipping': shipping,
        'tax': tax,
      }),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception(_errMsg(res).isEmpty ? 'Mã giảm giá không hợp lệ.' : _errMsg(res));
    }
    final m = await _decodeJson(res);
    return ValidateVoucherResult.fromJson(m);
  }

  Future<OrderCreatedResult> createOrder({
    int? userId,
    GuestCheckoutDraft? guestCheckout,
    String? shippingAddress,
    int? shippingAddressId,
    int? shippingMethodId,
    required String paymentMethod, // COD | VNPAY | MOMO
    String? voucherCode,
    required List<OrderItemDraft> items,
    String? idempotencyKey,
  }) async {
    if ((userId ?? 0) <= 0 && guestCheckout == null) {
      throw Exception('Vui lòng đăng nhập hoặc nhập thông tin khách.');
    }
    if (items.isEmpty) throw Exception('Giỏ hàng trống.');

    final payload = <String, dynamic>{
      if ((userId ?? 0) > 0) 'userID': userId,
      if (guestCheckout != null) 'guestCheckout': guestCheckout.toJson(),
      'shippingAddress': (shippingAddress ?? '').trim(),
      if ((shippingAddressId ?? 0) > 0) 'shippingAddressId': shippingAddressId,
      if ((shippingMethodId ?? 0) > 0) 'shippingMethodID': shippingMethodId,
      'paymentMethod': paymentMethod.trim(),
      if (voucherCode != null && voucherCode.trim().isNotEmpty) 'voucherCode': voucherCode.trim(),
      'items': items.map((e) => e.toJson()).toList(growable: false),
    };

    final headers = _authHeaders(json: true);
    final key = (idempotencyKey ?? '').trim();
    if (key.isNotEmpty) headers['Idempotency-Key'] = key;

    final res = await _client.post(
      _u('/Orders'),
      headers: headers,
      body: jsonEncode(payload),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception(_errMsg(res).isEmpty ? 'Đặt hàng thất bại.' : _errMsg(res));
    }
    final m = await _decodeJson(res);
    return OrderCreatedResult.fromJson(m);
  }

  Future<String> createVnPayPaymentUrl({
    required int orderId,
    String? orderCode,
    String? bankCode,
    String? locale,
    String returnTo = 'app',
  }) async {
    final hasAuth = (AuthState.token.value ?? '').trim().isNotEmpty;
    final res = await _client.post(
      _u(hasAuth ? '/VnPay/CreatePaymentUrl' : '/VnPay/CreatePaymentUrlPublic'),
      headers: hasAuth ? _authHeaders(json: true) : {'Content-Type': 'application/json'},
      body: jsonEncode({
        if (hasAuth) 'orderID': orderId,
        if (!hasAuth) 'orderCode': (orderCode ?? '').trim(),
        'bankCode': bankCode,
        'locale': locale ?? 'vn',
        'returnTo': returnTo,
      }),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception(_errMsg(res).isEmpty ? 'Không tạo được link VNPay.' : _errMsg(res));
    }
    final m = await _decodeJson(res);
    final url = (m['paymentUrl'] ?? m['PaymentUrl'] ?? '').toString();
    if (url.trim().isEmpty) throw Exception('Link VNPay không hợp lệ.');
    return url;
  }

  Future<String> createMomoPaymentUrl({
    required int orderId,
    String? orderCode,
    String? payMethod, // wallet | atm | method
    String returnTo = 'app',
  }) async {
    final hasAuth = (AuthState.token.value ?? '').trim().isNotEmpty;
    final res = await _client.post(
      _u(hasAuth ? '/Momo/CreatePaymentUrl' : '/Momo/CreatePaymentUrlPublic'),
      headers: hasAuth ? _authHeaders(json: true) : {'Content-Type': 'application/json'},
      body: jsonEncode({
        if (hasAuth) 'orderID': orderId,
        if (!hasAuth) 'orderCode': (orderCode ?? '').trim(),
        'payMethod': payMethod,
        'returnTo': returnTo,
      }),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception(_errMsg(res).isEmpty ? 'Không tạo được link MoMo.' : _errMsg(res));
    }
    final m = await _decodeJson(res);
    final url = (m['paymentUrl'] ?? m['PaymentUrl'] ?? m['deeplink'] ?? m['Deeplink'] ?? '').toString();
    if (url.trim().isEmpty) throw Exception('Link MoMo không hợp lệ.');
    return url;
  }

  Future<List<RecentReview>> getRecentReviews({int take = 30}) async {
    final cacheKey = 'reviews:recent:take=$take';
    final cached = _cacheGet<List<RecentReview>>(cacheKey);
    if (cached != null) return cached;
    final uri = _u('/Reviews/Recent').replace(queryParameters: {'take': '$take'});
    final res = await _client.get(uri);
    if (res.statusCode < 200 || res.statusCode >= 300) return const [];
    final body = jsonDecode(res.body);
    if (body is! List) return const [];
    final out = <RecentReview>[];
    for (final item in body) {
      if (item is Map) out.add(RecentReview.fromJson(Map<String, dynamic>.from(item)));
    }
    _cacheSet(cacheKey, out, ttl: const Duration(minutes: 2));
    return out;
  }

  Future<ReviewSummary> getReviewSummary() async {
    final cached = _cacheGet<ReviewSummary>('reviews:summary');
    if (cached != null) return cached;
    final res = await _client.get(_u('/Reviews/Summary'));
    if (res.statusCode < 200 || res.statusCode >= 300) {
      return const ReviewSummary(averageRating: 0, totalReviews: 0);
    }
    final body = jsonDecode(res.body);
    if (body is! Map) return const ReviewSummary(averageRating: 0, totalReviews: 0);
    final v = ReviewSummary.fromJson(Map<String, dynamic>.from(body));
    _cacheSet('reviews:summary', v, ttl: const Duration(minutes: 5));
    return v;
  }

  Future<List<String>> uploadReviewImages(List<String> filePaths) async {
    final paths = filePaths.map((e) => e.trim()).where((e) => e.isNotEmpty).take(3).toList(growable: false);
    if (paths.isEmpty) return const <String>[];

    final uri = Uri.parse('${ApiConfig.apiBaseUrl}/Reviews/UploadImages');
    final req = http.MultipartRequest('POST', uri);
    for (final p in paths) {
      req.files.add(await http.MultipartFile.fromPath('files', p));
    }
    final streamed = await req.send();
    final res = await http.Response.fromStream(streamed);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception(_errMsg(res).isEmpty ? 'Upload ảnh đánh giá thất bại.' : _errMsg(res));
    }
    final body = jsonDecode(res.body);
    if (body is! List) return const <String>[];
    return body.map((x) => x.toString()).where((x) => x.trim().isNotEmpty).toList(growable: false);
  }

  Future<Map<String, dynamic>> createReview({
    required int productId,
    required int userId,
    required int rating,
    String? comment,
    List<String> imageUrls = const <String>[],
  }) async {
    if (productId <= 0) throw Exception('Sản phẩm không hợp lệ.');
    if (userId <= 0) throw Exception('User không hợp lệ.');
    final r = rating.clamp(1, 5);
    final res = await _client.post(
      _u('/Reviews'),
      headers: _authHeaders(json: true),
      body: jsonEncode({
        'productID': productId,
        'userID': userId,
        'rating': r,
        if ((comment ?? '').trim().isNotEmpty) 'comment': comment!.trim(),
        if (imageUrls.isNotEmpty) 'imageUrls': imageUrls,
      }),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception(_errMsg(res).isEmpty ? 'Gửi đánh giá thất bại.' : _errMsg(res));
    }
    return await _decodeJson(res);
  }

  Future<List<Order>> getUserOrders(int userId) async {
    final res = await _client.get(_u('/Orders/User/$userId'), headers: _authHeaders());
    if (res.statusCode < 200 || res.statusCode >= 300) return const <Order>[];
    final body = jsonDecode(res.body);
    if (body is! List) return const <Order>[];
    final out = <Order>[];
    for (final e in body) {
      if (e is Map) out.add(Order.fromJson(Map<String, dynamic>.from(e)));
    }
    return out;
  }

  Future<Order?> getOrder(int id) async {
    final res = await _client.get(_u('/Orders/$id'), headers: _authHeaders());
    if (res.statusCode < 200 || res.statusCode >= 300) return null;
    final body = jsonDecode(res.body);
    if (body is! Map) return null;
    return Order.fromJson(Map<String, dynamic>.from(body));
  }

  Future<Order?> getOrderByToken(String token) async {
    final t = token.trim();
    if (t.isEmpty) return null;
    final res = await _client.get(_u('/Orders/token/${Uri.encodeComponent(t)}'), headers: _authHeaders());
    if (res.statusCode < 200 || res.statusCode >= 300) return null;
    final body = jsonDecode(res.body);
    if (body is! Map) return null;
    return Order.fromJson(Map<String, dynamic>.from(body));
  }

  Future<Order?> cancelOrder({required int orderId, required int userId, String? reason}) async {
    final res = await _client.post(
      _u('/Orders/$orderId/cancel'),
      headers: _authHeaders(json: true),
      body: jsonEncode({'userID': userId, 'reason': reason}),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception(_errMsg(res).isEmpty ? 'Hủy đơn thất bại.' : _errMsg(res));
    }
    final body = jsonDecode(res.body);
    if (body is! Map) return null;
    return Order.fromJson(Map<String, dynamic>.from(body));
  }

  Future<Order?> confirmReceived({required int orderId, required int userId}) async {
    final res = await _client.post(
      _u('/Orders/$orderId/confirm-received'),
      headers: _authHeaders(json: true),
      body: jsonEncode({'userID': userId}),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception(_errMsg(res).isEmpty ? 'Xác nhận nhận hàng thất bại.' : _errMsg(res));
    }
    final body = jsonDecode(res.body);
    if (body is! Map) return null;
    return Order.fromJson(Map<String, dynamic>.from(body));
  }

  Future<Order?> confirmCodPaid({required int orderId}) async {
    final res = await _client.post(_u('/Orders/$orderId/confirm-cod-paid'));
    if (res.statusCode < 200 || res.statusCode >= 300) return null;
    final body = jsonDecode(res.body);
    if (body is! Map) return null;
    return Order.fromJson(Map<String, dynamic>.from(body));
  }

  Future<ReturnRequest?> getOrderReturnRequest({required int orderId, required int userId}) async {
    final uri = _u('/Orders/$orderId/return-request').replace(queryParameters: {'userId': '$userId'});
    final res = await _client.get(uri, headers: _authHeaders());
    if (res.statusCode < 200 || res.statusCode >= 300) return null;
    final body = jsonDecode(res.body);
    if (body == null) return null;
    if (body is! Map) return null;
    return ReturnRequest.fromJson(Map<String, dynamic>.from(body));
  }

  Future<int> createOrderReturnRequest({
    required int orderId,
    required int userId,
    required String reason,
    List<String> imageFilePaths = const <String>[],
    String? videoFilePath,
  }) async {
    final uri = _u('/Orders/$orderId/return-request');
    final req = http.MultipartRequest('POST', uri);
    req.headers.addAll(_authHeaders());
    req.fields['userId'] = '$userId';
    req.fields['reason'] = reason;

    MediaType? _contentTypeForPath(String path) {
      final p = path.trim().toLowerCase();
      String ext = '';
      final dot = p.lastIndexOf('.');
      if (dot >= 0) ext = p.substring(dot);
      switch (ext) {
        case '.jpg':
        case '.jpeg':
        case '.jfif':
          return MediaType('image', 'jpeg');
        case '.png':
          return MediaType('image', 'png');
        case '.webp':
          return MediaType('image', 'webp');
        case '.gif':
          return MediaType('image', 'gif');
        case '.mp4':
          return MediaType('video', 'mp4');
        case '.mov':
          return MediaType('video', 'quicktime');
        case '.webm':
          return MediaType('video', 'webm');
        case '.m4v':
          return MediaType('video', 'x-m4v');
      }
      return null;
    }

    final imgs = imageFilePaths.take(6);
    for (final p in imgs) {
      req.files.add(await http.MultipartFile.fromPath('files', p, contentType: _contentTypeForPath(p)));
    }
    if (videoFilePath != null && videoFilePath.trim().isNotEmpty) {
      final vp = videoFilePath.trim();
      req.files.add(await http.MultipartFile.fromPath('video', vp, contentType: _contentTypeForPath(vp)));
    }

    final streamed = await req.send();
    final res = await http.Response.fromStream(streamed);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      final raw = res.body.toString();
      // Backend often returns plain text for validation errors (e.g. "Only delivered orders can request return.")
      final msg = _errMsg(res);
      throw Exception((msg.trim().isNotEmpty ? msg : raw).trim().isNotEmpty ? (msg.trim().isNotEmpty ? msg : raw) : 'Không tạo được yêu cầu hoàn hàng.');
    }
    final m = await _decodeJson(res);
    final idRaw = m['returnRequestID'] ?? m['ReturnRequestID'] ?? m['id'];
    final id = idRaw is num ? idRaw.toInt() : int.tryParse('$idRaw') ?? 0;
    return id;
  }

  Future<List<int>> getWishlistIds(int userId) async {
    final res = await _client.get(_u('/Wishlists/Ids/$userId'), headers: _authHeaders());
    if (res.statusCode < 200 || res.statusCode >= 300) return const <int>[];
    final body = jsonDecode(res.body);
    if (body is! List) return const <int>[];
    final out = <int>[];
    for (final e in body) {
      if (e is num) out.add(e.toInt());
      else {
        final v = int.tryParse('$e');
        if (v != null) out.add(v);
      }
    }
    return out;
  }

  Future<List<Product>> getWishlistProducts(int userId) async {
    final res = await _client.get(_u('/Wishlists/User/$userId'), headers: _authHeaders());
    if (res.statusCode < 200 || res.statusCode >= 300) return const <Product>[];
    final body = jsonDecode(res.body);
    if (body is! List) return const <Product>[];
    final out = <Product>[];
    for (final item in body) {
      if (item is! Map) continue;
      final m = Map<String, dynamic>.from(item);
      final pRaw = m['product'] ?? m['Product'];
      if (pRaw is Map) {
        out.add(Product.fromJson(Map<String, dynamic>.from(pRaw)));
      } else {
        // Fallback: sometimes API may flatten product fields.
        out.add(Product.fromJson(m));
      }
    }
    return out;
  }

  Future<bool?> toggleWishlist({required int userId, required int productId}) async {
    final res = await _client.post(
      _u('/Wishlists/Toggle'),
      headers: _authHeaders(json: true),
      body: jsonEncode({'userID': userId, 'productID': productId}),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception(_errMsg(res).isEmpty ? 'Không cập nhật yêu thích.' : _errMsg(res));
    }
    final m = await _decodeJson(res);
    final wished = m['wished'] ?? m['Wished'];
    if (wished is bool) return wished;
    if (wished is num) return wished != 0;
    if (wished is String) return wished.trim() == 'true' || wished.trim() == '1';
    return null;
  }

  Future<Product?> getProductByTokenOrId(String tokenOrId) async {
    final t = tokenOrId.trim();
    if (t.isEmpty) return null;
    final isNumeric = int.tryParse(t) != null;
    final uri = isNumeric ? _u('/Products/${Uri.encodeComponent(t)}') : _u('/Products/token/${Uri.encodeComponent(t)}');
    final res = await _client.get(uri);
    if (res.statusCode < 200 || res.statusCode >= 300) return null;
    final body = jsonDecode(res.body);
    if (body is! Map) return null;
    return Product.fromJson(Map<String, dynamic>.from(body));
  }
}

class ProductsMetaResult {
  final int totalCount;
  final Map<int, int> categoryCounts;
  final double maxEffectivePrice;
  const ProductsMetaResult({required this.totalCount, required this.categoryCounts, required this.maxEffectivePrice});
}

class ProductsPagedResult {
  final List<Product> items;
  final int totalCount;
  const ProductsPagedResult({required this.items, required this.totalCount});
}

class _CacheEntry {
  final dynamic value;
  final DateTime expiresAt;
  const _CacheEntry({required this.value, required this.expiresAt});
}

class LoginResult {
  final AuthUser user;
  final String token;
  final int expiresInSeconds;
  const LoginResult({required this.user, required this.token, required this.expiresInSeconds});
}

class ValidateVoucherResult {
  final int voucherId;
  final String code;
  final num discountAmount;
  final num subtotalAfterDiscount;
  final num taxAfterDiscount;
  final num grandTotal;

  const ValidateVoucherResult({
    required this.voucherId,
    required this.code,
    required this.discountAmount,
    required this.subtotalAfterDiscount,
    required this.taxAfterDiscount,
    required this.grandTotal,
  });

  factory ValidateVoucherResult.fromJson(Map<String, dynamic> json) {
    final idRaw = json['voucherID'] ?? json['VoucherID'] ?? json['voucherId'];
    final id = idRaw is num ? idRaw.toInt() : int.tryParse('$idRaw') ?? 0;
    num _n(dynamic v) => v is num ? v : num.tryParse('$v') ?? 0;
    return ValidateVoucherResult(
      voucherId: id,
      code: (json['code'] ?? json['Code'] ?? '').toString(),
      discountAmount: _n(json['discountAmount'] ?? json['DiscountAmount']),
      subtotalAfterDiscount: _n(json['subtotalAfterDiscount'] ?? json['SubtotalAfterDiscount']),
      taxAfterDiscount: _n(json['taxAfterDiscount'] ?? json['TaxAfterDiscount']),
      grandTotal: _n(json['grandTotal'] ?? json['GrandTotal']),
    );
  }
}

class OrderItemDraft {
  final int productId;
  final int quantity;
  const OrderItemDraft({required this.productId, required this.quantity});
  Map<String, dynamic> toJson() => <String, dynamic>{'productID': productId, 'quantity': quantity};
}

class GuestCheckoutDraft {
  final String fullName;
  final String email;
  final String phone;
  const GuestCheckoutDraft({required this.fullName, required this.email, required this.phone});
  Map<String, dynamic> toJson() => <String, dynamic>{'fullName': fullName, 'email': email, 'phone': phone};
}

class OrderCreatedResult {
  final int orderId;
  final String? orderCode;
  final num? totalAmount;
  const OrderCreatedResult({required this.orderId, required this.orderCode, required this.totalAmount});

  factory OrderCreatedResult.fromJson(Map<String, dynamic> json) {
    final idRaw = json['orderID'] ?? json['OrderID'] ?? json['orderId'] ?? json['id'];
    final id = idRaw is num ? idRaw.toInt() : int.tryParse('$idRaw') ?? 0;
    num? _n(dynamic v) => v is num ? v : num.tryParse('$v');
    return OrderCreatedResult(
      orderId: id,
      orderCode: (json['orderCode'] ?? json['OrderCode'])?.toString(),
      totalAmount: _n(json['totalAmount'] ?? json['TotalAmount']),
    );
  }
}

