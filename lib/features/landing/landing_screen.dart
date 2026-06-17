import 'dart:math' as math;
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
import '../../core/widgets/hover_lift.dart';
import '../../core/widgets/nuzl_logo.dart';
import '../../core/widgets/auth_prompt.dart';
import '../mortgage/presentation/calculator_screen.dart';

// Theme-aware color helpers — the landing follows light/dark like the rest of the app.
bool _isDark(BuildContext c) => Theme.of(c).brightness == Brightness.dark;

// A featured card opens the public property page when it's a real listing;
// sample teasers (no id) fall to the value-prop sign-up prompt.
void _openListing(BuildContext context, Map<String, dynamic> data) {
  final id = '${data['id'] ?? ''}'.trim();
  if (id.isNotEmpty) {
    context.go('/property/$id');
  } else {
    showAuthPrompt(context, action: 'view full property details');
  }
}
Color _surface(BuildContext c) => Theme.of(c).colorScheme.surface;
Color _border(BuildContext c) => Theme.of(c).dividerColor;
Color _onBg(BuildContext c) => Theme.of(c).colorScheme.onSurface;
Color _muted(BuildContext c) => _isDark(c) ? AppColors.dTextMuted : AppColors.textMuted;
Color _subtle(BuildContext c) => _isDark(c) ? AppColors.dTextSubtle : AppColors.textSubtle;
Color _primary(BuildContext c) => Theme.of(c).colorScheme.primary;
Color _borderStrong(BuildContext c) => _isDark(c) ? AppColors.dBorderStrong : AppColors.borderStrong;
// Higher-contrast body text than the muted grey (review: body was too light).
Color _body(BuildContext c) => _isDark(c) ? AppColors.dTextMuted : const Color(0xFF4A5B65);
// Premium landing card radius (review: 20 -> 24).
const double _kCardR = 24;
// Layered card shadow so cards feel elevated/touchable (review: deeper 3-layer).
List<BoxShadow> _cardShadow(BuildContext c) => _isDark(c)
    ? const [BoxShadow(color: Color(0x40000000), blurRadius: 28, offset: Offset(0, 10))]
    : const [
        BoxShadow(color: Color(0x0D000000), blurRadius: 3, offset: Offset(0, 1)),
        BoxShadow(color: Color(0x14000000), blurRadius: 32, offset: Offset(0, 12)),
        BoxShadow(color: Color(0x0A000000), blurRadius: 64, offset: Offset(0, 24)),
      ];

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
class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key});
  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen> {
  final _scroll = ScrollController();
  final _kFeatured = GlobalKey();
  final _kModules = GlobalKey();
  final _kMarket = GlobalKey();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// Top-nav targets: scroll to a section, or route for Pricing (no landing section).
  void _onNav(String id) {
    if (id == 'pricing') {
      context.go('/pricing');
      return;
    }
    final key = const {'properties': 0, 'marketplace': 1, 'insights': 2}[id];
    final ctx = [_kFeatured, _kModules, _kMarket][key ?? 0].currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 450), curve: Curves.easeInOut);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _StickyTopBar(onNav: _onNav), // stays pinned while content scrolls
            Expanded(
              child: SingleChildScrollView(
                controller: _scroll,
                child: Column(
                  children: [
                    const _Hero(),
                    const _EcosystemTrust(),
                    const _TrustMetrics(),
                    KeyedSubtree(key: _kFeatured, child: const _FeaturedListings()),
                    const _WhoAreYou(),
                    const _Ecosystem(),
                    const _WhyNuzl(),
                    const _PropertyTimeline(),
                    KeyedSubtree(key: _kModules, child: const _MainModules()),
                    KeyedSubtree(key: _kMarket, child: const _MarketIntelligence()),
                    const _HowItWorks(),
                    const _CalculatorSection(),
                    const _Testimonials(),
                    const _FinalCta(),
                    const _Footer(),
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
  const _StickyTopBar({this.onNav});
  final void Function(String id)? onNav;
  static const _nav = [('Properties', 'properties'), ('Marketplace', 'marketplace'), ('Insights', 'insights'), ('Pricing', 'pricing')];
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wide = MediaQuery.of(context).size.width >= 760;
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
                      if (wide)
                        for (final l in _nav)
                          TextButton(
                            onPressed: () => onNav?.call(l.$2),
                            child: Text(l.$1,
                                style: GoogleFonts.poppins(color: _onBg(context), fontWeight: FontWeight.w500)),
                          ),
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
    final textCol = Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      Text('The Real Estate\nOperating System',
          style: GoogleFonts.poppins(
              fontSize: wide ? 52 : 34, height: 1.1, fontWeight: FontWeight.w700, color: _onBg(context))),
      const SizedBox(height: AppSpacing.x16),
      ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: Text(
          'From finding your next property to managing ownership, tenants, mortgages, '
          'maintenance and investments — everything in one place.',
          style: t.bodyLarge?.copyWith(color: _body(context), height: 1.6),
        ),
      ),
      const SizedBox(height: AppSpacing.x12),
      Text('Trusted by owners, buyers, agents and service providers across the UAE.',
          style: t.bodySmall?.copyWith(color: _muted(context), fontWeight: FontWeight.w600)),
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
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.x16), child: Text('Start managing properties')),
        ),
      ]),
    ]);
    return FadeIn(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1040),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.x24, AppSpacing.x48, AppSpacing.x24, AppSpacing.x40),
            child: wide
                ? Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                    Expanded(flex: 5, child: textCol),
                    const SizedBox(width: AppSpacing.x32),
                    const Expanded(flex: 4, child: _HeroPreview()),
                  ])
                : textCol,
          ),
        ),
      ),
    );
  }
}

