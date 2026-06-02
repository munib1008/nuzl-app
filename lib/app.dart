import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/router/app_router.dart';
import 'core/rbac/persona.dart';
import 'core/theme/theme_mode_provider.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/application/auth_controller.dart';

class NuzlApp extends ConsumerWidget {
  const NuzlApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    if (!auth.initialized) {
      return MaterialApp(
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        debugShowCheckedModeBanner: false,
        home: const Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'NUZL',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ref.watch(themeModeProvider),
      routerConfig: router,
      builder: (context, child) => _TestModeWrapper(child: child ?? const SizedBox.shrink()),
    );
  }
}

/// Renders a persistent "TEST MODE — viewing as {role}" banner above all
/// screens when a super-admin is previewing another role (Section 6).
class _TestModeWrapper extends ConsumerWidget {
  const _TestModeWrapper({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final override = ref.watch(personaOverrideProvider);
    final actual = personaFromRole(ref.watch(authControllerProvider).user?.role);
    final testing = override != null && override != actual;
    if (!testing) return child;
    return Column(
      children: [
        Material(
          color: AppColors.accentGold,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(children: [
                const Icon(Icons.science_outlined, size: 18, color: AppColors.secondary),
                const SizedBox(width: 8),
                Expanded(child: Text('TEST MODE — viewing as ${override.label}',
                    style: const TextStyle(color: AppColors.secondary, fontWeight: FontWeight.w600))),
                TextButton(
                  onPressed: () => ref.read(personaOverrideProvider.notifier).state = null,
                  child: const Text('Exit'),
                ),
              ]),
            ),
          ),
        ),
        Expanded(child: child),
      ],
    );
  }
}
