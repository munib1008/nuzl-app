import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/responsive.dart';
import '../shell/app_shell.dart';

/// Finance & ROI — the owner/investor's portfolio investment view (owner module
/// §6). Reuses the portfolio overview (which already computes value, cost, NOI,
/// gross/net yield, appreciation, equity, per-property) and derives the rest
/// (capital gain, total ROI = net yield + appreciation, average occupancy).
final _roiPortfoliosProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  try {
    final d = await ref.read(apiClientProvider).get('/portfolio');
    return d is List ? d : [];
  } catch (_) {
    return [];
  }
});

final _roiOverviewProvider =
    FutureProvider.autoDispose.family<Map<String, dynamic>, String>((ref, id) async {
  try {
    final d = await ref.read(apiClientProvider).get('/portfolio/$id/overview');
    return d is Map ? Map<String, dynamic>.from(d) : <String, dynamic>{};
  } catch (_) {
    return <String, dynamic>{};
  }
});

num? _num(dynamic v) => v is num ? v : num.tryParse('${v ?? ''}');
String _money(dynamic v) {
  final n = _num(v);
  return n == null ? '—' : NumberFormat.compactCurrency(symbol: 'AED ', decimalDigits: 0).format(n);
}

String _pct(dynamic v) {
  final n = _num(v);
  return n == null ? '—' : '${n.toStringAsFixed(1)}%';
}

