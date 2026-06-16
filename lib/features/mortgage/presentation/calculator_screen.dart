import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/util/mortgage_math.dart';
import '../../auth/application/auth_controller.dart';
import '../../shell/app_shell.dart';

/// Mortgage calculator.
/// - Standalone screen at /calculator (its own Scaffold + scroll).
/// - Embedded (e.g. on the landing page) it renders as a plain Column so it
///   flows inside the parent's scroll view (no nested scrolling).
class CalculatorScreen extends ConsumerStatefulWidget {
  const CalculatorScreen({super.key, this.embedded = false});
  final bool embedded;
  @override
  ConsumerState<CalculatorScreen> createState() => _CalculatorScreenState();
}

class _CalculatorScreenState extends ConsumerState<CalculatorScreen> {
  double price = 1500000;
  double downPct = 20;
  double ratePct = 4.5;
  int years = 25;

  double get loan => price * (1 - downPct / 100);
  int get months => years * 12;
  double get monthly => MortgageMath.monthlyPayment(loan, ratePct, months);
  double get totalInterest => MortgageMath.totalInterest(loan, monthly, months);
  double get totalPaid => MortgageMath.totalPaid(monthly, months);

  final _aed = NumberFormat.currency(symbol: 'AED ', decimalDigits: 0);

  @override
  Widget build(BuildContext context) {
    final content = _content(context);
    if (widget.embedded) {
      return Padding(padding: const EdgeInsets.all(AppSpacing.x16), child: content);
    }
    // Signed-in users keep the full app menu (drawer); public visitors get a back button.
    final signedIn = ref.watch(authControllerProvider).isAuthenticated;
    return Scaffold(
      appBar: signedIn
          ? const NuzlAppBar(title: 'Mortgage calculator')
          : AppBar(
              title: const Text('Calculator'),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => context.canPop() ? context.pop() : context.go('/'),
              ),
            ),
      drawer: signedIn ? const NuzlDrawer() : null,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.x16),
        child: Center(
          child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 560), child: content),
        ),
      ),
    );
  }

  Widget _content(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final c = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Card(
          color: c.primary,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.x20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Estimated monthly payment',
                  style: t.bodySmall?.copyWith(color: Colors.white70)),
              const SizedBox(height: AppSpacing.x4),
              Text(_aed.format(monthly), style: t.displayLarge?.copyWith(color: Colors.white)),
              const SizedBox(height: AppSpacing.x12),
              Row(children: [
                _miniStat('Loan', _aed.format(loan), t),
                _miniStat('Total interest', _aed.format(totalInterest), t),
              ]),
            ]),
          ),
        ),
        const SizedBox(height: AppSpacing.x24),
        _slider('Property price', _aed.format(price), price, 300000, 15000000, 50000,
            (v) => setState(() => price = v), decimals: 0, title: 'property price (AED)'),
        _slider('Down payment', '${downPct.toStringAsFixed(0)}%', downPct, 0, 80, 1,
            (v) => setState(() => downPct = v), decimals: 0, title: 'down payment (%)'),
        _slider('Interest rate', '${ratePct.toStringAsFixed(2)}%', ratePct, 1, 10, 0.25,
            (v) => setState(() => ratePct = v), decimals: 2, title: 'interest rate (%)'),
        _slider('Term', '$years years', years.toDouble(), 5, 30, 1,
            (v) => setState(() => years = v.round()), decimals: 0, title: 'term (years)'),
        const SizedBox(height: AppSpacing.x16),
        Card(child: Padding(
          padding: const EdgeInsets.all(AppSpacing.x16),
          child: Column(children: [
            _row('Loan amount', _aed.format(loan), t),
            _row('Term', '$years years ($months payments)', t),
            _row('Total of payments', _aed.format(totalPaid), t),
            _row('Total interest', _aed.format(totalInterest), t),
          ]),
        )),
        if (!widget.embedded) ...[
          const SizedBox(height: AppSpacing.x24),
          if (ref.watch(authControllerProvider).isAuthenticated)
            FilledButton(
              onPressed: () => context.go('/mortgages'),
              child: const Text('Track real payments'),
            )
          else
            FilledButton(
              onPressed: () => context.go('/register'),
              child: const Text('Sign up to track real payments'),
            ),
        ],
      ],
    );
  }

  Widget _miniStat(String label, String value, TextTheme t) => Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: t.bodySmall?.copyWith(color: Colors.white70)),
          Text(value, style: t.titleMedium?.copyWith(color: Colors.white)),
        ]),
      );

  Widget _row(String k, String v, TextTheme t) => Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.x4),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(k, style: t.bodyMedium), Text(v, style: t.titleMedium),
        ]),
      );

  Widget _slider(String label, String value, double v, double min, double max,
      double step, ValueChanged<double> onChanged, {int decimals = 0, String title = ''}) {
    final t = Theme.of(context).textTheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: t.bodyMedium),
        // Tap the value to type an exact number (the slider only moves in steps).
        InkWell(
          borderRadius: BorderRadius.circular(AppSpacing.rSm),
          onTap: () => _edit(title.isEmpty ? label : title, v, min, max, decimals, onChanged),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text(value, style: t.titleMedium),
              const SizedBox(width: 4),
              Icon(Icons.edit_outlined, size: 15, color: Theme.of(context).hintColor),
            ]),
          ),
        ),
      ]),
      Slider(
        value: v.clamp(min, max),
        min: min, max: max,
        divisions: ((max - min) / step).round(),
        onChanged: onChanged,
      ),
      const SizedBox(height: AppSpacing.x8),
    ]);
  }

  /// Type an exact value (supports fractions the slider's steps can't reach).
  Future<void> _edit(String title, double current, double min, double max, int decimals,
      ValueChanged<double> onChanged) async {
    final ctrl = TextEditingController(
        text: decimals == 0 ? current.round().toString() : current.toStringAsFixed(decimals));
    final result = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Enter $title'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            helperText: 'From ${_bound(min, decimals)} to ${_bound(max, decimals)}',
          ),
          onSubmitted: (_) => Navigator.pop(ctx, double.tryParse(ctrl.text.trim())),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, double.tryParse(ctrl.text.trim())),
            child: const Text('Set'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (result != null) onChanged(result.clamp(min, max).toDouble());
  }

  String _bound(double v, int decimals) =>
      decimals == 0 ? NumberFormat.decimalPattern().format(v) : v.toStringAsFixed(decimals);
}
