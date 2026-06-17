import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/network/api_client.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/theme_mode_provider.dart';
import '../../core/widgets/fade_in.dart';
import '../../core/widgets/gradient_button.dart';
import '../../core/widgets/nuzl_logo.dart';
import '../mortgage/presentation/calculator_screen.dart';

// Theme-aware color helpers — the landing follows light/dark like the rest of the app.
bool _isDark(BuildContext c) => Theme.of(c).brightness == Brightness.dark;
Color _surface(BuildContext c) => Theme.of(c).colorScheme.surface;
Color _border(BuildContext c) => Theme.of(c).dividerColor;
Color _onBg(BuildContext c) => Theme.of(c).colorScheme.onSurface;
Color _muted(BuildContext c) => _isDark(c) ? AppColors.dTextMuted : AppColors.textMuted;
Color _subtle(BuildContext c) => _isDark(c) ? AppColors.dTextSubtle : AppColors.textSubtle;
Color _primary(BuildContext c) => Theme.of(c).colorScheme.primary;
Color _borderStrong(BuildContext c) => _isDark(c) ? AppColors.dBorderStrong : AppColors.borderStrong;

/// A consistent full-width section: centered, max content width, heading + optional
/// subtitle (capped to 700px for readability), then the body.
Widget _section(BuildContext context,
    {required String title, String? subtitle, required Widget child, Color? bg}) {
  final t = Theme.of(context).textTheme;
  final wide = MediaQuery.of(context).size.width >= 900;
  return Container(
    width: double.infinity,
    color: bg,
    padding: const EdgeInsets.symmetric(vertical: AppSpacing.x40),
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1040),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title,
                style: GoogleFonts.poppins(
                    fontSize: wide ? 30 : 24, fontWeight: FontWeight.w600, color: _onBg(context))),
            if (subtitle != null) ...[
              const SizedBox(height: AppSpacing.x4),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 700),
                child: Text(subtitle, style: t.bodyMedium?.copyWith(color: _muted(context), height: 1.6)),
              ),
            ],
            const SizedBox(height: AppSpacing.x20),
            child,
          ]),
        ),
      ),
    ),
  );
}

/// Public landing page — outcome-first information architecture.
class LandingScreen extends StatelessWidget {
  const LandingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _StickyTopBar(), // stays pinned while content scrolls
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _Hero(),
                    _WhoAreYou(),
                    _Ecosystem(),
                    _FeaturedListings(),
                    _WhyNuzl(),
                    _MainModules(),
                    _MarketIntelligence(),
                    _HowItWorks(),
                    _CalculatorSection(),
                    _Testimonials(),
                    _FinalCta(),
                    _Footer(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StickyTopBar extends ConsumerWidget {
  const _StickyTopBar();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(bottom: BorderSide(color: _border(context))),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1040),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x24, vertical: AppSpacing.x12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                InkWell(onTap: () => context.go('/'), child: const NuzlLogo(size: 36)),
                Flexible(
                  child: Wrap(
                    alignment: WrapAlignment.end,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: AppSpacing.x8,
                    runSpacing: AppSpacing.x4,
                    children: [
                      IconButton(
                        tooltip: 'Toggle light / dark',
                        icon: Icon(_isDark(context) ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                            color: _onBg(context)),
                        onPressed: () => ref.read(themeModeProvider.notifier).toggle(),
                      ),
                      TextButton(
                        onPressed: () => context.go('/login'),
                        child: Text('Sign in',
                            style: GoogleFonts.poppins(color: _onBg(context), fontWeight: FontWeight.w600)),
                      ),
                      FilledButton(
                        onPressed: () => context.go('/register'),
                        style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
                        child: const Text('Join NUZL'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Section 1 — Hero ─────────────────────────────────────────────────────────
class _Hero extends StatelessWidget {
  const _Hero();
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final wide = MediaQuery.of(context).size.width >= 900;
    return FadeIn(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1040),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.x24, AppSpacing.x48, AppSpacing.x24, AppSpacing.x40),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('The Real Estate\nOperating System',
                  style: GoogleFonts.poppins(
                      fontSize: wide ? 52 : 34, height: 1.1, fontWeight: FontWeight.w700, color: _onBg(context))),
              const SizedBox(height: AppSpacing.x16),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 700),
                child: Text(
                  'Manage properties, ownership, leasing, mortgages, tenancy, services and '
                  'investments — in one platform. For owners, buyers, tenants, agents, service '
                  'providers and real-estate professionals.',
                  style: t.bodyLarge?.copyWith(color: _muted(context), height: 1.6),
                ),
              ),
              const SizedBox(height: AppSpacing.x24),
              Wrap(spacing: AppSpacing.x12, runSpacing: AppSpacing.x12, children: [
                GradientButton(
                  onPressed: () => context.go('/login'),
                  label: 'Explore properties',
                  icon: Icons.arrow_forward,
                ),
                OutlinedButton(
                  onPressed: () => context.go('/register'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _onBg(context),
                    side: BorderSide(color: _borderStrong(context)),
                    minimumSize: const Size(0, 48),
                  ),
                  child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: AppSpacing.x16), child: Text('Join NUZL')),
                ),
              ]),
            ]),
          ),
        ),
      ),
    );
  }
}

