import 'package:flutter/material.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/theme/app_spacing.dart';
import '../shell/app_shell.dart';

/// Friendly placeholder for sections on the roadmap (keeps nav from dead-ending).
class StubScreen extends StatelessWidget {
  const StubScreen({super.key, required this.title});
  final String title;
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: NuzlAppBar(title: title),
      drawer: const NuzlDrawer(),
      body: Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.x24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.construction_outlined, size: 48, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: AppSpacing.x16),
          Text(title, style: t.headlineSmall, textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.x8),
          Text(context.tr('This section is coming soon. The backend is ready — the screen is on the way.'),
              style: t.bodyMedium?.copyWith(color: Theme.of(context).hintColor),
              textAlign: TextAlign.center),
        ]),
      ),
    ));
  }
}
