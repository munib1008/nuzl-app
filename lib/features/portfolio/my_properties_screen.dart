import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/app_dialog.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/place_field.dart';
import '../../core/widgets/responsive.dart';
import '../shell/app_shell.dart';

final _portfoliosProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  try {
    final d = await ref.read(apiClientProvider).get('/portfolio');
    return d is List ? d : [];
  } catch (_) {
    return [];
  }
});

final _selectedPortfolioProvider = StateProvider.autoDispose<String?>((ref) => null);

final _overviewProvider = FutureProvider.autoDispose.family<Map<String, dynamic>, String>((ref, id) async {
  try {
    final d = await ref.read(apiClientProvider).get('/portfolio/$id/overview');
    return d is Map ? Map<String, dynamic>.from(d) : <String, dynamic>{};
  } catch (_) {
    return <String, dynamic>{};
  }
});

String _money(dynamic v) {
  final n = v is num ? v : num.tryParse('${v ?? ''}');
  if (n == null) return '—';
  return NumberFormat.compactCurrency(symbol: 'AED ', decimalDigits: 0).format(n);
}

class MyPropertiesScreen extends ConsumerWidget {
  const MyPropertiesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final portfolios = ref.watch(_portfoliosProvider);
    final selected = ref.watch(_selectedPortfolioProvider);
    return Scaffold(
      appBar: const NuzlAppBar(title: 'My Properties'),
      drawer: const NuzlDrawer(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addProperty(context, ref),
        icon: const Icon(Icons.add_home_outlined),
        label: const Text('Add property'),
      ),
      body: ResponsiveCenter(
        child: portfolios.when(
          loading: () => const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator())),
          error: (e, _) => Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(friendlyError(e)))),
          data: (list) {
            if (list.isEmpty) {
              return EmptyState(
                icon: Icons.home_work_outlined,
                title: 'No portfolio yet',
                message: 'Create a portfolio to track your owned properties and returns.',
                actionLabel: 'Create portfolio',
                onAction: () => _create(context, ref),
              );
            }
            final ids = list.map((e) => '${(e as Map)['id']}').toList();
            final active = (selected != null && ids.contains(selected)) ? selected : ids.first;
            return ListView(
              padding: const EdgeInsets.all(AppSpacing.x16),
              children: [
                if (list.length > 1) ...[
                  DropdownButtonFormField<String>(
                    initialValue: active,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Portfolio'),
                    items: list.map((e) {
                      final m = Map<String, dynamic>.from(e);
                      return DropdownMenuItem(value: '${m['id']}', child: Text('${m['name'] ?? 'Portfolio'}'));
                    }).toList(),
                    onChanged: (v) => ref.read(_selectedPortfolioProvider.notifier).state = v,
                  ),
                  const SizedBox(height: AppSpacing.x16),
                ],
                _Overview(portfolioId: active),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(apiClientProvider).post('/portfolio', body: {'name': 'My Portfolio'});
      ref.invalidate(_portfoliosProvider);
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
    }
  }

  /// Owner adds a property RECORD they own (creates the asset + links it to their
  /// portfolio). No public listing is created — they assign an agent on the
  /// property workspace, and the agent publishes it.
  Future<void> _addProperty(BuildContext context, WidgetRef ref) async {
    final building = TextEditingController();
    final unit = TextEditingController();
    final beds = TextEditingController();
    final baths = TextEditingController();
    final size = TextEditingController();
    final price = TextEditingController();
    var type = 'apartment';
    double? lat, lng;
    final ok = await AppDialog.show<bool>(
      context,
      title: 'Add a property',
      children: [
        StatefulBuilder(
          builder: (ctx, setS) => Column(mainAxisSize: MainAxisSize.min, children: [
            PlaceField(
              controller: building,
              label: 'Building / location',
              onSelected: (p) { lat = p.lat; lng = p.lng; },
              onCleared: () { lat = null; lng = null; },
            ),
            const SizedBox(height: AppSpacing.x8),
            TextField(controller: unit, decoration: const InputDecoration(labelText: 'Unit no.')),
            const SizedBox(height: AppSpacing.x8),
            DropdownButtonFormField<String>(
              initialValue: type,
              decoration: const InputDecoration(labelText: 'Type'),
              items: const [
                DropdownMenuItem(value: 'apartment', child: Text('Apartment')),
                DropdownMenuItem(value: 'villa', child: Text('Villa')),
                DropdownMenuItem(value: 'townhouse', child: Text('Townhouse')),
                DropdownMenuItem(value: 'office', child: Text('Office')),
              ],
              onChanged: (v) => setS(() => type = v ?? 'apartment'),
            ),
            const SizedBox(height: AppSpacing.x8),
            Row(children: [
              Expanded(child: TextField(controller: beds, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Beds'))),
              const SizedBox(width: AppSpacing.x8),
              Expanded(child: TextField(controller: baths, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Baths'))),
            ]),
            const SizedBox(height: AppSpacing.x8),
            Row(children: [
              Expanded(child: TextField(controller: size, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Size (sqft)'))),
              const SizedBox(width: AppSpacing.x8),
              Expanded(child: TextField(controller: price, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Purchase price'))),
            ]),
          ]),
        ),
      ],
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            if (building.text.trim().isEmpty) {
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(const SnackBar(content: Text('Add a building or location.')));
              return;
            }
            Navigator.pop(context, true);
          },
          child: const Text('Add'),
        ),
      ],
    );
    if (ok != true) return;
    try {
      final res = await ref.read(apiClientProvider).post('/portfolio/property', body: {
        'building_name': building.text.trim(),
        'unit_no': unit.text.trim(),
        'property_type': type,
        'bedrooms': int.tryParse(beds.text.trim()),
        'bathrooms': int.tryParse(baths.text.trim()),
        'size_sqft': double.tryParse(size.text.trim()),
        'purchase_price': double.tryParse(price.text.trim()),
        if (lat != null) 'latitude': lat,
        if (lng != null) 'longitude': lng,
      });
      ref.invalidate(_portfoliosProvider);
      ref.invalidate(_overviewProvider);
      final id = res is Map ? '${res['id'] ?? ''}' : '';
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Property added to your portfolio.')));
        if (id.isNotEmpty) context.push('/property/$id');
      }
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
    }
  }
}

class _Overview extends ConsumerWidget {
  const _Overview({required this.portfolioId});
  final String portfolioId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ov = ref.watch(_overviewProvider(portfolioId));
    return ov.when(
      loading: () => const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator())),
      error: (e, _) => Padding(padding: const EdgeInsets.all(24), child: Text(friendlyError(e))),
      data: (m) {
        final totals = m['totals'] is Map ? Map<String, dynamic>.from(m['totals']) : <String, dynamic>{};
        final properties = m['properties'] is List ? (m['properties'] as List) : const [];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GridView(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: AppSpacing.x12,
                crossAxisSpacing: AppSpacing.x12,
                mainAxisExtent: 104,
              ),
              children: [
                _Stat('Market value', _money(totals['market_value'])),
                _Stat('Equity', _money(totals['equity'])),
                _Stat('Net operating income', _money(totals['net_operating_income'])),
                _Stat('Outstanding debt', _money(totals['outstanding_debt'])),
              ],
            ),
            const SizedBox(height: AppSpacing.x24),
            Text('Properties', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppSpacing.x8),
            if (properties.isEmpty)
              Text('No properties in this portfolio yet.',
                  style: TextStyle(color: Theme.of(context).hintColor))
            else
              ...properties.map((e) => _PropCard(Map<String, dynamic>.from(e))),
          ],
        );
      },
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value);
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.x16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(value, style: t.titleLarge?.copyWith(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w700)),
            const SizedBox(height: AppSpacing.x4),
            Text(label, style: t.bodySmall?.copyWith(color: Theme.of(context).hintColor)),
          ],
        ),
      ),
    );
  }
}

class _PropCard extends StatelessWidget {
  const _PropCard(this.p);
  final Map<String, dynamic> p;
  @override
  Widget build(BuildContext context) {
    final yield_ = p['net_yield_pct'];
    final pid = '${p['property_id'] ?? ''}'.trim();
    return Card(
      child: ListTile(
        leading: const Icon(Icons.home_outlined),
        title: Text([p['community'], p['property_type']]
            .where((x) => x != null && '$x'.isNotEmpty)
            .join('  ·  ')),
        subtitle: Text('Equity ${_money(p['equity'])}'),
        // Open the full property record hub (lease, mortgage, maintenance, docs, timeline).
        onTap: pid.isEmpty ? null : () => context.push('/property/$pid'),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          if (yield_ != null)
            Text('${(num.tryParse('$yield_') ?? 0).toStringAsFixed(1)}%',
                style: TextStyle(fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurface)),
          if (pid.isNotEmpty)
            const Padding(padding: EdgeInsets.only(left: 4), child: Icon(Icons.chevron_right, size: 18)),
        ]),
      ),
    );
  }
}
