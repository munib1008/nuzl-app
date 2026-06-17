import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/util/mortgage_math.dart';
import '../domain/finance_type.dart';
import '../data/mortgage_repository.dart';

final _ownerPropsProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  try {
    final d = await ref.read(apiClientProvider).get('/listings');
    return d is List ? d : [];
  } catch (_) {
    return [];
  }
});

/// A label + amount row for the down-payment split breakdown.
class _SplitRow {
  _SplitRow() : label = TextEditingController(), amount = TextEditingController();
  final TextEditingController label;
  final TextEditingController amount;
  void dispose() { label.dispose(); amount.dispose(); }
}

/// Set up a tracked home finance (owner #16/#17). Speaks your statement's
/// language: for an Islamic (Ijarah) product it relabels interest -> profit /
/// rental and insurance -> Takaful, and lays the finance numbers out the way
/// the bank statement does. Then it powers the payment tracker.
class MortgageFormScreen extends ConsumerStatefulWidget {
  const MortgageFormScreen({super.key});
  @override
  ConsumerState<MortgageFormScreen> createState() => _MortgageFormScreenState();
}

class _MortgageFormScreenState extends ConsumerState<MortgageFormScreen> {
  final _label = TextEditingController();
  final _lender = TextEditingController();
  final _principal = TextEditingController(text: '1000000');
  final _rate = TextEditingController(text: '4.5');
  final _years = TextEditingController(text: '25');
  final _fixedMonths = TextEditingController();
  final _rateAfter = TextEditingController();
  final _projectValue = TextEditingController();
  final _dld = TextEditingController();
  final _processing = TextEditingController();
  final _downPayment = TextEditingController();
  final _propInsurance = TextEditingController();
  final _lifeInsurance = TextEditingController();
  final List<_SplitRow> _splits = [];
  DateTime? _loanStart;
  DateTime? _firstInstallment;
  DateTime? _rateValidUntil;
  String _insuranceFreq = 'yearly';
  String _financeType = 'ijarah'; // UAE home finance is predominantly Ijarah
  String? _propertyId;
  bool _saving = false;
  String? _error;

  bool get _isl => isIslamicFinance(_financeType);
  bool get _isCash => isCashPurchase(_financeType);
  bool get _isDev => isDeveloperPlan(_financeType);

  // ── Statement-aware lexicon ────────────────────────────────────────────
  String get _financeLabel => _isl ? 'Finance amount (AED) *' : 'Loan amount (AED) *';
  String get _rateLabel => _isl ? 'Profit rate (% / yr) *' : 'Interest rate (% / yr) *';
  String get _termLabel => _isl ? 'Ijarah period (years) *' : 'Term (years) *';
  String get _monthlyLabel => _isl ? 'Estimated monthly rental' : 'Estimated monthly payment';
  String get _propInsLabel => _isl ? 'Property Takaful *' : 'Property insurance *';
  String get _lifeInsLabel => _isl ? 'Life Takaful *' : 'Life insurance *';
  String get _insFreqLabel => _isl ? 'Takaful frequency *' : 'Insurance frequency *';
  String get _startLabel => _isl ? 'Disbursal date *' : 'Loan start date *';
  String get _firstLabel => _isl ? 'First rental date *' : 'First installment *';
  String get _rateValidLabel => _isl ? 'Profit rate valid until' : 'Rate review date';

  @override
  void dispose() {
    for (final c in [_label, _lender, _principal, _rate, _years, _fixedMonths, _rateAfter,
        _projectValue, _dld, _processing, _downPayment, _propInsurance, _lifeInsurance]) {
      c.dispose();
    }
    for (final s in _splits) {
      s.dispose();
    }
    super.dispose();
  }

  double get _monthly {
    final p = double.tryParse(_principal.text) ?? 0;
    final r = double.tryParse(_rate.text) ?? 0;
    final y = int.tryParse(_years.text) ?? 0;
    return MortgageMath.monthlyPayment(p, r, y * 12);
  }

  double get _splitTotal => _splits.fold(0.0, (s, r) => s + (double.tryParse(r.amount.text) ?? 0));

  Future<void> _pickDate(int which) async {
    final now = DateTime.now();
    final current = which == 0 ? _loanStart : which == 1 ? _firstInstallment : _rateValidUntil;
    final d = await showDatePicker(
      context: context,
      initialDate: current ?? now,
      firstDate: DateTime(now.year - 30),
      lastDate: DateTime(now.year + 30),
    );
    if (d == null) return;
    setState(() {
      if (which == 0) {
        _loanStart = d;
      } else if (which == 1) {
        _firstInstallment = d;
      } else {
        _rateValidUntil = d;
      }
    });
  }

