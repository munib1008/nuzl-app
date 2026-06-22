import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/upload_service.dart';
import '../../../core/rbac/persona.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_dialog.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../../core/widgets/status_badge.dart';
import '../../auth/application/auth_controller.dart';
import '../../shell/app_shell.dart';

// Community Board category filter ('' = All); filters the loaded posts by kind.
final _feedCategoryProvider = StateProvider.autoDispose<String>((ref) => '');

/// Posts by scope: 'public' (the public Feed — everyone) vs 'company' (the
/// agents-only Community discussion). Keyed by scope so the two surfaces load
/// independently and never clobber each other.
final feedPostsProvider = FutureProvider.autoDispose.family<List<dynamic>, String>((ref, scope) async {
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

/// Community Board category filter — All + the role's post categories, filtering
/// the feed by kind (client-side over the loaded posts).
class _CategoryBar extends ConsumerWidget {
  const _CategoryBar();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final persona = ref.watch(personaProvider);
    final selected = ref.watch(_feedCategoryProvider);
    final cats = <(String, String)>[('', 'All'), ..._kindsFor(persona)];
    return SizedBox(
      height: 46,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x12, vertical: AppSpacing.x8),
        children: [
          for (final c in cats)
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.x8),
              child: ChoiceChip(
                label: Text(context.tr(c.$2)),
                selected: selected == c.$1,
                onSelected: (_) => ref.read(_feedCategoryProvider.notifier).state = c.$1,
              ),
            ),
        ],
      ),
    );
  }
}

/// The public Feed (everyone) — and, when [embedded], the body reused inside the
/// agents-only Community "Discussion" tab.
///
/// - `scope: 'public'`  → the public Feed, visible to and postable by everyone.
/// - `scope: 'company'` → the professional/agents discussion (Community).
class FeedScreen extends ConsumerWidget {
  const FeedScreen({super.key, this.embedded = false, this.scope = 'public'});

  /// When embedded (e.g. inside the Community tabs) render only the body — no
  /// Scaffold / app-bar / drawer / FAB; the host provides those.
  final bool embedded;
  final String scope;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final body = _FeedBody(scope: scope);
    if (embedded) return body;
    final persona = ref.watch(personaProvider);
    final canPost = persona.canManageLeads || persona.canListProperty;
    return Scaffold(
      appBar: NuzlAppBar(title: context.tr('Feed')),
      drawer: const NuzlDrawer(),
      floatingActionButton: canPost
          ? FloatingActionButton.extended(
              onPressed: () => openFeedComposer(context, ref, audience: 'public'),
              icon: const Icon(Icons.edit_outlined),
              label: Text(context.tr('New post')),
            )
          : null,
      body: body,
    );
  }
}

/// Feed body for a given scope — category filter + posts list. Reused by the
/// public [FeedScreen] and the Community "Discussion" tab.
class _FeedBody extends ConsumerWidget {
  const _FeedBody({required this.scope});
  final String scope;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final posts = ref.watch(feedPostsProvider(scope));
    return Column(children: [
      const _CategoryBar(),
      Expanded(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(feedPostsProvider(scope));
            await ref.read(feedPostsProvider(scope).future);
          },
          child: posts.when(
            loading: () => const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator())),
            error: (e, _) => ListView(children: [Padding(padding: const EdgeInsets.all(24), child: Center(child: Text(friendlyError(e))))]),
            data: (list) {
              final cat = ref.watch(_feedCategoryProvider);
              final filtered = cat.isEmpty
                  ? list
                  : list.where((p) {
                      final m = p as Map;
                      return '${m['kind'] ?? m['post_type'] ?? ''}' == cat;
                    }).toList();
              if (filtered.isEmpty) {
                final persona = ref.watch(personaProvider);
                final canPost = persona.canManageLeads || persona.canListProperty;
                return ListView(children: [
                  EmptyState(
                    icon: Icons.dynamic_feed_outlined,
                    title: context.tr(cat.isEmpty ? 'No posts yet' : 'Nothing in this category yet'),
                    message: context.tr(cat.isEmpty
                        ? 'Share a market update or a success story to start the conversation.'
                        : 'Be the first to post in this category.'),
                    actionLabel: canPost ? context.tr('New post') : null,
                    onAction: canPost ? () => openFeedComposer(context, ref, audience: scope) : null,
                  ),
                ]);
              }
              return Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: ListView.separated(
                    padding: const EdgeInsets.all(AppSpacing.x16),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.x12),
                    itemBuilder: (_, i) => _PostCard(Map<String, dynamic>.from(filtered[i])),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    ]);
  }
}

