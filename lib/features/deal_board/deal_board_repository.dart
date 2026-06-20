import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/api_client.dart';

const dealCategoryLabels = <String, String>{
  'distress': 'Distress',
  'below_op': 'Below OP',
  'urgent_sale': 'Urgent sale',
  'hot_deal': 'Hot deal',
  'rental': 'Rental',
  'commercial': 'Commercial',
  'exclusive': 'Exclusive',
  'direct_owner': 'Direct owner',
  'direct_buyer': 'Direct buyer',
};

final dealBoardRepoProvider = Provider((ref) => DealBoardRepository(ref.read(apiClientProvider)));

final dealBoardProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async =>
    ((await ref.read(apiClientProvider).get('/deal-board')) as List)
        .map((e) => Map<String, dynamic>.from(e)).toList());

class DealBoardRepository {
  DealBoardRepository(this._api);
  final ApiClient _api;

  Future<void> create(Map<String, dynamic> body) => _api.post('/deal-board', body: body);
  Future<void> close(String id) => _api.patch('/deal-board/$id/close');
}
