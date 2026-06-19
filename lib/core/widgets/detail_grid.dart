import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// A sensible icon for a common property-detail label, for the DetailGrid.
IconData detailIcon(String label) {
  switch (label.toLowerCase()) {
    case 'type':
      return Icons.home_work_outlined;
    case 'bedrooms':
      return Icons.bed_outlined;
    case 'bathrooms':
      return Icons.bathtub_outlined;
    case 'size':
    case 'sq ft':
      return Icons.straighten;
    case 'furnishing':
      return Icons.chair_outlined;
    case 'developer':
      return Icons.domain_outlined;
    case 'view':
      return Icons.visibility_outlined;
    case 'parking':
      return Icons.local_parking_outlined;
    case 'service charge':
      return Icons.receipt_long_outlined;
    case 'handover':
      return Icons.event_available_outlined;
    case 'community':
      return Icons.location_city_outlined;
    case 'building':
      return Icons.apartment_outlined;
    case 'unit':
      return Icons.meeting_room_outlined;
    case 'status':
      return Icons.verified_outlined;
    default:
      return Icons.info_outline;
  }
}

/// A responsive, distributed grid of detail items (icon + label + bold value) —
/// the balanced "Highlights" presentation used on premium property pages, vs a
/// flat vertical key/value list. Wraps to 2–3 columns by available width.
class DetailGrid extends StatelessWidget {
  const DetailGrid({super.key, required this.items});

  /// Each item: (icon, label, value).
  final List<(IconData, String, String)> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    final t = Theme.of(context).textTheme;
    final muted = Theme.of(context).brightness == Brightness.dark
        ? AppColors.dTextMuted
        : AppColors.textMuted;
    final accent = Theme.of(context).colorScheme.primary;
    return LayoutBuilder(builder: (ctx, c) {
      final cols = c.maxWidth >= 560 ? 3 : (c.maxWidth >= 340 ? 2 : 1);
      final w = (c.maxWidth - (cols - 1) * AppSpacing.x16) / cols;
      return Wrap(
        spacing: AppSpacing.x16,
        runSpacing: AppSpacing.x16,
        children: [
          for (final it in items)
            SizedBox(
              width: w,
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(it.$1, size: 20, color: accent),
                const SizedBox(width: AppSpacing.x8),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                    Text(it.$2, style: t.bodySmall?.copyWith(color: muted)),
                    Text(it.$3,
                        style: t.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
                        maxLines: 2, overflow: TextOverflow.ellipsis),
                  ]),
                ),
              ]),
            ),
        ],
      );
    });
  }
}
