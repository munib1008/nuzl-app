import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/network/api_client.dart';
import '../../core/rbac/persona.dart';
import '../../core/rbac/nav_config.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/theme_mode_provider.dart';
import '../../core/widgets/nuzl_logo.dart';
import '../auth/application/auth_controller.dart';

/// Unread notification badge (graceful: 0 on any error / missing permission).
final unreadCountProvider = FutureProvider.autoDispose<int>((ref) async {
  try {
    final d = await ref.read(apiClientProvider).get('/notifications/unread-count');
    final v = (d is Map) ? d['count'] : 0;
    return v is int ? v : int.tryParse('$v') ?? 0;
  } catch (_) {
    return 0;
  }
});

/// Branded top bar used by every authed screen: menu · logo · notifications · profile.
class NuzlAppBar extends ConsumerWidget implements PreferredSizeWidget {
  const NuzlAppBar({super.key, this.title, this.actions});
  final String? title;
  final List<Widget>? actions;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).user;
    return AppBar(
      // Gutter so a page title doesn't collide with the sidebar divider on wide.
      titleSpacing: MediaQuery.sizeOf(context).width >= 1000 ? AppSpacing.x32 : AppSpacing.x16,
      // Solid, premium app bar with a hairline separator (no glassmorphism).
      backgroundColor: Theme.of(context).colorScheme.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      shape: Border(bottom: BorderSide(color: Theme.of(context).dividerColor, width: 0.5)),
      automaticallyImplyLeading: false,
      leading: MediaQuery.sizeOf(context).width >= 1000
          ? null
          : Builder(
              builder: (ctx) => IconButton(
                icon: const Icon(Icons.menu),
                onPressed: () => Scaffold.of(ctx).openDrawer(),
              ),
            ),
      title: title != null
          ? Text(title!)
          : (MediaQuery.sizeOf(context).width >= 1000 ? const SizedBox.shrink() : const NuzlLogo(size: 28)),
      actions: [
        // Role switching lives in ONE place — the role chip under the logo in the
        // sidebar/drawer (_RoleChip). No duplicate switcher in the app bar.
        ...?actions,
        IconButton(
          tooltip: 'Toggle light / dark',
          icon: Icon(Theme.of(context).brightness == Brightness.dark
              ? Icons.light_mode_outlined
              : Icons.dark_mode_outlined),
          onPressed: () => ref.read(themeModeProvider.notifier).toggle(),
        ),
        ref.watch(unreadCountProvider).maybeWhen(
              data: (n) => _Bell(count: n, onTap: () => context.go('/notifications')),
              orElse: () => IconButton(
                  icon: const Icon(Icons.notifications_none),
                  onPressed: () => context.go('/notifications')),
            ),
        PopupMenuButton<String>(
          offset: const Offset(0, 48),
          onSelected: (v) async {
            if (v == 'profile') context.go('/profile');
            if (v == 'logout') {
              await ref.read(authControllerProvider.notifier).logout();
              if (context.mounted) context.go('/');
            }
          },
          itemBuilder: (_) => [
            PopupMenuItem(
              enabled: false,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(user?.fullName ?? 'Account', style: Theme.of(context).textTheme.titleSmall),
                Text(user?.email ?? '', style: Theme.of(context).textTheme.bodySmall),
              ]),
            ),
            const PopupMenuDivider(),
            const PopupMenuItem(value: 'profile', child: ListTile(
                leading: Icon(Icons.settings_outlined), title: Text('Settings'), dense: true)),
            const PopupMenuItem(value: 'logout', child: ListTile(
                leading: Icon(Icons.logout, color: AppColors.danger),
                title: Text('Logout'), dense: true)),
          ],
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x12),
            child: CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.primary,
              child: Text(
                (user?.fullName.isNotEmpty == true ? user!.fullName[0] : 'N').toUpperCase(),
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Bell extends StatelessWidget {
  const _Bell({required this.count, required this.onTap});
  final int count;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return Stack(alignment: Alignment.center, children: [
      IconButton(icon: const Icon(Icons.notifications_none), onPressed: onTap),
      if (count > 0)
        Positioned(
          right: 8, top: 8,
          child: Container(
            padding: const EdgeInsets.all(3),
            decoration: const BoxDecoration(color: AppColors.danger, shape: BoxShape.circle),
            constraints: const BoxConstraints(minWidth: 15, minHeight: 15),
            child: Text(count > 9 ? '9+' : '$count',
                style: const TextStyle(color: Colors.white, fontSize: 9, height: 1),
                textAlign: TextAlign.center),
          ),
        ),
    ]);
  }
}

