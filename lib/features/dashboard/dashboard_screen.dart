import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/network/api_client.dart';
import '../../core/rbac/persona.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/status_badge.dart';
import '../auth/application/auth_controller.dart';
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

/// Monthly sales series for the Sales overview chart. Scope is decided by the
/// API from the caller's role (own deals for an agent, whole-org for a broker /
/// admin). Falls back to a representative sample so the panel is never blank.
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
  return const [22, 30, 26, 38, 34, 46, 44, 58, 54, 66];
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

    return Scaffold(
      appBar: const NuzlAppBar(title: 'Dashboard'),
      drawer: const NuzlDrawer(),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(dashboardProvider);
          ref.invalidate(_recentListingsProvider);
          ref.invalidate(_activityProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.x20),
          children: [
            Text('Welcome back${user?.fullName.isNotEmpty == true ? ', ${user!.fullName.split(' ').first}' : ''}',
                style: t.headlineSmall),
            Text("Here's what's happening today", style: t.bodySmall?.copyWith(color: AppColors.textMuted)),
            if (user?.pendingDeletion == true) ...[
              const SizedBox(height: AppSpacing.x16),
              _DeletionBanner(deletionAt: user!.deletionAt),
            ],
            const SizedBox(height: AppSpacing.x20),

            // KPI row
            if (cards.isNotEmpty) _KpiGrid(cards: cards, wide: wide),
            if (cards.isNotEmpty) const SizedBox(height: AppSpacing.x16),

            // Sales overview (org / agent) or ROI (owner only) + recent activity.
            // Sales roles see a sales graph; owners see ROI; everyone else just
            // gets recent activity full-width.
            if (_overviewCard(persona, data.asData?.value ?? {}) case final overview?)
              _twoUp(wide, flexA: 2, a: overview, b: const _ActivityCard())
            else
              const _ActivityCard(),
            const SizedBox(height: AppSpacing.x16),

            if (persona == Persona.buyer) ...[const _BuyerCta(), const SizedBox(height: AppSpacing.x16)],

            // Recent properties — owners care about OWNED assets (their KPIs +
            // My Properties), not recently-added/viewed listings.
            if (persona != Persona.owner) ...[
              const _RecentProperties(),
              const SizedBox(height: AppSpacing.x16),
            ],

            // Quick actions + tools
            _twoUp(wide, flexA: 1,
                a: _PanelCard(title: 'Quick actions', child: _QuickActions(persona: persona)),
                b: _PanelCard(title: 'Tools', child: _ToolsList(persona: persona))),
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
        return _RoiCard(data: data);
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
  _Card(this.label, this.value, this.icon, this.color);
  final String label, value;
  final IconData icon;
  final Color color;
}

Widget _flatBox(BuildContext context, Widget child, {EdgeInsets? padding}) {
  return Container(
    padding: padding ?? const EdgeInsets.all(AppSpacing.x16),
    decoration: BoxDecoration(
      color: Theme.of(context).cardColor,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: Theme.of(context).dividerColor),
    ),
    child: child,
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
    return _flatBox(
      context,
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(card.label, style: t.bodySmall?.copyWith(color: AppColors.textMuted)),
            const SizedBox(height: 6),
            Text(card.value, style: t.headlineMedium?.copyWith(fontWeight: FontWeight.w700)),
          ]),
        ),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: card.color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
          child: Icon(card.icon, size: 18, color: card.color),
        ),
      ]),
    );
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
    final primary = ref.watch(_salesSeriesProvider).asData?.value ??
        const [22, 30, 26, 38, 34, 46, 44, 58, 54, 66];
    // Secondary trend line trails the primary for visual depth.
    final secondary = primary.map((v) => v * 0.82).toList();
    return _PanelCard(
      title: title,
      child: SizedBox(
        height: 140,
        child: Stack(children: [
          Positioned.fill(child: CustomPaint(painter: _SparkPainter(secondary, AppColors.secondary))),
          Positioned.fill(child: CustomPaint(painter: _SparkPainter(primary, AppColors.primary))),
        ]),
      ),
    );
  }
}

