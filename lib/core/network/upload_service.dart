import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'api_client.dart';

final uploadServiceProvider = Provider((ref) => UploadService(ref.read(apiClientProvider)));

class UploadService {
  UploadService(this._api);
  final ApiClient _api;

  /// Uploads bytes via the API (→ Supabase Storage) and returns a public URL.
  /// Throws on a server error (e.g. 501 uploads-not-configured, 413 too-large)
  /// so the caller can surface the real reason instead of silently dropping the
  /// photo; returns null only when the server responds without a URL.
  Future<String?> upload(Uint8List bytes, String filename, String contentType) async {
    final res = await _api.post('/uploads', body: {
      'filename': filename,
      'contentType': contentType,
      'dataBase64': base64Encode(bytes),
    });
    return (res is Map) ? res['url'] as String? : null;
  }
}
