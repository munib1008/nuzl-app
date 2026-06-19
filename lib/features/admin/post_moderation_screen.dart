import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../shell/app_shell.dart';

final _reportsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async =>
    ((await ref.read(apiClientProvider).get('/admin/post-reports')) as List)
        .map((e) => Map<String, dynamic>.from(e)).toList());

/// Public marketing posts awaiting admin review (feed split).
final _pendingMarketingProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  try {
    final d = await ref.read(apiClientProvider).get('/posts/admin/pending');
    return d is List ? d.map((e) => Map<String, dynamic>.from(e as Map)).toList() : [];
  } catch (_) {
    return [];
  }
});

/// Nuzler post-moderation queue: pending marketing posts to publish + open
/// community reports to remove/dismiss.
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
        onRefresh: () async {
          ref.invalidate(_reportsProvider);
          ref.invalidate(_pendingMarketingProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.x16),
          children: [
            const _PendingMarketing(),
            reports.when(
              loading: () => const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator())),
              error: (e, _) => Padding(padding: const EdgeInsets.all(24), child: Center(child: Text(friendlyError(e)))),
              data: (list) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Reported posts (${list.length})', style: t.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: AppSpacing.x8),
                if (list.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Text('No open reports.', style: t.bodyMedium?.copyWith(color: AppColors.textMuted)),
                  )
                else
                  for (final r in list) _ReportCard(r),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

/// Pending public marketing posts — approve to publish, or decline.
class _PendingMarketing extends ConsumerWidget {
  const _PendingMarketing();

  Future<void> _review(BuildContext context, WidgetRef ref, String id, bool approve) async {
    try {
      await ref.read(apiClientProvider).post('/posts/admin/$id/review', body: {'approve': approve});
      ref.invalidate(_pendingMarketingProvider);
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final pending = ref.watch(_pendingMarketingProvider);
    return pending.maybeWhen(
      data: (list) {
        if (list.isEmpty) return const SizedBox.shrink();
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Pending marketing posts (${list.length})', style: t.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: AppSpacing.x8),
          for (final m in list)
            Card(
              margin: const EdgeInsets.only(bottom: AppSpacing.x12),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.x16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${m['title'] ?? '(untitled)'}', style: t.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                  if ('${m['body'] ?? ''}'.isNotEmpty)
                    Padding(padding: const EdgeInsets.only(top: 4), child: Text('${m['body']}', maxLines: 4, overflow: TextOverflow.ellipsis)),
                  const SizedBox(height: AppSpacing.x8),
                  Text([
                    if (m['company'] != null) '${m['company']}',
                    if (m['author'] != null) 'by ${m['author']}',
                    if (m['kind'] != null) '${m['kind']}',
                  ].join('  ·  '), style: t.bodySmall?.copyWith(color: AppColors.textMuted)),
                  const SizedBox(height: AppSpacing.x12),
                  Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                    TextButton(onPressed: () => _review(context, ref, '${m['id']}', false), child: const Text('Decline')),
                    const SizedBox(width: AppSpacing.x8),
                    FilledButton(onPressed: () => _review(context, ref, '${m['id']}', true), child: const Text('Publish')),
                  ]),
                ]),
              ),
            ),
          const Divider(height: AppSpacing.x24),
        ]);
      },
      orElse: () => const SizedBox.shrink(),
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
