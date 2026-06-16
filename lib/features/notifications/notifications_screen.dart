import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/responsive.dart';
import '../shell/app_shell.dart';

final notificationsProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  try {
    final d = await ref.read(apiClientProvider).get('/notifications');
    return d is List ? d : [];
  } catch (_) {
    return [];
  }
});

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(notificationsProvider);
    final hasUnread = (items.asData?.value ?? const []).any((e) => (e as Map)['is_read'] != true);
    return Scaffold(
      appBar: NuzlAppBar(
        title: 'Notifications',
        actions: [
          if (hasUnread)
            TextButton(onPressed: () => _markAll(context, ref), child: const Text('Mark all read')),
        ],
      ),
      drawer: const NuzlDrawer(),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(notificationsProvider);
          await ref.read(notificationsProvider.future);
        },
        child: ResponsiveCenter(
          child: items.when(
            loading: () => const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator())),
            error: (e, _) => ListView(children: [
              Padding(padding: const EdgeInsets.all(24), child: Center(child: Text('$e'))),
            ]),
            data: (list) => list.isEmpty
                ? ListView(children: const [
                    Padding(
                      padding: EdgeInsets.all(60),
                      child: Center(child: Text('You’re all caught up — no notifications.')),
                    ),
                  ])
                : ListView.separated(
                    padding: const EdgeInsets.all(AppSpacing.x16),
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.x8),
                    itemBuilder: (_, i) => _NotifCard(n: Map<String, dynamic>.from(list[i])),
                  ),
          ),
        ),
      ),
    );
  }

  Future<void> _markAll(BuildContext context, WidgetRef ref) async {
    final list = ref.read(notificationsProvider).asData?.value ?? const [];
    final unread = list.where((e) => (e as Map)['is_read'] != true).toList();
    try {
      for (final e in unread) {
        await ref.read(apiClientProvider).patch('/notifications/${(e as Map)['id']}/read');
      }
      ref.invalidate(notificationsProvider);
      ref.invalidate(unreadCountProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('All notifications marked read')));
      }
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }
}

String? _deepLink(Map<String, dynamic> n) {
  final table = '${n['ref_table'] ?? ''}';
  final id = '${n['ref_id'] ?? ''}';
  if (id.isEmpty) return null;
  switch (table) {
    case 'listings':
    case 'properties':
      return '/listings/$id';
    case 'buyer_requirements':
      return '/crm';
    case 'viewings':
      return '/viewings/$id/crm';
    case 'conversations':
      return '/messages/$id';
    case 'collaboration_requests':
      return '/collaboration';
    case 'deals':
      return '/deals';
    default:
      return null;
  }
}

String _humanize(String k) => k
    .replaceAll('_', ' ')
    .split(' ')
    .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
    .join(' ');

class _NotifCard extends ConsumerWidget {
  const _NotifCard({required this.n});
  final Map<String, dynamic> n;

  Future<void> _open(BuildContext context, WidgetRef ref) async {
    if (n['is_read'] != true) {
      try {
        await ref.read(apiClientProvider).patch('/notifications/${n['id']}/read');
        ref.invalidate(notificationsProvider);
        ref.invalidate(unreadCountProvider);
      } catch (_) {/* ignore */}
    }
    final route = _deepLink(n);
    if (route != null && context.mounted) context.go(route);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final read = n['is_read'] == true;
    final urgent = '${n['tier']}' == 'urgent';
    final created = DateTime.tryParse('${n['created_at']}');
    final body = '${n['body'] ?? ''}';
    return Card(
      child: ListTile(
        onTap: () => _open(context, ref),
        leading: CircleAvatar(
          backgroundColor: urgent ? AppColors.danger : AppColors.primaryTint,
          child: Icon(urgent ? Icons.priority_high : Icons.notifications_none,
              color: urgent ? Colors.white : AppColors.primary),
        ),
        title: Text('${n['title'] ?? _humanize('${n['type'] ?? 'Notification'}')}',
            style: TextStyle(fontWeight: read ? FontWeight.w400 : FontWeight.w700)),
        subtitle: Text([
          if (body.isNotEmpty) body,
          if (created != null) DateFormat('d MMM · HH:mm').format(created),
        ].join('\n')),
        isThreeLine: body.isNotEmpty,
        trailing: read
            ? null
            : Container(width: 10, height: 10, decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle)),
      ),
    );
  }
}
