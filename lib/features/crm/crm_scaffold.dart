import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../shell/app_shell.dart';

/// The sections of the unified CRM workspace.
enum CrmTab { overview, pipeline, contacts, activities, deals, dealBoard, collaboration, leadMarket, invoicing, insights, analytics, reports }

class CrmTabDef {
  const CrmTabDef(this.tab, this.icon, this.label, this.route);
  final CrmTab tab;
  final IconData icon;
  final String label;
  final String route;
}

/// Single source of truth for the CRM workspace tabs (order = display order).
const List<CrmTabDef> crmTabs = [
  CrmTabDef(CrmTab.overview, Icons.dashboard_outlined, 'Overview', '/crm'),
  CrmTabDef(CrmTab.pipeline, Icons.trending_up, 'Pipeline', '/crm/pipeline'),
  CrmTabDef(CrmTab.contacts, Icons.contacts_outlined, 'Contacts', '/crm/contacts'),
  CrmTabDef(CrmTab.activities, Icons.event_note_outlined, 'Activities', '/crm/activities'),
  CrmTabDef(CrmTab.deals, Icons.handshake_outlined, 'Deals', '/crm/deals'),
  CrmTabDef(CrmTab.dealBoard, Icons.campaign_outlined, 'Deal board', '/crm/deal-board'),
  CrmTabDef(CrmTab.collaboration, Icons.diversity_3_outlined, 'Collaboration', '/crm/collaboration'),
  CrmTabDef(CrmTab.leadMarket, Icons.sell_outlined, 'Lead Market', '/crm/lead-market'),
  CrmTabDef(CrmTab.invoicing, Icons.request_quote_outlined, 'Invoicing', '/crm/invoicing'),
  CrmTabDef(CrmTab.insights, Icons.insights_outlined, 'Insights', '/crm/insights'),
];

CrmTabDef crmTabDef(CrmTab t) => crmTabs.firstWhere((d) => d.tab == t);

/// Shared chrome for every CRM screen. When the current location is inside the
/// CRM workspace (`/crm` or `/crm/*`) it shows the "CRM" app-bar title, a
/// breadcrumb (CRM › Section) and a horizontal tab strip — so the whole CRM
/// area lives under ONE sidebar entry and "CRM" stays highlighted everywhere.
///
/// The very same screens are also reachable as stand-alone routes (e.g.
/// `/reports` for a developer, `/contacts` for a provider). There the CRM
/// chrome is hidden and the screen renders with its own [title], unchanged.
class CrmScaffold extends StatelessWidget {
  const CrmScaffold({
    super.key,
    required this.tab,
    required this.title,
    required this.body,
    this.actions,
    this.floatingActionButton,
    this.embedded = false,
  });

  final CrmTab tab;
  final String title;
  final Widget body;
  final List<Widget>? actions;
  final Widget? floatingActionButton;

  /// When embedded inside another CRM screen (e.g. the Insights tab hosting both
  /// Analytics and Reports), render only the body — no Scaffold/app-bar/tab-strip.
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    if (embedded) return body;
    final loc = GoRouterState.of(context).matchedLocation;
    final inCrm = loc == '/crm' || loc.startsWith('/crm/');
    return Scaffold(
      appBar: NuzlAppBar(title: inCrm ? 'CRM' : title, actions: actions),
      drawer: const NuzlDrawer(),
      floatingActionButton: floatingActionButton,
      body: inCrm
          ? Column(children: [CrmTabStrip(active: tab), Expanded(child: body)])
          : body,
    );
  }
}

/// Breadcrumb + horizontal tab strip rendered at the top of the CRM workspace.
class CrmTabStrip extends StatelessWidget {
  const CrmTabStrip({super.key, required this.active});
  final CrmTab active;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final muted = dark ? AppColors.dTextMuted : AppColors.textMuted;
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor, width: 0.5)),
      ),
      padding: const EdgeInsets.fromLTRB(AppSpacing.x16, AppSpacing.x8, AppSpacing.x16, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Breadcrumb — CRM is tappable back to the workspace overview.
        Row(children: [
          InkWell(
            onTap: () => context.go('/crm'),
            child: Text('CRM', style: t.bodySmall?.copyWith(color: AppColors.primary, fontWeight: FontWeight.w600)),
          ),
          if (active != CrmTab.overview) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Icon(Icons.chevron_right, size: 14, color: muted),
            ),
            Text(crmTabDef(active).label, style: t.bodySmall?.copyWith(color: muted)),
          ],
        ]),
        const SizedBox(height: AppSpacing.x4),
        // Tab strip — current section underlined; tapping navigates within /crm/*.
        SizedBox(
          height: 44,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: crmTabs.length,
            separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.x4),
            itemBuilder: (_, i) {
              final d = crmTabs[i];
              final selected = d.tab == active;
              return InkWell(
                onTap: selected ? null : () => context.go(d.route),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: selected ? AppColors.primary : Colors.transparent, width: 2.5),
                    ),
                  ),
                  child: Row(children: [
                    Icon(d.icon, size: 16, color: selected ? AppColors.primary : muted),
                    const SizedBox(width: 6),
                    Text(d.label,
                        style: t.bodyMedium?.copyWith(
                          color: selected ? AppColors.primary : muted,
                          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                        )),
                  ]),
                ),
              );
            },
          ),
        ),
      ]),
    );
  }
}
