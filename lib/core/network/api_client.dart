import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
// hide Response/FormData/MultipartFile — dio owns these types here.
import 'package:get/get.dart' hide Response, FormData, MultipartFile;
import 'package:logger/logger.dart';

/// Mirrors the web frontend's 3-module consolidated backend topology.
///
///   platform (8080) — auth, settings, notification, approval
///   core     (8081) — employee, document, tracking, dashboard
///   payroll  (8082) — attendance, leave, payroll, compliance, report
class ApiClient {
  static const _storage = FlutterSecureStorage();
  static final _logger = Logger();

  static const String _apiHost = 'http://103.139.58.189';
  static const String _apiMode = 'port';

  static const _modulePorts = {'platform': 8090, 'core': 8091, 'payroll': 8092};

  static const _oldToNew = {
    'AUTH': 'platform',
    'SETTINGS': 'platform',
    'NOTIFICATION': 'platform',
    'APPROVAL': 'platform',
    'EMPLOYEE': 'core',
    'DOCUMENT': 'core',
    'TRACKING': 'core',
    'ATTENDANCE': 'payroll',
    'LEAVE': 'payroll',
    'PAYROLL': 'payroll',
    'COMPLIANCE': 'payroll',
    'REPORT': 'payroll',
  };

  static const _prefixTable = [
    ['/api/v1/auth', 'AUTH'],
    ['/api/v1/me/', 'SETTINGS'],
    ['/api/v1/payroll-runs', 'PAYROLL'],
    ['/api/v1/salary-structures', 'PAYROLL'],
    ['/api/v1/salary-revisions', 'PAYROLL'],
    ['/api/v1/employee-salaries', 'PAYROLL'],
    ['/api/v1/payslips', 'PAYROLL'],
    ['/api/v1/payroll', 'PAYROLL'],
    ['/api/v1/employee-shifts', 'ATTENDANCE'],
    ['/api/v1/shifts', 'ATTENDANCE'],
    ['/api/v1/attendance', 'ATTENDANCE'],
    ['/api/v1/employees', 'EMPLOYEE'],
    ['/api/v1/deployments', 'EMPLOYEE'],
    ['/api/v1/dashboard', 'EMPLOYEE'],
    ['/api/v1/leave-requests', 'LEAVE'],
    ['/api/v1/leave-balances', 'LEAVE'],
    ['/api/v1/leave-types', 'LEAVE'],
    ['/api/v1/public-holidays', 'LEAVE'],
    ['/api/v1/leave', 'LEAVE'],
    ['/api/v1/approvals', 'PAYROLL'],
    ['/api/v1/pf-contributions', 'COMPLIANCE'],
    ['/api/v1/pf-challans', 'COMPLIANCE'],
    ['/api/v1/esic-challans', 'COMPLIANCE'],
    ['/api/v1/challans', 'COMPLIANCE'],
    ['/api/v1/compliance', 'COMPLIANCE'],
    ['/api/v1/document-templates', 'DOCUMENT'],
    ['/api/v1/documents', 'DOCUMENT'],
    ['/api/v1/notification-templates', 'NOTIFICATION'],
    ['/api/v1/notifications', 'NOTIFICATION'],
    ['/api/v1/geofences', 'TRACKING'],
    ['/api/v1/tracking', 'TRACKING'],
    ['/api/v1/work-locations', 'SETTINGS'],
    ['/api/v1/departments', 'SETTINGS'],
    ['/api/v1/designations', 'SETTINGS'],
    ['/api/v1/tenant-features', 'SETTINGS'],
    ['/api/v1/tenants', 'SETTINGS'],
    ['/api/v1/users', 'SETTINGS'],
    ['/api/v1/access', 'SETTINGS'],
    ['/api/v1/branches', 'SETTINGS'],
    ['/api/v1/client-companies', 'SETTINGS'],
    ['/api/v1/menu', 'SETTINGS'],
    ['/api/v1/platform', 'SETTINGS'],
    ['/api/v1/admin', 'SETTINGS'],
    ['/api/v1/jobs', 'SETTINGS'],
    ['/api/v1/settings', 'SETTINGS'],
    ['/api/v1/reports', 'REPORT'],
  ];

