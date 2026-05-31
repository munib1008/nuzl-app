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

  Future<dynamic> _unwrap(Future<Response> Function() call) async {
    try {
      final res = await call();
      return res.data;
    } on DioException catch (e) {
      final msg = e.response?.data is Map && (e.response?.data['message'] != null)
          ? e.response!.data['message'].toString()
          : (e.message ?? 'Network error');
      throw ApiException(msg, statusCode: e.response?.statusCode);
    }
  }
}

class ApiException implements Exception {
  ApiException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;
  @override
  String toString() => message;
}