// ── Section 2 — Who are you? ─────────────────────────────────────────────────
class _WhoAreYou extends StatelessWidget {
  const _WhoAreYou();
  static const _roles = [
    (Icons.home_work_outlined, 'Owner', 'Manage properties, tenants, documents, payments and maintenance.'),
    (Icons.search_outlined, 'Customer', 'Find properties, rent, buy, track tenancy and discover opportunities.'),
    (Icons.badge_outlined, 'Agent', 'Generate leads, manage listings and close deals.'),
    (Icons.build_outlined, 'Service Provider', 'Offer maintenance and property-related services.'),
    (Icons.inventory_2_outlined, 'Product Supplier', 'Sell products and materials to owners and tenants.'),
  ];
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final wide = MediaQuery.of(context).size.width >= 900;
    return _section(
      context,
      title: 'Who are you?',
      subtitle: 'One platform that adapts to your role.',
      child: Wrap(
        spacing: AppSpacing.x16,
        runSpacing: AppSpacing.x16,
        children: _roles
            .map((r) => Container(
                  width: wide ? 320 : double.infinity,
                  height: 150,
                  padding: const EdgeInsets.all(AppSpacing.x20),
                  decoration: BoxDecoration(
                    color: _surface(context),
                    borderRadius: BorderRadius.circular(AppSpacing.rCard),
                    border: Border.all(color: _border(context)),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Icon(r.$1, color: _primary(context), size: 28),
                    const SizedBox(height: AppSpacing.x12),
                    Text(r.$2,
                        style: GoogleFonts.poppins(
                            fontSize: 17, fontWeight: FontWeight.w600, color: _onBg(context))),
                    const SizedBox(height: AppSpacing.x4),
                    Expanded(
                      child: Text(r.$3,
                          style: t.bodySmall?.copyWith(color: _muted(context), height: 1.4)),
                    ),
                  ]),
                ))
            .toList(),
      ),
    );
  }
}

// ── Section 3 — Everything connected ─────────────────────────────────────────
class _Ecosystem extends StatelessWidget {
  const _Ecosystem();
  static const _nodes = [
    'Owner', 'Agent', 'Customer', 'Tenant', 'Service Provider', 'Supplier', 'Mortgage Advisor'
  ];
  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[];
    for (var i = 0; i < _nodes.length; i++) {
      chips.add(Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x16, vertical: AppSpacing.x12),
        decoration: BoxDecoration(
          color: _primary(context).withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(AppSpacing.rFull),
          border: Border.all(color: _primary(context).withValues(alpha: 0.25)),
        ),
        child: Text(_nodes[i],
            style: GoogleFonts.poppins(color: _primary(context), fontWeight: FontWeight.w600, fontSize: 14)),
      ));
      if (i < _nodes.length - 1) {
        chips.add(Icon(Icons.sync_alt, size: 16, color: _subtle(context)));
      }
    }
    return _section(
      context,
      title: 'Everything connected',
      subtitle: 'Single source of truth. One property. One platform — every party works off the same record.',
      bg: _surface(context),
      child: Wrap(
        spacing: AppSpacing.x8,
        runSpacing: AppSpacing.x12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: chips,
      ),
    );
  }
}