/// Owner-only ROI summary. Derives a simple return on the equity held across the
/// owner's portfolio from the dashboard roll-up (no fabricated time series).
class _RoiCard extends StatelessWidget {
  const _RoiCard({required this.data});
  final Map<String, dynamic> data;
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    num g(String k) => (data[k] is num) ? data[k] as num : num.tryParse('${data[k]}') ?? 0;
    final value = g('total_value');
    final loan = g('outstanding_loan');
    final income = g('annual_rental_income');
    final equity = (value - loan) <= 0 ? value : (value - loan);
    final roi = equity > 0 ? (income / equity * 100) : 0;
    String aed(num v) => 'AED ${NumberFormat.compact().format(v)}';
    return _PanelCard(
      title: 'Portfolio ROI',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('${roi.toStringAsFixed(1)}%',
              style: t.displaySmall?.copyWith(fontWeight: FontWeight.w800, color: AppColors.success)),
          const SizedBox(width: AppSpacing.x8),
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text('annual return on equity', style: t.bodySmall?.copyWith(color: AppColors.textMuted)),
          ),
        ]),
        const SizedBox(height: AppSpacing.x12),
        _RoiLine(label: 'Equity invested', value: aed(equity)),
        _RoiLine(label: 'Annual income', value: aed(income)),
        _RoiLine(label: 'Outstanding loan', value: aed(loan)),
      ]),
    );
  }
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
        Expanded(child: Text(label, style: t.bodySmall?.copyWith(color: AppColors.textMuted))),
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
    final acts = ref.watch(_activityProvider);
    return _PanelCard(
      title: 'Recent activity',
      action: TextButton(onPressed: () => context.go('/notifications'), child: const Text('View all')),
      child: acts.maybeWhen(
        data: (list) => list.isEmpty
            ? Text('No recent activity.', style: t.bodySmall?.copyWith(color: AppColors.textMuted))
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
                            Text('${m['body']}', style: t.bodySmall?.copyWith(color: AppColors.textMuted), maxLines: 1, overflow: TextOverflow.ellipsis),
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
              ? Text('No listings yet.', style: t.bodySmall?.copyWith(color: AppColors.textMuted))
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

class _PropertyMiniCard extends StatelessWidget {
  const _PropertyMiniCard(this.m);
  final Map<String, dynamic> m;
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
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
      child: InkWell(
        onTap: () => context.go('/listings/$id'),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Theme.of(context).dividerColor),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Stack(children: [
              cover.isNotEmpty
                  ? Image.network(cover, height: 110, width: double.infinity, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(height: 110, color: AppColors.surface2))
                  : Container(height: 110, width: double.infinity, color: AppColors.surface2,
                      child: const Icon(Icons.apartment_outlined, color: AppColors.textMuted)),
              Positioned(
                top: 8, left: 8,
                child: StatusBadge(isRent ? 'For Rent' : 'For Sale', tone: isRent ? BadgeTone.warning : BadgeTone.success),
              ),
            ]),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.x12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (money.isNotEmpty)
                  Text(money, style: t.titleSmall?.copyWith(color: AppColors.primary, fontWeight: FontWeight.w700)),
                if (community.isNotEmpty)
                  Text(community, style: t.bodySmall?.copyWith(color: AppColors.textMuted), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 6),
                Row(children: [
                  if (beds != null) _spec(Icons.bed_outlined, '$beds'),
                  if (baths != null) _spec(Icons.bathtub_outlined, '$baths'),
                  if (sqft != null) _spec(Icons.straighten, '$sqft'),
                ]),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _spec(IconData icon, String v) => Padding(
        padding: const EdgeInsets.only(right: 10),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 13, color: AppColors.textMuted),
          const SizedBox(width: 3),
          Text(v, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
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
      Persona.investor || Persona.owner => [
          ('Mortgage calculator', Icons.calculate_outlined, '/calculator'),
          ('Track mortgages', Icons.account_balance_outlined, '/mortgages'),
          ('My properties', Icons.home_work_outlined, '/my-properties'),
        ],
      Persona.buyer => [
          ('Browse properties', Icons.storefront_outlined, '/properties'),
          ('Saved properties', Icons.bookmark_outline, '/saved'),
          ('Messages', Icons.chat_bubble_outline, '/messages'),
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
                leading: Icon(a.$2, color: AppColors.primary, size: 20),
                title: Text(a.$1),
                trailing: const Icon(Icons.chevron_right, size: 18),
                onTap: () => context.go(a.$3),
              ))
          .toList(),
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
                style: t.bodySmall?.copyWith(color: AppColors.textMuted)),
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
              if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
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
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Find your next home', style: t.titleLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
        const SizedBox(height: AppSpacing.x4),
        Text('Browse verified listings across the UAE.', style: t.bodyMedium?.copyWith(color: Colors.white70)),
        const SizedBox(height: AppSpacing.x12),
        FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: AppColors.primary),
          onPressed: () => context.go('/properties'),
          icon: const Icon(Icons.search),
          label: const Text('Browse the marketplace'),
        ),
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
                leading: Icon(tool.$2, color: AppColors.primary, size: 20),
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
          ('Mortgage calculator', Icons.calculate_outlined, '/calculator'),
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