  static late Dio _dio;

  static String _makeModuleUrl(String module) {
    final host = _apiHost.replaceAll(RegExp(r'/+$'), '');
    return _apiMode == 'path'
        ? '$host/svc/$module'
        : '$host:${_modulePorts[module]}';
  }

  static String _makeServiceUrl(String key) {
    final module = _oldToNew[key];
    if (module == null) throw Exception('Unknown service key: $key');
    return _makeModuleUrl(module);
  }

  static String? resolveServiceUrl(String? path) {
    if (path == null) return null;
    for (final e in _prefixTable) {
      if (path.startsWith(e[0])) return _makeServiceUrl(e[1]);
    }
    return null;
  }

  static String get authBaseUrl => _makeServiceUrl('AUTH');

  static void init() {
    _dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json'
      },
    ));
    _dio.interceptors.addAll([
      _ServiceRouterInterceptor(),
      _AuthInterceptor(),
      _LoggingInterceptor(_logger),
    ]);
  }

  static Dio get instance => _dio;

  // ── JWT Decode (mirrors web jwtUtils.js) ────────────────────────────────
  static Map<String, dynamic> decodeJwtPayload(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return {};
      String seg = parts[1].replaceAll('-', '+').replaceAll('_', '/');
      switch (seg.length % 4) {
        case 2:
          seg += '==';
          break;
        case 3:
          seg += '=';
          break;
      }
      return jsonDecode(utf8.decode(base64Decode(seg))) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }

  static String? getTenantIdFromToken(String? token) {
    if (token == null) return null;
    final p = decodeJwtPayload(token);
    return (p['tenantId'] ?? p['tenant_id'])?.toString();
  }

  static String? getBranchIdFromToken(String? token) {
    if (token == null) return null;
    final p = decodeJwtPayload(token);
    return (p['activeBranchId'] ?? p['branchId'] ?? p['branch_id'])?.toString();
  }

  static List<String> getRolesFromToken(String? token) {
    if (token == null) return [];
    final p = decodeJwtPayload(token);
    if (p['roles'] is List)
      return (p['roles'] as List).map((e) => e.toString()).toList();
    if (p['role'] is String) return [p['role']];
    return [];
  }

  static int? getEmployeeIdFromToken(String? token) {
    if (token == null) return null;
    final p = decodeJwtPayload(token);
    final v = p['employeeId'] ?? p['employee_id'];
    return v is int ? v : (v != null ? int.tryParse(v.toString()) : null);
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
class _ServiceRouterInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final base = ApiClient.resolveServiceUrl(options.path);
    if (base != null) options.baseUrl = base;
    handler.next(options);
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
class _AuthInterceptor extends Interceptor {
  static const _storage = FlutterSecureStorage();
  static const _publicPaths = [
    '/api/v1/auth/login',
    '/api/v1/auth/refresh',
    '/api/v1/auth/forgot-password',
    '/api/v1/auth/reset-password',
    '/api/v1/auth/validate-reset-token',
  ];
  static bool _isPublic(String? url) =>
      url != null && _publicPaths.any((p) => url.contains(p));

  bool _isRefreshing = false;
  final List<({RequestOptions options, ErrorInterceptorHandler handler})>
      _failedQueue = [];

  @override
  void onRequest(
      RequestOptions options, RequestInterceptorHandler handler) async {
    final token = await _storage.read(key: 'auth_token');
    if (token != null && !_isPublic(options.path)) {
      options.headers['Authorization'] = 'Bearer $token';
      // Prefer stored; fall back to JWT decode (same as web interceptor)
      final tenantId = await _storage.read(key: 'tenant_id') ??
          ApiClient.getTenantIdFromToken(token);
      options.headers['X-Tenant-ID'] = tenantId ?? '0';
      final branchId = await _storage.read(key: 'branch_id') ??
          ApiClient.getBranchIdFromToken(token);
      if (branchId != null) options.headers['X-Branch-ID'] = branchId;
    }
    if (options.data is FormData) options.headers.remove('Content-Type');
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode != 401 || _isPublic(err.requestOptions.path)) {
      handler.next(err);
      return;
    }
    if (_isRefreshing) {
      _failedQueue.add((options: err.requestOptions, handler: handler));
      return;
    }
    _isRefreshing = true;
    try {
      final refreshDio = Dio(BaseOptions(
          baseUrl: ApiClient.authBaseUrl,
          connectTimeout: const Duration(seconds: 15)));
      final res = await refreshDio.post('/api/v1/auth/refresh', data: {});
      final newToken = res.data?['data']?['accessToken'] as String?;
      if (newToken == null) throw Exception('No accessToken');
      await _storage.write(key: 'auth_token', value: newToken);
      // Retry original
      err.requestOptions.headers['Authorization'] = 'Bearer $newToken';
      final base = ApiClient.resolveServiceUrl(err.requestOptions.path);
      if (base != null) err.requestOptions.baseUrl = base;
      handler.resolve(await Dio().fetch(err.requestOptions));
      for (final q in _failedQueue) {
        q.options.headers['Authorization'] = 'Bearer $newToken';
        final qBase = ApiClient.resolveServiceUrl(q.options.path);
        if (qBase != null) q.options.baseUrl = qBase;
        try {
          q.handler.resolve(await Dio().fetch(q.options));
        } catch (e) {
          q.handler.reject(DioException(requestOptions: q.options, error: e));
        }
      }
    } catch (_) {
      // Refresh failed — session is dead. Wipe local state and force the user
      // back to the login screen exactly like AuthController.logout() does.
      // why: without this, a 401 leaves the user staring at a page whose data
      //      never arrives (calls silently fail), with no clear path back.
      await _storage.deleteAll();
      handler.next(err);
      for (final q in _failedQueue) q.handler.next(err);
      _redirectToLogin();
    } finally {
      _isRefreshing = false;
      _failedQueue.clear();
    }
  }

  // Only redirect once, and never redirect while the user is already on /login
  // (avoids fighting a fresh login attempt whose own 401 arrives seconds later).
  void _redirectToLogin() {
    try {
      final current = Get.currentRoute;
      if (current == '/login' || current == '/') return;
      Get.offAllNamed('/login');
    } catch (_) {
      // Get isn't ready (e.g. cold-start hydration) — safe to ignore; the
      // caller will land on /login on the next navigation attempt.
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
class _LoggingInterceptor extends Interceptor {
  final Logger _logger;
  _LoggingInterceptor(this._logger);
  @override
  void onRequest(RequestOptions o, RequestInterceptorHandler h) {
    _logger.d('→ ${o.method} ${o.baseUrl}${o.path}');
    h.next(o);
  }

  @override
  void onResponse(Response r, ResponseInterceptorHandler h) {
    _logger.d('← ${r.statusCode} ${r.requestOptions.path}');
    h.next(r);
  }

  @override
  void onError(DioException e, ErrorInterceptorHandler h) {
    _logger.e('✕ ${e.response?.statusCode} ${e.requestOptions.path}');
    h.next(e);
  }
}

// ── Shared models ─────────────────────────────────────────────────────────────
class ApiResponse<T> {
  final T? data;
  final String? message;
  final bool success;
  final int? totalRecords;
  final int? page;
  final int? totalPages;
  ApiResponse(
      {this.data,
      this.message,
      this.success = true,
      this.totalRecords,
      this.page,
      this.totalPages});
  factory ApiResponse.fromJson(
          Map<String, dynamic> json, T Function(dynamic) fromJson) =>
      ApiResponse<T>(
        data: json['data'] != null ? fromJson(json['data']) : null,
        message: json['message'],
        success: json['success'] ?? true,
        totalRecords: json['totalRecords'],
        page: json['page'],
        totalPages: json['totalPages'],
      );
}

class ApiFailure {
  final String message;
  final int? statusCode;
  const ApiFailure({required this.message, this.statusCode});
  factory ApiFailure.fromDioException(DioException e) {
    final d = e.response?.data;
    return ApiFailure(
        message: (d is Map ? d['message'] : null) ??
            e.message ??
            'Something went wrong',
        statusCode: e.response?.statusCode);
  }
}
