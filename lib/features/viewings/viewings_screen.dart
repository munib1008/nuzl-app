import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/skeleton_loader.dart';
import '../../core/widgets/responsive.dart';
import '../../core/widgets/status_badge.dart';
import '../auth/application/auth_controller.dart';
import '../shell/app_shell.dart';

final viewingsProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  try {
    final d = await ref.read(apiClientProvider).get('/viewings');
    return d is List ? d : [];
  } catch (_) {
    return [];
  }
});

(String, BadgeTone) _statusTag(String s) => switch (s) {
      'requested' => ('Requested', BadgeTone.warning),
      'approved' => ('Approved', BadgeTone.neutral),
      'scheduled' => ('Scheduled', BadgeTone.gold),
      'completed' => ('Completed', BadgeTone.success),
      'cancelled' => ('Cancelled', BadgeTone.danger),
      _ => (s, BadgeTone.neutral),
    };

class ViewingsScreen extends ConsumerWidget {
  const ViewingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final viewings = ref.watch(viewingsProvider);
    final myId = ref.watch(authControllerProvider).user?.id;
    return Scaffold(
      appBar: NuzlAppBar(title: context.tr('Viewings')),
      drawer: const NuzlDrawer(),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(viewingsProvider);
          await ref.read(viewingsProvider.future);
        },
        child: ResponsiveCenter(
          child: viewings.when(
            loading: () => const SkeletonList(),
            error: (e, _) => ListView(children: [Padding(padding: const EdgeInsets.all(24), child: Center(child: Text(friendlyError(e))))]),
            data: (list) => list.isEmpty
                ? ListView(children: [
                    EmptyState(
                      icon: Icons.event_available_outlined,
                      title: context.tr('No viewing requests yet'),
                      message: context.tr('Viewing requests from buyers and tenants will appear here.'),
                    ),
                  ])
                : ListView.separated(
                    padding: const EdgeInsets.all(AppSpacing.x16),
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.x12),
                    itemBuilder: (_, i) => _ViewingCard(Map<String, dynamic>.from(list[i]), myId: myId),
                  ),
          ),
        ),
      ),
    );
  }
}

class _ViewingCard extends ConsumerWidget {
  const _ViewingCard(this.v, {this.myId});
  final Map<String, dynamic> v;
  final String? myId;

  bool get _isBroker => myId != null && '${v['listing_broker_id']}' == myId;
  String get _id => '${v['id']}';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final status = '${v['status'] ?? 'requested'}';
    final (label, tone) = _statusTag(status);
    final beds = v['bedrooms'] == null ? '' : '${v['bedrooms']}BR ';
    final type = '${v['property_type'] ?? ''}'.replaceAll('_', ' ');
    final community = '${v['community'] ?? ''}';
    final title = ('$beds$type').trim().isEmpty ? context.tr('Property') : '$beds$type';
    final price = num.tryParse('${v['price']}') ?? 0;
    final money = price > 0 ? NumberFormat.currency(symbol: 'AED ', decimalDigits: 0).format(price) : '';
    final sched = DateTime.tryParse('${v['scheduled_at']}');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.x16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(title, style: t.titleMedium)),
            StatusBadge(context.tr(label), tone: tone),
          ]),
          if (community.isNotEmpty || money.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.x4),
            Text([community, money].where((x) => x.isNotEmpty).join('  ·  '),
                style: t.bodySmall?.copyWith(color: dark ? AppColors.dTextMuted : AppColors.textMuted)),
          ],
          if (_isBroker && '${v['requested_by_name'] ?? ''}'.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.x4),
            Row(children: [
              Icon(Icons.person_outline, size: 14, color: dark ? AppColors.dTextMuted : AppColors.textMuted),
              const SizedBox(width: 4),
              Text('${v['requested_by_name']}', style: t.bodySmall),
            ]),
          ],
          if (sched != null) ...[
            const SizedBox(height: AppSpacing.x4),
            Row(children: [
              Icon(Icons.event_outlined, size: 14, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 4),
              Text(DateFormat('EEE d MMM · HH:mm').format(sched),
                  style: t.bodySmall?.copyWith(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w600)),
            ]),
          ],
          _actions(context, ref, status),
        ]),
      ),
    );
  }

  Widget _actions(BuildContext context, WidgetRef ref, String status) {
    if (!_isBroker || status == 'completed' || status == 'cancelled') return const SizedBox.shrink();
    final buttons = <Widget>[];
    if (status == 'requested') {
      buttons.add(OutlinedButton(onPressed: () => _approve(context, ref), child: Text(context.tr('Approve'))));
    }
    if (status == 'requested' || status == 'approved') {
      buttons.add(FilledButton(onPressed: () => _schedule(context, ref), child: Text(context.tr('Schedule'))));
    }
    if (status == 'scheduled') {
      buttons.add(FilledButton(onPressed: () => _outcome(context, ref), child: Text(context.tr('Record outcome'))));
    }
    buttons.add(TextButton(
      onPressed: () => _reject(context, ref),
      style: TextButton.styleFrom(foregroundColor: AppColors.danger),
      child: Text(context.tr('Reject')),
    ));
    if (buttons.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.x12),
      child: Wrap(spacing: AppSpacing.x8, children: buttons),
    );
  }

  Future<void> _patch(BuildContext context, WidgetRef ref, String path, {Map<String, dynamic>? body, String? toast}) async {
    try {
      await ref.read(apiClientProvider).patch(path, body: body);
      ref.invalidate(viewingsProvider);
      if (context.mounted && toast != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(toast)));
      }
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
    }
  }

  Future<void> _approve(BuildContext context, WidgetRef ref) =>
      _patch(context, ref, '/viewings/$_id/approve', toast: context.tr('Approved'));

  Future<void> _reject(BuildContext context, WidgetRef ref) =>
      _patch(context, ref, '/viewings/$_id/cancel', toast: context.tr('Viewing declined'));

  Future<void> _schedule(BuildContext context, WidgetRef ref) async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (date == null || !context.mounted) return;
    final time = await showTimePicker(context: context, initialTime: const TimeOfDay(hour: 10, minute: 0));
    if (time == null || !context.mounted) return;
    final dt = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    await _patch(context, ref, '/viewings/$_id/schedule',
        body: {'scheduled_at': dt.toIso8601String()}, toast: context.tr('Viewing scheduled'));
  }

  Future<void> _outcome(BuildContext context, WidgetRef ref) async {
    var outcome = 'interested';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.tr('Viewing outcome')),
        content: StatefulBuilder(
          builder: (ctx, setS) => DropdownButtonFormField<String>(
            initialValue: outcome,
            decoration: InputDecoration(labelText: context.tr('Outcome')),
            items: [
              DropdownMenuItem(value: 'interested', child: Text(context.tr('Interested'))),
              DropdownMenuItem(value: 'negotiating', child: Text(context.tr('Negotiating'))),
              DropdownMenuItem(value: 'follow_up', child: Text(context.tr('Follow up'))),
              DropdownMenuItem(value: 'not_interested', child: Text(context.tr('Not interested'))),
            ],
            onChanged: (val) => setS(() => outcome = val ?? 'interested'),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(context.tr('Cancel'))),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(context.tr('Save'))),
        ],
      ),
    );
    if (ok != true) return;
    if (!context.mounted) return;
    await _patch(context, ref, '/viewings/$_id/outcome', body: {'outcome': outcome}, toast: context.tr('Outcome recorded'));
  }
}
