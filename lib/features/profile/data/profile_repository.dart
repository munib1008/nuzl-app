import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../models/user.dart';

final profileProvider = FutureProvider.autoDispose<AppUser>((ref) async {
  final data = await ref.read(apiClientProvider).get(Api.me);
  return AppUser.fromJson(Map<String, dynamic>.from(data));
});
