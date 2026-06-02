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
      leading: Builder(
        builder: (ctx) => IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () => Scaffold.of(ctx).openDrawer(),
        ),
      ),
      title: title != null
          ? Text(title!)
          : const NuzlLogo(size: 28),
      actions: [
        ...?actions,
        IconButton(
          tooltip: 'Toggle light / dark',
          icon: Icon(Theme.of(context).brightness == Brightness.dark
              ? Icons.light_mode_outlined
              : Icons.dark_mode_outlined),
          onPressed: () => ref.read(themeModeProvider.notifier).toggle(),
        ),
        ref.watch(unreadCountProvider).maybeWhen(
              data: (n) => _Bell(count: n, onTap: () => context.go('/soon/Notifications')),
              orElse: () => IconButton(
                  icon: const Icon(Icons.notifications_none),
                  onPressed: () => context.go('/soon/Notifications')),
            ),
        PopupMenuButton<String>(
          offset: const Offset(0, 48),
          onSelected: (v) async {
            if (v == 'profile') context.go('/profile');
            if (v == 'logout') {
              await ref.read(authControllerProvider.notifier).logout();
              if (context.mounted) context.go('/login');
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

/// Role-based navigation drawer (menu varies by persona) + profile footer.
class NuzlDrawer extends ConsumerWidget {
  const NuzlDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final persona = ref.watch(personaProvider);
    final items = navItemsFor(persona);
    final location = GoRouterState.of(context).matchedLocation;
    final t = Theme.of(context).textTheme;

    return Drawer(
      child: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.x20, AppSpacing.x20, AppSpacing.x20, AppSpacing.x8),
            child: Align(alignment: Alignment.centerLeft, child: const NuzlLogo(size: 34)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x20),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x12, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primaryTint, borderRadius: BorderRadius.circular(AppSpacing.rFull)),
                child: Text(persona.label, style: t.bodySmall?.copyWith(
                    color: AppColors.primaryDark, fontWeight: FontWeight.w600)),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.x8),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x8),
              children: items.map((it) {
                final selected = it.route == '/dashboard'
                    ? location == '/dashboard'
                    : location.startsWith(it.route);
                return ListTile(
                  leading: Icon(it.icon, color: selected ? AppColors.primary : null),
                  title: Text(it.label, style: TextStyle(
                      color: selected ? AppColors.primary : null,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w400)),
                  selected: selected,
                  selectedTileColor: AppColors.primaryTint,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.rMd)),
                  onTap: () { Navigator.pop(context); context.go(it.route); },
                );
              }).toList(),
            ),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: const Text('Profile & settings'),
            onTap: () { Navigator.pop(context); context.go('/profile'); },
          ),
        ]),
      ),
    );
  }
}
