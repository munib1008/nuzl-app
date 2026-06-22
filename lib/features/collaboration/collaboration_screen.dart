import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/status_badge.dart';
import '../crm/crm_scaffold.dart';
import 'collaboration_repository.dart';

String _title(BuildContext context, Map v) {
  final bn = '${v['building_name'] ?? ''}'.trim();
  final un = '${v['unit_no'] ?? ''}'.trim();
  final comm = '${v['community'] ?? ''}'.trim();
  if (bn.isNotEmpty) return un.isNotEmpty ? '$bn - $un' : bn;
  if (un.isNotEmpty) return '${context.tr('Unit')} $un';
  return comm.isNotEmpty ? comm : context.tr('Listing');
}

String _split(dynamic v) {
  final n = num.tryParse('${v ?? ''}');
  return n == null ? '' : '${n.toStringAsFixed(0)}%';
}

BadgeTone _statusTone(String s) => switch (s) {
      'accepted' => BadgeTone.success,
      'rejected' || 'withdrawn' => BadgeTone.danger,
      'countered' => BadgeTone.warning,
      _ => BadgeTone.neutral,
    };

/// Agent co-broking collaboration inbox (marketplace): incoming requests on my
/// listings + my outgoing requests, with accept / reject / counter.
class CollaborationScreen extends ConsumerWidget {
  const CollaborationScreen({super.key});

  void _refresh(WidgetRef ref) {
    ref.invalidate(collabIncomingProvider);
    ref.invalidate(collabOutgoingProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final incoming = ref.watch(collabIncomingProvider);
    final outgoing = ref.watch(collabOutgoingProvider);
    final t = Theme.of(context).textTheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return CrmScaffold(
      tab: CrmTab.collaboration,
      title: context.tr('Collaboration'),
      body: RefreshIndicator(
        onRefresh: () async => _refresh(ref),
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.x16),
          children: [
            Text(context.tr('Requests on your listings'), style: t.titleSmall?.copyWith(color: Theme.of(context).colorScheme.primary)),
            const SizedBox(height: AppSpacing.x8),
            incoming.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('$e', style: t.bodySmall),
              data: (list) => list.isEmpty
                  ? Text(context.tr('No incoming requests.'), style: t.bodySmall?.copyWith(color: dark ? AppColors.dTextMuted : AppColors.textMuted))
                  : Column(children: [for (final r in list) _IncomingCard(r)]),
            ),
            const SizedBox(height: AppSpacing.x20),
            Text(context.tr('Your requests'), style: t.titleSmall),
            const SizedBox(height: AppSpacing.x8),
            outgoing.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('$e', style: t.bodySmall),
              data: (list) => list.isEmpty
                  ? Text(context.tr('You have no outgoing requests.'), style: t.bodySmall?.copyWith(color: dark ? AppColors.dTextMuted : AppColors.textMuted))
                  : Column(children: [for (final r in list) _OutgoingCard(r)]),
            ),
          ],
        ),
      ),
    );
  }
}

class _IncomingCard extends ConsumerWidget {
  const _IncomingCard(this.r);
  final Map<String, dynamic> r;

  Future<void> _do(BuildContext context, WidgetRef ref, Future<void> Function() op) async {
    try {
      await op();
      ref.invalidate(collabIncomingProvider);
      ref.invalidate(collabOutgoingProvider);
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
    }
  }

  Future<void> _counter(BuildContext context, WidgetRef ref) async {
    final ctrl = TextEditingController(text: '${r['proposed_split'] ?? ''}');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.tr('Counter the split')),
        content: TextField(controller: ctrl, keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: context.tr('Your counter split (%)'))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(context.tr('Cancel'))),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(context.tr('Send'))),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final cs = double.tryParse(ctrl.text.trim());
    if (cs == null) return;
    await _do(context, ref, () => ref.read(collabRepoProvider).respond('${r['id']}', 'counter', counterSplit: cs));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final countered = r['status'] == 'countered';
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.x12),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.x16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_title(context, r), style: t.titleSmall),
          const SizedBox(height: 2),
          Text([
            if (r['requester_name'] != null) '${context.tr('from')} ${r['requester_name']}',
            if (_split(r['proposed_split']).isNotEmpty) '${context.tr('wants')} ${_split(r['proposed_split'])}',
            if (countered && _split(r['counter_split']).isNotEmpty) '${context.tr('you countered')} ${_split(r['counter_split'])}',
          ].join('  ·  '), style: t.bodySmall?.copyWith(color: dark ? AppColors.dTextMuted : AppColors.textMuted)),
          if ('${r['message'] ?? ''}'.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.x4),
            Text('${r['message']}', style: t.bodyMedium),
          ],
          const SizedBox(height: AppSpacing.x12),
          Wrap(spacing: AppSpacing.x8, children: [
            FilledButton(
              onPressed: () => _do(context, ref, () => ref.read(collabRepoProvider).respond('${r['id']}', 'accept')),
              child: Text(context.tr('Accept')),
            ),
            OutlinedButton(onPressed: () => _counter(context, ref), child: Text(context.tr('Counter'))),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: AppColors.danger),
              onPressed: () => _do(context, ref, () => ref.read(collabRepoProvider).respond('${r['id']}', 'reject')),
              child: Text(context.tr('Reject')),
            ),
          ]),
        ]),
      ),
    );
  }
}

class _OutgoingCard extends ConsumerWidget {
  const _OutgoingCard(this.r);
  final Map<String, dynamic> r;

  Future<void> _do(BuildContext context, WidgetRef ref, Future<void> Function() op) async {
    try {
      await op();
      ref.invalidate(collabOutgoingProvider);
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final status = '${r['status'] ?? 'pending'}';
    final countered = status == 'countered';
    final open = status == 'pending' || countered;
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.x12),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.x16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(_title(context, r), style: t.titleSmall)),
            StatusBadge(status, tone: _statusTone(status)),
          ]),
          const SizedBox(height: 2),
          Text([
            if (r['owner_name'] != null) '${context.tr('to')} ${r['owner_name']}',
            if (_split(r['proposed_split']).isNotEmpty) '${context.tr('you asked')} ${_split(r['proposed_split'])}',
            if (countered && _split(r['counter_split']).isNotEmpty) '${context.tr('countered')} ${_split(r['counter_split'])}',
          ].join('  ·  '), style: t.bodySmall?.copyWith(color: dark ? AppColors.dTextMuted : AppColors.textMuted)),
          if (open) ...[
            const SizedBox(height: AppSpacing.x12),
            Wrap(spacing: AppSpacing.x8, children: [
              if (countered)
                FilledButton(
                  onPressed: () => _do(context, ref, () => ref.read(collabRepoProvider).acceptCounter('${r['id']}')),
                  child: Text(context.tr('Accept counter')),
                ),
              TextButton(
                style: TextButton.styleFrom(foregroundColor: AppColors.danger),
                onPressed: () => _do(context, ref, () => ref.read(collabRepoProvider).withdraw('${r['id']}')),
                child: Text(context.tr('Withdraw')),
              ),
            ]),
          ],
        ]),
      ),
    );
  }
}
