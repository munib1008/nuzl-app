import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

class StatusBadge extends StatelessWidget {
  const StatusBadge(this.label, {super.key, this.tone = BadgeTone.neutral});
  final String label;
  final BadgeTone tone;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (tone) {
      BadgeTone.success => (AppColors.success.withOpacity(.12), AppColors.success),
      BadgeTone.warning => (AppColors.warning.withOpacity(.14), AppColors.warning),
      BadgeTone.danger => (AppColors.danger.withOpacity(.12), AppColors.danger),
      BadgeTone.gold => (AppColors.accentGoldTint, AppColors.accentGold),
      BadgeTone.neutral => (Theme.of(context).colorScheme.surface, AppColors.textMuted),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x8, vertical: AppSpacing.x4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppSpacing.rSm),
      ),
      child: Text(label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(color: fg)),
    );
  }
}

enum BadgeTone { neutral, success, warning, danger, gold }