/// Opens the new-post composer. [audience] is fixed by the surface that opens it
/// ('public' from the Feed; 'company' from the agents-only Community), so there's
/// no audience picker — you post where you are.
Future<void> openFeedComposer(BuildContext context, WidgetRef ref, {required String audience}) async {
  final title = TextEditingController();
  final body = TextEditingController();
  final kinds = _kindsFor(ref.read(personaProvider));
  var kind = kinds.first.$1;
  var uploading = false;
  final media = <String>[];
  final mentions = <Map<String, dynamic>>[]; // {id, name}
  final ok = await AppDialog.show<bool>(
    context,
    title: context.tr('New post'),
    maxWidth: 460,
    children: [
      StatefulBuilder(
        builder: (ctx, setS) => Column(mainAxisSize: MainAxisSize.min, children: [
          // Primary inputs first so they're visible the moment the sheet opens.
          TextField(controller: title, autofocus: true, textInputAction: TextInputAction.next,
              decoration: InputDecoration(labelText: context.tr('Title'))),
          const SizedBox(height: AppSpacing.x8),
          TextField(controller: body, minLines: 2, maxLines: 4,
              decoration: InputDecoration(labelText: context.tr('Share an update…'))),
          const SizedBox(height: AppSpacing.x8),
          DropdownButtonFormField<String>(
            initialValue: kind,
            decoration: InputDecoration(labelText: context.tr('Category')),
            items: kinds.map((k) => DropdownMenuItem(value: k.$1, child: Text(context.tr(k.$2)))).toList(),
            onChanged: (v) => setS(() => kind = v ?? kinds.first.$1),
          ),
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
                            ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(ctx.tr('Photo upload failed — try again'))));
                          }
                        } catch (e) {
                          if (ctx.mounted) {
                            ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('${ctx.tr('Photo upload failed')} — ${friendlyError(e)}')));
                          }
                        } finally {
                          setS(() => uploading = false);
                        }
                      },
                icon: uploading
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.add_photo_alternate_outlined, size: 18),
                label: Text(context.tr(uploading ? 'Uploading…' : 'Photo')),
              ),
              OutlinedButton.icon(
                onPressed: () async {
                  final picked = await _pickUser(ctx, ref);
                  if (picked == null) return;
                  if (mentions.any((m) => m['id'] == picked['id'])) return;
                  setS(() => mentions.add(picked));
                },
                icon: const Icon(Icons.alternate_email, size: 18),
                label: Text(context.tr('Tag')),
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
      TextButton(onPressed: () => Navigator.pop(context, false), child: Text(context.tr('Cancel'))),
      FilledButton(
        onPressed: () {
          if (title.text.trim().isEmpty && body.text.trim().isEmpty) {
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(SnackBar(content: Text(context.tr('Add a title or a few words to post.'))));
            return;
          }
          Navigator.pop(context, true);
        },
        child: Text(context.tr('Post')),
      ),
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
    // Refresh both surfaces (the family) so the new post shows wherever relevant.
    ref.invalidate(feedPostsProvider);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.tr(
          audience == 'company' ? 'Posted to your Community' : 'Posted — public marketing posts may be reviewed first'))));
    }
  } catch (e) {
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
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
          title: Text(ctx.tr('Tag someone')),
          content: SizedBox(
            width: MediaQuery.sizeOf(ctx).width - 80 < 360 ? MediaQuery.sizeOf(ctx).width - 80 : 360,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(
                controller: search,
                autofocus: true,
                decoration: InputDecoration(hintText: ctx.tr('Search by name…'), prefixIcon: const Icon(Icons.search)),
                onChanged: run,
              ),
              const SizedBox(height: AppSpacing.x8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 280),
                child: results.isEmpty
                    ? Padding(padding: const EdgeInsets.all(16), child: Text(ctx.tr('Type at least 2 letters to search')))
                    : ListView(
                        shrinkWrap: true,
                        children: [
                          for (final u in results)
                            ListTile(
                              dense: true,
                              leading: UserAvatar(name: '${u['full_name'] ?? ctx.tr('User')}', url: '${u['avatar_url'] ?? ''}', radius: 16),
                              title: Text('${u['full_name'] ?? ctx.tr('User')}'),
                              subtitle: u['role'] != null ? Text('${u['role']}') : null,
                              onTap: () => Navigator.pop(ctx, {'id': u['id'], 'name': u['full_name']}),
                            ),
                        ],
                      ),
              ),
            ]),
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text(ctx.tr('Close')))],
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

class _PostCard extends ConsumerStatefulWidget {
  const _PostCard(this.p);
  final Map<String, dynamic> p;
  @override
  ConsumerState<_PostCard> createState() => _PostCardState();
}

class _PostCardState extends ConsumerState<_PostCard> {
  // Optimistic local like state — toggles instantly, reconciles with the server.
  late bool _liked = widget.p['liked'] == true;
  late int _likeCount = int.tryParse('${widget.p['like_count'] ?? 0}') ?? 0;
  Map<String, dynamic> get p => widget.p;

