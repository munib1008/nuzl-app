import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/network/api_client.dart';
import '../../core/rbac/persona.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_elevation.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/hover_lift.dart';
import '../../core/widgets/hover_zoom_image.dart';
import '../../core/widgets/status_badge.dart';
import '../auth/application/auth_controller.dart';
import '../projects/projects_screen.dart' show projectsProvider;
import '../shell/app_shell.dart';

/// Role-appropriate KPI report. Graceful: {} on error / no permission.
final dashboardProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final persona = ref.watch(personaProvider);
  final endpoint = switch (persona) {
    Persona.broker => '/reports/agency',
    Persona.developer => '/reports/developer',
    Persona.owner => '/reports/owner',
    Persona.investor => '/reports/investor',
    Persona.admin => '/admin/overview',
    _ => '/reports/agent',
  };
  try {
    final d = await ref.read(apiClientProvider).get(endpoint);
    return (d is Map) ? Map<String, dynamic>.from(d) : {};
  } catch (_) {
    return {};
  }
});

/// Recommended properties for a buyer — latest visible listings. Empty on error.
final _recommendedProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  try {
    final d = await ref.read(apiClientProvider).get('/listings', query: {'limit': '8', 'sort': 'newest'});
    return d is List ? d.map((e) => Map<String, dynamic>.from(e as Map)).toList() : <Map<String, dynamic>>[];
  } catch (_) {
    return <Map<String, dynamic>>[];
  }
});

/// Market intelligence — latest community snapshots (avg asking price, rental
/// trend, occupancy). Empty list on error / no data so the widget hides cleanly.
final _marketIntelProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  try {
    final d = await ref.read(apiClientProvider).get('/intelligence/latest');
    return d is List ? d.map((e) => Map<String, dynamic>.from(e as Map)).toList() : <Map<String, dynamic>>[];
  } catch (_) {
    return <Map<String, dynamic>>[];
  }
});

/// Buyer KPI counters — saved properties, viewings, saved searches, mortgages
/// tracked. Each endpoint is counted independently and fails soft to 0 so a
/// missing/forbidden route never blanks the row.
final _buyerKpisProvider = FutureProvider.autoDispose<Map<String, int>>((ref) async {
  final api = ref.read(apiClientProvider);
  Future<int> count(String path) async {
    try {
      final d = await api.get(path);
      if (d is List) return d.length;
      if (d is Map && d['count'] is num) return (d['count'] as num).toInt();
      return 0;
    } catch (_) {
      return 0;
    }
  }

  final r = await Future.wait([
    count('/listings/saved/mine'),
    count('/viewings'),
    count('/saved-searches'),
    count('/finance-scenarios'), // customers plan finance, they don't track loans
  ]);
  return {'saved': r[0], 'viewings': r[1], 'searches': r[2], 'finance': r[3]};
});

/// Monthly sales series for the Sales overview chart. Scope is decided by the
/// API from the caller's role (own deals for an agent, whole-org for a broker /
/// admin). Returns an EMPTY series when there's no real data — the card then
/// shows an honest empty state rather than fabricated numbers (audit 2026-06-17).
final _salesSeriesProvider = FutureProvider.autoDispose<List<double>>((ref) async {
  final persona = ref.watch(personaProvider);
  final scope = (persona == Persona.broker || persona == Persona.admin) ? 'org' : 'agent';
  try {
    final d = await ref.read(apiClientProvider).get('/reports/sales-series?scope=$scope');
    if (d is Map && d['series'] is List) {
      final s = (d['series'] as List).map((e) => (num.tryParse('$e') ?? 0).toDouble()).toList();
      if (s.length >= 2 && s.any((v) => v > 0)) return s;
    }
  } catch (_) {}
  return const <double>[];
});

final _recentListingsProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  try {
    final d = await ref.read(apiClientProvider).get('/listings');
    return d is List ? d.take(8).toList() : [];
  } catch (_) {
    return [];
  }
});

