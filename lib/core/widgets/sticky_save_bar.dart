import 'package:flutter/material.dart';
import '../theme/app_spacing.dart';

/// A primary action button pinned to the bottom of a form. Use it in a
/// Scaffold's `bottomNavigationBar` slot so the scrolling body never overlaps
/// it and — importantly on mobile — it is never hidden behind the app's bottom
/// navigation bar. SafeArea keeps it clear of the gesture/home indicator.
class StickySaveBar extends StatelessWidget {
  const StickySaveBar({
    super.key,
    required this.saving,
    required this.label,
    required this.onPressed,
  });

  final bool saving;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(
          AppSpacing.x16, AppSpacing.x8, AppSpacing.x16, AppSpacing.x12),
      child: SizedBox(
        width: double.infinity,
        child: FilledButton(
          onPressed: saving ? null : onPressed,
          child: saving
              ? const SizedBox(
                  height: 20, width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Text(label),
        ),
      ),
    );
  }
}
