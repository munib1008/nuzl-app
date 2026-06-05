import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';

/// NUZL logo lockup — the flowing-"n" mark + "nuzl" wordmark.
/// FIXED brand gradient (#00C2A8 → #6D4AFF), never recoloured by theme.
class NuzlLogo extends StatelessWidget {
  const NuzlLogo({super.key, this.size = 48, this.showWordmark = true, this.color});
  final double size;
  final bool showWordmark;
  final Color? color; // ignored — logo colour is fixed (kept for call-site compatibility)

  @override
  Widget build(BuildContext context) {
    final lockup = Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SvgPicture.asset(
          'assets/logo/nuzl_mark.svg',
          width: size,
          height: size,
          colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
        ),
        if (showWordmark) ...[
          SizedBox(width: size * 0.06),
          Text(
            'nuzl',
            style: GoogleFonts.inter(
              fontSize: size * 0.74,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ],
    );
    // Paint the white lockup with the fixed brand gradient.
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (rect) => const LinearGradient(
        colors: [AppColors.gradientStart, AppColors.gradientEnd],
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
      ).createShader(rect),
      child: lockup,
    );
  }
}
