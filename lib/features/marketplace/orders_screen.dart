import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/network/api_client.dart';
import '../../core/network/upload_service.dart';
import '../messages/data/messaging_repository.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/app_dialog.dart';
import '../../core/widgets/async_view.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/skeleton_loader.dart';
import '../../core/widgets/status_badge.dart';
import '../shell/app_shell.dart';
import 'booking_schedule.dart';
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
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: NuzlAppBar(title: context.tr('Orders')),
        drawer: const NuzlDrawer(),
        body: Column(children: [
          Material(child: TabBar(tabs: [Tab(text: context.tr('My orders')), Tab(text: context.tr('Incoming'))])),
          const Expanded(child: TabBarView(children: [_OrdersList(mine: true), _OrdersList(mine: false)])),
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
    final body = RefreshIndicator(
      onRefresh: () async => ref.invalidate(provider),
      child: AsyncView<List<Map<String, dynamic>>>(
        value: orders,
        onRetry: () => ref.invalidate(provider),
        loading: const SkeletonList(),
        data: (list) {
          if (list.isEmpty) {
            return ListView(children: [
              EmptyState(
                icon: Icons.receipt_long_outlined,
                title: context.tr(mine ? 'No orders yet' : 'No incoming orders'),
                message: context.tr(mine
                    ? 'Orders you place in the marketplace will appear here.'
                    : 'Orders from buyers will appear here once they purchase.'),
                actionLabel: mine ? context.tr('Browse marketplace') : null,
                onAction: mine ? () => context.go('/marketplace') : null,
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
    // Provider/supplier view leads with a KPI scorecard (§8).
    if (mine) return body;
    return Column(children: [const _ProviderStatsCard(), Expanded(child: body)]);
  }
}

/// Compact provider scorecard shown above the incoming-orders queue (§8).
class _ProviderStatsCard extends ConsumerWidget {
  const _ProviderStatsCard();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final muted = Theme.of(context).hintColor;
    final aed = NumberFormat.compactCurrency(symbol: 'AED ', decimalDigits: 0);
    final s = ref.watch(marketplaceStatsProvider).asData?.value ?? const {};
    if (s.isEmpty) return const SizedBox.shrink();
    num n(String k) => num.tryParse('${s[k] ?? 0}') ?? 0;
    final rating = s['avg_rating'];
    final resp = s['avg_response_hours'];
    final completion = s['completion_rate'];
    final tiles = <(String, String)>[
      ('Received', '${n('received')}'),
      ('Active', '${n('active')}'),
      ('Completed', '${n('completed')}'),
      ('Revenue', aed.format(n('revenue'))),
      ('Avg rating', rating == null ? '—' : '$rating★'),
      ('Completion', completion == null ? '—' : '$completion%'),
      if (resp != null) ('Avg response', '${resp}h'),
    ];
    return Card(
      margin: const EdgeInsets.fromLTRB(AppSpacing.x16, AppSpacing.x12, AppSpacing.x16, 0),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.x12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Your orders', style: t.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: AppSpacing.x8),
          Wrap(spacing: AppSpacing.x20, runSpacing: AppSpacing.x8, children: [
            for (final tile in tiles)
              Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(tile.$2, style: t.titleMedium?.copyWith(fontWeight: FontWeight.w800, color: AppColors.primary)),
                Text(tile.$1, style: t.bodySmall?.copyWith(color: muted)),
              ]),
          ]),
        ]),
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

  /// Provider confirms / reschedules the service slot → notifies the customer.
  Future<void> _schedule(BuildContext context, WidgetRef ref) async {
    final when = await pickServiceSchedule(context);
    if (when == null) return;
    try {
      await ref.read(apiClientProvider).patch('/marketplace/orders/${o['id']}/schedule',
          body: {'scheduled_at': when.toIso8601String()});
      ref.invalidate(myOrdersProvider);
      ref.invalidate(incomingOrdersProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Slot confirmed — the customer has been notified.')));
      }
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
    }
  }

  /// Customer confirms the finished service → closes it, then offers to review.
  Future<void> _confirmComplete(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(apiClientProvider).post('/marketplace/orders/${o['id']}/confirm-complete');
      ref.invalidate(myOrdersProvider);
      ref.invalidate(incomingOrdersProvider);
      if (!context.mounted) return;
      await _rate(context, ref); // "review requested" right after confirmation
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
    }
  }

  /// §7 "Issue found" — flag the order (provider notified, stays open) AND open a
  /// support ticket so it lands in the Support Center.
  Future<void> _reportIssue(BuildContext context, WidgetRef ref) async {
    final reason = TextEditingController();
    final ok = await AppDialog.show<bool>(
      context,
      title: 'Report an issue',
      children: [
        TextField(controller: reason, maxLines: 3, decoration: const InputDecoration(labelText: 'What went wrong?')),
      ],
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Submit')),
      ],
    );
    if (ok != true) return;
    final text = reason.text.trim();
    final api = ref.read(apiClientProvider);
    try {
      await api.post('/marketplace/orders/${o['id']}/dispute', body: {'reason': text});
      // Best-effort support ticket — keeps going even if it fails.
      try {
        await api.post('/feedback', body: {
          'category': 'other',
          'subject': 'Order issue — ${o['title'] ?? o['code'] ?? 'order'}',
          'description': text.isEmpty ? 'Issue reported on a completed order.' : text,
          'page': '/orders',
          'meta': {'order_id': o['id'], 'order_code': o['code']},
        });
      } catch (_) {/* ticket is best-effort */}
      ref.invalidate(myOrdersProvider);
      ref.invalidate(incomingOrdersProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Issue reported — our support team will follow up.')));
      }
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
    bool? recommend = true;
    final photos = <String>[];
    var uploading = false;
    final review = TextEditingController();
    final ok = await AppDialog.show<bool>(
      context,
      title: 'Rate this ${o['kind'] == 'product' ? 'order' : 'service'}',
      children: [
        StatefulBuilder(
          builder: (ctx, setS) => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                for (var i = 1; i <= 5; i++)
                  IconButton(
                    onPressed: () => setS(() => stars = i),
                    icon: Icon(i <= stars ? Icons.star : Icons.star_border, color: AppColors.accentGold),
                  ),
              ]),
            ),
            TextField(controller: review, maxLines: 2, decoration: const InputDecoration(labelText: 'Review (optional)')),
            const SizedBox(height: AppSpacing.x12),
            Text('Would you recommend?', style: Theme.of(ctx).textTheme.bodySmall),
            const SizedBox(height: AppSpacing.x4),
            Row(children: [
              ChoiceChip(
                label: const Text('👍 Yes'),
                selected: recommend == true,
                onSelected: (_) => setS(() => recommend = true),
              ),
              const SizedBox(width: AppSpacing.x8),
              ChoiceChip(
                label: const Text('👎 No'),
                selected: recommend == false,
                onSelected: (_) => setS(() => recommend = false),
              ),
            ]),
            const SizedBox(height: AppSpacing.x12),
            Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
              for (final url in photos)
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppSpacing.rMd),
                  child: Image.network(url, width: 52, height: 52, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const SizedBox(width: 52, height: 52)),
                ),
              OutlinedButton.icon(
                onPressed: uploading
                    ? null
                    : () async {
                        final picked = await ImagePicker()
                            .pickImage(source: ImageSource.gallery, maxWidth: 1280, imageQuality: 72);
                        if (picked == null) return;
                        final bytes = await picked.readAsBytes();
                        setS(() => uploading = true);
                        try {
                          final url = await ref.read(uploadServiceProvider).upload(bytes, picked.name, 'image/jpeg');
                          if (url != null) setS(() => photos.add(url));
                        } catch (_) {/* ignore — photos are optional */} finally {
                          setS(() => uploading = false);
                        }
                      },
                icon: uploading
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.add_photo_alternate_outlined, size: 18),
                label: Text(uploading ? 'Uploading…' : (photos.isEmpty ? 'Add photo' : 'Add another')),
              ),
            ]),
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
      await ref.read(apiClientProvider).post('/marketplace/orders/${o['id']}/rate', body: {
        'rating': stars,
        'review': review.text.trim(),
        'recommend': recommend,
        if (photos.isNotEmpty) 'photos': photos,
      });
      ref.invalidate(myOrdersProvider);
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Thanks for the rating!')));
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
    }
  }

  /// Provider replies to a customer's review (§6).
  Future<void> _reviewReply(BuildContext context, WidgetRef ref) async {
    final reply = TextEditingController();
    final ok = await AppDialog.show<bool>(
      context,
      title: 'Reply to review',
      children: [
        TextField(controller: reply, maxLines: 3, decoration: const InputDecoration(labelText: 'Your reply')),
      ],
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Send')),
      ],
    );
    if (ok != true || reply.text.trim().isEmpty) return;
    try {
      await ref.read(apiClientProvider)
          .patch('/marketplace/orders/${o['id']}/review-reply', body: {'reply': reply.text.trim()});
      ref.invalidate(incomingOrdersProvider);
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Reply posted.')));
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final kind = '${o['kind'] ?? 'service'}';
    final status = '${o['status'] ?? 'requested'}';
    final title = '${o['title'] ?? 'Order'}';
    final counterpart = mine ? '${o['provider_name'] ?? ''}' : '${o['customer_name'] ?? ''}';
    final price = num.tryParse('${o['quoted_price'] ?? ''}');
    final aed = NumberFormat.currency(symbol: 'AED ', decimalDigits: 0);
    final created = DateTime.tryParse('${o['created_at']}');
    final scheduledAt = DateTime.tryParse('${o['scheduled_at'] ?? ''}');
    final propertyLabel = '${o['property_label'] ?? ''}'.trim();
    final code = '${o['code'] ?? ''}'.trim();
    // §7 completion confirmation — once the provider marks a service 'completed',
    // the customer confirms (→ closes) or reports an issue (→ dispute).
    final canConfirm = mine && kind == 'service' && status == 'completed' && o['completed_confirmed_at'] == null;
    final statusHistory = (o['status_history'] is List)
        ? (o['status_history'] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList()
        : <Map<String, dynamic>>[];
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
              StatusBadge(context.tr('Disputed'), tone: BadgeTone.danger),
              const SizedBox(width: 4),
            ],
            StatusBadge(context.tr(orderStatusLabels[status] ?? status), tone: _statusTone(status)),
          ]),
          if (counterpart.isNotEmpty || price != null || created != null) ...[
            const SizedBox(height: 4),
            Text([
              if (code.isNotEmpty) code,
              if (counterpart.isNotEmpty) (mine ? 'Provider: $counterpart' : counterpart),
              if (price != null) aed.format(price),
              if (created != null) DateFormat('d MMM').format(created),
              if (propertyLabel.isNotEmpty) '🏠 $propertyLabel',
            ].join('  ·  '), style: t.bodySmall?.copyWith(color: dark ? AppColors.dTextMuted : AppColors.textMuted)),
          ],
          // Booked service slot — the key info for the provider to plan the job.
          if (scheduledAt != null) ...[
            const SizedBox(height: 4),
            Row(children: [
              Icon(Icons.event_available_outlined, size: 14, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  '${context.tr(mine ? 'Scheduled' : 'Requested')}: ${DateFormat('EEE d MMM · h:mm a').format(scheduledAt)}',
                  style: t.bodySmall?.copyWith(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w600),
                ),
              ),
            ]),
          ],
          // Status progress (the flow, current step highlighted). Hidden when
          // cancelled or still pre-order (quote_requested / quoted → curIdx < 0).
          if (status != 'cancelled' && curIdx >= 0) ...[
            const SizedBox(height: AppSpacing.x8),
            Wrap(spacing: 6, runSpacing: 4, children: [
              for (var i = 0; i < flow.length; i++)
                Text(
                  context.tr(orderStatusLabels[flow[i]] ?? flow[i]),
                  style: t.bodySmall?.copyWith(
                    color: i <= curIdx && curIdx >= 0
                        ? Theme.of(context).colorScheme.primary
                        : (dark ? AppColors.dTextSubtle : AppColors.textSubtle),
                    fontWeight: i == curIdx ? FontWeight.w700 : FontWeight.w400,
                  ),
                ),
            ]),
          ],
          // Tracking timeline — each status change with its timestamp.
          if (statusHistory.length > 1) ...[
            const SizedBox(height: AppSpacing.x8),
            for (final h in statusHistory)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(Icons.circle, size: 6, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(_trackLine(context, h),
                        style: t.bodySmall?.copyWith(color: dark ? AppColors.dTextMuted : AppColors.textMuted)),
                  ),
                ]),
              ),
          ],
          if (rating != null) ...[
            const SizedBox(height: AppSpacing.x8),
            Row(children: [
              for (var i = 1; i <= 5; i++)
                Icon(i <= rating ? Icons.star : Icons.star_border, size: 14, color: AppColors.accentGold),
            ]),
            if ('${o['provider_reply'] ?? ''}'.trim().isNotEmpty) ...[
              const SizedBox(height: 4),
              Text('Provider replied: ${o['provider_reply']}',
                  style: t.bodySmall?.copyWith(color: dark ? AppColors.dTextMuted : AppColors.textMuted)),
            ],
          ],
          if (disputed && disputeReason.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.x8),
            Text('Dispute: $disputeReason', style: t.bodySmall?.copyWith(color: AppColors.danger)),
          ],
          if (!disputed && resolution.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.x8),
            Text('Resolved: $resolution', style: t.bodySmall?.copyWith(color: AppColors.success)),
          ],
          // §7 — customer confirms the finished service (or reports an issue).
          if (canConfirm) ...[
            const SizedBox(height: AppSpacing.x8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.x12),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppSpacing.rMd),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Was this service completed?', style: t.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: AppSpacing.x8),
                Wrap(spacing: AppSpacing.x8, runSpacing: AppSpacing.x4, children: [
                  FilledButton(onPressed: () => _confirmComplete(context, ref), child: const Text('Yes, completed')),
                  OutlinedButton(onPressed: () => _reportIssue(context, ref), child: const Text('Report an issue')),
                ]),
              ]),
            ),
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
            // Provider: confirm / reschedule the service slot (notifies the customer).
            if (!mine && kind == 'service' && !orderIsTerminal(status) &&
                status != 'quote_requested' && status != 'quoted')
              OutlinedButton.icon(
                onPressed: () => _schedule(context, ref),
                icon: const Icon(Icons.event_outlined, size: 16),
                label: Text(context.tr(scheduledAt == null ? 'Set time' : 'Reschedule')),
              ),
            if (!mine && next != null && status != 'quote_requested' && status != 'quoted')
              FilledButton(
                onPressed: () => _patch(context, ref, next),
                child: Text('${context.tr('Mark')} ${context.tr(orderStatusLabels[next] ?? next)}'),
              ),
            if (mine && providerId.isNotEmpty)
              OutlinedButton.icon(
                onPressed: () => _message(context, ref, providerId),
                icon: const Icon(Icons.chat_bubble_outline, size: 16),
                label: Text(context.tr('Message')),
              ),
            // Provider: reply to a customer review (once).
            if (!mine && rating != null && '${o['provider_reply'] ?? ''}'.trim().isEmpty)
              OutlinedButton(onPressed: () => _reviewReply(context, ref), child: Text(context.tr('Reply to review'))),
            if (mine && orderIsRateable(status) && rating == null)
              OutlinedButton.icon(
                onPressed: () => _rate(context, ref),
                icon: const Icon(Icons.star_outline, size: 16),
                label: Text(context.tr('Rate')),
              ),
            if (mine && !orderIsTerminal(status) && !disputed && status != 'quote_requested' && status != 'quoted')
              OutlinedButton(onPressed: () => _dispute(context, ref), child: Text(context.tr('Dispute'))),
            // Generic cancel — for the customer on a 'quoted' order, Decline covers it.
            if (!orderIsTerminal(status) && !(mine && status == 'quoted'))
              OutlinedButton(onPressed: () => _patch(context, ref, 'cancelled'), child: Text(context.tr('Cancel'))),
          ]),
        ]),
      ),
    );
  }
}

/// One tracking-timeline line: "Status · 3 Jun, 2:00 PM".
String _trackLine(BuildContext context, Map<String, dynamic> h) {
  final s = '${h['status'] ?? ''}';
  final at = DateTime.tryParse('${h['at'] ?? ''}');
  final label = context.tr(orderStatusLabels[s] ?? s);
  return at != null ? '$label · ${DateFormat('d MMM, h:mm a').format(at)}' : label;
}
