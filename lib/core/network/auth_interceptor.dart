import 'package:dio/dio.dart';
import '../storage/token_storage.dart';

/// Injects the JWT and surfaces 401s so the app can redirect to login.
class AuthInterceptor extends Interceptor {
  AuthInterceptor(this._storage, {this.onUnauthorized});
  final TokenStorage _storage;
  final void Function()? onUnauthorized;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    final token = await _storage.read();
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (err.response?.statusCode == 401) {
      onUnauthorized?.call();
    }
    handler.next(err);
  }
}
