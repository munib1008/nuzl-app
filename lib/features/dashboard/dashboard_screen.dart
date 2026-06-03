import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/network/api_client.dart';
import '../../core/rbac/persona.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../auth/application/auth_controller.dart';
import '../shell/app_shell.dart';

/// Pulls the role-appropriate report. Graceful: returns {} on error/no-permission.
final dashboardProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final persona = ref.watch(personaProvider);
  final endpoint = switch (persona) {
    Persona.broker => '/reports/agency',
    Persona.developer => '/reports/developer',
    Persona.investor || Persona.owner => '/reports/investor',
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

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final persona = ref.watch(personaProvider);
    final user = ref.watch(authControllerProvider).user;
    final data = ref.watch(dashboardProvider);
    final wide = MediaQuery.of(context).size.width >= 720;

    final cards = _cardsFor(persona, data.asData?.value ?? {});

    return Scaffold(
      appBar: const NuzlAppBar(title: 'Dashboard'),
      drawer: const NuzlDrawer(),
      body: RefreshIndicator(
      onRefresh: () async => ref.refresh(dashboardProvider.future),
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.x16),
        children: [
          Text('Welcome back${user?.fullName.isNotEmpty == true ? ', ${user!.fullName.split(' ').first}' : ''}',
              style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.w700)),
          const SizedBox(height: AppSpacing.x4),
          Text("Here's what's happening today", style: t.bodyMedium?.copyWith(color: AppColors.textMuted)),
          const SizedBox(height: AppSpacing.x20),

          // hero stat (first card) + grid of the rest
          if (cards.isNotEmpty) ...[
            _HeroStat(card: cards.first),
            const SizedBox(height: AppSpacing.x12),
            GridView.count(
              crossAxisCount: wide ? 3 : 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: AppSpacing.x12,
              crossAxisSpacing: AppSpacing.x12,
              childAspectRatio: 1.5,
              children: cards.skip(1).map((c) => _StatCard(card: c)).toList(),
            ),
            const SizedBox(height: AppSpacing.x24),
          ],

          if (persona == Persona.buyer) ...[
            const _BuyerCta(),
            const SizedBox(height: AppSpacing.x24),
          ],

          Text('Quick actions', style: t.titleMedium),
          const SizedBox(height: AppSpacing.x12),
          _QuickActions(persona: persona),

          const SizedBox(height: AppSpacing.x24),
          Text('Tools', style: t.titleMedium),
          const SizedBox(height: AppSpacing.x12),
          _ToolsGroup(persona: persona),
        ],
      ),
    ));
  }

  List<_Card> _cardsFor(Persona p, Map<String, dynamic> d) {
    num g(String k) => (d[k] is num) ? d[k] as num : num.tryParse('${d[k]}') ?? 0;
    String aed(num v) => 'AED ${v.toStringAsFixed(0)}';
    switch (p) {
      case Persona.broker:
        return [
          _Card('Active leads', '${g('active_leads')}', Icons.trending_up),
          _Card('Active deals', '${g('active_deals')}', Icons.handshake_outlined),
          _Card('Listings', '${g('listings')}', Icons.apartment_outlined),
          _Card('Agents', '${g('agents')}', Icons.groups_outlined),
          _Card('Pipeline', aed(g('revenue_pipeline')), Icons.account_balance_wallet_outlined),
        ];
      case Persona.developer:
        return [
          _Card('Projects', '${g('projects')}', Icons.domain_outlined),
          _Card('Available', '${g('available')}', Icons.check_circle_outline),
          _Card('Reserved', '${g('reserved')}', Icons.lock_clock_outlined),
          _Card('Sold', '${g('sold')}', Icons.sell_outlined),
        ];
      case Persona.investor:
      case Persona.owner:
        return [
          _Card('Properties', '${g('properties')}', Icons.home_work_outlined),
          _Card('Total value', aed(g('total_value')), Icons.real_estate_agent_outlined),
          _Card('Outstanding loan', aed(g('outstanding_loan')), Icons.account_balance_outlined),
          _Card('Rental income', aed(g('annual_rental_income')), Icons.payments_outlined),
        ];
      case Persona.admin:
        return [
          _Card('Organizations', '${g('organizations')}', Icons.business_outlined),
          _Card('Users', '${g('users')}', Icons.people_outline),
          _Card('Subscriptions', '${g('active_subscriptions')}', Icons.workspace_premium_outlined),
          _Card('Active deals', '${g('active_deals')}', Icons.handshake_outlined),
        ];
      default: // agent / lead generator
        return [
          _Card('Active leads', '${g('new_leads') + g('hot_leads')}', Icons.trending_up),
          _Card('Hot leads', '${g('hot_leads')}', Icons.local_fire_department_outlined),
          _Card('Follow-ups', '${g('follow_ups')}', Icons.event_repeat_outlined),
          _Card('Active deals', '${g('active_deals')}', Icons.handshake_outlined),
          _Card('Tasks today', '${g('tasks_due_today')}', Icons.task_alt_outlined),
        ];
    }
  }
}

