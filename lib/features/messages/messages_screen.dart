import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/responsive.dart';
import '../shell/app_shell.dart';
import 'data/messaging_repository.dart';
import 'domain/conversation.dart';

/// Inbox — the list of the user's conversations. Tapping one opens the thread.
class MessagesScreen extends ConsumerWidget {
  const MessagesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inbox = ref.watch(inboxProvider);
    return Scaffold(
      appBar: const NuzlAppBar(title: 'Messages'),
      drawer: const NuzlDrawer(),
      body: ResponsiveCenter(
        child: inbox.when(
          loading: () => const Center(
              child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator())),
          error: (e, _) => Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(friendlyError(e)))),
          data: (list) => list.isEmpty
              ? const _EmptyInbox()
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.x8),
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const Divider(height: 1, indent: 76),
                  itemBuilder: (_, i) => _ConversationTile(c: list[i]),
                ),
        ),
      ),
    );
  }
}

class _ConversationTile extends StatelessWidget {
  const _ConversationTile({required this.c});
  final Conversation c;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final avatar = c.primaryOther?.avatarUrl;
    final unread = c.unread > 0;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.x16, vertical: 4),
      leading: CircleAvatar(
        radius: 24,
        backgroundColor: AppColors.primaryTint,
        backgroundImage: (avatar != null && avatar.isNotEmpty) ? NetworkImage(avatar) : null,
        child: (avatar == null || avatar.isEmpty)
            ? Text(c.title.isNotEmpty ? c.title[0].toUpperCase() : '?',
                style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700))
            : null,
      ),
      title: Text(c.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: t.titleSmall?.copyWith(fontWeight: unread ? FontWeight.w700 : FontWeight.w600)),
      subtitle: Text(c.lastPreview ?? 'No messages yet',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: t.bodySmall?.copyWith(
            color: unread ? null : (dark ? AppColors.dTextMuted : AppColors.textMuted),
            fontWeight: unread ? FontWeight.w500 : FontWeight.w400,
          )),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(c.lastAt != null ? _shortTime(c.lastAt!) : '',
              style: t.labelSmall?.copyWith(color: dark ? AppColors.dTextMuted : AppColors.textMuted)),
          const SizedBox(height: 4),
          if (unread)
            // Fixed-height, width-capped pill — can never stretch to a full-width bar.
            Container(
              height: 20,
              constraints: const BoxConstraints(minWidth: 20, maxWidth: 40),
              padding: const EdgeInsets.symmetric(horizontal: 6),
              decoration: BoxDecoration(
                  color: AppColors.primary, borderRadius: BorderRadius.circular(AppSpacing.rFull)),
              alignment: Alignment.center,
              child: Text(c.unread > 99 ? '99+' : '${c.unread}',
                  maxLines: 1,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700, height: 1.0)),
            )
          else
            const SizedBox(height: 20),
        ],
      ),
      onTap: () => context.push('/messages/${c.id}'),
    );
  }
}

class _EmptyInbox extends StatelessWidget {
  const _EmptyInbox();
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.x32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.forum_outlined, size: 56, color: dark ? AppColors.dTextSubtle : AppColors.textSubtle),
            const SizedBox(height: AppSpacing.x16),
            Text('No conversations yet', style: t.titleMedium),
            const SizedBox(height: AppSpacing.x8),
            Text('Start a chat from a member’s profile or a listing’s agent card.',
                textAlign: TextAlign.center, style: t.bodyMedium?.copyWith(color: dark ? AppColors.dTextMuted : AppColors.textMuted)),
          ],
        ),
      ),
    );
  }
}

/// Compact timestamp: HH:mm today, weekday this week, else "d MMM".
String _shortTime(DateTime dt) {
  final local = dt.toLocal();
  final now = DateTime.now();
  final sameDay = now.year == local.year && now.month == local.month && now.day == local.day;
  if (sameDay) return DateFormat('HH:mm').format(local);
  if (now.difference(local).inDays < 7) return DateFormat('EEE').format(local);
  return DateFormat('d MMM').format(local);
}
