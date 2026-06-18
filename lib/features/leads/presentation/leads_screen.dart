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
      appBar: NuzlAppBar(title: 'Leads', actions: canManage
          ? [
              IconButton(
                tooltip: 'Import leads',
                icon: const Icon(Icons.upload_file_outlined),
                onPressed: () => context.push('/leads/import'),
              ),
            ]
          : null),
      drawer: const NuzlDrawer(),
      floatingActionButton: canManage
          ? FloatingActionButton.extended(
              onPressed: () => context.push('/leads/new'),
              icon: const Icon(Icons.person_add_alt),
              label: const Text('New lead'),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: () {
          ref.invalidate(leadOffersProvider);
          return ref.refresh(leadsProvider.future);
        },
        child: AsyncView<List<Lead>>(
          value: leads,
          onRetry: () {
            ref.invalidate(leadsProvider);
            ref.invalidate(leadOffersProvider);
          },
          data: (items) {
            final offers = ref.watch(leadOffersProvider).asData?.value ?? const <Lead>[];
            if (items.isEmpty && offers.isEmpty) {
              return EmptyState(
                icon: Icons.people_outline,
                title: 'No leads yet',
                message: 'Capture a buyer requirement to start qualifying and matching.',
                actionLabel: canManage ? 'Add lead' : null,
                onAction: canManage ? () => context.push('/leads/new') : null,
              );
            }
            final t = Theme.of(context).textTheme;
            return ListView(
              padding: const EdgeInsets.all(AppSpacing.x16),
              children: [
                if (offers.isNotEmpty) ...[
                  Text('Offered to you — first to accept gets it',
                      style: t.titleSmall?.copyWith(color: AppColors.primary)),
                  const SizedBox(height: AppSpacing.x8),
                  for (final o in offers)
                    Padding(padding: const EdgeInsets.only(bottom: AppSpacing.x12), child: _OfferCard(o)),
                  const SizedBox(height: AppSpacing.x4),
                  const Divider(),
                  const SizedBox(height: AppSpacing.x12),
                  Text('My leads', style: t.titleSmall),
                  const SizedBox(height: AppSpacing.x8),
                ],
                for (final l in items)
                  Padding(padding: const EdgeInsets.only(bottom: AppSpacing.x12), child: _LeadCard(l)),
              ],
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

  Color _scoreColor(int s) => s >= 70 ? AppColors.success : (s >= 40 ? AppColors.warning : AppColors.textMuted);

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
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/leads/${lead.id}'),
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
              Tooltip(
                message: 'Lead score',
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                      color: _scoreColor(lead.score).withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(AppSpacing.rFull)),
                  child: Text('${lead.score}',
                      style: t.labelSmall?.copyWith(color: _scoreColor(lead.score), fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(width: AppSpacing.x8),
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
      ),
    );
  }
}

/// A lead offered to several agents — first to tap Accept claims it (agent #6).
class _OfferCard extends ConsumerStatefulWidget {
  const _OfferCard(this.lead);
  final Lead lead;
  @override
  ConsumerState<_OfferCard> createState() => _OfferCardState();
}

class _OfferCardState extends ConsumerState<_OfferCard> {
  bool _busy = false;

  Future<void> _accept() async {
    setState(() => _busy = true);
    try {
      await ref.read(leadsRepositoryProvider).accept(widget.lead.id);
      ref.invalidate(leadOffersProvider);
      ref.invalidate(leadsProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lead accepted — it is yours')));
      context.push('/leads/${widget.lead.id}');
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      ref.invalidate(leadOffersProvider); // it may have just been claimed by someone else
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final lead = widget.lead;
    final f = NumberFormat.compactCurrency(symbol: 'AED ', decimalDigits: 0);
    final budget = (lead.minBudget != null && lead.maxBudget != null)
        ? '${f.format(lead.minBudget)} – ${f.format(lead.maxBudget)}'
        : null;
    final details = [
      if (lead.community != null) lead.community,
      if (lead.propertyType != null) lead.propertyType!.replaceAll('_', ' '),
      if (budget != null) budget,
    ].whereType<String>().join('  ·  ');
    return Card(
      color: AppColors.primaryTint,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.x16),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(lead.buyerName ?? 'New lead', style: t.titleMedium),
              if (details.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(details, style: t.bodySmall?.copyWith(color: AppColors.textMuted)),
              ],
            ]),
          ),
          const SizedBox(width: AppSpacing.x12),
          FilledButton(
            onPressed: _busy ? null : _accept,
            child: _busy
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Accept'),
          ),
        ]),
      ),
    );
  }
}
