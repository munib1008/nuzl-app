import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Primary CTA with the fixed brand gradient (#00C2A8 → #6D4AFF).
/// Flat 8px radius, no pill. Use for the most prominent primary actions.
class GradientButton extends StatelessWidget {
  const GradientButton({
    super.key,
    required this.onPressed,
    required this.label,
    this.icon,
    this.expand = false,
  });
  final VoidCallback? onPressed;
  final String label;
  final IconData? icon;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final inner = DecoratedBox(
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [AppColors.gradientStart, AppColors.gradientEnd]),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[Icon(icon, size: 18, color: Colors.white), const SizedBox(width: 8)],
                Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
              ],
            ),
          ),
        ),
      ),
    );
    final child = Opacity(opacity: enabled ? 1 : 0.5, child: inner);
    return expand ? SizedBox(width: double.infinity, child: child) : child;
  }
}