final _activityProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  try {
    final d = await ref.read(apiClientProvider).get('/notifications');
    return d is List ? d.take(5).toList() : [];
  } catch (_) {
    return [];
  }
});

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final persona = ref.watch(personaProvider);
    final user = ref.watch(authControllerProvider).user;
    final data = ref.watch(dashboardProvider);
    final cards = _cardsFor(persona, data.asData?.value ?? {});
    final wide = MediaQuery.of(context).size.width >= 1000;
    final isBuyer = persona == Persona.buyer;
    final overview = _overviewCard(persona, data.asData?.value ?? {});
    final hour = DateTime.now().hour;
    final greet = hour < 12 ? 'Good morning' : (hour < 17 ? 'Good afternoon' : 'Good evening');
    final gutter = wide ? AppSpacing.x32 : AppSpacing.x20;

    return Scaffold(
      // No "Dashboard" title — the nav already says where you are (Stripe/Linear style).
      appBar: const NuzlAppBar(),
      drawer: const NuzlDrawer(),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(dashboardProvider);
          ref.invalidate(_recentListingsProvider);
          ref.invalidate(_activityProvider);
        },
        child: ListView(
          padding: EdgeInsets.fromLTRB(gutter, AppSpacing.x24, gutter, AppSpacing.x24),
          children: [
            // Time-based greeting — the page heading (no redundant "Dashboard").
            Text('$greet${user?.fullName.isNotEmpty == true ? ', ${user!.fullName.split(' ').first}' : ''}',
                style: t.headlineSmall),
            const SizedBox(height: 2),
            Text(isBuyer ? 'Discover and track your next property.' : "Here's what's happening today.",
                style: t.bodyMedium?.copyWith(color: Theme.of(context).brightness == Brightness.dark ? AppColors.dTextMuted : AppColors.textMuted)),
            // Property search lives in the Properties tab (single search surface) —
            // the dashboard is for tracking, not discovery.
            if (user?.pendingDeletion == true) ...[
              const SizedBox(height: AppSpacing.x16),
              _DeletionBanner(deletionAt: user!.deletionAt),
            ],
            const SizedBox(height: AppSpacing.x24),

            // 1) Headline metrics.
            if (isBuyer) ...[
              _BuyerKpis(wide: wide),
              const SizedBox(height: AppSpacing.x24),
            ] else if (cards.isNotEmpty) ...[
              _KpiGrid(cards: cards, wide: wide),
              const SizedBox(height: AppSpacing.x24),
            ],

            // 2) Primary tasks — the actions a user actually performs, up top
            // (above the search banner for customers).
            _twoUp(wide, flexA: 1,
                a: _PanelCard(title: 'Quick actions', child: _QuickActions(persona: persona)),
                b: _PanelCard(title: 'Tools', child: _ToolsList(persona: persona))),
            const SizedBox(height: AppSpacing.x24),

            // 3) Buyer search banner.
            if (isBuyer) ...[
              const _BuyerCta(),
              const SizedBox(height: AppSpacing.x24),
            ],

            // 4) Analytics + activity — sales chart (agent/broker/admin) or ROI
            // (owner) paired with the activity feed.
            if (overview != null) ...[
              _twoUp(wide, flexA: 2, a: overview, b: const _ActivityCard()),
              const SizedBox(height: AppSpacing.x24),
            ],

            // 5) Properties — buyers get recommendations; other browsing roles
            // get recent listings; owners care about owned assets, not these.
            if (isBuyer) const _RecommendedProperties(),
            // Marketplace strip — shows NUZL is more than listings (services + products).
            if (isBuyer) const _MarketplaceStrip(),
            // Developers manage ONLY their own projects — never the public market
            // (Access Rules). Agents/brokers browse the market they sell, so they
            // still get recent listings; developers get their own projects instead.
            if (!isBuyer && persona != Persona.owner && persona != Persona.developer) ...[
              const _RecentProperties(),
              const SizedBox(height: AppSpacing.x24),
            ],
            if (persona == Persona.developer) ...[
              const _DeveloperProjects(),
              const SizedBox(height: AppSpacing.x24),
            ],
            // Owner command centre — portfolio/viewing/document stats + the agents
            // working your properties (merged in from the retired Owner Cockpit).
            if (persona == Persona.owner) ...[
              const _OwnerCockpit(),
              const SizedBox(height: AppSpacing.x24),
            ],

            // 6) Market insights (buyer).
            if (isBuyer) const _MarketIntelligence(),

            // 7) Recent activity at the bottom for roles without a chart.
            if (overview == null) const _ActivityCard(),
          ],
        ),
      ),
    );
  }

  Widget _twoUp(bool wide, {required Widget a, required Widget b, int flexA = 1}) {
    if (!wide) return Column(children: [a, const SizedBox(height: AppSpacing.x16), b]);
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Expanded(flex: flexA, child: a),
      const SizedBox(width: AppSpacing.x16),
      Expanded(flex: 1, child: b),
    ]);
  }

  /// The middle overview panel. Sales overview for sales roles (agent =
  /// personal, broker/admin = organization), ROI for owners only, and nothing
  /// for the remaining roles ("for owner roi and for others no need this graph").
  Widget? _overviewCard(Persona p, Map<String, dynamic> data) {
    switch (p) {
      case Persona.agent:
        return const _SalesCard(title: 'Sales overview');
      case Persona.broker:
      case Persona.admin:
        return const _SalesCard(title: 'Sales overview · Organization');
      case Persona.owner:
        return const _PortfolioPerformance();
      default:
        return null;
    }
  }

  List<_Card> _cardsFor(Persona p, Map<String, dynamic> d) {
    num g(String k) => (d[k] is num) ? d[k] as num : num.tryParse('${d[k]}') ?? 0;
    String aed(num v) => 'AED ${NumberFormat.compact().format(v)}';
    switch (p) {
      case Persona.broker:
        return [
          _Card('Active leads', '${g('active_leads')}', Icons.trending_up, AppColors.secondary),
          _Card('Active deals', '${g('active_deals')}', Icons.handshake_outlined, AppColors.primary),
          _Card('Listings', '${g('listings')}', Icons.apartment_outlined, AppColors.info),
          _Card('Pipeline', aed(g('revenue_pipeline')), Icons.account_balance_wallet_outlined, AppColors.success),
        ];
      case Persona.developer:
        return [
          _Card('Projects', '${g('projects')}', Icons.domain_outlined, AppColors.secondary),
          _Card('Available', '${g('available')}', Icons.check_circle_outline, AppColors.success),
          _Card('Reserved', '${g('reserved')}', Icons.lock_clock_outlined, AppColors.warning),
          _Card('Sold', '${g('sold')}', Icons.sell_outlined, AppColors.primary),
        ];
      case Persona.owner:
        return [
          _Card('Owned properties', '${g('owned_properties')}', Icons.home_work_outlined, AppColors.secondary),
          _Card('Active listings', '${g('active_listings')}', Icons.apartment_outlined, AppColors.primary),
          _Card('Under lease', '${g('under_lease')}', Icons.vpn_key_outlined, AppColors.info),
          _Card('Expiring tenancies', '${g('expiring_tenancies')}', Icons.event_busy_outlined, AppColors.warning),
          _Card('Pending maintenance', '${g('pending_maintenance')}', Icons.build_outlined, AppColors.danger),
          _Card('Owner actions', '${g('outstanding_actions')}', Icons.notifications_active_outlined, AppColors.success),
        ];
      case Persona.investor:
        return [
          _Card('Properties', '${g('properties')}', Icons.home_work_outlined, AppColors.secondary),
          _Card('Total value', aed(g('total_value')), Icons.real_estate_agent_outlined, AppColors.primary),
          _Card('Outstanding loan', aed(g('outstanding_loan')), Icons.account_balance_outlined, AppColors.warning),
          _Card('Rental income', aed(g('annual_rental_income')), Icons.payments_outlined, AppColors.success),
        ];
      case Persona.admin:
        return [
          _Card('Organizations', '${g('organizations')}', Icons.business_outlined, AppColors.secondary),
          _Card('Users', '${g('users')}', Icons.people_outline, AppColors.primary),
          _Card('Subscriptions', '${g('active_subscriptions')}', Icons.workspace_premium_outlined, AppColors.success),
          _Card('Active deals', '${g('active_deals')}', Icons.handshake_outlined, AppColors.info),
        ];
      case Persona.buyer:
        return <_Card>[];
      default: // agent / lead generator
        return [
          _Card('Active leads', '${g('new_leads') + g('hot_leads')}', Icons.trending_up, AppColors.secondary),
          _Card('Hot leads', '${g('hot_leads')}', Icons.local_fire_department_outlined, AppColors.danger),
          _Card('Active deals', '${g('active_deals')}', Icons.handshake_outlined, AppColors.primary),
          _Card('Listings', '${g('listings')}', Icons.apartment_outlined, AppColors.info),
        ];
    }
  }
}

class _Card {
  _Card(this.label, this.value, this.icon, this.color, {this.route});
  final String label, value;
  final IconData icon;
  final Color color;
  final String? route; // tapping the KPI opens this destination
}

/// Premium dashboard surface — white card on the near-neutral page, soft
/// ink-tinted depth and a hairline border. An optional [accent] paints a 3px
/// brand-coloured top bar so each card reads as a distinct module at a glance.
Widget _flatBox(BuildContext context, Widget child, {EdgeInsets? padding, Color? accent}) {
  final dark = Theme.of(context).brightness == Brightness.dark;
  final radius = BorderRadius.circular(AppSpacing.rCard);
  return DecoratedBox(
    decoration: BoxDecoration(borderRadius: radius, boxShadow: dark ? null : AppShadows.card),
    child: ClipRRect(
      borderRadius: radius,
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: radius,
          border: Border.all(color: Theme.of(context).dividerColor, width: 0.5),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (accent != null) Container(height: 3, color: accent),
            Padding(padding: padding ?? const EdgeInsets.all(AppSpacing.x16), child: child),
          ],
        ),
      ),
    ),
  );
}

class _KpiGrid extends StatelessWidget {
  const _KpiGrid({required this.cards, required this.wide});
  final List<_Card> cards;
  final bool wide;
  @override
  Widget build(BuildContext context) {
    final cols = wide ? 4 : 2;
    return LayoutBuilder(builder: (ctx, c) {
      final w = (c.maxWidth - AppSpacing.x16 * (cols - 1)) / cols;
      return Wrap(
        spacing: AppSpacing.x16,
        runSpacing: AppSpacing.x16,
        children: cards.map((card) => SizedBox(width: w, child: _KpiCard(card))).toList(),
      );
    });
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard(this.card);
  final _Card card;
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final box = _flatBox(
      context,
      accent: card.color,
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(card.label, style: t.bodySmall?.copyWith(color: dark ? AppColors.dTextMuted : AppColors.textMuted)),
            const SizedBox(height: 6),
            Text(card.value, style: t.headlineMedium?.copyWith(fontWeight: FontWeight.w700)),
          ]),
        ),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: card.color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(AppSpacing.rMd)),
          child: Icon(card.icon, size: 18, color: card.color),
        ),
      ]),
    );
    if (card.route == null) return box;
    // KPI cards are clickable — they open the matching destination.
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: () => context.go(card.route!), child: box),
    );
  }
}

