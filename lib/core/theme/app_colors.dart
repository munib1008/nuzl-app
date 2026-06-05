import 'package:flutter/material.dart';

/// NUZL Design System 2.1 — gradient brand.
/// Light: Teal → Blue on slate-white.  Dark (true dark): Purple → Pink on deep slate.
/// Constant names are kept stable so screens reflow automatically.
class AppColors {
  // ── Brand (light) ──
  static const primary = Color(0xFF14B8A6); // Teal
  static const primaryHover = Color(0xFF0F9488);
  static const primaryDark = Color(0xFF0F766E);
  static const primaryTint = Color(0xFFECFDF5); // Mint
  static const primaryBright = Color(0xFF2DD4BF);
  static const secondary = Color(0xFF2563EB); // Blue
  static const accentGold = Color(0xFFB45309); // amber-800 (badge text)
  static const accentGoldTint = Color(0xFFFEF3C7);
  static const accentCream = Color(0xFFECFDF5);
  static const accentPlum = Color(0xFF7C3AED); // Purple (dark primary / projects)

  // ── Brand gradient ──
  static const gradientStart = Color(0xFF14B8A6); // light: teal
  static const gradientEnd = Color(0xFF2563EB); // light: blue
  static const dGradientStart = Color(0xFF7C3AED); // dark: purple
  static const dGradientEnd = Color(0xFFEC4899); // dark: pink
  static List<Color> brandGradient(bool dark) =>
      dark ? const [dGradientStart, dGradientEnd] : const [gradientStart, gradientEnd];

  // ── Semantic (shared) ──
  static const success = Color(0xFF10B981);
  static const warning = Color(0xFFF59E0B);
  static const danger = Color(0xFFEF4444);
  static const info = Color(0xFF2563EB);

  // ── Light neutrals ──
  static const bg = Color(0xFFF1F5F9);
  static const surface = Color(0xFFFFFFFF);
  static const surface2 = Color(0xFFE2E8F0);
  static const border = Color(0xFFE2E8F0);
  static const borderStrong = Color(0xFFCBD5E1);
  static const text = Color(0xFF0F172A);
  static const textMuted = Color(0xFF64748B); // secondary text
  static const textSubtle = Color(0xFF94A3B8); // muted

  // ── Dark neutrals (true dark, not inverted) ──
  static const dBg = Color(0xFF0B1220); // Slate
  static const dSurface = Color(0xFF111C2E); // surface / app bars
  static const dSurface2 = Color(0xFF1E293B); // card (Gray)
  static const dBorder = Color(0xFF334155);
  static const dBorderStrong = Color(0xFF475569);
  static const dText = Color(0xFFF8FAFC);
  static const dTextMuted = Color(0xFF94A3B8);
  static const dTextSubtle = Color(0xFF64748B);
  static const dPrimary = Color(0xFF7C3AED); // Purple
  static const dPrimaryTint = Color(0xFF1E1B4B); // deep indigo tint
  static const dSecondary = Color(0xFFEC4899); // Pink
  static const dTertiary = Color(0xFF6366F1); // Indigo
  static const dGold = Color(0xFFF59E0B);
}
