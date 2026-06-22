import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/network/api_client.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/status_badge.dart';
import '../shell/app_shell.dart';
import 'viewing_leads_repository.dart';

String _propTitle(Map v) {
  final bn = '${v['building_name'] ?? ''}'.trim();
  final un = '${v['unit_no'] ?? ''}'.trim();
  final comm = '${v['community'] ?? ''}'.trim();
  if (bn.isNotEmpty) return un.isNotEmpty ? '$bn - $un' : bn;
  if (un.isNotEmpty) return 'Unit $un';
  return comm.isNotEmpty ? comm : 'Property';
}

BadgeTone _stageTone(String? s) => switch (s) {
      'closed_won' => BadgeTone.success,
      'closed_lost' => BadgeTone.danger,
      'new_inquiry' => BadgeTone.warning,
      _ => BadgeTone.gold,
    };

/// Leasing-leads inbox built on viewing requests (agent #21/#22/#27): claimable
/// pending requests, my assigned leads, and the pipeline metrics.
class ViewingLeadsScreen extends ConsumerWidget {
  const ViewingLeadsScreen({super.key});

  void _refresh(WidgetRef ref) {
    ref.invalidate(viewingPendingProvider);
    ref.invalidate(viewingAssignedProvider);
    ref.invalidate(viewingMetricsProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final pending = ref.watch(viewingPendingProvider);
    final assigned = ref.watch(viewingAssignedProvider);
    final metrics = ref.watch(viewingMetricsProvider);
    return Scaffold(
      appBar: NuzlAppBar(title: context.tr('Leasing leads')),
      drawer: const NuzlDrawer(),
      body: RefreshIndicator(
        onRefresh: () async => _refresh(ref),
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.x16),
          children: [
            metrics.maybeWhen(
              data: (m) => _MetricsCard(m),
              orElse: () => const SizedBox.shrink(),
            ),
            const SizedBox(height: AppSpacing.x20),

            Text(context.tr('Pending — first to accept gets the lead'), style: t.titleSmall?.copyWith(color: Theme.of(context).colorScheme.primary)),
            const SizedBox(height: AppSpacing.x8),
            pending.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('$e', style: t.bodySmall),
              data: (list) => list.isEmpty
                  ? Text(context.tr('No pending viewing requests.'), style: t.bodySmall?.copyWith(color: dark ? AppColors.dTextMuted : AppColors.textMuted))
                  : Column(children: [for (final v in list) _PendingCard(v)]),
            ),
            const SizedBox(height: AppSpacing.x20),

            Text(context.tr('Assigned to me'), style: t.titleSmall),
            const SizedBox(height: AppSpacing.x8),
            assigned.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('$e', style: t.bodySmall),
              data: (list) => list.isEmpty
                  ? Text(context.tr('No leads assigned to you yet.'), style: t.bodySmall?.copyWith(color: dark ? AppColors.dTextMuted : AppColors.textMuted))
                  : Column(children: [for (final v in list) _AssignedCard(v)]),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricsCard extends StatelessWidget {
  const _MetricsCard(this.m);
  final Map<String, dynamic> m;

  int _i(dynamic v) => v is int ? v : int.tryParse('$v') ?? 0;

  String _avg() {
    final secs = _i(m['avg_response_secs']);
    if (secs <= 0) return '—';
    if (secs < 3600) return '${(secs / 60).round()}m';
    final h = secs ~/ 3600, mm = (secs % 3600) ~/ 60;
    return mm == 0 ? '${h}h' : '${h}h ${mm}m';
  }

  @override
  Widget build(BuildContext context) {
    final conv = m['conversion_rate'];
    final stats = <(String, String)>[
      (context.tr('Total requests'), '${_i(m['total_requests'])}'),
      (context.tr('Pending'), '${_i(m['pending'])}'),
      (context.tr('Accepted'), '${_i(m['accepted'])}'),
      (context.tr('Scheduled'), '${_i(m['scheduled'])}'),
      (context.tr('Active pipeline'), '${_i(m['active_pipeline'])}'),
      (context.tr('Conversion'), '${conv is num ? conv.toStringAsFixed(0) : 0}%'),
      (context.tr('Won / Lost'), '${_i(m['closed_won'])} / ${_i(m['closed_lost'])}'),
      (context.tr('Avg response'), _avg()),
    ];
    final t = Theme.of(context).textTheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.x16),
        child: Wrap(
          spacing: AppSpacing.x24,
          runSpacing: AppSpacing.x16,
          children: [
            for (final s in stats)
              SizedBox(
                width: 120,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(s.$2, style: t.titleLarge),
                  Text(s.$1, style: t.bodySmall?.copyWith(color: dark ? AppColors.dTextMuted : AppColors.textMuted)),
                ]),
              ),
          ],
        ),
      ),
    );
  }
}

/// A claimable pending request — first to tap Accept wins (agent #22).
class _PendingCard extends ConsumerStatefulWidget {
  const _PendingCard(this.v);
  final Map<String, dynamic> v;
  @override
  ConsumerState<_PendingCard> createState() => _PendingCardState();
}

class _PendingCardState extends ConsumerState<_PendingCard> {
  bool _busy = false;

  Future<void> _accept() async {
    setState(() => _busy = true);
    try {
      await ref.read(viewingLeadsRepoProvider).accept('${widget.v['id']}');
      ref.invalidate(viewingPendingProvider);
      ref.invalidate(viewingAssignedProvider);
      ref.invalidate(viewingMetricsProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.tr('Lead accepted — it is yours'))));
      context.push('/viewings/${widget.v['id']}/crm');
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
      ref.invalidate(viewingPendingProvider); // it may have just been claimed
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final v = widget.v;
    return Card(
      color: AppColors.primaryTint,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.x16),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_propTitle(v), maxLines: 1, overflow: TextOverflow.ellipsis, style: t.titleMedium),
              const SizedBox(height: 2),
              Text([
                if ('${v['requested_by_name'] ?? ''}'.isNotEmpty) '${context.tr('from')} ${v['requested_by_name']}',
                if ('${v['community'] ?? ''}'.isNotEmpty) '${v['community']}',
              ].join('  ·  '), maxLines: 2, overflow: TextOverflow.ellipsis, style: t.bodySmall?.copyWith(color: AppColors.textMuted)),
            ]),
          ),
          const SizedBox(width: AppSpacing.x12),
          FilledButton(
            onPressed: _busy ? null : _accept,
            child: _busy
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Text(context.tr('Accept')),
          ),
        ]),
      ),
    );
  }
}

class _AssignedCard extends StatelessWidget {
  const _AssignedCard(this.v);
  final Map<String, dynamic> v;
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final stage = '${v['crm_stage'] ?? 'new_inquiry'}';
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/viewings/${v['id']}/crm'),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.x16),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(_propTitle(v), maxLines: 1, overflow: TextOverflow.ellipsis, style: t.titleMedium),
                if ('${v['requested_by_name'] ?? ''}'.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text('${v['requested_by_name']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: t.bodySmall?.copyWith(color: dark ? AppColors.dTextMuted : AppColors.textMuted)),
                ],
              ]),
            ),
            StatusBadge(viewingStageLabels[stage] ?? stage, tone: _stageTone(stage)),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right, color: dark ? AppColors.dTextMuted : AppColors.textMuted),
          ]),
        ),
      ),
    );
  }
}
