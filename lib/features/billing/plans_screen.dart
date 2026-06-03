import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/responsive.dart';
import '../shell/app_shell.dart';

final plansProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  try {
    final d = await ref.read(apiClientProvider).get('/plans');
    return d is List ? d : [];
  } catch (_) {
    return [];
  }
});

class PlansScreen extends ConsumerWidget {
  const PlansScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plans = ref.watch(plansProvider);
    return Scaffold(
      appBar: const NuzlAppBar(title: 'Plans'),
      drawer: const NuzlDrawer(),
      body: ResponsiveCenter(
        child: plans.when(
          loading: () => const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator())),
          error: (e, _) => Center(child: Padding(padding: const EdgeInsets.all(24), child: Text('$e'))),
          data: (list) => list.isEmpty
              ? const Center(child: Padding(padding: EdgeInsets.all(40), child: Text('No plans configured.')))
              : ListView(
                  padding: const EdgeInsets.all(AppSpacing.x16),
                  children: [
                    ...list.map((e) => _PlanCard(Map<String, dynamic>.from(e))),
                    const SizedBox(height: AppSpacing.x8),
                    const Card(
                      child: ListTile(
                        leading: Icon(Icons.lock_outline),
                        title: Text('Checkout & payment'),
                        subtitle: Text('Online checkout is coming soon (TODO).'),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard(this.plan);
  final Map<String, dynamic> plan;

  List<String> get _features {
    final f = plan['features'];
    if (f is List) return f.map((e) => '$e').toList();
    if (f is Map) return f.entries.where((e) => e.value == true).map((e) => '${e.key}').toList();
    return const [];
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final price = num.tryParse('${plan['price_aed']}') ?? 0;
    final money = NumberFormat.currency(symbol: 'AED ', decimalDigits: 0).format(price);
    final interval = '${plan['interval'] ?? 'month'}';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.x16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: Text('${plan['name'] ?? plan['key'] ?? 'Plan'}', style: t.titleLarge)),
                Text('$money / $interval',
                    style: t.titleMedium?.copyWith(color: AppColors.primary, fontWeight: FontWeight.w700)),
              ],
            ),
            if (plan['seats'] != null) ...[
              const SizedBox(height: AppSpacing.x4),
              Text('${plan['seats']} seats', style: t.bodySmall?.copyWith(color: Theme.of(context).hintColor)),
            ],
            if (_features.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.x12),
              ..._features.map((f) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(children: [
                      const Icon(Icons.check, size: 16, color: AppColors.primary),
                      const SizedBox(width: AppSpacing.x8),
                      Expanded(child: Text(f, style: t.bodyMedium)),
                    ]),
                  )),
            ],
          ],
        ),
      ),
    );
  }
}
