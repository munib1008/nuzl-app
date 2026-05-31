import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../domain/listing.dart';

final listingsRepositoryProvider = Provider((ref) => ListingsRepository(ref.read(apiClientProvider)));

final listingsProvider = FutureProvider.autoDispose<List<Listing>>((ref) async =>
    ref.read(listingsRepositoryProvider).fetch());

class ListingsRepository {
  ListingsRepository(this._api);
  final ApiClient _api;

  Future<List<Listing>> fetch({Map<String, dynamic>? filters}) async {
    final data = await _api.get(Api.listings, query: filters);
    return (data as List).map((e) => Listing.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  Future<Listing> create(Map<String, dynamic> body) async {
    final data = await _api.post(Api.listings, body: body);
    return Listing.fromJson(Map<String, dynamic>.from(data));
  }

  Future<void> verify(String id) => _api.patch(Api.verifyListing(id), body: {'owner_contacted': true});
}
