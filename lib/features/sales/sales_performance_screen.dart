import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/async_view.dart';
import '../../core/widgets/user_avatar.dart';
import '../shell/app_shell.dart';

final salesMeProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final d = await ref.read(apiClientProvider).get('/marketplace/sales/me');
  return d is Map ? Map<String, dynamic>.from(d) : <String, dynamic>{};
});

final salesTeamProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final d = await ref.read(apiClientProvider).get('/marketplace/sales/team');
  return (d is List ? d : const []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
});

String _money(num? v) => NumberFormat.compactCurrency(symbol: 'AED ', decimalDigits: 0).format(v ?? 0);

/// Marketplace sales performance: the rep's own scorecard + the manager rollup,
/// computed from the inquiries/orders on the items each person is assigned.
class SalesPerformanceScreen extends ConsumerWidget {
  const SalesPerformanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(salesMeProvider);
    final team = ref.watch(salesTeamProvider);
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: NuzlAppBar(title: context.tr('Sales performance')),
      drawer: const NuzlDrawer(),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(salesMeProvider);
          ref.invalidate(salesTeamProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.x16),
          children: [
            Text(context.tr('Your performance'), style: t.titleSmall),
            const SizedBox(height: AppSpacing.x8),
            AsyncView<Map<String, dynamic>>(
              value: me,
              onRetry: () => ref.invalidate(salesMeProvider),
              data: (m) => _MyScorecard(m),
            ),
            const SizedBox(height: AppSpacing.x20),
            Text(context.tr('Team'), style: t.titleSmall),
            const SizedBox(height: AppSpacing.x8),
            AsyncView<List<Map<String, dynamic>>>(
              value: team,
              onRetry: () => ref.invalidate(salesTeamProvider),
              data: (rows) => rows.isEmpty
                  ? Text(context.tr('No team sales activity yet.'),
                      style: t.bodySmall?.copyWith(color: AppColors.textMuted))
                  : Column(children: [for (final r in rows) _TeamRow(r)]),
            ),
          ],
        ),
      ),
    );
  }
}

class _MyScorecard extends StatelessWidget {
  const _MyScorecard(this.m);
  final Map<String, dynamic> m;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final muted = dark ? AppColors.dTextMuted : AppColors.textMuted;
    int n(String k) => int.tryParse('${m[k] ?? 0}') ?? 0;
    final rh = m['avg_response_hours'];
    final stats = <({String label, String value, IconData icon, Color color})>[
      (label: context.tr('Assigned leads'), value: '${n('assigned')}', icon: Icons.inbox_outlined, color: AppColors.primary),
      (label: context.tr('Quotes sent'), value: '${n('quotes_sent')}', icon: Icons.request_quote_outlined, color: AppColors.accentGold),
      (label: context.tr('Orders won'), value: '${n('won')}', icon: Icons.emoji_events_outlined, color: AppColors.success),
      (label: context.tr('Revenue'), value: _money(num.tryParse('${m['revenue']}')), icon: Icons.payments_outlined, color: AppColors.success),
      (label: context.tr('Conversion'), value: '${n('conversion')}%', icon: Icons.trending_up, color: AppColors.primary),
      (label: context.tr('Avg response'), value: rh != null ? '${rh}h' : '—', icon: Icons.timer_outlined, color: AppColors.accentGold),
    ];
    return LayoutBuilder(builder: (context, c) {
      final cols = c.maxWidth >= 720 ? 3 : 2;
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
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(s.icon, size: 18, color: s.color),
                  const Spacer(),
                  Text(s.value, style: t.titleLarge, maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text(s.label, style: t.bodySmall?.copyWith(color: muted), maxLines: 1, overflow: TextOverflow.ellipsis),
                ]),
              ),
            ),
        ],
      );
    });
  }
}

class _TeamRow extends StatelessWidget {
  const _TeamRow(this.r);
  final Map<String, dynamic> r;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final muted = dark ? AppColors.dTextMuted : AppColors.textMuted;
    int n(String k) => int.tryParse('${r[k] ?? 0}') ?? 0;
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.x8),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.x12),
        child: Row(children: [
          UserAvatar(name: '${r['full_name'] ?? '?'}', url: '${r['avatar_url'] ?? ''}', radius: 18),
          const SizedBox(width: AppSpacing.x12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${r['full_name'] ?? context.tr('Member')}', style: t.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
              Text('${n('assigned')} ${context.tr('leads')} · ${n('won')} ${context.tr('won')} · ${n('conversion')}%',
                  style: t.bodySmall?.copyWith(color: muted), maxLines: 1, overflow: TextOverflow.ellipsis),
            ]),
          ),
          const SizedBox(width: AppSpacing.x8),
          Text(_money(num.tryParse('${r['revenue']}')), style: t.titleSmall?.copyWith(color: AppColors.success)),
        ]),
      ),
    );
  }
}