  @override
  void didUpdateWidget(covariant _PostCard old) {
    super.didUpdateWidget(old);
    // If this card is recycled for a different post, resync from the new data.
    if (old.p['id'] != widget.p['id']) {
      _liked = widget.p['liked'] == true;
      _likeCount = int.tryParse('${widget.p['like_count'] ?? 0}') ?? 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final author = '${p['author'] ?? context.tr('Member')}';
    final created = DateTime.tryParse('${p['created_at']}');
    final liked = _liked;
    final likeCount = _likeCount;
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
              UserAvatar(name: author, url: '${p['author_avatar'] ?? ''}'),
              const SizedBox(width: AppSpacing.x12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(author, style: t.titleSmall),
                  if (created != null)
                    Text(DateFormat('d MMM · HH:mm').format(created), style: t.bodySmall?.copyWith(color: dark ? AppColors.dTextMuted : AppColors.textMuted)),
                ]),
              ),
              StatusBadge(context.tr(label), tone: tone),
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert, size: 18, color: dark ? AppColors.dTextMuted : AppColors.textMuted),
                onSelected: (v) { if (v == 'report') _report(context, ref); },
                itemBuilder: (_) => [PopupMenuItem(value: 'report', child: Text(context.tr('Report post')))],
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
    // Optimistic: flip instantly, fire the call, revert only if it fails.
    final prevLiked = _liked, prevCount = _likeCount;
    setState(() {
      _liked = !_liked;
      _likeCount = (_likeCount + (_liked ? 1 : -1)).clamp(0, 1 << 30);
    });
    try {
      await ref.read(apiClientProvider).post('/posts/${p['id']}/like');
    } catch (_) {
      if (mounted) setState(() { _liked = prevLiked; _likeCount = prevCount; });
    }
  }

  Future<void> _report(BuildContext context, WidgetRef ref) async {
    var reason = 'spam';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: Text(context.tr('Report post')),
          content: DropdownButtonFormField<String>(
            initialValue: reason,
            decoration: InputDecoration(labelText: context.tr('Reason')),
            items: [
              DropdownMenuItem(value: 'spam', child: Text(context.tr('Spam'))),
              DropdownMenuItem(value: 'inappropriate', child: Text(context.tr('Inappropriate'))),
              DropdownMenuItem(value: 'misleading', child: Text(context.tr('Misleading'))),
              DropdownMenuItem(value: 'duplicate', child: Text(context.tr('Duplicate'))),
              DropdownMenuItem(value: 'other', child: Text(context.tr('Other'))),
            ],
            onChanged: (v) => setS(() => reason = v ?? 'spam'),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(context.tr('Cancel'))),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(context.tr('Report'))),
          ],
        ),
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(apiClientProvider).post('/posts/${p['id']}/report', body: {'reason': reason});
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.tr('Reported — thank you'))));
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
  // Optimistic comments — shown the instant Send is tapped, reconciled on reopen.
  final _optimistic = <Map<String, dynamic>>[];

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    final me = ref.read(authControllerProvider).user;
    final temp = <String, dynamic>{
      'author': me?.fullName ?? context.tr('You'),
      'author_avatar': me?.avatarUrl ?? '',
      'body': text,
    };
    // Append instantly + clear the box; no spinner, no refetch flicker.
    setState(() { _optimistic.add(temp); _input.clear(); });
    try {
      await ref.read(apiClientProvider).post('/posts/${widget.postId}/comments', body: {'body': text});
      ref.invalidate(feedPostsProvider); // bump the post's comment count underneath
    } catch (e) {
      if (mounted) {
        setState(() { _optimistic.remove(temp); _input.text = text; });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
      }
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
                child: Text(context.tr('Comments'), style: Theme.of(context).textTheme.titleMedium),
              ),
              const Divider(height: 1),
              Expanded(
                child: comments.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(friendlyError(e)))),
                  data: (list) {
                    final all = [...list.map((e) => Map<String, dynamic>.from(e)), ..._optimistic];
                    return all.isEmpty
                        ? Center(child: Text(context.tr('No comments yet. Be the first.')))
                        : ListView(
                            controller: scroll,
                            children: all.map((c) {
                              return ListTile(
                                leading: UserAvatar(name: '${c['author'] ?? context.tr('Member')}', url: '${c['author_avatar'] ?? ''}', radius: 16),
                                title: Text('${c['author'] ?? context.tr('Member')}'),
                                subtitle: Text('${c['body'] ?? ''}'),
                              );
                            }).toList(),
                          );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.x12),
                child: Row(children: [
                  Expanded(
                    child: TextField(
                      controller: _input,
                      decoration: InputDecoration(hintText: context.tr('Write a comment…')),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.x8),
                  IconButton(
                    icon: const Icon(Icons.send),
                    onPressed: _send,
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
