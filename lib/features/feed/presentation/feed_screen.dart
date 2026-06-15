import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/network/api_client.dart';
import '../../../core/rbac/persona.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_dialog.dart';
import '../../../core/widgets/status_badge.dart';
import '../../shell/app_shell.dart';

/// Professional Feed — social posts (market updates, showcases, success stories…).
final feedPostsProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  try {
    final d = await ref.read(apiClientProvider).get('/posts');
    return d is List ? d : [];
  } catch (_) {
    return [];
  }
});

final _commentsProvider = FutureProvider.autoDispose.family<List<dynamic>, String>((ref, postId) async {
  try {
    final d = await ref.read(apiClientProvider).get('/posts/$postId/comments');
    return d is List ? d : [];
  } catch (_) {
    return [];
  }
});

const _kinds = [
  ('market_update', 'Market update'),
  ('property_showcase', 'Property showcase'),
  ('project_update', 'Project update'),
  ('service_promotion', 'Service promotion'),
  ('success_story', 'Success story'),
  ('educational', 'Educational'),
];

class FeedScreen extends ConsumerWidget {
  const FeedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final posts = ref.watch(feedPostsProvider);
    final persona = ref.watch(personaProvider);
    final canPost = persona.canManageLeads || persona.canListProperty;
    return Scaffold(
      appBar: const NuzlAppBar(title: 'Feed'),
      drawer: const NuzlDrawer(),
      floatingActionButton: canPost
          ? FloatingActionButton.extended(
              onPressed: () => _composer(context, ref),
              icon: const Icon(Icons.edit_outlined),
              label: const Text('New post'),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(feedPostsProvider);
          await ref.read(feedPostsProvider.future);
        },
        child: posts.when(
          loading: () => const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator())),
          error: (e, _) => ListView(children: [Padding(padding: const EdgeInsets.all(24), child: Center(child: Text('$e')))]),
          data: (list) => list.isEmpty
              ? ListView(children: const [
                  Padding(
                    padding: EdgeInsets.all(48),
                    child: Center(child: Text('No posts yet. Share a market update or success story.', textAlign: TextAlign.center)),
                  ),
                ])
              : Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 720),
                    child: ListView.separated(
                      padding: const EdgeInsets.all(AppSpacing.x16),
                      itemCount: list.length,
                      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.x12),
                      itemBuilder: (_, i) => _PostCard(Map<String, dynamic>.from(list[i])),
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  Future<void> _composer(BuildContext context, WidgetRef ref) async {
    final title = TextEditingController();
    final body = TextEditingController();
    var kind = 'market_update';
    final ok = await AppDialog.show<bool>(
      context,
      title: 'New post',
      maxWidth: 460,
      children: [
        StatefulBuilder(
          builder: (ctx, setS) => Column(mainAxisSize: MainAxisSize.min, children: [
            DropdownButtonFormField<String>(
              initialValue: kind,
              decoration: const InputDecoration(labelText: 'Category'),
              items: _kinds.map((k) => DropdownMenuItem(value: k.$1, child: Text(k.$2))).toList(),
              onChanged: (v) => setS(() => kind = v ?? 'market_update'),
            ),
            const SizedBox(height: AppSpacing.x8),
            TextField(controller: title, decoration: const InputDecoration(labelText: 'Title')),
            const SizedBox(height: AppSpacing.x8),
            TextField(controller: body, maxLines: 4, decoration: const InputDecoration(labelText: 'Share an update…')),
          ]),
        ),
      ],
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Post')),
      ],
    );
    if (ok != true) return;
    if (title.text.trim().isEmpty && body.text.trim().isEmpty) return;
    try {
      await ref.read(apiClientProvider).post('/posts', body: {
        'kind': kind,
        'post_type': 'need_help',
        'title': title.text.trim(),
        'body': body.text.trim(),
      });
      ref.invalidate(feedPostsProvider);
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Posted to the feed')));
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }
}

(String, BadgeTone) _tag(String kind) => switch (kind) {
      'market_update' => ('Market update', BadgeTone.gold),
      'property_showcase' => ('Property', BadgeTone.success),
      'project_update' => ('Project', BadgeTone.neutral),
      'service_promotion' => ('Service', BadgeTone.warning),
      'success_story' => ('Success', BadgeTone.success),
      'educational' => ('Guide', BadgeTone.neutral),
      'co_broking_buyer' || 'co_broking_seller' => ('Co-broking', BadgeTone.gold),
      'need_help' => ('Need help', BadgeTone.warning),
      '' => ('Update', BadgeTone.neutral),
      _ => (_humanize(kind), BadgeTone.neutral),
    };

