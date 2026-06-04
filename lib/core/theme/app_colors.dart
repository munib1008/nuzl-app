import 'package:flutter/material.dart';

/// NUZL Design System 2.0 — a premium real-estate operating system.
/// Royal Blue (trust/investment) + Emerald (growth) + Warm Beige (luxury).
/// No pure black, no pure white.
class AppColors {
  // Brand
  static const primary = Color(0xFF1E3A8A);       // Royal Blue
  static const primaryHover = Color(0xFF172E6E);  // darker royal blue
  static const primaryDark = Color(0xFF0F1F52);   // deep navy (headers/badges)
  static const primaryTint = Color(0xFFDDE5F5);   // light royal-blue tint (selected nav)
  static const primaryBright = Color(0xFF3B82F6); // brighter blue accent
  static const secondary = Color(0xFF0F172A);     // deep navy (sidebar/headings)
  static const accentGold = Color(0xFFB45309);    // amber-800 (premium accent text)
  static const accentGoldTint = Color(0xFFF5F1E8);// warm beige (luxury surfaces)
  static const accentCream = Color(0xFFF5F1E8);   // warm beige
  static const accentPlum = Color(0xFF7C3AED);    // purple (projects/portfolio)

  // Semantic
  static const success = Color(0xFF15803D);       // Emerald
  static const warning = Color(0xFFD97706);       // Amber
  static const danger = Color(0xFFDC2626);        // Red
  static const info = Color(0xFF3B82F6);          // Blue

  // Light neutrals (no pure white)
  static const bg = Color(0xFFFAFAF8);
  static const surface = Color(0xFFFFFFFF);
  static const surface2 = Color(0xFFF3F4F6);
  static const border = Color(0xFFE5E7EB);
  static const borderStrong = Color(0xFFD1D5DB);
  static const text = Color(0xFF111827);
  static const textMuted = Color(0xFF6B7280);     // secondary text
  static const textSubtle = Color(0xFF9CA3AF);

  // Dark neutrals (no pure black — deep charcoal/navy)
  static const dBg = Color(0xFF111827);           // main background
  static const dSurface = Color(0xFF1F2937);      // secondary bg / app bars
  static const dSurface2 = Color(0xFF1E293B);     // card
  static const dBorder = Color(0xFF334155);
  static const dBorderStrong = Color(0xFF475569);
  static const dText = Color(0xFFF8FAFC);
  static const dTextMuted = Color(0xFFCBD5E1);
  static const dTextSubtle = Color(0xFF94A3B8);
  static const dPrimary = Color(0xFF3B82F6);      // brighter blue in dark
  static const dPrimaryTint = Color(0xFF1E293B);  // subtle selected tint
  static const dGold = Color(0xFFF59E0B);
}
