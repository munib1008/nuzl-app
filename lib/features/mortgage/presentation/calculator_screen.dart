import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/util/mortgage_math.dart';

/// PUBLIC mortgage calculator — no login required.
/// Reachable at /calculator (e.g. from the login screen).
class CalculatorScreen extends StatefulWidget {
  const CalculatorScreen({super.key, this.embedded = false});
  /// When embedded (inside a logged-in tab) we hide the back button/app bar chrome.
  final bool embedded;

  @override
  State<CalculatorScreen> createState() => _CalculatorScreenState();
}

class _CalculatorScreenState extends State<CalculatorScreen> {
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
    final t = Theme.of(context).textTheme;
    final c = Theme.of(context).colorScheme;

    final body = ListView(
      padding: const EdgeInsets.all(AppSpacing.x16),
      children: [
        if (!widget.embedded) ...[
          Text('Mortgage calculator', style: t.headlineMedium),
          const SizedBox(height: AppSpacing.x4),
          Text('Estimate your monthly payment. UAE expat down payment is typically 20%+.',
              style: t.bodySmall),
          const SizedBox(height: AppSpacing.x24),
        ],
        // Result card
        Card(
          color: c.primary,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.x20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Estimated monthly payment',
                  style: t.bodySmall?.copyWith(color: Colors.white70)),
              const SizedBox(height: AppSpacing.x4),
              Text(_aed.format(monthly),
                  style: t.displayLarge?.copyWith(color: Colors.white)),
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
            (v) => setState(() => price = v)),
        _slider('Down payment', '${downPct.toStringAsFixed(0)}%', downPct, 0, 80, 1,
            (v) => setState(() => downPct = v)),
        _slider('Interest rate', '${ratePct.toStringAsFixed(2)}%', ratePct, 1, 10, 0.25,
            (v) => setState(() => ratePct = v)),
        _slider('Term', '$years years', years.toDouble(), 5, 30, 1,
            (v) => setState(() => years = v.round())),
        const SizedBox(height: AppSpacing.x16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.x16),
            child: Column(children: [
              _row('Loan amount', _aed.format(loan), t),
              _row('Term', '$years years ($months payments)', t),
              _row('Total of payments', _aed.format(totalPaid), t),
              _row('Total interest', _aed.format(totalInterest), t),
            ]),
          ),
        ),
        if (!widget.embedded) ...[
          const SizedBox(height: AppSpacing.x24),
          Text('Want to track real payments against a mortgage?', style: t.bodySmall),
          const SizedBox(height: AppSpacing.x8),
          FilledButton(
            onPressed: () => context.go('/login'),
            child: const Text('Sign in to track payments'),
          ),
        ],
      ],
    );

    if (widget.embedded) return body;
    return Scaffold(appBar: AppBar(title: const Text('Calculator')), body: body);
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
          Text(k, style: t.bodyMedium),
          Text(v, style: t.titleMedium),
        ]),
      );

  Widget _slider(String label, String value, double v, double min, double max,
      double step, ValueChanged<double> onChanged) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: Theme.of(context).textTheme.bodyMedium),
        Text(value, style: Theme.of(context).textTheme.titleMedium),
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
}