class _Card {
  _Card(this.label, this.value, this.icon);
  final String label, value;
  final IconData icon;
}

class _HeroStat extends StatelessWidget {
  const _HeroStat({required this.card});
  final _Card card;
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.x20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
            colors: [AppColors.primaryDark, AppColors.primary, Color(0xFF2BB39A)],
            begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(AppSpacing.rLg),
      ),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(card.label, style: t.bodyMedium?.copyWith(color: Colors.white70)),
          const SizedBox(height: AppSpacing.x4),
          Text(card.value, style: t.displaySmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
        ])),
        Icon(card.icon, color: Colors.white, size: 36),
      ]),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.card});
  final _Card card;
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.x16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(AppSpacing.rLg),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Icon(card.icon, color: AppColors.primary, size: 22),
        const Spacer(),
        Text(card.value, style: t.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
        Text(card.label, style: t.bodySmall?.copyWith(color: AppColors.textMuted)),
      ]),
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.persona});
  final Persona persona;
  @override
  Widget build(BuildContext context) {
    final actions = switch (persona) {
      Persona.leadGenerator => [
        ('Post new lead', Icons.add_circle_outline, '/soon/Post Lead'),
        ('Browse marketplace', Icons.storefront_outlined, '/feed'),
        ('Find partners', Icons.people_outline, '/soon/Network'),
      ],
      Persona.developer => [
        ('New project', Icons.domain_add_outlined, '/soon/Projects'),
        ('Manage inventory', Icons.inventory_2_outlined, '/soon/Inventory'),
        ('View feed', Icons.dynamic_feed_outlined, '/feed'),
      ],
      Persona.investor || Persona.owner => [
        ('Mortgage calculator', Icons.calculate_outlined, '/calculator'),
        ('Track mortgages', Icons.account_balance_outlined, '/mortgages'),
        ('My properties', Icons.home_work_outlined, '/soon/My Properties'),
      ],
      _ => [
        ('Add listing', Icons.add_home_work_outlined, '/properties'),
        ('New lead', Icons.person_add_alt, '/leads'),
        ('View deals', Icons.handshake_outlined, '/deals'),
      ],
    };
    return Column(
      children: actions.map((a) => Card(
        child: ListTile(
          leading: Icon(a.$2, color: AppColors.primary),
          title: Text(a.$1),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.go(a.$3),
        ),
      )).toList(),
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
            colors: [AppColors.primaryDark, AppColors.primary],
            begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(AppSpacing.rLg),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Find your next home',
            style: t.titleLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
        const SizedBox(height: AppSpacing.x4),
        Text('Browse verified listings across the UAE.',
            style: t.bodyMedium?.copyWith(color: Colors.white70)),
        const SizedBox(height: AppSpacing.x12),
        FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: AppColors.primary),
          onPressed: () => context.go('/feed'),
          icon: const Icon(Icons.search),
          label: const Text('Browse the marketplace'),
        ),
      ]),
    );
  }
}

/// Per-role tools — only the ones relevant to the persona are shown (§7).
List<(String, IconData, String)> _toolsFor(Persona p) => switch (p) {
      Persona.broker || Persona.agent => [
          ('Lead matcher', Icons.auto_awesome_outlined, '/lead-matches'),
          ('Mortgage calculator', Icons.calculate_outlined, '/calculator'),
          ('Documents', Icons.folder_outlined, '/documents'),
          ('Commission tracker', Icons.payments_outlined, '/soon/Commission'),
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
          ('Mortgage calculator', Icons.calculate_outlined, '/calculator'),
        ],
      Persona.buyer => [
          ('Mortgage calculator', Icons.calculate_outlined, '/calculator'),
          ('Saved searches', Icons.bookmark_outline, '/soon/Saved'),
          ('Viewing scheduler', Icons.event_available_outlined, '/soon/Viewings'),
        ],
      Persona.admin => [
          ('Organizations', Icons.business_outlined, '/organizations'),
          ('Audit logs', Icons.receipt_long_outlined, '/audit'),
          ('Plans', Icons.workspace_premium_outlined, '/plans'),
        ],
    };

class _ToolsGroup extends StatelessWidget {
  const _ToolsGroup({required this.persona});
  final Persona persona;
  @override
  Widget build(BuildContext context) {
    final tools = _toolsFor(persona);
    return LayoutBuilder(
      builder: (ctx, c) {
        final cols = c.maxWidth >= 600 ? 2 : 1;
        final w = cols == 1 ? c.maxWidth : (c.maxWidth - AppSpacing.x12) / 2;
        return Wrap(
          spacing: AppSpacing.x12,
          runSpacing: AppSpacing.x12,
          children: tools
              .map((tool) => SizedBox(
                    width: w,
                    child: Card(
                      child: ListTile(
                        leading: Icon(tool.$2, color: AppColors.primary),
                        title: Text(tool.$1),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => context.go(tool.$3),
                      ),
                    ),
                  ))
              .toList(),
        );
      },
    );
  }
}
