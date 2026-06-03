import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/responsive.dart';
import '../shell/app_shell.dart';

/// Structured comms log built on the notifications module (no free chat).
final messagesProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  try {
    final d = await ref.read(apiClientProvider).get('/notifications');
    return d is List ? d : [];
  } catch (_) {
    return [];
  }
});

class MessagesScreen extends ConsumerWidget {
  const MessagesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final messages = ref.watch(messagesProvider);
    return Scaffold(
      appBar: const NuzlAppBar(title: 'Messages'),
      drawer: const NuzlDrawer(),
      body: ResponsiveCenter(
        child: messages.when(
          loading: () => const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator())),
          error: (e, _) => Center(child: Padding(padding: const EdgeInsets.all(24), child: Text('$e'))),
          data: (list) => list.isEmpty
              ? const Center(child: Padding(padding: EdgeInsets.all(40), child: Text('No messages yet.')))
              : ListView.separated(
                  padding: const EdgeInsets.all(AppSpacing.x16),
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.x8),
                  itemBuilder: (_, i) {
                    final n = Map<String, dynamic>.from(list[i]);
                    final read = n['is_read'] == true;
                    final urgent = '${n['tier']}' == 'urgent';
                    final created = DateTime.tryParse('${n['created_at']}');
                    final body = '${n['body'] ?? ''}';
                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: urgent ? AppColors.danger : AppColors.primaryTint,
                          child: Icon(urgent ? Icons.priority_high : Icons.notifications_none,
                              color: urgent ? Colors.white : AppColors.primary),
                        ),
                        title: Text('${n['title'] ?? _humanize('${n['type'] ?? 'Notification'}')}',
                            style: TextStyle(fontWeight: read ? FontWeight.w400 : FontWeight.w700)),
                        subtitle: body.isNotEmpty ? Text(body) : null,
                        isThreeLine: body.isNotEmpty,
                        trailing: read
                            ? (created != null
                                ? Text(DateFormat('d MMM').format(created), style: Theme.of(context).textTheme.bodySmall)
                                : null)
                            : TextButton(onPressed: () => _markRead(context, ref, '${n['id']}'), child: const Text('Mark read')),
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }

  Future<void> _markRead(BuildContext context, WidgetRef ref, String id) async {
    try {
      await ref.read(apiClientProvider).patch('/notifications/$id/read');
      ref.invalidate(messagesProvider);
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }
}

String _humanize(String k) => k
    .replaceAll('_', ' ')
    .split(' ')
    .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
    .join(' ');