/// Buyer activity counters, colour-anchored like the role KPI grid.
class _BuyerKpis extends ConsumerWidget {
  const _BuyerKpis({required this.wide});
  final bool wide;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final k = ref.watch(_buyerKpisProvider).asData?.value ?? const <String, int>{};
    int n(String key) => k[key] ?? 0;
    final cards = [
      _Card('Saved properties', '${n('saved')}', Icons.bookmark_outline, AppColors.secondary, route: '/saved'),
      _Card('Upcoming viewings', '${n('viewings')}', Icons.event_available_outlined, AppColors.primary, route: '/viewings'),
      _Card('Property alerts', '${n('searches')}', Icons.notifications_active_outlined, AppColors.warning, route: '/saved-searches'),
      _Card('Finance plans', '${n('finance')}', Icons.calculate_outlined, AppColors.accentGold, route: '/finance-planner'),
    ];
    return _KpiGrid(cards: cards, wide: wide);
  }
}

class _PanelCard extends StatelessWidget {
  const _PanelCard({required this.title, required this.child, this.action});
  final String title;
  final Widget child;
  final Widget? action;
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return _flatBox(
      context,
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(title, style: t.titleMedium)),
          if (action != null) action!,
        ]),
        const SizedBox(height: AppSpacing.x12),
        child,
      ]),
    );
  }
}

class _SalesCard extends ConsumerWidget {
  const _SalesCard({required this.title});
  final String title;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final async = ref.watch(_salesSeriesProvider);
    return _PanelCard(
      title: title,
      child: SizedBox(
        height: 140,
        child: async.when(
          loading: () => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
          error: (_, __) => _empty(t, dark),
          data: (series) {
            final hasData = series.length >= 2 && series.any((v) => v > 0);
            if (!hasData) return _empty(t, dark);
            final secondary = series.map((v) => v * 0.82).toList();
            return Stack(children: [
              Positioned.fill(child: CustomPaint(painter: _SparkPainter(secondary, AppColors.secondary))),
              Positioned.fill(child: CustomPaint(painter: _SparkPainter(series, AppColors.primary))),
            ]);
          },
        ),
      ),
    );
  }

  Widget _empty(TextTheme t, bool dark) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.show_chart, size: 28, color: dark ? AppColors.dTextMuted : AppColors.textSubtle),
          const SizedBox(height: AppSpacing.x8),
          Text('No sales recorded yet', style: t.bodySmall?.copyWith(color: dark ? AppColors.dTextMuted : AppColors.textMuted)),
          Text('Closed deals will chart here.', style: t.bodySmall?.copyWith(color: dark ? AppColors.dTextMuted : AppColors.textSubtle)),
        ]),
      );
}

/// Owner Portfolio Performance — monthly income/expense over the owned portfolio.
final _ownerPerfProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  try {
    final d = await ref.read(apiClientProvider).get('/reports/owner-performance');
    return d is Map ? Map<String, dynamic>.from(d) : <String, dynamic>{};
  } catch (_) {
    return <String, dynamic>{};
  }
});

class _PerfPoint {
  _PerfPoint(this.label, this.income, this.expense, this.roi);
  final String label;
  final double income, expense, roi;
}

/// Interactive Income / Expense / ROI trend with a Monthly | Annual toggle,
/// drag-to-inspect readout, and a period summary. Replaces the static ROI card.
class _PortfolioPerformance extends ConsumerStatefulWidget {
  const _PortfolioPerformance();
  @override
  ConsumerState<_PortfolioPerformance> createState() => _PortfolioPerformanceState();
}

class _PortfolioPerformanceState extends ConsumerState<_PortfolioPerformance> {
  bool _annual = false;
  int? _sel;

  List<_PerfPoint> _build(List rows, double equity) {
    double inc(dynamic e) => (num.tryParse('${e['income']}') ?? 0).toDouble();
    double exp(dynamic e) => (num.tryParse('${e['expense']}') ?? 0).toDouble();
    double roiOf(double net) => equity > 0 ? net / equity * 100 : 0;
    if (_annual) {
      final byYear = <String, List<double>>{};
      for (final e in rows) {
        final y = '${e['period']}'.padRight(4).substring(0, 4);
        final cur = byYear.putIfAbsent(y, () => [0, 0]);
        cur[0] += inc(e);
        cur[1] += exp(e);
      }
      final years = byYear.keys.toList()..sort();
      return [for (final y in years) _PerfPoint(y, byYear[y]![0], byYear[y]![1], roiOf(byYear[y]![0] - byYear[y]![1]))];
    }
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final last = rows.length > 12 ? rows.sublist(rows.length - 12) : rows;
    return last.map((e) {
      final p = '${e['period']}';
      final m = p.length >= 7 ? (int.tryParse(p.substring(5, 7)) ?? 1) : 1;
      return _PerfPoint(months[(m - 1).clamp(0, 11)], inc(e), exp(e), roiOf(inc(e) - exp(e)));
    }).toList();
  }