/// A premium product preview for the hero (pure Flutter — no asset). Gives the
/// hero a "this is a product" feel instead of text-on-empty-space.
class _HeroPreview extends StatelessWidget {
  const _HeroPreview();

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    Widget dot(Color c) => Container(width: 9, height: 9, decoration: BoxDecoration(color: c, shape: BoxShape.circle));
    Widget kpi(String v, String l, Color c) => Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 3),
            padding: const EdgeInsets.all(AppSpacing.x12),
            decoration: BoxDecoration(color: c.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(AppSpacing.rMd)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(v, style: GoogleFonts.poppins(fontSize: 17, fontWeight: FontWeight.w700, color: c)),
              Text(l, style: t.labelSmall?.copyWith(color: _muted(context))),
            ]),
          ),
        );
    return HoverLift(
      child: Container(
        decoration: BoxDecoration(
          color: _surface(context),
          borderRadius: BorderRadius.circular(_kCardR),
          border: Border.all(color: _border(context)),
          boxShadow: _cardShadow(context),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.x12),
            color: _primary(context).withValues(alpha: 0.06),
            child: Row(children: [
              dot(AppColors.danger), const SizedBox(width: 5), dot(AppColors.warning),
              const SizedBox(width: 5), dot(AppColors.success), const SizedBox(width: 10),
              Text('Owner dashboard', style: t.labelMedium?.copyWith(color: _onBg(context))),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.x16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                kpi('24', 'Properties', _primary(context)),
                kpi('92%', 'Occupancy', AppColors.success),
                kpi('AED 8M', 'Portfolio', AppColors.accentGold),
              ]),
              const SizedBox(height: AppSpacing.x12),
              Container(
                padding: const EdgeInsets.all(AppSpacing.x8),
                decoration: BoxDecoration(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    borderRadius: BorderRadius.circular(AppSpacing.rMd),
                    border: Border.all(color: _border(context))),
                child: Row(children: [
                  Container(width: 48, height: 48,
                      decoration: BoxDecoration(color: _primary(context).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(AppSpacing.rSm)),
                      child: Icon(Icons.apartment, color: _primary(context), size: 22)),
                  const SizedBox(width: AppSpacing.x12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Marina Heights · 2BR',
                          style: t.bodySmall?.copyWith(color: _onBg(context), fontWeight: FontWeight.w600)),
                      Text('AED 2.1M · For sale', style: t.labelSmall?.copyWith(color: _muted(context))),
                    ]),
                  ),
                  const Icon(Icons.verified, size: 16, color: AppColors.success),
                ]),
              ),
              const SizedBox(height: AppSpacing.x12),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('Mortgage', style: t.bodySmall?.copyWith(color: _muted(context))),
                Text('78% paid', style: t.bodySmall?.copyWith(color: _onBg(context), fontWeight: FontWeight.w600)),
              ]),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(AppSpacing.rFull),
                child: LinearProgressIndicator(
                    value: 0.78, minHeight: 8, backgroundColor: _border(context), color: _primary(context)),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

/// Trust metrics band directly under the hero (review: instant credibility).
class _TrustMetrics extends StatelessWidget {
  const _TrustMetrics();
  static const _metrics = [
    ('12,000+', 'Properties'),
    ('3,500+', 'Owners'),
    ('850+', 'Agents'),
    ('25,000+', 'Documents managed'),
    ('AED 500M+', 'Assets managed'),
  ];
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Container(
      width: double.infinity,
      color: _surface(context),
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.x32),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1040),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x24),
            child: Column(children: [
              Text('Trusted by property owners across the UAE',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600, color: _onBg(context))),
              const SizedBox(height: AppSpacing.x20),
              Wrap(
                spacing: AppSpacing.x40,
                runSpacing: AppSpacing.x16,
                alignment: WrapAlignment.center,
                children: _metrics
                    .map((m) => Column(children: [
                          Text(m.$1,
                              style: GoogleFonts.poppins(
                                  fontSize: 28, fontWeight: FontWeight.w700, color: _primary(context))),
                          Text(m.$2, style: t.bodySmall?.copyWith(color: _muted(context))),
                        ]))
                    .toList(),
              ),
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
    (Icons.home_work_outlined, 'Own & manage', 'Track ownership, tenants, maintenance and documents.', 'Full ownership dashboard'),
    (Icons.search_outlined, 'Buy, rent & invest', 'Discover, rent and buy with confidence.', '12,000+ listings'),
    (Icons.badge_outlined, 'List & close deals', 'Manage listings, leads and commissions.', 'Lead scoring + CRM'),
    (Icons.build_outlined, 'Deliver services', 'Offer maintenance and property-related services.', 'Orders + tracking'),
    (Icons.inventory_2_outlined, 'Sell products', 'Sell products and materials to owners and tenants.', 'Marketplace storefront'),
  ];
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final wide = MediaQuery.of(context).size.width >= 900;
    return _section(
      context,
      title: 'Built for every real estate journey',
      subtitle: 'Whether you own, buy, rent, lease, manage, service or invest in property, NUZL adapts to your needs.',
      child: Wrap(
        spacing: AppSpacing.x16,
        runSpacing: AppSpacing.x16,
        children: _roles
            .map((r) => HoverLift(
                  child: Container(
                    width: wide ? 320 : double.infinity,
                    height: 188,
                    padding: const EdgeInsets.all(AppSpacing.x20),
                    decoration: BoxDecoration(
                      color: _surface(context),
                      borderRadius: BorderRadius.circular(_kCardR),
                      border: Border.all(color: _border(context)),
                      boxShadow: _cardShadow(context),
                    ),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Icon(r.$1, color: _primary(context), size: 28),
                      const SizedBox(height: AppSpacing.x12),
                      Text(r.$2,
                          style: GoogleFonts.poppins(
                              fontSize: 17, fontWeight: FontWeight.w600, color: _onBg(context))),
                      const SizedBox(height: AppSpacing.x4),
                      Expanded(
                        child: Text(r.$3, style: t.bodySmall?.copyWith(color: _body(context), height: 1.4)),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                            color: _primary(context).withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(AppSpacing.rFull)),
                        child: Text(r.$4,
                            style: t.labelSmall?.copyWith(color: _primary(context), fontWeight: FontWeight.w700)),
                      ),
                    ]),
                  ),
                ))
            .toList(),
      ),
    );
  }
}

// ── Section 3 — Everything connected ─────────────────────────────────────────
class _Ecosystem extends StatefulWidget {
  const _Ecosystem();
  @override
  State<_Ecosystem> createState() => _EcosystemState();
}

