import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Type scale (design foundation): Poppins. Heavy bold reserved for KPIs and
/// primary actions; everything else 400–600.
class AppTypography {
  static TextTheme textTheme(Color text, Color muted) {
    TextStyle s(double size, double height, FontWeight w, {Color? c}) =>
        GoogleFonts.poppins(
          fontSize: size,
          height: height / size,
          fontWeight: w,
          color: c ?? text,
        );
    return TextTheme(
      displayLarge: s(32, 40, FontWeight.w700), // KPI
      displaySmall: s(30, 38, FontWeight.w700), // KPI
      headlineLarge: s(28, 36, FontWeight.w600), // pageTitle
      headlineMedium: s(24, 32, FontWeight.w600),
      headlineSmall: s(20, 28, FontWeight.w600), // sectionTitle / app bar
      titleLarge: s(18, 26, FontWeight.w600),
      titleMedium: s(16, 24, FontWeight.w500), // cardTitle
      titleSmall: s(14, 20, FontWeight.w500),
      bodyLarge: s(16, 24, FontWeight.w400),
      bodyMedium: s(14, 22, FontWeight.w400), // body
      bodySmall: s(12, 18, FontWeight.w400, c: muted), // caption
      labelLarge: s(14, 20, FontWeight.w600), // primary action
      labelMedium: s(12, 16, FontWeight.w500),
    );
  }
}
