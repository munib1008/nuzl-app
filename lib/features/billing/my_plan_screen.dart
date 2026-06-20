import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/async_view.dart';
import '../shell/app_shell.dart';
import 'entitlements_repository.dart';

/// Customer-facing plan & billing screen: shows the current plan, what it
/// unlocks, and the upgrade options (from the live plan catalogue).
class MyPlanScreen extends ConsumerWidget {
  const MyPlanScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ent = ref.watch(entitlementsProvider);
    return Scaffold(
      appBar: const NuzlAppBar(title: 'Plan & billing'),
      drawer: const NuzlDrawer(),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(entitlementsProvider),
        child: AsyncView<Entitlements>(
          value: ent,
          onRetry: () => ref.invalidate(entitlementsProvider),
          data: (e) => ListView(
            padding: const EdgeInsets.all(AppSpacing.x16),
            children: [
              _CurrentPlanCard(e),
              const SizedBox(height: AppSpacing.x20),
              Text('All plans', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: AppSpacing.x8),
              for (final p in (e.allPlans..sort((a, b) => a.rank.compareTo(b.rank))))
                _PlanCard(p, current: p.key == e.plan),
              if (!e.enforced) ...[
                const SizedBox(height: AppSpacing.x12),
                Text(
                  'You currently have full access while we finish billing setup. '
                  'Plan limits will apply once billing goes live.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _CurrentPlanCard extends StatelessWidget {
  const _CurrentPlanCard(this.e);
  final Entitlements e;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Card(
      color: AppColors.primary,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.x20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.workspace_premium, color: Colors.white, size: 20),
            const SizedBox(width: AppSpacing.x8),
            Text('Current plan', style: t.bodySmall?.copyWith(color: Colors.white70)),
          ]),
          const SizedBox(height: AppSpacing.x4),
          Text(e.planName, style: t.headlineSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
          Text(
            e.priceAed > 0 ? '${NumberFormat.decimalPattern().format(e.priceAed)} AED / month' : 'Free',
            style: t.bodyMedium?.copyWith(color: Colors.white70),
          ),
        ]),
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard(this.p, {required this.current});
  final PlanOption p;
  final bool current;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final price = p.priceAed > 0
        ? '${NumberFormat.decimalPattern().format(p.priceAed)} AED/mo'
        : (p.key == 'enterprise' ? 'Custom' : 'Free');
    return Card(
      shape: current
          ? RoundedRectangleBorder(
              side: const BorderSide(color: AppColors.primary, width: 1.5),
              borderRadius: BorderRadius.circular(AppSpacing.x20))
          : null,
      margin: const EdgeInsets.only(bottom: AppSpacing.x12),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.x16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(p.name, style: t.titleMedium)),
            if (current)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                    color: AppColors.primaryTint, borderRadius: BorderRadius.circular(AppSpacing.rFull)),
                child: Text('Current', style: t.labelSmall?.copyWith(color: AppColors.primary, fontWeight: FontWeight.w700)),
              )
            else
              Text(price, style: t.titleSmall?.copyWith(color: AppColors.primary)),
          ]),
          if (!current) Text(price, style: t.bodySmall?.copyWith(color: AppColors.textMuted)),
          const SizedBox(height: AppSpacing.x12),
          for (final f in p.features)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.x4),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Icon(Icons.check_circle_outline, size: 16, color: AppColors.success),
                const SizedBox(width: AppSpacing.x8),
                Expanded(child: Text(featureLabel(f), style: t.bodyMedium)),
              ]),
            ),
          if (!current) ...[
            const SizedBox(height: AppSpacing.x12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => _enquire(context),
                child: Text(p.key == 'enterprise' ? 'Contact sales' : 'Upgrade to ${p.name}'),
              ),
            ),
          ],
        ]),
      ),
    );
  }

  void _enquire(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Upgrade to ${p.name}'),
        content: const Text(
            'Our team will reach out to set up your plan and billing. In the meantime you keep full access.'),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
      ),
    );
  }
}
