import 'package:flutter/material.dart';

/// NUZL brand — "Real Estate Operating System".
/// Palette: ink #172B36 · teal #114C5A · gold #FFC801 · orange #FF9932 ·
/// mist #D9E8E2 · canvas #F1F6F4. Ink is the primary structure/button colour,
/// teal is secondary/links, gold is the accent/CTA pop. Token NAMES are kept
/// stable so every screen reflows automatically to the new brand.
class AppColors {
  // ── Brand ──
  static const primary = Color(0xFF172B36);      // ink — primary buttons / nav / structure
  static const primaryHover = Color(0xFF0F1E26);
  static const primaryDark = Color(0xFF0C171E);
  static const primaryTint = Color(0xFFE5ECEF);  // subtle ink tint — active nav (light)
  static const primaryBright = Color(0xFF24414F);
  static const secondary = Color(0xFF114C5A);    // teal — links / secondary
  static const accentGold = Color(0xFFC8960A);   // readable gold — accent text/icons
  static const accentGoldTint = Color(0xFFFFF4CC);
  static const accentCream = Color(0xFFF1F6F4);  // canvas
  static const accentPlum = Color(0xFF114C5A);   // (legacy slot) → teal

  // ── Brand gradient (ink → teal) — logo no longer uses it; kept for GradientButton ──
  static const gradientStart = Color(0xFF172B36);
  static const gradientEnd = Color(0xFF114C5A);
  static List<Color> brandGradient([bool dark = false]) => const [gradientStart, gradientEnd];

  // ── Semantic ──
  static const success = Color(0xFF157A4B);
  static const warning = Color(0xFFFF9932);      // orange
  static const danger = Color(0xFFC0392B);
  static const info = Color(0xFF114C5A);

  // ── Light neutrals ──
  static const bg = Color(0xFFF1F6F4);           // canvas
  static const surface = Color(0xFFFFFFFF);      // cards + sidebar
  static const surface2 = Color(0xFFE8EFEC);
  static const border = Color(0xFFD9E8E2);       // mist
  static const borderStrong = Color(0xFFC2D6CE);
  static const text = Color(0xFF172B36);         // ink
  static const textMuted = Color(0xFF5A6B73);
  static const textSubtle = Color(0xFF8A9BA2);

  // ── Dark neutrals (ink-based) ──
  static const dBg = Color(0xFF0C171E);
  static const dSurface = Color(0xFF172B36);     // sidebar + app bars
  static const dSurface2 = Color(0xFF1E343F);    // cards
  static const dBorder = Color(0xFF2A3F49);
  static const dBorderStrong = Color(0xFF3A4F59);
  static const dText = Color(0xFFF1F6F4);
  static const dTextMuted = Color(0xFFA9BCC2);
  static const dTextSubtle = Color(0xFF7A8D94);
  static const dPrimary = Color(0xFF3E8094);     // brighter teal for dark accents
  static const dPrimaryTint = Color(0xFF14333C); // subtle teal — active nav (dark)
  static const dSecondary = Color(0xFFFFC801);   // gold accent in dark
  static const dTertiary = Color(0xFFFF9932);
  static const dGold = Color(0xFFFFC801);
}