// ── Section 5 — Why NUZL ─────────────────────────────────────────────────────
class _WhyNuzl extends StatelessWidget {
  const _WhyNuzl();
  static const _traditional = [
    'Only listings',
    'No ownership management',
    'No tenancy tracking',
    'No service coordination',
  ];
  static const _nuzl = [
    'Property discovery',
    'Ownership management',
    'Leasing CRM',
    'Mortgage tracking',
    'Tenant management',
    'Service & product marketplace',
  ];
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final wide = MediaQuery.of(context).size.width >= 900;

    Widget panel(String title, List<String> items, bool good) => Container(
          width: wide ? 420 : double.infinity,
          padding: const EdgeInsets.all(AppSpacing.x20),
          decoration: BoxDecoration(
            color: _surface(context),
            borderRadius: BorderRadius.circular(AppSpacing.rCard),
            border: Border.all(color: good ? _primary(context).withValues(alpha: 0.4) : _border(context)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title,
                style: GoogleFonts.poppins(fontSize: 17, fontWeight: FontWeight.w600, color: _onBg(context))),
            const SizedBox(height: AppSpacing.x12),
            ...items.map((line) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.x8),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 2, right: AppSpacing.x8),
                      child: Icon(good ? Icons.check_circle : Icons.cancel_outlined,
                          size: 18, color: good ? AppColors.success : _subtle(context)),
                    ),
                    Expanded(child: Text(line, style: t.bodyMedium?.copyWith(color: _muted(context), height: 1.4))),
                  ]),
                )),
          ]),
        );

    return _section(
      context,
      title: 'Why NUZL',
      subtitle: 'Traditional platforms stop at listings. NUZL runs the whole property lifecycle.',
      child: Wrap(spacing: AppSpacing.x16, runSpacing: AppSpacing.x16, children: [
        panel('Traditional platforms', _traditional, false),
        panel('NUZL', _nuzl, true),
      ]),
    );
  }
}

// ── Section 6 — Main modules ─────────────────────────────────────────────────
class _MainModules extends StatelessWidget {
  const _MainModules();
  static const _modules = [
    (Icons.apartment_outlined, 'Properties', 'Buy, sell, rent and invest.'),
    (Icons.verified_user_outlined, 'Ownership', 'Track documents, tenants and payments.'),
    (Icons.trending_up, 'Leasing CRM', 'Manage inquiries and deals.'),
    (Icons.account_balance_outlined, 'Mortgage Finance', 'Track home financing and repayments.'),
    (Icons.handyman_outlined, 'Services Marketplace', 'Book maintenance and professional services.'),
    (Icons.shopping_bag_outlined, 'Products Marketplace', 'Purchase products and materials.'),
  ];
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final wide = MediaQuery.of(context).size.width >= 900;
    return _section(
      context,
      title: 'Everything in one place',
      subtitle: 'Six core modules cover the entire journey — discover the rest as you go.',
      bg: _surface(context),
      child: Wrap(
        spacing: AppSpacing.x16,
        runSpacing: AppSpacing.x16,
        children: _modules
            .map((m) => Container(
                  width: wide ? 320 : double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.x20),
                  decoration: BoxDecoration(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    borderRadius: BorderRadius.circular(AppSpacing.rCard),
                    border: Border.all(color: _border(context)),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Icon(m.$1, color: _primary(context), size: 26),
                    const SizedBox(height: AppSpacing.x12),
                    Text(m.$2,
                        style: GoogleFonts.poppins(
                            fontSize: 16, fontWeight: FontWeight.w600, color: _onBg(context))),
                    const SizedBox(height: AppSpacing.x4),
                    Text(m.$3, style: t.bodySmall?.copyWith(color: _muted(context), height: 1.4)),
                  ]),
                ))
            .toList(),
      ),
    );
  }
}