class FinanceRoiScreen extends ConsumerWidget {
  const FinanceRoiScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pfs = ref.watch(_roiPortfoliosProvider);
    return Scaffold(
      appBar: const NuzlAppBar(title: 'Finance & ROI'),
      drawer: const NuzlDrawer(),
      body: ResponsiveCenter(
        child: pfs.when(
          loading: () => const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator())),
          error: (e, _) => Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(friendlyError(e)))),
          data: (list) {
            if (list.isEmpty) {
              return EmptyState(
                icon: Icons.account_balance_wallet_outlined,
                title: 'No portfolio yet',
                message: 'Add a property in My Properties to track yield, ROI and appreciation.',
                actionLabel: 'My Properties',
                onAction: () => context.go('/my-properties'),
              );
            }
            return _Body(portfolioId: '${(list.first as Map)['id']}');
          },
        ),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.portfolioId});
  final String portfolioId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ov = ref.watch(_roiOverviewProvider(portfolioId));
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(_roiPortfoliosProvider);
        ref.invalidate(_roiOverviewProvider(portfolioId));
      },
      child: ov.when(
        loading: () => const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator())),
        error: (e, _) => ListView(children: [Padding(padding: const EdgeInsets.all(24), child: Text(friendlyError(e)))]),
        data: (m) {
          final tot = m['totals'] is Map ? Map<String, dynamic>.from(m['totals'] as Map) : const <String, dynamic>{};
          final props = m['properties'] is List ? (m['properties'] as List) : const [];
          final marketValue = _num(tot['market_value']) ?? 0;
          final cost = _num(tot['total_cost']) ?? 0;
          final capitalGain = cost > 0 ? marketValue - cost : null;
          final netYield = _num(tot['portfolio_net_yield_pct']);
          final apprec = _num(tot['appreciation_pct']);
          final totalRoi = (netYield != null || apprec != null) ? (netYield ?? 0) + (apprec ?? 0) : null;
          // Average occupancy across properties that report it.
          final occ = props
              .map((e) => _num((e as Map)['occupancy_pct']))
              .whereType<num>()
              .toList();
          final occupancy = occ.isEmpty ? null : occ.reduce((a, b) => a + b) / occ.length;

          final metrics = <({String label, String value, Color color})>[
            (label: 'Market value', value: _money(marketValue), color: AppColors.primary),
            (label: 'Capital gain', value: _money(capitalGain),
                color: (capitalGain ?? 0) >= 0 ? AppColors.success : AppColors.danger),
            (label: 'Appreciation', value: _pct(apprec), color: AppColors.accentGold),
            (label: 'Gross yield', value: _pct(tot['portfolio_gross_yield_pct']), color: AppColors.secondary),
            (label: 'Net yield', value: _pct(netYield), color: AppColors.secondary),
            (label: 'Total ROI', value: _pct(totalRoi), color: AppColors.success),
            (label: 'Net cash flow', value: _money(tot['net_operating_income']), color: AppColors.primary),
            (label: 'Equity', value: _money(tot['equity']), color: AppColors.primary),
            (label: 'Occupancy', value: _pct(occupancy), color: AppColors.statusReady),
          ];

          return ListView(
            padding: const EdgeInsets.all(AppSpacing.x16),
            children: [
              LayoutBuilder(builder: (context, c) {
                final cols = c.maxWidth >= 900 ? 4 : (c.maxWidth >= 560 ? 3 : 2);
                return GridView(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: cols,
                    mainAxisSpacing: AppSpacing.x12,
                    crossAxisSpacing: AppSpacing.x12,
                    mainAxisExtent: 96,
                  ),
                  children: [for (final s in metrics) _MetricCard(label: s.label, value: s.value, color: s.color)],
                );
              }),
              const SizedBox(height: AppSpacing.x20),
              _SummaryCard(tot: tot),
              const SizedBox(height: AppSpacing.x20),
              Text('By property', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: AppSpacing.x8),
              if (props.isEmpty)
                Text('No properties yet.', style: TextStyle(color: Theme.of(context).hintColor))
              else
                ...props.map((e) => _PropRoi(Map<String, dynamic>.from(e as Map))),
              const SizedBox(height: AppSpacing.x16),
              OutlinedButton.icon(
                onPressed: () => context.push('/financials'),
                icon: const Icon(Icons.receipt_long_outlined, size: 18),
                label: const Text('Rental income & cheques'),
              ),
              const SizedBox(height: AppSpacing.x24),
            ],
          );
        },
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.label, required this.value, required this.color});
  final String label;
  final String value;
  final Color color;
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final muted = dark ? AppColors.dTextMuted : AppColors.textMuted;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.x12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(value, style: t.titleLarge?.copyWith(color: color, fontWeight: FontWeight.w700),
              maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          Text(label, style: t.bodySmall?.copyWith(color: muted), maxLines: 1, overflow: TextOverflow.ellipsis),
        ]),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.tot});
  final Map<String, dynamic> tot;
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final muted = dark ? AppColors.dTextMuted : AppColors.textMuted;
    Widget row(String k, String v) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(k, style: t.bodyMedium?.copyWith(color: muted)),
            Text(v, style: t.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
          ]),
        );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.x16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Cost basis & cash', style: t.titleSmall),
          const SizedBox(height: AppSpacing.x8),
          row('Total cost (purchase)', _money(tot['total_cost'])),
          row('Gross income (annual)', _money(tot['gross_income'])),
          row('Operating expenses', _money(tot['total_expenses'])),
          row('Outstanding debt', _money(tot['outstanding_debt'])),
        ]),
      ),
    );
  }
}

class _PropRoi extends StatelessWidget {
  const _PropRoi(this.p);
  final Map<String, dynamic> p;
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final muted = dark ? AppColors.dTextMuted : AppColors.textMuted;
    final title = [p['community'], p['property_type'], p['bedrooms'] != null ? '${p['bedrooms']}BR' : null]
        .where((e) => e != null && '$e'.trim().isNotEmpty)
        .join(' · ');
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.x8),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.x12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(title.isEmpty ? 'Property' : title, style: t.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis)),
            Text(_money(p['current_value']), style: t.titleSmall?.copyWith(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 4),
          Text(
            'Net yield ${_pct(p['net_yield_pct'])}  ·  Gross ${_pct(p['gross_yield_pct'])}  ·  NOI ${_money(p['noi'])}  ·  Equity ${_money(p['equity'])}',
            style: t.bodySmall?.copyWith(color: muted),
          ),
        ]),
      ),
    );
  }
}
