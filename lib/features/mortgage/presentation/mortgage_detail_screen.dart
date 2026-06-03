import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/async_view.dart';
import '../data/mortgage_repository.dart';

/// Mortgage detail: progress summary + payment history + log a payment.
class MortgageDetailScreen extends ConsumerWidget {
  const MortgageDetailScreen({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(mortgageDetailProvider(id));
    final aed = NumberFormat.currency(symbol: 'AED ', decimalDigits: 0);
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Mortgage')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _logPayment(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Log payment'),
      ),
      body: AsyncView<Map<String, dynamic>>(
        value: detail,
        onRetry: () => ref.refresh(mortgageDetailProvider(id)),
        data: (d) {
          final s = Map<String, dynamic>.from(d['summary'] ?? {});
          final m = Map<String, dynamic>.from(d['mortgage'] ?? {});
          double n(v) => v is num ? v.toDouble() : double.tryParse('$v') ?? 0;
          final progress = (n(s['progress_pct']) / 100).clamp(0, 1).toDouble();
          return ListView(
            padding: const EdgeInsets.all(AppSpacing.x16),
            children: [
              Text(m['label'] ?? m['lender'] ?? 'Mortgage', style: t.headlineSmall),
              const SizedBox(height: AppSpacing.x16),
              Card(child: Padding(
                padding: const EdgeInsets.all(AppSpacing.x16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${n(s['progress_pct']).toStringAsFixed(1)}% paid off', style: t.titleLarge),
                  const SizedBox(height: AppSpacing.x8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppSpacing.rFull),
                    child: LinearProgressIndicator(value: progress, minHeight: 8,
                        backgroundColor: Theme.of(context).dividerColor),
                  ),
                  const SizedBox(height: AppSpacing.x16),
                  _row('Outstanding', aed.format(n(s['outstanding'])), t),
                  _row('Monthly payment', aed.format(n(s['monthly_payment'])), t),
                  _row('Principal paid', aed.format(n(s['principal_paid'])), t),
                  _row('Interest paid', aed.format(n(s['interest_paid'])), t),
                  _row('Payments made', '${s['payments_made'] ?? 0}', t),
                  _row('Projected total interest', aed.format(n(s['projected_total_interest'])), t),
                ]),
              )),
              const SizedBox(height: AppSpacing.x24),
              Text('Payment history', style: t.titleMedium),
              const SizedBox(height: AppSpacing.x8),
              _PaymentList(id: id),
            ],
          );
        },
      ),
    );
  }

  Widget _row(String k, String v, TextTheme t) => Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.x4),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(k, style: t.bodyMedium), Text(v, style: t.titleMedium),
        ]),
      );

  Future<void> _logPayment(BuildContext context, WidgetRef ref) async {
    final ctrl = TextEditingController();
    final amount = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log a payment'),
        content: TextField(
          controller: ctrl, keyboardType: TextInputType.number, autofocus: true,
          decoration: const InputDecoration(hintText: 'Amount (AED)'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, double.tryParse(ctrl.text)),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (amount == null || amount <= 0) return;
    await ref.read(mortgageRepositoryProvider).addPayment(id, {'amount': amount});
    ref.invalidate(mortgageDetailProvider(id));
    ref.invalidate(mortgagePaymentsProvider(id));
    ref.invalidate(mortgagesProvider);
  }
}

class _PaymentList extends ConsumerWidget {
  const _PaymentList({required this.id});
  final String id;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final payments = ref.watch(mortgagePaymentsProvider(id));
    final aed = NumberFormat.currency(symbol: 'AED ', decimalDigits: 0);
    final t = Theme.of(context).textTheme;
    return payments.when(
      loading: () => const Padding(padding: EdgeInsets.all(AppSpacing.x16), child: LinearProgressIndicator()),
      error: (e, _) => Text('$e', style: t.bodySmall),
      data: (list) {
        if (list.isEmpty) return Text('No payments logged yet.', style: t.bodySmall);
        return Column(
          children: list.map((p) => ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(aed.format(p.amount), style: t.titleMedium),
            subtitle: Text([
              if (p.paidOn != null) DateFormat.yMMMd().format(p.paidOn!),
              if (p.principalPart != null) 'principal ${aed.format(p.principalPart)}',
              if (p.interestPart != null) 'interest ${aed.format(p.interestPart)}',
            ].join('  ·  '), style: t.bodySmall),
          )).toList(),
        );
      },
    );
  }
}
