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
        // Permanent, prominent role switcher — visible on every authenticated page
        // (desktop + mobile header). "Viewing as <Role> ▼", role-coloured.
        if (user != null)
          const Padding(padding: EdgeInsets.symmetric(horizontal: AppSpacing.x4), child: RoleSwitcher()),
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
                leading: Icon(Icons.logout, color: Colors.redAccent),
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
            decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle),
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
    final roles = user?.approvedRoles ?? const [];
    final active = (user?.activeRole?.isNotEmpty == true)
        ? user!.activeRole!
        : (roles.isNotEmpty ? roles.first : null);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final accent = dark ? AppColors.dPrimary : AppColors.primary;
    final tint = dark ? AppColors.dPrimaryTint : AppColors.primaryTint;
    final t = Theme.of(context).textTheme;
    final multi = roles.length >= 2;

    final pill = Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x12, vertical: 5),
      decoration: BoxDecoration(color: tint, borderRadius: BorderRadius.circular(AppSpacing.rFull)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.account_circle_outlined, size: 15, color: accent),
        const SizedBox(width: 6),
        Text(persona.label, style: t.bodySmall?.copyWith(color: accent, fontWeight: FontWeight.w600)),
        if (multi) ...[
          const SizedBox(width: 6),
          Icon(Icons.swap_horiz, size: 15, color: accent),
        ],
      ]),
    );
    if (!multi) return pill;

    return PopupMenuButton<String>(
      tooltip: 'Switch role',
      offset: const Offset(0, 40),
      onSelected: (r) async {
        if (r == active) return;
        await ref.read(authControllerProvider.notifier).switchRole(r);
        if (!context.mounted) return;
        if (inDrawer) Navigator.pop(context); // close the drawer after switching
        context.go('/dashboard');
      },
      itemBuilder: (_) => roles
          .map((r) => PopupMenuItem<String>(
                value: r,
                child: Row(children: [
                  Icon(r == active ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                      size: 16, color: r == active ? accent : AppColors.textMuted),
                  const SizedBox(width: 8),
                  Text(personaFromRole(r).label),
                ]),
              ))
          .toList(),
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

/// Top-bar role switcher: "Viewing as <Role> ▼" with a role-coloured badge.
/// Always shown for signed-in users (even single-role) so role activation is
/// discoverable; the dropdown lists active roles + "Add a role".
class RoleSwitcher extends ConsumerWidget {
  const RoleSwitcher({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).user;
    if (user == null) return const SizedBox.shrink();
    final persona = ref.watch(personaProvider);
    final roles = user.approvedRoles;
    final active = (user.activeRole?.isNotEmpty == true)
        ? user.activeRole!
        : (roles.isNotEmpty ? roles.first : null);
    final wide = MediaQuery.sizeOf(context).width >= 600;
    final c = roleColor(persona);
    final t = Theme.of(context).textTheme;

    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSpacing.rFull),
        border: Border.all(color: c.withValues(alpha: 0.35)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (wide) ...[
          Text('Viewing as', style: t.bodySmall?.copyWith(color: AppColors.textMuted)),
          const SizedBox(width: 6),
        ],
        Container(width: 8, height: 8, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(persona.label, style: t.bodySmall?.copyWith(color: c, fontWeight: FontWeight.w700)),
        Icon(Icons.expand_more, size: 16, color: c),
      ]),
    );

    return PopupMenuButton<String>(
      tooltip: 'Switch role',
      offset: const Offset(0, 44),
      onSelected: (r) async {
        if (r == '__add__') {
          await _addRole(context, ref, roles);
          return;
        }
        if (r == active) return;
        await ref.read(authControllerProvider.notifier).switchRole(r);
        if (context.mounted) context.go('/dashboard');
      },
      itemBuilder: (_) => [
        for (final r in roles)
          PopupMenuItem<String>(
            value: r,
            child: Row(children: [
              Container(width: 8, height: 8,
                  decoration: BoxDecoration(color: roleColor(personaFromRole(r)), shape: BoxShape.circle)),
              const SizedBox(width: 10),
              Text(personaFromRole(r).label),
              if (r == active) ...[const Spacer(), const Icon(Icons.check, size: 16, color: AppColors.primary)],
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
      child: chip,
    );
  }

  // Roles a user can add to their single account. Verified roles need RERA / a
  // trade license (they land as 'pending' until approved).
  static const _addable = [
    ('owner', 'Property Owner', false),
    ('tenant', 'Tenant', false),
    ('investor', 'Investor', false),
    ('agent', 'Agent', true),
    ('developer', 'Developer', true),
    ('provider', 'Service Provider', true),
    ('supplier', 'Supplier', true),
  ];

  Future<void> _addRole(BuildContext context, WidgetRef ref, List<String> held) async {
    final options = _addable.where((o) => !held.contains(o.$1)).toList();
    final picked = await showDialog<({String key, bool verified})>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Add a role'),
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(24, 0, 24, 8),
            child: Text('One account, many roles. Verified roles are reviewed before they go live.',
                style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
          ),
          if (options.isEmpty)
            const Padding(padding: EdgeInsets.all(24), child: Text('You already have every role.'))
          else
            for (final o in options)
              SimpleDialogOption(
                onPressed: () => Navigator.pop(ctx, (key: o.$1, verified: o.$3)),
                child: Row(children: [
                  Container(width: 8, height: 8,
                      decoration: BoxDecoration(color: roleColor(personaFromRole(o.$1)), shape: BoxShape.circle)),
                  const SizedBox(width: 10),
                  Text(o.$2),
                  if (o.$3) ...[
                    const Spacer(),
                    const Icon(Icons.verified_user_outlined, size: 14, color: AppColors.textMuted),
                    const SizedBox(width: 4),
                    const Text('Verification', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                  ],
                ]),
              ),
        ],
      ),
    );
    if (picked == null) return;
    try {
      await ref.read(apiClientProvider).post('/users/me/roles', body: {'role': picked.key});
      await ref.read(authControllerProvider.notifier).bootstrap(); // refresh approved roles
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(picked.verified
            ? 'Requested — your role will activate once verified.'
            : 'Role added — switch to it from the top bar.'),
      ));
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }
}

/// Mobile-only bottom navigation: the role's top 4 destinations. The drawer
/// still carries the full menu. Hidden on wide (web) layouts.
class NuzlBottomNav extends ConsumerWidget {
  const NuzlBottomNav({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = navItemsFor(ref.watch(personaProvider)).take(4).toList();
    if (items.length < 2) return const SizedBox.shrink();
    final location = GoRouterState.of(context).matchedLocation;
    var index = items.indexWhere((it) =>
        it.route == '/dashboard' ? location == '/dashboard' : location.startsWith(it.route));
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
              final selected = it.route == '/dashboard'
                  ? location == '/dashboard'
                  : location.startsWith(it.route);
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
        ListTile(
          dense: true,
          leading: const Icon(Icons.card_giftcard, color: AppColors.accentGold),
          title: const Text('Refer & Earn'),
          subtitle: const Text('Get a free month', style: TextStyle(fontSize: 11)),
          onTap: () => go('/refer'),
        ),
        ListTile(
          dense: true,
          leading: const Icon(Icons.emoji_events_outlined, color: AppColors.accentGold),
          title: const Text('Rewards & offers'),
          onTap: () => go('/rewards'),
        ),
        ListTile(
          leading: const Icon(Icons.person_outline),
          title: const Text('Profile & settings'),
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
