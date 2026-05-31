import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../domain/lead.dart';

final leadsRepositoryProvider = Provider((ref) => LeadsRepository(ref.read(apiClientProvider)));

final leadsProvider = FutureProvider.autoDispose<List<Lead>>((ref) async =>
    ref.read(leadsRepositoryProvider).fetch());

class LeadsRepository {
  LeadsRepository(this._api);
  final ApiClient _api;

  Future<List<Lead>> fetch() async {
    final data = await _api.get(Api.buyerRequirements);
    return (data as List).map((e) => Lead.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  Future<void> qualify(String id, Map<String, bool> fields) =>
      _api.patch(Api.qualify(id), body: fields);
}
