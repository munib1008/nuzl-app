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

// Theme-aware color helpers — the landing now follows light/dark like the rest of the app.
bool _isDark(BuildContext c) => Theme.of(c).brightness == Brightness.dark;
Color _surface(BuildContext c) => Theme.of(c).colorScheme.surface;
Color _border(BuildContext c) => Theme.of(c).dividerColor;
Color _onBg(BuildContext c) => Theme.of(c).colorScheme.onSurface;
Color _muted(BuildContext c) => _isDark(c) ? AppColors.dTextMuted : AppColors.textMuted;
Color _subtle(BuildContext c) => _isDark(c) ? AppColors.dTextSubtle : AppColors.textSubtle;
Color _primary(BuildContext c) => Theme.of(c).colorScheme.primary;
Color _borderStrong(BuildContext c) => _isDark(c) ? AppColors.dBorderStrong : AppColors.borderStrong;

/// Public landing page with a STICKY top bar, hero, features, calculator and footer.
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
                    _WhatYouGet(),
                    _FeaturedListings(),
                    _CalculatorSection(),
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
                // Right side: theme toggle · Sign in · Get started.
                // Wrap so it never overflows on narrow phones — items flow to a new line if tight.
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
                        child: const Text('Get started'),
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
          padding: const EdgeInsets.fromLTRB(AppSpacing.x24, AppSpacing.x48, AppSpacing.x24, AppSpacing.x24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('The operating system\nfor UAE real estate',
                style: GoogleFonts.poppins(
                    fontSize: wide ? 52 : 34, height: 1.1, fontWeight: FontWeight.w700, color: _onBg(context))),
            const SizedBox(height: AppSpacing.x16),
            Text(
              'A verified network connecting brokers, agents and lead generators — capture buyers, match listings, manage viewings, offers and deals, and track mortgages, all in one place.',
              style: t.bodyLarge?.copyWith(color: _muted(context), height: 1.5),
            ),
            const SizedBox(height: AppSpacing.x24),
            Wrap(spacing: AppSpacing.x12, runSpacing: AppSpacing.x12, children: [
              GradientButton(
                onPressed: () => context.go('/register'),
                label: 'Get started',
                icon: Icons.arrow_forward,
              ),
              OutlinedButton(
                onPressed: () => context.go('/login'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _onBg(context),
                  side: BorderSide(color: _borderStrong(context)),
                  minimumSize: const Size(0, 48),
                ),
                child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: AppSpacing.x16), child: Text('Sign in')),
              ),
            ]),
            const SizedBox(height: AppSpacing.x48),
            const _Features(),
          ]),
        ),
      ),
      ),
    );
  }
}

class _Features extends StatelessWidget {
  const _Features();
  static const _items = [
    (Icons.dynamic_feed_outlined, 'Opportunity feed', 'See new listings, buyer needs and co-broking in one live stream.'),
    (Icons.auto_awesome_outlined, 'Smart matching', 'Match buyers to listings automatically — rule-based and AI.'),
    (Icons.handshake_outlined, 'Deals & viewings', 'Track holds, viewings, offers and deals end to end.'),
    (Icons.account_balance_outlined, 'Mortgage tools', 'Calculate payments and track real mortgages over time.'),
  ];
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final wide = MediaQuery.of(context).size.width >= 900;
    final cards = _items.map((it) => Container(
          width: wide ? 232 : double.infinity,
          padding: const EdgeInsets.all(AppSpacing.x20),
          decoration: BoxDecoration(
            color: _surface(context),
            borderRadius: BorderRadius.circular(AppSpacing.rLg),
            border: Border.all(color: _border(context)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(it.$1, color: _primary(context), size: 28),
            const SizedBox(height: AppSpacing.x12),
            Text(it.$2, style: GoogleFonts.poppins(fontSize: 17, fontWeight: FontWeight.w600, color: _onBg(context))),
            const SizedBox(height: AppSpacing.x4),
            Text(it.$3, style: t.bodySmall?.copyWith(color: _muted(context), height: 1.4)),
          ]),
        )).toList();
    return Wrap(spacing: AppSpacing.x16, runSpacing: AppSpacing.x16, children: cards);
  }
}

class _WhatYouGet extends StatelessWidget {
  const _WhatYouGet();

