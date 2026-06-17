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
// Higher-contrast body text than the muted grey (review: body was too light).
Color _body(BuildContext c) => _isDark(c) ? AppColors.dTextMuted : const Color(0xFF4A5B65);
// Soft layered card shadow so cards feel elevated/touchable (review: cards lacked depth).
List<BoxShadow> _cardShadow(BuildContext c) => _isDark(c)
    ? const [BoxShadow(color: Color(0x40000000), blurRadius: 24, offset: Offset(0, 8))]
    : const [
        BoxShadow(color: Color(0x0A000000), blurRadius: 2, offset: Offset(0, 1)),
        BoxShadow(color: Color(0x14000000), blurRadius: 24, offset: Offset(0, 8)),
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
      context.go('/info/pricing');
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
                    const _TrustMetrics(),
                    KeyedSubtree(key: _kFeatured, child: const _FeaturedListings()),
                    const _WhoAreYou(),
                    const _Ecosystem(),
                    const _WhyNuzl(),
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
          'Manage properties, ownership, leasing, mortgages, tenancy, services and '
          'investments — in one platform. For owners, buyers, tenants, agents, service '
          'providers and real-estate professionals.',
          style: t.bodyLarge?.copyWith(color: _body(context), height: 1.6),
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
          borderRadius: BorderRadius.circular(AppSpacing.rXl),
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
    (Icons.home_work_outlined, 'Owner', 'Track ownership, tenants, maintenance and documents.', 'Full ownership dashboard'),
    (Icons.search_outlined, 'Customer', 'Discover, rent and buy with confidence.', '12,000+ listings'),
    (Icons.badge_outlined, 'Agent', 'Manage listings, leads and commissions.', 'Lead scoring + CRM'),
    (Icons.build_outlined, 'Service Provider', 'Offer maintenance and property-related services.', 'Orders + tracking'),
    (Icons.inventory_2_outlined, 'Product Supplier', 'Sell products and materials to owners.', 'Marketplace storefront'),
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
            .map((r) => HoverLift(
                  child: Container(
                    width: wide ? 320 : double.infinity,
                    height: 188,
                    padding: const EdgeInsets.all(AppSpacing.x20),
                    decoration: BoxDecoration(
                      color: _surface(context),
                      borderRadius: BorderRadius.circular(AppSpacing.rCard),
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

class _EcosystemState extends State<_Ecosystem> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat();
  static const _nodes = ['Owner', 'Agent', 'Customer', 'Tenant', 'Service Provider', 'Supplier'];

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width >= 760;
    return _section(
      context,
      title: 'Everything connected',
      subtitle: 'Single source of truth. One property. One platform — every party works off the same record.',
      bg: _surface(context),
      child: wide ? _diagram(context) : _chips(context),
    );
  }

  // Animated hub-and-spoke: roles orbit a central NUZL hub with pulses flowing in.
  Widget _diagram(BuildContext context) {
    return SizedBox(
      height: 360,
      child: LayoutBuilder(builder: (ctx, cons) {
        final w = cons.maxWidth;
        const h = 360.0;
        final center = Offset(w / 2, h / 2);
        final r = (math.min(w, h) / 2) - 80;
        final pts = <Offset>[
          for (var i = 0; i < _nodes.length; i++)
            Offset(
              center.dx + r * math.cos(-math.pi / 2 + i * (2 * math.pi / _nodes.length)),
              center.dy + r * math.sin(-math.pi / 2 + i * (2 * math.pi / _nodes.length)),
            ),
        ];
        return AnimatedBuilder(
          animation: _c,
          builder: (_, __) => Stack(children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _EcoPainter(center: center, points: pts, t: _c.value, color: _primary(context)),
              ),
            ),
            Positioned(
              left: center.dx - 46, top: center.dy - 26, width: 92, height: 52,
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                    color: _primary(context),
                    borderRadius: BorderRadius.circular(AppSpacing.rFull),
                    boxShadow: _cardShadow(context)),
                child: Text('NUZL',
                    style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
              ),
            ),
            for (var i = 0; i < _nodes.length; i++)
              Positioned(
                left: pts[i].dx - 66, top: pts[i].dy - 18, width: 132, height: 36,
                child: Container(
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x8),
                  decoration: BoxDecoration(
                    color: _surface(context),
                    borderRadius: BorderRadius.circular(AppSpacing.rFull),
                    border: Border.all(color: _primary(context).withValues(alpha: 0.25)),
                    boxShadow: _cardShadow(context),
                  ),
                  child: Text(_nodes[i],
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(color: _primary(context), fontWeight: FontWeight.w600, fontSize: 12)),
                ),
              ),
          ]),
        );
      }),
    );
  }

  Widget _chips(BuildContext context) {
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
      if (i < _nodes.length - 1) chips.add(Icon(Icons.sync_alt, size: 16, color: _subtle(context)));
    }
    return Wrap(
        spacing: AppSpacing.x8, runSpacing: AppSpacing.x12,
        crossAxisAlignment: WrapCrossAlignment.center, children: chips);
  }
}

/// Faint spoke lines from the hub to each role, with a pulse dot flowing inward.
class _EcoPainter extends CustomPainter {
  _EcoPainter({required this.center, required this.points, required this.t, required this.color});
  final Offset center;
  final List<Offset> points;
  final double t;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..color = color.withValues(alpha: 0.25)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    final dot = Paint()..color = color;
    for (var i = 0; i < points.length; i++) {
      canvas.drawLine(center, points[i], line);
      final tt = (t + i / points.length) % 1.0; // staggered flow node -> hub
      final p = Offset.lerp(points[i], center, tt)!;
      canvas.drawCircle(p, 3.0, dot);
    }
  }

  @override
  bool shouldRepaint(_EcoPainter old) => old.t != t || old.center != center;
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
            .map((m) => HoverLift(
                  child: Container(
                    width: wide ? 320 : double.infinity,
                    padding: const EdgeInsets.all(AppSpacing.x20),
                    decoration: BoxDecoration(
                      color: Theme.of(context).scaffoldBackgroundColor,
                      borderRadius: BorderRadius.circular(AppSpacing.rCard),
                      border: Border.all(color: _border(context)),
                      boxShadow: _cardShadow(context),
                    ),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Icon(m.$1, color: _primary(context), size: 26),
                      const SizedBox(height: AppSpacing.x12),
                      Text(m.$2,
                          style: GoogleFonts.poppins(
                              fontSize: 16, fontWeight: FontWeight.w600, color: _onBg(context))),
                      const SizedBox(height: AppSpacing.x4),
                      Text(m.$3, style: t.bodySmall?.copyWith(color: _body(context), height: 1.4)),
                    ]),
                  ),
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
    (Icons.insights_outlined, 'Area growth', 'Spot where prices are climbing fastest.'),
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
                    width: wide ? 320 : double.infinity,
                    padding: const EdgeInsets.all(AppSpacing.x16),
                    decoration: BoxDecoration(
                      color: _surface(context),
                      borderRadius: BorderRadius.circular(AppSpacing.rCard),
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
                      child: HoverLift(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(AppSpacing.rCard),
                          onTap: () => context.go('/login'),
                          child: _ListingCard(data: Map<String, dynamic>.from(e.value), width: w),
                        ),
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
        boxShadow: _cardShadow(context),
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
