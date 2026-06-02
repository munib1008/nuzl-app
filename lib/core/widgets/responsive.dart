import 'package:flutter/material.dart';

/// Centers content with a comfortable max width on wide screens, full-width on
/// mobile — so the web app reads like a native app on every device.
class ResponsiveCenter extends StatelessWidget {
  const ResponsiveCenter({super.key, required this.child, this.maxWidth = 640, this.padding});
  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry? padding;
  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Padding(padding: padding ?? EdgeInsets.zero, child: child),
        ),
      );
}
