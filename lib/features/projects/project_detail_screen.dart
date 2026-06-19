import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/network/api_client.dart';
import '../../core/network/upload_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/app_dialog.dart';
import '../../core/widgets/responsive.dart';
import '../../core/widgets/status_badge.dart';
import '../shell/app_shell.dart';

/// GET /projects/:id → { project, units }
final projectDetailProvider =
    FutureProvider.autoDispose.family<Map<String, dynamic>, String>((ref, id) async {
  final d = await ref.read(apiClientProvider).get('/projects/$id');
  return d is Map ? Map<String, dynamic>.from(d) : <String, dynamic>{};
});

/// GET /inventory/agents → agents a developer can distribute units to.
final assignableAgentsProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  try {
    final d = await ref.read(apiClientProvider).get('/inventory/agents');
    return d is List ? d : [];
  } catch (_) {
    return [];
  }
});

BadgeTone _unitTone(String? s) => switch (s) {
      'available' => BadgeTone.success,
      'reserved' => BadgeTone.warning,
      'blocked' => BadgeTone.danger,
      'rented' => BadgeTone.gold,
      'sold' => BadgeTone.neutral,
      _ => BadgeTone.neutral,
    };

class ProjectDetailScreen extends ConsumerWidget {
  const ProjectDetailScreen({super.key, required this.projectId});
  final String projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(projectDetailProvider(projectId));
    return Scaffold(
      appBar: const NuzlAppBar(title: 'Project'),
      drawer: const NuzlDrawer(),
      body: ResponsiveCenter(
        child: detail.when(
          loading: () => const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator())),
          error: (e, _) => Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(friendlyError(e)))),
          data: (d) {
            final p = Map<String, dynamic>.from(d['project'] ?? {});
            final units = (d['units'] as List? ?? []);
            return ListView(
              padding: const EdgeInsets.all(AppSpacing.x16),
              children: [
                _header(context, ref, p),
                const SizedBox(height: AppSpacing.x16),
                _availability(context, p),
                const SizedBox(height: AppSpacing.x16),
                _actions(context, ref, p),
                const SizedBox(height: AppSpacing.x16),
                Text('Units (${units.length})',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: AppSpacing.x8),
                if (units.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: AppSpacing.x24),
                    child: Center(child: Text('No units yet. Use “Add units”, then “Release” them to market.')),
                  )
                else
                  ...units.map((u) => _unitTile(context, ref, Map<String, dynamic>.from(u))),
              ],
            );
          },
        ),
      ),
    );
  }

  // ── Header: name, status, location, plans ──
  Widget _header(BuildContext context, WidgetRef ref, Map<String, dynamic> p) {
    final t = Theme.of(context).textTheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final status = '${p['status'] ?? 'planning'}';
    final handover = DateTime.tryParse('${p['handover_date']}');
    final priceFrom = num.tryParse('${p['price_from']}');
    final aed = NumberFormat.currency(symbol: 'AED ', decimalDigits: 0);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.x16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
              child: Text('${p['name'] ?? 'Project'}',
                  style: t.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
            ),
            StatusBadge(_humanize(status), tone: _projectTone(status)),
          ]),
          if ('${p['location'] ?? ''}'.trim().isNotEmpty || '${p['community'] ?? ''}'.trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Row(children: [
              Icon(Icons.place_outlined, size: 16, color: dark ? AppColors.dTextMuted : AppColors.textMuted),
              const SizedBox(width: 4),
              Text([p['location'], p['community']].where((e) => '$e'.trim().isNotEmpty).join(', '),
                  style: t.bodyMedium?.copyWith(color: dark ? AppColors.dTextMuted : AppColors.textMuted)),
            ]),
          ],
          const SizedBox(height: AppSpacing.x8),
          Wrap(spacing: AppSpacing.x16, runSpacing: 6, children: [
            if (handover != null) _meta(Icons.event_outlined, 'Handover ${DateFormat('MMM y').format(handover)}', dark),
            if (priceFrom != null && priceFrom > 0) _meta(Icons.sell_outlined, 'From ${aed.format(priceFrom)}', dark),
          ]),
          if ('${p['description'] ?? ''}'.trim().isNotEmpty) ...[
            const SizedBox(height: AppSpacing.x8),
            Text('${p['description']}', style: t.bodyMedium),
          ],
          const SizedBox(height: AppSpacing.x12),
          Wrap(spacing: AppSpacing.x8, runSpacing: AppSpacing.x8, children: [
            _planChip(context, ref, p, label: 'Masterplan', field: 'masterplan_url'),
            _planChip(context, ref, p, label: 'Brochure', field: 'brochure_url'),
            OutlinedButton.icon(
              onPressed: () => _editProject(context, ref, p),
              icon: const Icon(Icons.edit_outlined, size: 16),
              label: const Text('Edit'),
            ),
          ]),
        ]),
      ),
    );
  }

  Widget _meta(IconData i, String s, bool dark) => Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(i, size: 16, color: dark ? AppColors.dTextMuted : AppColors.textMuted),
        const SizedBox(width: 4),
        Text(s, style: TextStyle(color: dark ? AppColors.dTextMuted : AppColors.textMuted)),
      ]);

  Widget _planChip(BuildContext context, WidgetRef ref, Map<String, dynamic> p,
      {required String label, required String field}) {
    final url = '${p[field] ?? ''}'.trim();
    final has = url.isNotEmpty;
    return OutlinedButton.icon(
      onPressed: () async {
        if (has) {
          await launchUrl(Uri.parse(url), webOnlyWindowName: '_blank');
        } else {
          await _uploadPlan(context, ref, '${p['id']}', field);
        }
      },
      icon: Icon(has ? Icons.description_outlined : Icons.upload_file_outlined, size: 16),
      label: Text(has ? 'View $label' : 'Upload $label'),
      style: OutlinedButton.styleFrom(
        foregroundColor: has ? Theme.of(context).colorScheme.primary : null,
      ),
    );
  }

  // ── Availability breakdown + stacked bar ──
  Widget _availability(BuildContext context, Map<String, dynamic> p) {
    final t = Theme.of(context).textTheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    int n(String k) => int.tryParse('${p[k] ?? 0}') ?? 0;
    final total = n('total');
    final available = n('available');
    final reserved = n('reserved');
    final blocked = n('blocked');
    final sold = n('sold');
    final unreleased = n('unreleased');
    final segs = <(int, Color, String)>[
      (available, AppColors.success, 'Available'),
      (reserved, AppColors.warning, 'Reserved'),
      (blocked, AppColors.danger, 'Blocked'),
      (sold, AppColors.primary, 'Sold'),
      (unreleased, AppColors.textSubtle, 'Unreleased'),
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.x16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text('Availability', style: t.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            const Spacer(),
            Text('$total units', style: t.bodyMedium?.copyWith(color: dark ? AppColors.dTextMuted : AppColors.textMuted)),
          ]),
          const SizedBox(height: AppSpacing.x12),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppSpacing.rFull),
            child: SizedBox(
              height: 12,
              child: total == 0
                  ? Container(color: AppColors.surface2)
                  : Row(
                      children: [
                        for (final s in segs)
                          if (s.$1 > 0) Expanded(flex: s.$1, child: Container(color: s.$2)),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: AppSpacing.x12),
          Wrap(spacing: AppSpacing.x16, runSpacing: AppSpacing.x8, children: [
            for (final s in segs) _legend(s.$2, s.$3, s.$1),
          ]),
        ]),
      ),
    );
  }

  Widget _legend(Color c, String label, int count) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 6),
        Text('$label  $count', style: const TextStyle(fontSize: 13)),
      ]);

  // ── Primary actions ──
  Widget _actions(BuildContext context, WidgetRef ref, Map<String, dynamic> p) {
    final unreleased = int.tryParse('${p['unreleased'] ?? 0}') ?? 0;
    return Row(children: [
      Expanded(
        child: OutlinedButton.icon(
          onPressed: () => _addUnits(context, ref, '${p['id']}'),
          icon: const Icon(Icons.add_home_work_outlined, size: 18),
          label: const Text('Add units'),
        ),
      ),
      const SizedBox(width: AppSpacing.x8),
      Expanded(
        child: FilledButton.icon(
          onPressed: unreleased > 0 ? () => _release(context, ref, '${p['id']}', unreleased) : null,
          icon: const Icon(Icons.rocket_launch_outlined, size: 18),
          label: Text(unreleased > 0 ? 'Release ($unreleased)' : 'All released'),
        ),
      ),
    ]);
  }

  // ── Unit row ──
  Widget _unitTile(BuildContext context, WidgetRef ref, Map<String, dynamic> u) {
    final status = u['inventory_status'] as String?;
    final released = u['released_at'] != null;
    final agent = '${u['agent_name'] ?? ''}'.trim();
    final beds = u['bedrooms'];
    final type = '${u['property_type'] ?? ''}';
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.x8),
      child: ListTile(
        leading: const Icon(Icons.meeting_room_outlined),
        title: Text('${u['unit_no'] ?? 'Unit'}'),
        subtitle: Text([
          if (type.isNotEmpty) _humanize(type),
          if (beds != null) '$beds BR',
          agent.isNotEmpty ? 'Agent: $agent' : (released ? 'Unassigned' : 'Held'),
        ].join('  ·  ')),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          StatusBadge(released ? _humanize(status ?? 'available') : 'Held',
              tone: released ? _unitTone(status) : BadgeTone.neutral),
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'assign') _assignAgent(context, ref, '${u['id']}');
              if (v == 'unassign') _doAssign(context, ref, '${u['id']}', null);
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'assign', child: Text('Assign agent')),
              if (agent.isNotEmpty) const PopupMenuItem(value: 'unassign', child: Text('Clear agent')),
            ],
          ),
        ]),
      ),
    );
  }

  // ── Mutations ──
  Future<void> _uploadPlan(BuildContext context, WidgetRef ref, String id, String field) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png', 'webp'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final f = result.files.first;
    final bytes = f.bytes;
    if (bytes == null) return;
    final ext = (f.extension ?? '').toLowerCase();
    final ct = ext == 'pdf' ? 'application/pdf' : (ext == 'png' ? 'image/png' : 'image/jpeg');
    try {
      final url = await ref.read(uploadServiceProvider).upload(bytes, f.name, ct);
      if (url == null) return;
      await ref.read(apiClientProvider).patch('/projects/$id', body: {field: url});
      ref.invalidate(projectDetailProvider(id));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Plan uploaded')));
      }
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload failed: $e')));
    }
  }

  Future<void> _addUnits(BuildContext context, WidgetRef ref, String id) async {
    final count = TextEditingController(text: '10');
    final prefix = TextEditingController(text: 'Unit');
    final beds = TextEditingController(text: '1');
    var type = 'apartment';
    final ok = await AppDialog.show<bool>(
      context,
      title: 'Add units',
      children: [
        StatefulBuilder(
          builder: (ctx, setS) => Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: count, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'How many units')),
            const SizedBox(height: AppSpacing.x8),
            TextField(controller: prefix, decoration: const InputDecoration(labelText: 'Unit label prefix')),
            const SizedBox(height: AppSpacing.x8),
            TextField(controller: beds, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Bedrooms')),
            const SizedBox(height: AppSpacing.x8),
            DropdownButtonFormField<String>(
              initialValue: type,
              decoration: const InputDecoration(labelText: 'Type'),
              items: const [
                DropdownMenuItem(value: 'apartment', child: Text('Apartment')),
                DropdownMenuItem(value: 'villa', child: Text('Villa')),
                DropdownMenuItem(value: 'townhouse', child: Text('Townhouse')),
                DropdownMenuItem(value: 'office', child: Text('Office')),
              ],
              onChanged: (v) => setS(() => type = v ?? 'apartment'),
            ),
          ]),
        ),
      ],
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Add')),
      ],
    );
    if (ok != true) return;
    try {
      await ref.read(apiClientProvider).post('/projects/$id/units', body: {
        'count': int.tryParse(count.text.trim()) ?? 1,
        'prefix': prefix.text.trim().isEmpty ? 'Unit' : prefix.text.trim(),
        'bedrooms': int.tryParse(beds.text.trim()),
        'property_type': type,
      });
      ref.invalidate(projectDetailProvider(id));
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Units added')));
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
    }
  }

  Future<void> _release(BuildContext context, WidgetRef ref, String id, int unreleased) async {
    final count = TextEditingController(text: '$unreleased');
    final ok = await AppDialog.show<bool>(
      context,
      title: 'Release units to market',
      children: [
        Text('Releasing flips held units to Available so they appear in the market and can be assigned to agents. '
            '$unreleased unit(s) are currently held.'),
        const SizedBox(height: AppSpacing.x8),
        TextField(controller: count, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'How many to release')),
      ],
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Release')),
      ],
    );
    if (ok != true) return;
    try {
      final res = await ref.read(apiClientProvider).post('/projects/$id/release', body: {
        'count': int.tryParse(count.text.trim()) ?? unreleased,
      });
      ref.invalidate(projectDetailProvider(id));
      final n = (res is Map) ? res['released'] ?? 0 : 0;
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Released $n unit(s) to market')));
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
    }
  }

  Future<void> _assignAgent(BuildContext context, WidgetRef ref, String unitId) async {
    final agents = await ref.read(assignableAgentsProvider.future);
    if (!context.mounted) return;
    if (agents.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No agents available to assign')));
      return;
    }
    final chosen = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: ListView(shrinkWrap: true, children: [
          const Padding(
            padding: EdgeInsets.all(AppSpacing.x16),
            child: Text('Assign agent', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          ),
          for (final a in agents)
            ListTile(
              leading: const Icon(Icons.person_outline),
              title: Text('${a['full_name'] ?? a['email'] ?? 'Agent'}'),
              subtitle: '${a['email'] ?? ''}'.isNotEmpty ? Text('${a['email']}') : null,
              onTap: () => Navigator.pop(ctx, '${a['id']}'),
            ),
        ]),
      ),
    );
    if (chosen == null || !context.mounted) return;
    await _doAssign(context, ref, unitId, chosen);
  }

  Future<void> _doAssign(BuildContext context, WidgetRef ref, String unitId, String? agentId) async {
    try {
      await ref.read(apiClientProvider).post('/inventory/units/$unitId/assign', body: {'agent_id': agentId});
      ref.invalidate(projectDetailProvider(projectId));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(agentId == null ? 'Agent cleared' : 'Unit assigned to agent')));
      }
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
    }
  }

  Future<void> _editProject(BuildContext context, WidgetRef ref, Map<String, dynamic> p) async {
    final id = '${p['id']}';
    final loc = TextEditingController(text: '${p['location'] ?? ''}');
    final desc = TextEditingController(text: '${p['description'] ?? ''}');
    final price = TextEditingController(text: p['price_from'] != null ? '${p['price_from']}' : '');
    var status = '${p['status'] ?? 'planning'}';
    final ok = await AppDialog.show<bool>(
      context,
      title: 'Edit project',
      children: [
        StatefulBuilder(
          builder: (ctx, setS) => Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: loc, decoration: const InputDecoration(labelText: 'Location')),
            const SizedBox(height: AppSpacing.x8),
            TextField(controller: price, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Price from (AED)')),
            const SizedBox(height: AppSpacing.x8),
            DropdownButtonFormField<String>(
              initialValue: status,
              decoration: const InputDecoration(labelText: 'Status'),
              items: const [
                DropdownMenuItem(value: 'planning', child: Text('Planning')),
                DropdownMenuItem(value: 'under_construction', child: Text('Under construction')),
                DropdownMenuItem(value: 'ready', child: Text('Ready')),
                DropdownMenuItem(value: 'handover', child: Text('Handover')),
              ],
              onChanged: (v) => setS(() => status = v ?? 'planning'),
            ),
            const SizedBox(height: AppSpacing.x8),
            TextField(controller: desc, maxLines: 3, decoration: const InputDecoration(labelText: 'Description')),
          ]),
        ),
      ],
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save')),
      ],
    );
    if (ok != true) return;
    try {
      await ref.read(apiClientProvider).patch('/projects/$id', body: {
        'location': loc.text.trim(),
        'description': desc.text.trim(),
        'price_from': num.tryParse(price.text.trim()),
        'status': status,
      });
      ref.invalidate(projectDetailProvider(id));
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Project updated')));
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
    }
  }
}

BadgeTone _projectTone(String s) => switch (s) {
      'ready' => BadgeTone.success,
      'under_construction' => BadgeTone.warning,
      'planning' => BadgeTone.gold,
      _ => BadgeTone.neutral,
    };

String _humanize(String k) => k
    .replaceAll('_', ' ')
    .split(' ')
    .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
    .join(' ');
