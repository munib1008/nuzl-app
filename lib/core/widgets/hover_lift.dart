import 'package:flutter/material.dart';

/// Premium hover affordance for web: on pointer hover the child lifts a few px
/// (translateY) and scales up a hair (1.01) with the click cursor — the combined
/// motion reads as depth, not decoration. A no-op on touch platforms.
class HoverLift extends StatefulWidget {
  const HoverLift({super.key, required this.child, this.lift = 3, this.hoverScale = 1.01});
  final Widget child;
  final double lift;
  final double hoverScale;

  @override
  State<HoverLift> createState() => _HoverLiftState();
}

class _HoverLiftState extends State<HoverLift> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    // Scale on the diagonal + raise via the translation column — both set with
    // non-deprecated constructors. transformAlignment pins the pivot to centre
    // so the card grows in place instead of drifting.
    final transform = _hover
        ? (Matrix4.diagonal3Values(widget.hoverScale, widget.hoverScale, 1.0)
          ..setTranslationRaw(0, -widget.lift, 0))
        : Matrix4.identity();
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        transform: transform,
        transformAlignment: Alignment.center,
        child: widget.child,
      ),
    );
  }
}
