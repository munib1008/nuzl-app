import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/responsive.dart';
import '../../core/widgets/status_badge.dart';
import '../shell/app_shell.dart';

final myQuotesProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  try {
    final d = await ref.read(apiClientProvider).get('/tenders/my-bids');
    return d is List ? d : [];
  } catch (_) {
    return [];
  }
});

/// Quotations — the quotes the caller has submitted on service requests / RFQs.
class QuotationsScreen extends ConsumerWidget {
  const QuotationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quotes = ref.watch(myQuotesProvider);
    return Scaffold(
      appBar: const NuzlAppBar(title: 'Quotations'),
      drawer: const NuzlDrawer(),
      body: ResponsiveCenter(
        child: RefreshIndicator(
          onRefresh: () async => ref.refresh(myQuotesProvider.future),
          child: quotes.when(
            loading: () => const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator())),
            error: (e, _) => ListView(children: [Padding(padding: const EdgeInsets.all(24), child: Text('$e'))]),
            data: (list) => list.isEmpty
                ? ListView(children: [
                    const SizedBox(height: 80),
                    const Icon(Icons.request_quote_outlined, size: 48, color: AppColors.textSubtle),
                    const SizedBox(height: 12),
                    const Center(child: Text('No quotations yet', style: TextStyle(fontWeight: FontWeight.w700))),
                    const SizedBox(height: 4),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 40),
                      child: Text('Quotes you submit on open requests appear here. Browse open requests to start bidding.',
                          textAlign: TextAlign.center, style: TextStyle(color: AppColors.textMuted)),
                    ),
                    const SizedBox(height: AppSpacing.x16),
                    Center(child: FilledButton.icon(
                      onPressed: () => context.push('/tenders'),
                      icon: const Icon(Icons.assignment_outlined, size: 18),
                      label: const Text('Browse requests'),
                    )),
                  ])
                : ListView.separated(
                    padding: const EdgeInsets.all(AppSpacing.x16),
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.x8),
                    itemBuilder: (_, i) => _QuoteCard(Map<String, dynamic>.from(list[i])),
                  ),
          ),
        ),
      ),
    );
  }
}

class _QuoteCard extends StatelessWidget {
  const _QuoteCard(this.q);
  final Map<String, dynamic> q;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final aed = NumberFormat.currency(symbol: 'AED ', decimalDigits: 0);
    final price = num.tryParse('${q['price']}');
    final status = '${q['status']}'; // submitted | accepted | declined
    final (label, tone) = switch (status) {
      'accepted' => ('Won', BadgeTone.success),
      'declined' => ('Lost', BadgeTone.neutral),
      _ => ('Pending', BadgeTone.warning),
    };
    final days = int.tryParse('${q['completion_days'] ?? ''}');
    final isProduct = '${q['kind']}' == 'product';
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSpacing.rCard),
        onTap: () => context.push('/tenders/${q['request_id']}'),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.x16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(isProduct ? Icons.inventory_2_outlined : Icons.handyman_outlined, size: 15, color: AppColors.textMuted),
              const SizedBox(width: 6),
              Text('${q['ref_code'] ?? ''}', style: t.labelSmall?.copyWith(color: AppColors.textMuted, fontWeight: FontWeight.w700)),
              const Spacer(),
              StatusBadge(label, tone: tone),
            ]),
            const SizedBox(height: 4),
            Text('${q['request_title'] ?? 'Request'}', style: t.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: AppSpacing.x8),
            Row(children: [
              if (price != null) ...[
                Text('Your quote ', style: t.bodySmall?.copyWith(color: AppColors.textMuted)),
                Text(aed.format(price), style: t.bodyMedium?.copyWith(fontWeight: FontWeight.w700, color: AppColors.primary)),
              ],
              if (days != null) ...[
                const SizedBox(width: AppSpacing.x12),
                Text('$days days', style: t.bodySmall?.copyWith(color: AppColors.textMuted)),
              ],
              const Spacer(),
              Text('View →', style: t.bodySmall?.copyWith(color: AppColors.primary)),
            ]),
          ]),
        ),
      ),
    );
  }
}