// ── Section 7 — Market intelligence ──────────────────────────────────────────
class _MarketIntelligence extends StatelessWidget {
  const _MarketIntelligence();
  static const _items = [
    (Icons.show_chart, 'Price trends', 'Track sale-price movement by community.'),
    (Icons.trending_up, 'Rental trends', 'See where yields are rising.'),
    (Icons.percent, 'Mortgage rates', 'Watch profit / interest rates over time.'),
    (Icons.location_city_outlined, 'Community insights', 'Supply, occupancy and demand signals.'),
    (Icons.rocket_launch_outlined, 'New launches', 'Be first to new project releases.'),
  ];
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final wide = MediaQuery.of(context).size.width >= 900;
    return _section(
      context,
      title: 'Market intelligence',
      subtitle: 'Stay ahead with the data that drives decisions.',
      child: Wrap(
        spacing: AppSpacing.x16,
        runSpacing: AppSpacing.x16,
        children: _items
            .map((it) => Container(
                  width: wide ? 196 : double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.x16),
                  decoration: BoxDecoration(
                    color: _surface(context),
                    borderRadius: BorderRadius.circular(AppSpacing.rCard),
                    border: Border.all(color: _border(context)),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Icon(it.$1, color: _primary(context), size: 24),
                    const SizedBox(height: AppSpacing.x8),
                    Text(it.$2,
                        style: GoogleFonts.poppins(
                            fontSize: 15, fontWeight: FontWeight.w600, color: _onBg(context))),
                    const SizedBox(height: AppSpacing.x4),
                    Text(it.$3, style: t.bodySmall?.copyWith(color: _muted(context), height: 1.4)),
                  ]),
                ))
            .toList(),
      ),
    );
  }
}

// ── Section 8 — How it works ─────────────────────────────────────────────────
class _HowItWorks extends StatelessWidget {
  const _HowItWorks();
  static const _steps = [
    'Find a property',
    'Buy or rent',
    'Manage ownership',
    'Track finance',
    'Manage tenants',
    'Book services',
  ];
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final wide = MediaQuery.of(context).size.width >= 900;
    return _section(
      context,
      title: 'How it works',
      bg: _surface(context),
      child: Wrap(
        spacing: AppSpacing.x16,
        runSpacing: AppSpacing.x16,
        children: List.generate(_steps.length, (i) {
          return Container(
            width: wide ? 300 : double.infinity,
            padding: const EdgeInsets.all(AppSpacing.x16),
            child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: _primary(context),
                child: Text('${i + 1}',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
              ),
              const SizedBox(width: AppSpacing.x12),
              Expanded(
                child: Text(_steps[i],
                    style: t.titleMedium?.copyWith(color: _onBg(context), fontWeight: FontWeight.w600)),
              ),
            ]),
          );
        }),
      ),
    );
  }
}

// ── Section 9 — Testimonials (placeholder copy — replace with real stories) ──
class _Testimonials extends StatelessWidget {
  const _Testimonials();
  static const _quotes = [
    ('Property Owner', 'I finally see every property, tenant and payment in one place — no more spreadsheets.'),
    ('Agent', 'Leads, listings and deals in one pipeline. I close faster and nothing slips.'),
    ('Tenant', 'My lease, rent schedule and maintenance requests are all in the app.'),
  ];
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final wide = MediaQuery.of(context).size.width >= 900;
    return _section(
      context,
      title: 'Built for everyone in the deal',
      child: Wrap(
        spacing: AppSpacing.x16,
        runSpacing: AppSpacing.x16,
        children: _quotes
            .map((q) => Container(
                  width: wide ? 320 : double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.x20),
                  decoration: BoxDecoration(
                    color: _surface(context),
                    borderRadius: BorderRadius.circular(AppSpacing.rCard),
                    border: Border.all(color: _border(context)),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Icon(Icons.format_quote, color: _primary(context), size: 24),
                    const SizedBox(height: AppSpacing.x8),
                    Text(q.$2, style: t.bodyMedium?.copyWith(color: _onBg(context), height: 1.5)),
                    const SizedBox(height: AppSpacing.x12),
                    Text(q.$1, style: t.bodySmall?.copyWith(color: _muted(context), fontWeight: FontWeight.w600)),
                  ]),
                ))
            .toList(),
      ),
    );
  }
}