  Widget _legendDot(Color c, String label) {
    final t = Theme.of(context).textTheme;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 9, height: 9, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
      const SizedBox(width: 5),
      Text(label, style: t.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final muted = dark ? AppColors.dTextMuted : AppColors.textMuted;
    final d = ref.watch(_ownerPerfProvider).asData?.value ?? const <String, dynamic>{};
    final rows = (d['series'] is List) ? d['series'] as List : const [];
    final equity = (num.tryParse('${d['equity'] ?? 0}') ?? 0).toDouble();
    final pts = _build(rows, equity);
    final aed = NumberFormat.compactCurrency(symbol: 'AED ', decimalDigits: 0);

    final header = Row(children: [
      Expanded(child: Text('Portfolio Performance', style: t.titleMedium)),
      _SegToggle(annual: _annual, onChanged: (v) => setState(() { _annual = v; _sel = null; })),
    ]);
    Widget card(Widget body) => Card(child: Padding(padding: const EdgeInsets.all(AppSpacing.x16), child: body));

    if (pts.isEmpty) {
      return card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        header,
        const SizedBox(height: AppSpacing.x20),
        Center(child: Column(children: [
          Icon(Icons.show_chart, size: 36, color: muted),
          const SizedBox(height: AppSpacing.x8),
          Text('No financial data yet', style: t.titleSmall),
          const SizedBox(height: 4),
          Text('Add a property and log income/expenses to start tracking performance.',
              textAlign: TextAlign.center, style: t.bodySmall?.copyWith(color: muted)),
          const SizedBox(height: AppSpacing.x12),
          OutlinedButton(onPressed: () => context.go('/financials'), child: const Text('Open financials')),
        ])),
        const SizedBox(height: AppSpacing.x8),
      ]));
    }

    final totalInc = pts.fold(0.0, (s, p) => s + p.income);
    final totalExp = pts.fold(0.0, (s, p) => s + p.expense);
    final avgRoi = pts.map((p) => p.roi).fold(0.0, (s, v) => s + v) / pts.length;
    final selPt = (_sel != null && _sel! < pts.length) ? pts[_sel!] : null;

    return card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      header,
      const SizedBox(height: AppSpacing.x12),
      if (selPt != null)
        Row(children: [
          Text(selPt.label, style: t.titleSmall),
          const Spacer(),
          _legendDot(AppColors.success, aed.format(selPt.income)),
          const SizedBox(width: AppSpacing.x12),
          _legendDot(AppColors.danger, aed.format(selPt.expense)),
          const SizedBox(width: AppSpacing.x12),
          _legendDot(AppColors.accentGold, '${selPt.roi.toStringAsFixed(1)}%'),
        ])
      else
        Text('Drag across the chart to inspect a period', style: t.bodySmall?.copyWith(color: muted)),
      const SizedBox(height: AppSpacing.x8),
      LayoutBuilder(builder: (ctx, c) {
        void select(double dx) {
          final n = pts.length;
          final i = n <= 1 ? 0 : ((dx / c.maxWidth) * (n - 1)).round().clamp(0, n - 1);
          setState(() => _sel = i);
        }
        return GestureDetector(
          onTapDown: (e) => select(e.localPosition.dx),
          onHorizontalDragUpdate: (e) => select(e.localPosition.dx),
          child: SizedBox(
            height: 150,
            width: double.infinity,
            child: CustomPaint(
              painter: _PerfPainter(
                pts: pts, sel: _sel, grid: Theme.of(context).dividerColor,
                income: AppColors.success, expense: AppColors.danger, roi: AppColors.accentGold),
            ),
          ),
        );
      }),
      const SizedBox(height: AppSpacing.x8),
      Wrap(spacing: AppSpacing.x16, children: [
        _legendDot(AppColors.success, 'Income'),
        _legendDot(AppColors.danger, 'Expense'),
        _legendDot(AppColors.accentGold, 'ROI'),
      ]),
      const Divider(height: AppSpacing.x24),
      _RoiLine(label: 'Total income', value: aed.format(totalInc)),
      _RoiLine(label: 'Total expenses', value: aed.format(totalExp)),
      _RoiLine(label: 'Net profit', value: aed.format(totalInc - totalExp)),
      _RoiLine(label: 'Average ROI', value: '${avgRoi.toStringAsFixed(1)}%'),
    ]));
  }
}

class _SegToggle extends StatelessWidget {
  const _SegToggle({required this.annual, required this.onChanged});
  final bool annual;
  final ValueChanged<bool> onChanged;
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme.primary;
    Widget seg(String label, bool selected, VoidCallback onTap) => GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: selected ? c.withValues(alpha: 0.14) : Colors.transparent,
              borderRadius: BorderRadius.circular(AppSpacing.rFull),
            ),
            child: Text(label,
                style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w700, color: selected ? c : Theme.of(context).hintColor)),
          ),
        );
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(AppSpacing.rFull)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        seg('Monthly', !annual, () => onChanged(false)),
        seg('Annual', annual, () => onChanged(true)),
      ]),
    );
  }
}

class _PerfPainter extends CustomPainter {
  _PerfPainter({
    required this.pts,
    required this.sel,
    required this.grid,
    required this.income,
    required this.expense,
    required this.roi,
  });
  final List<_PerfPoint> pts;
  final int? sel;
  final Color grid, income, expense, roi;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final n = pts.length;
    final gridP = Paint()..color = grid..strokeWidth = 0.5;
    for (var i = 0; i <= 3; i++) {
      final y = h * i / 3;
      canvas.drawLine(Offset(0, y), Offset(w, y), gridP);
    }
    double xAt(int i) => n <= 1 ? w / 2 : w * i / (n - 1);
    final maxAed = pts.map((p) => max(p.income, p.expense)).fold(1.0, max);
    final maxRoi = pts.map((p) => p.roi.abs()).fold(1.0, max);
    double yAed(double v) => h - (v / maxAed) * (h * 0.86) - h * 0.07;
    double yRoi(double v) => h / 2 - (v / maxRoi) * (h * 0.43);

    void line(double Function(_PerfPoint) yf, Color color) {
      final paint = Paint()
        ..color = color
        ..strokeWidth = 2.2
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round;
      final path = Path();
      for (var i = 0; i < n; i++) {
        final o = Offset(xAt(i), yf(pts[i]));
        if (i == 0) {
          path.moveTo(o.dx, o.dy);
        } else {
          path.lineTo(o.dx, o.dy);
        }
      }
      canvas.drawPath(path, paint);
    }

    line((p) => yAed(p.income), income);
    line((p) => yAed(p.expense), expense);
    line((p) => yRoi(p.roi), roi);

    if (sel != null && sel! < n) {
      final x = xAt(sel!);
      canvas.drawLine(Offset(x, 0), Offset(x, h), Paint()..color = grid..strokeWidth = 1);
      void dot(double y, Color c) => canvas.drawCircle(Offset(x, y), 3.5, Paint()..color = c);
      dot(yAed(pts[sel!].income), income);
      dot(yAed(pts[sel!].expense), expense);
      dot(yRoi(pts[sel!].roi), roi);
    }
  }

  @override
  bool shouldRepaint(_PerfPainter old) => old.pts != pts || old.sel != sel;
}

class _RoiLine extends StatelessWidget {
  const _RoiLine({required this.label, required this.value});
  final String label, value;
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        Expanded(child: Text(label, style: t.bodySmall?.copyWith(color: Theme.of(context).brightness == Brightness.dark ? AppColors.dTextMuted : AppColors.textMuted))),
        Text(value, style: t.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

class _SparkPainter extends CustomPainter {
  _SparkPainter(this.points, this.color);
  final List<double> points;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;
    final maxV = points.reduce(max), minV = points.reduce(min);
    final range = (maxV - minV).abs() < 1e-6 ? 1.0 : (maxV - minV);
    final dx = size.width / (points.length - 1);
    final path = Path();
    for (var i = 0; i < points.length; i++) {
      final x = dx * i;
      final y = size.height - ((points[i] - minV) / range) * (size.height - 8) - 4;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    final fill = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withValues(alpha: 0.16), color.withValues(alpha: 0.0)],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant _SparkPainter old) => old.points != points || old.color != color;
}

class _ActivityCard extends ConsumerWidget {
  const _ActivityCard();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final acts = ref.watch(_activityProvider);
    return _PanelCard(
      title: 'Recent activity',
      action: TextButton(onPressed: () => context.go('/notifications'), child: const Text('View all')),
      child: acts.maybeWhen(
        data: (list) => list.isEmpty
            ? Text('No recent activity.', style: t.bodySmall?.copyWith(color: dark ? AppColors.dTextMuted : AppColors.textMuted))
            : Column(
                children: list.map((e) {
                  final m = Map<String, dynamic>.from(e);
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 4, right: 10),
                        child: CircleAvatar(radius: 4, backgroundColor: AppColors.primary),
                      ),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('${m['title'] ?? 'Update'}', style: t.bodyMedium),
                          if ('${m['body'] ?? ''}'.isNotEmpty)
                            Text('${m['body']}', style: t.bodySmall?.copyWith(color: dark ? AppColors.dTextMuted : AppColors.textMuted), maxLines: 1, overflow: TextOverflow.ellipsis),
                        ]),
                      ),
                    ]),
                  );
                }).toList(),
              ),
        orElse: () => const SizedBox(height: 40, child: Center(child: CircularProgressIndicator())),
      ),
    );
  }
}

