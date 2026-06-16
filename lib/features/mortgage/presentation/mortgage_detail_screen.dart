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
          final isl = m['finance_type'] == 'islamic';
          final rateValid = DateTime.tryParse('${m['rate_valid_until'] ?? ''}');
          double n(v) => v is num ? v.toDouble() : double.tryParse('$v') ?? 0;
          final progress = (n(s['progress_pct']) / 100).clamp(0, 1).toDouble();
          return ListView(
            padding: const EdgeInsets.all(AppSpacing.x16),
            children: [
              Text(m['label'] ?? m['lender'] ?? 'Mortgage', style: t.headlineSmall),
              const SizedBox(height: AppSpacing.x16),
              // This month — simplified at-a-glance view (#17).
              Card(child: Padding(
                padding: const EdgeInsets.all(AppSpacing.x16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(isl ? 'Rental due this month' : 'Due this month', style: t.bodyMedium),
                  const SizedBox(height: 2),
                  Text(aed.format(n(s['current_month_payment'] ?? s['monthly_payment'])), style: t.headlineMedium),
                  const SizedBox(height: AppSpacing.x12),
                  Row(children: [
                    Expanded(child: _stat('${n(s['progress_pct']).toStringAsFixed(0)}%', 'paid off', t)),
                    Expanded(child: _stat(_term(_intv(s['remaining_term'])), 'remaining', t)),
                    Expanded(child: _stat(aed.format(n(s['outstanding'])), 'outstanding', t)),
                  ]),
                ]),
              )),
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
                  _row(isl ? 'Outstanding (fixed rental balance)' : 'Outstanding', aed.format(n(s['outstanding'])), t),
                  _row(isl ? 'Profit rate' : 'Interest rate',
                      '${n(m['interest_rate']).toStringAsFixed(2)}%'
                      '${rateValid != null ? ' · to ${DateFormat.yMMMd().format(rateValid)}' : ''}', t),
                  _row(isl ? 'Monthly rental' : 'Monthly payment', aed.format(n(s['monthly_payment'])), t),
                  _row(isl ? 'Fixed rental paid' : 'Principal paid', aed.format(n(s['principal_paid'])), t),
                  _row(isl ? 'Variable rental (profit) paid' : 'Interest paid', aed.format(n(s['interest_paid'])), t),
                  _row(isl ? 'Rentals paid' : 'Payments made', '${s['payments_made'] ?? 0}', t),
                  _row(isl ? 'Projected total profit' : 'Projected total interest', aed.format(n(s['projected_total_interest'])), t),
                ]),
              )),
              if (n(s['total_project_value']) > 0 || n(s['down_payment']) > 0) ...[
                const SizedBox(height: AppSpacing.x16),
                Card(child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.x16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Purchase & financing', style: t.titleMedium),
                    const SizedBox(height: AppSpacing.x8),
                    if (n(s['total_project_value']) > 0) _row('Total project value', aed.format(n(s['total_project_value'])), t),
                    if (n(s['dld_charges']) > 0) _row('DLD charges', aed.format(n(s['dld_charges'])), t),
                    if (n(s['processing_fees']) > 0) _row('Processing fees', aed.format(n(s['processing_fees'])), t),
                    if (n(s['down_payment']) > 0) _row('Down payment', aed.format(n(s['down_payment'])), t),
                    if (s['down_payment_splits'] is List)
                      ...(s['down_payment_splits'] as List).map((sp) {
                        final mp = Map<String, dynamic>.from(sp as Map);
                        return Padding(
                          padding: const EdgeInsets.only(left: AppSpacing.x16),
                          child: _row('• ${mp['label'] ?? 'Split'}', aed.format(n(mp['amount'])), t),
                        );
                      }),
                    _row(isl ? 'Finance amount' : 'Loan amount', aed.format(n(m['principal'])), t),
                    _row(isl ? 'Ijarah period' : 'Term', _term(_intv(s['term_months'])), t),
                    if (n(s['insurance_monthly']) > 0)
                      _row(isl ? 'Takaful (per month)' : 'Insurance (per month)', aed.format(n(s['insurance_monthly'])), t),
                  ]),
                )),
              ],
              const SizedBox(height: AppSpacing.x24),
              Text(isl ? 'Rental history' : 'Payment history', style: t.titleMedium),
              const SizedBox(height: AppSpacing.x8),
              _PaymentList(id: id, isl: isl),
            ],
          );
        },
      ),
    );
  }

  Widget _row(String k, String v, TextTheme t) => Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.x4),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Flexible(child: Text(k, style: t.bodyMedium)), Text(v, style: t.titleMedium),
        ]),
      );

  Widget _stat(String value, String label, TextTheme t) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: t.titleMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
          Text(label, style: t.bodySmall),
        ],
      );

  int _intv(dynamic v) => v is int ? v : int.tryParse('$v') ?? 0;

  /// Human term: "8 mo", "3y", "3y 2m".
  String _term(int months) {
    if (months <= 0) return 'Done';
    if (months < 12) return '$months mo';
    final y = months ~/ 12, m = months % 12;
    return m == 0 ? '${y}y' : '${y}y ${m}m';
  }

  Future<void> _logPayment(BuildContext context, WidgetRef ref) async {
    // Relabel the split fields to match an Islamic statement when applicable.
    final d = ref.read(mortgageDetailProvider(id)).asData?.value;
    final isl = d?['mortgage'] is Map && (d!['mortgage'] as Map)['finance_type'] == 'islamic';
    final amount = TextEditingController();
    final principal = TextEditingController();
    final profit = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isl ? 'Log a rental payment' : 'Log a payment'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            TextField(
              controller: amount, autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Amount (AED)', prefixText: 'AED '),
            ),
            const SizedBox(height: AppSpacing.x8),
            Text(
              isl
                  ? 'Optional: enter the Fixed + Variable rental split exactly as your statement shows, to keep the balance accurate.'
                  : 'Optional: enter the principal / interest split from your statement to keep the balance accurate.',
              style: Theme.of(ctx).textTheme.bodySmall,
            ),
            const SizedBox(height: AppSpacing.x8),
            Row(children: [
              Expanded(
                child: TextField(
                  controller: principal,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                      labelText: isl ? 'Fixed rental' : 'Principal', prefixText: 'AED ', isDense: true),
                ),
              ),
              const SizedBox(width: AppSpacing.x8),
              Expanded(
                child: TextField(
                  controller: profit,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                      labelText: isl ? 'Variable rental' : 'Interest', prefixText: 'AED ', isDense: true),
                ),
              ),
            ]),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
        ],
      ),
    );
    if (ok != true) return;
    final amt = double.tryParse(amount.text.trim());
    if (amt == null || amt <= 0) return;
    final body = <String, dynamic>{'amount': amt};
    final pr = double.tryParse(principal.text.trim());
    final pf = double.tryParse(profit.text.trim());
    if (pr != null) body['principal_part'] = pr;
    if (pf != null) body['interest_part'] = pf;
    await ref.read(mortgageRepositoryProvider).addPayment(id, body);
    ref.invalidate(mortgageDetailProvider(id));
    ref.invalidate(mortgagePaymentsProvider(id));
    ref.invalidate(mortgagesProvider);
  }
}

