/// Spacing (4px base), radii, motion — from NUZL_Design_System.md (§4).
class AppSpacing {
  static const double x2 = 2, x4 = 4, x8 = 8, x12 = 12, x16 = 16,
      x20 = 20, x24 = 24, x32 = 32, x40 = 40, x48 = 48, x64 = 64;

  // radius
  static const double rSm = 6, rMd = 10, rLg = 14, rXl = 20, rFull = 9999;
  // design-system radii: cards/inputs 16, buttons 14
  static const double rButton = 14, rCard = 16;

  // tap target
  static const double tapTarget = 44;

  // motion (ms) — standard transition 200–300ms
  static const int durFast = 150, durBase = 200, durSlow = 250, durStd = 250;
}
