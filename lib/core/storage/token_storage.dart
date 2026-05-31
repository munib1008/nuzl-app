import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Persists the JWT across sessions (works on mobile + web).
class TokenStorage {
  static const _key = 'nuzl_jwt';
  final _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  Future<void> save(String token) => _storage.write(key: _key, value: token);
  Future<String?> read() => _storage.read(key: _key);
  Future<void> clear() => _storage.delete(key: _key);
}
