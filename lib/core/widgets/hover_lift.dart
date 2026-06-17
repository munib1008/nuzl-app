import 'package:flutter/material.dart';

/// Premium hover affordance for web: lifts the child a few px on pointer hover
/// (translateY) and shows the click cursor. A no-op on touch platforms.
class HoverLift extends StatefulWidget {
  const HoverLift({super.key, required this.child, this.lift = 4});
  final Widget child;
  final double lift;

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
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
        transform: Matrix4.translationValues(0, _hover ? -widget.lift : 0, 0),
        child: widget.child,
      ),
    );
  }
}