  /// First validation problem (mandatory setup fields), or null if all good.
  String? _validate() {
    double? pos(TextEditingController c) {
      final v = double.tryParse(c.text.trim());
      return (v == null || v <= 0) ? null : v;
    }
    final fin = _isl ? 'finance amount' : 'loan amount';
    final rate = _isl ? 'profit rate' : 'interest rate';
    final period = _isl ? 'Ijarah period' : 'term';
    final propIns = _isl ? 'property Takaful' : 'property insurance';
    final lifeIns = _isl ? 'life Takaful' : 'life insurance';
    if (_label.text.trim().isEmpty) return 'Name this finance.';
    if (_lender.text.trim().isEmpty) {
      return 'Enter the ${_isDev ? 'developer / provider' : _isCash ? 'seller / source' : 'bank / lender'}.';
    }
    if (!_isCash) {
      if (pos(_principal) == null) return 'The $fin is required.';
      if ((double.tryParse(_rate.text.trim()) ?? -1) < 0) return 'Enter a valid $rate.';
      if ((int.tryParse(_years.text.trim()) ?? 0) <= 0) return 'Enter the $period in years.';
      if (_loanStart == null) return 'Pick the ${_isl ? 'disbursal' : 'loan start'} date.';
      if (_firstInstallment == null) return 'Pick the first ${_isl ? 'rental' : 'installment'} date.';
      // Insurance/Takaful is required only for bank-financed products.
      if (!_isDev) {
        if (pos(_propInsurance) == null) return 'The $propIns is required.';
        if (pos(_lifeInsurance) == null) return 'The $lifeIns is required.';
      }
    }
    if (pos(_projectValue) == null) return 'Total property value is required.';
    if (pos(_dld) == null) return 'DLD charges are required.';
    if (pos(_processing) == null) return 'Processing fees are required.';
    if (pos(_downPayment) == null) return 'Down payment is required.';
    if (_splits.isNotEmpty && _splitTotal > 0) {
      final dp = double.tryParse(_downPayment.text.trim()) ?? 0;
      if ((_splitTotal - dp).abs() > 1) {
        return 'Down-payment splits (AED ${_splitTotal.toStringAsFixed(0)}) must add up to the '
            'down payment (AED ${dp.toStringAsFixed(0)}).';
      }
    }
    return null;
  }

