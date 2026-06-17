import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/api_client.dart';

/// Per-kind status flows (mirror the API). 'cancelled' is terminal, reachable from any.
const productFlow = ['received', 'processing', 'dispatched', 'out_for_delivery', 'delivered', 'returned'];
const serviceFlow = ['requested', 'assigned', 'scheduled', 'in_progress', 'completed', 'closed'];

const orderStatusLabels = <String, String>{
  'received': 'Received',
  'processing': 'Processing',
  'dispatched': 'Dispatched',
  'out_for_delivery': 'Out for delivery',
  'delivered': 'Delivered',
  'returned': 'Returned',
  'requested': 'Requested',
  'assigned': 'Assigned',
  'scheduled': 'Scheduled',
  'in_progress': 'In progress',
  'completed': 'Completed',
  'closed': 'Closed',
  'cancelled': 'Cancelled',
};

const _terminal = {'delivered', 'returned', 'completed', 'closed', 'cancelled'};
const _rateable = {'delivered', 'completed', 'closed'};

bool orderIsTerminal(String s) => _terminal.contains(s);
bool orderIsRateable(String s) => _rateable.contains(s);

List<String> flowFor(String kind) => kind == 'product' ? productFlow : serviceFlow;

/// Next status a provider can advance to, or null if at the end / terminal.
String? nextStatus(String kind, String current) {
  final flow = flowFor(kind);
  final i = flow.indexOf(current);
  if (i < 0 || i >= flow.length - 1) return null;
  return flow[i + 1];
}

final myOrdersProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final d = await ref.read(apiClientProvider).get('/marketplace/orders/mine');
  return d is List ? d.map((e) => Map<String, dynamic>.from(e as Map)).toList() : <Map<String, dynamic>>[];
});

final incomingOrdersProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final d = await ref.read(apiClientProvider).get('/marketplace/orders/incoming');
  return d is List ? d.map((e) => Map<String, dynamic>.from(e as Map)).toList() : <Map<String, dynamic>>[];
});