class _RecentProperties extends ConsumerWidget {
  const _RecentProperties();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final listings = ref.watch(_recentListingsProvider);
    return _flatBox(
      context,
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text('Recent properties', style: t.titleMedium)),
          TextButton(onPressed: () => context.go('/properties'), child: const Text('Browse all')),
        ]),
        const SizedBox(height: AppSpacing.x12),
        listings.maybeWhen(
          data: (list) => list.isEmpty
              ? Text('No listings yet.', style: t.bodySmall?.copyWith(color: Theme.of(context).brightness == Brightness.dark ? AppColors.dTextMuted : AppColors.textMuted))
              : SizedBox(
                  height: 210,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.x12),
                    itemBuilder: (_, i) => _PropertyMiniCard(Map<String, dynamic>.from(list[i])),
                  ),
                ),
          orElse: () => const SizedBox(height: 40, child: Center(child: CircularProgressIndicator())),
        ),
      ]),
    );
  }
}

/// Developer dashboard — the developer's OWN projects (org-scoped via
/// projectsProvider), never the public market. Empty state guides project
/// creation so the dashboard is never a dead end.
class _DeveloperProjects extends ConsumerWidget {
  const _DeveloperProjects();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final muted = dark ? AppColors.dTextMuted : AppColors.textMuted;
    final projects = ref.watch(projectsProvider);
    return _flatBox(
      context,
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text('Your projects', style: t.titleMedium)),
          TextButton(onPressed: () => context.go('/projects'), child: const Text('View all')),
        ]),
        const SizedBox(height: AppSpacing.x12),
        projects.maybeWhen(
          data: (list) => list.isEmpty
              ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('No projects yet — create your first development to start managing inventory and sales.',
                      style: t.bodySmall?.copyWith(color: muted)),
                  const SizedBox(height: AppSpacing.x12),
                  FilledButton.icon(
                    onPressed: () => context.go('/projects'),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Create a project'),
                  ),
                ])
              : SizedBox(
                  height: 150,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.x12),
                    itemBuilder: (_, i) => _ProjectMiniCard(Map<String, dynamic>.from(list[i])),
                  ),
                ),
          orElse: () => const SizedBox(height: 40, child: Center(child: CircularProgressIndicator())),
        ),
      ]),
    );
  }
}

class _ProjectMiniCard extends StatelessWidget {
  const _ProjectMiniCard(this.p);
  final Map<String, dynamic> p;
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final muted = dark ? AppColors.dTextMuted : AppColors.textMuted;
    final status = '${p['status'] ?? 'planning'}';
    final units = p['units'] ?? 0;
    final available = p['available'] ?? 0;
    final statusColor = switch (status) {
      'ready' => AppColors.success,
      'under_construction' => AppColors.warning,
      'completed' || 'sold_out' => AppColors.info,
      _ => AppColors.primary,
    };
    final label = status.isEmpty ? '' : '${status[0].toUpperCase()}${status.substring(1).replaceAll('_', ' ')}';
    return SizedBox(
      width: 230,
      child: HoverLift(
        child: Card(
          child: InkWell(
            onTap: () => context.push('/projects/${p['id']}'),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.x12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Icon(Icons.domain_outlined, size: 18, color: Theme.of(context).colorScheme.primary),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(AppSpacing.rFull)),
                    child: Text(label, style: t.labelSmall?.copyWith(color: statusColor, fontWeight: FontWeight.w700)),
                  ),
                ]),
                const SizedBox(height: AppSpacing.x12),
                Text('${p['name'] ?? 'Project'}',
                    style: t.titleSmall?.copyWith(fontWeight: FontWeight.w700), maxLines: 2, overflow: TextOverflow.ellipsis),
                const Spacer(),
                Text('$units units · $available available', style: t.bodySmall?.copyWith(color: muted)),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

class _PropertyMiniCard extends StatelessWidget {
  const _PropertyMiniCard(this.m);
  final Map<String, dynamic> m;
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    // Theme-aware: AppColors.primary/textMuted are dark and vanish on a dark
    // card. Use the colorScheme primary (bright in dark mode) + dark muted token.
    final dark = Theme.of(context).brightness == Brightness.dark;
    final priceColor = Theme.of(context).colorScheme.primary;
    final muted = dark ? AppColors.dTextMuted : AppColors.textMuted;
    final id = '${m['id']}';
    final price = num.tryParse('${m['price']}') ?? 0;
    final isRent = '${m['purpose']}' == 'rent';
    final money = price > 0
        ? '${NumberFormat.currency(symbol: 'AED ', decimalDigits: 0).format(price)}${isRent ? ' / yr' : ''}'
        : '';
    final cover = '${m['cover_image'] ?? ''}';
    final beds = m['bedrooms'];
    final baths = m['bathrooms'];
    final sqft = m['size_sqft'];
    final community = '${m['community'] ?? ''}';
    return SizedBox(
      width: 230,
      child: HoverLift(
        child: Card(
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => context.go('/listings/$id'),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Stack(children: [
                // ClipRect contains the hover-zoom so it can't bleed past the card.
                ClipRect(
                  child: SizedBox(
                    height: 110,
                    width: double.infinity,
                    child: cover.isNotEmpty
                        ? HoverZoomImage(
                            url: cover,
                            placeholder: Container(color: AppColors.surface2,
                                child: const Icon(Icons.apartment_outlined, color: AppColors.textMuted)),
                          )
                        : Container(color: AppColors.surface2,
                            child: const Icon(Icons.apartment_outlined, color: AppColors.textMuted)),
                  ),
                ),
                Positioned(
                  top: 8, left: 8,
                  child: StatusBadge(isRent ? 'For Rent' : 'For Sale', tone: isRent ? BadgeTone.warning : BadgeTone.success),
                ),
              ]),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.x12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  if (money.isNotEmpty)
                    Text(money, style: t.titleSmall?.copyWith(color: priceColor, fontWeight: FontWeight.w700)),
                  if (community.isNotEmpty)
                    Text(community, style: t.bodySmall?.copyWith(color: muted), maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 6),
                  Row(children: [
                    if (beds != null) _spec(Icons.bed_outlined, '$beds', muted),
                    if (baths != null) _spec(Icons.bathtub_outlined, '$baths', muted),
                    if (sqft != null) _spec(Icons.straighten, '$sqft', muted),
                  ]),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _spec(IconData icon, String v, Color color) => Padding(
        padding: const EdgeInsets.only(right: 10),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 3),
          Text(v, style: TextStyle(fontSize: 12, color: color)),
        ]),
      );
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.persona});
  final Persona persona;
  @override
  Widget build(BuildContext context) {
    final actions = switch (persona) {
      Persona.leadGenerator => [
          ('Post new lead', Icons.add_circle_outline, '/leads/new'),
          ('Browse marketplace', Icons.storefront_outlined, '/feed'),
          ('Find partners', Icons.people_outline, '/network'),
        ],
      Persona.developer => [
          ('New project', Icons.domain_add_outlined, '/projects'),
          ('Manage inventory', Icons.inventory_2_outlined, '/inventory'),
          ('View feed', Icons.dynamic_feed_outlined, '/feed'),
        ],
      Persona.owner => [
          ('Add property', Icons.add_home_work_outlined, '/properties/new'),
          ('My properties', Icons.home_work_outlined, '/my-properties'),
          ('Documents', Icons.folder_outlined, '/documents'),
          ('Request maintenance', Icons.build_outlined, '/maintenance'),
          ('Financials', Icons.account_balance_wallet_outlined, '/financials'),
          ('Track mortgages', Icons.account_balance_outlined, '/mortgages'),
        ],
      Persona.investor => [
          ('Mortgage calculator', Icons.calculate_outlined, '/calculator'),
          ('Track mortgages', Icons.account_balance_outlined, '/mortgages'),
          ('My properties', Icons.home_work_outlined, '/my-properties'),
        ],
      Persona.buyer => [
          ('Browse properties', Icons.search, '/properties'),
          ('Finance calculator', Icons.calculate_outlined, '/finance-planner'),
          ('Saved properties', Icons.bookmark_outline, '/saved'),
          ('Viewings', Icons.event_available_outlined, '/viewings'),
          ('Marketplace', Icons.storefront_outlined, '/marketplace'),
          ('Messages', Icons.chat_bubble_outline, '/messages'),
        ],
      Persona.tenant => [
          ('My tenancy', Icons.vpn_key_outlined, '/rentals'),
          ('Request maintenance', Icons.build_outlined, '/maintenance'),
          ('Documents', Icons.folder_outlined, '/documents'),
          ('Messages', Icons.chat_bubble_outline, '/messages'),
        ],
      Persona.salesperson => [
          ('Marketplace', Icons.storefront_outlined, '/marketplace'),
          ('Orders', Icons.receipt_long_outlined, '/orders'),
          ('Activities', Icons.event_note_outlined, '/activities'),
        ],
      Persona.provider => [
          ('Marketplace', Icons.storefront_outlined, '/marketplace'),
          ('Orders', Icons.receipt_long_outlined, '/orders'),
          ('Team', Icons.groups_outlined, '/team'),
        ],
      Persona.bank => [
          ('Mortgages', Icons.account_balance_outlined, '/mortgages'),
          ('Reports', Icons.insights_outlined, '/reports'),
          ('Contacts', Icons.contacts_outlined, '/contacts'),
        ],
      _ => [
          ('Add listing', Icons.add_home_work_outlined, '/properties/new'),
          ('New lead', Icons.person_add_alt, '/leads'),
          ('View deals', Icons.handshake_outlined, '/deals'),
        ],
    };
    return Column(
      children: actions
          .map((a) => ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                leading: Icon(a.$2, color: Theme.of(context).colorScheme.primary, size: 20),
                title: Text(a.$1),
                trailing: const Icon(Icons.chevron_right, size: 18),
                onTap: () => context.go(a.$3),
              ))
          .toList(),
    );
  }
}

