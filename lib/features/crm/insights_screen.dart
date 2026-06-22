import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/theme/app_spacing.dart';
import '../reports/lead_analytics_screen.dart';
import '../reports/reports_screen.dart';
import 'crm_scaffold.dart';

/// CRM Insights — one place for performance, merging the former Analytics and
/// Reports tabs behind a simple toggle (users didn't know the difference).
class InsightsScreen extends ConsumerStatefulWidget {
  const InsightsScreen({super.key});
  @override
  ConsumerState<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends ConsumerState<InsightsScreen> {
  int _i = 0;

  @override
  Widget build(BuildContext context) {
    return CrmScaffold(
      tab: CrmTab.insights,
      title: 'Insights',
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.x16, AppSpacing.x12, AppSpacing.x16, AppSpacing.x8),
          child: SegmentedButton<int>(
            segments: [
              ButtonSegment(value: 0, label: Text(context.tr('Analytics')), icon: const Icon(Icons.query_stats_outlined)),
              ButtonSegment(value: 1, label: Text(context.tr('Reports')), icon: const Icon(Icons.insights_outlined)),
            ],
            selected: {_i},
            showSelectedIcon: false,
            onSelectionChanged: (s) => setState(() => _i = s.first),
          ),
        ),
        Expanded(
          child: IndexedStack(
            index: _i,
            children: const [
              LeadAnalyticsScreen(embedded: true),
              ReportsScreen(embedded: true),
            ],
          ),
        ),
      ]),
    );
  }
}
