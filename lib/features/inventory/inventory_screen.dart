import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/app_dialog.dart';
import '../../core/widgets/responsive.dart';
import '../../core/widgets/status_badge.dart';
import '../auth/application/auth_controller.dart';
import '../shell/app_shell.dart';

const _unitStatuses = ['available', 'reserved', 'sold', 'rented', 'blocked'];

final inventoryProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  try {
    final d = await ref.read(apiClientProvider).get('/inventory');
    return d is List ? d : [];
  } catch (_) {
    return [];
  }
});

BadgeTone _tone(String s) => switch (s) {
      'available' => BadgeTone.success,
      'reserved' => BadgeTone.warning,
      'blocked' => BadgeTone.danger,
      'rented' => BadgeTone.gold,
      _ => BadgeTone.neutral,
    };

class InventoryScreen extends ConsumerWidget {
  const InventoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inventory = ref.watch(inventoryProvider);
    return Scaffold(
      appBar: const NuzlAppBar(title: 'Inventory'),
      drawer: const NuzlDrawer(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _createProject(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('New project'),
      ),
      body: ResponsiveCenter(
        child: inventory.when(
          loading: () => const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator())),
          error: (e, _) => Center(child: Padding(padding: const EdgeInsets.all(24), child: Text('$e'))),
          data: (list) {
            if (list.isEmpty) {
              return const Center(child: Padding(padding: EdgeInsets.all(40), child: Text('No units yet.')));
            }
            final groups = <String, List<Map<String, dynamic>>>{};
            for (final e in list) {
              final m = Map<String, dynamic>.from(e);
              final p = '${m['project'] ?? m['community'] ?? 'Unassigned'}';
              (groups[p] ??= []).add(m);
            }
            final keys = groups.keys.toList();
            return ListView.builder(
              padding: const EdgeInsets.all(AppSpacing.x16),
              itemCount: keys.length,
              itemBuilder: (_, i) {
                final project = keys[i];
                final units = groups[project]!;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: AppSpacing.x8),
                      child: Text(project, style: Theme.of(context).textTheme.titleMedium),
                    ),
                    ...units.map((u) => _UnitTile(u)),
                    const SizedBox(height: AppSpacing.x8),
                  ],
                );
              },
            );
          },
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
      title: 'New project',
      children: [
        StatefulBuilder(
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
      ],
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Create')),
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
      ref.invalidate(inventoryProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Project created')));
      }
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }
}

class _UnitTile extends ConsumerWidget {
  const _UnitTile(this.unit);
  final Map<String, dynamic> unit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = '${unit['inventory_status'] ?? 'available'}';
    final beds = unit['bedrooms'];
    return Card(
      child: ListTile(
        title: Text('${unit['unit_no'] ?? 'Unit'}'),
        subtitle: Text([unit['property_type'], beds != null ? '$beds BR' : null]
            .where((x) => x != null && '$x'.isNotEmpty)
            .join('  ·  ')),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          StatusBadge(status, tone: _tone(status)),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (s) => _setStatus(context, ref, '${unit['id']}', s),
            itemBuilder: (_) => _unitStatuses
                .map((s) => PopupMenuItem(value: s, child: Text('Set ${_humanize(s)}')))
                .toList(),
          ),
        ]),
      ),
    );
  }

  Future<void> _setStatus(BuildContext context, WidgetRef ref, String id, String status) async {
    try {
      await ref.read(apiClientProvider).patch('/inventory/$id/status', body: {'status': status});
      ref.invalidate(inventoryProvider);
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
