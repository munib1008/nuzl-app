import 'package:flutter/material.dart';

/// NUZL design-system colors. Mirrors NUZL_Design_System.md (§2).
class AppColors {
  // Brand
  static const primary = Color(0xFF0F6B5B);
  static const primaryHover = Color(0xFF0C5C4E);
  static const primaryDark = Color(0xFF0A4D42);
  static const primaryTint = Color(0xFFE6F2EF);
  static const secondary = Color(0xFF132238);
  static const accentGold = Color(0xFFC8A45D);
  static const accentGoldTint = Color(0xFFF6EFDD);

  // Semantic
  static const success = Color(0xFF198754);
  static const warning = Color(0xFFD49A00);
  static const danger = Color(0xFFC0392B);
  static const info = Color(0xFF2563EB);

  // Light neutrals
  static const bg = Color(0xFFF8FAFC);
  static const surface = Color(0xFFFFFFFF);
  static const surface2 = Color(0xFFF1F5F9);
  static const border = Color(0xFFE2E8F0);
  static const borderStrong = Color(0xFFCBD5E1);
  static const text = Color(0xFF1E293B);
  static const textMuted = Color(0xFF64748B);
  static const textSubtle = Color(0xFF94A3B8);

  // Dark neutrals (never pure black)
  static const dBg = Color(0xFF0F172A);
  static const dSurface = Color(0xFF162032);
  static const dSurface2 = Color(0xFF1B2740);
  static const dBorder = Color(0xFF263244);
  static const dBorderStrong = Color(0xFF33425A);
  static const dText = Color(0xFFE2E8F0);
  static const dTextMuted = Color(0xFF94A3B8);
  static const dPrimary = Color(0xFF1E9C85); // lightened for dark contrast
  static const dPrimaryTint = Color(0xFF13332C);
  static const dGold = Color(0xFFD4B36E);
}
