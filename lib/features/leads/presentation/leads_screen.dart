import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/rbac/persona.dart';
import '../../../core/theme/app_colors.dart';
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
    final canManage = ref.watch(personaProvider).canManageLeads;
    return Scaffold(
      appBar: const NuzlAppBar(title: 'Leads'),
      drawer: const NuzlDrawer(),
      floatingActionButton: canManage
          ? FloatingActionButton.extended(
              onPressed: () => context.push('/leads/new'),
              icon: const Icon(Icons.person_add_alt),
              label: const Text('New lead'),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: () async => ref.refresh(leadsProvider.future),
        child: AsyncView<List<Lead>>(
          value: leads,
          onRetry: () => ref.refresh(leadsProvider),
          data: (items) {
            if (items.isEmpty) {
              return EmptyState(
                icon: Icons.people_outline,
                title: 'No leads yet',
                message: 'Capture a buyer requirement to start qualifying and matching.',
                actionLabel: canManage ? 'Add lead' : null,
                onAction: canManage ? () => context.push('/leads/new') : null,
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

  BadgeTone _statusTone(String? s) => switch (s) {
        'converted' || 'qualified' => BadgeTone.success,
        'lost' => BadgeTone.danger,
        'negotiating' || 'viewing_scheduled' => BadgeTone.warning,
        _ => BadgeTone.neutral,
      };

  BadgeTone _catTone(String? c) => switch (c) {
        'qualified' => BadgeTone.success,
        'potential' => BadgeTone.gold,
        _ => BadgeTone.neutral,
      };

  static String _label(String s) => s.replaceAll('_', ' ');

  static String _ago(DateTime? d) {
    if (d == null) return '—';
    final diff = DateTime.now().difference(d);
    if (diff.inDays >= 1) return '${diff.inDays}d ago';
    if (diff.inHours >= 1) return '${diff.inHours}h ago';
    if (diff.inMinutes >= 1) return '${diff.inMinutes}m ago';
    return 'just now';
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final f = NumberFormat.compactCurrency(symbol: 'AED ', decimalDigits: 0);
    final budget = (lead.minBudget != null && lead.maxBudget != null)
        ? '${f.format(lead.minBudget)} – ${f.format(lead.maxBudget)}'
        : null;
    final created = lead.createdAt != null ? DateFormat('d MMM y').format(lead.createdAt!) : null;
    final details = [
      if (lead.community != null) lead.community,
      if (lead.propertyType != null) _label(lead.propertyType!),
      if (budget != null) budget,
    ].whereType<String>().join('  ·  ');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.x16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: avatar + name/phone + temperature
            Row(children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.primaryTint,
                child: Text(
                  (lead.buyerName?.isNotEmpty == true ? lead.buyerName![0] : '?').toUpperCase(),
                  style: t.titleSmall?.copyWith(color: AppColors.primary, fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: AppSpacing.x12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(lead.buyerName ?? 'Unnamed buyer', style: t.titleMedium),
                  if (lead.phone != null && lead.phone!.isNotEmpty)
                    Text(lead.phone!, style: t.bodySmall?.copyWith(color: AppColors.textMuted)),
                ]),
              ),
              if (lead.temperature != null) StatusBadge(_label(lead.temperature!), tone: _tempTone),
            ]),
            const SizedBox(height: AppSpacing.x12),
            // Status / category / priority chips
            Wrap(spacing: AppSpacing.x8, runSpacing: AppSpacing.x8, children: [
              if (lead.status != null) StatusBadge(_label(lead.status!), tone: _statusTone(lead.status)),
              if (lead.leadCategory != null) StatusBadge(_label(lead.leadCategory!), tone: _catTone(lead.leadCategory)),
              if (lead.priority != null && lead.priority!.isNotEmpty)
                StatusBadge(_label(lead.priority!), tone: BadgeTone.neutral),
            ]),
            if (details.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.x8),
              Text(details, style: t.bodyMedium),
            ],
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
            const SizedBox(height: AppSpacing.x12),
            const Divider(height: 1),
            const SizedBox(height: AppSpacing.x8),
            // Footer: created + last-activity dates
            Row(children: [
              const Icon(Icons.schedule, size: 14, color: AppColors.textSubtle),
              const SizedBox(width: 4),
              Text(created != null ? 'Created $created' : 'Created —',
                  style: t.bodySmall?.copyWith(color: AppColors.textMuted)),
              const Spacer(),
              const Icon(Icons.history, size: 14, color: AppColors.textSubtle),
              const SizedBox(width: 4),
              Text('Active ${_ago(lead.lastActivityAt)}',
                  style: t.bodySmall?.copyWith(color: AppColors.textMuted)),
            ]),
          ],
        ),
      ),
    );
  }
}
