import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/app_dialog.dart';

final _myKpiProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final d = await ref.read(apiClientProvider).get('/kpi/me');
  return d is Map ? Map<String, dynamic>.from(d) : <String, dynamic>{};
});

/// Manager rollup. Non-managers get 403 → null (no Team section shown).
final _orgKpiProvider = FutureProvider.autoDispose<Map<String, dynamic>?>((ref) async {
  try {
    final d = await ref.read(apiClientProvider).get('/kpi/org');
    return d is Map ? Map<String, dynamic>.from(d) : null;
  } catch (_) {
    return null;
  }
});

const _metricLabels = <String, String>{
  'leads': 'Leads',
  'viewings': 'Viewings',
  'offers': 'Offers',
  'deals': 'Closed deals',
  'sales_value': 'Sales value',
};

/// Human turnaround time: minutes under an hour, else hours.
String _fmtHours(dynamic h) {
  final v = num.tryParse('$h') ?? 0;
  if (v <= 0) return '—';
  if (v < 1) return '${(v * 60).round()} min';
  return '${v.toStringAsFixed(v < 10 ? 1 : 0)}h';
}

Color _statusColor(String s) {
  switch (s) {
    case 'Outstanding':
      return AppColors.success;
    case 'On Track':
      return AppColors.primary;
    case 'At Risk':
      return AppColors.accentGold;
    case 'Below Target':
      return AppColors.danger;
    default:
      return AppColors.textMuted;
  }
}

class KpiScreen extends ConsumerWidget {
  const KpiScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(_myKpiProvider);
    final org = ref.watch(_orgKpiProvider);
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('Performance'))),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(_myKpiProvider);
          ref.invalidate(_orgKpiProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.x16),
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                me.when(
                  data: (m) => _Scorecard(m),
                  loading: () => const Padding(
                      padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator())),
                  error: (e, _) => Text(friendlyError(e)),
                ),
                org.maybeWhen(
                  data: (o) => o == null ? const SizedBox.shrink() : _TeamLeaderboard(o),
                  orElse: () => const SizedBox.shrink(),
                ),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

