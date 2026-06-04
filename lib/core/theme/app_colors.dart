import 'package:flutter/material.dart';

/// NUZL design tokens — Apple-inspired neutrals, brand teal kept.
class AppColors {
  // Brand (unchanged hue)
  static const primary = Color(0xFF0F766E);
  static const primaryHover = Color(0xFF115E59);
  static const primaryDark = Color(0xFF042F2E);
  static const primaryTint = Color(0xFFCCFBF1);
  static const primaryBright = Color(0xFF14B8A6);
  static const secondary = Color(0xFF042F2E);
  static const accentGold = Color(0xFFFF9500);
  static const accentGoldTint = Color(0xFFFFF2DD);
  static const accentCream = Color(0xFFE6D1B4);
  static const accentPlum = Color(0xFF533946);

  // Semantic (Apple system)
  static const success = Color(0xFF34C759);
  static const warning = Color(0xFFFF9500);
  static const danger = Color(0xFFFF3B30);
  static const info = Color(0xFF14B8A6);

  // Light neutrals (Apple system)
  static const bg = Color(0xFFF2F2F7);
  static const surface = Color(0xFFFFFFFF);
  static const surface2 = Color(0xFFEFEFF4);
  static const border = Color(0xFFE5E5EA); // separator
  static const borderStrong = Color(0xFFD1D1D6);
  static const text = Color(0xFF1C1C1E);
  static const textMuted = Color(0xFF8E8E93); // secondary
  static const textSubtle = Color(0xFFAEAEB2);

  // Dark neutrals (Apple system; true-black background)
  static const dBg = Color(0xFF000000);
  static const dSurface = Color(0xFF1C1C1E);
  static const dSurface2 = Color(0xFF2C2C2E); // card
  static const dBorder = Color(0xFF38383A); // separator
  static const dBorderStrong = Color(0xFF48484A);
  static const dText = Color(0xFFF5F5F7);
  static const dTextMuted = Color(0xFF8E8E93);
  static const dTextSubtle = Color(0xFF636366);
  static const dPrimary = Color(0xFF2DD4BF);
  static const dPrimaryTint = Color(0xFF0E2E2A);
  static const dGold = Color(0xFFFF9F0A);
}
