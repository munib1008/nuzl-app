import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/util/mortgage_math.dart';
import '../../../core/widgets/responsive.dart';
import '../../shell/app_shell.dart';

/// Saved Property Finance Calculator scenarios for the signed-in user.
final financeScenariosProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  try {
    final d = await ref.read(apiClientProvider).get('/finance-scenarios');
    return d is List ? d : [];
  } catch (_) {
    return [];
  }
});

/// Customer Finance Planner — an affordability tool, NOT a loan tracker (that's
/// the Owner portal). Answers: what can I afford, what will it cost monthly, and
/// what income do I need. All client-side; supports conventional + Islamic.
class FinancePlannerScreen extends ConsumerStatefulWidget {
  const FinancePlannerScreen({super.key, this.listingId});
  /// When opened from a property, the saved scenario links back to that listing.
  final String? listingId;
  @override
  ConsumerState<FinancePlannerScreen> createState() => _FinancePlannerScreenState();
}

/// GCC bank Debt-Burden-Ratio caps + currency. The DBR cap is the share of
/// gross monthly income a bank lets go to ALL debt instalments combined; the
/// new instalment must fit under (cap × income − existing obligations).
typedef _Gcc = ({String code, String name, String currency, double dbr, String bureau});
const List<_Gcc> _gccCountries = [
  (code: 'AE', name: 'United Arab Emirates', currency: 'AED', dbr: 0.50, bureau: 'AECB'),
  (code: 'SA', name: 'Saudi Arabia', currency: 'SAR', dbr: 0.55, bureau: 'SIMAH'),
  (code: 'QA', name: 'Qatar', currency: 'QAR', dbr: 0.50, bureau: 'Qatar Credit Bureau'),
  (code: 'KW', name: 'Kuwait', currency: 'KWD', dbr: 0.45, bureau: 'CI-Net (CBK)'),
  (code: 'BH', name: 'Bahrain', currency: 'BHD', dbr: 0.55, bureau: 'Benefit'),
  (code: 'OM', name: 'Oman', currency: 'OMR', dbr: 0.50, bureau: 'Mala’a'),
];

class _FinancePlannerScreenState extends ConsumerState<FinancePlannerScreen> {
  final _income = TextEditingController();
  final _obligations = TextEditingController();
  final _price = TextEditingController();
  final _downPct = TextEditingController(text: '20');
  final _rate = TextEditingController(text: '4.5');
  String _financeType = 'conventional';
  String _countryCode = 'AE';
  int _years = 25;
  bool _saving = false;

  _Gcc get _country => _gccCountries.firstWhere((c) => c.code == _countryCode, orElse: () => _gccCountries.first);

  bool get _isl => _financeType == 'islamic';
  String get _financeLabel => _isl ? 'Finance amount' : 'Loan amount';
  String get _rateLabel => _isl ? 'Profit rate (% / yr)' : 'Interest rate (% / yr)';
  String get _installmentLabel => _isl ? 'Monthly rental' : 'Monthly installment';