/// Role chip under the logo in the sidebar/drawer — the SINGLE place the current
/// role is shown (no duplicate in the app bar). Always shows the active role;
/// when the account holds >1 approved role it becomes a tap-to-switch menu
/// (writes active_role server-side, survives devices, reloads nav + dashboard).
class _RoleChip extends ConsumerWidget {
  const _RoleChip({this.inDrawer = false});
  final bool inDrawer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).user;
    final persona = ref.watch(personaProvider);
    // Dedupe by persona label — 'customer' and 'buyer' both render as "Customer",
    // so without this the switcher can show "Customer" twice.
    final roles = <String>[];
    final seenLabels = <String>{};
    for (final r in (user?.approvedRoles ?? const <String>[])) {
      if (seenLabels.add(personaFromRole(r).label)) roles.add(r);
    }
    final active = (user?.activeRole?.isNotEmpty == true)
        ? user!.activeRole!
        : (roles.isNotEmpty ? roles.first : null);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final accent = dark ? AppColors.dPrimary : AppColors.primary;
    final tint = dark ? AppColors.dPrimaryTint : AppColors.primaryTint;
    final t = Theme.of(context).textTheme;
    final multi = roles.length >= 2;

    // Always show the swap affordance — the chip is the single role control, so
    // even a single-role (Customer) account can tap it to add a role.
    final pill = Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x12, vertical: 5),
      decoration: BoxDecoration(color: tint, borderRadius: BorderRadius.circular(AppSpacing.rFull)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.account_circle_outlined, size: 15, color: accent),
        const SizedBox(width: 6),
        Text(persona.label, style: t.bodySmall?.copyWith(color: accent, fontWeight: FontWeight.w600)),
        const SizedBox(width: 6),
        Icon(multi ? Icons.swap_horiz : Icons.expand_more, size: 15, color: accent),
      ]),
    );

    return PopupMenuButton<String>(
      tooltip: multi ? 'Switch role' : 'Roles',
      offset: const Offset(0, 40),
      onSelected: (r) async {
        if (r == '__add__') {
          if (inDrawer && context.mounted) Navigator.pop(context); // close drawer first
          await showAddRoleDialog(context, ref, roles);
          return;
        }
        if (r == active) return;
        await ref.read(authControllerProvider.notifier).switchRole(r);
        if (!context.mounted) return;
        if (inDrawer) Navigator.pop(context); // close the drawer after switching
        context.go('/dashboard');
      },
      itemBuilder: (_) => [
        for (final r in roles)
          PopupMenuItem<String>(
            value: r,
            child: Row(children: [
              Icon(r == active ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                  size: 16, color: r == active ? accent : AppColors.textMuted),
              const SizedBox(width: 8),
              Text(personaFromRole(r).label),
            ]),
          ),
        const PopupMenuDivider(),
        const PopupMenuItem<String>(
          value: '__add__',
          child: Row(children: [
            Icon(Icons.add_circle_outline, size: 16),
            SizedBox(width: 10),
            Text('Add a role'),
          ]),
        ),
      ],
      child: pill,
    );
  }
}

/// Brand colour per role — drives the role badge so users instantly recognise
/// which role they're acting as.
Color roleColor(Persona p) {
  switch (p) {
    case Persona.owner:
      return AppColors.secondary;
    case Persona.tenant:
      return AppColors.primaryBright;
    case Persona.developer:
    case Persona.bank:
      return AppColors.info;
    case Persona.provider:
      return AppColors.warning;
    case Persona.investor:
    case Persona.buyer:
      return AppColors.success;
    case Persona.admin:
      return AppColors.danger;
    default:
      return AppColors.primary; // customer/agent/broker/salesperson/leadGenerator
  }
}

/// Whether a nav destination is the active one for the current [location].
/// Matches the route exactly or a true sub-path (`route/…`) — NOT a sibling that
/// merely shares a prefix (so `/saved-searches` no longer lights up `/saved`).
bool isActiveRoute(String location, String route) => route == '/dashboard'
    ? location == '/dashboard'
    : location == route || location.startsWith('$route/');

