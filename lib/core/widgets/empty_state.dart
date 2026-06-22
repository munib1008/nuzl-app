import 'package:flutter/material.dart';
import '../theme/app_spacing.dart';

/// Design-system empty state: a friendly dashed-border card with icon + purpose
/// + next step + one action (§9). The dashed card reads as "intentionally empty,
/// here's what to do" rather than a blank screen.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.x24),
        child: CustomPaint(
          painter: _DashedRRectPainter(
            color: Theme.of(context).dividerColor,
            radius: AppSpacing.rCard,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 240, maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.x32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 40, color: c.primary),
                  const SizedBox(height: AppSpacing.x16),
                  Text(title, style: t.titleMedium, textAlign: TextAlign.center),
                  const SizedBox(height: AppSpacing.x8),
                  Text(message, style: t.bodySmall, textAlign: TextAlign.center),
                  if (actionLabel != null) ...[
                    const SizedBox(height: AppSpacing.x24),
                    FilledButton(onPressed: onAction, child: Text(actionLabel!)),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Draws a dashed rounded-rectangle border at the child's size — no package.
class _DashedRRectPainter extends CustomPainter {
  _DashedRRectPainter({required this.color, required this.radius});
  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final rrect = RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius));
    final source = Path()..addRRect(rrect);
    const dash = 6.0, gap = 5.0;
    for (final metric in source.computeMetrics()) {
      var dist = 0.0;
      while (dist < metric.length) {
        final next = dist + dash;
        canvas.drawPath(metric.extractPath(dist, next.clamp(0, metric.length)), paint);
        dist = next + gap;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedRRectPainter old) => old.color != color || old.radius != radius;
}