/// Owner command-centre block (merged in from the retired Owner Cockpit page):
/// portfolio / viewing / document roll-ups + the agents working your properties.
final _ownerCockpitProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  try {
    final d = await ref.read(apiClientProvider).get('/reports/owner-cockpit');
    return d is Map ? Map<String, dynamic>.from(d) : <String, dynamic>{};
  } catch (_) {
    return <String, dynamic>{};
  }
});

String _fmtResp(int secs) {
  if (secs <= 0) return '—';
  if (secs < 3600) return '${(secs / 60).round()}m';
  final h = secs ~/ 3600, m = (secs % 3600) ~/ 60;
  return m == 0 ? '${h}h' : '${h}h ${m}m';
}

int _ci(dynamic v) => v is int ? v : int.tryParse('$v') ?? 0;

class _OwnerCockpit extends ConsumerWidget {
  const _OwnerCockpit();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final muted = dark ? AppColors.dTextMuted : AppColors.textMuted;
    final d = ref.watch(_ownerCockpitProvider).asData?.value ?? const <String, dynamic>{};
    if (d.isEmpty) return const SizedBox.shrink();
    final props = Map<String, dynamic>.from(d['properties'] ?? {});
    final v = Map<String, dynamic>.from(d['viewings'] ?? {});
    final docs = Map<String, dynamic>.from(d['documents'] ?? {});
    final agents = (d['agents'] is List) ? List.from(d['agents']) : const [];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Portfolio activity', style: t.titleMedium),
      const SizedBox(height: AppSpacing.x12),
      _statCard(context, 'Properties', [
        ('Total', '${_ci(props['total'])}'),
        ('Published', '${_ci(props['published'])}'),
        ('Drafts', '${_ci(props['drafts'])}'),
      ], t, muted, onTap: () => context.go('/my-properties')),
      const SizedBox(height: AppSpacing.x12),
      _statCard(context, 'Viewing activity', [
        ('Requests', '${_ci(v['requests'])}'),
        ('Pending', '${_ci(v['pending'])}'),
        ('Scheduled', '${_ci(v['scheduled'])}'),
        ('Completed', '${_ci(v['completed'])}'),
        ('Won', '${_ci(v['closed_won'])}'),
      ], t, muted),
      const SizedBox(height: AppSpacing.x12),
      _statCard(context, 'Documents', [
        ('Uploaded', '${_ci(docs['uploaded'])}'),
        ('Pending requests', '${_ci(docs['pending_requests'])}'),
      ], t, muted, onTap: () => context.go('/documents')),
      if (agents.isNotEmpty) ...[
        const SizedBox(height: AppSpacing.x20),
        Text('Agents working your properties', style: t.titleMedium),
        const SizedBox(height: AppSpacing.x8),
        for (final a in agents) _agentRow(context, Map<String, dynamic>.from(a), t, muted),
      ],
    ]);
  }

  Widget _statCard(BuildContext context, String title, List<(String, String)> stats, TextTheme t, Color muted,
      {VoidCallback? onTap}) {
    final card = Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.x16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(title, style: t.titleSmall),
            if (onTap != null) ...[const Spacer(), Icon(Icons.chevron_right, size: 18, color: muted)],
          ]),
          const SizedBox(height: AppSpacing.x12),
          Wrap(spacing: AppSpacing.x24, runSpacing: AppSpacing.x12, children: [
            for (final s in stats)
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(s.$2, style: t.titleLarge),
                Text(s.$1, style: t.bodySmall?.copyWith(color: muted)),
              ]),
          ]),
        ]),
      ),
    );
    return onTap == null
        ? card
        : InkWell(onTap: onTap, borderRadius: BorderRadius.circular(AppSpacing.rMd), child: card);
  }

  Widget _agentRow(BuildContext context, Map<String, dynamic> a, TextTheme t, Color muted) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.x8),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.x12),
        child: Row(children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.primaryTint,
            child: Text('${a['name'] ?? '?'}'.isNotEmpty ? '${a['name']}'[0].toUpperCase() : '?',
                style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: AppSpacing.x12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${a['name'] ?? 'Agent'}', style: t.titleSmall),
              Text([
                '${_ci(a['viewings'])} viewings',
                '${_ci(a['scheduled'])} scheduled',
                '${_ci(a['closed_won'])} won',
                'resp ${_fmtResp(_ci(a['avg_response_secs']))}',
              ].join('  ·  '), style: t.bodySmall?.copyWith(color: muted)),
            ]),
          ),
        ]),
      ),
    );
  }
}