class _EcosystemState extends State<_Ecosystem> {
  // The Developer is the ORIGIN of inventory — projects become property records.
  // Everyone else (incl. agents, who are a sales channel, not the owner of stock)
  // connects to that record. Material icons approximate the bespoke NUZL marks.
  static const _developer = (
    role: 'Developer',
    title: 'Project creation & inventory',
    icon: Icons.domain_outlined,
    tags: ['Communities', 'Projects', 'Inventory', 'Sales channels', 'Reservations', 'Handover'],
    color: AppColors.info,
  );
  static const _pillars = [
    (role: 'Owner', title: 'Property Portfolio', icon: Icons.apartment, tags: ['Ownership', 'Tenancy', 'Maintenance'], color: AppColors.secondary),
    (role: 'Agent', title: 'Sales Channel', icon: Icons.handshake_outlined, tags: ['Listings', 'Viewings', 'Offers'], color: AppColors.primary),
    (role: 'Customer', title: 'Property Search', icon: Icons.search, tags: ['Buy', 'Rent', 'Invest'], color: AppColors.success),
    (role: 'Tenant', title: 'Lease Management', icon: Icons.description_outlined, tags: ['Rent', 'Payments', 'Documents'], color: AppColors.primaryBright),
    (role: 'Supplier', title: 'Products', icon: Icons.inventory_2_outlined, tags: ['Furniture', 'Materials', 'Equipment'], color: AppColors.accentGold),
    (role: 'Service Provider', title: 'Maintenance', icon: Icons.build_outlined, tags: ['Repair', 'Cleaning', 'Inspection'], color: AppColors.warning),
  ];

  int? _active; // hovered pillar — drives the central record's highlight
  bool _devActive = false; // hovered developer origin card

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width >= 760;
    final cards = List<Widget>.generate(_pillars.length, (i) {
      final p = _pillars[i];
      return _PillarCard(
        role: p.role, title: p.title, icon: p.icon, tags: p.tags, color: p.color,
        active: _active == i,
        onHover: (h) => setState(() => _active = h ? i : (_active == i ? null : _active)),
      );
    });
    return _section(
      context,
      title: 'One property. One record. One ecosystem.',
      subtitle:
          'Developers create the inventory. Every project becomes a property record that owners, agents, customers, tenants, suppliers and service providers all work from.',
      bg: _surface(context),
      child: wide ? _wide(context, cards) : _stacked(context, cards),
    );
  }

  // Wide: Developer origin → PROPERTY RECORD → two rows of three participants.
  Widget _wide(BuildContext context, List<Widget> cards) {
    Widget rowOf(Iterable<Widget> items) {
      final list = items.toList();
      return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        for (var i = 0; i < list.length; i++) ...[
          if (i > 0) const SizedBox(width: AppSpacing.x16),
          Expanded(child: list[i]),
        ],
      ]);
    }

    return Column(children: [
      Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 540), child: _originCard(context))),
      _creates(context),
      _recordBand(context),
      _connector(context),
      rowOf(cards.take(3)),
      const SizedBox(height: AppSpacing.x16),
      rowOf(cards.skip(3)),
    ]);
  }

  Widget _stacked(BuildContext context, List<Widget> cards) {
    return Column(children: [
      _originCard(context),
      _creates(context),
      _recordBand(context),
      const SizedBox(height: AppSpacing.x16),
      LayoutBuilder(builder: (ctx, cons) {
        final twoCol = cons.maxWidth >= 460;
        final w = twoCol ? (cons.maxWidth - AppSpacing.x12) / 2 : cons.maxWidth;
        return Wrap(
          spacing: AppSpacing.x12,
          runSpacing: AppSpacing.x12,
          children: [for (final c in cards) SizedBox(width: w, child: c)],
        );
      }),
    ]);
  }

  // Developer = the inventory source. Distinct from the participant pillars: it
  // sits above the record with a "SOURCE OF INVENTORY" mark and a "creates" link.
  Widget _originCard(BuildContext context) {
    final t = Theme.of(context).textTheme;
    const dev = AppColors.info;
    return MouseRegion(
      onEnter: (_) => setState(() => _devActive = true),
      onExit: (_) => setState(() => _devActive = false),
      child: HoverLift(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          padding: const EdgeInsets.all(AppSpacing.x20),
          decoration: BoxDecoration(
            color: _surface(context),
            borderRadius: BorderRadius.circular(_kCardR),
            border: Border.all(color: _devActive ? dev : _border(context), width: _devActive ? 1.5 : 1),
            boxShadow: _devActive
                ? [BoxShadow(color: dev.withValues(alpha: 0.25), blurRadius: 24, offset: const Offset(0, 10))]
                : _cardShadow(context),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    color: dev.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(AppSpacing.rMd)),
                child: Icon(_developer.icon, color: dev, size: 24),
              ),
              const SizedBox(width: AppSpacing.x12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 8, runSpacing: 4, children: [
                    Text('DEVELOPER',
                        style: t.labelSmall?.copyWith(color: dev, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                          color: dev.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(AppSpacing.rFull)),
                      child: Text('SOURCE OF INVENTORY',
                          style: t.labelSmall?.copyWith(color: dev, fontWeight: FontWeight.w700, fontSize: 9, letterSpacing: 0.5)),
                    ),
                  ]),
                  Text(_developer.title,
                      style: t.titleSmall?.copyWith(color: _onBg(context), fontWeight: FontWeight.w700)),
                ]),
              ),
            ]),
            const SizedBox(height: AppSpacing.x12),
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final tag in _developer.tags)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                      color: _isDark(context) ? Colors.white10 : AppColors.surface2,
                      borderRadius: BorderRadius.circular(AppSpacing.rFull)),
                  child: Text(tag, style: t.labelSmall?.copyWith(color: _muted(context), fontWeight: FontWeight.w500)),
                ),
            ]),
          ]),
        ),
      ),
    );
  }

  // Developer → record link, labelled "creates".
  Widget _creates(BuildContext context) {
    final on = _devActive ? AppColors.info : _muted(context);
    return Center(
      child: Column(children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 2, height: 14,
          margin: const EdgeInsets.only(top: AppSpacing.x4),
          color: _devActive ? AppColors.info : _border(context),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Text('CREATES',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: on, fontWeight: FontWeight.w700, letterSpacing: 1.5, fontSize: 10)),
        ),
        Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: on),
      ]),
    );
  }

  Widget _connector(BuildContext context) => Center(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 2, height: 18,
          margin: const EdgeInsets.symmetric(vertical: AppSpacing.x4),
          color: _active != null ? _pillars[_active!].color : _border(context),
        ),
      );

  // The source of truth at the centre — glows in the hovered party's colour.
  Widget _recordBand(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final active = _devActive ? AppColors.info : (_active != null ? _pillars[_active!].color : null);
    final activeRole = _devActive ? 'Developer' : (_active != null ? _pillars[_active!].role : null);
    final verb = _devActive ? 'creates this record' : 'works from this record';
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x24, vertical: AppSpacing.x20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
            colors: [AppColors.gradientStart, AppColors.gradientEnd],
            begin: Alignment.centerLeft, end: Alignment.centerRight),
        borderRadius: BorderRadius.circular(_kCardR),
        border: Border.all(color: active ?? Colors.transparent, width: 2),
        boxShadow: active != null
            ? [BoxShadow(color: active.withValues(alpha: 0.45), blurRadius: 28, offset: const Offset(0, 10))]
            : _cardShadow(context),
      ),
      child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.account_tree_outlined, color: AppColors.goldAccent, size: 20),
          const SizedBox(width: AppSpacing.x8),
          Text('PROPERTY RECORD',
              style: GoogleFonts.poppins(
                  color: Colors.white, fontWeight: FontWeight.w700, fontSize: 18, letterSpacing: 1)),
        ]),
        const SizedBox(height: 6),
        Text(
            activeRole != null
                ? '$activeRole $verb'
                : 'One property. One source of truth. Everyone connected.',
            textAlign: TextAlign.center,
            style: t.bodyMedium?.copyWith(color: Colors.white.withValues(alpha: 0.85))),
      ]),
    );
  }
}

