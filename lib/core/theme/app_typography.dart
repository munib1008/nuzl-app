import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Type scale — Inter. Calm + consistent: all main titles share ONE size (20)
/// and are differentiated by WEIGHT, not size — bold (700) → semibold (600).
/// Card/sub titles sit one step down (16/14). Body 400/500. Nothing "loud".
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
      // KPI numbers — prominent but not shouting.
      displayLarge: s(24, FontWeight.w700, ls: -0.4),
      displaySmall: s(22, FontWeight.w700, ls: -0.3),
      // Main titles — same size (20), weight is the only differentiator.
      headlineLarge: s(20, FontWeight.w700, ls: -0.2), // page title (bold)
      headlineMedium: s(20, FontWeight.w600, ls: -0.2), // page title (semibold)
      headlineSmall: s(20, FontWeight.w600, ls: -0.2), // section title / app bar (semibold)
      // Card / sub titles — one calm step down.
      titleLarge: s(16, FontWeight.w600),
      titleMedium: s(16, FontWeight.w600), // card title
      titleSmall: s(14, FontWeight.w500), // minor title (medium)
      // Body + labels.
      bodyLarge: s(16, FontWeight.w400),
      bodyMedium: s(14, FontWeight.w400), // body
      bodySmall: s(12, FontWeight.w400, c: muted), // caption
      labelLarge: s(14, FontWeight.w600), // primary action
      labelMedium: s(12, FontWeight.w500),
    );
  }
}
