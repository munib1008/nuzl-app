import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/api_client.dart';

final propertyDocsRepoProvider = Provider((ref) => PropertyDocsRepository(ref.read(apiClientProvider)));

final propertyDocRequestsProvider =
    FutureProvider.autoDispose.family<List<Map<String, dynamic>>, String>(
        (ref, id) async => ref.read(propertyDocsRepoProvider).requests(id));

final propertyDocumentsProvider =
    FutureProvider.autoDispose.family<List<Map<String, dynamic>>, String>(
        (ref, id) async => ref.read(propertyDocsRepoProvider).documents(id));

final propertyDocActivityProvider =
    FutureProvider.autoDispose.family<List<Map<String, dynamic>>, String>(
        (ref, id) async => ref.read(propertyDocsRepoProvider).activity(id));

/// Owner <-> agent document collaboration for a property (owner/agent #9/#10/#11).
class PropertyDocsRepository {
  PropertyDocsRepository(this._api);
  final ApiClient _api;

  Future<List<Map<String, dynamic>>> requests(String id) async =>
      ((await _api.get('/properties/$id/doc-requests')) as List)
          .map((e) => Map<String, dynamic>.from(e)).toList();

  Future<List<Map<String, dynamic>>> documents(String id) async =>
      ((await _api.get('/properties/$id/documents')) as List)
          .map((e) => Map<String, dynamic>.from(e)).toList();

  Future<List<Map<String, dynamic>>> activity(String id) async =>
      ((await _api.get('/properties/$id/doc-activity')) as List)
          .map((e) => Map<String, dynamic>.from(e)).toList();

  Future<void> requestDoc(String id, String docType, String? label, String? note) =>
      _api.post('/properties/$id/doc-requests', body: {'doc_type': docType, 'label': label, 'note': note});

  Future<void> addDoc(String id,
          {required String docType, String? label, required String fileUrl, String? requestId}) =>
      _api.post('/properties/$id/documents',
          body: {'doc_type': docType, 'label': label, 'file_url': fileUrl, 'request_id': requestId});

  Future<void> deleteDoc(String id, String docId) => _api.delete('/properties/$id/documents/$docId');
}
