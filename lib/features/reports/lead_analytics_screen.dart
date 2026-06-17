import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/api_client.dart';
import '../../core/rbac/persona.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/async_view.dart';
import '../../core/widgets/responsive.dart';
import '../shell/app_shell.dart';

final leadAnalyticsProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final persona = ref.watch(personaProvider);
  final scope = (persona == Persona.broker || persona == Persona.admin) ? 'org' : 'agent';
  try {
    final d = await ref.read(apiClientProvider).get('/reports/lead-analytics', query: {'scope': scope});
    return d is Map ? Map<String, dynamic>.from(d) : <String, dynamic>{};
  } catch (_) {
    return <String, dynamic>{};
  }
});

/// Conversion funnel + lost-lead analytics (enterprise-CRM).
class LeadAnalyticsScreen extends ConsumerWidget {
  const LeadAnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final data = ref.watch(leadAnalyticsProvider);
    int n(Map m, String k) => int.tryParse('${m[k] ?? 0}') ?? 0;
    return Scaffold(
      appBar: const NuzlAppBar(title: 'Lead analytics'),
      drawer: const NuzlDrawer(),
      body: ResponsiveCenter(
        child: RefreshIndicator(
          onRefresh: () async => ref.invalidate(leadAnalyticsProvider),
          child: AsyncView<Map<String, dynamic>>(
            value: data,
            onRetry: () => ref.invalidate(leadAnalyticsProvider),
            data: (m) {
              final total = n(m, 'total');
              if (total == 0) {
                return ListView(children: [
                  Padding(
                    padding: const EdgeInsets.all(48),
                    child: Center(child: Text('No leads to analyse yet.',
                        style: t.bodyMedium?.copyWith(color: AppColors.textMuted))),
                  ),
                ]);
              }
              final rate = n(m, 'conversion_rate');
              final sources = (m['by_source'] is List) ? (m['by_source'] as List) : const [];
              final labels = (m['labels'] is List) ? (m['labels'] as List) : const [];
              final conv = (m['converted_series'] is List) ? (m['converted_series'] as List) : const [];
              final lost = (m['lost_series'] is List) ? (m['lost_series'] as List) : const [];
              return ListView(
                padding: const EdgeInsets.all(AppSpacing.x16),
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.x16),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Conversion rate', style: t.bodyMedium?.copyWith(color: AppColors.textMuted)),
                        Text('$rate%',
                            style: t.displaySmall?.copyWith(color: AppColors.primary, fontWeight: FontWeight.w700)),
                        Text('of decided leads converted (won vs lost)',
                            style: t.bodySmall?.copyWith(color: AppColors.textMuted)),
                      ]),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.x12),
                  Row(children: [
                    _stat('Total', total, AppColors.primary, t),
                    _stat('Active', n(m, 'active'), AppColors.info, t),
                    _stat('Won', n(m, 'converted'), AppColors.success, t),
                    _stat('Lost', n(m, 'lost'), AppColors.danger, t),
                  ]),
                  const SizedBox(height: AppSpacing.x24),
                  if (labels.isNotEmpty) ...[
                    Text('Won vs lost (6 months)', style: t.titleMedium),
                    const SizedBox(height: AppSpacing.x8),
                    _TrendBars(labels: labels, converted: conv, lost: lost),
                    const SizedBox(height: AppSpacing.x24),
                  ],
                  Text('By source', style: t.titleMedium),
                  const SizedBox(height: AppSpacing.x8),
                  if (sources.isEmpty)
                    Text('No source data.', style: t.bodySmall?.copyWith(color: AppColors.textMuted))
                  else
                    ...sources.map((s) {
                      final sm = Map<String, dynamic>.from(s as Map);
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(children: [
                          Expanded(child: Text('${sm['source']}', style: t.bodyMedium)),
                          Text('${sm['total']} total', style: t.bodySmall?.copyWith(color: AppColors.textMuted)),
                          const SizedBox(width: AppSpacing.x12),
                          Text('${sm['converted']} won',
                              style: t.bodySmall?.copyWith(color: AppColors.success, fontWeight: FontWeight.w600)),
                          const SizedBox(width: AppSpacing.x8),
                          Text('${sm['lost']} lost',
                              style: t.bodySmall?.copyWith(color: AppColors.danger, fontWeight: FontWeight.w600)),
                        ]),
                      );
                    }),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _stat(String label, int value, Color color, TextTheme t) => Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('$value', style: t.titleLarge?.copyWith(color: color, fontWeight: FontWeight.w700)),
          Text(label, style: t.bodySmall?.copyWith(color: AppColors.textMuted)),
        ]),
      );
}

/// Compact grouped bars: converted (green) vs lost (red) per month.
class _TrendBars extends StatelessWidget {
  const _TrendBars({required this.labels, required this.converted, required this.lost});
  final List labels;
  final List converted;
  final List lost;

  int _v(List l, int i) => i < l.length ? (int.tryParse('${l[i]}') ?? 0) : 0;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    var max = 1;
    for (var i = 0; i < labels.length; i++) {
      max = [max, _v(converted, i), _v(lost, i)].reduce((a, b) => a > b ? a : b);
    }
    return SizedBox(
      height: 140,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                Row(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
                  _bar(_v(converted, i), max, AppColors.success),
                  const SizedBox(width: 3),
                  _bar(_v(lost, i), max, AppColors.danger),
                ]),
                const SizedBox(height: 4),
                Text('${labels[i]}', style: t.labelSmall?.copyWith(color: AppColors.textMuted)),
              ]),
            ),
        ],
      ),
    );
  }

  Widget _bar(int value, int max, Color color) {
    final h = (value / max * 100).clamp(2.0, 100.0);
    return Container(
      width: 12,
      height: h,
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
    );
  }
}
