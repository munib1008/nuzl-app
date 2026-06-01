import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/async_view.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/status_badge.dart';
import '../data/leads_repository.dart';
import '../domain/lead.dart';
import '../../shell/app_shell.dart';

class LeadsScreen extends ConsumerWidget {
  const LeadsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final leads = ref.watch(leadsProvider);
    return Scaffold(
      appBar: const NuzlAppBar(title: 'Leads'),
      drawer: const NuzlDrawer(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {},
        icon: const Icon(Icons.person_add_alt),
        label: const Text('New lead'),
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.refresh(leadsProvider.future),
        child: AsyncView<List<Lead>>(
          value: leads,
          onRetry: () => ref.refresh(leadsProvider),
          data: (items) {
            if (items.isEmpty) {
              return const EmptyState(
                icon: Icons.people_outline,
                title: 'No leads yet',
                message: 'Capture a buyer requirement to start qualifying and matching.',
                actionLabel: 'Add lead',
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.x16),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.x12),
              itemBuilder: (_, i) => _LeadCard(items[i]),
            );
          },
        ),
      ),
    );
  }
}

class _LeadCard extends StatelessWidget {
  const _LeadCard(this.lead);
  final Lead lead;

  BadgeTone get _tempTone => switch (lead.temperature) {
        'hot' => BadgeTone.danger,
        'warm' => BadgeTone.warning,
        _ => BadgeTone.neutral,
      };

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final f = NumberFormat.compactCurrency(symbol: 'AED ', decimalDigits: 0);
    final budget = (lead.minBudget != null && lead.maxBudget != null)
        ? '${f.format(lead.minBudget)} – ${f.format(lead.maxBudget)}'
        : null;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.x16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(child: Text(lead.buyerName ?? 'Unnamed buyer', style: t.titleMedium)),
              if (lead.temperature != null) StatusBadge(lead.temperature!, tone: _tempTone),
            ]),
            const SizedBox(height: AppSpacing.x4),
            Text([
              if (lead.community != null) lead.community,
              if (lead.buyerType != null) lead.buyerType,
              if (budget != null) budget,
            ].whereType<String>().join('  ·  '), style: t.bodyMedium),
            const SizedBox(height: AppSpacing.x12),
            // qualification progress (0..5)
            Row(children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppSpacing.rFull),
                  child: LinearProgressIndicator(
                    value: lead.qualificationSteps / 5,
                    minHeight: 6,
                    backgroundColor: Theme.of(context).dividerColor,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.x8),
              Text('${lead.qualificationSteps}/5', style: t.bodySmall),
            ]),
          ],
        ),
      ),
    );
  }
}
