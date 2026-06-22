import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/util/mortgage_math.dart';
import '../../../core/widgets/field_pair.dart';
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

/// Set up a tracked home finance (owner #16/#17) as a guided 4-step wizard —
/// Property → Costs → Finance → Schedule. Speaks your statement's language: for
/// an Islamic (Ijarah) product it relabels interest -> profit / rental and
/// insurance -> Takaful. The final step previews the amortization before saving,
/// then the record powers the payment tracker.
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
  final _registration = TextEditingController();
  final _downPayment = TextEditingController();
  final _propInsurance = TextEditingController();
  final _lifeInsurance = TextEditingController();
  final List<_SplitRow> _splits = [];
  DateTime? _loanStart;
  DateTime? _firstInstallment;
  DateTime? _rateValidUntil;
  DateTime? _insStart;
  DateTime? _insRenewal;
  String _insuranceFreq = 'yearly';
  String _financeType = 'ijarah'; // UAE home finance is predominantly Ijarah
  String? _propertyId;
  int _step = 0;
  bool _saving = false;
  String? _error;

  static const _stepLabels = ['Property', 'Costs', 'Finance', 'Schedule'];

  bool get _isl => isIslamicFinance(_financeType);
  bool get _isCash => isCashPurchase(_financeType);
  bool get _isDev => isDeveloperPlan(_financeType);

  // ── Statement-aware lexicon ────────────────────────────────────────────
  String get _financeLabel => context.tr(_isl ? 'Finance amount (AED) *' : 'Loan amount (AED) *');
  String get _rateLabel => context.tr(_isl ? 'Profit rate (% / yr) *' : 'Interest rate (% / yr) *');
  String get _termLabel => context.tr(_isl ? 'Ijarah period (years) *' : 'Term (years) *');
  String get _monthlyLabel => context.tr(_isl ? 'Estimated monthly rental' : 'Estimated monthly payment');
  String get _propInsLabel => context.tr(_isl ? 'Property Takaful *' : 'Property insurance *');
  String get _lifeInsLabel => context.tr(_isl ? 'Life Takaful *' : 'Life insurance *');
  String get _insFreqLabel => context.tr(_isl ? 'Takaful frequency *' : 'Insurance frequency *');
  String get _startLabel => context.tr(_isl ? 'Disbursal date *' : 'Loan start date *');
  String get _firstLabel => context.tr(_isl ? 'First rental date *' : 'First installment *');
  String get _rateValidLabel => context.tr(_isl ? 'Profit rate valid until' : 'Rate review date');

  @override
  void dispose() {
    for (final c in [_label, _lender, _principal, _rate, _years, _fixedMonths, _rateAfter,
        _projectValue, _dld, _processing, _registration, _downPayment, _propInsurance, _lifeInsurance]) {
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

  double? _pos(TextEditingController c) {
    final v = double.tryParse(c.text.trim());
    return (v == null || v <= 0) ? null : v;
  }

  Future<void> _pickDate(int which) async {
    final now = DateTime.now();
    final current = switch (which) {
      0 => _loanStart,
      1 => _firstInstallment,
      2 => _rateValidUntil,
      3 => _insStart,
      _ => _insRenewal,
    };
    final d = await showDatePicker(
      context: context,
      initialDate: current ?? now,
      firstDate: DateTime(now.year - 30),
      lastDate: DateTime(now.year + 30),
    );
    if (d == null) return;
    setState(() {
      switch (which) {
        case 0:
          _loanStart = d;
        case 1:
          _firstInstallment = d;
        case 2:
          _rateValidUntil = d;
        case 3:
          _insStart = d;
        default:
          _insRenewal = d;
      }
    });
  }

  /// First validation problem on [step] (0 Property · 1 Costs · 2 Finance), or
  /// null when the step is complete. The Schedule step has no inputs.
  String? _validateStep(int step) {
    final fin = context.tr(_isl ? 'finance amount' : 'loan amount');
    final rate = context.tr(_isl ? 'profit rate' : 'interest rate');
    final period = context.tr(_isl ? 'Ijarah period' : 'term');
    final propIns = context.tr(_isl ? 'property Takaful' : 'property insurance');
    final lifeIns = context.tr(_isl ? 'life Takaful' : 'life insurance');
    switch (step) {
      case 0: // Property
        if (_label.text.trim().isEmpty) return context.tr('Name this finance.');
        if (_lender.text.trim().isEmpty) {
          return '${context.tr('Enter the')} ${context.tr(_isDev ? 'developer / provider' : _isCash ? 'seller / source' : 'bank / lender')}.';
        }
        if (_pos(_projectValue) == null) return context.tr('Total property value is required.');
        return null;
      case 1: // Costs
        if (_pos(_dld) == null) return context.tr('DLD charges are required.');
        if (_pos(_processing) == null) return context.tr('Processing fees are required.');
        if (_pos(_downPayment) == null) return context.tr('Down payment is required.');
        if (!_isCash && !_isDev) {
          if (_pos(_propInsurance) == null) return '${context.tr('The')} $propIns ${context.tr('is required.')}';
          if (_pos(_lifeInsurance) == null) return '${context.tr('The')} $lifeIns ${context.tr('is required.')}';
        }
        if (_splits.isNotEmpty && _splitTotal > 0) {
          final dp = double.tryParse(_downPayment.text.trim()) ?? 0;
          if ((_splitTotal - dp).abs() > 1) {
            return '${context.tr('Down-payment splits')} (AED ${_splitTotal.toStringAsFixed(0)}) ${context.tr('must add up to the down payment')} '
                '(AED ${dp.toStringAsFixed(0)}).';
          }
        }
        return null;
      case 2: // Finance (skipped for an outright cash purchase)
        if (_isCash) return null;
        if (_pos(_principal) == null) return '${context.tr('The')} $fin ${context.tr('is required.')}';
        if ((double.tryParse(_rate.text.trim()) ?? -1) < 0) return '${context.tr('Enter a valid')} $rate.';
        if ((int.tryParse(_years.text.trim()) ?? 0) <= 0) return '${context.tr('Enter the')} $period ${context.tr('in years.')}';
        if (_loanStart == null) return '${context.tr('Pick the')} ${context.tr(_isl ? 'disbursal' : 'loan start')} ${context.tr('date.')}';
        if (_firstInstallment == null) return '${context.tr('Pick the first')} ${context.tr(_isl ? 'rental' : 'installment')} ${context.tr('date.')}';
        return null;
      default:
        return null;
    }
  }

  void _onPrimary() {
    if (_step < 3) {
      final problem = _validateStep(_step);
      if (problem != null) {
        setState(() => _error = problem);
        return;
      }
      setState(() {
        _step++;
        _error = null;
      });
      return;
    }
    _save();
  }

  Future<void> _save() async {
    // Re-validate every input step and jump back to the first with a problem.
    for (final step in [0, 1, 2]) {
      final problem = _validateStep(step);
      if (problem != null) {
        setState(() {
          _step = step;
          _error = problem;
        });
        return;
      }
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
        'registration_fees': n(_registration),
        if (!_isCash && _insStart != null) 'insurance_start_date': iso.format(_insStart!),
        if (!_isCash && _insRenewal != null) 'insurance_renewal_date': iso.format(_insRenewal!),
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

  // ── Reusable field builders ───────────────────────────────────────────
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
          child: Text(value == null ? context.tr('Select date') : DateFormat.yMMMd().format(value),
              style: TextStyle(color: value == null ? Theme.of(context).hintColor : null)),
        ),
      );

  Widget _stepIntro(TextTheme t, String title, String subtitle) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.x16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: t.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(subtitle, style: t.bodySmall?.copyWith(color: Theme.of(context).hintColor)),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('Track a home finance'))),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.x16, AppSpacing.x16, AppSpacing.x16, AppSpacing.x8),
          child: _stepHeader(t),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.x16),
            children: _stepBody(t),
          ),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.x16, AppSpacing.x8, AppSpacing.x16, 0),
            child: Row(children: [
              Icon(Icons.error_outline, size: 16, color: Theme.of(context).colorScheme.error),
              const SizedBox(width: 6),
              Expanded(child: Text(_error!, style: t.bodySmall?.copyWith(color: Theme.of(context).colorScheme.error))),
            ]),
          ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.x16),
            child: Row(children: [
              if (_step > 0) ...[
                Expanded(
                  child: OutlinedButton(
                    onPressed: _saving ? null : () => setState(() { _step--; _error = null; }),
                    child: Text(context.tr('Back')),
                  ),
                ),
                const SizedBox(width: AppSpacing.x12),
              ],
              Expanded(
                flex: 2,
                child: FilledButton(
                  onPressed: _saving ? null : _onPrimary,
                  child: _saving
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text(context.tr(_step < 3 ? 'Continue' : 'Save finance')),
                ),
              ),
            ]),
          ),
        ),
      ]),
    );
  }

  // Four-step progress indicator: numbered dots, completed dots show a check,
  // connectors fill in as you advance.
  Widget _stepHeader(TextTheme t) {
    final primary = Theme.of(context).colorScheme.primary;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final border = Theme.of(context).dividerColor;
    final muted = Theme.of(context).hintColor;
    Widget dot(int i) {
      final done = i < _step;
      final active = i == _step;
      return Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 28, height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? primary : (done ? primary.withValues(alpha: 0.12) : Colors.transparent),
            shape: BoxShape.circle,
            border: Border.all(color: (done || active) ? primary : border, width: 1.5),
          ),
          child: done
              ? Icon(Icons.check, size: 16, color: primary)
              : Text('${i + 1}',
                  style: t.labelSmall?.copyWith(color: active ? Colors.white : muted, fontWeight: FontWeight.w700)),
        ),
        const SizedBox(height: 4),
        Text(context.tr(_stepLabels[i]),
            style: t.labelSmall?.copyWith(
                color: (done || active) ? onSurface : muted,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500)),
      ]);
    }
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      for (var i = 0; i < 4; i++) ...[
        dot(i),
        if (i < 3)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 13, left: 4, right: 4),
              child: Container(height: 2, color: i < _step ? primary : border),
            ),
          ),
      ],
    ]);
  }

  List<Widget> _stepBody(TextTheme t) => switch (_step) {
        0 => _stepProperty(t),
        1 => _stepCosts(t),
        2 => _stepFinance(t),
        _ => _stepSchedule(t),
      };

  // ── Step 1 — Property ──────────────────────────────────────────────────
  List<Widget> _stepProperty(TextTheme t) => [
        _stepIntro(t, context.tr('Which property?'), context.tr('Choose the finance type and tell us what you’re buying.')),
        DropdownButtonFormField<String>(
          initialValue: _financeType,
          isExpanded: true,
          decoration: InputDecoration(labelText: context.tr('Finance type')),
          items: [for (final f in kFinanceTypes) DropdownMenuItem(value: f.$1, child: Text(context.tr(f.$2)))],
          onChanged: (v) => setState(() => _financeType = v ?? 'conventional'),
        ),
        const SizedBox(height: AppSpacing.x12),
        ref.watch(_ownerPropsProvider).maybeWhen(
              data: (list) {
                final items = <DropdownMenuItem<String?>>[
                  DropdownMenuItem(value: null, child: Text(context.tr('Not linked to a property'))),
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
                      : (un.isNotEmpty ? '${context.tr('Unit')} $un' : (comm.isNotEmpty ? comm : context.tr('Property')));
                  items.add(DropdownMenuItem(value: pid, child: Text(label, overflow: TextOverflow.ellipsis)));
                }
                return DropdownButtonFormField<String?>(
                  initialValue: _propertyId,
                  isExpanded: true,
                  decoration: InputDecoration(labelText: context.tr('Link to a property (optional)')),
                  items: items,
                  onChanged: (v) => setState(() => _propertyId = v),
                );
              },
              orElse: () => const SizedBox.shrink(),
            ),
        const SizedBox(height: AppSpacing.x12),
        TextField(
            controller: _label,
            decoration: InputDecoration(labelText: context.tr('Name this finance *'), hintText: context.tr('e.g. Star by Azizi 619'))),
        const SizedBox(height: AppSpacing.x12),
        TextField(
            controller: _lender,
            decoration: InputDecoration(
                labelText: context.tr(_isDev ? 'Developer / provider *' : _isCash ? 'Seller / source *' : 'Bank / lender *'),
                hintText: context.tr(_isDev
                    ? 'e.g. Emaar, DAMAC'
                    : _isCash
                        ? 'e.g. private seller'
                        : (_isl ? 'e.g. Mashreq Al Islami' : 'e.g. Emirates NBD')))),
        const SizedBox(height: AppSpacing.x12),
        _money(_projectValue, context.tr('Total property value *'), live: true),
      ];

  // ── Step 2 — Costs ─────────────────────────────────────────────────────
  List<Widget> _stepCosts(TextTheme t) => [
        _stepIntro(t, context.tr('Purchase costs'),
            '${context.tr('Upfront cash')}${_isCash ? '' : ' ${_isl ? context.tr('and Takaful') : context.tr('and insurance')}'}.'),
        FieldPair(
          _money(_dld, context.tr('DLD charges *'), helper: context.tr('e.g. 4% of value')),
          _money(_processing, context.tr('Processing fees *')),
        ),
        const SizedBox(height: AppSpacing.x12),
        _money(_registration, context.tr('Registration fees')),
        const SizedBox(height: AppSpacing.x12),
        _money(_downPayment, context.tr('Down payment *'), live: true),
        const SizedBox(height: AppSpacing.x8),
        for (var i = 0; i < _splits.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.x8),
            child: Row(children: [
              Expanded(
                flex: 3,
                child: TextField(
                    controller: _splits[i].label,
                    decoration: InputDecoration(labelText: context.tr('Split'), hintText: context.tr('e.g. Booking'), isDense: true)),
              ),
              const SizedBox(width: AppSpacing.x8),
              Expanded(
                flex: 2,
                child: TextField(
                    controller: _splits[i].amount,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(labelText: context.tr('Amount'), prefixText: 'AED ', isDense: true)),
              ),
              IconButton(
                  tooltip: context.tr('Remove'),
                  onPressed: () => setState(() => _splits.removeAt(i).dispose()),
                  icon: const Icon(Icons.close, size: 18)),
            ]),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => setState(() => _splits.add(_SplitRow())),
            icon: const Icon(Icons.add, size: 18),
            label: Text(context.tr('Add down-payment split')),
          ),
        ),
        if (_splits.isNotEmpty)
          Text('${context.tr('Splits total')}: AED ${_splitTotal.toStringAsFixed(0)}',
              style: t.bodySmall?.copyWith(color: Theme.of(context).hintColor)),
        // Insurance / Takaful — only for financed products.
        if (!_isCash) ...[
          _sectionTitle(context.tr(_isl ? 'Takaful' : 'Insurance'), t),
          FieldPair(
            _money(_propInsurance, _propInsLabel),
            _money(_lifeInsurance, _lifeInsLabel),
          ),
          const SizedBox(height: AppSpacing.x12),
          DropdownButtonFormField<String>(
            initialValue: _insuranceFreq,
            decoration: InputDecoration(labelText: _insFreqLabel),
            items: [
              DropdownMenuItem(value: 'monthly', child: Text(context.tr('Monthly'))),
              DropdownMenuItem(value: 'yearly', child: Text(context.tr('Yearly'))),
            ],
            onChanged: (v) => setState(() => _insuranceFreq = v ?? 'yearly'),
          ),
          const SizedBox(height: AppSpacing.x12),
          FieldPair(
            _dateField(context.tr(_isl ? 'Takaful start' : 'Insurance start'), _insStart, () => _pickDate(3)),
            _dateField(context.tr('Renewal date'), _insRenewal, () => _pickDate(4)),
          ),
        ],
      ];

  // ── Step 3 — Finance ───────────────────────────────────────────────────
  List<Widget> _stepFinance(TextTheme t) {
    if (_isCash) {
      return [
        _stepIntro(t, context.tr('Financing'), context.tr('Cash purchase — nothing to finance.')),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.x16),
            child: Row(children: [
              Icon(Icons.payments_outlined, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: AppSpacing.x12),
              Expanded(
                child: Text(context.tr('This is an outright cash purchase, so there is no loan or rental schedule. Continue to review your upfront costs.'),
                    style: t.bodySmall?.copyWith(color: Theme.of(context).hintColor)),
              ),
            ]),
          ),
        ),
      ];
    }
    return [
      _stepIntro(t, context.tr('Financing'), context.tr(_isl ? 'Enter the numbers from your statement.' : 'Enter your loan terms.')),
      _money(_principal, _financeLabel, live: true,
          helper: _isl ? context.tr("Statement: 'Ijarah Finance Amount Disbursed'") : null),
      const SizedBox(height: AppSpacing.x12),
      FieldPair(
        TextField(
            controller: _rate,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
                labelText: _rateLabel, helperText: _isl ? context.tr("Statement: 'Rental Rate' (variable)") : null)),
        _dateField(_rateValidLabel, _rateValidUntil, () => _pickDate(2)),
      ),
      const SizedBox(height: AppSpacing.x12),
      TextField(
          controller: _years,
          keyboardType: TextInputType.number,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(labelText: _termLabel)),
      const SizedBox(height: AppSpacing.x12),
      FieldPair(
        _dateField(_startLabel, _loanStart, () => _pickDate(0)),
        _dateField(_firstLabel, _firstInstallment, () => _pickDate(1)),
      ),
      const SizedBox(height: AppSpacing.x16),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.x16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text(_monthlyLabel, style: t.bodyMedium),
              Text('AED ${_monthly.toStringAsFixed(0)}', style: t.titleLarge),
            ]),
            const SizedBox(height: 4),
            Text(
              context.tr(_isl
                  ? 'Estimated at the current rate. Log each actual rental (fixed + variable) under Payments.'
                  : 'Estimated at the current rate. Log each actual installment under Payments.'),
              style: t.bodySmall?.copyWith(color: Theme.of(context).hintColor),
            ),
          ]),
        ),
      ),
      _sectionTitle(context.tr('Fixed intro period (optional)'), t),
      FieldPair(
        TextField(
            controller: _fixedMonths,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(labelText: context.tr('Fixed for (months)'))),
        TextField(
            controller: _rateAfter,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: context.tr(_isl ? 'Profit rate after (%)' : 'Rate after (%)'))),
      ),
    ];
  }

  // ── Step 4 — Schedule (review + amortization preview) ──────────────────
  List<Widget> _stepSchedule(TextTheme t) {
    final hint = Theme.of(context).hintColor;
    final primary = Theme.of(context).colorScheme.primary;
    final aed0 = NumberFormat.currency(symbol: 'AED ', decimalDigits: 0);
    double n(TextEditingController c) => double.tryParse(c.text.trim()) ?? 0;
    final upfront = n(_downPayment) + n(_dld) + n(_processing) + n(_registration);

    final widgets = <Widget>[
      _stepIntro(t, context.tr('Review & schedule'), context.tr('Confirm the numbers, then save to start tracking payments.')),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.x16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(context.tr('Upfront cash'), style: t.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: AppSpacing.x8),
            _kv(context.tr('Down payment'), aed0.format(n(_downPayment))),
            _kv(context.tr('DLD charges'), aed0.format(n(_dld))),
            _kv(context.tr('Processing fees'), aed0.format(n(_processing))),
            if (n(_registration) > 0) _kv(context.tr('Registration fees'), aed0.format(n(_registration))),
            const Divider(height: AppSpacing.x16),
            _kv(context.tr('Total upfront'), aed0.format(upfront), bold: true),
          ]),
        ),
      ),
    ];

    if (!_isCash) {
      final p = n(_principal);
      final rate = double.tryParse(_rate.text) ?? 0;
      final years = int.tryParse(_years.text) ?? 0;
      final months = years * 12;
      if (p > 0 && years > 0) {
        final monthly = _monthly;
        final totalPaid = MortgageMath.totalPaid(monthly, months);
        final totalInterest = MortgageMath.totalInterest(p, monthly, months);
        widgets.addAll([
          const SizedBox(height: AppSpacing.x12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.x16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text(_monthlyLabel, style: t.bodyMedium),
                  Text(aed0.format(monthly),
                      style: t.titleLarge?.copyWith(color: primary, fontWeight: FontWeight.w700)),
                ]),
                const Divider(height: AppSpacing.x16),
                _kv(context.tr(_isl ? 'Finance amount' : 'Loan amount'), aed0.format(p)),
                _kv(context.tr(_isl ? 'Profit rate' : 'Interest rate'), '${rate.toStringAsFixed(2)} %'),
                _kv(context.tr('Term'), '$years ${context.tr('years')}'),
                _kv(context.tr(_isl ? 'Total profit' : 'Total interest'), aed0.format(totalInterest)),
                _kv(context.tr('Total repayment'), aed0.format(totalPaid), bold: true),
              ]),
            ),
          ),
          const SizedBox(height: AppSpacing.x16),
          Text(context.tr(_isl ? 'Yearly rental schedule' : 'Yearly amortization'),
              style: t.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: AppSpacing.x8),
          _amortTable(t, p, rate, months, monthly, aed0),
          const SizedBox(height: AppSpacing.x8),
          Text(
            '${context.tr('Estimated at the current rate. Actual')} ${context.tr(_isl ? 'rentals' : 'installments')} ${context.tr('are logged under Payments.')}',
            style: t.bodySmall?.copyWith(color: hint),
          ),
        ]);
      } else {
        widgets.add(Padding(
          padding: const EdgeInsets.only(top: AppSpacing.x12),
          child: Text(context.tr('Add the finance amount and term to preview the schedule.'),
              style: t.bodySmall?.copyWith(color: hint)),
        ));
      }
    }
    return widgets;
  }

  Widget _kv(String k, String v, {bool bold = false}) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(children: [
        Expanded(child: Text(k, style: t.bodySmall?.copyWith(color: Theme.of(context).hintColor))),
        Text(v,
            style: (bold ? t.bodyMedium : t.bodySmall)
                ?.copyWith(fontWeight: bold ? FontWeight.w700 : FontWeight.w600)),
      ]),
    );
  }

  Widget _amortTable(TextTheme t, double p, double rate, int months, double monthly, NumberFormat aed0) {
    final border = Theme.of(context).dividerColor;
    final hint = Theme.of(context).hintColor;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final years = (months / 12).ceil();
    Widget cell(String s, {bool header = false, TextAlign align = TextAlign.right}) => Expanded(
          child: Text(s,
              textAlign: align,
              style: t.labelSmall?.copyWith(
                  color: header ? onSurface : hint, fontWeight: header ? FontWeight.w700 : FontWeight.w500)),
        );
    final rows = <Widget>[
      Row(children: [
        cell(context.tr('Year'), header: true, align: TextAlign.left),
        cell(context.tr(_isl ? 'Profit' : 'Interest'), header: true),
        cell(context.tr('Principal'), header: true),
        cell(context.tr('Balance'), header: true),
      ]),
      const SizedBox(height: 6),
    ];
    for (var y = 1; y <= years; y++) {
      final bStart = MortgageMath.balanceAfter(p, rate, months, (y - 1) * 12);
      final bEnd = MortgageMath.balanceAfter(p, rate, months, y * 12);
      final principalPaid = bStart - bEnd;
      final paidMonths = (months - (y - 1) * 12) < 12 ? (months - (y - 1) * 12) : 12;
      final interest = (monthly * paidMonths) - principalPaid;
      rows.add(Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(children: [
          cell('$y', align: TextAlign.left),
          cell(aed0.format(interest < 0 ? 0 : interest)),
          cell(aed0.format(principalPaid < 0 ? 0 : principalPaid)),
          cell(aed0.format(bEnd)),
        ]),
      ));
      if (y < years) rows.add(Divider(height: 1, color: border));
    }
    // Keep the proportional columns, but never let the AED values crush: hold a
    // 440px minimum and scroll horizontally below that (phones) instead.
    return LayoutBuilder(builder: (context, c) {
      final tableWidth = c.maxWidth < 440 ? 440.0 : c.maxWidth;
      final table = Container(
        width: tableWidth,
        padding: const EdgeInsets.all(AppSpacing.x12),
        decoration:
            BoxDecoration(border: Border.all(color: border), borderRadius: BorderRadius.circular(AppSpacing.rMd)),
        child: Column(children: rows),
      );
      return c.maxWidth < 440
          ? SingleChildScrollView(scrollDirection: Axis.horizontal, child: table)
          : table;
    });
  }
}
