import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:logger/logger.dart';

/// Mirrors the web frontend's 3-module consolidated backend topology:
///
///   platform (8080) — auth, settings, notification, approval
///   core     (8081) — employee, document, tracking, dashboard
///   payroll  (8082) — attendance, leave, payroll, compliance, report, approvals-history
///
/// URL resolution uses ordered prefix matching identical to
/// `src/config/apiConfig.js → PATH_PREFIX_TO_SERVICE`.
class ApiClient {
  static const _storage = FlutterSecureStorage();
  static final _logger = Logger();

  /// Change this to your server IP / domain.
  /// For local dev:  http://10.0.2.2  (Android emulator → host machine)
  /// For device on same Wi-Fi: http://<your-machine-ip>
  /// For production: https://hrms.auspreytech.com
  static const String _apiHost = 'http://103.139.58.189';

  /// URL composition mode: 'port' for dev, 'path' for nginx production.
  static const String _apiMode = 'port';

  // ── Module ports (port mode) / slug names (path mode) ───────────────────
  static const _modulePorts = {
    'platform': 8080,
    'core': 8081,
    'payroll': 8082,
  };

  // ── Old logical service → new module mapping (same as web OLD_TO_NEW) ───
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

  /// Ordered prefix → service key table. More-specific prefixes FIRST.
  /// Mirrors `PATH_PREFIX_TO_SERVICE` from the web `apiConfig.js`.
  static const _prefixTable = [
    // Auth → platform
    ['/api/v1/auth', 'AUTH'],
    ['/api/v1/me/', 'SETTINGS'],

    // Payroll → payroll module
    ['/api/v1/payroll-runs', 'PAYROLL'],
    ['/api/v1/salary-structures', 'PAYROLL'],
    ['/api/v1/salary-revisions', 'PAYROLL'],
    ['/api/v1/employee-salaries', 'PAYROLL'],
    ['/api/v1/payslips', 'PAYROLL'],
    ['/api/v1/payroll', 'PAYROLL'],

    // Attendance → payroll
    ['/api/v1/employee-shifts', 'ATTENDANCE'],
    ['/api/v1/shifts', 'ATTENDANCE'],
    ['/api/v1/attendance', 'ATTENDANCE'],

    // Employee → core
    ['/api/v1/employees', 'EMPLOYEE'],
    ['/api/v1/deployments', 'EMPLOYEE'],

    // Dashboard → core
    ['/api/v1/dashboard', 'EMPLOYEE'],

    // Leave → payroll
    ['/api/v1/leave-requests', 'LEAVE'],
    ['/api/v1/leave-balances', 'LEAVE'],
    ['/api/v1/leave-types', 'LEAVE'],
    ['/api/v1/public-holidays', 'LEAVE'],
    ['/api/v1/leave', 'LEAVE'],

    // Approvals history → payroll
    ['/api/v1/approvals', 'PAYROLL'],

    // Compliance → payroll
    ['/api/v1/pf-contributions', 'COMPLIANCE'],
    ['/api/v1/pf-challans', 'COMPLIANCE'],
    ['/api/v1/esic-challans', 'COMPLIANCE'],
    ['/api/v1/challans', 'COMPLIANCE'],
    ['/api/v1/compliance', 'COMPLIANCE'],

    // Document → core
    ['/api/v1/document-templates', 'DOCUMENT'],
    ['/api/v1/documents', 'DOCUMENT'],

    // Notification → platform
    ['/api/v1/notification-templates', 'NOTIFICATION'],
    ['/api/v1/notifications', 'NOTIFICATION'],

    // Tracking → core
    ['/api/v1/geofences', 'TRACKING'],
    ['/api/v1/tracking', 'TRACKING'],

    // Settings → platform
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

    // Report → payroll
    ['/api/v1/reports', 'REPORT'],
  ];

  static late Dio _dio;

  /// Build the full base URL for a module.
  static String _makeModuleUrl(String module) {
    final host = _apiHost.replaceAll(RegExp(r'/+$'), '');
    if (_apiMode == 'path') {
      return '$host/svc/$module';
    }
    return '$host:${_modulePorts[module]}';
  }

  /// Build the full base URL for an old service key.
  static String _makeServiceUrl(String serviceKey) {
    final module = _oldToNew[serviceKey];
    if (module == null) throw Exception('Unknown service key: $serviceKey');
    return _makeModuleUrl(module);
  }

  /// Resolve a request path to its module base URL (first-match-wins).
  static String? resolveServiceUrl(String? path) {
    if (path == null) return null;
    for (final entry in _prefixTable) {
      if (path.startsWith(entry[0])) {
        return _makeServiceUrl(entry[1]);
      }
    }
    return null;
  }

  /// Convenience: AUTH service URL for direct use (refresh, login).
  static String get authBaseUrl => _makeServiceUrl('AUTH');

