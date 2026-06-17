import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Type scale — Inter. Calm + consistent: all main titles share ONE size (20)
/// and are differentiated by WEIGHT, not size — bold (700) → semibold (600).
/// Card/sub titles sit one step down (16/14). Body 400/500. Nothing "loud".
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
    return TextTheme(
      // KPI numbers — prominent but not shouting.
      displayLarge: s(24, FontWeight.w700, ls: -0.4, h: 1.15),
      displaySmall: s(22, FontWeight.w700, ls: -0.3, h: 1.15),
      // Main titles — same size (20), weight is the only differentiator.
      headlineLarge: s(20, FontWeight.w700, ls: -0.2, h: 1.25), // page title (bold)
      headlineMedium: s(20, FontWeight.w600, ls: -0.2, h: 1.25), // page title (semibold)
      headlineSmall: s(20, FontWeight.w600, ls: -0.2, h: 1.25), // section title / app bar (semibold)
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
