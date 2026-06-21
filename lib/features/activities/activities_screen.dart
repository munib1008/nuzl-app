import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/app_dialog.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/skeleton_loader.dart';
import '../../core/widgets/responsive.dart';
import '../crm/crm_scaffold.dart';

final activitiesProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  try {
    final d = await ref.read(apiClientProvider).get('/activity/mine');
    return d is List ? d : [];
  } catch (_) {
    return [];
  }
});

class ActivitiesScreen extends ConsumerWidget {
  const ActivitiesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activities = ref.watch(activitiesProvider);
    return CrmScaffold(
      tab: CrmTab.activities,
      title: 'Activities',
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addDialog(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Log activity'),
      ),
      body: ResponsiveCenter(
        child: activities.when(
          loading: () => const SkeletonList(),
          error: (e, _) => Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(friendlyError(e)))),
          data: (list) => list.isEmpty
              ? EmptyState(
                  icon: Icons.timeline_outlined,
                  title: 'No activity yet',
                  message: 'Log calls, meetings and notes to keep a timeline of your work.',
                  actionLabel: 'Log activity',
                  onAction: () => _addDialog(context, ref),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(AppSpacing.x16),
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.x8),
                  itemBuilder: (_, i) {
                    final a = Map<String, dynamic>.from(list[i]);
                    final created = DateTime.tryParse('${a['created_at']}');
                    final note = '${a['note'] ?? ''}';
                    return Card(
                      child: ListTile(
                        leading: const CircleAvatar(child: Icon(Icons.event_note_outlined)),
                        title: Text(_humanize('${a['activity_type'] ?? 'activity'}')),
                        subtitle: note.isNotEmpty ? Text(note) : null,
                        trailing: created != null
                            ? Text(DateFormat('d MMM').format(created), style: Theme.of(context).textTheme.bodySmall)
                            : null,
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }

  Future<void> _addDialog(BuildContext context, WidgetRef ref) async {
    final type = TextEditingController();
    final note = TextEditingController();
    final ok = await AppDialog.show<bool>(
      context,
      title: 'Log activity',
      children: [
        TextField(controller: type, decoration: const InputDecoration(labelText: 'Type', hintText: 'call, viewing, follow_up…')),
        TextField(controller: note, decoration: const InputDecoration(labelText: 'Note'), maxLines: 2),
      ],
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save')),
      ],
    );
    if (ok != true) return;
    if (type.text.trim().isEmpty) return;
    try {
      await ref.read(apiClientProvider).post('/activity', body: {
        'activity_type': type.text.trim(),
        if (note.text.trim().isNotEmpty) 'note': note.text.trim(),
      });
      ref.invalidate(activitiesProvider);
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
    }
  }
}

String _humanize(String k) => k
    .replaceAll('_', ' ')
    .split(' ')
    .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
    .join(' ');