  static void init() {
    _dio = Dio(
      BaseOptions(
        // baseURL is intentionally NOT set — resolved per-request.
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    _dio.interceptors.addAll([
      _ServiceRouterInterceptor(),
      _AuthInterceptor(),
      _LoggingInterceptor(_logger),
    ]);
  }

  static Dio get instance => _dio;
}

// ═══════════════════════════════════════════════════════════════════════════════
// SERVICE ROUTER — resolves baseURL per-request from the prefix table
// ═══════════════════════════════════════════════════════════════════════════════
class _ServiceRouterInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final serviceBase = ApiClient.resolveServiceUrl(options.path);
    if (serviceBase != null) {
      options.baseUrl = serviceBase;
    }
    handler.next(options);
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// AUTH INTERCEPTOR — attaches JWT + X-Tenant-ID, handles 401 refresh
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
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await _storage.read(key: 'auth_token');
    final tenantId = await _storage.read(key: 'tenant_id');
    final branchId = await _storage.read(key: 'branch_id');

    if (token != null && !_isPublic(options.path)) {
      options.headers['Authorization'] = 'Bearer $token';
    }

    if (token != null && !_isPublic(options.path)) {
      options.headers['X-Tenant-ID'] = tenantId ?? '0';
      if (branchId != null) {
        options.headers['X-Branch-ID'] = branchId;
      }
    }

    // Let browser/Dio set Content-Type for FormData (multipart)
    if (options.data is FormData) {
      options.headers.remove('Content-Type');
    }

    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode != 401) {
      handler.next(err);
      return;
    }

    final originalRequest = err.requestOptions;

    // Don't try to refresh if the refresh call itself failed
    if (_isPublic(originalRequest.path)) {
      handler.next(err);
      return;
    }

    if (_isRefreshing) {
      _failedQueue.add((options: originalRequest, handler: handler));
      return;
    }

    _isRefreshing = true;

    try {
      final refreshDio = Dio(BaseOptions(
        baseUrl: ApiClient.authBaseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
      ));

      final refreshToken = await _storage.read(key: 'refresh_token');
      final res = await refreshDio.post(
        '/api/v1/auth/refresh',
        data: {},
        options: Options(headers: {
          if (refreshToken != null) 'Cookie': 'refreshToken=$refreshToken',
        }),
      );

      final newToken = res.data?['data']?['accessToken'] as String?;
      if (newToken == null)
        throw Exception('No accessToken in refresh response');

      await _storage.write(key: 'auth_token', value: newToken);

      // Retry the original request
      originalRequest.headers['Authorization'] = 'Bearer $newToken';
      final serviceBase = ApiClient.resolveServiceUrl(originalRequest.path);
      if (serviceBase != null) originalRequest.baseUrl = serviceBase;

      final response = await Dio().fetch(originalRequest);
      handler.resolve(response);

      // Retry queued requests
      for (final queued in _failedQueue) {
        queued.options.headers['Authorization'] = 'Bearer $newToken';
        final qServiceBase = ApiClient.resolveServiceUrl(queued.options.path);
        if (qServiceBase != null) queued.options.baseUrl = qServiceBase;
        try {
          final r = await Dio().fetch(queued.options);
          queued.handler.resolve(r);
        } catch (e) {
          queued.handler.reject(
            DioException(requestOptions: queued.options, error: e),
          );
        }
      }
    } catch (_) {
      // Refresh failed — clear auth, reject all
      await _storage.deleteAll();
      handler.next(err);
      for (final queued in _failedQueue) {
        queued.handler.next(err);
      }
    } finally {
      _isRefreshing = false;
      _failedQueue.clear();
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// LOGGING INTERCEPTOR
// ═══════════════════════════════════════════════════════════════════════════════
class _LoggingInterceptor extends Interceptor {
  final Logger _logger;
  _LoggingInterceptor(this._logger);

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    _logger.d('→ ${options.method} ${options.baseUrl}${options.path}');
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    _logger.d(
        '← ${response.statusCode} ${response.requestOptions.baseUrl}${response.requestOptions.path}');
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    _logger.e(
        '✕ ${err.response?.statusCode} ${err.requestOptions.baseUrl}${err.requestOptions.path}: ${err.message}');
    handler.next(err);
  }
}

// ── API Response wrapper ──────────────────────────────────────────────────────
class ApiResponse<T> {
  final T? data;
  final String? message;
  final bool success;
  final int? totalRecords;
  final int? page;
  final int? totalPages;

  ApiResponse({
    this.data,
    this.message,
    this.success = true,
    this.totalRecords,
    this.page,
    this.totalPages,
  });

  factory ApiResponse.fromJson(
    Map<String, dynamic> json,
    T Function(dynamic) fromJson,
  ) {
    return ApiResponse<T>(
      data: json['data'] != null ? fromJson(json['data']) : null,
      message: json['message'],
      success: json['success'] ?? true,
      totalRecords: json['totalRecords'],
      page: json['page'],
      totalPages: json['totalPages'],
    );
  }
}

// ── API Failure model ────────────────────────────────────────────────────────
class ApiFailure {
  final String message;
  final int? statusCode;
  final Map<String, dynamic>? fieldErrors;

  const ApiFailure({
    required this.message,
    this.statusCode,
    this.fieldErrors,
  });

  factory ApiFailure.fromDioException(DioException e) {
    final data = e.response?.data;
    return ApiFailure(
      message: (data is Map ? data['message'] : null) ??
          e.message ??
          'Something went wrong',
      statusCode: e.response?.statusCode,
      fieldErrors: data is Map ? data['errors'] : null,
    );
  }

  static const ApiFailure network = ApiFailure(
    message: 'No internet connection. Check your network and try again.',
  );
  static const ApiFailure timeout = ApiFailure(
    message: 'Request timed out. Please try again.',
  );
}