/// One ecosystem pillar — icon, role, what they do, and the modules behind it.
/// Reports hover so the central record can highlight, and lights up itself.
class _PillarCard extends StatelessWidget {
  const _PillarCard(
      {required this.role,
      required this.title,
      required this.icon,
      required this.tags,
      required this.color,
      this.active = false,
      this.onHover});
  final String role, title;
  final IconData icon;
  final List<String> tags;
  final Color color;
  final bool active;
  final ValueChanged<bool>? onHover;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return MouseRegion(
      onEnter: (_) => onHover?.call(true),
      onExit: (_) => onHover?.call(false),
      child: HoverLift(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          padding: const EdgeInsets.all(AppSpacing.x16),
          decoration: BoxDecoration(
            color: _surface(context),
            borderRadius: BorderRadius.circular(_kCardR),
            border: Border.all(color: active ? color : _border(context), width: active ? 1.5 : 1),
            boxShadow: active
                ? [BoxShadow(color: color.withValues(alpha: 0.25), blurRadius: 24, offset: const Offset(0, 10))]
                : _cardShadow(context),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(AppSpacing.rMd)),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: AppSpacing.x12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(role.toUpperCase(),
                      style: t.labelSmall?.copyWith(color: color, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
                  Text(title,
                      style: t.titleSmall?.copyWith(color: _onBg(context), fontWeight: FontWeight.w700),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                ]),
              ),
            ]),
            const SizedBox(height: AppSpacing.x12),
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final tag in tags)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                      color: _isDark(context) ? Colors.white10 : AppColors.surface2,
                      borderRadius: BorderRadius.circular(AppSpacing.rFull)),
                  child: Text(tag, style: t.labelSmall?.copyWith(color: _muted(context), fontWeight: FontWeight.w500)),
                ),
            ]),
          ]),
        ),
      ),
    );
  }
}

// ── Section 5 — Why NUZL ─────────────────────────────────────────────────────
class _WhyNuzl extends StatelessWidget {
  const _WhyNuzl();
  // The differentiation is the lifecycle: portals dead-end at the deal; NUZL
  // keeps going. Shown as two side-by-side journeys, not a feature checklist.
  static const _traditional = [
    (Icons.search, 'Search property'),
    (Icons.call_outlined, 'Contact an agent'),
    (Icons.vpn_key_outlined, 'Buy or rent'),
    (Icons.block, 'End of journey'),
  ];
  static const _lifecycle = [
    (Icons.search, 'Search property'),
    (Icons.vpn_key_outlined, 'Buy or rent'),
    (Icons.account_balance_outlined, 'Mortgage tracking'),
    (Icons.description_outlined, 'Ownership records'),
    (Icons.groups_outlined, 'Tenant management'),
    (Icons.build_outlined, 'Maintenance'),
    (Icons.shopping_bag_outlined, 'Marketplace'),
    (Icons.insights_outlined, 'Portfolio insights'),
    (Icons.verified, 'Lifetime management'),
  ];
  static const _stats = [
    ('1', 'Property'),
    ('7', 'Connected roles'),
    ('1', 'Shared record'),
    ('∞', 'Lifetime management'),
  ];

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width >= 900;
    return _section(
      context,
      title: 'Why property owners choose NUZL',
      subtitle: 'Traditional platforms help you buy or rent. NUZL manages everything that happens after.',
      child: Column(children: [
        Wrap(
          alignment: WrapAlignment.center,
          spacing: AppSpacing.x32, runSpacing: AppSpacing.x16,
          children: [for (final s in _stats) _stat(context, s.$1, s.$2)],
        ),
        const SizedBox(height: AppSpacing.x32),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: AppSpacing.x16, runSpacing: AppSpacing.x16,
          children: [
            _journey(context, 'Traditional property portals', _traditional, good: false, wide: wide),
            _journey(context, 'The NUZL property lifecycle', _lifecycle, good: true, wide: wide),
          ],
        ),
      ]),
    );
  }

  Widget _stat(BuildContext context, String value, String label) {
    final t = Theme.of(context).textTheme;
    return SizedBox(
      width: 130,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(value, style: t.displaySmall?.copyWith(color: _primary(context), fontWeight: FontWeight.w800)),
        const SizedBox(height: 2),
        Text(label, textAlign: TextAlign.center, style: t.bodySmall?.copyWith(color: _muted(context))),
      ]),
    );
  }

  Widget _journey(BuildContext context, String title, List<(IconData, String)> steps,
      {required bool good, required bool wide}) {
    final t = Theme.of(context).textTheme;
    final dark = _isDark(context);
    final stepColor = good ? AppColors.secondary : _subtle(context);
    final endColor = good ? AppColors.success : AppColors.danger;
    final bg = good
        ? AppColors.success.withValues(alpha: dark ? 0.10 : 0.06)
        : (dark ? Colors.white10 : AppColors.surface2);
    return Container(
      width: wide ? 420 : double.infinity,
      padding: const EdgeInsets.all(AppSpacing.x20),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(_kCardR),
        border: Border.all(color: good ? AppColors.success.withValues(alpha: 0.35) : _border(context)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700, color: _onBg(context))),
        const SizedBox(height: AppSpacing.x16),
        for (var i = 0; i < steps.length; i++) ...[
          Row(children: [
            Container(
              width: 30, height: 30,
              decoration: BoxDecoration(
                color: (i == steps.length - 1) ? endColor : stepColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(steps[i].$1,
                  size: 16, color: (i == steps.length - 1) ? Colors.white : stepColor),
            ),
            const SizedBox(width: AppSpacing.x12),
            Expanded(
              child: Text(steps[i].$2,
                  style: t.bodyMedium?.copyWith(
                      color: (i == steps.length - 1) ? endColor : _onBg(context),
                      fontWeight: (i == steps.length - 1) ? FontWeight.w700 : FontWeight.w500)),
            ),
          ]),
          if (i < steps.length - 1)
            Padding(
              padding: const EdgeInsets.only(left: 14),
              child: Container(width: 2, height: 14, color: _border(context)),
            ),
        ],
      ]),
    );
  }
}

