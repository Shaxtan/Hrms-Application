import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:logger/logger.dart';

class ApiClient {
  static const String _baseUrl = 'http://localhost:8083'; // Employee Service
  static const _storage = FlutterSecureStorage();
  static final _logger = Logger();

  static late Dio _dio;

  static void init() {
    _dio = Dio(
      BaseOptions(
        baseUrl: _baseUrl,
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    _dio.interceptors.addAll([
      _AuthInterceptor(),
      _LoggingInterceptor(_logger),
    ]);
  }

  static Dio get instance => _dio;
}

class _AuthInterceptor extends Interceptor {
  static const _storage = FlutterSecureStorage();

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await _storage.read(key: 'auth_token');
    final tenantId = await _storage.read(key: 'tenant_id');

    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    if (tenantId != null) {
      options.headers['X-Tenant-ID'] = tenantId;
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode == 401) {
      // Token expired — surface to auth layer
      // TODO: trigger token refresh or re-login
    }
    handler.next(err);
  }
}

class _LoggingInterceptor extends Interceptor {
  final Logger _logger;
  _LoggingInterceptor(this._logger);

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    _logger.d('→ ${options.method} ${options.path}');
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    _logger.d('← ${response.statusCode} ${response.requestOptions.path}');
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    _logger.e('✕ ${err.response?.statusCode} ${err.requestOptions.path}: ${err.message}');
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