// ── Section 10 — Final CTA ───────────────────────────────────────────────────
class _FinalCta extends StatelessWidget {
  const _FinalCta();
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final wide = MediaQuery.of(context).size.width >= 900;
    return Container(
      width: double.infinity,
      color: _surface(context),
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.x64),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x24),
            child: Column(children: [
              Text('Your entire property journey in one platform',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                      fontSize: wide ? 34 : 26, fontWeight: FontWeight.w700, color: _onBg(context), height: 1.2)),
              const SizedBox(height: AppSpacing.x12),
              Text('Buy. Own. Manage. Lease. Maintain.',
                  textAlign: TextAlign.center,
                  style: t.bodyLarge?.copyWith(color: _muted(context))),
              const SizedBox(height: AppSpacing.x24),
              GradientButton(
                onPressed: () => context.go('/register'),
                label: 'Get started',
                icon: Icons.arrow_forward,
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

class _CalculatorSection extends StatelessWidget {
  const _CalculatorSection();
  @override
  Widget build(BuildContext context) {
    return _section(
      context,
      title: 'Mortgage calculator',
      subtitle: 'Estimate a monthly payment instantly — no account needed.',
      child: Container(
        decoration: BoxDecoration(
          color: _surface(context),
          borderRadius: BorderRadius.circular(AppSpacing.rCard),
          border: Border.all(color: _border(context)),
        ),
        child: const CalculatorScreen(embedded: true),
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer();
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final wide = MediaQuery.of(context).size.width >= 900;

    Widget col(String title, List<(String, String)> links) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: GoogleFonts.poppins(color: _onBg(context), fontWeight: FontWeight.w600, fontSize: 15)),
            const SizedBox(height: AppSpacing.x12),
            ...links.map((l) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.x8),
                  child: InkWell(
                    onTap: () => context.go(l.$2),
                    child: Text(l.$1, style: t.bodyMedium?.copyWith(color: _muted(context))),
                  ),
                )),
          ],
        );

    final columns = [
      col('Product', [('Marketplace', '/info/marketplace'), ('Tools', '/info/tools'), ('Pricing', '/info/pricing'), ('Get started', '/register')]),
      col('Company', [('About', '/info/about'), ('Blog', '/info/blog'), ('Partners', '/info/partners'), ('Contact', '/info/contact')]),
      col('Legal', [('Privacy', '/info/privacy'), ('Terms', '/info/terms'), ('Cookies', '/info/cookies')]),
    ];

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(top: BorderSide(color: _border(context))),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1040),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.x32),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Flex(
                direction: wide ? Axis.horizontal : Axis.vertical,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: wide ? 2 : 0,
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const NuzlLogo(size: 34),
                      const SizedBox(height: AppSpacing.x12),
                      SizedBox(
                        width: 280,
                        child: Text('The real-estate operating system. Dubai · Abu Dhabi.',
                            style: t.bodySmall?.copyWith(color: _muted(context), height: 1.5)),
                      ),
                    ]),
                  ),
                  if (!wide) const SizedBox(height: AppSpacing.x32),
                  ...columns.map((c) => Expanded(
                      flex: wide ? 1 : 0,
                      child: Padding(padding: EdgeInsets.only(bottom: wide ? 0 : AppSpacing.x24), child: c))),
                ],
              ),
              const SizedBox(height: AppSpacing.x32),
              Divider(color: _border(context)),
              const SizedBox(height: AppSpacing.x16),
              Text('© 2026 nuzl by Businesstech Arabia FZE, Innovation Licence 6803. All rights reserved.',
                  style: t.bodySmall?.copyWith(color: _subtle(context))),
              const SizedBox(height: AppSpacing.x16),
              Text('Important disclaimer',
                  style: GoogleFonts.poppins(color: _muted(context), fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(height: AppSpacing.x4),
              Text(
                'nuzl is not a real estate broker or agent. We are licensed to conduct opportunity facilitation and operate as a marketplace platform connecting real estate professionals. We are not involved directly in the sale, purchase, or lease of any property units. All real estate transactions are conducted between licensed brokers, agents, and their clients in accordance with UAE real estate regulations. Users must ensure they work with RERA-certified professionals for all property transactions.',
                style: t.bodySmall?.copyWith(color: _subtle(context), height: 1.5),
              ),
              const SizedBox(height: AppSpacing.x16),
            ]),
          ),
        ),
      ),
    );
  }
}

final _featuredListingsProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  try {
    final d = await ref.read(apiClientProvider).get('/public/listings?limit=6');
    return d is List ? d : [];
  } catch (_) {
    return [];
  }
});

