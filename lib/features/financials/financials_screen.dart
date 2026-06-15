import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/app_dialog.dart';
import '../../core/widgets/responsive.dart';
import '../shell/app_shell.dart';

final _propsProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  try {
    final d = await ref.read(apiClientProvider).get('/listings');
    return d is List ? d : [];
  } catch (_) {
    return [];
  }
});

final _selectedPropProvider = StateProvider.autoDispose<String?>((ref) => null);

final _financialsProvider = FutureProvider.autoDispose.family<Map<String, dynamic>, String>((ref, id) async {
  try {
    final d = await ref.read(apiClientProvider).get('/properties/$id/financials');
    return d is Map ? Map<String, dynamic>.from(d) : <String, dynamic>{};
  } catch (_) {
    return <String, dynamic>{};
  }
});

final _txProvider = FutureProvider.autoDispose.family<List<dynamic>, String>((ref, id) async {
  try {
    final d = await ref.read(apiClientProvider).get('/properties/$id/transactions');
    return d is List ? d : [];
  } catch (_) {
    return [];
  }
});

final _eventsProvider = FutureProvider.autoDispose.family<List<dynamic>, String>((ref, id) async {
  try {
    final d = await ref.read(apiClientProvider).get('/properties/$id/events');
    return d is List ? d : [];
  } catch (_) {
    return [];
  }
});

String _money(dynamic v) {
  final n = v is num ? v : num.tryParse('${v ?? ''}');
  if (n == null) return '—';
  return NumberFormat.compactCurrency(symbol: 'AED ', decimalDigits: 0).format(n);
}

