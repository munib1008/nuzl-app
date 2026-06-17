import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/nuzl_logo.dart';

class _Plan {
  const _Plan(this.name, this.price, this.period, this.features, {this.highlighted = false, this.cta = 'Get started'});
  final String name;
  final String price; // 'Free', 'AED 29', …
  final String period; // '', '/month', '/year'
  final List<String> features;
  final bool highlighted;
  final String cta;
}

const _roles = ['Customer', 'Owner', 'Agent', 'Brokerage', 'Service Provider', 'Supplier'];

const _plans = <String, List<_Plan>>{
  'Customer': [
    _Plan('Free', 'Free', ' forever', [
      'Property search', 'Save properties', 'Viewing requests', 'Messages',
      'Finance Planner', 'Marketplace access', 'Market insights',
    ], highlighted: true, cta: 'Create free account'),
  ],
  'Owner': [
    _Plan('Free Owner', 'Free', '', [
      '1 property', 'Tenant tracking', 'Ownership records', 'Document storage', 'Basic maintenance',
    ]),
    _Plan('Owner Plus', 'AED 29', '/month', [
      'Up to 5 properties', 'Advanced maintenance', 'Expense tracking',
      'Property performance', 'Service marketplace',
    ], highlighted: true),
    _Plan('Owner Pro', 'AED 79', '/month', [
      'Unlimited properties', 'Portfolio dashboard', 'Advanced analytics',
      'Investment tracking', 'Priority support',
    ]),
  ],
  'Agent': [
    _Plan('Individual Agent', 'Free', '', ['1 active listing', 'Basic CRM', 'Viewing management']),
    _Plan('Agent Pro', 'AED 99', '/month', [
      'Unlimited listings', 'Advanced CRM', 'Lead scoring', 'Priority placement', 'Marketing tools', 'Analytics',
    ], highlighted: true),
  ],
  'Brokerage': [
    _Plan('Brokerage', 'AED 499', '/month', [
      'Multi-agent management', 'Lead distribution', 'Commission tracking', 'Office dashboard',
    ], highlighted: true),
  ],
  'Service Provider': [
    _Plan('Free', 'Free', '', ['Basic profile', '5 service listings']),
    _Plan('Professional', 'AED 49', '/month', [
      'Unlimited services', 'Featured placement', 'Lead management', 'Performance dashboard',
    ], highlighted: true),
  ],
  'Supplier': [
    _Plan('Free', 'Free', '', ['10 products']),
    _Plan('Business', 'AED 99', '/month', [
      'Unlimited products', 'Storefront', 'Order analytics', 'Featured listings',
    ], highlighted: true),
  ],
};

const _faqs = [
  ('Is NUZL free?', 'Yes — during Early Access the platform is free, and customers stay free forever. Owners, agents, '
      'service providers and suppliers can start on a free plan and upgrade only when they need more.'),
  ('Who pays?', 'Customers never pay — they bring demand. Professionals (owners with multiple properties, agents, '
      'brokerages, service providers and suppliers) pay for higher limits and pro tools.'),
  ('Can I upgrade or downgrade later?', 'Yes. Start free and move to a paid plan whenever you outgrow the limits; '
      'you can change or cancel anytime.'),
  ('What is the Founding Member Program?', 'Join before the official launch and manage up to 5 properties free for '
      'life, with Owner Plus features and a Founder badge.'),
];

class PricingScreen extends StatefulWidget {
  const PricingScreen({super.key});
  @override
  State<PricingScreen> createState() => _PricingScreenState();
}

class _PricingScreenState extends State<PricingScreen> {
  String _role = 'Owner';

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final wide = MediaQuery.of(context).size.width >= 760;
    final plans = _plans[_role] ?? const [];

