import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/async_view.dart';
import '../shell/app_shell.dart';

final _reportsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async =>
    ((await ref.read(apiClientProvider).get('/admin/post-reports')) as List)
        .map((e) => Map<String, dynamic>.from(e)).toList());

/// Nuzler post-moderation queue: open community reports + remove/dismiss.
class PostModerationScreen extends ConsumerWidget {
  const PostModerationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reports = ref.watch(_reportsProvider);
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: const NuzlAppBar(title: 'Post moderation'),
      drawer: const NuzlDrawer(),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(_reportsProvider),
        child: AsyncView<List<Map<String, dynamic>>>(
          value: reports,
          onRetry: () => ref.invalidate(_reportsProvider),
          data: (list) => list.isEmpty
              ? ListView(children: [
                  Padding(
                    padding: const EdgeInsets.all(48),
                    child: Center(child: Text('No open reports.',
                        style: t.bodyMedium?.copyWith(color: AppColors.textMuted))),
                  ),
                ])
              : ListView(
                  padding: const EdgeInsets.all(AppSpacing.x16),
                  children: [for (final r in list) _ReportCard(r)],
                ),
        ),
      ),
    );
  }
}

class _ReportCard extends ConsumerWidget {
  const _ReportCard(this.r);
  final Map<String, dynamic> r;

  Future<void> _resolve(BuildContext context, WidgetRef ref, String action) async {
    try {
      await ref.read(apiClientProvider).post('/admin/post-reports/${r['id']}/resolve', body: {'action': action});
      ref.invalidate(_reportsProvider);
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final when = DateTime.tryParse('${r['created_at'] ?? ''}');
    final body = '${r['post_body'] ?? ''}'.trim();
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.x12),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.x16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: AppColors.danger.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppSpacing.rFull)),
              child: Text('${r['reason'] ?? 'report'}',
                  style: t.labelSmall?.copyWith(color: AppColors.danger, fontWeight: FontWeight.w700)),
            ),
            const Spacer(),
            if (when != null) Text(DateFormat.yMMMd().format(when), style: t.bodySmall?.copyWith(color: AppColors.textMuted)),
          ]),
          const SizedBox(height: AppSpacing.x8),
          Text(body.isEmpty ? '(no text)' : body, maxLines: 4, overflow: TextOverflow.ellipsis, style: t.bodyMedium),
          const SizedBox(height: AppSpacing.x8),
          Text([
            if (r['author'] != null) 'by ${r['author']}',
            if (r['reporter'] != null) 'reported by ${r['reporter']}',
            if (r['post_kind'] != null) '${r['post_kind']}',
          ].join('  ·  '), style: t.bodySmall?.copyWith(color: AppColors.textMuted)),
          const SizedBox(height: AppSpacing.x12),
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            TextButton(onPressed: () => _resolve(context, ref, 'dismiss'), child: const Text('Dismiss')),
            const SizedBox(width: AppSpacing.x8),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
              onPressed: () => _resolve(context, ref, 'remove'),
              child: const Text('Remove post'),
            ),
          ]),
        ]),
      ),
    );
  }
}
