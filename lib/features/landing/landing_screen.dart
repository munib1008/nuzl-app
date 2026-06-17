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
      subtitle: 'One property. One ecosystem. One platform — every party works off the same record.',
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
    'Find listings',
    'Contact an agent',
    'The trail ends there',
  ];
  static const _nuzl = [
    'Find properties',
    'Buy or rent',
    'Track your mortgage',
    'Manage ownership',
    'Manage tenants',
    'Track payments',
    'Book services',
    'Buy products',
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
            borderRadius: BorderRadius.circular(_kCardR),
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
    (Icons.verified_user_outlined, 'Ownership', 'Documents, tenants and payments.'),
    (Icons.trending_up, 'Leasing CRM', 'Inquiries, leads and deals.'),
    (Icons.account_balance_outlined, 'Mortgage Finance', 'Track financing and repayments.'),
    (Icons.handyman_outlined, 'Services', 'Book maintenance and pro services.'),
    (Icons.shopping_bag_outlined, 'Marketplace', 'Buy products and materials.'),
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
                  child: InkWell(
                    borderRadius: BorderRadius.circular(_kCardR),
                    onTap: () => context.go('/login'),
                    child: Container(
                      width: wide ? 232 : double.infinity,
                      padding: const EdgeInsets.all(AppSpacing.x16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).scaffoldBackgroundColor,
                        borderRadius: BorderRadius.circular(_kCardR),
                        border: Border.all(color: _border(context)),
                        boxShadow: _cardShadow(context),
                      ),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Icon(m.$1, color: _primary(context), size: 24),
                        const SizedBox(height: AppSpacing.x8),
                        Text(m.$2,
                            style: GoogleFonts.poppins(
                                fontSize: 15, fontWeight: FontWeight.w600, color: _onBg(context))),
                        const SizedBox(height: AppSpacing.x4),
                        Text(m.$3, style: t.bodySmall?.copyWith(color: _body(context), height: 1.4)),
                      ]),
                    ),
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
    final d = await ref.read(apiClientProvider).get('/public/listings?limit=8');
    return d is List ? d : [];
  } catch (_) {
    return [];
  }
});

// Showcase samples — used to top up the carousel so it never looks sparse. These
// tap through to sign-in (teasers), not to a specific listing. Replace with real
// featured listings as inventory grows.
const _sampleListings = [
  {'property_type': 'Luxury villa', 'community': 'Palm Jumeirah', 'price': 12500000, 'bedrooms': 5, 'bathrooms': 6, 'size_sqft': 7200, 'verified': true, 'rating': 4.9},
  {'property_type': 'Apartment', 'community': 'Downtown Dubai', 'price': 2100000, 'bedrooms': 2, 'bathrooms': 2, 'size_sqft': 1066, 'verified': true, 'rating': 4.8},
  {'property_type': 'Townhouse', 'community': 'Arabian Ranches', 'price': 3850000, 'bedrooms': 4, 'bathrooms': 4, 'size_sqft': 2900, 'verified': true, 'rating': 4.7},
  {'property_type': 'Commercial unit', 'community': 'Business Bay', 'price': 5600000, 'bedrooms': 0, 'bathrooms': 2, 'size_sqft': 3400, 'verified': true, 'rating': 4.6},
];

/// Rough monthly mortgage estimate (75% LTV, 4.5% / 25y) for a teaser line.
double _estMonthly(num price) {
  final loan = price * 0.75;
  const r = 0.045 / 12;
  const n = 300;
  if (loan <= 0) return 0;
  final f = math.pow(1 + r, n).toDouble();
  return loan * r * f / (f - 1);
}

// ── Section 4 — Featured properties (horizontal carousel) ────────────────────
class _FeaturedListings extends ConsumerWidget {
  const _FeaturedListings();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wide = MediaQuery.of(context).size.width >= 900;
    final listings = ref.watch(_featuredListingsProvider);

    List<Map<String, dynamic>> topUp(List<dynamic> raw) {
      final out = raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      for (final s in _sampleListings) {
        if (out.length >= 4) break;
        out.add(Map<String, dynamic>.from(s));
      }
      return out;
    }

    Widget carousel(List<Map<String, dynamic>> items) {
      final cardW = wide ? 300.0 : (MediaQuery.of(context).size.width - AppSpacing.x24 * 2) * 0.82;
      return SizedBox(
        height: 356,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.zero,
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.x16),
          itemBuilder: (_, i) => FadeIn(
            delayMs: 50 * i,
            child: HoverLift(
              child: InkWell(
                borderRadius: BorderRadius.circular(_kCardR),
                onTap: () => context.go('/login'),
                child: _ListingCard(data: items[i], width: cardW),
              ),
            ),
          ),
        ),
      );
    }

    return _section(
      context,
      title: 'Featured properties',
      subtitle: 'A preview of homes across the UAE — sign in to view full details.',
      bg: _surface(context),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        listings.when(
          loading: () => const SizedBox(height: 356, child: Center(child: CircularProgressIndicator())),
          error: (e, _) => carousel(topUp(const [])),
          data: (list) => carousel(topUp(list)),
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
    final verified = data['verified'] == true || '${data['ownership_status']}' == 'verified';
    final rating = num.tryParse('${data['rating'] ?? ''}');
    final estMonthly = _estMonthly(price);
    final placeholder = ColoredBox(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: Icon(Icons.apartment, color: _muted(context), size: 40));
    return Container(
      width: width,
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(_kCardR),
        border: Border.all(color: _border(context)),
        boxShadow: _cardShadow(context),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Stack(children: [
          AspectRatio(
            aspectRatio: 16 / 10,
            child: cover != null && cover.isNotEmpty
                ? Image.network(cover, fit: BoxFit.cover, errorBuilder: (_, __, ___) => placeholder)
                : placeholder,
          ),
          Positioned(
            left: 8, top: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                  color: _primary(context).withValues(alpha: 0.92), borderRadius: BorderRadius.circular(AppSpacing.rFull)),
              child: Text(purpose == 'rent' ? 'For rent' : 'For sale',
                  style: t.bodySmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w600)),
            ),
          ),
          if (verified)
            Positioned(
              right: 8, top: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.95), borderRadius: BorderRadius.circular(AppSpacing.rFull)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.verified, size: 12, color: Colors.white),
                  const SizedBox(width: 3),
                  Text('Verified', style: t.labelSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
                ]),
              ),
            ),
        ]),
        Padding(
          padding: const EdgeInsets.all(AppSpacing.x12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                child: Text(aed.format(price),
                    style: t.titleLarge?.copyWith(color: _onBg(context), fontWeight: FontWeight.w700)),
              ),
              if (rating != null) ...[
                const Icon(Icons.star, size: 14, color: AppColors.accentGold),
                const SizedBox(width: 2),
                Text(rating.toStringAsFixed(1),
                    style: t.bodySmall?.copyWith(color: _onBg(context), fontWeight: FontWeight.w600)),
              ],
            ]),
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
            if (estMonthly > 0) ...[
              const SizedBox(height: AppSpacing.x8),
              Row(children: [
                Icon(Icons.account_balance_outlined, size: 13, color: _primary(context)),
                const SizedBox(width: 4),
                Text('~${aed.format(estMonthly)}/mo est.',
                    style: t.bodySmall?.copyWith(color: _primary(context), fontWeight: FontWeight.w600)),
              ]),
            ],
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