    return Scaffold(
      appBar: AppBar(
        titleSpacing: AppSpacing.x16,
        title: InkWell(onTap: () => context.go('/'), child: const NuzlLogo(size: 26)),
        actions: [
          TextButton(onPressed: () => context.go('/login'), child: const Text('Sign in')),
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.x12, left: AppSpacing.x8),
            child: FilledButton(onPressed: () => context.go('/register'), child: const Text('Join free')),
          ),
        ],
      ),
      body: ListView(
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1040),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.x24),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  // Early-access banner
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSpacing.x16),
                    decoration: BoxDecoration(
                      color: AppColors.accentGold.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppSpacing.rCard),
                      border: Border.all(color: AppColors.accentGold.withValues(alpha: 0.35)),
                    ),
                    child: Row(children: [
                      const Icon(Icons.workspace_premium_outlined, color: AppColors.accentGold),
                      const SizedBox(width: AppSpacing.x12),
                      Expanded(
                        child: Text(
                          'NUZL Early Access — join today and receive founding-member benefits before public launch.',
                          style: t.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ]),
                  ),
                  const SizedBox(height: AppSpacing.x24),

                  // Hero
                  Text('Simple pricing. Scale as you grow.', style: t.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: AppSpacing.x8),
                  Text('Start free. Upgrade only when you need more — built for owners, agents, tenants, '
                      'service providers and suppliers.',
                      style: t.bodyLarge?.copyWith(color: AppColors.textMuted)),
                  const SizedBox(height: AppSpacing.x24),

                  // Role selector
                  Text('CHOOSE YOUR ROLE',
                      style: t.labelSmall?.copyWith(color: AppColors.textMuted, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
                  const SizedBox(height: AppSpacing.x8),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    for (final r in _roles)
                      ChoiceChip(
                        label: Text(r),
                        selected: _role == r,
                        onSelected: (_) => setState(() => _role = r),
                      ),
                  ]),
                  const SizedBox(height: AppSpacing.x24),

                  // Plan cards
                  Wrap(
                    spacing: AppSpacing.x16,
                    runSpacing: AppSpacing.x16,
                    children: [
                      for (final p in plans)
                        SizedBox(width: wide ? 300 : double.infinity, child: _PlanCard(plan: p)),
                    ],
                  ),

                  if (_role == 'Customer') ...[
                    const SizedBox(height: AppSpacing.x12),
                    Text('Customers never pay — your access stays free for life.',
                        style: t.bodySmall?.copyWith(color: AppColors.textMuted)),
                  ],

                  // Founder program (owners)
                  if (_role == 'Owner') ...[
                    const SizedBox(height: AppSpacing.x24),
                    const _FounderCard(),
                    const SizedBox(height: AppSpacing.x24),
                    Text('Compare owner plans', style: t.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: AppSpacing.x12),
                    _comparison(context),
                  ],

                  // FAQ
                  const SizedBox(height: AppSpacing.x32),
                  Text('Frequently asked questions', style: t.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: AppSpacing.x8),
                  for (final f in _faqs)
                    Card(
                      margin: const EdgeInsets.only(bottom: AppSpacing.x8),
                      child: ExpansionTile(
                        title: Text(f.$1, style: t.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                        childrenPadding: const EdgeInsets.fromLTRB(AppSpacing.x16, 0, AppSpacing.x16, AppSpacing.x16),
                        children: [
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(f.$2, style: t.bodyMedium?.copyWith(color: AppColors.textMuted, height: 1.5)),
                          ),
                        ],
                      ),
                    ),

                  // Bottom CTA
                  const SizedBox(height: AppSpacing.x24),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSpacing.x24),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [AppColors.gradientStart, AppColors.gradientEnd]),
                      borderRadius: BorderRadius.circular(AppSpacing.rCard),
                    ),
                    child: Column(children: [
                      Text('Start free during Early Access',
                          textAlign: TextAlign.center,
                          style: t.titleLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
                      const SizedBox(height: AppSpacing.x4),
                      Text('Customer access free forever · 1 property free for owners · Founding-member benefits',
                          textAlign: TextAlign.center, style: t.bodyMedium?.copyWith(color: Colors.white70)),
                      const SizedBox(height: AppSpacing.x16),
                      FilledButton(
                        onPressed: () => context.go('/register'),
                        style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: AppColors.primary),
                        child: const Text('Join free'),
                      ),
                    ]),
                  ),
                  const SizedBox(height: AppSpacing.x24),
                ]),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _comparison(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final border = Theme.of(context).dividerColor;
    const rows = [
      ('Properties', '1', '5', 'Unlimited'),
      ('Documents', '✓', '✓', '✓'),
      ('Maintenance', 'Basic', 'Advanced', 'Advanced'),
      ('Analytics', '—', 'Basic', 'Advanced'),
      ('Marketplace', '✓', '✓', '✓'),
      ('Priority support', '—', '—', '✓'),
    ];
    TableRow head() => TableRow(
          decoration: const BoxDecoration(color: AppColors.surface2),
          children: [
            for (final h in ['Feature', 'Free', 'Plus', 'Pro'])
              Padding(
                padding: const EdgeInsets.all(AppSpacing.x12),
                child: Text(h, style: t.labelLarge?.copyWith(fontWeight: FontWeight.w700)),
              ),
          ],
        );
    return Container(
      decoration: BoxDecoration(border: Border.all(color: border), borderRadius: BorderRadius.circular(AppSpacing.rMd)),
      clipBehavior: Clip.antiAlias,
      child: Table(
        border: TableBorder(horizontalInside: BorderSide(color: border)),
        columnWidths: const {0: FlexColumnWidth(2)},
        children: [
          head(),
          for (final r in rows)
            TableRow(children: [
              Padding(padding: const EdgeInsets.all(AppSpacing.x12), child: Text(r.$1)),
              Padding(padding: const EdgeInsets.all(AppSpacing.x12), child: Text(r.$2, textAlign: TextAlign.center)),
              Padding(padding: const EdgeInsets.all(AppSpacing.x12), child: Text(r.$3, textAlign: TextAlign.center)),
              Padding(padding: const EdgeInsets.all(AppSpacing.x12), child: Text(r.$4, textAlign: TextAlign.center)),
            ]),
        ],
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({required this.plan});
  final _Plan plan;
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.x20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(AppSpacing.rCard),
        border: Border.all(
            color: plan.highlighted ? AppColors.primary : Theme.of(context).dividerColor,
            width: plan.highlighted ? 1.5 : 1),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        if (plan.highlighted)
          Container(
            margin: const EdgeInsets.only(bottom: AppSpacing.x8),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(AppSpacing.rFull)),
            child: Text('Most popular', style: t.labelSmall?.copyWith(color: AppColors.primary, fontWeight: FontWeight.w700)),
          ),
        Text(plan.name, style: t.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: AppSpacing.x8),
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(plan.price, style: t.headlineMedium?.copyWith(fontWeight: FontWeight.w800, color: AppColors.primary)),
          if (plan.period.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 4, left: 2),
              child: Text(plan.period, style: t.bodyMedium?.copyWith(color: AppColors.textMuted)),
            ),
        ]),
        const SizedBox(height: AppSpacing.x16),
        for (final f in plan.features)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.check_circle, size: 16, color: AppColors.success),
              const SizedBox(width: AppSpacing.x8),
              Expanded(child: Text(f, style: t.bodyMedium)),
            ]),
          ),
        const SizedBox(height: AppSpacing.x16),
        SizedBox(
          width: double.infinity,
          child: plan.highlighted
              ? FilledButton(onPressed: () => context.go('/register'), child: Text(plan.cta))
              : OutlinedButton(onPressed: () => context.go('/register'), child: Text(plan.cta)),
        ),
      ]),
    );
  }
}

class _FounderCard extends StatelessWidget {
  const _FounderCard();
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.x20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [AppColors.gradientStart, AppColors.gradientEnd]),
        borderRadius: BorderRadius.circular(AppSpacing.rCard),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.verified, color: AppColors.goldAccent, size: 20),
          const SizedBox(width: AppSpacing.x8),
          Text('Founding Member Program',
              style: t.titleLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: AppSpacing.x8),
        Text('Join before the official launch and receive management for up to 5 properties free for life — '
            'Owner Plus features and a Founder badge included.',
            style: t.bodyMedium?.copyWith(color: Colors.white70, height: 1.5)),
        const SizedBox(height: AppSpacing.x16),
        FilledButton(
          onPressed: () => context.go('/register'),
          style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: AppColors.primary),
          child: const Text('Become a founding member'),
        ),
      ]),
    );
  }
}
