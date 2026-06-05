import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Type scale — Poppins everywhere. Bold (700) reserved for KPI numbers +
/// primary actions; Semibold (600) for titles; Medium (500) for card titles.
/// pageTitle 28/600 · sectionTitle 20/600 · cardTitle 16/500 · body 14/400 · caption 12/400.
class AppTypography {
  static TextTheme textTheme(Color text, Color muted) {
    TextStyle s(double size, FontWeight w, {Color? c, double ls = 0}) => GoogleFonts.poppins(
          fontSize: size,
          fontWeight: w,
          color: c ?? text,
          letterSpacing: ls,
          height: 1.3,
        );
    return TextTheme(
      displayLarge: s(30, FontWeight.w700, ls: -0.5), // KPI number
      displaySmall: s(26, FontWeight.w700, ls: -0.5), // KPI number
      headlineLarge: s(28, FontWeight.w600, ls: -0.3), // page title
      headlineMedium: s(24, FontWeight.w600, ls: -0.2),
      headlineSmall: s(20, FontWeight.w600, ls: -0.2), // section title / app bar
      titleLarge: s(18, FontWeight.w600),
      titleMedium: s(16, FontWeight.w500), // card title
      titleSmall: s(14, FontWeight.w500),
      bodyLarge: s(16, FontWeight.w400),
      bodyMedium: s(14, FontWeight.w400), // body
      bodySmall: s(12, FontWeight.w400, c: muted), // caption
      labelLarge: s(14, FontWeight.w600), // primary action
      labelMedium: s(12, FontWeight.w500),
    );
  }
}
