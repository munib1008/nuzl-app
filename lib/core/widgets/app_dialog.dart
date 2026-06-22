import 'package:flutter/material.dart';
import '../theme/app_spacing.dart';

/// DS 3.0 dialog wrapper: width-capped on wide/desktop web and vertically
/// scrollable + keyboard-safe on short screens, so popups never render
/// off-screen or overflow. Replaces ad-hoc `AlertDialog(content: Column(...))`.
///
/// Usage:
/// ```dart
/// final ok = await AppDialog.show<bool>(
///   context,
///   title: 'New organization',
///   children: [ TextField(...), const SizedBox(height: AppSpacing.x12), Dropdown(...) ],
///   actions: [
///     TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
///     FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Create')),
///   ],
/// );
/// ```
class AppDialog extends StatelessWidget {
  const AppDialog({
    super.key,
    required this.title,
    required this.children,
    this.actions = const [],
    this.maxWidth = 440,
  });

  final String title;
  final List<Widget> children;
  final List<Widget> actions;
  final double maxWidth;

  static Future<T?> show<T>(
    BuildContext context, {
    required String title,
    required List<Widget> children,
    List<Widget> actions = const [],
    double maxWidth = 440,
    bool barrierDismissible = true,
  }) {
    return showDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      // CRITICAL: must stay false. Authed screens live under go_router's
      // ShellRoute (a nested Navigator). Callers close these dialogs with
      // `Navigator.pop(context, value)` using the *screen* context, which
      // resolves to that shell navigator (rootNavigator:false). If the dialog
      // were pushed on the root navigator (the showDialog default), that pop
      // would pop the page instead of the dialog — blanking the screen and
      // leaving the dialog's future unresolved, so the submit code after
      // `await AppDialog.show` never ran. Showing the dialog on the same
      // navigator the buttons pop keeps push/pop consistent. Do not flip back.
      useRootNavigator: false,
      builder: (_) => AppDialog(
        title: title,
        actions: actions,
        maxWidth: maxWidth,
        children: children,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    // Never exceed the viewport (leaves room for the on-screen keyboard).
    final maxHeight = (media.size.height - media.viewInsets.bottom - 96).clamp(160.0, 720.0);
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.rCard)),
      titlePadding: const EdgeInsets.fromLTRB(AppSpacing.x24, AppSpacing.x24, AppSpacing.x24, AppSpacing.x12),
      contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.x24),
      actionsPadding: const EdgeInsets.fromLTRB(AppSpacing.x16, AppSpacing.x8, AppSpacing.x16, AppSpacing.x16),
      title: Text(title),
      content: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth, maxHeight: maxHeight),
        child: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
        ),
      ),
      actions: actions.isEmpty ? null : actions,
    );
  }
}
