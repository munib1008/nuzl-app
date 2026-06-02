import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'api_client.dart';

final uploadServiceProvider = Provider((ref) => UploadService(ref.read(apiClientProvider)));

class UploadService {
  UploadService(this._api);
  final ApiClient _api;

  /// Uploads bytes via the API (→ Supabase Storage) and returns a public URL.
  /// Returns null if uploads aren't configured server-side (graceful).
  Future<String?> upload(Uint8List bytes, String filename, String contentType) async {
    try {
      final res = await _api.post('/uploads', body: {
        'filename': filename,
        'contentType': contentType,
        'dataBase64': base64Encode(bytes),
      });
      return (res is Map) ? res['url'] as String? : null;
    } catch (_) {
      return null; // uploads optional — form still submits without an image
    }
  }
}
