import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/rbac/persona.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/responsive.dart';
import '../auth/application/auth_controller.dart';
import '../shell/app_shell.dart';

/// Admin "View As Role" switcher (Section 6). Renders any role's interface
/// in the current session via the persona override, with a TEST MODE banner.
class ViewAsScreen extends ConsumerWidget {
  const ViewAsScreen({super.key});

  static const _roles = [
    (Persona.admin, Icons.shield_outlined, 'Administrator', 'Full platform: tenants, audit, plans'),
    (Persona.broker, Icons.business_outlined, 'Broker / Agency', 'Team, pipeline, inventory, revenue'),
    (Persona.agent, Icons.person_outline, 'Agent', 'Leads, deals, listings, performance'),
    (Persona.leadGenerator, Icons.people_outline, 'Lead Generator', 'Marketplace, post leads, network'),
    (Persona.developer, Icons.domain_outlined, 'Developer', 'Projects, inventory, forecast'),
    (Persona.investor, Icons.account_balance_wallet_outlined, 'Investor', 'Portfolio, financials, mortgages'),
    (Persona.owner, Icons.home_work_outlined, 'Property Owner', 'Properties, rentals, financials'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final actual = personaFromRole(ref.watch(authControllerProvider).user?.role);
    final current = ref.watch(personaProvider);

    // Test mode is restricted to real administrators only.
    if (actual != Persona.admin) {
      return Scaffold(
        appBar: NuzlAppBar(title: context.tr('View as role')),
        drawer: const NuzlDrawer(),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.x24),
            child: Text(context.tr('Test mode is restricted to administrators.'), textAlign: TextAlign.center),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: NuzlAppBar(title: context.tr('View as role · Test mode')),
      drawer: const NuzlDrawer(),
      body: ResponsiveCenter(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.x16),
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.x16),
              decoration: BoxDecoration(
                color: AppColors.accentGoldTint,
                borderRadius: BorderRadius.circular(AppSpacing.rLg),
              ),
              child: Row(children: [
                const Icon(Icons.science_outlined, color: AppColors.secondary),
                const SizedBox(width: AppSpacing.x12),
                Expanded(child: Text(
                  '${context.tr('Preview any role\'s interface without logging out. Your real role stays')} ${actual.label}. '
                  '${context.tr('Actions in test mode are clearly flagged; in production this is restricted to super-admins.')}',
                  style: t.bodySmall?.copyWith(color: AppColors.secondary, height: 1.4))),
              ]),
            ),
            const SizedBox(height: AppSpacing.x16),
            ..._roles.map((r) {
              final selected = current == r.$1;
              return Card(
                child: ListTile(
                  leading: Icon(r.$2, color: AppColors.primary),
                  title: Text(context.tr(r.$3)),
                  subtitle: Text(context.tr(r.$4)),
                  trailing: selected ? const Icon(Icons.check_circle, color: AppColors.primary) : const Icon(Icons.chevron_right),
                  onTap: () {
                    ref.read(personaPreviewProvider.notifier).state = r.$1;
                    context.go('/dashboard');
                  },
                ),
              );
            }),
            const SizedBox(height: AppSpacing.x12),
            if (ref.watch(personaPreviewProvider) != null)
              OutlinedButton.icon(
                onPressed: () => ref.read(personaPreviewProvider.notifier).state = null,
                icon: const Icon(Icons.logout),
                label: Text(context.tr('Exit test mode')),
              ),
            const SizedBox(height: AppSpacing.x24),
          ],
        ),
      ),
    );
  }
}
