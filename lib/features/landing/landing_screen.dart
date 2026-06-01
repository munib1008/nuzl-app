import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/nuzl_logo.dart';
import '../mortgage/presentation/calculator_screen.dart';

/// Public landing page with a STICKY top bar, hero, features, calculator and footer.
class LandingScreen extends StatelessWidget {
  const LandingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.dBg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const _StickyTopBar(),           // stays pinned while content scrolls
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: const [
                    _Hero(),
                    _WhatYouGet(),
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

class _StickyTopBar extends StatelessWidget {
  const _StickyTopBar();
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.dBg,
        border: Border(bottom: BorderSide(color: AppColors.dBorder)),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1040),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x24, vertical: AppSpacing.x12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                InkWell(onTap: () => context.go('/'), child: const NuzlLogo(size: 36, color: Colors.white)),
                Row(children: [
                  TextButton(
                    onPressed: () => context.go('/login'),
                    child: Text('Sign in',
                        style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(width: AppSpacing.x8),
                  FilledButton(
                    onPressed: () => context.go('/register'),
                    child: const Text('Get started'),
                  ),
                ]),
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
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1040),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.x24, AppSpacing.x48, AppSpacing.x24, AppSpacing.x24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('The operating system\nfor UAE real estate',
                style: GoogleFonts.poppins(
                    fontSize: wide ? 52 : 34, height: 1.1,
                    fontWeight: FontWeight.w700, color: Colors.white)),
            const SizedBox(height: AppSpacing.x16),
            Text(
              'A verified network connecting brokers, agents and lead generators — capture buyers, match listings, manage viewings, offers and deals, and track mortgages, all in one place.',
              style: t.bodyLarge?.copyWith(color: AppColors.dTextMuted, height: 1.5),
            ),
            const SizedBox(height: AppSpacing.x24),
            Wrap(spacing: AppSpacing.x12, runSpacing: AppSpacing.x12, children: [
              FilledButton(
                onPressed: () => context.go('/register'),
                child: const Padding(padding: EdgeInsets.symmetric(horizontal: AppSpacing.x16), child: Text('Get started')),
              ),
              OutlinedButton(
                onPressed: () => context.go('/login'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: AppColors.dBorderStrong),
                  minimumSize: const Size.fromHeight(AppSpacing.tapTarget),
                ),
                child: const Padding(padding: EdgeInsets.symmetric(horizontal: AppSpacing.x16), child: Text('Sign in')),
              ),
            ]),
            const SizedBox(height: AppSpacing.x48),
            const _Features(),
          ]),
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
            color: AppColors.dSurface,
            borderRadius: BorderRadius.circular(AppSpacing.rLg),
            border: Border.all(color: AppColors.dBorder),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(it.$1, color: AppColors.dPrimary, size: 28),
            const SizedBox(height: AppSpacing.x12),
            Text(it.$2, style: GoogleFonts.poppins(fontSize: 17, fontWeight: FontWeight.w600, color: Colors.white)),
            const SizedBox(height: AppSpacing.x4),
            Text(it.$3, style: t.bodySmall?.copyWith(color: AppColors.dTextMuted, height: 1.4)),
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
            color: AppColors.dSurface,
            borderRadius: BorderRadius.circular(AppSpacing.rLg),
            border: Border.all(color: AppColors.dBorder),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(g.$1, style: GoogleFonts.poppins(
                fontSize: 17, fontWeight: FontWeight.w600, color: Colors.white)),
            const SizedBox(height: AppSpacing.x12),
            ...g.$2.map((line) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.x8),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 2, right: AppSpacing.x8),
                      child: Icon(Icons.check_circle, size: 18, color: AppColors.dPrimary),
                    ),
                    Expanded(child: Text(line,
                        style: t.bodyMedium?.copyWith(color: AppColors.dTextMuted, height: 1.4))),
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
                style: GoogleFonts.poppins(
                    fontSize: wide ? 30 : 24, fontWeight: FontWeight.w600, color: Colors.white)),
            const SizedBox(height: AppSpacing.x4),
            Text('One platform for everyone in the deal — not a portal, not a CRM.',
                style: t.bodyMedium?.copyWith(color: AppColors.dTextMuted)),
            const SizedBox(height: AppSpacing.x20),
            Wrap(spacing: AppSpacing.x16, runSpacing: AppSpacing.x16,
                children: _groups.map(group).toList()),
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
                style: GoogleFonts.poppins(fontSize: wide ? 30 : 24, fontWeight: FontWeight.w600, color: Colors.white)),
            const SizedBox(height: AppSpacing.x4),
            Text('Estimate a monthly payment instantly — no account needed.',
                style: t.bodyMedium?.copyWith(color: AppColors.dTextMuted)),
            const SizedBox(height: AppSpacing.x16),
            Container(
              decoration: BoxDecoration(
                color: AppColors.dSurface,
                borderRadius: BorderRadius.circular(AppSpacing.rLg),
                border: Border.all(color: AppColors.dBorder),
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
            Text(title, style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15)),
            const SizedBox(height: AppSpacing.x12),
            ...links.map((l) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.x8),
                  child: InkWell(
                    onTap: () => context.go(l.$2),
                    child: Text(l.$1, style: t.bodyMedium?.copyWith(color: AppColors.dTextMuted)),
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
      decoration: const BoxDecoration(
        color: AppColors.dSurface,
        border: Border(top: BorderSide(color: AppColors.dBorder)),
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
                      const NuzlLogo(size: 34, color: Colors.white),
                      const SizedBox(height: AppSpacing.x12),
                      SizedBox(
                        width: 280,
                        child: Text('UAE\'s premier real-estate lead marketplace. Dubai · Abu Dhabi.',
                            style: t.bodySmall?.copyWith(color: AppColors.dTextMuted, height: 1.5)),
                      ),
                    ]),
                  ),
                  if (!wide) const SizedBox(height: AppSpacing.x32),
                  ...columns.map((c) => Expanded(flex: wide ? 1 : 0, child: Padding(
                        padding: EdgeInsets.only(bottom: wide ? 0 : AppSpacing.x24),
                        child: c,
                      ))),
                ],
              ),
              const SizedBox(height: AppSpacing.x32),
              const Divider(color: AppColors.dBorder),
              const SizedBox(height: AppSpacing.x16),
              Text('© 2026 nuzl by Businesstech Arabia FZE, Innovation Licence 6803. All rights reserved.',
                  style: t.bodySmall?.copyWith(color: AppColors.dTextSubtle)),
              const SizedBox(height: AppSpacing.x16),
              Text('Important disclaimer',
                  style: GoogleFonts.poppins(
                      color: AppColors.dTextMuted, fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(height: AppSpacing.x4),
              Text(
                'nuzl is not a real estate broker or agent. We are licensed to conduct opportunity facilitation and operate as a marketplace platform connecting real estate professionals. We are not involved directly in the sale, purchase, or lease of any property units. All real estate transactions are conducted between licensed brokers, agents, and their clients in accordance with UAE real estate regulations. Users must ensure they work with RERA-certified professionals for all property transactions.',
                style: t.bodySmall?.copyWith(color: AppColors.dTextSubtle, height: 1.5),
              ),
              const SizedBox(height: AppSpacing.x16),
            ]),
          ),
        ),
      ),
    );
  }
}
