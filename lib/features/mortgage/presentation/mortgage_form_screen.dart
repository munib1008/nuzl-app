import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/util/mortgage_math.dart';
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

/// Set up a tracked mortgage. Captures the full purchase + financing picture
/// (owner #16/#17): project value, fees, down payment (with split), loan, key
/// dates and insurance — then powers the payment tracker. Auto-computes the
/// monthly payment as you type, and can capture a fixed-then-floating rate.
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
  // Tracking-setup fields (owner #16) — mandatory.
  final _projectValue = TextEditingController();
  final _dld = TextEditingController();
  final _processing = TextEditingController();
  final _downPayment = TextEditingController();
  final _propInsurance = TextEditingController();
  final _lifeInsurance = TextEditingController();
  final List<_SplitRow> _splits = [];
  DateTime? _loanStart;
  DateTime? _firstInstallment;
  String _insuranceFreq = 'yearly';
  String? _propertyId;
  bool _saving = false;
  String? _error;

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

  Future<void> _pickDate(bool start) async {
    final now = DateTime.now();
    final init = (start ? _loanStart : _firstInstallment) ?? now;
    final d = await showDatePicker(
      context: context,
      initialDate: init,
      firstDate: DateTime(now.year - 30),
      lastDate: DateTime(now.year + 30),
    );
    if (d == null) return;
    setState(() {
      if (start) {
        _loanStart = d;
      } else {
        _firstInstallment = d;
      }
    });
  }

  /// First validation problem (mandatory tracking fields), or null if all good.
  String? _validate() {
    double? pos(TextEditingController c) {
      final v = double.tryParse(c.text.trim());
      return (v == null || v <= 0) ? null : v;
    }
    if (_label.text.trim().isEmpty) return 'Name this mortgage.';
    if (_lender.text.trim().isEmpty) return 'Enter the lender.';
    if (pos(_projectValue) == null) return 'Total project value is required.';
    if (pos(_dld) == null) return 'DLD charges are required.';
    if (pos(_processing) == null) return 'Processing fees are required.';
    if (pos(_downPayment) == null) return 'Down payment is required.';
    if (pos(_principal) == null) return 'Loan amount is required.';
    if ((double.tryParse(_rate.text.trim()) ?? -1) < 0) return 'Enter a valid interest rate.';
    if ((int.tryParse(_years.text.trim()) ?? 0) <= 0) return 'Enter the loan term in years.';
    if (_loanStart == null) return 'Pick the loan start date.';
    if (_firstInstallment == null) return 'Pick the first installment date.';
    if (pos(_propInsurance) == null) return 'Property insurance cost is required.';
    if (pos(_lifeInsurance) == null) return 'Life insurance cost is required.';
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
    try {
      await ref.read(mortgageRepositoryProvider).create({
        'label': _label.text.trim(),
        'lender': _lender.text.trim(),
        'principal': n(_principal),
        'interest_rate': double.tryParse(_rate.text) ?? 0,
        'term_months': (int.tryParse(_years.text) ?? 0) * 12,
        'monthly_payment': double.parse(_monthly.toStringAsFixed(2)),
        'total_project_value': n(_projectValue),
        'dld_charges': n(_dld),
        'processing_fees': n(_processing),
        'down_payment': n(_downPayment),
        if (splits.isNotEmpty) 'down_payment_splits': splits,
        'start_date': iso.format(_loanStart!),
        'first_installment_date': iso.format(_firstInstallment!),
        'property_insurance_cost': n(_propInsurance),
        'life_insurance_cost': n(_lifeInsurance),
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

  Widget _money(TextEditingController c, String label, {bool live = false}) => TextField(
        controller: c,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        onChanged: live ? (_) => setState(() {}) : null,
        decoration: InputDecoration(labelText: label, prefixText: 'AED '),
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
      appBar: AppBar(title: const Text('Track a mortgage')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.x16),
        children: [
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
                // Show "Building name - Unit number" so the owner recognises which
                // property this is, not a generic label (owner #13).
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
              labelText: 'Name this mortgage *', hintText: 'e.g. Marina apartment')),
          const SizedBox(height: AppSpacing.x12),
          TextField(controller: _lender, decoration: const InputDecoration(
              labelText: 'Lender *', hintText: 'e.g. Emirates NBD')),

          // ── Purchase costs ───────────────────────────────────────
          _sectionTitle('Purchase costs', t),
          _money(_projectValue, 'Total project value *'),
          const SizedBox(height: AppSpacing.x12),
          Row(children: [
            Expanded(child: _money(_dld, 'DLD charges *')),
            const SizedBox(width: AppSpacing.x12),
            Expanded(child: _money(_processing, 'Processing fees *')),
          ]),

          // ── Financing ────────────────────────────────────────────
          _sectionTitle('Financing', t),
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
          const SizedBox(height: AppSpacing.x12),
          _money(_principal, 'Loan amount *', live: true),
          const SizedBox(height: AppSpacing.x12),
          Row(children: [
            Expanded(
              child: TextField(controller: _rate, keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(labelText: 'Interest rate (% / yr) *')),
            ),
            const SizedBox(width: AppSpacing.x12),
            Expanded(
              child: TextField(controller: _years, keyboardType: TextInputType.number,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(labelText: 'Term (years) *')),
            ),
          ]),

          // ── Variable rate (optional) ─────────────────────────────
          _sectionTitle('Variable rate (optional)', t),
          Row(children: [
            Expanded(
              child: TextField(controller: _fixedMonths, keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Fixed for (months)')),
            ),
            const SizedBox(width: AppSpacing.x12),
            Expanded(
              child: TextField(controller: _rateAfter, keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Rate after (%)')),
            ),
          ]),

          // ── Dates & insurance ────────────────────────────────────
          _sectionTitle('Dates & insurance', t),
          Row(children: [
            Expanded(child: _dateField('Loan start date *', _loanStart, () => _pickDate(true))),
            const SizedBox(width: AppSpacing.x12),
            Expanded(child: _dateField('First installment *', _firstInstallment, () => _pickDate(false))),
          ]),
          const SizedBox(height: AppSpacing.x12),
          Row(children: [
            Expanded(child: _money(_propInsurance, 'Property insurance *')),
            const SizedBox(width: AppSpacing.x12),
            Expanded(child: _money(_lifeInsurance, 'Life insurance *')),
          ]),
          const SizedBox(height: AppSpacing.x12),
          DropdownButtonFormField<String>(
            initialValue: _insuranceFreq,
            decoration: const InputDecoration(labelText: 'Insurance frequency *'),
            items: const [
              DropdownMenuItem(value: 'monthly', child: Text('Monthly')),
              DropdownMenuItem(value: 'yearly', child: Text('Yearly')),
            ],
            onChanged: (v) => setState(() => _insuranceFreq = v ?? 'yearly'),
          ),

          const SizedBox(height: AppSpacing.x20),
          Card(child: Padding(
            padding: const EdgeInsets.all(AppSpacing.x16),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('Monthly payment', style: t.bodyMedium),
              Text('AED ${_monthly.toStringAsFixed(0)}', style: t.titleLarge),
            ]),
          )),
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.x12),
            Text(_error!, style: t.bodySmall?.copyWith(color: Theme.of(context).colorScheme.error)),
          ],
          const SizedBox(height: AppSpacing.x20),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Save mortgage'),
          ),
        ],
      ),
    );
  }
}
