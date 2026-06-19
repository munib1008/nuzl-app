import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/empty_state.dart';
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
      body: ResponsiveCenter(
        child: portfolios.when(
          loading: () => const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator())),
          error: (e, _) => Center(child: Padding(padding: const EdgeInsets.all(24), child: Text('$e'))),
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
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
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
      error: (e, _) => Padding(padding: const EdgeInsets.all(24), child: Text('$e')),
      data: (m) {
        final totals = m['totals'] is Map ? Map<String, dynamic>.from(m['totals']) : <String, dynamic>{};
        final properties = m['properties'] is List ? (m['properties'] as List) : const [];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: AppSpacing.x12,
              crossAxisSpacing: AppSpacing.x12,
              childAspectRatio: 1.6,
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
    return Card(
      child: ListTile(
        leading: const Icon(Icons.home_outlined),
        title: Text([p['community'], p['property_type']]
            .where((x) => x != null && '$x'.isNotEmpty)
            .join('  ·  ')),
        subtitle: Text('Equity ${_money(p['equity'])}'),
        trailing: yield_ == null
            ? null
            : Text('${(num.tryParse('$yield_') ?? 0).toStringAsFixed(1)}%',
                style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.primary)),
      ),
    );
  }
}
