import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/api_client.dart';
import '../../core/rbac/persona.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/responsive.dart';
import '../shell/app_shell.dart';

/// Role-aware reports: each persona hits its own summary endpoint.
String _reportPath(Persona p) => switch (p) {
      Persona.broker || Persona.bank || Persona.provider => '/reports/agency',
      Persona.developer => '/reports/developer',
      Persona.investor || Persona.owner => '/reports/investor',
      Persona.admin => '/admin/overview',
      _ => '/reports/agent', // agent, leadGenerator, salesperson, buyer
    };

final reportsProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final path = _reportPath(ref.watch(personaProvider));
  try {
    final d = await ref.read(apiClientProvider).get(path);
    return d is Map ? Map<String, dynamic>.from(d) : <String, dynamic>{};
  } catch (_) {
    return <String, dynamic>{};
  }
});

/// Per-agent leaderboard for organization-scoped personas (manager/broker view).
final orgLeaderboardProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  try {
    final d = await ref.read(apiClientProvider).get('/reports/org-leaderboard');
    return d is List ? d.map((e) => Map<String, dynamic>.from(e as Map)).toList() : <Map<String, dynamic>>[];
  } catch (_) {
    return <Map<String, dynamic>>[];
  }
});

bool _orgPersona(Persona p) =>
    p == Persona.broker || p == Persona.bank || p == Persona.provider || p == Persona.developer;

class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final report = ref.watch(reportsProvider);
    final persona = ref.watch(personaProvider);
    final showTeam = _orgPersona(persona);
    return Scaffold(
      appBar: const NuzlAppBar(title: 'Reports'),
      drawer: const NuzlDrawer(),
      body: ResponsiveCenter(
        child: report.when(
          loading: () => const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator())),
          error: (e, _) => Center(child: Padding(padding: const EdgeInsets.all(24), child: Text('$e'))),
          data: (m) {
            final entries = m.entries
                .where((e) => e.value is num || num.tryParse('${e.value}') != null)
                .map((e) => MapEntry(_humanize(e.key),
                    e.value is num ? e.value as num : num.tryParse('${e.value}') ?? 0))
                .toList();
            if (entries.isEmpty) {
              return const Center(
                  child: Padding(padding: EdgeInsets.all(40), child: Text('No report data yet.')));
            }
            final maxVal = entries.map((e) => e.value).fold<num>(0, (a, b) => b > a ? b : a);
            return ListView(
              padding: const EdgeInsets.all(AppSpacing.x16),
              children: [
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: AppSpacing.x12,
                  crossAxisSpacing: AppSpacing.x12,
                  childAspectRatio: 1.7,
                  children: entries.map((e) => _StatCard(label: e.key, value: e.value)).toList(),
                ),
                const SizedBox(height: AppSpacing.x24),
                Text('Breakdown', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: AppSpacing.x8),
                ...entries.map((e) => _Bar(label: e.key, value: e.value, max: maxVal)),
                if (showTeam) ...[
                  const SizedBox(height: AppSpacing.x24),
                  Text('Team performance', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: AppSpacing.x8),
                  Consumer(builder: (context, ref, _) {
                    final lb = ref.watch(orgLeaderboardProvider);
                    return lb.when(
                      loading: () => const Padding(
                          padding: EdgeInsets.symmetric(vertical: AppSpacing.x8),
                          child: LinearProgressIndicator()),
                      error: (_, __) => const SizedBox.shrink(),
                      data: (rows) => rows.isEmpty
                          ? const Padding(
                              padding: EdgeInsets.symmetric(vertical: AppSpacing.x8),
                              child: Text('No team members yet.'))
                          : Column(children: [for (final r in rows) _AgentRow(r)]),
                    );
                  }),
                ],
                const SizedBox(height: AppSpacing.x24),
                const Card(
                  child: ListTile(
                    leading: Icon(Icons.file_download_outlined),
                    title: Text('Excel / PDF export'),
                    subtitle: Text('Coming soon.'),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

String _humanize(String k) => k
    .replaceAll('_', ' ')
    .split(' ')
    .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
    .join(' ');

String _fmt(num v) => v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value});
  final String label;
  final num value;
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.x16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_fmt(value),
                style: t.headlineMedium?.copyWith(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w700)),
            const SizedBox(height: AppSpacing.x4),
            Text(label, style: t.bodySmall?.copyWith(color: Theme.of(context).hintColor)),
          ],
        ),
      ),
    );
  }
}

class _AgentRow extends StatelessWidget {
  const _AgentRow(this.r);
  final Map<String, dynamic> r;
  int _n(String k) => int.tryParse('${r[k] ?? 0}') ?? 0;
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final name = '${r['name'] ?? 'Agent'}';
    final designation = '${r['designation'] ?? ''}'.trim();
    Widget chip(String label, int v, Color c) => Padding(
          padding: const EdgeInsets.only(left: AppSpacing.x8),
          child: Column(children: [
            Text('$v', style: t.titleSmall?.copyWith(color: c, fontWeight: FontWeight.w700)),
            Text(label, style: t.labelSmall?.copyWith(color: Theme.of(context).hintColor)),
          ]),
        );
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x16, vertical: AppSpacing.x12),
        child: Row(children: [
          CircleAvatar(
            radius: 18,
            child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?'),
          ),
          const SizedBox(width: AppSpacing.x12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name, style: t.bodyMedium?.copyWith(fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
              if (designation.isNotEmpty)
                Text(designation, style: t.bodySmall?.copyWith(color: Theme.of(context).hintColor)),
            ]),
          ),
          chip('Listings', _n('listings'), AppColors.primary),
          chip('Leads', _n('active_leads'), AppColors.info),
          chip('Deals', _n('active_deals'), AppColors.warning),
          chip('Won', _n('closed_deals'), AppColors.success),
        ]),
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.label, required this.value, required this.max});
  final String label;
  final num value;
  final num max;
  @override
  Widget build(BuildContext context) {
    final frac = max > 0 ? (value / max).clamp(0.0, 1.0).toDouble() : 0.0;
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.x8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(label, style: t.bodyMedium),
            Text(_fmt(value), style: t.bodyMedium),
          ]),
          const SizedBox(height: AppSpacing.x4),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppSpacing.rFull),
            child: LinearProgressIndicator(
              value: frac,
              minHeight: 8,
              backgroundColor: Theme.of(context).dividerColor,
            ),
          ),
        ],
      ),
    );
  }
}