// ── Section 5b — The property timeline (discovery → ownership) ────────────────
class _PropertyTimeline extends StatelessWidget {
  const _PropertyTimeline();
  static const _steps = [
    (Icons.search, 'Find'),
    (Icons.vpn_key_outlined, 'Buy'),
    (Icons.account_balance_outlined, 'Finance'),
    (Icons.verified_user_outlined, 'Own'),
    (Icons.groups_outlined, 'Lease'),
    (Icons.build_outlined, 'Maintain'),
    (Icons.trending_up, 'Grow'),
  ];
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return _section(
      context,
      title: 'The property timeline',
      subtitle: 'From discovery to ownership — one record at every stage.',
      bg: _surface(context),
      child: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: AppSpacing.x8, runSpacing: AppSpacing.x16,
        children: [
          for (var i = 0; i < _steps.length; i++) ...[
            Column(mainAxisSize: MainAxisSize.min, children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: _primary(context).withValues(alpha: 0.10),
                child: Icon(_steps[i].$1, color: _primary(context), size: 24),
              ),
              const SizedBox(height: 6),
              Text(_steps[i].$2, style: t.labelLarge?.copyWith(color: _onBg(context))),
            ]),
            if (i < _steps.length - 1) Icon(Icons.arrow_forward, size: 18, color: _subtle(context)),
          ],
        ],
      ),
    );
  }
}

// ── Section 1b — Built for the UAE property ecosystem (trust strip) ───────────
class _EcosystemTrust extends StatelessWidget {
  const _EcosystemTrust();
  static const _roles = [
    (Icons.home_work_outlined, 'Owners'),
    (Icons.handshake_outlined, 'Agents'),
    (Icons.vpn_key_outlined, 'Tenants'),
    (Icons.build_outlined, 'Service Providers'),
    (Icons.domain_outlined, 'Developers'),
    (Icons.trending_up, 'Investors'),
  ];
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return _section(
      context,
      title: 'Built for the UAE property ecosystem',
      subtitle: 'Every party in a property’s life — working from one shared record.',
      bg: _surface(context),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: AppSpacing.x12, runSpacing: AppSpacing.x12,
        children: [
          for (final r in _roles)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x16, vertical: AppSpacing.x12),
              decoration: BoxDecoration(
                color: _isDark(context) ? Colors.white10 : AppColors.surface2,
                borderRadius: BorderRadius.circular(AppSpacing.rFull),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(r.$1, size: 18, color: _primary(context)),
                const SizedBox(width: AppSpacing.x8),
                Text(r.$2, style: t.bodyMedium?.copyWith(color: _onBg(context), fontWeight: FontWeight.w600)),
              ]),
            ),
        ],
      ),
    );
  }
}