  @override
  void dispose() {
    for (final c in [_income, _obligations, _price, _downPct, _rate]) {
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
    final dark = Theme.of(context).brightness == Brightness.dark;
    final country = _country;
    final dbrCap = country.dbr;
    final aed = NumberFormat.currency(symbol: '${country.currency} ', decimalDigits: 0);
    final income = double.tryParse(_income.text.trim()) ?? 0;
    final obligations = double.tryParse(_obligations.text.trim()) ?? 0;
    final price = double.tryParse(_price.text.trim()) ?? 0;
    final downPct = (double.tryParse(_downPct.text.trim()) ?? 20).clamp(0, 90) / 100;
    final rate = double.tryParse(_rate.text.trim()) ?? 4.5;
    final months = _years * 12;

    // From income → eligibility. DBR allowance covers ALL debt; subtract the
    // borrower's existing monthly obligations to get the room for a new one.
    final dbrAllowance = income * dbrCap;
    final maxMonthly = math.max(0.0, dbrAllowance - obligations);
    final maxLoan = _maxLoanFor(maxMonthly, rate, months);
    final maxPrice = downPct < 1 ? maxLoan / (1 - downPct) : maxLoan;

    // From property price → cost.
    final downPayment = price * downPct;
    final financeAmount = price - downPayment;
    final installment = MortgageMath.monthlyPayment(financeAmount, rate, months);
    // Income a bank looks for: the instalment PLUS existing obligations must sit
    // under the DBR cap → income ≥ (instalment + obligations) / cap.
    final recommendedIncome = (installment + obligations) / dbrCap;
    // Approval likelihood from the TOTAL debt-burden ratio (all instalments).
    final dbr = income > 0 ? (installment + obligations) / income : null;
    final ({String label, Color color})? approval = dbr == null
        ? null
        : dbr <= dbrCap - 0.10
            ? (label: 'High', color: AppColors.success)
            : dbr <= dbrCap
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
                style: t.bodyMedium?.copyWith(color: dark ? AppColors.dTextMuted : AppColors.textMuted)),
            const SizedBox(height: AppSpacing.x20),

            // ── Inputs ──
            _Panel(title: 'Your numbers', child: Column(children: [
              DropdownButtonFormField<String>(
                initialValue: _countryCode,
                decoration: const InputDecoration(labelText: 'Country (sets the bank DBR cap)'),
                items: [
                  for (final c in _gccCountries)
                    DropdownMenuItem(value: c.code, child: Text('${c.name}  ·  ${(c.dbr * 100).round()}% DBR')),
                ],
                onChanged: (v) => setState(() => _countryCode = v ?? 'AE'),
              ),
              const SizedBox(height: AppSpacing.x12),
              _money(_income, 'Gross monthly income (${country.currency})', live: true),
              const SizedBox(height: AppSpacing.x12),
              _money(_obligations, 'Existing monthly obligations (${country.currency})', live: true),
              const SizedBox(height: AppSpacing.x12),
              _money(_price, 'Property price (${country.currency}) — optional', live: true),
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
                      style: t.displaySmall?.copyWith(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w800)),
                  Text('estimated maximum property price', style: t.bodySmall?.copyWith(color: dark ? AppColors.dTextMuted : AppColors.textMuted)),
                  const SizedBox(height: AppSpacing.x12),
                  // DBR breakdown — how the available instalment is derived.
                  _kv('Gross monthly income', aed.format(income)),
                  _kv('Max debt burden (${(dbrCap * 100).round()}% — ${country.name})', aed.format(dbrAllowance)),
                  if (obligations > 0) _kv('Less existing obligations', '− ${aed.format(obligations)}'),
                  const Divider(height: AppSpacing.x16),
                  _kv('Available for new ${_installmentLabel.toLowerCase()}', aed.format(maxMonthly)),
                  _kv('Eligible ${_financeLabel.toLowerCase()}', aed.format(maxLoan)),
                  _kv('Over', '$_years years at ${rate.toStringAsFixed(2)}%'),
                  if (maxMonthly <= 0) ...[
                    const SizedBox(height: AppSpacing.x8),
                    Text('Your existing obligations already reach the ${(dbrCap * 100).round()}% debt-burden cap — '
                        'a bank is unlikely to approve new finance until they reduce.',
                        style: t.bodySmall?.copyWith(color: AppColors.danger)),
                  ],
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
                        style: t.titleLarge?.copyWith(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w800)),
                  ]),
                  const Divider(height: AppSpacing.x16),
                  _kv('Property price', aed.format(price)),
                  _kv('Down payment (${(downPct * 100).round()}%)', aed.format(downPayment)),
                  _kv(_financeLabel, aed.format(financeAmount)),
                  _kv('Recommended income', aed.format(recommendedIncome)),
                  if (approval != null) ...[
                    const SizedBox(height: AppSpacing.x8),
                    Row(children: [
                      Text('Approval likelihood  ', style: t.bodySmall?.copyWith(color: dark ? AppColors.dTextMuted : AppColors.textMuted)),
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
                    style: t.bodyMedium?.copyWith(color: dark ? AppColors.dTextMuted : AppColors.textMuted)),
              ),

            if (income > 0 || price > 0) ...[
              const SizedBox(height: AppSpacing.x8),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _saving ? null : () => _save(
                        price: price, income: income, downPayment: downPayment, financeAmount: financeAmount,
                        installment: installment, rate: rate, dbr: dbr, maxPrice: maxPrice),
                  icon: const Icon(Icons.bookmark_add_outlined, size: 18),
                  label: Text(_saving ? 'Saving…' : 'Save this scenario'),
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.x8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => context.go('/properties'),
                icon: const Icon(Icons.search, size: 18),
                label: Text(income > 0 ? 'Browse properties in budget' : 'Browse properties'),
              ),
            ),