/// Shown when the signed-in account is in the 14-day deletion grace window.
class _DeletionBanner extends ConsumerWidget {
  const _DeletionBanner({this.deletionAt});
  final DateTime? deletionAt;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final when = deletionAt != null ? DateFormat('d MMM y').format(deletionAt!) : 'soon';
    return Container(
      padding: const EdgeInsets.all(AppSpacing.x12),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(AppSpacing.rCard),
        border: Border.all(color: AppColors.danger.withValues(alpha: .35)),
      ),
      child: Row(children: [
        const Icon(Icons.warning_amber_rounded, color: AppColors.danger),
        const SizedBox(width: AppSpacing.x12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Account scheduled for deletion',
                style: t.titleSmall?.copyWith(color: AppColors.danger, fontWeight: FontWeight.w700)),
            Text('Your account will be permanently deleted on $when. Reactivate to cancel.',
                style: t.bodySmall?.copyWith(color: Theme.of(context).brightness == Brightness.dark ? AppColors.dTextMuted : AppColors.textMuted)),
          ]),
        ),
        const SizedBox(width: AppSpacing.x8),
        FilledButton(
          onPressed: () async {
            try {
              await ref.read(authControllerProvider.notifier).reactivate();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Account reactivated — welcome back!')));
              }
            } catch (e) {
              if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
            }
          },
          child: const Text('Reactivate'),
        ),
      ]),
    );
  }
}

class _BuyerCta extends StatelessWidget {
  const _BuyerCta();
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.x20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
            colors: [AppColors.gradientStart, AppColors.gradientEnd],
            begin: Alignment.centerLeft, end: Alignment.centerRight),
        borderRadius: BorderRadius.circular(AppSpacing.rCard),
        boxShadow: AppShadows.card,
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Find your next property',
            style: t.headlineSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
        const SizedBox(height: AppSpacing.x4),
        Text('Search by community, building, budget or travel time.',
            style: t.bodyMedium?.copyWith(color: Colors.white)),
        const SizedBox(height: AppSpacing.x12),
        // Search-bar affordance — tapping opens the properties search.
        InkWell(
          onTap: () => context.go('/properties'),
          borderRadius: BorderRadius.circular(AppSpacing.rFull),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x16, vertical: AppSpacing.x12),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(AppSpacing.rFull)),
            child: Row(children: [
              const Icon(Icons.search, color: AppColors.primary, size: 20),
              const SizedBox(width: AppSpacing.x8),
              Expanded(
                child: Text('Search by community, building, budget or yield…',
                    style: t.bodyMedium?.copyWith(color: AppColors.textMuted),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}

/// "Recommended for you" — a horizontal strip of fresh listings for buyers.
/// Featured marketplace items for customers — services + products. Shows NUZL is
/// more than property listings. Empty list on error (never blanks the dashboard).
final _featuredMktProvider = FutureProvider.autoDispose.family<List<dynamic>, String>((ref, kind) async {
  try {
    final d = await ref.read(apiClientProvider).get('/marketplace', query: {'kind': kind});
    return d is List ? d.take(8).toList() : [];
  } catch (_) {
    return [];
  }
});

/// Friendly empty state for a dashboard strip (clean/new-platform first-run) —
/// keeps the section visible with a prompt instead of vanishing.
Widget _stripEmpty(BuildContext context,
    {required String title, required IconData icon, required String message, String? actionLabel, VoidCallback? onAction}) {
  final t = Theme.of(context).textTheme;
  final dark = Theme.of(context).brightness == Brightness.dark;
  final muted = dark ? AppColors.dTextMuted : AppColors.textMuted;
  return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Row(children: [
      Expanded(child: Text(title, style: t.titleMedium)),
      if (actionLabel != null) TextButton(onPressed: onAction, child: Text(actionLabel)),
    ]),
    const SizedBox(height: AppSpacing.x8),
    Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.x20, horizontal: AppSpacing.x16),
      decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(16)),
      child: Row(children: [
        Icon(icon, size: 22, color: muted),
        const SizedBox(width: AppSpacing.x12),
        Expanded(child: Text(message, style: t.bodySmall?.copyWith(color: muted))),
      ]),
    ),
    const SizedBox(height: AppSpacing.x24),
  ]);
}

class _MarketplaceStrip extends ConsumerWidget {
  const _MarketplaceStrip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final services = ref.watch(_featuredMktProvider('service')).asData?.value ?? const [];
    final products = ref.watch(_featuredMktProvider('product')).asData?.value ?? const [];
    if (services.isEmpty && products.isEmpty) {
      return _stripEmpty(context,
          title: 'From the marketplace', icon: Icons.storefront_outlined,
          message: 'Services and products from verified providers will appear here.',
          actionLabel: 'Browse all', onAction: () => context.go('/marketplace'));
    }
    Widget group(String label, List<dynamic> items, IconData fallbackIcon) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: AppSpacing.x12),
            Text(label, style: t.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: AppSpacing.x8),
            SizedBox(
              height: 132,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.x12),
                itemBuilder: (_, i) => _MktMini(Map<String, dynamic>.from(items[i]), fallbackIcon),
              ),
            ),
          ],
        );
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(child: Text('From the marketplace', style: t.titleMedium)),
        TextButton(onPressed: () => context.go('/marketplace'), child: const Text('Browse all')),
      ]),
      if (services.isNotEmpty) group('Services', services, Icons.handyman_outlined),
      if (products.isNotEmpty) group('Products', products, Icons.inventory_2_outlined),
      const SizedBox(height: AppSpacing.x24),
    ]);
  }
}

class _MktMini extends StatelessWidget {
  const _MktMini(this.m, this.fallbackIcon);
  final Map<String, dynamic> m;
  final IconData fallbackIcon;
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final img = '${m['image_url'] ?? ''}'.trim();
    final price = num.tryParse('${m['price']}');
    final money = price != null && price > 0 ? NumberFormat.currency(symbol: 'AED ', decimalDigits: 0).format(price) : '';
    final fallback = Container(
      color: AppColors.surface2,
      child: Center(child: Icon(fallbackIcon, color: AppColors.textSubtle)),
    );
    return GestureDetector(
      onTap: () => context.push('/marketplace/${m['id']}'),
      child: SizedBox(
        width: 150,
        child: Card(
          clipBehavior: Clip.antiAlias,
          margin: EdgeInsets.zero,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(
              height: 70,
              width: double.infinity,
              child: img.isEmpty ? fallback : Image.network(img, fit: BoxFit.cover, errorBuilder: (_, __, ___) => fallback),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.x8),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${m['title'] ?? ''}', maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: t.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
                if (money.isNotEmpty)
                  Text(money, style: t.bodySmall?.copyWith(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w700)),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

class _RecommendedProperties extends ConsumerWidget {
  const _RecommendedProperties();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final recs = ref.watch(_recommendedProvider);
    return recs.maybeWhen(
      data: (list) {
        if (list.isEmpty) {
          return _stripEmpty(context,
              title: 'Recommended for you', icon: Icons.recommend_outlined,
              message: 'Personalised picks appear here as new properties are listed.',
              actionLabel: 'Browse properties', onAction: () => context.go('/properties'));
        }
        final aed = NumberFormat.compactCurrency(symbol: 'AED ', decimalDigits: 0);
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text('Recommended for you', style: t.titleMedium),
            const Spacer(),
            TextButton(onPressed: () => context.go('/properties'), child: const Text('See all')),
          ]),
          const SizedBox(height: AppSpacing.x8),
          SizedBox(
            height: 226,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: list.length,
              separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.x12),
              itemBuilder: (_, i) => _RecCard(l: list[i], aed: aed),
            ),
          ),
          const SizedBox(height: AppSpacing.x16),
        ]);
      },
      orElse: () => const SizedBox.shrink(),
    );
  }
}