// ── Section 4 — Featured properties ──────────────────────────────────────────
class _FeaturedListings extends ConsumerWidget {
  const _FeaturedListings();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wide = MediaQuery.of(context).size.width >= 900;
    final listings = ref.watch(_featuredListingsProvider);
    return _section(
      context,
      title: 'Featured properties',
      subtitle: 'A preview of listings shared by verified agents across the UAE — sign in to view full details.',
      bg: _surface(context),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        listings.when(
          loading: () => const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator())),
          error: (e, _) => const _GalleryEmpty(),
          data: (list) => list.isEmpty
              ? const _GalleryEmpty()
              : Wrap(
                  spacing: AppSpacing.x16,
                  runSpacing: AppSpacing.x16,
                  children: list.asMap().entries.map((e) {
                    final w = wide ? 320.0 : MediaQuery.of(context).size.width - (AppSpacing.x24 * 2);
                    return FadeIn(
                      delayMs: 60 * e.key,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(AppSpacing.rCard),
                        onTap: () => context.go('/login'),
                        child: _ListingCard(data: Map<String, dynamic>.from(e.value), width: w),
                      ),
                    );
                  }).toList()),
        ),
        const SizedBox(height: AppSpacing.x24),
        OutlinedButton(
          onPressed: () => context.go('/login'),
          style: OutlinedButton.styleFrom(foregroundColor: _onBg(context), side: BorderSide(color: _borderStrong(context))),
          child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.x16, vertical: AppSpacing.x8),
              child: Text('Sign in to view all listings')),
        ),
      ]),
    );
  }
}

class _GalleryEmpty extends StatelessWidget {
  const _GalleryEmpty();
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.x40),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(AppSpacing.rCard),
        border: Border.all(color: _border(context)),
      ),
      child: Column(children: [
        Icon(Icons.apartment_outlined, size: 44, color: _primary(context)),
        const SizedBox(height: AppSpacing.x12),
        Text('Listings coming soon', style: t.titleMedium?.copyWith(color: _onBg(context))),
        const SizedBox(height: AppSpacing.x4),
        Text('Verified agents across the UAE will post properties here.',
            style: t.bodySmall?.copyWith(color: _muted(context)), textAlign: TextAlign.center),
      ]),
    );
  }
}

class _ListingCard extends StatelessWidget {
  const _ListingCard({required this.data, required this.width});
  final Map<String, dynamic> data;
  final double width;
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final aed = NumberFormat.currency(symbol: 'AED ', decimalDigits: 0);
    final price = num.tryParse('${data['price']}') ?? 0;
    final cover = data['cover_image']?.toString();
    final purpose = (data['purpose'] ?? '').toString();
    final placeholder = ColoredBox(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: Icon(Icons.apartment, color: _muted(context), size: 40));
    return Container(
      width: width,
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(AppSpacing.rCard),
        border: Border.all(color: _border(context)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        AspectRatio(
          aspectRatio: 16 / 10,
          child: cover != null && cover.isNotEmpty
              ? Image.network(cover, fit: BoxFit.cover, errorBuilder: (_, __, ___) => placeholder)
              : placeholder,
        ),
        Padding(
          padding: const EdgeInsets.all(AppSpacing.x12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                    color: _primary(context).withValues(alpha: 0.14), borderRadius: BorderRadius.circular(AppSpacing.rFull)),
                child: Text(purpose == 'rent' ? 'For rent' : 'For sale',
                    style: t.bodySmall?.copyWith(color: _primary(context), fontWeight: FontWeight.w600)),
              ),
            ]),
            const SizedBox(height: AppSpacing.x8),
            Text(aed.format(price), style: t.titleLarge?.copyWith(color: _onBg(context), fontWeight: FontWeight.w700)),
            const SizedBox(height: AppSpacing.x4),
            Text('${data['property_type'] ?? ''}${data['community'] != null ? ' · ${data['community']}' : ''}',
                style: t.bodySmall?.copyWith(color: _muted(context)), maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: AppSpacing.x8),
            Row(children: [
              _meta(context, Icons.bed_outlined, '${data['bedrooms'] ?? '-'}'),
              const SizedBox(width: AppSpacing.x12),
              _meta(context, Icons.bathtub_outlined, '${data['bathrooms'] ?? '-'}'),
              const SizedBox(width: AppSpacing.x12),
              _meta(context, Icons.straighten, '${data['size_sqft'] ?? '-'} sqft'),
            ]),
          ]),
        ),
      ]),
    );
  }

  Widget _meta(BuildContext context, IconData i, String v) => Row(children: [
        Icon(i, size: 14, color: _muted(context)),
        const SizedBox(width: 4),
        Text(v, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: _muted(context))),
      ]);
}
