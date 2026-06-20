import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Small status pill for a company's verification state (verified / pending /
/// rejected). Use `compact` for an icon-only mark next to a company name.
class VerificationBadge extends StatelessWidget {
  const VerificationBadge(this.status, {super.key, this.compact = false});
  final String status;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final (label, color, icon) = switch (status) {
      'verified' => ('Verified', AppColors.success, Icons.verified),
      'rejected' => ('Not verified', AppColors.danger, Icons.cancel_outlined),
      _ => ('Pending review', AppColors.warning, Icons.hourglass_bottom),
    };
    if (compact) {
      return Icon(icon, size: 16, color: color, semanticLabel: label);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(9999),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 11)),
      ]),
    );
  }
}