// Roles a user can add on top of their base Customer identity. Verified roles
// (RERA / trade licence) land as 'pending' until an admin approves them.
const _addableRoles = <({String key, String title, String desc, String req, bool verified})>[
  (key: 'owner', title: 'Property Owner', desc: 'Manage owned properties, leases and service requests.', req: 'Title Deed + Emirates ID', verified: false),
  (key: 'tenant', title: 'Tenant', desc: 'Track your tenancy, rent payments and maintenance.', req: 'Tenancy contract (Ejari)', verified: false),
  (key: 'investor', title: 'Investor', desc: 'Yield analysis, portfolio tracking and opportunities.', req: 'No documents required', verified: false),
  (key: 'agent', title: 'Agent', desc: 'List and sell properties, manage CRM, leads and viewings.', req: 'RERA licence + agency affiliation', verified: true),
  (key: 'developer', title: 'Developer', desc: 'Manage projects, inventory and unit releases.', req: 'Trade licence + developer registration', verified: true),
  (key: 'provider', title: 'Service Provider', desc: 'Offer services, bid on tenders and send quotes.', req: 'Trade licence', verified: true),
  (key: 'supplier', title: 'Supplier', desc: 'Sell products and manage your catalogue.', req: 'Trade licence', verified: true),
];

/// Opens the "Add a role" picker — informative cards with required documents +
/// verification status. Verified roles request admin approval; instant roles
/// activate immediately. Single entry point, reached from the sidebar role chip.
Future<void> showAddRoleDialog(BuildContext context, WidgetRef ref, List<String> held) async {
  final picked = await showDialog<({String key, bool verified})>(
    context: context,
    builder: (ctx) {
      final options = _addableRoles.where((o) => !held.contains(o.key)).toList();
      return Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460, maxHeight: 580),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 20, 4),
              child: Text('Add a role', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Text(
                  'One account, many roles. You stay a Customer — added roles layer on top. '
                  'Verified roles are reviewed before they go live.',
                  style: TextStyle(fontSize: 12.5, color: AppColors.textMuted)),
            ),
            Expanded(
              child: options.isEmpty
                  ? const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('You already have every role.')))
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                      itemCount: options.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (_, i) => _addRoleCard(ctx, options[i]),
                    ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(0, 0, 12, 8),
                child: TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
              ),
            ),
          ]),
        ),
      );
    },
  );
  if (picked == null) return;
  try {
    await ref.read(apiClientProvider).post('/users/me/roles', body: {'role': picked.key});
    await ref.read(authControllerProvider.notifier).bootstrap(); // refresh approved roles
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(picked.verified
          ? 'Requested — your role will activate once verified.'
          : 'Role added — switch to it from the role chip under the logo.'),
    ));
  } catch (e) {
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
  }
}

/// One informative role card in the Add-a-role dialog: purpose, required
/// documents, verification status and an Apply action.
Widget _addRoleCard(BuildContext ctx, ({String key, String title, String desc, String req, bool verified}) o) {
  final c = roleColor(personaFromRole(o.key));
  final badge = o.verified
      ? _roleStatusPill('Needs verification', AppColors.warning, Icons.verified_user_outlined)
      : _roleStatusPill('Instant', AppColors.success, Icons.bolt_outlined);
  return Container(
    decoration: BoxDecoration(
      border: Border.all(color: AppColors.surface2),
      borderRadius: BorderRadius.circular(AppSpacing.rLg),
    ),
    padding: const EdgeInsets.all(AppSpacing.x12),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Expanded(child: Text(o.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15))),
        badge,
      ]),
      const SizedBox(height: 6),
      Text(o.desc, style: const TextStyle(fontSize: 13, color: AppColors.textMuted)),
      const SizedBox(height: 8),
      Row(children: [
        const Icon(Icons.description_outlined, size: 14, color: AppColors.textSubtle),
        const SizedBox(width: 4),
        Expanded(child: Text(o.req, style: const TextStyle(fontSize: 12, color: AppColors.textSubtle))),
        const SizedBox(width: 8),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, (key: o.key, verified: o.verified)),
          style: FilledButton.styleFrom(
              visualDensity: VisualDensity.compact, padding: const EdgeInsets.symmetric(horizontal: 16)),
          child: const Text('Apply'),
        ),
      ]),
    ]),
  );
}

Widget _roleStatusPill(String label, Color c, IconData icon) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: c.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(AppSpacing.rFull)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 12, color: c),
        const SizedBox(width: 3),
        Text(label, style: TextStyle(fontSize: 10.5, color: c, fontWeight: FontWeight.w600)),
      ]),
    );

