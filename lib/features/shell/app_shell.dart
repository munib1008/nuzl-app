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
      titleSpacing: 0,
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
        ...?actions,
        const _RoleSwitcher(),
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

/// Top-nav role switcher (UAT #3) — shown only when the account holds >1
/// approved role. Switching writes the active role server-side (survives
/// devices) and reloads nav + dashboard.
class _RoleSwitcher extends ConsumerWidget {
  const _RoleSwitcher();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).user;
    final roles = user?.approvedRoles ?? const [];
    if (roles.length < 2) return const SizedBox.shrink();
    final active = (user?.activeRole?.isNotEmpty == true) ? user!.activeRole! : roles.first;
    final t = Theme.of(context).textTheme;
    return PopupMenuButton<String>(
      tooltip: 'Switch role',
      offset: const Offset(0, 44),
      onSelected: (r) async {
        if (r == active) return;
        await ref.read(authControllerProvider.notifier).switchRole(r);
        if (context.mounted) context.go('/dashboard');
      },
      itemBuilder: (_) => roles
          .map((r) => PopupMenuItem<String>(
                value: r,
                child: Row(children: [
                  Icon(r == active ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                      size: 16, color: r == active ? AppColors.primary : AppColors.textMuted),
                  const SizedBox(width: 8),
                  Text(personaFromRole(r).label),
                ]),
              ))
          .toList(),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.primaryTint,
          borderRadius: BorderRadius.circular(AppSpacing.rFull),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.swap_horiz, size: 16, color: AppColors.primary),
          const SizedBox(width: 4),
          Text(personaFromRole(active).label,
              style: t.bodySmall?.copyWith(color: AppColors.primary, fontWeight: FontWeight.w600)),
        ]),
      ),
    );
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
    final t = Theme.of(context).textTheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final accent = dark ? AppColors.dPrimary : AppColors.primary;
    final tint = dark ? AppColors.dPrimaryTint : AppColors.primaryTint;
    final muted = dark ? AppColors.dTextMuted : AppColors.textMuted;
    final onSurface = dark ? AppColors.dText : AppColors.text;

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
          child: Align(
            alignment: Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x12, vertical: 4),
              decoration: BoxDecoration(color: tint, borderRadius: BorderRadius.circular(AppSpacing.rFull)),
              child: Text(persona.label, style: t.bodySmall?.copyWith(color: accent, fontWeight: FontWeight.w600)),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.x8),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.x4),
            children: items.map((it) {
              final selected = it.route == '/dashboard'
                  ? location == '/dashboard'
                  : location.startsWith(it.route);
              // Enterprise: subtle tint + 3px left accent border; monochrome icons except active.
              return DecoratedBox(
                decoration: BoxDecoration(
                  color: selected ? tint : null,
                  border: Border(left: BorderSide(color: selected ? accent : Colors.transparent, width: 3)),
                ),
                child: ListTile(
                  dense: true,
                  leading: Icon(it.icon, size: 20, color: selected ? accent : muted),
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
