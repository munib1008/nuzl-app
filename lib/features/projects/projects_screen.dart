import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_spacing.dart';
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
      'construction' => BadgeTone.warning,
      'planning' => BadgeTone.gold,
      _ => BadgeTone.neutral,
    };

class ProjectsScreen extends ConsumerWidget {
  const ProjectsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projects = ref.watch(projectsProvider);
    return Scaffold(
      appBar: const NuzlAppBar(title: 'Projects'),
      drawer: const NuzlDrawer(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _createProject(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('New project'),
      ),
      body: ResponsiveCenter(
        child: projects.when(
          loading: () => const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator())),
          error: (e, _) => Center(child: Padding(padding: const EdgeInsets.all(24), child: Text('$e'))),
          data: (list) => list.isEmpty
              ? const Center(child: Padding(padding: EdgeInsets.all(40), child: Text('No projects yet. Create one.')))
              : ListView.separated(
                  padding: const EdgeInsets.all(AppSpacing.x16),
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.x8),
                  itemBuilder: (_, i) {
                    final p = Map<String, dynamic>.from(list[i]);
                    final status = '${p['status'] ?? 'planning'}';
                    final handover = DateTime.tryParse('${p['handover_date']}');
                    final units = p['units'] ?? 0;
                    return Card(
                      child: ListTile(
                        leading: const Icon(Icons.domain_outlined),
                        title: Text('${p['name'] ?? 'Project'}'),
                        subtitle: Text([
                          '$units units',
                          if (handover != null) 'handover ${DateFormat('MMM y').format(handover)}',
                        ].join('  ·  ')),
                        trailing: StatusBadge(_humanize(status), tone: _tone(status)),
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
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New project'),
        content: StatefulBuilder(
          builder: (ctx, setS) => Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: name, decoration: const InputDecoration(labelText: 'Project name')),
            const SizedBox(height: AppSpacing.x8),
            DropdownButtonFormField<String>(
              initialValue: status,
              decoration: const InputDecoration(labelText: 'Status'),
              items: const [
                DropdownMenuItem(value: 'planning', child: Text('Planning')),
                DropdownMenuItem(value: 'construction', child: Text('Construction')),
                DropdownMenuItem(value: 'ready', child: Text('Ready')),
                DropdownMenuItem(value: 'handed_over', child: Text('Handed over')),
              ],
              onChanged: (v) => setS(() => status = v ?? 'planning'),
            ),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Create')),
        ],
      ),
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
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }
}

String _humanize(String k) => k
    .replaceAll('_', ' ')
    .split(' ')
    .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
    .join(' ');
