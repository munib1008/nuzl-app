import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// A network image that gently zooms on hover (desktop) — the Airbnb/Bayut
/// "photo comes alive" feel. Uses AnimatedScale (a Transform, NOT a saveLayer),
/// so there's no Flutter-web grey-box artifact. Clip it via the parent.
class HoverZoomImage extends StatefulWidget {
  const HoverZoomImage({super.key, required this.url, this.placeholder, this.scale = 1.06});
  final String url;
  final Widget? placeholder;
  final double scale;

  @override
  State<HoverZoomImage> createState() => _HoverZoomImageState();
}

class _HoverZoomImageState extends State<HoverZoomImage> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final ph = widget.placeholder ?? Container(color: AppColors.surface2);
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedScale(
        scale: _hover ? widget.scale : 1.0,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOut,
        child: Image.network(
          widget.url,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          loadingBuilder: (c, child, p) => p == null ? child : Container(color: AppColors.surface2),
          errorBuilder: (_, __, ___) => ph,
        ),
      ),
    );
  }
}