/// Mobile-only bottom navigation: the role's top 4 destinations. The drawer
/// still carries the full menu. Hidden on wide (web) layouts.
class NuzlBottomNav extends ConsumerWidget {
  const NuzlBottomNav({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = navItemsFor(ref.watch(personaProvider)).take(5).toList();
    if (items.length < 2) return const SizedBox.shrink();
    final location = GoRouterState.of(context).matchedLocation;
    var index = items.indexWhere((it) => isActiveRoute(location, it.route));
    if (index < 0) index = 0;
    // Solid nav bar with a hairline top separator (no glassmorphism).
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Theme.of(context).dividerColor, width: 0.5)),
      ),
      child: NavigationBar(
        backgroundColor: Theme.of(context).colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        selectedIndex: index,
        onDestinationSelected: (i) => context.go(items[i].route),
        destinations: items
            .map((it) => NavigationDestination(icon: Icon(it.icon), label: it.label))
            .toList(),
      ),
    );
  }
}

/// Shared sidebar content (logo + role badge + nav + profile). Used by both the
/// mobile Drawer and the persistent desktop sidebar.
class NuzlSidebarBody extends ConsumerWidget {
  const NuzlSidebarBody({super.key, this.inDrawer = true});
  final bool inDrawer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final persona = ref.watch(personaProvider);
    final items = navItemsFor(persona);
    final location = GoRouterState.of(context).matchedLocation;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final muted = dark ? AppColors.dTextMuted : AppColors.textMuted;
    final onSurface = dark ? AppColors.dText : AppColors.text;
    // Active nav: teal-tint fill + 4px gold left accent — premium and brand-led.
    final navTint = dark ? AppColors.dPrimaryTint : AppColors.secondary.withValues(alpha: 0.08);
    final navActive = dark ? AppColors.dPrimary : AppColors.secondary;
    const navAccent = AppColors.goldAccent;

    void go(String route) {
      if (inDrawer) Navigator.pop(context);
      context.go(route);
    }

    return SafeArea(
      child: Column(children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(AppSpacing.x20, AppSpacing.x20, AppSpacing.x20, AppSpacing.x8),
          child: Align(alignment: Alignment.centerLeft, child: NuzlLogo(size: 30)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x20),
          child: Align(alignment: Alignment.centerLeft, child: _RoleChip(inDrawer: inDrawer)),
        ),
        const SizedBox(height: AppSpacing.x8),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.x4),
            children: items.map((it) {
              final selected = isActiveRoute(location, it.route);
              // Premium: teal-tint fill + 4px gold left accent; monochrome icons
              // except the active item, which picks up the brand teal.
              return DecoratedBox(
                decoration: BoxDecoration(
                  color: selected ? navTint : null,
                  border: Border(left: BorderSide(color: selected ? navAccent : Colors.transparent, width: 4)),
                ),
                child: ListTile(
                  dense: true,
                  leading: Icon(it.icon, size: 20, color: selected ? navActive : muted),
                  title: Text(it.label, style: TextStyle(
                      color: selected ? onSurface : muted,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500)),
                  onTap: () => go(it.route),
                ),
              );
            }).toList(),
          ),
        ),
        const Divider(height: 1),
        // Footer tiles share one type scale with the nav items above (dense,
        // 14px / w500, theme onSurface) so 'Profile & settings' no longer
        // renders larger than its neighbours.
        ListTile(
          dense: true,
          leading: const Icon(Icons.card_giftcard, size: 20, color: AppColors.accentGold),
          title: Text('Rewards & referrals', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: onSurface)),
          subtitle: Text('Refer & earn · offers · leaderboard', style: TextStyle(fontSize: 11, color: muted)),
          onTap: () => go('/rewards-hub'),
        ),
        ListTile(
          dense: true,
          leading: Icon(Icons.person_outline, size: 20, color: muted),
          title: Text('Profile & settings', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: onSurface)),
          onTap: () => go('/profile'),
        ),
      ]),
    );
  }
}

/// Mobile drawer wrapper.
class NuzlDrawer extends StatelessWidget {
  const NuzlDrawer({super.key});
  @override
  Widget build(BuildContext context) => const Drawer(child: NuzlSidebarBody(inDrawer: true));
}

/// Persistent sidebar for wide (desktop/tablet) layouts.
class NuzlSidebar extends StatelessWidget {
  const NuzlSidebar({super.key});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 248,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(right: BorderSide(color: Theme.of(context).dividerColor, width: 0.5)),
      ),
      child: const NuzlSidebarBody(inDrawer: false),
    );
  }
}
