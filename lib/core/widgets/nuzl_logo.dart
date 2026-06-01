import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';

/// NUZL logo lockup: the flowing-"n" mark + "nuzl" wordmark in Poppins.
/// Tints to the brand emerald (light) or a lifted teal/white (dark) automatically.
class NuzlLogo extends StatelessWidget {
  const NuzlLogo({super.key, this.size = 48, this.showWordmark = true, this.color});
  final double size;
  final bool showWordmark;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final markColor = color ?? (dark ? AppColors.dPrimary : AppColors.primary);
    final wordColor = color ?? (dark ? Colors.white : AppColors.secondary);

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SvgPicture.asset(
          'assets/logo/nuzl_mark.svg',
          width: size,
          height: size,
          colorFilter: ColorFilter.mode(markColor, BlendMode.srcIn),
        ),
        if (showWordmark) ...[
          SizedBox(width: size * 0.18),
          Text(
            'nuzl',
            style: GoogleFonts.poppins(
              fontSize: size * 0.78,
              fontWeight: FontWeight.w600,
              color: wordColor,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ],
    );
  }
}
