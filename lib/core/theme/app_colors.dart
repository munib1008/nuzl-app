import 'package:flutter/material.dart';

/// NUZL Design System 3.0 — enterprise SaaS + real-estate marketplace.
/// Brand gradient is FIXED across light/dark: #00C2A8 (teal) → #6D4AFF (violet).
/// Constant names are kept stable so screens reflow automatically.
class AppColors {
  // ── Brand (fixed gradient endpoints) ──
  static const primary = Color(0xFF00C2A8); // Teal (gradient start)
  static const primaryHover = Color(0xFF00A892);
  static const primaryDark = Color(0xFF00897B);
  static const primaryTint = Color(0xFFE6FAF6); // subtle teal — active nav (light)
  static const primaryBright = Color(0xFF2DD4BF);
  static const secondary = Color(0xFF6D4AFF); // Violet (gradient end)
  static const accentGold = Color(0xFFB45309);
  static const accentGoldTint = Color(0xFFFEF3C7);
  static const accentCream = Color(0xFFE6FAF6);
  static const accentPlum = Color(0xFF6D4AFF);

  // ── Brand gradient (FIXED — never recolour by theme; used by the logo + primary buttons) ──
  static const gradientStart = Color(0xFF00C2A8);
  static const gradientEnd = Color(0xFF6D4AFF);
  static List<Color> brandGradient([bool dark = false]) => const [gradientStart, gradientEnd];

  // ── Semantic (shared) ──
  static const success = Color(0xFF10B981);
  static const warning = Color(0xFFF59E0B);
  static const danger = Color(0xFFEF4444);
  static const info = Color(0xFF6D4AFF);

  // ── Light neutrals ──
  static const bg = Color(0xFFF8FAFC);
  static const surface = Color(0xFFFFFFFF); // cards + sidebar
  static const surface2 = Color(0xFFF1F5F9);
  static const border = Color(0xFFE2E8F0);
  static const borderStrong = Color(0xFFCBD5E1);
  static const text = Color(0xFF0F172A);
  static const textMuted = Color(0xFF64748B); // secondary text
  static const textSubtle = Color(0xFF94A3B8);

  // ── Dark neutrals (true dark) ──
  static const dBg = Color(0xFF020617);
  static const dSurface = Color(0xFF0F172A); // sidebar + app bars
  static const dSurface2 = Color(0xFF111827); // cards
  static const dBorder = Color(0xFF1E293B);
  static const dBorderStrong = Color(0xFF334155);
  static const dText = Color(0xFFF8FAFC);
  static const dTextMuted = Color(0xFF94A3B8);
  static const dTextSubtle = Color(0xFF64748B);
  static const dPrimary = Color(0xFF2DD4BF); // brighter teal for dark accents
  static const dPrimaryTint = Color(0xFF0B2E2A); // subtle teal — active nav (dark)
  static const dSecondary = Color(0xFF8B6DFF);
  static const dTertiary = Color(0xFF6366F1);
  static const dGold = Color(0xFFF59E0B);
}
