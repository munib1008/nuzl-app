import 'package:flutter/material.dart';

/// Premium hover affordance for web: lifts (scales) the child slightly on pointer
/// hover and shows the click cursor. A no-op on touch platforms (no hover events).
class HoverLift extends StatefulWidget {
  const HoverLift({super.key, required this.child, this.scale = 1.02});
  final Widget child;
  final double scale;

  @override
  State<HoverLift> createState() => _HoverLiftState();
}

class _HoverLiftState extends State<HoverLift> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedScale(
        scale: _hover ? widget.scale : 1.0,
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}
