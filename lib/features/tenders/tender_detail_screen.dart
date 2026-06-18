import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/app_dialog.dart';
import '../../core/widgets/responsive.dart';
import '../../core/widgets/status_badge.dart';
import '../auth/application/auth_controller.dart';
import '../shell/app_shell.dart';
import 'tenders_screen.dart';

final _tenderProvider = FutureProvider.autoDispose.family<Map<String, dynamic>?, String>((ref, id) async {
  try {
    final d = await ref.read(apiClientProvider).get('/tenders/$id');
    return d is Map ? Map<String, dynamic>.from(d) : null;
  } catch (_) {
    return null;
  }
});

final _bidsProvider = FutureProvider.autoDispose.family<List<dynamic>, String>((ref, id) async {
  try {
    final d = await ref.read(apiClientProvider).get('/tenders/$id/bids');
    return d is List ? d : [];
  } catch (_) {
    return [];
  }
});

class TenderDetailScreen extends ConsumerWidget {
  const TenderDetailScreen({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final req = ref.watch(_tenderProvider(id));
    final myId = ref.watch(authControllerProvider).user?.id;
    return Scaffold(
      appBar: const NuzlAppBar(title: 'Request'),
      drawer: const NuzlDrawer(),
      body: ResponsiveCenter(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(_tenderProvider(id));
            ref.invalidate(_bidsProvider(id));
          },
          child: req.when(
            loading: () => const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator())),
            error: (e, _) => ListView(children: [Padding(padding: const EdgeInsets.all(24), child: Text('$e'))]),
            data: (r) => r == null
                ? ListView(children: const [Padding(padding: EdgeInsets.all(40), child: Center(child: Text('Request not found.')))])
                : _body(context, ref, r, myId),
          ),
        ),
      ),
    );
  }

  Widget _body(BuildContext context, WidgetRef ref, Map<String, dynamic> r, String? myId) {
    final t = Theme.of(context).textTheme;
    final isOwner = myId != null && '${r['created_by']}' == myId;
    final status = '${r['status'] ?? 'open'}';
    final isProduct = '${r['kind']}' == 'product';
    final aed = NumberFormat.currency(symbol: 'AED ', decimalDigits: 0);
    final budget = num.tryParse('${r['budget']}');
    final preferred = '${r['preferred_date'] ?? ''}'.split('T').first;
    return ListView(padding: const EdgeInsets.all(AppSpacing.x16), children: [
      Row(children: [
        Text('${r['ref_code'] ?? ''}', style: t.labelMedium?.copyWith(color: AppColors.textMuted, fontWeight: FontWeight.w700)),
        const Spacer(),
        StatusBadge(status.replaceAll('_', ' '), tone: tenderTone(status)),
      ]),
      const SizedBox(height: 6),
      Text('${r['title'] ?? ''}', style: t.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
      if ('${r['description'] ?? ''}'.trim().isNotEmpty) ...[
        const SizedBox(height: 6),
        Text('${r['description']}', style: t.bodyMedium),
      ],
      const SizedBox(height: AppSpacing.x12),
      Wrap(spacing: AppSpacing.x8, runSpacing: AppSpacing.x8, children: [
        if ('${r['category'] ?? ''}'.isNotEmpty) _chip(Icons.category_outlined, '${r['category']}${'${r['subcategory'] ?? ''}'.isNotEmpty ? ' · ${r['subcategory']}' : ''}'),
        if (budget != null) _chip(Icons.payments_outlined, 'Budget ${aed.format(budget)}'),
        if (isProduct && r['quantity'] != null) _chip(Icons.numbers, 'Qty ${r['quantity']}'),
        if ('${r['location'] ?? ''}'.isNotEmpty) _chip(Icons.place_outlined, '${r['location']}'),
        if ('${r['community'] ?? ''}'.isNotEmpty) _chip(Icons.home_work_outlined, '${r['community']}${'${r['unit_no'] ?? ''}'.isNotEmpty ? ' · ${r['unit_no']}' : ''}'),
        if (preferred.isNotEmpty) _chip(Icons.event, 'Preferred $preferred'),
      ]),
      const SizedBox(height: AppSpacing.x16),

      // Requester lifecycle controls.
      if (isOwner && status != 'open') ...[
        _StatusBar(id: id, status: status),
        const SizedBox(height: AppSpacing.x16),
      ],

      // Provider bid CTA.
      if (!isOwner && status == 'open') ...[
        FilledButton.icon(
          onPressed: () => _bidDialog(context, ref),
          icon: const Icon(Icons.request_quote_outlined, size: 18),
          label: const Text('Submit / update your quote'),
        ),
        const SizedBox(height: AppSpacing.x16),
      ],

      Text(isOwner ? 'Quotes received' : 'Quotes', style: t.titleMedium),
      const SizedBox(height: AppSpacing.x8),
      Consumer(builder: (ctx, r2, _) {
        final bids = r2.watch(_bidsProvider(id));
        return bids.when(
          loading: () => const Padding(padding: EdgeInsets.all(16), child: LinearProgressIndicator()),
          error: (e, _) => Text('$e'),
          data: (list) => list.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.x16),
                  child: Text('No quotes yet.', style: t.bodyMedium?.copyWith(color: AppColors.textMuted)))
              : Column(children: [
                  for (final b in list)
                    _BidCard(
                      bid: Map<String, dynamic>.from(b),
                      requestId: id,
                      canAward: isOwner && (status == 'open' || status == 'awarded'),
                    ),
                ]),
        );
      }),
    ]);
  }

  Widget _chip(IconData icon, String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(AppSpacing.rFull)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: AppColors.textMuted),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textMuted, fontWeight: FontWeight.w500)),
        ]),
      );

  Future<void> _bidDialog(BuildContext context, WidgetRef ref) async {
    final price = TextEditingController();
    final days = TextEditingController();
    final warranty = TextEditingController();
    final note = TextEditingController();
    final ok = await AppDialog.show<bool>(
      context,
      title: 'Submit your quote',
      maxWidth: 420,
      children: [
        Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: price, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Price (AED) *')),
          const SizedBox(height: AppSpacing.x8),
          TextField(controller: days, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Completion time (days)')),
          const SizedBox(height: AppSpacing.x8),
          TextField(controller: warranty, decoration: const InputDecoration(labelText: 'Warranty', hintText: 'e.g. 1 year')),
          const SizedBox(height: AppSpacing.x8),
          TextField(controller: note, maxLines: 2, decoration: const InputDecoration(labelText: 'Note')),
        ]),
      ],
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Submit quote')),
      ],
    );
    if (ok != true) return;
    try {
      await ref.read(apiClientProvider).post('/tenders/$id/bids', body: {
        'price': num.tryParse(price.text.trim()),
        'completion_days': int.tryParse(days.text.trim()),
        'warranty': warranty.text.trim(),
        'note': note.text.trim(),
      });
      ref.invalidate(_bidsProvider(id));
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Quote submitted')));
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }
}