  Future<void> _save() async {
    final problem = _validate();
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    setState(() { _saving = true; _error = null; });
    final iso = DateFormat('yyyy-MM-dd');
    final splits = [
      for (final r in _splits)
        if (r.label.text.trim().isNotEmpty || (double.tryParse(r.amount.text) ?? 0) > 0)
          {'label': r.label.text.trim(), 'amount': double.tryParse(r.amount.text) ?? 0}
    ];
    double n(TextEditingController c) => double.tryParse(c.text.trim()) ?? 0;
    // A cash purchase carries no finance — zero out the loan fields (the inputs are
    // hidden but their controllers still hold defaults).
    final principal = _isCash ? 0.0 : n(_principal);
    final rate = _isCash ? 0.0 : (double.tryParse(_rate.text) ?? 0);
    final termMonths = _isCash ? 0 : (int.tryParse(_years.text) ?? 0) * 12;
    final monthly = _isCash ? 0.0 : double.parse(_monthly.toStringAsFixed(2));
    try {
      await ref.read(mortgageRepositoryProvider).create({
        'finance_type': _financeType,
        'label': _label.text.trim(),
        'lender': _lender.text.trim(),
        'principal': principal,
        'interest_rate': rate,
        'term_months': termMonths,
        'monthly_payment': monthly,
        'total_project_value': n(_projectValue),
        'dld_charges': n(_dld),
        'processing_fees': n(_processing),
        'down_payment': n(_downPayment),
        if (splits.isNotEmpty) 'down_payment_splits': splits,
        if (_loanStart != null) 'start_date': iso.format(_loanStart!),
        if (_firstInstallment != null) 'first_installment_date': iso.format(_firstInstallment!),
        if (_rateValidUntil != null) 'rate_valid_until': iso.format(_rateValidUntil!),
        if (!_isCash) 'property_insurance_cost': n(_propInsurance),
        if (!_isCash) 'life_insurance_cost': n(_lifeInsurance),
        'insurance_frequency': _insuranceFreq,
        if (_propertyId != null) 'property_id': _propertyId,
        if (_fixedMonths.text.trim().isNotEmpty) 'fixed_months': int.tryParse(_fixedMonths.text.trim()),
        if (_rateAfter.text.trim().isNotEmpty) 'rate_after': double.tryParse(_rateAfter.text.trim()),
      });
      ref.invalidate(mortgagesProvider);
      if (mounted) context.pop();
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _money(TextEditingController c, String label, {bool live = false, String? helper}) => TextField(
        controller: c,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        onChanged: live ? (_) => setState(() {}) : null,
        decoration: InputDecoration(labelText: label, prefixText: 'AED ', helperText: helper),
      );

  Widget _sectionTitle(String s, TextTheme t) => Padding(
        padding: const EdgeInsets.only(top: AppSpacing.x20, bottom: AppSpacing.x8),
        child: Text(s, style: t.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
      );

  Widget _dateField(String label, DateTime? value, VoidCallback onTap) => InkWell(
        onTap: onTap,
        child: InputDecorator(
          decoration: InputDecoration(
              labelText: label, suffixIcon: const Icon(Icons.calendar_today_outlined, size: 18)),
          child: Text(value == null ? 'Select date' : DateFormat.yMMMd().format(value),
              style: TextStyle(color: value == null ? Theme.of(context).hintColor : null)),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Track a home finance')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.x16),
        children: [
          // Finance type — relabels the whole form (Islamic = profit / finance / Takaful;
          // Cash hides the finance section; Developer plan relabels the provider).
          DropdownButtonFormField<String>(
            initialValue: _financeType,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Finance type'),
            items: [for (final f in kFinanceTypes) DropdownMenuItem(value: f.$1, child: Text(f.$2))],
            onChanged: (v) => setState(() => _financeType = v ?? 'conventional'),
          ),
          const SizedBox(height: AppSpacing.x12),
          ref.watch(_ownerPropsProvider).maybeWhen(
            data: (list) {
              final items = <DropdownMenuItem<String?>>[
                const DropdownMenuItem(value: null, child: Text('Not linked to a property')),
              ];
              final seen = <String>{};
              for (final e in list) {
                final mp = Map<String, dynamic>.from(e);
                final pid = '${mp['property_id'] ?? ''}';
                if (pid.isEmpty || !seen.add(pid)) continue;
                final bn = '${mp['building_name'] ?? ''}'.trim();
                final un = '${mp['unit_no'] ?? ''}'.trim();
                final comm = '${mp['community'] ?? ''}'.trim();
                final label = bn.isNotEmpty
                    ? (un.isNotEmpty ? '$bn - $un' : bn)
                    : (un.isNotEmpty ? 'Unit $un' : (comm.isNotEmpty ? comm : 'Property'));
                items.add(DropdownMenuItem(value: pid, child: Text(label, overflow: TextOverflow.ellipsis)));
              }
              return DropdownButtonFormField<String?>(
                initialValue: _propertyId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Link to a property (optional)'),
                items: items,
                onChanged: (v) => setState(() => _propertyId = v),
              );
            },
            orElse: () => const SizedBox.shrink(),
          ),
          const SizedBox(height: AppSpacing.x12),
          TextField(controller: _label, decoration: const InputDecoration(
              labelText: 'Name this finance *', hintText: 'e.g. Star by Azizi 619')),
          const SizedBox(height: AppSpacing.x12),
          TextField(controller: _lender, decoration: InputDecoration(
              labelText: _isDev ? 'Developer / provider *' : _isCash ? 'Seller / source *' : 'Bank / lender *',
              hintText: _isDev ? 'e.g. Emaar, DAMAC' : _isCash ? 'e.g. private seller' : (_isl ? 'e.g. Mashreq Al Islami' : 'e.g. Emirates NBD'))),

          // The whole finance block is hidden for an outright cash purchase.
          if (!_isCash) ...[
          // ── Finance (from your statement) ─────────────────────────
          _sectionTitle(_isl ? 'Finance (from your statement)' : 'Finance', t),
          _money(_principal, _financeLabel, live: true,
              helper: _isl ? "Statement: 'Ijarah Finance Amount Disbursed'" : null),
          const SizedBox(height: AppSpacing.x12),
          Row(children: [
            Expanded(
              child: TextField(controller: _rate, keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                      labelText: _rateLabel,
                      helperText: _isl ? "Statement: 'Rental Rate' (variable)" : null)),
            ),
            const SizedBox(width: AppSpacing.x12),
            Expanded(child: _dateField(_rateValidLabel, _rateValidUntil, () => _pickDate(2))),
          ]),
          const SizedBox(height: AppSpacing.x12),
          TextField(controller: _years, keyboardType: TextInputType.number,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(labelText: _termLabel)),
          const SizedBox(height: AppSpacing.x12),
          Row(children: [
            Expanded(child: _dateField(_startLabel, _loanStart, () => _pickDate(0))),
            const SizedBox(width: AppSpacing.x12),
            Expanded(child: _dateField(_firstLabel, _firstInstallment, () => _pickDate(1))),
          ]),
          const SizedBox(height: AppSpacing.x16),
          Card(child: Padding(
            padding: const EdgeInsets.all(AppSpacing.x16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text(_monthlyLabel, style: t.bodyMedium),
                Text('AED ${_monthly.toStringAsFixed(0)}', style: t.titleLarge),
              ]),
              const SizedBox(height: 4),
              Text(
                _isl
                    ? 'Estimated at the current rate. Log each actual rental (fixed + variable) under Payments.'
                    : 'Estimated at the current rate. Log each actual installment under Payments.',
                style: t.bodySmall?.copyWith(color: Theme.of(context).hintColor),
              ),
            ]),
          )),

          // ── Takaful / insurance ───────────────────────────────────
          _sectionTitle(_isl ? 'Takaful' : 'Insurance', t),
          Row(children: [
            Expanded(child: _money(_propInsurance, _propInsLabel)),
            const SizedBox(width: AppSpacing.x12),
            Expanded(child: _money(_lifeInsurance, _lifeInsLabel)),
          ]),
          const SizedBox(height: AppSpacing.x12),
          DropdownButtonFormField<String>(
            initialValue: _insuranceFreq,
            decoration: InputDecoration(labelText: _insFreqLabel),
            items: const [
              DropdownMenuItem(value: 'monthly', child: Text('Monthly')),
              DropdownMenuItem(value: 'yearly', child: Text('Yearly')),
            ],
            onChanged: (v) => setState(() => _insuranceFreq = v ?? 'yearly'),
          ),

          // ── Fixed intro period (optional) ─────────────────────────
          _sectionTitle('Fixed intro period (optional)', t),
          Row(children: [
            Expanded(
              child: TextField(controller: _fixedMonths, keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Fixed for (months)')),
            ),
            const SizedBox(width: AppSpacing.x12),
            Expanded(
              child: TextField(controller: _rateAfter, keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(labelText: _isl ? 'Profit rate after (%)' : 'Rate after (%)')),
            ),
          ]),
          ], // end if (!_isCash)

          // ── Purchase costs ────────────────────────────────────────
          _sectionTitle('Purchase costs', t),
          _money(_projectValue, 'Total property value *'),
          const SizedBox(height: AppSpacing.x12),
          Row(children: [
            Expanded(child: _money(_dld, 'DLD charges *', helper: 'e.g. 4% of value')),
            const SizedBox(width: AppSpacing.x12),
            Expanded(child: _money(_processing, 'Processing fees *')),
          ]),
          const SizedBox(height: AppSpacing.x12),
          _money(_downPayment, 'Down payment *', live: true),
          const SizedBox(height: AppSpacing.x8),
          for (var i = 0; i < _splits.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.x8),
              child: Row(children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _splits[i].label,
                    decoration: const InputDecoration(
                        labelText: 'Split', hintText: 'e.g. Booking', isDense: true)),
                ),
                const SizedBox(width: AppSpacing.x8),
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _splits[i].amount,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(labelText: 'Amount', prefixText: 'AED ', isDense: true)),
                ),
                IconButton(
                  tooltip: 'Remove',
                  onPressed: () => setState(() => _splits.removeAt(i).dispose()),
                  icon: const Icon(Icons.close, size: 18)),
              ]),
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => setState(() => _splits.add(_SplitRow())),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add down-payment split'),
            ),
          ),
          if (_splits.isNotEmpty)
            Text('Splits total: AED ${_splitTotal.toStringAsFixed(0)}',
                style: t.bodySmall?.copyWith(color: Theme.of(context).hintColor)),

          if (_error != null) ...[
            const SizedBox(height: AppSpacing.x12),
            Text(_error!, style: t.bodySmall?.copyWith(color: Theme.of(context).colorScheme.error)),
          ],
          const SizedBox(height: AppSpacing.x20),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Save'),
          ),
        ],
      ),
    );
  }
}
