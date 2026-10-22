import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
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
    enableBrowserCredentials(_dio);
    _dio.interceptors.addAll([
      _ServiceRouterInterceptor(),
      _AuthInterceptor(),
      _LoggingInterceptor(_logger),
    ]);
  }

  /// The refresh token is an **HttpOnly cookie** issued by the Auth Service at
  /// login — the login response body never contains it (same as the web
  /// portal). On Flutter Web the browser will only send that cookie
  /// cross-origin when the XHR has `withCredentials`, so turn it on. Without
  /// this every /auth/refresh call arrives with no credential and fails,
  /// which forced a logout on the first 401 after the access token expired.
  ///
  /// Accessed dynamically so this file still compiles for Android/iOS, where
  /// the adapter has no `withCredentials` property.
  static void enableBrowserCredentials(Dio dio) {
    if (!kIsWeb) return;
    try {
      (dio.httpClientAdapter as dynamic).withCredentials = true;
    } catch (_) {
      // Adapter doesn't expose it — nothing to do.
    }
  }

  /// Re-arm the interceptor after a successful login. The session-expiry latch
  /// below is sticky by design, so it must be cleared when a new session
  /// starts or the very first 401 of that session would be swallowed.
  static void resetSessionExpiry() => _AuthInterceptor.resetSessionExpiry();

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

  /// Sticky latch — once a session expiry has been handled, every later 401 is
  /// dropped silently instead of triggering another wipe + redirect.
  ///
  /// why: when the access token expires the app usually has several requests
  /// in flight (dashboard summary, employee list, attendance, approvals…).
  /// Each one 401s. Without this latch each of those independently ran the
  /// refresh → fail → deleteAll → Get.offAllNamed('/login') path, so the user
  /// was bounced to the login screen several times in a row — the "app
  /// refreshing randomly" symptom. The web portal solves this exact problem
  /// with its `sessionExpiredHandled` flag; this mirrors it.
  static bool _sessionExpired = false;

  static void resetSessionExpiry() => _sessionExpired = false;

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
  void onResponse(Response response, ResponseInterceptorHandler handler) async {
    // Capture the refresh cookie on mobile. Browsers hide Set-Cookie from JS
    // (there the HttpOnly cookie is replayed automatically by
    // withCredentials), but on Android/iOS Dio has no cookie store at all, so
    // we persist it ourselves and replay it on /auth/refresh.
    if (!kIsWeb) {
      final cookies = response.headers.map['set-cookie'];
      if (cookies != null) {
        for (final c in cookies) {
          final m = RegExp(r'refreshToken=([^;]+)').firstMatch(c);
          if (m != null) {
            await _storage.write(key: 'refresh_token', value: m.group(1));
            break;
          }
        }
      }
    }
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final isAuthError = err.response?.statusCode == 401;
    if (!isAuthError || _isPublic(err.requestOptions.path)) {
      handler.next(err);
      return;
    }

    // Session already declared dead — swallow the rest of the 401 burst
    // instead of wiping storage and redirecting once per failed request.
    if (_sessionExpired) {
      handler.next(err);
      return;
    }

    // Never retry the same request twice (mirrors the web's `_retry` flag).
    if (err.requestOptions.extra['__retried'] == true) {
      await _expireSession();
      handler.next(err);
      return;
    }

    if (_isRefreshing) {
      _failedQueue.add((options: err.requestOptions, handler: handler));
      return;
    }

    _isRefreshing = true;
    // Guards against completing `handler` twice if anything after the retry
    // throws — a handler may only be resolved or rejected once.
    var resolved = false;
    try {
      final newToken = await _performRefresh();
      if (newToken == null || newToken.isEmpty) {
        throw Exception('Refresh did not return an access token');
      }
      await _storage.write(key: 'auth_token', value: newToken);

      // Retry the original request once, through the configured client so the
      // service-router and logging interceptors still apply.
      err.requestOptions.headers['Authorization'] = 'Bearer $newToken';
      err.requestOptions.extra['__retried'] = true;
      final retried = await ApiClient.instance.fetch(err.requestOptions);
      resolved = true;
      handler.resolve(retried);

      for (final q in _failedQueue) {
        q.options.headers['Authorization'] = 'Bearer $newToken';
        q.options.extra['__retried'] = true;
        try {
          q.handler.resolve(await ApiClient.instance.fetch(q.options));
        } catch (e) {
          q.handler.reject(e is DioException
              ? e
              : DioException(requestOptions: q.options, error: e));
        }
      }
    } catch (_) {
      // Refresh is not possible (expired / missing refresh cookie). Wipe the
      // session once and send the user to login — exactly once, thanks to the
      // latch set inside _expireSession().
      await _expireSession();
      if (!resolved) handler.next(err);
      for (final q in _failedQueue) {
        q.handler.next(err);
      }
    } finally {
      _isRefreshing = false;
      _failedQueue.clear();
    }
  }

  /// POST /api/v1/auth/refresh carrying whatever credential this platform has.
  /// Returns null when there is nothing to send, so the caller fails fast
  /// instead of burning a round-trip that can never succeed.
  Future<String?> _performRefresh() async {
    final stored = await _storage.read(key: 'refresh_token');

    // On web the browser replays the HttpOnly cookie itself (withCredentials),
    // so an empty store is fine. On mobile, no captured cookie means refresh
    // is impossible — don't call the endpoint at all.
    if (!kIsWeb && (stored == null || stored.isEmpty)) return null;

    final refreshDio = Dio(BaseOptions(
      baseUrl: ApiClient.authBaseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
    ));
    ApiClient.enableBrowserCredentials(refreshDio);

    // Forward the active branch so the re-issued token keeps the current
    // branch scope instead of resetting to the home branch (web parity).
    final branchId = await _storage.read(key: 'branch_id');

    final res = await refreshDio.post(
      '/api/v1/auth/refresh',
      data: const <String, dynamic>{},
      options: Options(headers: {
        if (!kIsWeb && stored != null) 'Cookie': 'refreshToken=$stored',
        if (branchId != null) 'X-Branch-ID': branchId,
      }),
    );
    return res.data?['data']?['accessToken'] as String?;
  }

  /// Idempotent "the session is over" handler: latch, clear storage, redirect
  /// once. Every later 401 short-circuits on the latch.
  Future<void> _expireSession() async {
    if (_sessionExpired) return;
    _sessionExpired = true;
    try {
      await _storage.deleteAll();
    } catch (_) {}
    _redirectToLogin();
  }

  // Never redirect while the user is already on /login.
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