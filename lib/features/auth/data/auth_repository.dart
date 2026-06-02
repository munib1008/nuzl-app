import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/storage/token_storage.dart';
import '../../../models/user.dart';

final authRepositoryProvider = Provider((ref) => AuthRepository(
      ref.read(apiClientProvider),
      ref.read(tokenStorageProvider),
    ));

class AuthRepository {
  AuthRepository(this._api, this._storage);
  final ApiClient _api;
  final TokenStorage _storage;

  Future<AppUser> login(String email, String password) async {
    final data = await _api.post(Api.login, body: {'email': email, 'password': password});
    return _persist(data);
  }

  Future<AppUser> register(String email, String password, String fullName) async {
    final data = await _api.post(Api.register,
        body: {'email': email, 'password': password, 'full_name': fullName});
    return _persist(data);
  }

  Future<AppUser> loginWithGoogle(String idToken) async {
    final data = await _api.post(Api.google, body: {'idToken': idToken});
    return _persist(data);
  }

  Future<AppUser?> currentUser() async {
    final token = await _storage.read();
    if (token == null || token.isEmpty) return null;
    final data = await _api.get(Api.me);
    return AppUser.fromJson(Map<String, dynamic>.from(data));
  }

  Future<void> logout() => _storage.clear();

  Future<AppUser> _persist(dynamic data) async {
    await _storage.save(data['token']);
    return AppUser.fromJson(Map<String, dynamic>.from(data['user']));
  }
}
