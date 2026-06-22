import 'package:flutter/material.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';

/// Status ribbons derived from a listing map (design): Verified, Exclusive,
/// Hot deal, Price reduced, New. Renders nothing when none apply.
class ListingRibbons extends StatelessWidget {
  const ListingRibbons({super.key, required this.listing, this.spacing = 6});
  final Map<String, dynamic> listing;
  final double spacing;

  List<(String, Color)> _specs() {
    final out = <(String, Color)>[];
    if ('${listing['ownership_status'] ?? ''}' == 'verified') out.add(('Verified', AppColors.success));
    if (listing['is_exclusive'] == true) out.add(('Exclusive', AppColors.primary));
    if (listing['is_hot_deal'] == true) out.add(('Hot deal', AppColors.danger));
    final price = num.tryParse('${listing['price']}') ?? 0;
    final orig = num.tryParse('${listing['original_price']}') ?? 0;
    if (orig > 0 && price > 0 && price < orig) out.add(('Price reduced', AppColors.info));
    final created = DateTime.tryParse('${listing['created_at'] ?? ''}');
    if (created != null && DateTime.now().difference(created).inDays <= 7) out.add(('New', AppColors.warning));
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final specs = _specs();
    if (specs.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: spacing,
      runSpacing: 4,
      children: [
        for (final (label, color) in specs)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(AppSpacing.rFull),
            ),
            child: Text(context.tr(label),
                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
          ),
      ],
    );
  }
}
