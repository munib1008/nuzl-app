import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/network/api_client.dart';
import '../messages/data/messaging_repository.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/app_dialog.dart';
import '../../core/widgets/async_view.dart';
import '../../core/widgets/status_badge.dart';
import '../shell/app_shell.dart';
import 'orders_repository.dart';

BadgeTone _statusTone(String s) {
  if (s == 'cancelled' || s == 'returned') return BadgeTone.danger;
  if (s == 'delivered' || s == 'completed' || s == 'closed') return BadgeTone.success;
  if (s == 'received' || s == 'requested') return BadgeTone.neutral;
  return BadgeTone.gold;
}

/// Customer orders + service requests with status tracking. Two views: the
/// customer's own orders, and (for providers) the incoming queue.
class OrdersScreen extends ConsumerWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: NuzlAppBar(title: 'Orders'),
        drawer: NuzlDrawer(),
        body: Column(children: [
          Material(child: TabBar(tabs: [Tab(text: 'My orders'), Tab(text: 'Incoming')])),
          Expanded(child: TabBarView(children: [_OrdersList(mine: true), _OrdersList(mine: false)])),
        ]),
      ),
    );
  }
}

class _OrdersList extends ConsumerWidget {
  const _OrdersList({required this.mine});
  final bool mine;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = mine ? myOrdersProvider : incomingOrdersProvider;
    final orders = ref.watch(provider);
    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(provider),
      child: AsyncView<List<Map<String, dynamic>>>(
        value: orders,
        onRetry: () => ref.invalidate(provider),
        data: (list) {
          if (list.isEmpty) {
            return ListView(children: [
              Padding(
                padding: const EdgeInsets.all(48),
                child: Center(
                  child: Text(mine ? 'You have no orders yet.' : 'No incoming orders.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textMuted)),
                ),
              ),
            ]);
          }
          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.x16),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.x12),
            itemBuilder: (_, i) => _OrderCard(o: list[i], mine: mine, listProvider: provider),
          );
        },
      ),
    );
  }
}

class _OrderCard extends ConsumerWidget {
  const _OrderCard({required this.o, required this.mine, required this.listProvider});
  final Map<String, dynamic> o;
  final bool mine;
  final ProviderListenable listProvider;

  Future<void> _patch(BuildContext context, WidgetRef ref, String status) async {
    try {
      await ref.read(apiClientProvider).patch('/marketplace/orders/${o['id']}/status', body: {'status': status});
      ref.invalidate(myOrdersProvider);
      ref.invalidate(incomingOrdersProvider);
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
    }
  }

  Future<void> _message(BuildContext context, WidgetRef ref, String providerId) async {
    try {
      final convId = await ref
          .read(messagingRepositoryProvider)
          .startDirect(providerId, contextTable: 'marketplace_orders', contextId: '${o['id']}');
      if (convId.isNotEmpty && context.mounted) context.push('/messages/$convId');
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
    }
  }