class _Scorecard extends StatelessWidget {
  const _Scorecard(this.data);
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final metrics = (data['metrics'] is Map) ? Map<String, dynamic>.from(data['metrics']) : <String, dynamic>{};
    final overall = data['overall'];
    final status = '${data['status'] ?? 'No target'}';
    final hasTarget = data['has_target'] == true && overall != null;
    final periodStart = '${data['period_start'] ?? ''}';
    final monthLabel = periodStart.length >= 7
        ? DateFormat('MMMM yyyy').format(DateTime.tryParse(periodStart) ?? DateTime(2026))
        : context.tr('This month');

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(context.tr('My scorecard'), style: t.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
      Text(monthLabel, style: t.bodySmall?.copyWith(color: AppColors.textMuted)),
      const SizedBox(height: AppSpacing.x12),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.x16),
        decoration: BoxDecoration(
          color: _statusColor(status).withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppSpacing.rCard),
          border: Border.all(color: _statusColor(status).withValues(alpha: 0.25)),
        ),
        child: hasTarget
            ? Row(children: [
                Text('${(num.tryParse('$overall') ?? 0).toStringAsFixed(0)}%',
                    style: t.displaySmall?.copyWith(fontWeight: FontWeight.w800, color: _statusColor(status))),
                const SizedBox(width: AppSpacing.x16),
                Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                  Text(context.tr('Overall achievement'), style: t.bodySmall?.copyWith(color: AppColors.textMuted)),
                  const SizedBox(height: 2),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                        color: _statusColor(status), borderRadius: BorderRadius.circular(AppSpacing.rFull)),
                    child: Text(context.tr(status), style: t.labelMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
                  ),
                ]),
              ])
            : Row(children: [
                const Icon(Icons.flag_outlined, color: AppColors.textMuted),
                const SizedBox(width: AppSpacing.x8),
                Expanded(child: Text(context.tr('No target set for this month yet — your manager assigns KPI targets.'),
                    style: t.bodyMedium?.copyWith(color: AppColors.textMuted))),
              ]),
      ),
      if (data['avg_response_hours'] != null) ...[
        const SizedBox(height: AppSpacing.x8),
        Row(children: [
          const Icon(Icons.timer_outlined, size: 16, color: AppColors.textMuted),
          const SizedBox(width: 6),
          Text('${context.tr('Avg response (TAT)')}: ${_fmtHours(data['avg_response_hours'])}',
              style: t.bodySmall?.copyWith(color: AppColors.textMuted)),
        ]),
      ],
      const SizedBox(height: AppSpacing.x16),
      for (final key in _metricLabels.keys)
        if (metrics[key] is Map) _MetricRow(label: context.tr(_metricLabels[key]!), m: Map<String, dynamic>.from(metrics[key]), money: key == 'sales_value'),
    ]);
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({required this.label, required this.m, this.money = false});
  final String label;
  final Map<String, dynamic> m;
  final bool money;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final target = num.tryParse('${m['target'] ?? 0}') ?? 0;
    final actual = num.tryParse('${m['actual'] ?? 0}') ?? 0;
    final pct = m['pct'];
    final frac = target > 0 ? (actual / target).clamp(0.0, 1.0).toDouble() : 0.0;
    final fmt = money
        ? NumberFormat.compactCurrency(symbol: 'AED ', decimalDigits: 0)
        : NumberFormat.decimalPattern();
    final reached = target > 0 && actual >= target;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.x12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(label, style: t.bodyMedium?.copyWith(fontWeight: FontWeight.w600))),
          Text('${fmt.format(actual)} / ${fmt.format(target)}',
              style: t.bodySmall?.copyWith(color: AppColors.textMuted)),
          if (pct != null) ...[
            const SizedBox(width: AppSpacing.x8),
            Text('${(num.tryParse('$pct') ?? 0).toStringAsFixed(0)}%',
                style: t.bodySmall?.copyWith(fontWeight: FontWeight.w700, color: reached ? AppColors.success : AppColors.textMuted)),
          ],
        ]),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppSpacing.rFull),
          child: LinearProgressIndicator(
            value: frac,
            minHeight: 7,
            backgroundColor: AppColors.textMuted.withValues(alpha: 0.15),
            valueColor: AlwaysStoppedAnimation(reached ? AppColors.success : AppColors.primary),
          ),
        ),
      ]),
    );
  }
}

class _TeamLeaderboard extends ConsumerWidget {
  const _TeamLeaderboard(this.data);
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final members = (data['members'] is List) ? data['members'] as List : const [];
    final team = (data['team_actual'] is Map) ? Map<String, dynamic>.from(data['team_actual']) : <String, dynamic>{};
    final money = NumberFormat.compactCurrency(symbol: 'AED ', decimalDigits: 0);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SizedBox(height: AppSpacing.x24),
      Row(children: [
        const Icon(Icons.leaderboard_outlined, size: 20, color: AppColors.primary),
        const SizedBox(width: AppSpacing.x8),
        Text(context.tr('Team performance'), style: t.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
      ]),
      const SizedBox(height: AppSpacing.x4),
      Text('${context.tr('This month')} · ${money.format(num.tryParse('${team['sales_value'] ?? 0}') ?? 0)} ${context.tr('sales')} · '
          '${team['deals'] ?? 0} ${context.tr('deals')} · ${team['viewings'] ?? 0} ${context.tr('viewings')} · ${team['leads'] ?? 0} ${context.tr('leads')}',
          style: t.bodySmall?.copyWith(color: AppColors.textMuted)),
      const SizedBox(height: AppSpacing.x12),
      for (var i = 0; i < members.length; i++)
        _LeaderRow(rank: i + 1, m: Map<String, dynamic>.from(members[i] as Map)),
    ]);
  }
}