// ── Section 6 — Main modules ─────────────────────────────────────────────────
class _MainModules extends StatelessWidget {
  const _MainModules();
  // Each module is colour-anchored (top accent + tinted icon) so the eye can
  // navigate by colour — mirrors the in-app dashboard KPI anchors.
  static const _modules = [
    (Icons.apartment_outlined, 'Properties', 'Buy, sell, rent and invest.', AppColors.secondary),
    (Icons.verified_user_outlined, 'Ownership', 'Documents, tenants and payments.', AppColors.primary),
    (Icons.trending_up, 'Leasing CRM', 'Inquiries, leads and deals.', AppColors.success),
    (Icons.account_balance_outlined, 'Mortgage Finance', 'Track financing and repayments.', AppColors.accentGold),
    (Icons.handyman_outlined, 'Services', 'Book maintenance and pro services.', AppColors.warning),
    (Icons.shopping_bag_outlined, 'Marketplace', 'Buy products and materials.', AppColors.primaryBright),
  ];
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final wide = MediaQuery.of(context).size.width >= 900;
    final r = BorderRadius.circular(_kCardR);
    return _section(
      context,
      title: 'Everything in one place',
      subtitle: 'Six core modules cover the entire journey — discover the rest as you go.',
      bg: _surface(context),
      child: Wrap(
        spacing: AppSpacing.x16,
        runSpacing: AppSpacing.x16,
        children: _modules.map((m) {
          final accent = m.$4;
          return HoverLift(
            child: SizedBox(
              width: wide ? 232 : double.infinity,
              child: DecoratedBox(
                decoration: BoxDecoration(borderRadius: r, boxShadow: _cardShadow(context)),
                child: Container(
                  decoration: BoxDecoration(borderRadius: r, border: Border.all(color: _border(context))),
                  child: ClipRRect(
                    borderRadius: r,
                    child: Material(
                      color: _surface(context),
                      child: InkWell(
                        onTap: () => context.go('/login'),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Container(height: 3, color: accent),
                          Padding(
                            padding: const EdgeInsets.all(AppSpacing.x16),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                    color: accent.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(AppSpacing.rMd)),
                                child: Icon(m.$1, color: accent, size: 22),
                              ),
                              const SizedBox(height: AppSpacing.x12),
                              Text(m.$2,
                                  style: GoogleFonts.poppins(
                                      fontSize: 15, fontWeight: FontWeight.w600, color: _onBg(context))),
                              const SizedBox(height: AppSpacing.x4),
                              Text(m.$3, style: t.bodySmall?.copyWith(color: _body(context), height: 1.4)),
                            ]),
                          ),
                        ]),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
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
    (Icons.insights_outlined, 'Area growth', 'Spot where prices are climbing fastest.'),
    (Icons.savings_outlined, 'Investment opportunities', 'High-yield deals matched to your goals.'),
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
            .map((it) => HoverLift(
                  child: Container(
                    width: wide ? 232 : double.infinity,
                    padding: const EdgeInsets.all(AppSpacing.x16),
                    decoration: BoxDecoration(
                      color: _surface(context),
                      borderRadius: BorderRadius.circular(_kCardR),
                      border: Border.all(color: _border(context)),
                      boxShadow: _cardShadow(context),
                    ),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Icon(it.$1, color: _primary(context), size: 24),
                      const SizedBox(height: AppSpacing.x8),
                      Text(it.$2,
                          style: GoogleFonts.poppins(
                              fontSize: 15, fontWeight: FontWeight.w600, color: _onBg(context))),
                      const SizedBox(height: AppSpacing.x4),
                      Text(it.$3, style: t.bodySmall?.copyWith(color: _body(context), height: 1.4)),
                    ]),
                  ),
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
    (Icons.search, 'Find a property'),
    (Icons.handshake_outlined, 'Buy or rent'),
    (Icons.verified_user_outlined, 'Manage ownership'),
    (Icons.account_balance_outlined, 'Track finance'),
    (Icons.people_outline, 'Manage tenants'),
    (Icons.build_outlined, 'Book services'),
  ];
  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width >= 900;
    return _section(
      context,
      title: 'How it works',
      bg: _surface(context),
      child: wide
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < _steps.length; i++) ...[
                  Expanded(child: _step(context, i)),
                  if (i < _steps.length - 1)
                    Padding(
                      padding: const EdgeInsets.only(top: 22),
                      child: Icon(Icons.arrow_forward, size: 18, color: _subtle(context)),
                    ),
                ],
              ],
            )
          : Column(
              children: [
                for (var i = 0; i < _steps.length; i++)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.x8),
                    child: Row(children: [
                      _badge(context, i),
                      const SizedBox(width: AppSpacing.x12),
                      Text(_steps[i].$2,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: _onBg(context), fontWeight: FontWeight.w600)),
                    ]),
                  ),
              ],
            ),
    );
  }

  Widget _badge(BuildContext context, int i) => Container(
        width: 44, height: 44, alignment: Alignment.center,
        decoration: BoxDecoration(color: _primary(context).withValues(alpha: 0.10), shape: BoxShape.circle),
        child: Icon(_steps[i].$1, color: _primary(context), size: 20),
      );

  Widget _step(BuildContext context, int i) {
    final t = Theme.of(context).textTheme;
    return Column(children: [
      Stack(clipBehavior: Clip.none, children: [
        _badge(context, i),
        Positioned(
          right: -2, top: -2,
          child: CircleAvatar(
            radius: 9, backgroundColor: _primary(context),
            child: Text('${i + 1}',
                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
          ),
        ),
      ]),
      const SizedBox(height: AppSpacing.x8),
      Text(_steps[i].$2,
          textAlign: TextAlign.center,
          style: t.bodySmall?.copyWith(color: _onBg(context), fontWeight: FontWeight.w600)),
    ]);
  }
}

// ── Section 9 — Testimonials (placeholder copy — replace with real stories) ──
class _Testimonials extends StatelessWidget {
  const _Testimonials();
  static const _quotes = [
    ('Property Owner', 'I finally see every property, tenant and payment in one place — no more spreadsheets.'),
    ('Agent', 'Leads, listings and deals in one pipeline. I close faster and nothing slips.'),
    ('Tenant', 'My lease, rent schedule and maintenance requests are all in the app.'),
    ('Service Provider', 'Jobs come in, I track every order and get paid — all from one inbox.'),
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
                    borderRadius: BorderRadius.circular(_kCardR),
                    border: Border.all(color: _border(context)),
                    boxShadow: _cardShadow(context),
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
              Text('Ready to manage your entire property journey?',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                      fontSize: wide ? 34 : 26, fontWeight: FontWeight.w700, color: _onBg(context), height: 1.2)),
              const SizedBox(height: AppSpacing.x12),
              Text('Find. Buy. Own. Lease. Finance. Maintain. Grow — all from one platform.',
                  textAlign: TextAlign.center,
                  style: t.bodyLarge?.copyWith(color: _muted(context))),
              const SizedBox(height: AppSpacing.x24),
              // Two distinct destinations only: explore (sign in) vs create an account.
              Wrap(
                spacing: AppSpacing.x12,
                runSpacing: AppSpacing.x12,
                alignment: WrapAlignment.center,
                children: [
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
                        padding: EdgeInsets.symmetric(horizontal: AppSpacing.x16),
                        child: Text('Join NUZL')),
                  ),
                ],
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
          borderRadius: BorderRadius.circular(_kCardR),
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
      col('Product', [('Marketplace', '/info/marketplace'), ('Tools', '/info/tools'), ('Pricing', '/pricing'), ('Get started', '/register')]),
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
    final d = await ref.read(apiClientProvider).get('/public/listings?limit=8');
    return d is List ? d : [];
  } catch (_) {
    return [];
  }
});