  static const _groups = [
    ('For brokers & agents', [
      'Live opportunity feed — never miss a new listing or buyer',
      'Smart matching of buyers to listings (rule-based + AI)',
      'Listing availability verification — no dead listings',
      'Holds & blocking to avoid double-selling a unit',
      'Viewings, offers and deals tracked end to end',
      'System-generated reputation that builds trust',
    ]),
    ('For owners & investors', [
      'Portfolio tracking with income, expenses and ROI',
      'Mortgage calculator and live payment tracker',
      'Community & building intelligence',
      'Clear view of every property\'s timeline',
    ]),
    ('For lead generators & co-broking', [
      'Post buyer leads to a verified network',
      'Referral network with transparent commissions',
      'Co-broking and "need help" requests',
      'Activity trail on every opportunity',
    ]),
  ];

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final wide = MediaQuery.of(context).size.width >= 900;

    Widget group((String, List<String>) g) => Container(
          width: wide ? 320 : double.infinity,
          padding: const EdgeInsets.all(AppSpacing.x20),
          decoration: BoxDecoration(
            color: _surface(context),
            borderRadius: BorderRadius.circular(AppSpacing.rLg),
            border: Border.all(color: _border(context)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(g.$1, style: GoogleFonts.poppins(fontSize: 17, fontWeight: FontWeight.w600, color: _onBg(context))),
            const SizedBox(height: AppSpacing.x12),
            ...g.$2.map((line) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.x8),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 2, right: AppSpacing.x8),
                      child: Icon(Icons.check_circle, size: 18, color: _primary(context)),
                    ),
                    Expanded(child: Text(line, style: t.bodyMedium?.copyWith(color: _muted(context), height: 1.4))),
                  ]),
                )),
          ]),
        );

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1040),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x24, vertical: AppSpacing.x24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('What you get with nuzl',
                style: GoogleFonts.poppins(fontSize: wide ? 30 : 24, fontWeight: FontWeight.w600, color: _onBg(context))),
            const SizedBox(height: AppSpacing.x4),
            Text('One platform for everyone in the deal — not a portal, not a CRM.',
                style: t.bodyMedium?.copyWith(color: _muted(context))),
            const SizedBox(height: AppSpacing.x20),
            Wrap(spacing: AppSpacing.x16, runSpacing: AppSpacing.x16, children: _groups.map(group).toList()),
          ]),
        ),
      ),
    );
  }
}

class _CalculatorSection extends StatelessWidget {
  const _CalculatorSection();
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final wide = MediaQuery.of(context).size.width >= 900;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1040),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x24, vertical: AppSpacing.x24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('Mortgage calculator',
                style: GoogleFonts.poppins(fontSize: wide ? 30 : 24, fontWeight: FontWeight.w600, color: _onBg(context))),
            const SizedBox(height: AppSpacing.x4),
            Text('Estimate a monthly payment instantly — no account needed.',
                style: t.bodyMedium?.copyWith(color: _muted(context))),
            const SizedBox(height: AppSpacing.x16),
            Container(
              decoration: BoxDecoration(
                color: _surface(context),
                borderRadius: BorderRadius.circular(AppSpacing.rLg),
                border: Border.all(color: _border(context)),
              ),
              child: const CalculatorScreen(embedded: true),
            ),
          ]),
        ),
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
        color: _surface(context),
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
                        child: Text('UAE\'s premier real-estate lead marketplace. Dubai · Abu Dhabi.',
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

class _FeaturedListings extends ConsumerWidget {
  const _FeaturedListings();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final wide = MediaQuery.of(context).size.width >= 900;
    final listings = ref.watch(_featuredListingsProvider);
    return Container(
      width: double.infinity,
      color: _surface(context),
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.x48),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1040),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x24),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Browse properties',
                  style: GoogleFonts.poppins(fontSize: wide ? 30 : 24, fontWeight: FontWeight.w700, color: _onBg(context))),
              const SizedBox(height: AppSpacing.x4),
              Text('A preview of listings shared by verified agents across the UAE — sign in to view full details.',
                  style: t.bodyMedium?.copyWith(color: _muted(context))),
              const SizedBox(height: AppSpacing.x20),
              listings.when(
                loading: () => const Padding(
                    padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator())),
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
                              borderRadius: BorderRadius.circular(AppSpacing.rLg),
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
          ),
        ),
      ),
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
        borderRadius: BorderRadius.circular(AppSpacing.rLg),
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
        borderRadius: BorderRadius.circular(AppSpacing.rLg),
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