class FinancialsScreen extends ConsumerWidget {
  const FinancialsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final props = ref.watch(_propsProvider);
    final selected = ref.watch(_selectedPropProvider);
    return Scaffold(
      appBar: const NuzlAppBar(title: 'Financials'),
      drawer: const NuzlDrawer(),
      body: ResponsiveCenter(
        child: props.when(
          loading: () => const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator())),
          error: (e, _) => Center(child: Padding(padding: const EdgeInsets.all(24), child: Text('$e'))),
          data: (list) {
            final propMap = <String, String>{};
            for (final e in list) {
              final m = Map<String, dynamic>.from(e);
              final pid = '${m['property_id'] ?? m['id']}';
              propMap.putIfAbsent(pid, () => '${m['community'] ?? 'Property'} · ${_money(m['price'])}');
            }
            if (propMap.isEmpty) {
              return const Center(
                  child: Padding(padding: EdgeInsets.all(40), child: Text('No properties to report on yet.')));
            }
            return ListView(
              padding: const EdgeInsets.all(AppSpacing.x16),
              children: [
                DropdownButtonFormField<String>(
                  initialValue: selected,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Property'),
                  items: propMap.entries
                      .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value, overflow: TextOverflow.ellipsis)))
                      .toList(),
                  onChanged: (v) => ref.read(_selectedPropProvider.notifier).state = v,
                ),
                const SizedBox(height: AppSpacing.x16),
                if (selected == null)
                  const Padding(
                    padding: EdgeInsets.all(40),
                    child: Center(child: Text('Pick a property to view its financials.')),
                  )
                else
                  _PropertyFinancials(propertyId: selected),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _PropertyFinancials extends ConsumerWidget {
  const _PropertyFinancials({required this.propertyId});
  final String propertyId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fin = ref.watch(_financialsProvider(propertyId));
    final tx = ref.watch(_txProvider(propertyId));
    final events = ref.watch(_eventsProvider(propertyId));
    final t = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        fin.maybeWhen(
          data: (m) => _SummaryCard(summary: m['summary'] is Map ? Map<String, dynamic>.from(m['summary']) : const {}),
          orElse: () => const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator())),
        ),
        const SizedBox(height: AppSpacing.x24),
        Row(
          children: [
            Expanded(child: Text('Transactions', style: t.titleMedium)),
            TextButton.icon(
              onPressed: () => _addTransaction(context, ref),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add'),
            ),
          ],
        ),
        tx.maybeWhen(
          data: (list) => list.isEmpty
              ? Text('No transactions.', style: t.bodySmall?.copyWith(color: Theme.of(context).hintColor))
              : Column(children: list.map((e) => _ledgerTile(Map<String, dynamic>.from(e), isTx: true)).toList()),
          orElse: () => const LinearProgressIndicator(),
        ),
        const SizedBox(height: AppSpacing.x16),
        Row(
          children: [
            Expanded(child: Text('Ledger events', style: t.titleMedium)),
            TextButton.icon(
              onPressed: () => _addEvent(context, ref),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add'),
            ),
          ],
        ),
        events.maybeWhen(
          data: (list) => list.isEmpty
              ? Text('No ledger events.', style: t.bodySmall?.copyWith(color: Theme.of(context).hintColor))
              : Column(children: list.map((e) => _ledgerTile(Map<String, dynamic>.from(e), isTx: false)).toList()),
          orElse: () => const LinearProgressIndicator(),
        ),
        const SizedBox(height: AppSpacing.x16),
        Text('Money is append-only — corrections are new entries, never edits.',
            style: t.bodySmall?.copyWith(color: Theme.of(context).hintColor)),
      ],
    );
  }

  Widget _ledgerTile(Map<String, dynamic> m, {required bool isTx}) {
    final kind = isTx ? '${m['kind'] ?? ''}' : '${m['category'] ?? ''}';
    final sub = isTx ? '${m['category'] ?? ''}' : '${m['subtype'] ?? ''}';
    final date = DateTime.tryParse('${m[isTx ? 'occurred_on' : 'event_date']}');
    return Card(
      child: ListTile(
        dense: true,
        title: Text(_humanize(kind)),
        subtitle: Text([sub, if (date != null) DateFormat('d MMM y').format(date)]
            .where((x) => x.isNotEmpty)
            .join('  ·  ')),
        trailing: Text(_money(m['amount']), style: const TextStyle(fontWeight: FontWeight.w600)),
      ),
    );
  }

  Future<void> _addTransaction(BuildContext context, WidgetRef ref) async {
    final category = TextEditingController();
    final amount = TextEditingController();
    final note = TextEditingController();
    var kind = 'income';
    final ok = await AppDialog.show<bool>(
      context,
      title: 'Add transaction',
      maxWidth: 460,
      children: [
        StatefulBuilder(
          builder: (ctx, setS) => DropdownButtonFormField<String>(
            initialValue: kind,
            decoration: const InputDecoration(labelText: 'Kind'),
            items: const [
              DropdownMenuItem(value: 'income', child: Text('Income')),
              DropdownMenuItem(value: 'expense', child: Text('Expense')),
            ],
            onChanged: (v) => setS(() => kind = v ?? 'income'),
          ),
        ),
        TextField(controller: category, decoration: const InputDecoration(labelText: 'Category')),
        TextField(controller: amount, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Amount (AED)')),
        TextField(controller: note, decoration: const InputDecoration(labelText: 'Note')),
      ],
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save')),
      ],
    );
    if (ok != true) return;
    final amt = num.tryParse(amount.text.trim());
    if (amt == null) return;
    try {
      await ref.read(apiClientProvider).post('/properties/$propertyId/transactions', body: {
        'kind': kind,
        'category': category.text.trim(),
        'amount': amt,
        if (note.text.trim().isNotEmpty) 'note': note.text.trim(),
      });
      ref.invalidate(_txProvider(propertyId));
      ref.invalidate(_financialsProvider(propertyId));
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _addEvent(BuildContext context, WidgetRef ref) async {
    final subtype = TextEditingController();
    final amount = TextEditingController();
    var category = 'expense';
    final ok = await AppDialog.show<bool>(
      context,
      title: 'Add ledger event',
      maxWidth: 460,
      children: [
        StatefulBuilder(
          builder: (ctx, setS) => DropdownButtonFormField<String>(
            initialValue: category,
            decoration: const InputDecoration(labelText: 'Category'),
            items: const [
              DropdownMenuItem(value: 'acquisition', child: Text('Acquisition')),
              DropdownMenuItem(value: 'expense', child: Text('Expense')),
              DropdownMenuItem(value: 'income', child: Text('Income')),
              DropdownMenuItem(value: 'loan', child: Text('Loan')),
            ],
            onChanged: (v) => setS(() => category = v ?? 'expense'),
          ),
        ),
        TextField(controller: subtype, decoration: const InputDecoration(labelText: 'Subtype')),
        TextField(controller: amount, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Amount (AED)')),
      ],
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save')),
      ],
    );
    if (ok != true) return;
    final amt = num.tryParse(amount.text.trim());
    if (amt == null) return;
    try {
      await ref.read(apiClientProvider).post('/properties/$propertyId/events', body: {
        'category': category,
        'subtype': subtype.text.trim(),
        'amount': amt,
      });
      ref.invalidate(_eventsProvider(propertyId));
      ref.invalidate(_financialsProvider(propertyId));
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.summary});
  final Map<String, dynamic> summary;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final roi = summary['roi_pct'];
    final rows = <(String, String)>[
      ('Acquisition cost', _money(summary['acquisition_cost'])),
      ('Equity invested', _money(summary['equity_invested'])),
      ('Annual income', _money(summary['annual_income'])),
      ('Operating expenses', _money(summary['annual_operating_expenses'])),
      ('Net annual cashflow', _money(summary['net_annual_cashflow'])),
      ('ROI', roi == null ? '—' : '${(num.tryParse('$roi') ?? 0).toStringAsFixed(1)}%'),
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.x16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Summary', style: t.titleMedium),
            const SizedBox(height: AppSpacing.x8),
            ...rows.map((r) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(r.$1, style: t.bodyMedium?.copyWith(color: Theme.of(context).hintColor)),
                      Text(r.$2, style: t.bodyMedium?.copyWith(fontWeight: FontWeight.w600, color: AppColors.primary)),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }
}

String _humanize(String k) => k
    .replaceAll('_', ' ')
    .split(' ')
    .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
    .join(' ');
