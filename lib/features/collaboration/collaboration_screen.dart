import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/status_badge.dart';
import '../shell/app_shell.dart';
import 'collaboration_repository.dart';

String _title(Map v) {
  final bn = '${v['building_name'] ?? ''}'.trim();
  final un = '${v['unit_no'] ?? ''}'.trim();
  final comm = '${v['community'] ?? ''}'.trim();
  if (bn.isNotEmpty) return un.isNotEmpty ? '$bn - $un' : bn;
  if (un.isNotEmpty) return 'Unit $un';
  return comm.isNotEmpty ? comm : 'Listing';
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
    return Scaffold(
      appBar: const NuzlAppBar(title: 'Collaboration'),
      drawer: const NuzlDrawer(),
      body: RefreshIndicator(
        onRefresh: () async => _refresh(ref),
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.x16),
          children: [
            Text('Requests on your listings', style: t.titleSmall?.copyWith(color: AppColors.primary)),
            const SizedBox(height: AppSpacing.x8),
            incoming.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('$e', style: t.bodySmall),
              data: (list) => list.isEmpty
                  ? Text('No incoming requests.', style: t.bodySmall?.copyWith(color: AppColors.textMuted))
                  : Column(children: [for (final r in list) _IncomingCard(r)]),
            ),
            const SizedBox(height: AppSpacing.x20),
            Text('Your requests', style: t.titleSmall),
            const SizedBox(height: AppSpacing.x8),
            outgoing.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('$e', style: t.bodySmall),
              data: (list) => list.isEmpty
                  ? Text('You have no outgoing requests.', style: t.bodySmall?.copyWith(color: AppColors.textMuted))
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
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _counter(BuildContext context, WidgetRef ref) async {
    final ctrl = TextEditingController(text: '${r['proposed_split'] ?? ''}');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Counter the split'),
        content: TextField(controller: ctrl, keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Your counter split (%)')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Send')),
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
    final countered = r['status'] == 'countered';
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.x12),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.x16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_title(r), style: t.titleSmall),
          const SizedBox(height: 2),
          Text([
            if (r['requester_name'] != null) 'from ${r['requester_name']}',
            if (_split(r['proposed_split']).isNotEmpty) 'wants ${_split(r['proposed_split'])}',
            if (countered && _split(r['counter_split']).isNotEmpty) 'you countered ${_split(r['counter_split'])}',
          ].join('  ·  '), style: t.bodySmall?.copyWith(color: AppColors.textMuted)),
          if ('${r['message'] ?? ''}'.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.x4),
            Text('${r['message']}', style: t.bodyMedium),
          ],
          const SizedBox(height: AppSpacing.x12),
          Wrap(spacing: AppSpacing.x8, children: [
            FilledButton(
              onPressed: () => _do(context, ref, () => ref.read(collabRepoProvider).respond('${r['id']}', 'accept')),
              child: const Text('Accept'),
            ),
            OutlinedButton(onPressed: () => _counter(context, ref), child: const Text('Counter')),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: AppColors.danger),
              onPressed: () => _do(context, ref, () => ref.read(collabRepoProvider).respond('${r['id']}', 'reject')),
              child: const Text('Reject'),
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
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final status = '${r['status'] ?? 'pending'}';
    final countered = status == 'countered';
    final open = status == 'pending' || countered;
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.x12),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.x16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(_title(r), style: t.titleSmall)),
            StatusBadge(status, tone: _statusTone(status)),
          ]),
          const SizedBox(height: 2),
          Text([
            if (r['owner_name'] != null) 'to ${r['owner_name']}',
            if (_split(r['proposed_split']).isNotEmpty) 'you asked ${_split(r['proposed_split'])}',
            if (countered && _split(r['counter_split']).isNotEmpty) 'countered ${_split(r['counter_split'])}',
          ].join('  ·  '), style: t.bodySmall?.copyWith(color: AppColors.textMuted)),
          if (open) ...[
            const SizedBox(height: AppSpacing.x12),
            Wrap(spacing: AppSpacing.x8, children: [
              if (countered)
                FilledButton(
                  onPressed: () => _do(context, ref, () => ref.read(collabRepoProvider).acceptCounter('${r['id']}')),
                  child: const Text('Accept counter'),
                ),
              TextButton(
                style: TextButton.styleFrom(foregroundColor: AppColors.danger),
                onPressed: () => _do(context, ref, () => ref.read(collabRepoProvider).withdraw('${r['id']}')),
                child: const Text('Withdraw'),
              ),
            ]),
          ],
        ]),
      ),
    );
  }
}
