import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/nuzl_logo.dart';

/// Public marketing / legal pages (About, Pricing, Contact, Privacy, Terms, …)
/// mirroring the reference site's information architecture, in our design system.
class InfoPage extends StatelessWidget {
  const InfoPage({super.key, required this.slug});
  final String slug;

  static const Map<String, (String, String)> _content = {
    'about': ('About NUZL',
      'NUZL is the operating system for UAE real estate — a verified network connecting brokers, agents and lead generators to close more deals faster, with transparent commissions.'),
    'pricing': ('Pricing',
      'Simple, transparent plans for individual brokers and brokerages. Detailed tiers are coming soon — get started free today.'),
    'contact': ('Contact',
      'Questions or partnership enquiries? Reach the NUZL team at hello@nuzl.ae.'),
    'partners': ('Partners',
      'Brokerages, mortgage advisors and lead generators partner with NUZL to grow their network. Partnership details coming soon.'),
    'blog': ('Blog',
      'Insights on UAE real estate, broker productivity and market trends. Articles coming soon.'),
    'marketplace': ('Marketplace',
      'A verified marketplace of buyer leads and co-broking opportunities across Dubai and Abu Dhabi.'),
    'tools': ('Tools',
      'Mortgage calculator, smart matching and deal tracking — the tools brokers use daily.'),
    'privacy': ('Privacy Policy',
      'We respect your privacy. This page will detail how NUZL collects, uses and protects your data.'),
    'terms': ('Terms of Service',
      'These terms govern your use of NUZL. Full terms will be published here.'),
    'cookies': ('Cookie Policy',
      'NUZL uses essential cookies to keep you signed in. A full cookie policy will be published here.'),
  };

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final c = _content[slug] ?? ('NUZL', 'Coming soon.');
    return Scaffold(
      backgroundColor: AppColors.dBg,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.x24),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                InkWell(onTap: () => context.go('/'), child: const NuzlLogo(size: 36, color: Colors.white)),
                const SizedBox(height: AppSpacing.x40),
                Text(c.$1, style: GoogleFonts.poppins(
                    fontSize: 36, fontWeight: FontWeight.w700, color: Colors.white)),
                const SizedBox(height: AppSpacing.x16),
                Text(c.$2, style: t.bodyLarge?.copyWith(color: AppColors.dTextMuted, height: 1.6)),
                const SizedBox(height: AppSpacing.x32),
                FilledButton(onPressed: () => context.go('/'), child: const Text('Back to home')),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
