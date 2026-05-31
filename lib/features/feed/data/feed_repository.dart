import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../domain/feed_item.dart';

final feedRepositoryProvider = Provider((ref) => FeedRepository(ref.read(apiClientProvider)));

final feedProvider = FutureProvider.autoDispose<List<FeedItem>>((ref) async =>
    ref.read(feedRepositoryProvider).fetch());

class FeedRepository {
  FeedRepository(this._api);
  final ApiClient _api;
  Future<List<FeedItem>> fetch() async {
    final data = await _api.get(Api.feed);
    return (data as List).map((e) => FeedItem.fromJson(Map<String, dynamic>.from(e))).toList();
  }
}