// Showcase samples — used to top up the carousel so it never looks sparse. These
// tap through to sign-in (teasers), not to a specific listing. Replace with real
// featured listings as inventory grows.
// Teaser previews for the public landing carousel (clearly labelled "preview …
// sign in to view full details"). Representative stock imagery, as every portal
// uses for marketing showcases; real listings carry their own uploaded photos.
const _sampleListings = [
  {'property_type': 'Villa', 'building_name': 'Signature Villas', 'community': 'Palm Jumeirah', 'purpose': 'sale', 'price': 12500000, 'bedrooms': 5, 'bathrooms': 6, 'size_sqft': 7200, 'verified': true, 'status': 'Vacant', 'furnishing': 'Furnished', 'view': 'Sea view', 'agent_name': 'Layla Hassan', 'cover_image': 'https://images.unsplash.com/photo-1613490493576-7fde63acd811?auto=format&fit=crop&w=800&q=70'},
  {'property_type': 'Apartment', 'building_name': 'Burj Vista 1', 'community': 'Downtown Dubai', 'purpose': 'sale', 'price': 2100000, 'bedrooms': 2, 'bathrooms': 2, 'size_sqft': 1066, 'verified': true, 'status': 'Vacant', 'furnishing': 'Unfurnished', 'view': 'Burj Khalifa view', 'agent_name': 'Omar Khalid', 'cover_image': 'https://images.unsplash.com/photo-1512453979798-5ea266f8880c?auto=format&fit=crop&w=800&q=70'},
  {'property_type': 'Townhouse', 'building_name': 'Palmera 3', 'community': 'Arabian Ranches', 'purpose': 'sale', 'price': 3850000, 'bedrooms': 4, 'bathrooms': 4, 'size_sqft': 2900, 'verified': true, 'status': 'Tenanted', 'furnishing': 'Partly furnished', 'agent_name': 'Sara Aziz', 'cover_image': 'https://images.unsplash.com/photo-1570129477492-45c003edd2be?auto=format&fit=crop&w=800&q=70'},
  {'property_type': 'Office', 'building_name': 'The Prism', 'community': 'Business Bay', 'purpose': 'sale', 'price': 5600000, 'bedrooms': 0, 'bathrooms': 2, 'size_sqft': 3400, 'verified': true, 'status': 'Vacant', 'view': 'Canal view', 'agent_name': 'Yousef Nair', 'cover_image': 'https://images.unsplash.com/photo-1486406146926-c627a92ad1ab?auto=format&fit=crop&w=800&q=70'},
];

// ── Section 4 — Featured properties (horizontal carousel) ────────────────────
class _FeaturedListings extends ConsumerStatefulWidget {
  const _FeaturedListings();
  @override
  ConsumerState<_FeaturedListings> createState() => _FeaturedListingsState();
}

class _FeaturedListingsState extends ConsumerState<_FeaturedListings> {
  final _sc = ScrollController();
  String _filter = 'all';
  static const _height = 440.0;

  @override
  void dispose() {
    _sc.dispose();
    super.dispose();
  }

  void _scrollBy(double dx) {
    if (!_sc.hasClients) return;
    final target = (_sc.offset + dx).clamp(0.0, _sc.position.maxScrollExtent);
    _sc.animateTo(target, duration: const Duration(milliseconds: 320), curve: Curves.easeOut);
  }

  List<Map<String, dynamic>> _topUp(List<dynamic> raw) {
    final out = raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    for (final s in _sampleListings) {
      if (out.length >= 6) break;
      out.add(Map<String, dynamic>.from(s));
    }
    return out;
  }

  bool _match(Map<String, dynamic> m) {
    switch (_filter) {
      case 'sale':
        return '${m['purpose']}' == 'sale';
      case 'rent':
        return '${m['purpose']}' == 'rent';
      case 'offplan':
        return '${m['handover_date'] ?? ''}'.trim().isNotEmpty || '${m['developer'] ?? ''}'.trim().isNotEmpty;
      case 'commercial':
        final ty = '${m['property_type'] ?? ''}'.toLowerCase();
        return ty.contains('office') || ty.contains('commercial') || ty.contains('retail') ||
            ty.contains('shop') || ty.contains('warehouse');
      default:
        return true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width >= 900;
    final t = Theme.of(context).textTheme;
    final listings = ref.watch(_featuredListingsProvider);

    Widget carousel(List<Map<String, dynamic>> all) {
      final items = all.where(_match).toList();
      final cardW = wide ? 300.0 : math.min((MediaQuery.of(context).size.width - AppSpacing.x24 * 2) * 0.82, 320.0);
      if (items.isEmpty) {
        return SizedBox(
          height: _height,
          child: Center(
            child: Text('More featured listings coming soon.',
                style: t.bodyMedium?.copyWith(color: _muted(context))),
          ),
        );
      }
      final list = ListView.separated(
        controller: _sc,
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 48),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.x16),
        itemBuilder: (_, i) => FadeIn(
          delayMs: 40 * i,
          child: _ListingCard(data: items[i], width: cardW, onOpen: () => _openListing(context, items[i])),
        ),
      );
      // Soft edge fade so partial cards melt out instead of being hard-clipped.
      final faded = ShaderMask(
        shaderCallback: (rect) => const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [Colors.transparent, Colors.black, Colors.black, Colors.transparent],
          stops: [0.0, 0.06, 0.94, 1.0],
        ).createShader(rect),
        blendMode: BlendMode.dstIn,
        child: list,
      );
      return SizedBox(
        height: _height,
        child: Stack(children: [
          Positioned.fill(child: faded),
          if (wide) ...[
            Positioned(left: 4, top: 0, bottom: 0, child: Center(child: _arrow(Icons.chevron_left, () => _scrollBy(-(cardW + 16) * 2)))),
            Positioned(right: 4, top: 0, bottom: 0, child: Center(child: _arrow(Icons.chevron_right, () => _scrollBy((cardW + 16) * 2)))),
          ],
        ]),
      );
    }

    const quick = [('all', 'All'), ('sale', 'For sale'), ('rent', 'For rent'), ('offplan', 'Off-plan'), ('commercial', 'Commercial')];

    return _section(
      context,
      title: 'Featured opportunities',
      subtitle: 'Verified homes, investment opportunities and rental listings across the UAE.',
      bg: _surface(context),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final q in quick)
            ChoiceChip(label: Text(q.$2), selected: _filter == q.$1, onSelected: (_) => setState(() => _filter = q.$1)),
        ]),
        const SizedBox(height: AppSpacing.x16),
        listings.when(
          loading: () => const SizedBox(height: _height, child: Center(child: CircularProgressIndicator())),
          error: (e, _) => carousel(_topUp(const [])),
          data: (list) => carousel(_topUp(list)),
        ),
        const SizedBox(height: AppSpacing.x24),
        Center(
          child: OutlinedButton(
            onPressed: () => context.go('/login'),
            style: OutlinedButton.styleFrom(foregroundColor: _onBg(context), side: BorderSide(color: _borderStrong(context))),
            child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: AppSpacing.x16, vertical: AppSpacing.x8),
                child: Text('Sign in to view all listings')),
          ),
        ),
      ]),
    );
  }

  Widget _arrow(IconData icon, VoidCallback onTap) => Material(
        color: _surface(context),
        shape: const CircleBorder(),
        elevation: 2,
        shadowColor: Colors.black26,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Padding(padding: const EdgeInsets.all(8), child: Icon(icon, color: _onBg(context))),
        ),
      );
}

