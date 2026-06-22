import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/env.dart';
import '../storage/token_storage.dart';
import 'auth_interceptor.dart';

final tokenStorageProvider = Provider((_) => TokenStorage());

/// Notifies listeners (the router) when the API returns 401.
final unauthorizedProvider = StateProvider<int>((_) => 0);

final apiClientProvider = Provider<ApiClient>((ref) {
  final storage = ref.read(tokenStorageProvider);
  final dio = Dio(BaseOptions(
    baseUrl: Env.apiBaseUrl,
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 20),
    headers: {'Content-Type': 'application/json'},
  ));
  dio.interceptors.add(AuthInterceptor(
    storage,
    onUnauthorized: () => ref.read(unauthorizedProvider.notifier).state++,
  ));
  return ApiClient(dio);
});

/// Thin wrapper exposing typed helpers and consistent error messages.
class ApiClient {
  ApiClient(this._dio);
  final Dio _dio;

  Future<dynamic> get(String path, {Map<String, dynamic>? query}) async =>
      _unwrap(() => _dio.get(path, queryParameters: query));

  Future<dynamic> post(String path, {Object? body}) async =>
      _unwrap(() => _dio.post(path, data: body));

  Future<dynamic> patch(String path, {Object? body}) async =>
      _unwrap(() => _dio.patch(path, data: body));

  Future<dynamic> delete(String path, {Object? body}) async =>
      _unwrap(() => _dio.delete(path, data: body));

  Future<dynamic> _unwrap(Future<Response> Function() call) async {
    try {
      final res = await call();
      return res.data;
    } on DioException catch (e) {
      final data = e.response?.data;
      String? msg;
      if (data is Map && data['message'] != null) {
        final m = data['message'];
        msg = m is List ? m.join(', ') : m.toString();
      }
      msg ??= e.message ?? 'Network error';
      throw ApiException(msg, statusCode: e.response?.statusCode);
    }
  }
}

class ApiException implements Exception {
  ApiException(this.message, {this.statusCode});

  /// Raw server message + HTTP status. Kept for code that needs specifics
  /// (e.g. session-expiry handling); NOT shown directly to users.
  final String message;
  final int? statusCode;

  /// What `'$e'` renders — always a clean, user-facing message (never a stack
  /// trace, DB error or "Internal server error").
  @override
  String toString() => friendlyError(this);
}

/// Maps any thrown error to a short, user-facing sentence. Use this anywhere an
/// error is shown to a person. Raw server/stack/DB text is never surfaced.
String friendlyError(Object? e, {String? fallback}) {
  final fb = fallback ?? 'Unable to complete your request. Please try again.';
  if (e is ApiException) {
    final code = e.statusCode;
    if (code == null) {
      return 'Connection issue detected. Please check your network and try again.';
    }
    switch (code) {
      case 401:
        return 'Your session has expired. Please sign in again.';
      case 403:
        return 'You don’t have permission to do that.';
      case 404:
        return 'We couldn’t find what you were looking for.';
      case 408:
      case 504:
        return 'The request timed out. Please try again.';
    }
    if (code == 400 || code == 409 || code == 422) {
      return _cleanMessage(e.message) ??
          (code == 409
              ? 'That conflicts with the current state. Please refresh and try again.'
              : 'Some information is missing or invalid. Please review the highlighted fields.');
    }
    if (code >= 500) return fb; // never leak server internals
    return _cleanMessage(e.message) ?? fb;
  }
  // DioException not wrapped, timeouts, or anything unexpected.
  return 'Connection issue detected. Please check your network and try again.';
}

/// Returns [raw] only when it reads like a clean, user-facing message; otherwise
/// null so the caller falls back to a safe generic. Filters stack traces, HTML,
/// SQL and HTTP jargon that should never reach a user.
String? _cleanMessage(String? raw) {
  if (raw == null) return null;
  final m = raw.trim();
  if (m.isEmpty || m.length > 160) return null;
  final low = m.toLowerCase();
  const bad = [
    'internal server error', 'exception', 'stack', 'econn', 'socket',
    'timeout of', 'syntax error', 'relation ', 'column ', 'duplicate key',
    'null value', 'violates', 'constraint', '<!doctype', '<html',
    'cannot read', 'undefined', 'errno', 'sqlstate', 'xhr', 'dioerror', 'enotfound',
  ];
  if (bad.any(low.contains)) return null;
  return m;
}
