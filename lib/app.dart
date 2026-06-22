import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'core/router/app_router.dart';
import 'core/rbac/persona.dart';
import 'core/i18n/app_localizations.dart';
import 'core/i18n/locale_provider.dart';
import 'core/theme/theme_mode_provider.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/application/auth_controller.dart';

/// Localization delegates — AppLocalizations + the Material/Widgets/Cupertino
/// globals (the globals supply RTL text direction for Arabic automatically).
const _localizationsDelegates = <LocalizationsDelegate<dynamic>>[
  AppLocalizations.delegate,
  GlobalMaterialLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
];

/// Apply a professional Arabic font (Tajawal) over the theme when Arabic is on.
ThemeData _localizedTheme(ThemeData base, bool arabic) {
  if (!arabic) return base;
  return base.copyWith(
    textTheme: GoogleFonts.tajawalTextTheme(base.textTheme),
    primaryTextTheme: GoogleFonts.tajawalTextTheme(base.primaryTextTheme),
  );
}

class NuzlApp extends ConsumerWidget {
  const NuzlApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    final locale = ref.watch(localeProvider);
    final arabic = locale?.languageCode == 'ar';
    final light = _localizedTheme(AppTheme.light(), arabic);
    final dark = _localizedTheme(AppTheme.dark(), arabic);
    if (!auth.initialized) {
      return MaterialApp(
        theme: light,
        darkTheme: dark,
        locale: locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: _localizationsDelegates,
        debugShowCheckedModeBanner: false,
        home: const Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'NUZL',
      debugShowCheckedModeBanner: false,
      theme: light,
      darkTheme: dark,
      themeMode: ref.watch(themeModeProvider),
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: _localizationsDelegates,
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
    final preview = ref.watch(personaPreviewProvider);
    if (preview == null) return child;
    return Column(
      children: [
        Material(
          color: AppColors.accentGoldTint,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(children: [
                const Icon(Icons.science_outlined, size: 18, color: AppColors.secondary),
                const SizedBox(width: 8),
                Expanded(child: Text('TEST MODE — viewing as ${preview.label}',
                    style: const TextStyle(color: AppColors.secondary, fontWeight: FontWeight.w600))),
                TextButton(
                  onPressed: () => ref.read(personaPreviewProvider.notifier).state = null,
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
