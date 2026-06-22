import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/app_dialog.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/skeleton_loader.dart';
import '../../core/widgets/responsive.dart';
import '../../core/widgets/status_badge.dart';
import '../auth/application/auth_controller.dart';
import '../shell/app_shell.dart';

final projectsProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  final me = ref.watch(authControllerProvider).user;
  try {
    final d = await ref.read(apiClientProvider).get('/projects',
        query: me?.organizationId != null ? {'org': me!.organizationId} : null);
    return d is List ? d : [];
  } catch (_) {
    return [];
  }
});

BadgeTone _tone(String s) => switch (s) {
      'ready' => BadgeTone.success,
      'under_construction' => BadgeTone.warning,
      'planning' => BadgeTone.gold,
      _ => BadgeTone.neutral,
    };

class ProjectsScreen extends ConsumerWidget {
  const ProjectsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projects = ref.watch(projectsProvider);
    return Scaffold(
      appBar: NuzlAppBar(title: context.tr('Projects')),
      drawer: const NuzlDrawer(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _createProject(context, ref),
        icon: const Icon(Icons.add),
        label: Text(context.tr('New project')),
      ),
      body: ResponsiveCenter(
        child: projects.when(
          loading: () => const SkeletonList(),
          error: (e, _) => Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(friendlyError(e)))),
          data: (list) => list.isEmpty
              ? EmptyState(
                  icon: Icons.apartment_outlined,
                  title: context.tr('No projects yet'),
                  message: context.tr('Create a project, then add units to it to manage your inventory.'),
                  actionLabel: context.tr('New project'),
                  onAction: () => _createProject(context, ref),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(AppSpacing.x16),
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.x8),
                  itemBuilder: (_, i) {
                    final p = Map<String, dynamic>.from(list[i]);
                    final status = '${p['status'] ?? 'planning'}';
                    final handover = DateTime.tryParse('${p['handover_date']}');
                    final units = p['units'] ?? 0;
                    final available = p['available'] ?? 0;
                    return Card(
                      child: ListTile(
                        leading: const Icon(Icons.domain_outlined),
                        title: Text('${p['name'] ?? context.tr('Project')}'),
                        subtitle: Text([
                          '$units ${context.tr('units')}',
                          if ('$available' != '0') '$available ${context.tr('available')}',
                          if (handover != null) '${context.tr('handover')} ${DateFormat('MMM y').format(handover)}',
                        ].join('  ·  ')),
                        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                          StatusBadge(context.tr(_humanize(status)), tone: _tone(status)),
                          const SizedBox(width: 4),
                          const Icon(Icons.chevron_right, color: Colors.grey),
                        ]),
                        onTap: () => context.push('/projects/${p['id']}'),
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }

  Future<void> _createProject(BuildContext context, WidgetRef ref) async {
    final me = ref.read(authControllerProvider).user;
    final name = TextEditingController();
    var status = 'planning';
    final ok = await AppDialog.show<bool>(
      context,
      title: context.tr('New project'),
      children: [
        StatefulBuilder(
          builder: (ctx, setS) => Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: name, decoration: InputDecoration(labelText: context.tr('Project name'))),
            const SizedBox(height: AppSpacing.x8),
            DropdownButtonFormField<String>(
              initialValue: status,
              decoration: InputDecoration(labelText: context.tr('Status')),
              items: [
                DropdownMenuItem(value: 'planning', child: Text(context.tr('Planning'))),
                DropdownMenuItem(value: 'under_construction', child: Text(context.tr('Under construction'))),
                DropdownMenuItem(value: 'ready', child: Text(context.tr('Ready'))),
                DropdownMenuItem(value: 'handover', child: Text(context.tr('Handover'))),
              ],
              onChanged: (v) => setS(() => status = v ?? 'planning'),
            ),
          ]),
        ),
      ],
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: Text(context.tr('Cancel'))),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(context.tr('Create'))),
      ],
    );
    if (ok != true) return;
    if (name.text.trim().isEmpty) return;
    try {
      await ref.read(apiClientProvider).post('/projects', body: {
        'developer_org': me?.organizationId,
        'name': name.text.trim(),
        'status': status,
      });
      ref.invalidate(projectsProvider);
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
