import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/upload_service.dart';
import '../../../core/rbac/persona.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_dialog.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/status_badge.dart';
import '../../auth/application/auth_controller.dart';
import '../../shell/app_shell.dart';

/// Feed scope: 'public' (everyone, approved) vs 'company' (internal to my org).
final _feedScopeProvider = StateProvider.autoDispose<String>((ref) => 'public');

/// Professional Feed — social posts (market updates, showcases, success stories…).
final feedPostsProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  final scope = ref.watch(_feedScopeProvider);
  try {
    final d = await ref.read(apiClientProvider).get('/posts', query: {'scope': scope});
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

/// Post categories tailored to the active role (spec §4) — agents talk listings
/// & deals, developers talk projects, providers talk services, etc.
List<(String, String)> _kindsFor(Persona p) {
  switch (p) {
    case Persona.developer:
      return const [
        ('project_update', 'Project update'),
        ('new_launch', 'New launch'),
        ('construction_progress', 'Construction progress'),
        ('unit_release', 'Unit release'),
        ('investment_opportunity', 'Investment opportunity'),
        ('success_story', 'Success story'),
      ];
    case Persona.provider:
      return const [
        ('service_promotion', 'Service promotion'),
        ('completed_project', 'Completed project'),
        ('tips_advice', 'Tips & advice'),
        ('success_story', 'Success story'),
      ];
    case Persona.agent:
    case Persona.salesperson:
    case Persona.broker:
      return const [
        ('market_update', 'Market update'),
        ('new_listing', 'New listing'),
        ('buyer_requirement', 'Buyer requirement'),
        ('off_market_deal', 'Off-market deal'),
        ('deal_closed', 'Deal closed'),
        ('property_showcase', 'Property showcase'),
        ('success_story', 'Success story'),
        ('educational', 'Educational'),
      ];
    default:
      return const [
        ('market_update', 'Market update'),
        ('property_showcase', 'Property showcase'),
        ('success_story', 'Success story'),
        ('educational', 'Educational'),
      ];
  }
}

/// Public (everyone) vs Company (internal team) feed switch.
class _ScopeToggle extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scope = ref.watch(_feedScopeProvider);
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.x16, AppSpacing.x12, AppSpacing.x16, 0),
      child: SegmentedButton<String>(
        segments: const [
          ButtonSegment(value: 'public', label: Text('Public'), icon: Icon(Icons.public, size: 16)),
          ButtonSegment(value: 'company', label: Text('Company'), icon: Icon(Icons.apartment, size: 16)),
        ],
        selected: {scope},
        showSelectedIcon: false,
        onSelectionChanged: (s) => ref.read(_feedScopeProvider.notifier).state = s.first,
      ),
    );
  }
}

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
      body: Column(children: [
        if (ref.watch(authControllerProvider).user?.organizationId != null) _ScopeToggle(),
        Expanded(
          child: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(feedPostsProvider);
          await ref.read(feedPostsProvider.future);
        },
        child: posts.when(
          loading: () => const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator())),
          error: (e, _) => ListView(children: [Padding(padding: const EdgeInsets.all(24), child: Center(child: Text(friendlyError(e))))]),
          data: (list) => list.isEmpty
              ? ListView(children: const [
                  EmptyState(
                    icon: Icons.dynamic_feed_outlined,
                    title: 'No posts yet',
                    message: 'Share a market update or a success story to start the conversation.',
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
        ),
      ]),
    );
  }

  Future<void> _composer(BuildContext context, WidgetRef ref) async {
    final title = TextEditingController();
    final body = TextEditingController();
    final kinds = _kindsFor(ref.read(personaProvider));
    var kind = kinds.first.$1;
    final hasOrg = ref.read(authControllerProvider).user?.organizationId != null;
    // Default the audience to whichever feed the user is currently viewing, so a
    // post doesn't silently land in a scope they're not looking at.
    var audience = hasOrg ? ref.read(_feedScopeProvider) : 'public';
    var uploading = false;
    final media = <String>[];
    final mentions = <Map<String, dynamic>>[]; // {id, name}
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
              items: kinds.map((k) => DropdownMenuItem(value: k.$1, child: Text(k.$2))).toList(),
              onChanged: (v) => setS(() => kind = v ?? kinds.first.$1),
            ),
            if (hasOrg) ...[
              const SizedBox(height: AppSpacing.x8),
              DropdownButtonFormField<String>(
                initialValue: audience,
                decoration: const InputDecoration(labelText: 'Audience'),
                items: const [
                  DropdownMenuItem(value: 'public', child: Text('Public — everyone')),
                  DropdownMenuItem(value: 'company', child: Text('Company — internal team only')),
                ],
                onChanged: (v) => setS(() => audience = v ?? 'public'),
              ),
              if (audience == 'public')
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text('Company marketing posts are reviewed before going live.',
                      style: Theme.of(ctx).textTheme.bodySmall?.copyWith(color: Theme.of(ctx).hintColor)),
                ),
            ],
            const SizedBox(height: AppSpacing.x8),
            TextField(controller: title, decoration: const InputDecoration(labelText: 'Title')),
            const SizedBox(height: AppSpacing.x8),
            TextField(controller: body, maxLines: 4, decoration: const InputDecoration(labelText: 'Share an update…')),
            const SizedBox(height: AppSpacing.x8),
            Align(
              alignment: Alignment.centerLeft,
              child: Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
                for (final url in media)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppSpacing.rMd),
                    child: Image.network(url, width: 56, height: 56, fit: BoxFit.cover),
                  ),
                OutlinedButton.icon(
                  onPressed: uploading
                      ? null
                      : () async {
                          final picked = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1280, imageQuality: 70);
                          if (picked == null) return;
                          final bytes = await picked.readAsBytes();
                          setS(() => uploading = true);
                          try {
                            final url = await ref.read(uploadServiceProvider).upload(bytes, picked.name, 'image/jpeg');
                            if (url != null) {
                              setS(() => media.add(url));
                            } else if (ctx.mounted) {
                              ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Photo upload failed — please try again')));
                            }
                          } catch (e) {
                            if (ctx.mounted) {
                              ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Photo upload failed — ${friendlyError(e)}')));
                            }
                          } finally {
                            setS(() => uploading = false);
                          }
                        },
                  icon: uploading
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.add_photo_alternate_outlined, size: 18),
                  label: Text(uploading ? 'Uploading…' : 'Photo'),
                ),
                OutlinedButton.icon(
                  onPressed: () async {
                    final picked = await _pickUser(ctx, ref);
                    if (picked == null) return;
                    if (mentions.any((m) => m['id'] == picked['id'])) return;
                    setS(() => mentions.add(picked));
                  },
                  icon: const Icon(Icons.alternate_email, size: 18),
                  label: const Text('Tag'),
                ),
              ]),
            ),
            if (mentions.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.x8),
              Align(
                alignment: Alignment.centerLeft,
                child: Wrap(spacing: 6, runSpacing: 6, children: [
                  for (final m in mentions)
                    InputChip(
                      label: Text('@${m['name'] ?? 'user'}'),
                      onDeleted: () => setS(() => mentions.removeWhere((x) => x['id'] == m['id'])),
                    ),
                ]),
              ),
            ],
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
        'audience': audience,
        'title': title.text.trim(),
        'body': body.text.trim(),
        if (media.isNotEmpty) 'media': media,
        if (mentions.isNotEmpty) 'mentions': mentions.map((m) => m['id']).toList(),
      });
      // Switch the feed to the scope we just posted to, so the new post is
      // visible immediately instead of landing in a tab the user isn't viewing.
      if (hasOrg) ref.read(_feedScopeProvider.notifier).state = audience;
      ref.invalidate(feedPostsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(
            audience == 'company' ? 'Posted to your company feed' : 'Posted — public marketing posts may be reviewed first')));
      }
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
    }
  }
}

