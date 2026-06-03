import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/responsive.dart';
import '../shell/app_shell.dart';

final _leadsProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  try {
    final d = await ref.read(apiClientProvider).get('/buyer-requirements');
    return d is List ? d : [];
  } catch (_) {
    return [];
  }
});

final _selectedLeadProvider = StateProvider.autoDispose<String?>((ref) => null);

/// Runs the rule-based matcher for a requirement; returns scored listings.
final _matchesProvider = FutureProvider.autoDispose.family<List<dynamic>, String>((ref, leadId) async {
  try {
    final d = await ref.read(apiClientProvider).post('/matching/requirements/$leadId/run');
    return d is List ? d : [];
  } catch (_) {
    return [];
  }
});

class LeadMatchesScreen extends ConsumerWidget {
  const LeadMatchesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final leads = ref.watch(_leadsProvider);
    final selected = ref.watch(_selectedLeadProvider);
    return Scaffold(
      appBar: const NuzlAppBar(title: 'Lead Matches'),
      drawer: const NuzlDrawer(),
      body: ResponsiveCenter(
        child: leads.when(
          loading: () => const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator())),
          error: (e, _) => Center(child: Padding(padding: const EdgeInsets.all(24), child: Text('$e'))),
          data: (list) {
            if (list.isEmpty) {
              return const Center(
                  child: Padding(padding: EdgeInsets.all(40), child: Text('No leads to match. Add a lead first.')));
            }
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.x16),
                  child: DropdownButtonFormField<String>(
                    initialValue: selected,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Select a lead'),
                    items: list.map((e) {
                      final m = Map<String, dynamic>.from(e);
                      return DropdownMenuItem(value: '${m['id']}', child: Text('${m['buyer_name'] ?? 'Lead'}'));
                    }).toList(),
                    onChanged: (v) => ref.read(_selectedLeadProvider.notifier).state = v,
                  ),
                ),
                Expanded(
                  child: selected == null
                      ? const Center(child: Text('Pick a lead to see suggested listings.'))
                      : ref.watch(_matchesProvider(selected)).when(
                          loading: () => const Center(child: CircularProgressIndicator()),
                          error: (e, _) => Center(child: Padding(padding: const EdgeInsets.all(24), child: Text('$e'))),
                          data: (matches) => matches.isEmpty
                              ? const Center(child: Text('No strong matches yet.'))
                              : ListView.separated(
                                  padding: const EdgeInsets.all(AppSpacing.x16),
                                  itemCount: matches.length,
                                  separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.x8),
                                  itemBuilder: (_, i) {
                                    final m = Map<String, dynamic>.from(matches[i]);
                                    final score = num.tryParse('${m['score']}') ?? 0;
                                    final id = '${m['listing_id'] ?? ''}';
                                    return Card(
                                      child: ListTile(
                                        leading: _ScoreBadge(score: score),
                                        title: Text('Listing ${id.split('-').first}'),
                                        subtitle: Text(_reason(m['reason'])),
                                      ),
                                    );
                                  },
                                ),
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

String _reason(dynamic r) {
  if (r is String && r.isNotEmpty) return r;
  if (r is Map) return r.entries.take(3).map((e) => '${e.key}: ${e.value}').join('  ·  ');
  return 'Rule-based match';
}

class _ScoreBadge extends StatelessWidget {
  const _ScoreBadge({required this.score});
  final num score;
  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      backgroundColor: AppColors.primaryTint,
      child: Text('${score.round()}',
          style: const TextStyle(color: AppColors.primaryDark, fontWeight: FontWeight.w700, fontSize: 12)),
    );
  }
}
