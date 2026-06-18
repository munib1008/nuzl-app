import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Primary CTA with the fixed brand gradient (#00C2A8 → #6D4AFF).
/// 14px radius + a fixed height so it lines up pixel-for-pixel with sibling
/// OutlinedButtons in a button row.
class GradientButton extends StatelessWidget {
  const GradientButton({
    super.key,
    required this.onPressed,
    required this.label,
    this.icon,
    this.expand = false,
    this.height = 48,
  });
  final VoidCallback? onPressed;
  final String label;
  final IconData? icon;
  final bool expand;
  final double height;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final inner = DecoratedBox(
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [AppColors.gradientStart, AppColors.gradientEnd]),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onPressed,
          child: SizedBox(
            height: height,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
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
      ),
    );
    final child = Opacity(opacity: enabled ? 1 : 0.5, child: inner);
    return expand ? SizedBox(width: double.infinity, child: child) : child;
  }
}
