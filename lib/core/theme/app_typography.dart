import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Type scale from NUZL_Design_System.md (§3). Inter as primary face.
class AppTypography {
  static TextTheme textTheme(Color text, Color muted) {
    TextStyle s(double size, double height, FontWeight w, {Color? c}) =>
        GoogleFonts.inter(
          fontSize: size,
          height: height / size,
          fontWeight: w,
          color: c ?? text,
        );
    return TextTheme(
      displayLarge: s(32, 40, FontWeight.w700),
      headlineLarge: s(28, 36, FontWeight.w700),
      headlineMedium: s(24, 32, FontWeight.w600),
      headlineSmall: s(20, 28, FontWeight.w600),
      titleLarge: s(18, 26, FontWeight.w600),
      titleMedium: s(16, 24, FontWeight.w600),
      bodyLarge: s(16, 24, FontWeight.w400),
      bodyMedium: s(14, 22, FontWeight.w400),
      bodySmall: s(12, 18, FontWeight.w400, c: muted),
      labelLarge: s(14, 20, FontWeight.w600),
      labelMedium: s(12, 16, FontWeight.w500),
    );
  }
}
