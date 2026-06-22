import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';

final profileCompletionProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async =>
    Map<String, dynamic>.from(await ref.read(apiClientProvider).get('/users/me/profile-completion')));

/// Soft nudge: shows how complete the profile is + what's missing. Renders
/// nothing when the profile is complete (or the check fails).
class ProfileCompletionBanner extends ConsumerWidget {
  const ProfileCompletionBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.watch(profileCompletionProvider);
    return c.maybeWhen(
      data: (d) {
        if (d['complete'] == true) return const SizedBox.shrink();
        final pct = d['pct'] is int ? d['pct'] : int.tryParse('${d['pct']}') ?? 0;
        final missing = (d['missing'] is List) ? (d['missing'] as List).join(', ') : '';
        final t = Theme.of(context).textTheme;
        return Card(
          color: AppColors.warning.withValues(alpha: 0.10),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.x16),
            child: Row(children: [
              const Icon(Icons.info_outline, color: AppColors.warning),
              const SizedBox(width: AppSpacing.x12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${context.tr('Profile')} $pct% ${context.tr('complete')}', style: t.titleSmall),
                  if (missing.isNotEmpty)
                    Text('${context.tr('Add')}: $missing', style: t.bodySmall?.copyWith(color: AppColors.textMuted)),
                ]),
              ),
            ]),
          ),
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }
}
