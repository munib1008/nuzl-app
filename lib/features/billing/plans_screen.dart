import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/network/api_client.dart';
import '../../core/rbac/persona.dart';
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
    final isAdmin = ref.watch(personaProvider) == Persona.admin;
    return Scaffold(
      appBar: const NuzlAppBar(title: 'Plans'),
      drawer: const NuzlDrawer(),
      floatingActionButton: isAdmin
          ? FloatingActionButton.extended(
              onPressed: () => _planDialog(context, ref),
              icon: const Icon(Icons.add),
              label: const Text('New plan'),
            )
          : null,
      body: ResponsiveCenter(
        child: plans.when(
          loading: () => const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator())),
          error: (e, _) => Center(child: Padding(padding: const EdgeInsets.all(24), child: Text('$e'))),
          data: (list) => ListView(
            padding: const EdgeInsets.all(AppSpacing.x16),
            children: [
              if (isAdmin)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.x8),
                  child: Text('Tap a plan to edit, or “New plan” to add one. Changes are live immediately.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textMuted)),
                ),
              if (list.isEmpty)
                const Padding(padding: EdgeInsets.all(40), child: Center(child: Text('No plans configured.')))
              else
                ...list.map((e) {
                  final p = Map<String, dynamic>.from(e);
                  return _PlanCard(p, onTap: isAdmin ? () => _planDialog(context, ref, existing: p) : null);
                }),
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

  Future<void> _planDialog(BuildContext context, WidgetRef ref, {Map<String, dynamic>? existing}) async {
    final editing = existing != null;
    final key = TextEditingController(text: '${existing?['key'] ?? ''}');
    final name = TextEditingController(text: '${existing?['name'] ?? ''}');
    final price = TextEditingController(text: '${existing?['price_aed'] ?? ''}');
    final seats = TextEditingController(text: '${existing?['seats'] ?? ''}');
    final feats = TextEditingController(
        text: existing?['features'] is List ? (existing!['features'] as List).join(', ') : '');
    var interval = const ['month', 'year'].contains('${existing?['interval']}') ? '${existing!['interval']}' : 'month';

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(editing ? 'Edit plan' : 'New plan'),
        content: StatefulBuilder(
          builder: (ctx, setS) => SizedBox(
            width: 400,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                TextField(
                  controller: key,
                  enabled: !editing, // key is the identity; don't change it on edit
                  decoration: const InputDecoration(labelText: 'Key (e.g. starter)', helperText: 'lowercase, unique'),
                ),
                const SizedBox(height: AppSpacing.x8),
                TextField(controller: name, decoration: const InputDecoration(labelText: 'Name')),
                const SizedBox(height: AppSpacing.x8),
                Row(children: [
                  Expanded(
                    child: TextField(
                      controller: price,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Price (AED)'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.x8),
                  SizedBox(
                    width: 120,
                    child: DropdownButtonFormField<String>(
                      initialValue: interval,
                      decoration: const InputDecoration(labelText: 'Per'),
                      items: const [
                        DropdownMenuItem(value: 'month', child: Text('month')),
                        DropdownMenuItem(value: 'year', child: Text('year')),
                      ],
                      onChanged: (v) => setS(() => interval = v ?? 'month'),
                    ),
                  ),
                ]),
                const SizedBox(height: AppSpacing.x8),
                TextField(
                  controller: seats,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Seats', helperText: 'blank = unlimited'),
                ),
                const SizedBox(height: AppSpacing.x8),
                TextField(
                  controller: feats,
                  maxLines: 3,
                  decoration: const InputDecoration(
                      labelText: 'Features', helperText: 'comma-separated, e.g. 10 users, Full CRM, Reports'),
                ),
              ]),
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
        ],
      ),
    );
    if (ok != true) return;
    if (key.text.trim().isEmpty || name.text.trim().isEmpty) return;
    try {
      await ref.read(apiClientProvider).post('/plans', body: {
        'key': key.text.trim(),
        'name': name.text.trim(),
        'price_aed': num.tryParse(price.text.trim()) ?? 0,
        'interval': interval,
        'seats': int.tryParse(seats.text.trim()),
        'features': feats.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList(),
      });
      ref.invalidate(plansProvider);
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Plan saved')));
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard(this.plan, {this.onTap});
  final Map<String, dynamic> plan;
  final VoidCallback? onTap;

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
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.rCard),
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
                  if (onTap != null) ...[
                    const SizedBox(width: AppSpacing.x8),
                    const Icon(Icons.edit_outlined, size: 18, color: AppColors.textMuted),
                  ],
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
      ),
    );
  }
}
