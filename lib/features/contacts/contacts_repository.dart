import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/api_client.dart';

/// Macro lifecycle labels/order for the unified contacts directory (CRM merge, Slice 2).
const contactLifecycleLabels = <String, String>{
  'lead': 'Leads',
  'qualified': 'Qualified',
  'customer': 'Customers',
  'owner': 'Owners',
  'tenant': 'Tenants',
  'lost': 'Lost',
};

const contactLifecycleOrder = ['lead', 'qualified', 'customer', 'owner', 'tenant', 'lost'];

/// Unified contacts across leads + customers.
final contactsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final d = await ref.read(apiClientProvider).get('/contacts');
  return d is List ? d.map((e) => Map<String, dynamic>.from(e as Map)).toList() : <Map<String, dynamic>>[];
});
