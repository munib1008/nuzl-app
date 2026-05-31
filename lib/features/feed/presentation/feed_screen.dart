import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/async_view.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/status_badge.dart';
import '../data/feed_repository.dart';
import '../domain/feed_item.dart';

class FeedScreen extends ConsumerWidget {
  const FeedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feed = ref.watch(feedProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Opportunities')),
      body: RefreshIndicator(
        onRefresh: () async => ref.refresh(feedProvider.future),
        child: AsyncView<List<FeedItem>>(
          value: feed,
          onRetry: () => ref.refresh(feedProvider),
          data: (items) {
            if (items.isEmpty) {
              return const EmptyState(
                icon: Icons.dynamic_feed_outlined,
                title: 'No opportunities yet',
                message: 'Post a buyer requirement or a need-help request to get matched.',
                actionLabel: 'Go to Leads',
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.x16),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.x12),
              itemBuilder: (_, i) => _FeedCard(items[i]),
            );
          },
        ),
      ),
    );
  }
}

class _FeedCard extends StatelessWidget {
  const _FeedCard(this.item);
  final FeedItem item;

  (String, BadgeTone) get _tag => switch (item.kind) {
        'new_listing' => ('New listing', BadgeTone.neutral),
        'need_help' => ('Need help', BadgeTone.warning),
        'co_broking_buyer' || 'co_broking_seller' => ('Co-broking', BadgeTone.gold),
        _ when item.urgency >= 3 => ('Urgent', BadgeTone.danger),
        _ => (item.kind.replaceAll('_', ' '), BadgeTone.neutral),
      };

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final (label, tone) = _tag;
    final price = item.price != null
        ? NumberFormat.currency(symbol: 'AED ', decimalDigits: 0).format(item.price)
        : null;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.x16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              StatusBadge(label, tone: tone),
              const Spacer(),
              if (item.createdAt != null)
                Text(DateFormat.MMMd().format(item.createdAt!), style: t.bodySmall),
            ]),
            const SizedBox(height: AppSpacing.x12),
            if (price != null) Text(price, style: t.titleLarge),
            const SizedBox(height: AppSpacing.x4),
            Text([
              if (item.community != null) item.community,
              if (item.bedrooms != null) '${item.bedrooms} BR',
            ].whereType<String>().join('  ·  '), style: t.bodyMedium),
            const SizedBox(height: AppSpacing.x12),
            Row(children: [
              OutlinedButton(onPressed: () {}, child: const Text('Respond')),
              const SizedBox(width: AppSpacing.x8),
              TextButton(onPressed: () {}, child: const Text('Save')),
            ]),
          ],
        ),
      ),
    );
  }
}
