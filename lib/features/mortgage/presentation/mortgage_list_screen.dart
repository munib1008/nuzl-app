import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/async_view.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/skeleton_loader.dart';
import '../data/mortgage_repository.dart';
import '../domain/mortgage.dart';
import '../domain/finance_type.dart';
import '../../shell/app_shell.dart';

/// INSIDE tracker — list of the user's saved mortgages + progress.
class MortgageListScreen extends ConsumerWidget {
  const MortgageListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mortgages = ref.watch(mortgagesProvider);
    return Scaffold(
      appBar: NuzlAppBar(title: 'Mortgages', actions: [
        IconButton(
          tooltip: 'Calculator',
          icon: const Icon(Icons.calculate_outlined),
          onPressed: () => context.push('/calculator'),
        ),
      ]),
      drawer: const NuzlDrawer(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/mortgages/new'),
        icon: const Icon(Icons.add),
        label: const Text('Track a mortgage'),
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.refresh(mortgagesProvider.future),
        child: AsyncView<List<Mortgage>>(
          value: mortgages,
          onRetry: () => ref.refresh(mortgagesProvider),
          loading: const SkeletonList(),
          data: (items) {
            if (items.isEmpty) {
              return EmptyState(
                icon: Icons.account_balance_outlined,
                title: 'No mortgages tracked',
                message: 'Add a mortgage to log payments and watch the balance fall.',
                actionLabel: 'Track a mortgage',
                onAction: () => context.push('/mortgages/new'),
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.x16),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.x12),
              itemBuilder: (_, i) => _MortgageCard(items[i]),
            );
          },
        ),
      ),
    );
  }
}

class _MortgageCard extends StatelessWidget {
  const _MortgageCard(this.m);
  final Mortgage m;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final aed = NumberFormat.currency(symbol: 'AED ', decimalDigits: 0);
    final isCash = isCashPurchase(m.financeType);
    final paid = m.outstanding != null && m.principal > 0
        ? (1 - (m.outstanding! / m.principal)).clamp(0, 1).toDouble()
        : 0.0;
    return Card(
      child: InkWell(
        onTap: () => context.push('/mortgages/${m.id}'),
        borderRadius: BorderRadius.circular(AppSpacing.rMd),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.x16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(m.label ?? m.lender ?? 'Mortgage', style: t.titleMedium)),
              if (!isCash && m.interestRate > 0) Text('${m.interestRate}%', style: t.bodySmall),
            ]),
            const SizedBox(height: 2),
            Text(financeTypeLabel(m.financeType),
                style: t.bodySmall?.copyWith(color: Theme.of(context).hintColor)),
            if (!isCash) ...[
              const SizedBox(height: AppSpacing.x4),
              Text('${aed.format(m.monthlyPayment ?? 0)} / month  ·  ${(m.termMonths / 12).round()} yrs',
                  style: t.bodyMedium),
              const SizedBox(height: AppSpacing.x12),
              ClipRRect(
                borderRadius: BorderRadius.circular(AppSpacing.rFull),
                child: LinearProgressIndicator(
                    value: paid, minHeight: 6, backgroundColor: Theme.of(context).dividerColor),
              ),
              const SizedBox(height: AppSpacing.x4),
              Text('${(paid * 100).toStringAsFixed(1)}% paid  ·  ${aed.format(m.outstanding ?? m.principal)} left',
                  style: t.bodySmall),
            ],
          ]),
        ),
      ),
    );
  }
}
