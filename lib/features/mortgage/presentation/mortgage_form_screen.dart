import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/util/mortgage_math.dart';
import '../data/mortgage_repository.dart';

/// Add a mortgage to track. Auto-computes the monthly payment as you type.
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
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _label.dispose(); _lender.dispose(); _principal.dispose(); _rate.dispose(); _years.dispose();
    super.dispose();
  }

  double get _monthly {
    final p = double.tryParse(_principal.text) ?? 0;
    final r = double.tryParse(_rate.text) ?? 0;
    final y = int.tryParse(_years.text) ?? 0;
    return MortgageMath.monthlyPayment(p, r, y * 12);
  }

  Future<void> _save() async {
    setState(() { _saving = true; _error = null; });
    try {
      await ref.read(mortgageRepositoryProvider).create({
        'label': _label.text.trim(),
        'lender': _lender.text.trim(),
        'principal': double.tryParse(_principal.text) ?? 0,
        'interest_rate': double.tryParse(_rate.text) ?? 0,
        'term_months': (int.tryParse(_years.text) ?? 0) * 12,
        'monthly_payment': double.parse(_monthly.toStringAsFixed(2)),
      });
      ref.invalidate(mortgagesProvider);
      if (mounted) context.pop();
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Track a mortgage')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.x16),
        children: [
          TextField(controller: _label, decoration: const InputDecoration(hintText: 'Label (e.g. Marina apartment)')),
          const SizedBox(height: AppSpacing.x12),
          TextField(controller: _lender, decoration: const InputDecoration(hintText: 'Lender (e.g. Emirates NBD)')),
          const SizedBox(height: AppSpacing.x12),
          TextField(controller: _principal, keyboardType: TextInputType.number,
              onChanged: (_) => setState(() {}), decoration: const InputDecoration(hintText: 'Loan amount (AED)')),
          const SizedBox(height: AppSpacing.x12),
          TextField(controller: _rate, keyboardType: TextInputType.number,
              onChanged: (_) => setState(() {}), decoration: const InputDecoration(hintText: 'Interest rate (% per year)')),
          const SizedBox(height: AppSpacing.x12),
          TextField(controller: _years, keyboardType: TextInputType.number,
              onChanged: (_) => setState(() {}), decoration: const InputDecoration(hintText: 'Term (years)')),
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
