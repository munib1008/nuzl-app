import 'package:flutter/material.dart';

/// A subtle one-shot fade + slide-up used to make screens feel alive on load.
/// Pass an increasing [delayMs] to stagger a list of items.
class FadeIn extends StatefulWidget {
  const FadeIn({super.key, required this.child, this.delayMs = 0, this.offsetY = 0.06});
  final Widget child;
  final int delayMs;
  final double offsetY;

  @override
  State<FadeIn> createState() => _FadeInState();
}

class _FadeInState extends State<FadeIn> {
  bool _on = false;

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(Duration(milliseconds: widget.delayMs), () {
      if (mounted) setState(() => _on = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    const d = Duration(milliseconds: 420);
    return AnimatedSlide(
      duration: d,
      curve: Curves.easeOutCubic,
      offset: _on ? Offset.zero : Offset(0, widget.offsetY),
      child: AnimatedOpacity(
        duration: d,
        opacity: _on ? 1 : 0,
        child: widget.child,
      ),
    );
  }
}