/// Requester lifecycle controls once a request is awarded.
class _StatusBar extends ConsumerWidget {
  const _StatusBar({required this.id, required this.status});
  final String id;
  final String status;

  static const _next = {
    'awarded': ('in_progress', 'Start work'),
    'in_progress': ('completed', 'Mark completed'),
    'completed': ('closed', 'Close request'),
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final step = _next[status];
    if (step == null) return const SizedBox.shrink();
    return Row(children: [
      FilledButton.icon(
        onPressed: () => _set(context, ref, step.$1),
        icon: const Icon(Icons.arrow_forward, size: 18),
        label: Text(step.$2),
      ),
    ]);
  }

  Future<void> _set(BuildContext context, WidgetRef ref, String s) async {
    try {
      await ref.read(apiClientProvider).patch('/tenders/$id/status', body: {'status': s});
      ref.invalidate(_tenderProvider(id));
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }
}

/// One quote in the comparison list — price, time, warranty, rating + Award.
class _BidCard extends ConsumerWidget {
  const _BidCard({required this.bid, required this.requestId, required this.canAward});
  final Map<String, dynamic> bid;
  final String requestId;
  final bool canAward;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final aed = NumberFormat.currency(symbol: 'AED ', decimalDigits: 0);
    final price = num.tryParse('${bid['price']}');
    final days = int.tryParse('${bid['completion_days'] ?? ''}');
    final rating = num.tryParse('${bid['rating'] ?? ''}');
    final reviews = int.tryParse('${bid['review_count'] ?? 0}') ?? 0;
    final accepted = '${bid['status']}' == 'accepted';
    final declined = '${bid['status']}' == 'declined';
    final provider = '${bid['provider_org'] ?? ''}'.trim().isNotEmpty ? '${bid['provider_org']}' : '${bid['provider_name'] ?? 'Provider'}';
    return Card(
      color: accepted ? AppColors.success.withValues(alpha: 0.06) : null,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.x12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(provider, style: t.titleSmall?.copyWith(fontWeight: FontWeight.w700))),
            if (bid['provider_verified'] == true) ...[
              const Icon(Icons.verified, size: 14, color: AppColors.success),
              const SizedBox(width: 4),
            ],
            if (accepted) const StatusBadge('Awarded', tone: BadgeTone.success),
            if (declined) const StatusBadge('Declined', tone: BadgeTone.neutral),
          ]),
          const SizedBox(height: 6),
          Wrap(spacing: AppSpacing.x16, runSpacing: 4, children: [
            if (price != null) _kv(t, 'Price', aed.format(price)),
            if (days != null) _kv(t, 'Time', '$days days'),
            if ('${bid['warranty'] ?? ''}'.trim().isNotEmpty) _kv(t, 'Warranty', '${bid['warranty']}'),
            if (rating != null && reviews > 0) _kv(t, 'Rating', '${rating.toStringAsFixed(1)} ($reviews)'),
          ]),
          if ('${bid['note'] ?? ''}'.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text('${bid['note']}', style: t.bodySmall?.copyWith(color: AppColors.textMuted)),
          ],
          if (canAward && !accepted) ...[
            const SizedBox(height: AppSpacing.x8),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: () => _award(context, ref),
                icon: const Icon(Icons.emoji_events_outlined, size: 18),
                label: const Text('Award'),
              ),
            ),
          ],
        ]),
      ),
    );
  }

  Widget _kv(TextTheme t, String k, String v) => Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Text(k, style: t.labelSmall?.copyWith(color: AppColors.textMuted)),
        Text(v, style: t.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
      ]);

  Future<void> _award(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Award this quote?'),
        content: const Text('The chosen provider is notified and accepted; all other quotes are declined.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Award')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(apiClientProvider).post('/tenders/$requestId/award', body: {'bid_id': bid['id']});
      ref.invalidate(_bidsProvider(requestId));
      ref.invalidate(_tenderProvider(requestId));
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Quote awarded ✓')));
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }
}
