import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/nuzl_logo.dart';
import '../mortgage/presentation/calculator_screen.dart';

/// Public landing page — the app's entry point (not the login screen).
/// Includes the brand hero, value props, and the mortgage calculator.
class LandingScreen extends StatelessWidget {
  const LandingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final wide = MediaQuery.of(context).size.width >= 900;

    return Scaffold(
      backgroundColor: AppColors.dBg,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1040),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.x24, vertical: AppSpacing.x16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // top bar
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: AppSpacing.x16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const NuzlLogo(size: 40, color: Colors.white),
                          TextButton(
                            onPressed: () => context.go('/login'),
                            child: Text('Sign in',
                                style: GoogleFonts.poppins(
                                    color: Colors.white, fontWeight: FontWeight.w600)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.x40),
                    // hero
                    Text('The operating system\nfor UAE real estate',
                        style: GoogleFonts.poppins(
                            fontSize: wide ? 52 : 34,
                            height: 1.1,
                            fontWeight: FontWeight.w700,
                            color: Colors.white)),
                    const SizedBox(height: AppSpacing.x16),
                    Text(
                      'Opportunities first. Capture buyers, match listings, manage viewings, offers and deals — and track your mortgages — all in one place.',
                      style: t.bodyLarge?.copyWith(color: AppColors.dTextMuted, height: 1.5),
                    ),
                    const SizedBox(height: AppSpacing.x24),
                    Wrap(spacing: AppSpacing.x12, runSpacing: AppSpacing.x12, children: [
                      FilledButton(
                        onPressed: () => context.go('/register'),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: AppSpacing.x16),
                          child: Text('Get started'),
                        ),
                      ),
                      OutlinedButton(
                        onPressed: () => context.go('/login'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: AppColors.dBorderStrong),
                          minimumSize: const Size.fromHeight(AppSpacing.tapTarget),
                        ),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: AppSpacing.x16),
                          child: Text('Sign in'),
                        ),
                      ),
                    ]),
                    const SizedBox(height: AppSpacing.x48),
                    // value props
                    _Features(wide: wide),
                    const SizedBox(height: AppSpacing.x48),
                    // mortgage calculator section
                    Text('Mortgage calculator',
                        style: GoogleFonts.poppins(
                            fontSize: wide ? 30 : 24,
                            fontWeight: FontWeight.w600,
                            color: Colors.white)),
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
                    const SizedBox(height: AppSpacing.x48),
                    // footer CTA
                    Center(
                      child: Column(children: [
                        Text('Ready to work opportunity-first?',
                            style: t.titleLarge?.copyWith(color: Colors.white)),
                        const SizedBox(height: AppSpacing.x12),
                        FilledButton(
                          onPressed: () => context.go('/register'),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(horizontal: AppSpacing.x24),
                            child: Text('Create your account'),
                          ),
                        ),
                      ]),
                    ),
                    const SizedBox(height: AppSpacing.x48),
                    Center(
                      child: Text('© ${DateTime.now().year} NUZL.AE',
                          style: t.bodySmall?.copyWith(color: AppColors.dTextSubtle)),
                    ),
                    const SizedBox(height: AppSpacing.x24),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Features extends StatelessWidget {
  const _Features({required this.wide});
  final bool wide;

  static const _items = [
    (Icons.dynamic_feed_outlined, 'Opportunity feed', 'See new listings, buyer needs and co-broking in one live stream.'),
    (Icons.auto_awesome_outlined, 'Smart matching', 'Match buyers to listings automatically — rule-based and AI.'),
    (Icons.handshake_outlined, 'Deals & viewings', 'Track holds, viewings, offers and deals end to end.'),
    (Icons.account_balance_outlined, 'Mortgage tools', 'Calculate payments and track real mortgages over time.'),
  ];

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
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
            Text(it.$2, style: GoogleFonts.poppins(
                fontSize: 17, fontWeight: FontWeight.w600, color: Colors.white)),
            const SizedBox(height: AppSpacing.x4),
            Text(it.$3, style: t.bodySmall?.copyWith(color: AppColors.dTextMuted, height: 1.4)),
          ]),
        )).toList();
    return Wrap(spacing: AppSpacing.x16, runSpacing: AppSpacing.x16, children: cards);
  }
}
