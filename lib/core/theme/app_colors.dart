import 'package:flutter/material.dart';

/// NUZL design-system colors — Teal · Gold · Cream palette.
/// Mirrors NUZL_Design_System.md (§2).
class AppColors {
  // Brand — teal primary, deep teal-navy headers
  static const primary = Color(0xFF21616A); // deep teal (button bg, white-text safe)
  static const primaryHover = Color(0xFF1A4E55);
  static const primaryDark = Color(0xFF0F2C33); // deep teal-navy
  static const primaryTint = Color(0xFFE2F1F1); // light teal wash (selected states)
  static const primaryBright = Color(0xFF2E9CA0); // vivid teal accent (icons, highlights)
  static const secondary = Color(0xFF0F2C33); // deep teal-navy
  static const accentGold = Color(0xFFEFA00F); // vivid gold
  static const accentGoldTint = Color(0xFFFDF1D6); // light gold wash
  static const accentCream = Color(0xFFE6D1B4); // warm cream neutral
  static const accentPlum = Color(0xFF533946); // muted plum (rare accents)

  // Semantic
  static const success = Color(0xFF198754);
  static const warning = Color(0xFFD49A00);
  static const danger = Color(0xFFC0392B);
  static const info = Color(0xFF2E9CA0);

  // Light neutrals (faint teal warmth)
  static const bg = Color(0xFFF5F9F9);
  static const surface = Color(0xFFFFFFFF);
  static const surface2 = Color(0xFFEDF4F4);
  static const border = Color(0xFFDCE7E7);
  static const borderStrong = Color(0xFFC2D3D3);
  static const text = Color(0xFF132A2E);
  static const textMuted = Color(0xFF5A7378);
  static const textSubtle = Color(0xFF8AA2A6);

  // Dark neutrals (deep teal-navy, never pure black)
  static const dBg = Color(0xFF0C242B);
  static const dSurface = Color(0xFF103039);
  static const dSurface2 = Color(0xFF143A45);
  static const dBorder = Color(0xFF1E4A54);
  static const dBorderStrong = Color(0xFF2A5C68);
  static const dText = Color(0xFFE5EFEF);
  static const dTextMuted = Color(0xFF93B2B7);
  static const dTextSubtle = Color(0xFF5F8086);
  static const dPrimary = Color(0xFF2E9CA0); // vivid teal for dark contrast
  static const dPrimaryTint = Color(0xFF123139);
  static const dGold = Color(0xFFF0B73E);
}