class _PaymentList extends ConsumerWidget {
  const _PaymentList({required this.id, this.isl = false});
  final String id;
  final bool isl;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final payments = ref.watch(mortgagePaymentsProvider(id));
    final aed = NumberFormat.currency(symbol: 'AED ', decimalDigits: 0);
    final t = Theme.of(context).textTheme;
    final principalWord = isl ? 'fixed' : 'principal';
    final interestWord = isl ? 'variable' : 'interest';
    return payments.when(
      loading: () => const Padding(padding: EdgeInsets.all(AppSpacing.x16), child: LinearProgressIndicator()),
      error: (e, _) => Text('$e', style: t.bodySmall),
      data: (list) {
        if (list.isEmpty) return Text(isl ? 'No rentals logged yet.' : 'No payments logged yet.', style: t.bodySmall);
        return Column(
          children: list.map((p) => ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(aed.format(p.amount), style: t.titleMedium),
            subtitle: Text([
              if (p.paidOn != null) DateFormat.yMMMd().format(p.paidOn!),
              if (p.principalPart != null) '$principalWord ${aed.format(p.principalPart)}',
              if (p.interestPart != null) '$interestWord ${aed.format(p.interestPart)}',
            ].join('  ·  '), style: t.bodySmall),
          )).toList(),
        );
      },
    );
  }
}