String _humanize(String k) => k
    .replaceAll('_', ' ')
    .split(' ')
    .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
    .join(' ');

class _PostCard extends ConsumerWidget {
  const _PostCard(this.p);
  final Map<String, dynamic> p;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final author = '${p['author'] ?? 'Member'}';
    final created = DateTime.tryParse('${p['created_at']}');
    final liked = p['liked'] == true;
    final likeCount = int.tryParse('${p['like_count'] ?? 0}') ?? 0;
    final commentCount = int.tryParse('${p['comment_count'] ?? 0}') ?? 0;
    final title = '${p['title'] ?? ''}';
    final body = '${p['body'] ?? ''}';
    final (label, tone) = _tag('${p['kind'] ?? p['post_type'] ?? ''}');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.x16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              CircleAvatar(
                backgroundColor: AppColors.primary,
                child: Text(author.isNotEmpty ? author[0].toUpperCase() : '?', style: const TextStyle(color: Colors.white)),
              ),
              const SizedBox(width: AppSpacing.x12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(author, style: t.titleSmall),
                  if (created != null)
                    Text(DateFormat('d MMM · HH:mm').format(created), style: t.bodySmall?.copyWith(color: AppColors.textMuted)),
                ]),
              ),
              StatusBadge(label, tone: tone),
            ]),
            if (title.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.x12),
              Text(title, style: t.titleMedium),
            ],
            if (body.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.x4),
              Text(body, style: t.bodyMedium),
            ],
            const SizedBox(height: AppSpacing.x12),
            Row(children: [
              _ActionButton(
                icon: liked ? Icons.favorite : Icons.favorite_border,
                label: '$likeCount',
                color: liked ? AppColors.danger : AppColors.textMuted,
                onTap: () => _like(ref),
              ),
              const SizedBox(width: AppSpacing.x16),
              _ActionButton(
                icon: Icons.mode_comment_outlined,
                label: '$commentCount',
                color: AppColors.textMuted,
                onTap: () => _openComments(context, ref),
              ),
            ]),
          ],
        ),
      ),
    );
  }

  Future<void> _like(WidgetRef ref) async {
    try {
      await ref.read(apiClientProvider).post('/posts/${p['id']}/like');
      ref.invalidate(feedPostsProvider);
    } catch (_) {/* ignore */}
  }

  void _openComments(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _CommentsSheet(postId: '${p['id']}'),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.icon, required this.label, required this.color, required this.onTap});
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppSpacing.rSm),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 4),
          Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: color)),
        ]),
      ),
    );
  }
}

class _CommentsSheet extends ConsumerStatefulWidget {
  const _CommentsSheet({required this.postId});
  final String postId;
  @override
  ConsumerState<_CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends ConsumerState<_CommentsSheet> {
  final _input = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    setState(() => _sending = true);
    try {
      await ref.read(apiClientProvider).post('/posts/${widget.postId}/comments', body: {'body': text});
      _input.clear();
      ref.invalidate(_commentsProvider(widget.postId));
      ref.invalidate(feedPostsProvider);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final comments = ref.watch(_commentsProvider(widget.postId));
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.6,
          maxChildSize: 0.9,
          builder: (ctx, scroll) => Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(AppSpacing.x16),
                child: Text('Comments', style: Theme.of(context).textTheme.titleMedium),
              ),
              const Divider(height: 1),
              Expanded(
                child: comments.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Padding(padding: const EdgeInsets.all(24), child: Text('$e'))),
                  data: (list) => list.isEmpty
                      ? const Center(child: Text('No comments yet. Be the first.'))
                      : ListView(
                          controller: scroll,
                          children: list.map((e) {
                            final c = Map<String, dynamic>.from(e);
                            return ListTile(
                              leading: const Icon(Icons.account_circle_outlined),
                              title: Text('${c['author'] ?? 'Member'}'),
                              subtitle: Text('${c['body'] ?? ''}'),
                            );
                          }).toList(),
                        ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.x12),
                child: Row(children: [
                  Expanded(
                    child: TextField(
                      controller: _input,
                      decoration: const InputDecoration(hintText: 'Write a comment…'),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.x8),
                  IconButton(
                    icon: _sending
                        ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.send),
                    onPressed: _sending ? null : _send,
                  ),
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
