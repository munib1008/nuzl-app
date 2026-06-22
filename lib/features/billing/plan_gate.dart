import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import 'entitlements_repository.dart';

/// Premium-feature gate (mirrors [showAuthPrompt] for plans). Returns true when
/// the caller may use [feature]; otherwise shows a graceful "upgrade to unlock"
/// prompt and returns false so the caller aborts — instead of letting the server
/// answer with a raw 403 once `ENFORCE_PLAN_GATES` is on.
///
/// No-op while gates are off (the server default): `enforced == false` → always
/// allowed, so wiring this in changes nothing until enforcement is switched on.
/// Fails OPEN on any error (never blocks a paying flow because a check hiccuped).
Future<bool> ensureEntitled(BuildContext context, WidgetRef ref, String feature) async {
  Entitlements ent;
  try {
    ent = await ref.read(entitlementsProvider.future);
  } catch (_) {
    return true; // fail-open
  }
  if (!ent.enforced || ent.has(feature)) return true;
  if (!context.mounted) return false;
  await showUpgradePrompt(context, ref, feature: feature, entitlements: ent);
  return false;
}

/// The upgrade dialog: names the feature and the cheapest plan that unlocks it,
/// and routes to the plan & billing screen. Educate-and-convert, not a dead end.
Future<void> showUpgradePrompt(
  BuildContext context,
  WidgetRef ref, {
  required String feature,
  Entitlements? entitlements,
}) {
  final ent = entitlements ?? ref.read(entitlementsProvider).asData?.value;
  // Cheapest plan that includes this feature → the natural upgrade target.
  PlanOption? target;
  if (ent != null) {
    final candidates = ent.allPlans.where((p) => p.features.contains(feature)).toList()
      ..sort((a, b) => a.priceAed.compareTo(b.priceAed));
    target = candidates.isNotEmpty ? candidates.first : null;
  }
  final label = featureLabel(feature);
  return showDialog<void>(
    context: context,
    builder: (ctx) {
      final t = Theme.of(ctx).textTheme;
      return Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.rCard)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.x24),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Icon(Icons.workspace_premium_outlined, color: AppColors.primary),
                const SizedBox(width: AppSpacing.x8),
                Expanded(
                  child: Text('Unlock $label', style: t.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                ),
              ]),
              const SizedBox(height: AppSpacing.x8),
              Text(
                target != null
                    ? '$label is included in the ${target.name} plan and above. Upgrade to start using it.'
                    : '$label is available on a higher plan. Upgrade to start using it.',
                style: t.bodyMedium?.copyWith(color: AppColors.textMuted),
              ),
              if (target != null && target.priceAed > 0) ...[
                const SizedBox(height: AppSpacing.x12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x12, vertical: AppSpacing.x8),
                  decoration: BoxDecoration(
                      color: AppColors.primaryTint, borderRadius: BorderRadius.circular(AppSpacing.rFull)),
                  child: Text('${target.name} · ${target.priceAed.toStringAsFixed(0)} AED / month',
                      style: t.labelLarge?.copyWith(color: AppColors.primary, fontWeight: FontWeight.w700)),
                ),
              ],
              const SizedBox(height: AppSpacing.x20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    context.go('/billing');
                  },
                  child: const Text('View plans'),
                ),
              ),
              const SizedBox(height: AppSpacing.x8),
              SizedBox(
                width: double.infinity,
                child: TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Not now')),
              ),
            ]),
          ),
        ),
      );
    },
  );
}
