import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/util/mortgage_math.dart';
import '../../../core/widgets/responsive.dart';
import '../../shell/app_shell.dart';

/// Customer Finance Planner — an affordability tool, NOT a loan tracker (that's
/// the Owner portal). Answers: what can I afford, what will it cost monthly, and
/// what income do I need. All client-side; supports conventional + Islamic.
class FinancePlannerScreen extends ConsumerStatefulWidget {
  const FinancePlannerScreen({super.key});
  @override
  ConsumerState<FinancePlannerScreen> createState() => _FinancePlannerScreenState();
}

class _FinancePlannerScreenState extends ConsumerState<FinancePlannerScreen> {
  final _income = TextEditingController();
  final _price = TextEditingController();
  final _downPct = TextEditingController(text: '20');
  final _rate = TextEditingController(text: '4.5');
  String _financeType = 'conventional';
  int _years = 25;

  // UAE mortgage-affordability rule of thumb: total instalments ≤ 50% of monthly
  // income (the bank "DBR" cap).
  static const _dbrCap = 0.5;

  bool get _isl => _financeType == 'islamic';
  String get _financeLabel => _isl ? 'Finance amount' : 'Loan amount';
  String get _rateLabel => _isl ? 'Profit rate (% / yr)' : 'Interest rate (% / yr)';
  String get _installmentLabel => _isl ? 'Monthly rental' : 'Monthly installment';

  @override
  void dispose() {
    for (final c in [_income, _price, _downPct, _rate]) {
      c.dispose();
    }
    super.dispose();
  }