class _RecCard extends StatelessWidget {
  const _RecCard({required this.l, required this.aed});
  final Map<String, dynamic> l;
  final NumberFormat aed;
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final price = num.tryParse('${l['price']}') ?? 0;
    final cover = '${l['cover_image'] ?? ''}';
    final isRent = '${l['purpose']}' == 'rent';
    final beds = '${l['bedrooms'] ?? '-'}';
    return SizedBox(
      width: 240,
      child: HoverLift(
        child: Card(
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => context.push('/listings/${l['id']}'),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              ClipRect(
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: cover.isEmpty
                      ? Container(color: AppColors.surface2,
                          child: const Center(child: Icon(Icons.apartment_outlined, color: AppColors.textSubtle)))
                      : HoverZoomImage(
                          url: cover,
                          placeholder: Container(color: AppColors.surface2,
                              child: const Center(child: Icon(Icons.apartment_outlined, color: AppColors.textSubtle))),
                        ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.x12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(aed.format(price), style: t.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text('${l['community'] ?? l['property_type'] ?? ''}',
                      style: t.bodySmall?.copyWith(color: Theme.of(context).brightness == Brightness.dark ? AppColors.dTextMuted : AppColors.textMuted),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text('$beds BR  ·  ${isRent ? 'For rent' : 'For sale'}',
                      style: t.bodySmall?.copyWith(color: Theme.of(context).brightness == Brightness.dark ? AppColors.dTextMuted : AppColors.textMuted)),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Market-intelligence widget for buyers — latest community snapshots (avg asking
/// price, rental trend, active listings). Hidden entirely when there's no data.
class _MarketIntelligence extends ConsumerWidget {
  const _MarketIntelligence();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final intel = ref.watch(_marketIntelProvider);
    return intel.maybeWhen(
      data: (rows) {
        if (rows.isEmpty) return const SizedBox.shrink();
        final aed = NumberFormat.compactCurrency(symbol: 'AED ', decimalDigits: 0);
        final top = rows.take(5).toList();
        return Column(children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.x16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Icon(Icons.insights_outlined, size: 18, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: AppSpacing.x8),
                  Text('Market intelligence', style: t.titleMedium),
                ]),
                const SizedBox(height: AppSpacing.x8),
                for (final r in top) _IntelRow(r: r, aed: aed),
              ]),
            ),
          ),
          const SizedBox(height: AppSpacing.x16),
        ]);
      },
      orElse: () => const SizedBox.shrink(),
    );
  }
}

class _IntelRow extends StatelessWidget {
  const _IntelRow({required this.r, required this.aed});
  final Map<String, dynamic> r;
  final NumberFormat aed;
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final name = '${r['community'] ?? 'Community'}';
    final price = num.tryParse('${r['avg_asking_price'] ?? ''}');
    final listings = int.tryParse('${r['active_listings'] ?? 0}') ?? 0;
    final trend = num.tryParse('${r['rental_trend_pct'] ?? ''}');
    final up = (trend ?? 0) >= 0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name, style: t.bodyMedium?.copyWith(fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
            Text('$listings active listing${listings == 1 ? '' : 's'}',
                style: t.bodySmall?.copyWith(color: Theme.of(context).brightness == Brightness.dark ? AppColors.dTextMuted : AppColors.textMuted)),
          ]),
        ),
        const SizedBox(width: AppSpacing.x8),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          if (price != null) Text(aed.format(price), style: t.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
          if (trend != null)
            Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(up ? Icons.arrow_upward : Icons.arrow_downward, size: 12,
                  color: up ? AppColors.success : AppColors.danger),
              Text('${trend.abs().toStringAsFixed(1)}% rent',
                  style: t.bodySmall?.copyWith(color: up ? AppColors.success : AppColors.danger)),
            ]),
        ]),
      ]),
    );
  }
}

/// Per-role tools list inside a panel.
class _ToolsList extends StatelessWidget {
  const _ToolsList({required this.persona});
  final Persona persona;
  @override
  Widget build(BuildContext context) {
    final tools = _toolsFor(persona);
    return Column(
      children: tools
          .map((tool) => ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                leading: Icon(tool.$2, color: Theme.of(context).colorScheme.primary, size: 20),
                title: Text(tool.$1),
                trailing: const Icon(Icons.chevron_right, size: 18),
                onTap: () => context.go(tool.$3),
              ))
          .toList(),
    );
  }
}

List<(String, IconData, String)> _toolsFor(Persona p) => switch (p) {
      Persona.broker || Persona.agent => [
          ('Lead matcher', Icons.auto_awesome_outlined, '/lead-matches'),
          ('Viewings', Icons.event_available_outlined, '/viewings'),
          ('Documents', Icons.folder_outlined, '/documents'),
          ('Reports', Icons.insights_outlined, '/reports'),
        ],
      Persona.leadGenerator => [
          ('Lead matcher', Icons.auto_awesome_outlined, '/lead-matches'),
          ('Marketplace', Icons.storefront_outlined, '/feed'),
          ('Network', Icons.people_outline, '/network'),
        ],
      Persona.developer => [
          ('Projects', Icons.domain_outlined, '/projects'),
          ('Inventory', Icons.inventory_2_outlined, '/inventory'),
          ('Reports', Icons.insights_outlined, '/reports'),
        ],
      Persona.owner => [
          ('Financials / ROI', Icons.account_balance_wallet_outlined, '/financials'),
          ('Rent & cheques', Icons.vpn_key_outlined, '/rentals'),
          ('Maintenance', Icons.build_outlined, '/maintenance'),
        ],
      Persona.investor => [
          ('ROI & portfolio', Icons.home_work_outlined, '/my-properties'),
          ('Financials', Icons.account_balance_wallet_outlined, '/financials'),
          ('Mortgage tracker', Icons.account_balance_outlined, '/mortgages'),
        ],
      Persona.buyer => [
          ('Marketplace', Icons.storefront_outlined, '/marketplace'),
          ('Saved searches', Icons.bookmark_outline, '/saved-searches'),
          ('Viewings', Icons.event_available_outlined, '/viewings'),
        ],
      Persona.bank => [
          ('Mortgages', Icons.account_balance_outlined, '/mortgages'),
          ('Leads', Icons.trending_up, '/leads'),
          ('Reports', Icons.insights_outlined, '/reports'),
        ],
      Persona.salesperson => [
          ('Marketplace', Icons.storefront_outlined, '/marketplace'),
          ('Customers', Icons.contacts_outlined, '/customers'),
          ('Activities', Icons.event_note_outlined, '/activities'),
        ],
      Persona.provider => [
          ('Marketplace', Icons.storefront_outlined, '/marketplace'),
          ('Team', Icons.groups_outlined, '/team'),
          ('Reports', Icons.insights_outlined, '/reports'),
        ],
      Persona.tenant => [
          ('Maintenance', Icons.build_outlined, '/maintenance'),
          ('My Tenancy', Icons.vpn_key_outlined, '/rentals'),
          ('Documents', Icons.folder_outlined, '/documents'),
        ],
      Persona.admin => [
          ('Organizations', Icons.business_outlined, '/organizations'),
          ('Audit logs', Icons.receipt_long_outlined, '/audit'),
          ('Plans', Icons.workspace_premium_outlined, '/plans'),
        ],
    };
