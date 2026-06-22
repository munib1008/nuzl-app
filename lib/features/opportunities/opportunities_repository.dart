import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/api_client.dart';

const oppStageLabels = <String, String>{
  'new': 'New',
  'contacted': 'Contacted',
  'viewing': 'Viewing',
  'negotiation': 'Negotiation',
  'offer': 'Offer',
  'agreement': 'Agreement',
  'closed_won': 'Closed won',
  'closed_lost': 'Closed lost',
};

const oppStageOrder = [
  'new', 'contacted', 'viewing', 'negotiation', 'offer', 'agreement', 'closed_won', 'closed_lost',
];

/// Unified pipeline over the lead CRM + viewing CRM (CRM merge, Slice 1).
final opportunitiesProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final d = await ref.read(apiClientProvider).get('/opportunities');
  return (d as List).map((e) => Map<String, dynamic>.from(e)).toList();
});
