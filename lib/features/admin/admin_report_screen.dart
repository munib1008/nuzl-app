import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/responsive.dart';
import '../shell/app_shell.dart';

/// GET /admin/report → platform-wide KPIs (users, orgs, properties, listings,
/// deal GMV/commission, marketplace, conversion funnel, subscription MRR).
final _adminReportProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final d = await ref.read(apiClientProvider).get('/admin/report');
  return d is Map ? Map<String, dynamic>.from(d) : <String, dynamic>{};
});

String _money(num? n) =>
    n == null ? '—' : NumberFormat.compactCurrency(symbol: 'AED ', decimalDigits: n >= 1000 ? 1 : 0).format(n);

class AdminReportScreen extends ConsumerWidget {
  const AdminReportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_adminReportProvider);
    return Scaffold(
      appBar: const NuzlAppBar(title: 'Platform Report'),
      drawer: const NuzlDrawer(),
      body: ResponsiveCenter(
        child: RefreshIndicator(
          onRefresh: () async => ref.refresh(_adminReportProvider.future),
          child: async.when(
            loading: () => const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator())),
            error: (e, _) => ListView(children: [Padding(padding: const EdgeInsets.all(24), child: Text(friendlyError(e)))]),
            data: (d) => _body(context, d),
          ),
        ),
      ),
    );
  }

  Widget _body(BuildContext context, Map<String, dynamic> d) {
    Map<String, dynamic> sec(String k) => d[k] is Map ? Map<String, dynamic>.from(d[k] as Map) : const {};
    num nv(Map m, String k) => num.tryParse('${m[k] ?? 0}') ?? 0;
    final users = sec('users'), orgs = sec('organizations'), props = sec('properties');
    final listings = sec('listings'), deals = sec('deals'), market = sec('marketplace');
    final funnel = sec('funnel'), revenue = sec('revenue');

    final kpis = <(String, String, String)>[
      ('Users', '${nv(users, 'total')}', '+${nv(users, 'new_7d')} / 7d · +${nv(users, 'new_30d')} / 30d'),
      ('Organizations', '${nv(orgs, 'total')}', '${nv(orgs, 'verified')} verified'),
      ('Properties', '${nv(props, 'total')}', '${nv(props, 'verified')} verified'),
      ('Listings', '${nv(listings, 'total')}', '${nv(listings, 'live')} live'),
      ('Deal GMV', _money(nv(deals, 'gmv')), '${nv(deals, 'won')} won · ${nv(deals, 'active')} active'),
      ('Commission', _money(nv(deals, 'commission')), 'on won deals'),
      ('Marketplace GMV', _money(nv(market, 'gmv')), '${nv(market, 'orders')} orders'),
      ('MRR', _money(nv(revenue, 'mrr')), '${nv(revenue, 'active_subscriptions')} active subs'),
    ];

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.x16),
      children: [
        GridView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 240, mainAxisSpacing: AppSpacing.x12, crossAxisSpacing: AppSpacing.x12, mainAxisExtent: 96),
          children: [for (final k in kpis) _Kpi(label: k.$1, value: k.$2, sub: k.$3)],
        ),
        const SizedBox(height: AppSpacing.x16),
        _FunnelCard(funnel: funnel),
        const SizedBox(height: AppSpacing.x12),
        _RevenueCard(revenue: revenue),
        const SizedBox(height: AppSpacing.x24),
      ],
    );
  }
}

class _Kpi extends StatelessWidget {
  const _Kpi({required this.label, required this.value, required this.sub});
  final String label, value, sub;
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final muted = Theme.of(context).hintColor;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.x16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(value, style: t.titleLarge?.copyWith(fontWeight: FontWeight.w800, color: Theme.of(context).colorScheme.primary), maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          Text(label, style: t.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
          Text(sub, style: t.bodySmall?.copyWith(color: muted), maxLines: 1, overflow: TextOverflow.ellipsis),
        ]),
      ),
    );
  }
}

class _FunnelCard extends StatelessWidget {
  const _FunnelCard({required this.funnel});
  final Map<String, dynamic> funnel;
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final muted = Theme.of(context).hintColor;
    final primary = Theme.of(context).colorScheme.primary;
    int g(String k) => int.tryParse('${funnel[k] ?? 0}') ?? 0;
    final steps = <(String, int)>[('Leads', g('leads')), ('Viewings', g('viewings')), ('Offers', g('offers')), ('Won', g('won'))];
    final max = steps.map((s) => s.$2).fold<int>(0, (a, b) => b > a ? b : a);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.x16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Conversion funnel', style: t.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: AppSpacing.x12),
          for (final s in steps) ...[
            Row(children: [
              SizedBox(width: 84, child: Text(s.$1, style: t.bodyMedium)),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppSpacing.rFull),
                  child: LinearProgressIndicator(
                    value: max == 0 ? 0 : (s.$2 / max).clamp(0, 1).toDouble(),
                    minHeight: 14, color: primary, backgroundColor: muted.withValues(alpha: 0.12)),
                ),
              ),
              const SizedBox(width: AppSpacing.x8),
              SizedBox(
                width: 64,
                child: Text('${s.$2}', textAlign: TextAlign.right, style: t.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
              ),
            ]),
            const SizedBox(height: AppSpacing.x8),
          ],
          Text(
            steps.first.$2 == 0 ? 'No leads yet.' : 'Lead → won: ${(g('won') / steps.first.$2 * 100).toStringAsFixed(1)}%',
            style: t.bodySmall?.copyWith(color: muted),
          ),
        ]),
      ),
    );
  }
}

class _RevenueCard extends StatelessWidget {
  const _RevenueCard({required this.revenue});
  final Map<String, dynamic> revenue;
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final muted = Theme.of(context).hintColor;
    final plans = (revenue['plans'] is List) ? (revenue['plans'] as List) : const [];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.x16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Subscriptions', style: t.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: AppSpacing.x8),
          Text('${_money(num.tryParse('${revenue['mrr'] ?? 0}'))} MRR · ${revenue['active_subscriptions'] ?? 0} active',
              style: t.bodyMedium),
          if (plans.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.x12),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final p in plans)
                Chip(
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  label: Text('${'${(p as Map)['key'] ?? ''}'.toUpperCase()} · ${p['c'] ?? 0}'),
                ),
            ]),
          ] else
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text('No active subscriptions yet.', style: t.bodySmall?.copyWith(color: muted)),
            ),
        ]),
      ),
    );
  }
}