  Future<void> _dispute(BuildContext context, WidgetRef ref) async {
    final reason = TextEditingController();
    final ok = await AppDialog.show<bool>(
      context,
      title: 'Raise a dispute',
      children: [
        TextField(controller: reason, maxLines: 3, decoration: const InputDecoration(labelText: 'What went wrong?')),
      ],
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Submit')),
      ],
    );
    if (ok != true) return;
    try {
      await ref.read(apiClientProvider)
          .post('/marketplace/orders/${o['id']}/dispute', body: {'reason': reason.text.trim()});
      ref.invalidate(myOrdersProvider);
      ref.invalidate(incomingOrdersProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Dispute submitted')));
      }
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
    }
  }

  /// Provider resolves (clears) a dispute the customer raised.
  Future<void> _resolveDispute(BuildContext context, WidgetRef ref) async {
    final note = TextEditingController();
    final ok = await AppDialog.show<bool>(
      context,
      title: 'Resolve dispute',
      children: [
        const Text('Mark this dispute as resolved. The customer is notified.'),
        const SizedBox(height: AppSpacing.x12),
        TextField(controller: note, maxLines: 2, decoration: const InputDecoration(labelText: 'Resolution note (optional)')),
      ],
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Resolve')),
      ],
    );
    if (ok != true) return;
    try {
      await ref.read(apiClientProvider)
          .patch('/marketplace/orders/${o['id']}/dispute-resolve', body: {'note': note.text.trim()});
      ref.invalidate(myOrdersProvider);
      ref.invalidate(incomingOrdersProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Dispute resolved.')));
      }
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
    }
  }

  /// Provider sets/updates the price on a quote request.
  Future<void> _sendQuote(BuildContext context, WidgetRef ref) async {
    final price = TextEditingController(text: '${o['quoted_price'] ?? ''}');
    final ok = await AppDialog.show<bool>(
      context,
      title: 'Send quote',
      children: [
        Text('Quote "${o['title'] ?? 'this request'}" for the customer to accept.'),
        const SizedBox(height: AppSpacing.x8),
        TextField(
            controller: price,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Quote amount (AED)')),
      ],
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Send quote')),
      ],
    );
    if (ok != true) return;
    final amt = double.tryParse(price.text.trim());
    if (amt == null || amt <= 0) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a valid quote amount.')));
      return;
    }
    try {
      await ref.read(apiClientProvider).patch('/marketplace/orders/${o['id']}/quote', body: {'quoted_price': amt});
      ref.invalidate(myOrdersProvider);
      ref.invalidate(incomingOrdersProvider);
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Quote sent.')));
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
    }
  }

  /// Customer accepts (-> order placed) or declines a quote.
  Future<void> _respondQuote(BuildContext context, WidgetRef ref, bool accept) async {
    try {
      await ref.read(apiClientProvider)
          .patch('/marketplace/orders/${o['id']}/quote-response', body: {'accept': accept});
      ref.invalidate(myOrdersProvider);
      ref.invalidate(incomingOrdersProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(accept ? 'Quote accepted — order placed.' : 'Quote declined.')));
      }
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
    }
  }

  Future<void> _rate(BuildContext context, WidgetRef ref) async {
    var stars = 5;
    final review = TextEditingController();
    final ok = await AppDialog.show<bool>(
      context,
      title: 'Rate this ${o['kind'] == 'product' ? 'order' : 'service'}',
      children: [
        StatefulBuilder(
          builder: (ctx, setS) => Column(mainAxisSize: MainAxisSize.min, children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 1; i <= 5; i++)
                  IconButton(
                    onPressed: () => setS(() => stars = i),
                    icon: Icon(i <= stars ? Icons.star : Icons.star_border, color: AppColors.accentGold),
                  ),
              ],
            ),
            TextField(controller: review, maxLines: 2, decoration: const InputDecoration(labelText: 'Review (optional)')),
          ]),
        ),
      ],
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Submit')),
      ],
    );
    if (ok != true) return;
    try {
      await ref.read(apiClientProvider).post('/marketplace/orders/${o['id']}/rate',
          body: {'rating': stars, 'review': review.text.trim()});
      ref.invalidate(myOrdersProvider);
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Thanks for the rating!')));
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final kind = '${o['kind'] ?? 'service'}';
    final status = '${o['status'] ?? 'requested'}';
    final title = '${o['title'] ?? 'Order'}';
    final counterpart = mine ? '${o['provider_name'] ?? ''}' : '${o['customer_name'] ?? ''}';
    final price = num.tryParse('${o['quoted_price'] ?? ''}');
    final aed = NumberFormat.currency(symbol: 'AED ', decimalDigits: 0);
    final created = DateTime.tryParse('${o['created_at']}');
    final flow = flowFor(kind);
    final curIdx = flow.indexOf(status);
    final next = nextStatus(kind, status);
    final rating = int.tryParse('${o['rating'] ?? ''}');
    final disputed = o['disputed'] == true;
    final disputeReason = '${o['dispute_reason'] ?? ''}'.trim();
    final resolution = '${o['dispute_resolution'] ?? ''}'.trim();
    final providerId = '${o['provider_id'] ?? ''}';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.x12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: (kind == 'product' ? AppColors.info : AppColors.primary).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppSpacing.rFull),
              ),
              child: Text(kind == 'product' ? 'Product' : 'Service',
                  style: t.labelSmall?.copyWith(
                      color: kind == 'product' ? AppColors.info : AppColors.primary, fontWeight: FontWeight.w700)),
            ),
            const SizedBox(width: AppSpacing.x8),
            Expanded(child: Text(title, style: t.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis)),
            if (disputed) ...[
              const StatusBadge('Disputed', tone: BadgeTone.danger),
              const SizedBox(width: 4),
            ],
            StatusBadge(orderStatusLabels[status] ?? status, tone: _statusTone(status)),
          ]),
          if (counterpart.isNotEmpty || price != null || created != null) ...[
            const SizedBox(height: 4),
            Text([
              if (counterpart.isNotEmpty) (mine ? 'Provider: $counterpart' : counterpart),
              if (price != null) aed.format(price),
              if (created != null) DateFormat('d MMM').format(created),
            ].join('  ·  '), style: t.bodySmall?.copyWith(color: AppColors.textMuted)),
          ],
          // Status progress (the flow, current step highlighted). Hidden when
          // cancelled or still pre-order (quote_requested / quoted → curIdx < 0).
          if (status != 'cancelled' && curIdx >= 0) ...[
            const SizedBox(height: AppSpacing.x8),
            Wrap(spacing: 6, runSpacing: 4, children: [
              for (var i = 0; i < flow.length; i++)
                Text(
                  orderStatusLabels[flow[i]] ?? flow[i],
                  style: t.bodySmall?.copyWith(
                    color: i <= curIdx && curIdx >= 0 ? AppColors.primary : AppColors.textSubtle,
                    fontWeight: i == curIdx ? FontWeight.w700 : FontWeight.w400,
                  ),
                ),
            ]),
          ],
          if (rating != null) ...[
            const SizedBox(height: AppSpacing.x8),
            Row(children: [
              for (var i = 1; i <= 5; i++)
                Icon(i <= rating ? Icons.star : Icons.star_border, size: 14, color: AppColors.accentGold),
            ]),
          ],
          if (disputed && disputeReason.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.x8),
            Text('Dispute: $disputeReason', style: t.bodySmall?.copyWith(color: AppColors.danger)),
          ],
          if (!disputed && resolution.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.x8),
            Text('Resolved: $resolution', style: t.bodySmall?.copyWith(color: AppColors.success)),
          ],
          // Actions (role-aware)
          const SizedBox(height: AppSpacing.x8),
          Wrap(spacing: AppSpacing.x8, runSpacing: AppSpacing.x4, children: [
            if (!mine && disputed)
              OutlinedButton(
                onPressed: () => _resolveDispute(context, ref),
                style: OutlinedButton.styleFrom(foregroundColor: AppColors.success),
                child: const Text('Resolve dispute'),
              ),
            // Provider: quote a request / revise the quote.
            if (!mine && status == 'quote_requested')
              FilledButton(onPressed: () => _sendQuote(context, ref), child: const Text('Send quote')),
            if (!mine && status == 'quoted')
              OutlinedButton(onPressed: () => _sendQuote(context, ref), child: const Text('Update quote')),
            // Customer: accept / decline a quote.
            if (mine && status == 'quoted') ...[
              FilledButton(onPressed: () => _respondQuote(context, ref, true), child: const Text('Accept quote')),
              OutlinedButton(onPressed: () => _respondQuote(context, ref, false), child: const Text('Decline')),
            ],
            if (!mine && next != null && status != 'quote_requested' && status != 'quoted')
              FilledButton(
                onPressed: () => _patch(context, ref, next),
                child: Text('Mark ${orderStatusLabels[next] ?? next}'),
              ),
            if (mine && providerId.isNotEmpty)
              OutlinedButton.icon(
                onPressed: () => _message(context, ref, providerId),
                icon: const Icon(Icons.chat_bubble_outline, size: 16),
                label: const Text('Message'),
              ),
            if (mine && orderIsRateable(status) && rating == null)
              OutlinedButton.icon(
                onPressed: () => _rate(context, ref),
                icon: const Icon(Icons.star_outline, size: 16),
                label: const Text('Rate'),
              ),
            if (mine && !orderIsTerminal(status) && !disputed && status != 'quote_requested' && status != 'quoted')
              OutlinedButton(onPressed: () => _dispute(context, ref), child: const Text('Dispute')),
            // Generic cancel — for the customer on a 'quoted' order, Decline covers it.
            if (!orderIsTerminal(status) && !(mine && status == 'quoted'))
              OutlinedButton(onPressed: () => _patch(context, ref, 'cancelled'), child: const Text('Cancel')),
          ]),
        ]),
      ),
    );
  }
}
