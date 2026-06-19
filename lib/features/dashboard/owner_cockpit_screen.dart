import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/async_view.dart';
import '../shell/app_shell.dart';

final _cockpitProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async =>
    Map<String, dynamic>.from(await ref.read(apiClientProvider).get('/reports/owner-cockpit')));

String _fmtResponse(int secs) {
  if (secs <= 0) return '—';
  if (secs < 3600) return '${(secs / 60).round()}m';
  final h = secs ~/ 3600, m = (secs % 3600) ~/ 60;
  return m == 0 ? '${h}h' : '${h}h ${m}m';
}

int _i(dynamic v) => v is int ? v : int.tryParse('$v') ?? 0;

/// Owner cockpit — leads + agent performance + documents + pipeline for the
/// properties the owner created, assembled into one view.
class OwnerCockpitScreen extends ConsumerWidget {
  const OwnerCockpitScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(_cockpitProvider);
    final t = Theme.of(context).textTheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final muted = dark ? AppColors.dTextMuted : AppColors.textMuted;
    return Scaffold(
      appBar: const NuzlAppBar(title: 'Owner cockpit'),
      drawer: const NuzlDrawer(),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(_cockpitProvider),
        child: AsyncView<Map<String, dynamic>>(
          value: data,
          onRetry: () => ref.invalidate(_cockpitProvider),
          data: (d) {
            final props = Map<String, dynamic>.from(d['properties'] ?? {});
            final v = Map<String, dynamic>.from(d['viewings'] ?? {});
            final docs = Map<String, dynamic>.from(d['documents'] ?? {});
            final agents = (d['agents'] is List) ? List.from(d['agents']) : const [];
            return ListView(
              padding: const EdgeInsets.all(AppSpacing.x16),
              children: [
                _statCard('Properties', [
                  ('Total', '${_i(props['total'])}'),
                  ('Published', '${_i(props['published'])}'),
                  ('Drafts', '${_i(props['drafts'])}'),
                ], t, muted, onTap: () => context.push('/properties')),
                const SizedBox(height: AppSpacing.x12),
                _statCard('Viewing activity', [
                  ('Requests', '${_i(v['requests'])}'),
                  ('Pending', '${_i(v['pending'])}'),
                  ('Scheduled', '${_i(v['scheduled'])}'),
                  ('Completed', '${_i(v['completed'])}'),
                  ('Won', '${_i(v['closed_won'])}'),
                ], t, muted),
                const SizedBox(height: AppSpacing.x12),
                _statCard('Documents', [
                  ('Uploaded', '${_i(docs['uploaded'])}'),
                  ('Pending requests', '${_i(docs['pending_requests'])}'),
                ], t, muted),
                const SizedBox(height: AppSpacing.x20),
                Text('Agents working your properties', style: t.titleMedium),
                const SizedBox(height: AppSpacing.x8),
                if (agents.isEmpty)
                  Text('No agents assigned yet.', style: t.bodySmall?.copyWith(color: muted))
                else
                  for (final a in agents) _agentRow(Map<String, dynamic>.from(a), t, muted),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _statCard(String title, List<(String, String)> stats, TextTheme t, Color muted, {VoidCallback? onTap}) {
    final card = Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.x16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(title, style: t.titleSmall),
            if (onTap != null) ...[const Spacer(), Icon(Icons.chevron_right, size: 18, color: muted)],
          ]),
          const SizedBox(height: AppSpacing.x12),
          Wrap(spacing: AppSpacing.x24, runSpacing: AppSpacing.x12, children: [
            for (final s in stats)
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(s.$2, style: t.titleLarge),
                Text(s.$1, style: t.bodySmall?.copyWith(color: muted)),
              ]),
          ]),
        ]),
      ),
    );
    return onTap == null ? card : InkWell(onTap: onTap, borderRadius: BorderRadius.circular(AppSpacing.rMd), child: card);
  }

  Widget _agentRow(Map<String, dynamic> a, TextTheme t, Color muted) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.x8),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.x12),
        child: Row(children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.primaryTint,
            child: Text('${a['name'] ?? '?'}'.isNotEmpty ? '${a['name']}'[0].toUpperCase() : '?',
                style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: AppSpacing.x12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${a['name'] ?? 'Agent'}', style: t.titleSmall),
              Text([
                '${_i(a['viewings'])} viewings',
                '${_i(a['scheduled'])} scheduled',
                '${_i(a['closed_won'])} won',
                'resp ${_fmtResponse(_i(a['avg_response_secs']))}',
              ].join('  ·  '), style: t.bodySmall?.copyWith(color: muted)),
            ]),
          ),
        ]),
      ),
    );
  }
}