class _ListingCard extends StatelessWidget {
  const _ListingCard({required this.data, required this.width, required this.onOpen});
  final Map<String, dynamic> data;
  final double width;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final aed = NumberFormat.currency(symbol: 'AED ', decimalDigits: 0);
    final price = num.tryParse('${data['price']}') ?? 0;
    final cover = '${data['cover_image'] ?? ''}';
    final isRent = '${data['purpose']}' == 'rent';
    final verified = data['verified'] == true || '${data['ownership_status']}' == 'verified';
    final building = '${data['building_name'] ?? ''}'.trim();
    final community = '${data['community'] ?? ''}'.trim();
    final ptype = '${data['property_type'] ?? ''}'.trim();
    final agent = '${data['agent_name'] ?? ''}'.trim();
    final refCode = '${data['ref_code'] ?? ''}'.trim();
    String cap(String s) => s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';
    final title = building.isNotEmpty ? building : (ptype.isNotEmpty ? cap(ptype) : 'Featured property');
    final specs = <String>[
      if (data['bedrooms'] != null) '${data['bedrooms']} Bed',
      if (data['bathrooms'] != null) '${data['bathrooms']} Bath',
      if (data['size_sqft'] != null) '${data['size_sqft']} sqft',
    ].join(' • ');
    // At most TWO tags (view + status) — the rest is noise on a card.
    final tags = <String>[
      if ('${data['view'] ?? ''}'.trim().isNotEmpty) '${data['view']}',
      if ('${data['status'] ?? ''}'.trim().isNotEmpty) cap('${data['status']}'),
    ].take(2).toList();

    return HoverLift(
      child: Container(
        width: width,
        decoration: BoxDecoration(
          color: _surface(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _border(context)),
          // Lighter single shadow — the 3-layer one was visual clutter.
          boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 14, offset: Offset(0, 6))],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Image — only For sale/rent + Verified badges (no type pill, no scrim).
          AspectRatio(
            aspectRatio: 16 / 10,
            child: Stack(fit: StackFit.expand, children: [
              cover.isNotEmpty
                  ? Image.network(cover, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const _Placeholder())
                  : const _Placeholder(),
              Positioned(top: 10, left: 10, child: _pill(context, isRent ? 'For rent' : 'For sale', _primary(context))),
              if (verified)
                Positioned(top: 10, right: 10, child: _pill(context, 'Verified', AppColors.success, icon: Icons.verified)),
            ]),
          ),
          // Body — property first; agent + actions last.
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.x12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: t.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                if (community.isNotEmpty)
                  Text(community, style: t.bodySmall?.copyWith(color: _muted(context)),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: AppSpacing.x4),
                if (price > 0)
                  Text('${aed.format(price)}${isRent ? ' / yr' : ''}',
                      style: t.titleLarge?.copyWith(color: _primary(context), fontWeight: FontWeight.w800)),
                if (specs.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.x8),
                  Text(specs, style: t.bodySmall?.copyWith(color: _onBg(context))),
                ],
                if (tags.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.x8),
                  Wrap(spacing: 6, runSpacing: 4, children: [
                    for (final h in tags)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                            color: AppColors.success.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(AppSpacing.rFull)),
                        child: Text(h, style: t.labelSmall?.copyWith(color: AppColors.success, fontWeight: FontWeight.w600)),
                      ),
                  ]),
                ],
                const Spacer(),
                if (refCode.isNotEmpty)
                  Text('Ref: $refCode', style: t.labelSmall?.copyWith(color: _subtle(context))),
                if (agent.isNotEmpty)
                  Text('Listed by $agent',
                      style: t.bodySmall?.copyWith(color: _muted(context)), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: AppSpacing.x8),
                Row(children: [
                  Expanded(
                    child: FilledButton(
                      onPressed: onOpen,
                      style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(36)),
                      child: const Text('View property'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: () => showAuthPrompt(context, action: 'save this property'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(36),
                      foregroundColor: _onBg(context),
                      side: BorderSide(color: _borderStrong(context)),
                    ),
                    icon: const Icon(Icons.favorite_border, size: 16),
                    label: const Text('Save'),
                  ),
                ]),
              ]),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _pill(BuildContext context, String text, Color c, {IconData? icon}) {
    final t = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: c.withValues(alpha: 0.92), borderRadius: BorderRadius.circular(AppSpacing.rFull)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[Icon(icon, size: 12, color: Colors.white), const SizedBox(width: 3)],
        Text(text, style: t.labelSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

/// Branded cover for an image-less listing — a deep NUZL gradient backdrop;
/// the card's overlay (building / location / price) renders on top, so it reads
/// as an intentional designed cover rather than a missing photo.
class _Placeholder extends StatelessWidget {
  const _Placeholder();
  @override
  Widget build(BuildContext context) => const DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [AppColors.gradientStart, AppColors.gradientEnd],
          ),
        ),
        child: Center(child: Icon(Icons.apartment_rounded, size: 44, color: Colors.white24)),
      );
}
