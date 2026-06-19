import 'package:flutter/material.dart';
import '../theme/app_spacing.dart';

/// A pulsing placeholder block — the premium alternative to a spinner. Composes
/// into card/list skeletons so loading states keep the page's shape.
class SkeletonBox extends StatefulWidget {
  const SkeletonBox({super.key, this.width, this.height = 14, this.radius = 8});
  final double? width;
  final double height;
  final double radius;

  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.35, end: 0.9).animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut)),
      child: Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: Theme.of(context).dividerColor,
          borderRadius: BorderRadius.circular(widget.radius),
        ),
      ),
    );
  }
}

/// A skeleton in the shape of a property card (image + price + meta lines).
class SkeletonListingCard extends StatelessWidget {
  const SkeletonListingCard({super.key, required this.width});
  final double width;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(AppSpacing.rCard),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      clipBehavior: Clip.antiAlias,
      child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        AspectRatio(aspectRatio: 3 / 2, child: SkeletonBox(height: double.infinity, radius: 0)),
        Padding(
          padding: EdgeInsets.all(AppSpacing.x12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SkeletonBox(width: 120, height: 18),
            SizedBox(height: AppSpacing.x8),
            SkeletonBox(width: 180, height: 12),
            SizedBox(height: AppSpacing.x8),
            SkeletonBox(width: 140, height: 12),
          ]),
        ),
      ]),
    );
  }
}

/// Responsive grid of card skeletons that mirrors a listing/result grid.
class SkeletonListingGrid extends StatelessWidget {
  const SkeletonListingGrid({super.key, this.count = 6, this.maxWidth = 1100});
  final int count;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: LayoutBuilder(builder: (ctx, c) {
          final cols = c.maxWidth >= 1120 ? 3 : (c.maxWidth >= 680 ? 2 : 1);
          final cardW = cols == 1 ? c.maxWidth : (c.maxWidth - (cols - 1) * AppSpacing.x16) / cols;
          return Wrap(
            spacing: AppSpacing.x16,
            runSpacing: AppSpacing.x16,
            children: List.generate(count, (_) => SkeletonListingCard(width: cardW)),
          );
        }),
      ),
    );
  }
}
