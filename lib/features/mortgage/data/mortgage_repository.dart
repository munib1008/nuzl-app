import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../domain/mortgage.dart';

final mortgageRepositoryProvider =
    Provider((ref) => MortgageRepository(ref.read(apiClientProvider)));

final mortgagesProvider = FutureProvider.autoDispose<List<Mortgage>>((ref) async =>
    ref.read(mortgageRepositoryProvider).list());

final mortgageDetailProvider =
    FutureProvider.autoDispose.family<Map<String, dynamic>, String>((ref, id) async =>
        ref.read(mortgageRepositoryProvider).detail(id));

final mortgagePaymentsProvider =
    FutureProvider.autoDispose.family<List<MortgagePayment>, String>((ref, id) async =>
        ref.read(mortgageRepositoryProvider).payments(id));

final mortgageRateHistoryProvider =
    FutureProvider.autoDispose.family<List<Map<String, dynamic>>, String>((ref, id) async =>
        ref.read(mortgageRepositoryProvider).rateHistory(id));

class MortgageRepository {
  MortgageRepository(this._api);
  final ApiClient _api;

  Future<List<Mortgage>> list() async {
    final data = await _api.get('/mortgages');
    return (data as List).map((e) => Mortgage.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  Future<Map<String, dynamic>> detail(String id) async {
    final data = await _api.get('/mortgages/$id');
    return Map<String, dynamic>.from(data);
  }

  Future<List<MortgagePayment>> payments(String id) async {
    final data = await _api.get('/mortgages/$id/payments');
    return (data as List).map((e) => MortgagePayment.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  Future<Mortgage> create(Map<String, dynamic> body) async {
    final data = await _api.post('/mortgages', body: body);
    return Mortgage.fromJson(Map<String, dynamic>.from(data));
  }

  Future<void> addPayment(String id, Map<String, dynamic> body) =>
      _api.post('/mortgages/$id/payments', body: body);

  Future<List<Map<String, dynamic>>> rateHistory(String id) async =>
      ((await _api.get('/mortgages/$id/rate-changes')) as List)
          .map((e) => Map<String, dynamic>.from(e)).toList();

  Future<void> addRateChange(String id, double rate, String effectiveFromIso) =>
      _api.post('/mortgages/$id/rate-changes', body: {'rate': rate, 'effective_from': effectiveFromIso});
}
