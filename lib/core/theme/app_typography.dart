import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Type scale — Inter (enterprise SaaS). Semibold (600) for titles + primary
/// actions, Bold (700) for KPI numbers; everything else 400/500. Dense, legible.
class AppTypography {
  static TextTheme textTheme(Color text, Color muted) {
    TextStyle s(double size, FontWeight w, {Color? c, double ls = 0}) => GoogleFonts.inter(
          fontSize: size,
          fontWeight: w,
          color: c ?? text,
          letterSpacing: ls,
          height: 1.35,
        );
    return TextTheme(
      displayLarge: s(30, FontWeight.w700, ls: -0.5), // KPI number
      displaySmall: s(26, FontWeight.w700, ls: -0.4), // KPI number
      headlineLarge: s(28, FontWeight.w600, ls: -0.4), // page title
      headlineMedium: s(24, FontWeight.w600, ls: -0.3),
      headlineSmall: s(20, FontWeight.w600, ls: -0.2), // section title / app bar
      titleLarge: s(18, FontWeight.w600, ls: -0.1),
      titleMedium: s(16, FontWeight.w600), // card title
      titleSmall: s(14, FontWeight.w600),
      bodyLarge: s(16, FontWeight.w400),
      bodyMedium: s(14, FontWeight.w400), // body
      bodySmall: s(12, FontWeight.w400, c: muted), // caption
      labelLarge: s(14, FontWeight.w600), // primary action
      labelMedium: s(12, FontWeight.w500),
    );
  }
}
