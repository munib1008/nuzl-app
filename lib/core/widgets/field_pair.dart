import 'package:flutter/material.dart';
import '../theme/app_spacing.dart';

/// Lays two form fields side-by-side on comfortable widths and stacks them
/// vertically on narrow (phone) widths, so long labels, `AED ` prefixes and
/// helper text don't get crushed into ellipsis on a ~360px screen.
///
/// Replaces the common `Row(children: [Expanded(a), gap, Expanded(b)])`
/// pattern — the side-by-side branch adds the Expanded wrappers itself, so
/// pass the bare fields. Default breakpoint 520px: below it a single roomy
/// column reads far better than two squeezed columns.
class FieldPair extends StatelessWidget {
  const FieldPair(
    this.first,
    this.second, {
    super.key,
    this.gap = AppSpacing.x12,
    this.breakpoint = 520,
  });

  final Widget first;
  final Widget second;
  final double gap;
  final double breakpoint;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        if (c.maxWidth < breakpoint) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [first, SizedBox(height: gap), second],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: first),
            SizedBox(width: gap),
            Expanded(child: second),
          ],
        );
      },
    );
  }
}
