import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';

/// NUZL logo lockup — the hexagonal-house mark + "nuzl" wordmark.
/// The mark carries the brand colours (ink hexagon, white house, gold accent);
/// the wordmark is ink on light surfaces and near-white in dark mode.
class NuzlLogo extends StatelessWidget {
  const NuzlLogo({super.key, this.size = 48, this.showWordmark = true, this.color});
  final double size;
  final bool showWordmark;
  final Color? color; // optional wordmark override (the mark keeps its brand colours)

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final wordColor = color ?? (dark ? AppColors.dText : AppColors.primary);
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // The hexagon fill is `currentColor`; drive it from the theme so the mark
        // matches the wordmark (ink on light, near-white on dark). The gold marker
        // stays gold. Without this the ink mark vanishes on dark backgrounds.
        SvgPicture.asset('assets/logo/nuzl_mark.svg',
            width: size, height: size, theme: SvgTheme(currentColor: wordColor)),
        if (showWordmark) ...[
          SizedBox(width: size * 0.16),
          Text(
            'nuzl',
            style: GoogleFonts.poppins(
              fontSize: size * 0.72,
              fontWeight: FontWeight.w600, // matches the brand wordmark (Poppins SemiBold)
              color: wordColor,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ],
    );
  }
}