class _LeaderRow extends ConsumerWidget {
  const _LeaderRow({required this.rank, required this.m});
  final int rank;
  final Map<String, dynamic> m;

  Future<void> _setTarget(BuildContext context, WidgetRef ref) async {
    final leads = TextEditingController(text: '50');
    final viewings = TextEditingController(text: '20');
    final offers = TextEditingController(text: '10');
    final deals = TextEditingController(text: '5');
    final sales = TextEditingController(text: '5000000');
    final ok = await AppDialog.show<bool>(
      context,
      title: '${context.tr('Set monthly target')} — ${m['full_name'] ?? context.tr('agent')}',
      maxWidth: 420,
      children: [
        Column(mainAxisSize: MainAxisSize.min, children: [
          for (final f in [
            ('Leads', leads),
            ('Viewings', viewings),
            ('Offers', offers),
            ('Closed deals', deals),
            ('Sales value (AED)', sales),
          ]) ...[
            TextField(controller: f.$2, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: context.tr(f.$1))),
            const SizedBox(height: AppSpacing.x8),
          ],
        ]),
      ],
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: Text(context.tr('Cancel'))),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(context.tr('Save target'))),
      ],
    );
    if (ok != true) return;
    try {
      await ref.read(apiClientProvider).post('/kpi/targets', body: {
        'user_id': m['user_id'],
        'period': 'month',
        'leads_target': int.tryParse(leads.text.trim()) ?? 0,
        'viewings_target': int.tryParse(viewings.text.trim()) ?? 0,
        'offers_target': int.tryParse(offers.text.trim()) ?? 0,
        'deals_target': int.tryParse(deals.text.trim()) ?? 0,
        'sales_value_target': num.tryParse(sales.text.trim()) ?? 0,
      });
      ref.invalidate(_orgKpiProvider);
      ref.invalidate(_myKpiProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.tr('Target saved'))));
      }
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final name = '${m['full_name'] ?? context.tr('Agent')}';
    final avatar = '${m['avatar_url'] ?? ''}';
    final status = '${m['status'] ?? 'No target'}';
    final overall = m['overall'];
    final teamRole = '${m['team_role'] ?? ''}'.replaceAll('_', ' ');
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.x8),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.x12),
        child: Row(children: [
          SizedBox(width: 24, child: Text('$rank', style: t.titleMedium?.copyWith(fontWeight: FontWeight.w800, color: AppColors.textMuted))),
          CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.primary,
            backgroundImage: avatar.isNotEmpty ? NetworkImage(avatar) : null,
            child: avatar.isEmpty
                ? Text((name.isNotEmpty ? name[0] : '?').toUpperCase(),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700))
                : null,
          ),
          const SizedBox(width: AppSpacing.x12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text(name, style: t.bodyLarge?.copyWith(fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
              Text([
                if (teamRole.trim().isNotEmpty) teamRole,
                if (m['avg_response_hours'] != null) '${context.tr('TAT')} ${_fmtHours(m['avg_response_hours'])}',
              ].join('  ·  '), maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: t.bodySmall?.copyWith(color: AppColors.textMuted)),
            ]),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, mainAxisSize: MainAxisSize.min, children: [
            Text(overall == null ? '—' : '${(num.tryParse('$overall') ?? 0).toStringAsFixed(0)}%',
                style: t.titleMedium?.copyWith(fontWeight: FontWeight.w800, color: _statusColor(status))),
            Text(context.tr(status), style: t.bodySmall?.copyWith(color: _statusColor(status))),
          ]),
          IconButton(
            tooltip: context.tr('Set target'),
            icon: const Icon(Icons.flag_outlined, size: 20),
            onPressed: () => _setTarget(context, ref),
          ),
        ]),
      ),
    );
  }
}
