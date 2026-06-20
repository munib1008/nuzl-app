import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/api_client.dart';

final invoicingRepoProvider = Provider<InvoicingRepository>((ref) => InvoicingRepository(ref.read(apiClientProvider)));

/// Documents for the current filter ('' = all, 'quote', 'invoice').
final invoicingListProvider =
    FutureProvider.autoDispose.family<List<Map<String, dynamic>>, String>((ref, type) async {
  return ref.read(invoicingRepoProvider).list(type);
});

class InvoicingRepository {
  InvoicingRepository(this._api);
  final ApiClient _api;

  Future<List<Map<String, dynamic>>> list(String type) async {
    final d = await _api.get('/invoicing', query: type.isEmpty ? null : {'type': type});
    return (d is List ? d : const []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<Map<String, dynamic>> create(Map<String, dynamic> body) async =>
      Map<String, dynamic>.from(await _api.post('/invoicing', body: body) as Map);

  Future<Map<String, dynamic>> update(String id, Map<String, dynamic> body) async =>
      Map<String, dynamic>.from(await _api.patch('/invoicing/$id', body: body) as Map);

  Future<Map<String, dynamic>> setStatus(String id, String status) async =>
      Map<String, dynamic>.from(await _api.patch('/invoicing/$id/status', body: {'status': status}) as Map);

  Future<Map<String, dynamic>> convert(String id) async =>
      Map<String, dynamic>.from(await _api.post('/invoicing/$id/convert') as Map);
}