/// Name-search picker used by the composer's "Tag" button. Returns {id, name}.
Future<Map<String, dynamic>?> _pickUser(BuildContext context, WidgetRef ref) {
  final search = TextEditingController();
  var results = <Map<String, dynamic>>[];
  return showDialog<Map<String, dynamic>>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setS) {
        Future<void> run(String q) async {
          if (q.trim().length < 2) {
            setS(() => results = []);
            return;
          }
          try {
            final r = await ref.read(apiClientProvider).get('/users/search', query: {'q': q.trim()});
            setS(() => results = (r as List).cast<Map<String, dynamic>>());
          } catch (_) {
            setS(() => results = []);
          }
        }

        return AlertDialog(
          title: const Text('Tag someone'),
          content: SizedBox(
            width: MediaQuery.sizeOf(ctx).width - 80 < 360 ? MediaQuery.sizeOf(ctx).width - 80 : 360,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(
                controller: search,
                autofocus: true,
                decoration: const InputDecoration(hintText: 'Search by name…', prefixIcon: Icon(Icons.search)),
                onChanged: run,
              ),
              const SizedBox(height: AppSpacing.x8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 280),
                child: results.isEmpty
                    ? const Padding(padding: EdgeInsets.all(16), child: Text('Type at least 2 letters to search'))
                    : ListView(
                        shrinkWrap: true,
                        children: [
                          for (final u in results)
                            ListTile(
                              dense: true,
                              leading: const CircleAvatar(child: Icon(Icons.person, size: 18)),
                              title: Text('${u['full_name'] ?? 'User'}'),
                              subtitle: u['role'] != null ? Text('${u['role']}') : null,
                              onTap: () => Navigator.pop(ctx, {'id': u['id'], 'name': u['full_name']}),
                            ),
                        ],
                      ),
              ),
            ]),
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))],
        );
      },
    ),
  );
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
    final dark = Theme.of(context).brightness == Brightness.dark;
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
                    Text(DateFormat('d MMM · HH:mm').format(created), style: t.bodySmall?.copyWith(color: dark ? AppColors.dTextMuted : AppColors.textMuted)),
                ]),
              ),
              StatusBadge(label, tone: tone),
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert, size: 18, color: dark ? AppColors.dTextMuted : AppColors.textMuted),
                onSelected: (v) { if (v == 'report') _report(context, ref); },
                itemBuilder: (_) => const [PopupMenuItem(value: 'report', child: Text('Report post'))],
              ),
            ]),
            if (title.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.x12),
              Text(title, style: t.titleMedium),
            ],
            if (body.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.x4),
              Text(body, style: t.bodyMedium),
            ],
            if (p['media'] is List && (p['media'] as List).isNotEmpty) ...[
              const SizedBox(height: AppSpacing.x8),
              Wrap(spacing: 6, runSpacing: 6, children: [
                for (final m in (p['media'] as List))
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppSpacing.rMd),
                    child: Image.network('$m', width: 110, height: 110, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const SizedBox.shrink()),
                  ),
              ]),
            ],
            if (p['mention_users'] is List && (p['mention_users'] as List).isNotEmpty) ...[
              const SizedBox(height: AppSpacing.x8),
              Row(children: [
                Icon(Icons.alternate_email, size: 14, color: t.bodySmall?.color),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    (p['mention_users'] as List).map((m) => '@${m['name'] ?? 'user'}').join('  '),
                    style: t.bodySmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ]),
            ],
            const SizedBox(height: AppSpacing.x12),
            Row(children: [
              _ActionButton(
                icon: liked ? Icons.favorite : Icons.favorite_border,
                label: '$likeCount',
                color: liked ? AppColors.danger : (dark ? AppColors.dTextMuted : AppColors.textMuted),
                onTap: () => _like(ref),
              ),
              const SizedBox(width: AppSpacing.x16),
              _ActionButton(
                icon: Icons.mode_comment_outlined,
                label: '$commentCount',
                color: dark ? AppColors.dTextMuted : AppColors.textMuted,
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

  Future<void> _report(BuildContext context, WidgetRef ref) async {
    var reason = 'spam';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('Report post'),
          content: DropdownButtonFormField<String>(
            initialValue: reason,
            decoration: const InputDecoration(labelText: 'Reason'),
            items: const [
              DropdownMenuItem(value: 'spam', child: Text('Spam')),
              DropdownMenuItem(value: 'inappropriate', child: Text('Inappropriate')),
              DropdownMenuItem(value: 'misleading', child: Text('Misleading')),
              DropdownMenuItem(value: 'duplicate', child: Text('Duplicate')),
              DropdownMenuItem(value: 'other', child: Text('Other')),
            ],
            onChanged: (v) => setS(() => reason = v ?? 'spam'),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Report')),
          ],
        ),
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(apiClientProvider).post('/posts/${p['id']}/report', body: {'reason': reason});
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Reported — thank you')));
      }
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
    }
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
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
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
                  error: (e, _) => Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(friendlyError(e)))),
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
