import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/api_client.dart';

final collabRepoProvider = Provider((ref) => CollaborationRepository(ref.read(apiClientProvider)));

final collabIncomingProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async =>
    ref.read(collabRepoProvider).incoming());
final collabOutgoingProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async =>
    ref.read(collabRepoProvider).outgoing());

class CollaborationRepository {
  CollaborationRepository(this._api);
  final ApiClient _api;

  Future<List<Map<String, dynamic>>> incoming() async =>
      ((await _api.get('/collaboration/incoming')) as List).map((e) => Map<String, dynamic>.from(e)).toList();
  Future<List<Map<String, dynamic>>> outgoing() async =>
      ((await _api.get('/collaboration/outgoing')) as List).map((e) => Map<String, dynamic>.from(e)).toList();

  Future<void> request(String listingId, double? proposedSplit, String? message) =>
      _api.post('/collaboration/listings/$listingId/request',
          body: {'proposed_split': proposedSplit, 'message': message});

  Future<void> respond(String id, String action, {double? counterSplit}) =>
      _api.post('/collaboration/$id/respond', body: {'action': action, 'counter_split': counterSplit});

  Future<void> acceptCounter(String id) => _api.post('/collaboration/$id/accept-counter');
  Future<void> withdraw(String id) => _api.post('/collaboration/$id/withdraw');
}
