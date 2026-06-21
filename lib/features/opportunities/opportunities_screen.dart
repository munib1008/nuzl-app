import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/async_view.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/status_badge.dart';
import '../crm/crm_scaffold.dart';
import 'opportunities_repository.dart';

BadgeTone _stageTone(String s) => switch (s) {
      'closed_won' => BadgeTone.success,
      'closed_lost' => BadgeTone.danger,
      'new' => BadgeTone.warning,
      _ => BadgeTone.gold,
    };

/// Unified CRM pipeline (CRM merge, Slice 1): manual leads + inbound viewing
/// requests in one stage-grouped view. Tapping opens the source CRM.
class OpportunitiesScreen extends ConsumerWidget {
  const OpportunitiesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final opps = ref.watch(opportunitiesProvider);
    final t = Theme.of(context).textTheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return CrmScaffold(
      tab: CrmTab.pipeline,
      title: 'CRM pipeline',
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(opportunitiesProvider),
        child: AsyncView<List<Map<String, dynamic>>>(
          value: opps,
          onRetry: () => ref.invalidate(opportunitiesProvider),
          data: (list) {
            if (list.isEmpty) {
              return ListView(children: const [
                EmptyState(
                  icon: Icons.trending_up,
                  title: 'No opportunities yet',
                  message: 'Opportunities appear here as you qualify and progress your leads.',
                ),
              ]);
            }
            final byStage = <String, List<Map<String, dynamic>>>{};
            for (final o in list) {
              (byStage[o['stage'] ?? 'new'] ??= []).add(o);
            }
            return ListView(
              padding: const EdgeInsets.all(AppSpacing.x16),
              children: [
                _summaryStrip(byStage, list.length, t, dark),
                const SizedBox(height: AppSpacing.x16),
                for (final s in oppStageOrder)
                  if (byStage[s]?.isNotEmpty == true) ...[
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.x8, bottom: AppSpacing.x8),
                      child: Row(children: [
                        Text(oppStageLabels[s] ?? s, style: t.titleSmall),
                        const SizedBox(width: AppSpacing.x8),
                        Text('${byStage[s]!.length}', style: t.bodySmall?.copyWith(color: dark ? AppColors.dTextMuted : AppColors.textMuted)),
                      ]),
                    ),
                    for (final o in byStage[s]!) _OppCard(o),
                  ],
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _summaryStrip(Map<String, List> byStage, int total, TextTheme t, bool dark) {
    final won = byStage['closed_won']?.length ?? 0;
    final lost = byStage['closed_lost']?.length ?? 0;
    final active = total - won - lost;
    final stats = <(String, String)>[
      ('Total', '$total'),
      ('Active', '$active'),
      ('Won', '$won'),
      ('Lost', '$lost'),
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.x16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (final s in stats)
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(s.$2, style: t.titleLarge),
                Text(s.$1, style: t.bodySmall?.copyWith(color: dark ? AppColors.dTextMuted : AppColors.textMuted)),
              ]),
          ],
        ),
      ),
    );
  }
}

class _OppCard extends StatelessWidget {
  const _OppCard(this.o);
  final Map<String, dynamic> o;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final source = '${o['source']}';
    final isLead = source == 'lead';
    final value = o['value'];
    final money = value is num && value > 0
        ? NumberFormat.compactCurrency(symbol: 'AED ', decimalDigits: 0).format(value)
        : null;
    final dest = isLead ? '/leads/${o['id']}' : '/viewings/${o['id']}/crm';
    return Card(
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.only(bottom: AppSpacing.x8),
      child: InkWell(
        onTap: () => context.push(dest),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.x12),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: isLead ? AppColors.primaryTint : AppColors.accentGoldTint,
                borderRadius: BorderRadius.circular(AppSpacing.rFull),
              ),
              child: Text(isLead ? 'Lead' : 'Viewing',
                  style: t.labelSmall?.copyWith(
                      color: isLead ? AppColors.primary : AppColors.accentGold, fontWeight: FontWeight.w700)),
            ),
            const SizedBox(width: AppSpacing.x12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${o['title'] ?? '—'}', style: t.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                if ('${o['subtitle'] ?? ''}'.isNotEmpty || money != null)
                  Text([
                    if ('${o['subtitle'] ?? ''}'.isNotEmpty) '${o['subtitle']}',
                    if (money != null) money,
                  ].join('  ·  '), style: t.bodySmall?.copyWith(color: dark ? AppColors.dTextMuted : AppColors.textMuted)),
              ]),
            ),
            const SizedBox(width: AppSpacing.x8),
            StatusBadge(oppStageLabels['${o['stage']}'] ?? '${o['stage']}', tone: _stageTone('${o['stage']}')),
          ]),
        ),
      ),
    );
  }
}
