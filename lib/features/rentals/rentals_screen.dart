import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/responsive.dart';
import '../shell/app_shell.dart';

final tenanciesProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  try { final d = await ref.read(apiClientProvider).get('/tenancies'); return d is List ? d : []; } catch (_) { return []; }
});
final chequesProvider = FutureProvider.autoDispose.family<List<dynamic>, String>((ref, id) async {
  try { final d = await ref.read(apiClientProvider).get('/tenancies/$id/cheques'); return d is List ? d : []; } catch (_) { return []; }
});

class RentalsScreen extends ConsumerWidget {
  const RentalsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tenancies = ref.watch(tenanciesProvider);
    final aed = NumberFormat.currency(symbol: 'AED ', decimalDigits: 0);
    return Scaffold(
      appBar: const NuzlAppBar(title: 'Rentals'),
      drawer: const NuzlDrawer(),
      body: ResponsiveCenter(
        child: RefreshIndicator(
          onRefresh: () async => ref.refresh(tenanciesProvider.future),
          child: tenancies.when(
            loading: () => const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator())),
            error: (e, _) => ListView(children: [Padding(padding: const EdgeInsets.all(24), child: Text('$e'))]),
            data: (list) => list.isEmpty
                ? ListView(children: [Padding(padding: const EdgeInsets.all(40), child: Column(children: [
                    Icon(Icons.vpn_key_outlined, size: 44, color: Theme.of(context).hintColor),
                    const SizedBox(height: 12), const Text('No tenancies yet'),
                  ]))])
                : ListView(
                    padding: const EdgeInsets.all(AppSpacing.x16),
                    children: list.map((m) {
                      final tc = Map<String, dynamic>.from(m);
                      return Card(child: ExpansionTile(
                        title: Text(tc['tenant_name'] ?? 'Tenant'),
                        subtitle: Text('${aed.format(num.tryParse('${tc['rent_amount']}') ?? 0)} / yr · ${tc['status']}'),
                        children: [_Cheques(tenancyId: tc['id'].toString())],
                      ));
                    }).toList(),
                  ),
          ),
        ),
      ),
    );
  }
}

class _Cheques extends ConsumerWidget {
  const _Cheques({required this.tenancyId});
  final String tenancyId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cheques = ref.watch(chequesProvider(tenancyId));
    final aed = NumberFormat.currency(symbol: 'AED ', decimalDigits: 0);
    Color c(String s) => s == 'cleared' ? AppColors.primary : s == 'bounced' ? Colors.redAccent : AppColors.accentGold;
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.x16, 0, AppSpacing.x16, AppSpacing.x12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('Post-dated cheques', style: TextStyle(fontWeight: FontWeight.w600)),
          TextButton.icon(onPressed: () => _add(context, ref), icon: const Icon(Icons.add, size: 18), label: const Text('Add')),
        ]),
        cheques.when(
          loading: () => const LinearProgressIndicator(),
          error: (e, _) => Text('$e'),
          data: (list) => list.isEmpty
              ? const Text('No cheques recorded.')
              : Column(children: list.map((m) {
                  final ch = Map<String, dynamic>.from(m);
                  return ListTile(
                    dense: true, contentPadding: EdgeInsets.zero,
                    title: Text('${ch['cheque_no'] ?? 'Cheque'} · ${aed.format(num.tryParse('${ch['amount']}') ?? 0)}'),
                    subtitle: Text('${ch['bank'] ?? ''} · due ${ch['due_date']?.toString().split('T').first ?? ''}'),
                    trailing: PopupMenuButton<String>(
                      onSelected: (v) async {
                        await ref.read(apiClientProvider).patch('/cheques/${ch['id']}/status', body: {'status': v});
                        ref.invalidate(chequesProvider(tenancyId));
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'cleared', child: Text('Mark cleared')),
                        PopupMenuItem(value: 'bounced', child: Text('Mark bounced')),
                        PopupMenuItem(value: 'pending', child: Text('Mark pending')),
                      ],
                      child: Chip(label: Text(ch['status'] ?? 'pending'),
                          backgroundColor: c('${ch['status']}').withValues(alpha: 0.15),
                          labelStyle: TextStyle(color: c('${ch['status']}'), fontSize: 12)),
                    ),
                  );
                }).toList()),
        ),
      ]),
    );
  }

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final no = TextEditingController(); final bank = TextEditingController(); final amount = TextEditingController(); final due = TextEditingController();
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Add cheque'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: no, decoration: const InputDecoration(labelText: 'Cheque no.')),
        TextField(controller: bank, decoration: const InputDecoration(labelText: 'Bank')),
        TextField(controller: amount, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Amount (AED)')),
        TextField(controller: due, decoration: const InputDecoration(labelText: 'Due date (YYYY-MM-DD)')),
      ]),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save'))],
    ));
    if (ok != true) return;
    await ref.read(apiClientProvider).post('/tenancies/$tenancyId/cheques', body: {
      'cheque_no': no.text.trim(), 'bank': bank.text.trim(), 'amount': double.tryParse(amount.text), 'due_date': due.text.trim(),
    });
    ref.invalidate(chequesProvider(tenancyId));
  }
}