  double _maxLoanFor(double monthly, double ratePct, int months) {
    final r = ratePct / 100 / 12;
    if (months <= 0 || monthly <= 0) return 0;
    if (r == 0) return monthly * months;
    final f = math.pow(1 + r, months).toDouble();
    return monthly * (f - 1) / (r * f);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final aed = NumberFormat.currency(symbol: 'AED ', decimalDigits: 0);
    final income = double.tryParse(_income.text.trim()) ?? 0;
    final price = double.tryParse(_price.text.trim()) ?? 0;
    final downPct = (double.tryParse(_downPct.text.trim()) ?? 20).clamp(0, 90) / 100;
    final rate = double.tryParse(_rate.text.trim()) ?? 4.5;
    final months = _years * 12;

    // From income → eligibility.
    final maxMonthly = income * _dbrCap;
    final maxLoan = _maxLoanFor(maxMonthly, rate, months);
    final maxPrice = downPct < 1 ? maxLoan / (1 - downPct) : maxLoan;

    // From property price → cost.
    final downPayment = price * downPct;
    final financeAmount = price - downPayment;
    final installment = MortgageMath.monthlyPayment(financeAmount, rate, months);
    final recommendedIncome = installment / _dbrCap;
    // Approval likelihood from the debt-burden ratio (instalment / income).
    final dbr = income > 0 ? installment / income : null;
    final ({String label, Color color})? approval = dbr == null
        ? null
        : dbr <= 0.40
            ? (label: 'High', color: AppColors.success)
            : dbr <= _dbrCap
                ? (label: 'Moderate', color: AppColors.warning)
                : (label: 'Low', color: AppColors.danger);

    return Scaffold(
      appBar: const NuzlAppBar(title: 'Finance Planner'),
      drawer: const NuzlDrawer(),
      body: ResponsiveCenter(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.x20),
          children: [
            Text('Plan your purchase', style: t.headlineSmall),
            const SizedBox(height: 2),
            Text('See what you can afford, the monthly cost, and the income a bank looks for.',
                style: t.bodyMedium?.copyWith(color: AppColors.textMuted)),
            const SizedBox(height: AppSpacing.x20),

            // ── Inputs ──
            _Panel(title: 'Your numbers', child: Column(children: [
              _money(_income, 'Monthly income (AED)', live: true),
              const SizedBox(height: AppSpacing.x12),
              _money(_price, 'Property price (AED) — optional', live: true),
              const SizedBox(height: AppSpacing.x12),
              Row(children: [
                Expanded(child: _money(_downPct, 'Down payment %', live: true, prefix: '')),
                const SizedBox(width: AppSpacing.x12),
                Expanded(
                  child: TextField(
                    controller: _rate,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(labelText: _rateLabel),
                  ),
                ),
              ]),
              const SizedBox(height: AppSpacing.x12),
              Row(children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _financeType,
                    decoration: const InputDecoration(labelText: 'Finance type'),
                    items: const [
                      DropdownMenuItem(value: 'conventional', child: Text('Conventional')),
                      DropdownMenuItem(value: 'islamic', child: Text('Islamic (Ijarah)')),
                    ],
                    onChanged: (v) => setState(() => _financeType = v ?? 'conventional'),
                  ),
                ),
                const SizedBox(width: AppSpacing.x12),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    initialValue: _years,
                    decoration: const InputDecoration(labelText: 'Term'),
                    items: const [
                      DropdownMenuItem(value: 10, child: Text('10 years')),
                      DropdownMenuItem(value: 15, child: Text('15 years')),
                      DropdownMenuItem(value: 20, child: Text('20 years')),
                      DropdownMenuItem(value: 25, child: Text('25 years')),
                    ],
                    onChanged: (v) => setState(() => _years = v ?? 25),
                  ),
                ),
              ]),
            ])),

            const SizedBox(height: AppSpacing.x16),

            // ── What you can afford (from income) ──
            if (income > 0)
              _Panel(
                title: 'What you can afford',
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(aed.format(maxPrice),
                      style: t.displaySmall?.copyWith(color: AppColors.primary, fontWeight: FontWeight.w800)),
                  Text('estimated maximum property price', style: t.bodySmall?.copyWith(color: AppColors.textMuted)),
                  const SizedBox(height: AppSpacing.x12),
                  _kv('Eligible ${_financeLabel.toLowerCase()}', aed.format(maxLoan)),
                  _kv('Max ${_installmentLabel.toLowerCase()}', aed.format(maxMonthly)),
                  _kv('Based on', '${(_dbrCap * 100).round()}% of income over $_years years'),
                ]),
              ),
            if (income > 0) const SizedBox(height: AppSpacing.x16),

            // ── This property (from price) ──
            if (price > 0)
              _Panel(
                title: 'This property',
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Text(_installmentLabel, style: t.bodyMedium),
                    Text(aed.format(installment),
                        style: t.titleLarge?.copyWith(color: AppColors.primary, fontWeight: FontWeight.w800)),
                  ]),
                  const Divider(height: AppSpacing.x16),
                  _kv('Property price', aed.format(price)),
                  _kv('Down payment (${(downPct * 100).round()}%)', aed.format(downPayment)),
                  _kv(_financeLabel, aed.format(financeAmount)),
                  _kv('Recommended income', aed.format(recommendedIncome)),
                  if (approval != null) ...[
                    const SizedBox(height: AppSpacing.x8),
                    Row(children: [
                      Text('Approval likelihood  ', style: t.bodySmall?.copyWith(color: AppColors.textMuted)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                            color: approval.color.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(AppSpacing.rFull)),
                        child: Text(approval.label,
                            style: t.labelMedium?.copyWith(color: approval.color, fontWeight: FontWeight.w700)),
                      ),
                    ]),
                  ],
                ]),
              ),
            if (price > 0) const SizedBox(height: AppSpacing.x16),

            if (income <= 0 && price <= 0)
              _Panel(
                title: 'Get started',
                child: Text('Enter your monthly income to see what you can afford, or a property price to see the '
                    'monthly cost and the income a bank typically looks for.',
                    style: t.bodyMedium?.copyWith(color: AppColors.textMuted)),
              ),

            const SizedBox(height: AppSpacing.x8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => context.go('/properties'),
                icon: const Icon(Icons.search, size: 18),
                label: Text(income > 0 ? 'Browse properties in budget' : 'Browse properties'),
              ),
            ),
            const SizedBox(height: AppSpacing.x12),
            Text('Estimates only — actual eligibility, rates and fees are set by your bank or finance provider.',
                style: t.bodySmall?.copyWith(color: AppColors.textSubtle)),
          ],
        ),
      ),
    );
  }

  Widget _money(TextEditingController c, String label, {bool live = false, String prefix = 'AED '}) => TextField(
        controller: c,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        onChanged: live ? (_) => setState(() {}) : null,
        decoration: InputDecoration(labelText: label, prefixText: prefix.isEmpty ? null : prefix),
      );

  Widget _kv(String k, String v) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(children: [
        Expanded(child: Text(k, style: t.bodySmall?.copyWith(color: AppColors.textMuted))),
        Text(v, style: t.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.title, required this.child});
  final String title;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.x16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: t.titleMedium),
          const SizedBox(height: AppSpacing.x12),
          child,
        ]),
      ),
    );
  }
}
