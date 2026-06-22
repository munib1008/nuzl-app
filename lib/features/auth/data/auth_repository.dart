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

  Future<AppUser> register(String email, String password, String fullName, {String? referralCode}) async {
    final data = await _api.post(Api.register, body: {
      'email': email,
      'password': password,
      'full_name': fullName,
      if (referralCode != null && referralCode.isNotEmpty) 'referral_code': referralCode,
    });
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

  Future<Map<String, dynamic>> forgotPassword(String email) async {
    final d = await _api.post(Api.forgotPassword, body: {'email': email});
    return d is Map ? Map<String, dynamic>.from(d) : <String, dynamic>{};
  }

  Future<void> resetPassword(String token, String password) async {
    await _api.post(Api.resetPassword, body: {'token': token, 'password': password});
  }

  /// Cancel a pending account deletion (within the 14-day grace window).
  Future<void> reactivate() async {
    await _api.post('/users/me/reactivate');
  }

  /// Switch the active role (multi-role accounts, UAT #3).
  Future<void> switchActiveRole(String role) async {
    await _api.patch('/users/me/roles/active', body: {'role': role});
  }

  /// Set the account's primary role once at signup.
  Future<void> setPrimaryRole(String role) async {
    await _api.post('/users/me/primary-role', body: {'role': role});
  }

  Future<void> logout() => _storage.clear();

  Future<AppUser> _persist(dynamic data) async {
    await _storage.save(data['token']);
    return AppUser.fromJson(Map<String, dynamic>.from(data['user']));
  }
}