            // ── Saved scenarios ──
            ...(() {
              final saved = ref.watch(financeScenariosProvider).asData?.value ?? const [];
              if (saved.isEmpty) return <Widget>[];
              return [
                const SizedBox(height: AppSpacing.x16),
                _Panel(
                  title: 'Saved scenarios',
                  child: Column(children: [
                    for (final s in saved) _scenarioTile(Map<String, dynamic>.from(s), aed),
                  ]),
                ),
              ];
            })(),

            const SizedBox(height: AppSpacing.x12),
            Text('Estimates only — actual eligibility, rates and fees are set by your bank or finance provider.',
                style: t.bodySmall?.copyWith(color: dark ? AppColors.dTextMuted : AppColors.textSubtle)),
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
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(children: [
        Expanded(child: Text(k, style: t.bodySmall?.copyWith(color: dark ? AppColors.dTextMuted : AppColors.textMuted))),
        Text(v, style: t.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
      ]),
    );
  }

  Future<void> _save({
    required double price, required double income, required double downPayment, required double financeAmount,
    required double installment, required double rate, double? dbr, required double maxPrice,
  }) async {
    final ctrl = TextEditingController(
      text: price > 0 ? NumberFormat.currency(symbol: 'AED ', decimalDigits: 0).format(price) : 'My scenario');
    final label = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Save scenario'),
        content: TextField(controller: ctrl, autofocus: true, decoration: const InputDecoration(labelText: 'Label')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: const Text('Save')),
        ],
      ),
    );
    if (label == null) return;
    setState(() => _saving = true);
    try {
      await ref.read(apiClientProvider).post('/finance-scenarios', body: {
        'listing_id': widget.listingId,
        'label': label.isEmpty ? null : label,
        'property_price': price > 0 ? price : null,
        'down_payment': price > 0 ? downPayment : null,
        'loan_amount': price > 0 ? financeAmount : null,
        'interest_rate': rate,
        'loan_years': _years,
        'monthly_installment': price > 0 ? installment : null,
        'income': income > 0 ? income : null,
        'dbr': dbr,
        'approval_estimate': income > 0 ? maxPrice : null,
        'is_islamic': _isl,
      });
      ref.invalidate(financeScenariosProvider);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Scenario saved')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _load(Map<String, dynamic> s) {
    setState(() {
      final price = num.tryParse('${s['property_price']}');
      final income = num.tryParse('${s['income']}');
      final rate = num.tryParse('${s['interest_rate']}');
      final years = int.tryParse('${s['loan_years'] ?? ''}');
      final down = num.tryParse('${s['down_payment']}');
      _price.text = price != null ? price.toStringAsFixed(0) : '';
      _income.text = income != null ? income.toStringAsFixed(0) : '';
      if (rate != null) _rate.text = '$rate';
      if (years != null && const [10, 15, 20, 25].contains(years)) _years = years;
      _financeType = s['is_islamic'] == true ? 'islamic' : 'conventional';
      if (price != null && price > 0 && down != null) {
        _downPct.text = ((down / price) * 100).round().toString();
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Scenario loaded')));
  }

  Future<void> _delete(String id) async {
    try {
      await ref.read(apiClientProvider).delete('/finance-scenarios/$id');
      ref.invalidate(financeScenariosProvider);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
    }
  }

  Widget _scenarioTile(Map<String, dynamic> s, NumberFormat aed) {
    final t = Theme.of(context).textTheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final price = num.tryParse('${s['property_price']}');
    final inst = num.tryParse('${s['monthly_installment']}');
    final sub = [
      if (price != null) aed.format(price),
      if (inst != null) '${aed.format(inst)}/mo',
      if ('${s['community'] ?? ''}'.isNotEmpty) '${s['community']}',
    ].join('  ·  ');
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(Icons.savings_outlined, color: Theme.of(context).colorScheme.primary),
      title: Text('${s['label'] ?? 'Scenario'}', maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: sub.isEmpty ? null : Text(sub, style: t.bodySmall?.copyWith(color: dark ? AppColors.dTextMuted : AppColors.textMuted)),
      onTap: () => _load(s),
      trailing: IconButton(
        tooltip: 'Delete',
        icon: const Icon(Icons.delete_outline, size: 20),
        onPressed: () => _delete('${s['id']}'),
      ),
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
