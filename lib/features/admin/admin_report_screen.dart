import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/i18n/app_localizations.dart';
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

/// GET /admin/integrations → [{key,label,env,active,powers}] — which keys are
/// configured (no secrets), so the admin sees what's live vs dormant.
final _integrationsProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  final d = await ref.read(apiClientProvider).get('/admin/integrations');
  return d is List ? d : [];
});

String _money(num? n) =>
    n == null ? '—' : NumberFormat.compactCurrency(symbol: 'AED ', decimalDigits: n >= 1000 ? 1 : 0).format(n);

class AdminReportScreen extends ConsumerWidget {
  const AdminReportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_adminReportProvider);
    return Scaffold(
      appBar: NuzlAppBar(title: context.tr('Platform Report')),
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
      (context.tr('Users'), '${nv(users, 'total')}', '+${nv(users, 'new_7d')} / 7d · +${nv(users, 'new_30d')} / 30d'),
      (context.tr('Organizations'), '${nv(orgs, 'total')}', '${nv(orgs, 'verified')} ${context.tr('verified')}'),
      (context.tr('Properties'), '${nv(props, 'total')}', '${nv(props, 'verified')} ${context.tr('verified')}'),
      (context.tr('Listings'), '${nv(listings, 'total')}', '${nv(listings, 'live')} ${context.tr('live')}'),
      (context.tr('Deal GMV'), _money(nv(deals, 'gmv')), '${nv(deals, 'won')} ${context.tr('won')} · ${nv(deals, 'active')} ${context.tr('active')}'),
      (context.tr('Commission'), _money(nv(deals, 'commission')), context.tr('on won deals')),
      (context.tr('Marketplace GMV'), _money(nv(market, 'gmv')), '${nv(market, 'orders')} ${context.tr('orders')}'),
      (context.tr('MRR'), _money(nv(revenue, 'mrr')), '${nv(revenue, 'active_subscriptions')} ${context.tr('active subs')}'),
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
        const SizedBox(height: AppSpacing.x12),
        const _IntegrationsCard(),
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
    final steps = <(String, int)>[(context.tr('Leads'), g('leads')), (context.tr('Viewings'), g('viewings')), (context.tr('Offers'), g('offers')), (context.tr('Won'), g('won'))];
    final max = steps.map((s) => s.$2).fold<int>(0, (a, b) => b > a ? b : a);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.x16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(context.tr('Conversion funnel'), style: t.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
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
            steps.first.$2 == 0 ? context.tr('No leads yet.') : '${context.tr('Lead → won')}: ${(g('won') / steps.first.$2 * 100).toStringAsFixed(1)}%',
            style: t.bodySmall?.copyWith(color: muted),
          ),
        ]),
      ),
    );
  }
}

/// Integration readiness — which API keys are configured (Active) vs Dormant,
/// and what each unlocks. Add the env var in Vercel → it flips to Active.
class _IntegrationsCard extends ConsumerWidget {
  const _IntegrationsCard();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final muted = Theme.of(context).hintColor;
    final async = ref.watch(_integrationsProvider);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.x16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(context.tr('Integrations'), style: t.titleSmall?.copyWith(fontWeight: FontWeight.w700))),
            IconButton(
              tooltip: context.tr('Refresh'),
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.refresh, size: 18),
              onPressed: () => ref.invalidate(_integrationsProvider),
            ),
          ]),
          async.when(
            loading: () => const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: LinearProgressIndicator()),
            error: (e, _) => Text(friendlyError(e), style: t.bodySmall?.copyWith(color: muted)),
            data: (list) => Column(
              children: [
                for (final raw in list) _row(context, Map<String, dynamic>.from(raw as Map)),
              ],
            ),
          ),
        ]),
      ),
    );
  }

  Widget _row(BuildContext context, Map<String, dynamic> m) {
    final t = Theme.of(context).textTheme;
    final muted = Theme.of(context).hintColor;
    final active = m['active'] == true;
    final color = active ? Colors.green : muted;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${m['label'] ?? m['key']}', style: t.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
            Text('${m['powers'] ?? ''}', style: t.bodySmall?.copyWith(color: muted)),
            Text('env: ${m['env'] ?? ''}', style: t.bodySmall?.copyWith(color: muted, fontStyle: FontStyle.italic)),
          ]),
        ),
        const SizedBox(width: AppSpacing.x8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(AppSpacing.rFull)),
          child: Text(context.tr(active ? 'Active' : 'Dormant'),
              style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 11)),
        ),
      ]),
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
          Text(context.tr('Subscriptions'), style: t.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: AppSpacing.x8),
          Text('${_money(num.tryParse('${revenue['mrr'] ?? 0}'))} ${context.tr('MRR')} · ${revenue['active_subscriptions'] ?? 0} ${context.tr('active')}',
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
              child: Text(context.tr('No active subscriptions yet.'), style: t.bodySmall?.copyWith(color: muted)),
            ),
        ]),
      ),
    );
  }
}
