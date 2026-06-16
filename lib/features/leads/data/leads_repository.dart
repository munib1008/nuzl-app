import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../domain/lead.dart';

final leadsRepositoryProvider = Provider((ref) => LeadsRepository(ref.read(apiClientProvider)));

final leadsProvider = FutureProvider.autoDispose<List<Lead>>((ref) async =>
    ref.read(leadsRepositoryProvider).fetch());

/// Leads offered to me, awaiting accept (agent #6).
final leadOffersProvider = FutureProvider.autoDispose<List<Lead>>((ref) async =>
    ref.read(leadsRepositoryProvider).offers());

/// CRM record + activity log for one lead (agent #7).
final leadCrmProvider = FutureProvider.autoDispose.family<Map<String, dynamic>, String>(
    (ref, id) async => ref.read(leadsRepositoryProvider).crm(id));

class LeadsRepository {
  LeadsRepository(this._api);
  final ApiClient _api;

  Future<List<Lead>> fetch() async {
    final data = await _api.get(Api.buyerRequirements);
    return (data as List).map((e) => Lead.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  Future<void> qualify(String id, Map<String, bool> fields) =>
      _api.patch(Api.qualify(id), body: fields);

  Future<List<Lead>> offers() async {
    final data = await _api.get('/buyer-requirements/offers');
    return (data as List).map((e) => Lead.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  /// First-accept-wins. Throws ApiException (409) if another agent got it first.
  Future<void> accept(String id) => _api.post('/buyer-requirements/$id/accept');

  Future<void> assign(String id, List<String> agentIds) =>
      _api.post('/buyer-requirements/$id/assign', body: {'agent_ids': agentIds});

  Future<Map<String, dynamic>> crm(String id) async =>
      Map<String, dynamic>.from(await _api.get('/buyer-requirements/$id/crm'));

  Future<void> setCrmStage(String id, String stage) =>
      _api.patch('/buyer-requirements/$id/crm-stage', body: {'stage': stage});

  Future<void> addCrmActivity(String id, String type, String note) =>
      _api.post('/buyer-requirements/$id/crm-activity', body: {'activity_type': type, 'note': note});

  /// Name search for the assign-to-agents picker.
  Future<List<Map<String, dynamic>>> searchUsers(String q) async {
    final data = await _api.get('/users/search', query: {'q': q});
    return (data as List).map((e) => Map<String, dynamic>.from(e)).toList();
  }
}
