import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Type scale — Manrope (modern geometric sans) for page/section headings,
/// Inter for body, labels and KPI numbers. Manrope SemiBold reads premium and
/// clean (lighter than the old serif) while numbers + dense UI stay legible.
/// Main titles share ONE size (20), differentiated by WEIGHT (700 → 600).
class AppTypography {
  static TextTheme textTheme(Color text, Color muted) {
    // Premium readability: body text breathes (1.5), while titles/labels stay
    // tight (≤1.3) so dense cards, chips and buttons don't overflow.
    TextStyle s(double size, FontWeight w, {Color? c, double ls = 0, double h = 1.35}) =>
        GoogleFonts.inter(
          fontSize: size,
          fontWeight: w,
          color: c ?? text,
          letterSpacing: ls,
          height: h,
        );
    // Manrope for headings — modern geometric sans, slightly tighter tracking.
    TextStyle d(double size, FontWeight w, {Color? c, double ls = -0.3, double h = 1.2}) =>
        GoogleFonts.manrope(
          fontSize: size,
          fontWeight: w,
          color: c ?? text,
          letterSpacing: ls,
          height: h,
        );
    return TextTheme(
      // KPI numbers — kept on Inter so figures stay clean + tabular-feeling.
      displayLarge: s(24, FontWeight.w700, ls: -0.4, h: 1.15),
      displaySmall: s(22, FontWeight.w700, ls: -0.3, h: 1.15),
      // Main titles — Fraunces serif; same size (20), weight differentiates.
      headlineLarge: d(20, FontWeight.w700, h: 1.25), // page title (bold)
      headlineMedium: d(20, FontWeight.w600, h: 1.25), // page title (semibold)
      headlineSmall: d(20, FontWeight.w600, h: 1.25), // section title / app bar (semibold)
      // Card / sub titles — one calm step down.
      titleLarge: s(16, FontWeight.w600, h: 1.3),
      titleMedium: s(16, FontWeight.w600, h: 1.3), // card title
      titleSmall: s(14, FontWeight.w500, h: 1.3), // minor title (medium)
      // Body — opened up for comfortable reading.
      bodyLarge: s(16, FontWeight.w400, h: 1.55),
      bodyMedium: s(14, FontWeight.w400, h: 1.5), // body
      bodySmall: s(12, FontWeight.w400, c: muted, h: 1.45), // caption
      // Labels stay tight (buttons / chips).
      labelLarge: s(14, FontWeight.w600, h: 1.2), // primary action
      labelMedium: s(12, FontWeight.w500, h: 1.2),
    );
  }
}
