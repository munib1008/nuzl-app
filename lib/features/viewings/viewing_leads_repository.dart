import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/api_client.dart';

/// The 12-stage viewing-request CRM pipeline (agent #24).
const viewingStageLabels = <String, String>{
  'new_inquiry': 'New inquiry',
  'contacted': 'Contacted',
  'viewing_scheduled': 'Viewing scheduled',
  'viewing_completed': 'Viewing completed',
  'negotiation': 'Negotiation',
  'offer_submitted': 'Offer submitted',
  'documents_requested': 'Documents requested',
  'lease_agreement': 'Lease agreement',
  'ejari_processing': 'Ejari processing',
  'payment_collection': 'Payment collection',
  'closed_won': 'Closed won',
  'closed_lost': 'Closed lost',
};

final viewingLeadsRepoProvider = Provider((ref) => ViewingLeadsRepository(ref.read(apiClientProvider)));

/// Unassigned viewing requests on my properties — claimable lead inbox (#21).
final viewingPendingProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>(
    (ref) async => ref.read(viewingLeadsRepoProvider).pending());

/// Viewing requests assigned to me (#22).
final viewingAssignedProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>(
    (ref) async => ref.read(viewingLeadsRepoProvider).assigned());

/// Dashboard metrics (#27).
final viewingMetricsProvider = FutureProvider.autoDispose<Map<String, dynamic>>(
    (ref) async => ref.read(viewingLeadsRepoProvider).metrics());

/// CRM record for one viewing request (#24/#25).
final viewingCrmProvider = FutureProvider.autoDispose.family<Map<String, dynamic>, String>(
    (ref, id) async => ref.read(viewingLeadsRepoProvider).crm(id));

class ViewingLeadsRepository {
  ViewingLeadsRepository(this._api);
  final ApiClient _api;

  Future<List<Map<String, dynamic>>> pending() async =>
      ((await _api.get('/viewings/pending')) as List).map((e) => Map<String, dynamic>.from(e)).toList();

  Future<List<Map<String, dynamic>>> assigned() async =>
      ((await _api.get('/viewings/assigned')) as List).map((e) => Map<String, dynamic>.from(e)).toList();

  Future<Map<String, dynamic>> metrics() async =>
      Map<String, dynamic>.from(await _api.get('/viewings/metrics'));

  Future<Map<String, dynamic>> crm(String id) async =>
      Map<String, dynamic>.from(await _api.get('/viewings/$id/crm'));

  /// First-accept-wins. Throws ApiException (409) if another agent got it first.
  Future<void> accept(String id) => _api.patch('/viewings/$id/accept');

  Future<void> setStage(String id, String stage) =>
      _api.patch('/viewings/$id/crm-stage', body: {'stage': stage});

  Future<void> logActivity(String id, String type, String note) =>
      _api.post('/viewings/$id/activity', body: {'activity_type': type, 'note': note});

  /// Open (or reuse) the customer<->assigned-agent chat; returns the conversation id (#23).
  Future<String> openConversation(String id) async {
    final res = await _api.post('/viewings/$id/conversation');
    return '${(res as Map)['conversation_id']}';
  }

  Future<void> scheduleCall(String id, String scheduledAtIso, String note) =>
      _api.post('/viewings/$id/schedule-call', body: {'scheduled_at': scheduledAtIso, 'note': note});
}
