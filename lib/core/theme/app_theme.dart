import 'package:flutter/material.dart';
import 'package:figma_squircle/figma_squircle.dart';
import 'app_colors.dart';
import 'app_spacing.dart';
import 'app_typography.dart';

/// Builds light + dark ThemeData from NUZL tokens — Apple-inspired:
/// squircle cards/buttons, hairline separators, soft depth, gentle motion.
class AppTheme {
  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness b) {
    final dark = b == Brightness.dark;
    final primary = dark ? AppColors.dPrimary : AppColors.primary;
    final bg = dark ? AppColors.dBg : AppColors.bg;
    final surface = dark ? AppColors.dSurface : AppColors.surface; // app bars / sheets
    final card = dark ? AppColors.dSurface2 : AppColors.surface; // elevated cards
    final border = dark ? AppColors.dBorder : AppColors.border;
    final borderStrong = dark ? AppColors.dBorderStrong : AppColors.borderStrong;
    final text = dark ? AppColors.dText : AppColors.text;
    final muted = dark ? AppColors.dTextMuted : AppColors.textMuted;
    final tt = AppTypography.textTheme(text, muted);

    // Squircle (iOS-style continuous corners) for cards + buttons.
    final cardShape = SmoothRectangleBorder(
      side: BorderSide(color: border),
      borderRadius: SmoothBorderRadius(cornerRadius: 20, cornerSmoothing: 0.6),
    );
    final buttonShape = SmoothRectangleBorder(
      borderRadius: SmoothBorderRadius(cornerRadius: 20, cornerSmoothing: 0.6),
    );
    const motion = Duration(milliseconds: 250);

    final scheme = ColorScheme(
      brightness: b,
      primary: primary,
      onPrimary: Colors.white,
      secondary: AppColors.accentGold,
      onSecondary: Colors.white,
      error: AppColors.danger,
      onError: Colors.white,
      surface: surface,
      onSurface: text,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: bg,
      textTheme: tt,
      dividerColor: border,
      dividerTheme: DividerThemeData(color: border, thickness: 0.5, space: 0.5),
      appBarTheme: AppBarTheme(
        backgroundColor: surface,
        foregroundColor: text,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: tt.headlineSmall,
      ),
      cardTheme: CardThemeData(
        color: card,
        elevation: 0,
        shape: cardShape,
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: card,
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.x16, vertical: AppSpacing.x12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.rCard),
          borderSide: BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.rCard),
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.rCard),
          borderSide: BorderSide(color: primary, width: 2),
        ),
        hintStyle: TextStyle(color: muted),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(AppSpacing.tapTarget),
          shape: buttonShape,
          textStyle: tt.labelLarge,
        ).copyWith(animationDuration: motion),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(AppSpacing.tapTarget),
          shape: buttonShape,
          side: BorderSide(color: borderStrong),
          textStyle: tt.labelLarge,
        ).copyWith(animationDuration: motion),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(shape: buttonShape, textStyle: tt.labelLarge).copyWith(animationDuration: motion),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        elevation: 0,
        indicatorColor: dark ? AppColors.dPrimaryTint : AppColors.primaryTint,
        labelTextStyle: WidgetStatePropertyAll(tt.labelMedium),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(builders: {
        TargetPlatform.android: _ApplePageTransitions(),
        TargetPlatform.iOS: _ApplePageTransitions(),
      }),
    );
  }
}

/// Gentle fade + tiny rise, easeOutCubic (~300ms route default).
class _ApplePageTransitions extends PageTransitionsBuilder {
  const _ApplePageTransitions();
  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 0.02), end: Offset.zero).animate(curved),
        child: child,
      ),
    );
  }
}
