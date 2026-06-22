import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/async_view.dart';
import '../opportunities/opportunities_repository.dart';
import 'crm_scaffold.dart';

/// CRM workspace landing — a KPI snapshot of the pipeline plus quick entry to
/// every CRM section. This is the default page when CRM is opened from the
/// sidebar; the sections live behind the tab strip (see [CrmScaffold]).
class CrmWorkspaceScreen extends ConsumerWidget {
  const CrmWorkspaceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final opps = ref.watch(opportunitiesProvider);
    return CrmScaffold(
      tab: CrmTab.overview,
      title: 'CRM',
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(opportunitiesProvider),
        child: AsyncView<List<Map<String, dynamic>>>(
          value: opps,
          onRetry: () => ref.invalidate(opportunitiesProvider),
          data: (list) => ListView(
            padding: const EdgeInsets.all(AppSpacing.x16),
            children: [
              _Kpis(list: list),
              const SizedBox(height: AppSpacing.x20),
              Text(context.tr('Workspace'), style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: AppSpacing.x12),
              const _SectionGrid(),
            ],
          ),
        ),
      ),
    );
  }
}

class _Kpis extends StatelessWidget {
  const _Kpis({required this.list});
  final List<Map<String, dynamic>> list;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final muted = dark ? AppColors.dTextMuted : AppColors.textMuted;
    var won = 0, lost = 0;
    num pipelineValue = 0;
    for (final o in list) {
      final stage = '${o['stage']}';
      if (stage == 'closed_won') {
        won++;
      } else if (stage == 'closed_lost') {
        lost++;
      }
      final v = o['value'];
      if (stage != 'closed_lost' && v is num) pipelineValue += v;
    }
    final active = list.length - won - lost;
    final value = pipelineValue > 0
        ? NumberFormat.compactCurrency(symbol: 'AED ', decimalDigits: 0).format(pipelineValue)
        : 'AED 0';
    final stats = <({String label, String value, IconData icon, Color color})>[
      (label: 'Open pipeline', value: '$active', icon: Icons.trending_up, color: AppColors.primary),
      (label: 'Pipeline value', value: value, icon: Icons.payments_outlined, color: AppColors.accentGold),
      (label: 'Won', value: '$won', icon: Icons.emoji_events_outlined, color: AppColors.success),
      (label: 'Lost', value: '$lost', icon: Icons.cancel_outlined, color: AppColors.danger),
    ];
    return LayoutBuilder(builder: (context, c) {
      final cols = c.maxWidth >= 720 ? 4 : 2;
      // Fixed card HEIGHT (mainAxisExtent), not a width-ratio — otherwise wide
      // desktop columns stretch the cards into tall, mostly-empty boxes.
      return GridView(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: cols,
          mainAxisSpacing: AppSpacing.x12,
          crossAxisSpacing: AppSpacing.x12,
          mainAxisExtent: 104,
        ),
        children: [
          for (final s in stats)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.x16),
                child: Row(children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(s.value, style: t.displaySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: AppSpacing.x4),
                        Text(context.tr(s.label), style: t.bodySmall?.copyWith(color: muted), maxLines: 1, overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.x8),
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.x8),
                    decoration: BoxDecoration(color: s.color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(AppSpacing.rMd)),
                    child: Icon(s.icon, size: 18, color: s.color),
                  ),
                ]),
              ),
            ),
        ],
      );
    });
  }
}

class _SectionGrid extends StatelessWidget {
  const _SectionGrid();

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final muted = dark ? AppColors.dTextMuted : AppColors.textMuted;
    // Every CRM section except Overview itself, with a one-line description.
    const blurbs = <CrmTab, String>{
      CrmTab.pipeline: 'Leads & viewings by stage',
      CrmTab.contacts: 'Everyone you work with',
      CrmTab.activities: 'Calls, meetings & notes',
      CrmTab.deals: 'Track deals to close',
      CrmTab.dealBoard: 'Broadcast & co-broke deals',
      CrmTab.collaboration: 'Work referrals with partners',
      CrmTab.leadMarket: 'Buy & sell marketplace leads',
      CrmTab.invoicing: 'Quotations & invoices for clients',
      CrmTab.insights: 'Analytics & exportable reports',
    };
    final tiles = crmTabs.where((d) => d.tab != CrmTab.overview).toList();
    return LayoutBuilder(builder: (context, c) {
      final cols = c.maxWidth >= 900 ? 3 : (c.maxWidth >= 560 ? 2 : 1);
      // Fixed tile HEIGHT so wide columns don't inflate the launchpad cards.
      return GridView(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: cols,
          mainAxisSpacing: AppSpacing.x12,
          crossAxisSpacing: AppSpacing.x12,
          mainAxisExtent: 92,
        ),
        children: [
          for (final d in tiles)
            Card(
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => context.go(d.route),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.x16),
                  child: Row(children: [
                    CircleAvatar(radius: 18, backgroundColor: AppColors.primaryTint, child: Icon(d.icon, size: 18, color: AppColors.primary)),
                    const SizedBox(width: AppSpacing.x12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                        Text(context.tr(d.label), style: t.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                        Text(blurbs[d.tab] == null ? '' : context.tr(blurbs[d.tab]!), style: t.bodySmall?.copyWith(color: muted), maxLines: 2, overflow: TextOverflow.ellipsis),
                      ]),
                    ),
                    Icon(Icons.chevron_right, size: 18, color: muted),
                  ]),
                ),
              ),
            ),
        ],
      );
    });
  }
}
