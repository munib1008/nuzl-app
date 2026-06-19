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
import '../auth/application/auth_controller.dart';
import '../shell/app_shell.dart';

/// GET /projects/:id → { project, units }
final projectDetailProvider =
    FutureProvider.autoDispose.family<Map<String, dynamic>, String>((ref, id) async {
  final d = await ref.read(apiClientProvider).get('/projects/$id');
  return d is Map ? Map<String, dynamic>.from(d) : <String, dynamic>{};
});

/// GET /projects/:id/progress → construction-progress milestones.
final projectProgressProvider =
    FutureProvider.autoDispose.family<List<dynamic>, String>((ref, id) async {
  try {
    final d = await ref.read(apiClientProvider).get('/projects/$id/progress');
    return d is List ? d : [];
  } catch (_) {
    return [];
  }
});

/// GET /projects/:id/inquiries → customer leads on a project (developer-scoped).
final projectInquiriesProvider =
    FutureProvider.autoDispose.family<List<dynamic>, String>((ref, id) async {
  try {
    final d = await ref.read(apiClientProvider).get('/projects/$id/inquiries');
    return d is List ? d : [];
  } catch (_) {
    return [];
  }
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
            final myOrg = ref.watch(authControllerProvider).user?.organizationId;
            final isOwnerDev = myOrg != null && '${p['developer_org']}' == myOrg;
            return ListView(
              padding: const EdgeInsets.all(AppSpacing.x16),
              children: [
                if ('${p['hero_image'] ?? ''}'.trim().isNotEmpty) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppSpacing.rCard),
                    child: AspectRatio(
                      aspectRatio: 21 / 9,
                      child: Image.network('${p['hero_image']}', fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(color: AppColors.surface2)),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.x12),
                ],
                _header(context, ref, p),
                const SizedBox(height: AppSpacing.x16),
                _availability(context, p),
                const SizedBox(height: AppSpacing.x16),
                _gallery(context, ref, p, isOwnerDev),
                _ConstructionProgress(projectId: projectId),
                const SizedBox(height: AppSpacing.x16),
                if (isOwnerDev)
                  _InquiriesInbox(projectId: projectId)
                else
                  _InquiryActions(projectId: projectId, projectName: '${p['name'] ?? 'this project'}'),
                const SizedBox(height: AppSpacing.x16),
                if (isOwnerDev) ...[
                  _actions(context, ref, p),
                  const SizedBox(height: AppSpacing.x8),
                  Row(children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _assignProjectAgent(context, ref, '${p['id']}'),
                        icon: const Icon(Icons.person_pin_outlined, size: 18),
                        label: const Text('Assign agent'),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.x8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _requestQuote(context, ref, p),
                        icon: const Icon(Icons.request_quote_outlined, size: 18),
                        label: const Text('Request quote'),
                      ),
                    ),
                  ]),
                  const SizedBox(height: AppSpacing.x16),
                ],
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
            _planChip(context, ref, p, label: 'Hero image', field: 'hero_image'),
            _planChip(context, ref, p, label: 'Masterplan', field: 'masterplan_url'),
            _planChip(context, ref, p, label: 'Brochure', field: 'brochure_url'),
            if ('${p['video_url'] ?? ''}'.trim().isNotEmpty)
              OutlinedButton.icon(
                onPressed: () => launchUrl(Uri.parse('${p['video_url']}'), webOnlyWindowName: '_blank'),
                icon: const Icon(Icons.play_circle_outline, size: 16),
                label: const Text('Video'),
              ),
            if ('${p['tour_url'] ?? ''}'.trim().isNotEmpty)
              OutlinedButton.icon(
                onPressed: () => launchUrl(Uri.parse('${p['tour_url']}'), webOnlyWindowName: '_blank'),
                icon: const Icon(Icons.threed_rotation, size: 16),
                label: const Text('360° tour'),
              ),
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
      (available, AppColors.statusAvailable, 'Available'),
      (reserved, AppColors.statusReserved, 'Reserved'),
      (blocked, AppColors.danger, 'Blocked'),
      (sold, AppColors.statusSold, 'Sold'),
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

  /// Project photo gallery — view for everyone, add/remove for the owner.
  Widget _gallery(BuildContext context, WidgetRef ref, Map<String, dynamic> p, bool isOwner) {
    final t = Theme.of(context).textTheme;
    final list = (p['gallery'] is List)
        ? (p['gallery'] as List).map((e) => '$e').where((s) => s.trim().isNotEmpty).toList()
        : <String>[];
    if (list.isEmpty && !isOwner) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.x16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.x16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text('Gallery', style: t.titleMedium?.copyWith(fontWeight: FontWeight.w700))),
              if (isOwner)
                TextButton.icon(
                  onPressed: () => _addGalleryPhoto(context, ref, '${p['id']}', list),
                  icon: const Icon(Icons.add_photo_alternate_outlined, size: 16),
                  label: const Text('Add'),
                  style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                ),
            ]),
            const SizedBox(height: AppSpacing.x8),
            if (list.isEmpty)
              Text('No photos yet. Add gallery images buyers can browse.',
                  style: t.bodySmall?.copyWith(color: Theme.of(context).hintColor))
            else
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final url in list)
                  Stack(children: [
                    GestureDetector(
                      onTap: () => launchUrl(Uri.parse(url), webOnlyWindowName: '_blank'),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(AppSpacing.rMd),
                        child: Image.network(url, width: 88, height: 88, fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(width: 88, height: 88, color: AppColors.surface2)),
                      ),
                    ),
                    if (isOwner)
                      Positioned(
                        top: -6, right: -6,
                        child: IconButton(
                          icon: const Icon(Icons.cancel, size: 18),
                          color: AppColors.danger,
                          onPressed: () => _removeGalleryPhoto(context, ref, '${p['id']}', list, url),
                        ),
                      ),
                  ]),
              ]),
          ]),
        ),
      ),
    );
  }

  Future<void> _addGalleryPhoto(BuildContext context, WidgetRef ref, String id, List<String> current) async {
    final res = await FilePicker.platform.pickFiles(type: FileType.image, withData: true);
    final f = res?.files.firstOrNull;
    if (f?.bytes == null) return;
    final ext = (f!.extension ?? 'jpg').toLowerCase();
    final ct = ext == 'png' ? 'image/png' : 'image/jpeg';
    try {
      final url = await ref.read(uploadServiceProvider).upload(f.bytes!, f.name, ct);
      if (url == null) return;
      await ref.read(apiClientProvider).patch('/projects/$id', body: {'gallery': [...current, url]});
      ref.invalidate(projectDetailProvider(id));
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
    }
  }

  Future<void> _removeGalleryPhoto(BuildContext context, WidgetRef ref, String id, List<String> current, String url) async {
    try {
      await ref.read(apiClientProvider).patch('/projects/$id', body: {'gallery': current.where((u) => u != url).toList()});
      ref.invalidate(projectDetailProvider(id));
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
    }
  }

  /// Assign one sales agent across the whole project (all units inherit).
  Future<void> _assignProjectAgent(BuildContext context, WidgetRef ref, String id) async {
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
          const Padding(padding: EdgeInsets.all(AppSpacing.x16),
              child: Text('Assign the project to an agent', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16))),
          for (final a in agents)
            ListTile(
              leading: const Icon(Icons.person_outline),
              title: Text('${a['full_name'] ?? a['email'] ?? 'Agent'}'),
              subtitle: '${a['email'] ?? ''}'.isNotEmpty ? Text('${a['email']}') : null,
              onTap: () => Navigator.pop(ctx, '${a['id']}'),
            ),
          ListTile(
            leading: const Icon(Icons.clear),
            title: const Text('Clear assignment'),
            onTap: () => Navigator.pop(ctx, ''),
          ),
        ]),
      ),
    );
    if (chosen == null || !context.mounted) return;
    try {
      final res = await ref.read(apiClientProvider).post('/projects/$id/assign-agent', body: {'agent_id': chosen.isEmpty ? null : chosen});
      ref.invalidate(projectDetailProvider(id));
      final n = (res is Map) ? res['units'] ?? 0 : 0;
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(chosen.isEmpty ? 'Cleared agent on $n units' : 'Assigned $n units to the agent')));
      }
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
    }
  }

  /// Post a service tender for the whole project (fit-out / MEP / landscaping…).
  Future<void> _requestQuote(BuildContext context, WidgetRef ref, Map<String, dynamic> p) async {
    final scope = TextEditingController();
    final budget = TextEditingController();
    final desc = TextEditingController();
    var category = 'fit_out';
    final ok = await AppDialog.show<bool>(
      context,
      title: 'Request a project quote',
      children: [
        Text('Post a request for the whole project — service providers bid in the marketplace.',
            style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: AppSpacing.x12),
        StatefulBuilder(
          builder: (ctx, setS) => Column(mainAxisSize: MainAxisSize.min, children: [
            DropdownButtonFormField<String>(
              initialValue: category,
              decoration: const InputDecoration(labelText: 'Scope'),
              items: const [
                DropdownMenuItem(value: 'fit_out', child: Text('Fit-out')),
                DropdownMenuItem(value: 'mep', child: Text('MEP')),
                DropdownMenuItem(value: 'landscaping', child: Text('Landscaping')),
                DropdownMenuItem(value: 'facade', child: Text('Façade')),
                DropdownMenuItem(value: 'interior', child: Text('Interior design')),
                DropdownMenuItem(value: 'other', child: Text('Other')),
              ],
              onChanged: (v) => setS(() => category = v ?? 'fit_out'),
            ),
            const SizedBox(height: AppSpacing.x8),
            TextField(controller: scope, decoration: const InputDecoration(labelText: 'Title', hintText: 'e.g. Full fit-out — 120 units')),
            const SizedBox(height: AppSpacing.x8),
            TextField(controller: budget, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Budget (AED) — optional')),
            const SizedBox(height: AppSpacing.x8),
            TextField(controller: desc, maxLines: 3, decoration: const InputDecoration(labelText: 'Details')),
          ]),
        ),
      ],
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Post request')),
      ],
    );
    if (ok != true) return;
    final title = scope.text.trim().isEmpty ? '${p['name'] ?? 'Project'} — ${_humanize(category)}' : scope.text.trim();
    try {
      await ref.read(apiClientProvider).post('/tenders', body: {
        'kind': 'service',
        'category': category,
        'title': 'Project quote: $title',
        'description': desc.text.trim().isEmpty ? 'Quote for ${p['name'] ?? 'the project'}.' : desc.text.trim(),
        'location': '${p['community'] ?? p['city'] ?? ''}',
        if (budget.text.trim().isNotEmpty) 'budget': num.tryParse(budget.text.trim()),
      });
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Quote request posted to the marketplace')));
      }
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
    }
  }

  Future<void> _editProject(BuildContext context, WidgetRef ref, Map<String, dynamic> p) async {
    final id = '${p['id']}';
    final loc = TextEditingController(text: '${p['location'] ?? ''}');
    final city = TextEditingController(text: '${p['city'] ?? ''}');
    final desc = TextEditingController(text: '${p['description'] ?? ''}');
    final price = TextEditingController(text: p['price_from'] != null ? '${p['price_from']}' : '');
    final video = TextEditingController(text: '${p['video_url'] ?? ''}');
    final tour = TextEditingController(text: '${p['tour_url'] ?? ''}');
    var status = '${p['status'] ?? 'planning'}';
    final ok = await AppDialog.show<bool>(
      context,
      title: 'Edit project',
      children: [
        StatefulBuilder(
          builder: (ctx, setS) => Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: loc, decoration: const InputDecoration(labelText: 'Location / area')),
            const SizedBox(height: AppSpacing.x8),
            TextField(controller: city, decoration: const InputDecoration(labelText: 'City (e.g. Dubai)')),
            const SizedBox(height: AppSpacing.x8),
            TextField(controller: price, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Price from (AED)')),
            const SizedBox(height: AppSpacing.x8),
            DropdownButtonFormField<String>(
              initialValue: status,
              decoration: const InputDecoration(labelText: 'Status'),
              items: const [
                DropdownMenuItem(value: 'planning', child: Text('Planning')),
                DropdownMenuItem(value: 'launching', child: Text('Launching')),
                DropdownMenuItem(value: 'under_construction', child: Text('Under construction')),
                DropdownMenuItem(value: 'ready', child: Text('Ready')),
                DropdownMenuItem(value: 'completed', child: Text('Completed')),
                DropdownMenuItem(value: 'sold_out', child: Text('Sold out')),
                DropdownMenuItem(value: 'handover', child: Text('Handover')),
              ],
              onChanged: (v) => setS(() => status = v ?? 'planning'),
            ),
            const SizedBox(height: AppSpacing.x8),
            TextField(controller: video, decoration: const InputDecoration(labelText: 'Video URL (optional)')),
            const SizedBox(height: AppSpacing.x8),
            TextField(controller: tour, decoration: const InputDecoration(labelText: '360° tour URL (optional)')),
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
        'city': city.text.trim(),
        'description': desc.text.trim(),
        'price_from': num.tryParse(price.text.trim()),
        'video_url': video.text.trim(),
        'tour_url': tour.text.trim(),
        'status': status,
      });
      ref.invalidate(projectDetailProvider(id));
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Project updated')));
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
    }
  }
}

const _inquiryKinds = [
  ('brochure', 'Request brochure', Icons.description_outlined),
  ('viewing', 'Book viewing', Icons.event_available_outlined),
  ('callback', 'Request callback', Icons.call_outlined),
  ('offer', 'Make an offer', Icons.local_offer_outlined),
];

Color _leadStatusColor(String s) => switch (s) {
      'new' => AppColors.info,
      'contacted' => AppColors.warning,
      'qualified' => AppColors.secondary,
      'won' => AppColors.success,
      'lost' => AppColors.danger,
      _ => AppColors.textMuted,
    };

/// Customer-facing inquiry actions on a project (spec §15). Lands as a developer lead.
class _InquiryActions extends ConsumerWidget {
  const _InquiryActions({required this.projectId, required this.projectName});
  final String projectId;
  final String projectName;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.x16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Interested in $projectName?', style: t.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text('Send a request and the developer will reach out.',
              style: t.bodySmall?.copyWith(color: Theme.of(context).hintColor)),
          const SizedBox(height: AppSpacing.x12),
          Wrap(spacing: AppSpacing.x8, runSpacing: AppSpacing.x8, children: [
            for (final k in _inquiryKinds)
              OutlinedButton.icon(
                onPressed: () => _submitInquiry(context, ref, k.$1),
                icon: Icon(k.$3, size: 16),
                label: Text(k.$2),
              ),
          ]),
        ]),
      ),
    );
  }

  Future<void> _submitInquiry(BuildContext context, WidgetRef ref, String kind) async {
    final me = ref.read(authControllerProvider).user;
    final name = TextEditingController(text: me?.fullName ?? '');
    final phone = TextEditingController();
    final message = TextEditingController();
    final offer = TextEditingController();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(20, 4, 20, 20 + MediaQuery.of(ctx).viewInsets.bottom),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_inquiryKinds.firstWhere((k) => k.$1 == kind).$2,
              style: Theme.of(ctx).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: AppSpacing.x12),
          TextField(controller: name, decoration: const InputDecoration(labelText: 'Your name', isDense: true)),
          const SizedBox(height: AppSpacing.x8),
          TextField(controller: phone, decoration: const InputDecoration(labelText: 'Phone', isDense: true)),
          if (kind == 'offer') ...[
            const SizedBox(height: AppSpacing.x8),
            TextField(controller: offer, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Offer amount (AED)', isDense: true)),
          ],
          const SizedBox(height: AppSpacing.x8),
          TextField(controller: message, maxLines: 2, decoration: const InputDecoration(labelText: 'Message (optional)', isDense: true)),
          const SizedBox(height: AppSpacing.x12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () async {
                try {
                  await ref.read(apiClientProvider).post('/projects/$projectId/inquiries', body: {
                    'kind': kind,
                    'name': name.text.trim(),
                    'phone': phone.text.trim(),
                    'message': message.text.trim(),
                    if (kind == 'offer') 'offer_amount': offer.text.trim(),
                  });
                  if (ctx.mounted) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Request sent — the developer will be in touch.')));
                  }
                } catch (e) {
                  if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(friendlyError(e))));
                }
              },
              child: const Text('Send request'),
            ),
          ),
        ]),
      ),
    );
  }
}

/// Developer-facing leads inbox + pipeline status (spec §9/§15).
class _InquiriesInbox extends ConsumerWidget {
  const _InquiriesInbox({required this.projectId});
  final String projectId;
  static const _statuses = ['new', 'contacted', 'qualified', 'won', 'lost'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final muted = Theme.of(context).hintColor;
    final inq = ref.watch(projectInquiriesProvider(projectId));
    final aed = NumberFormat.currency(symbol: 'AED ', decimalDigits: 0);
    final df = DateFormat('d MMM');
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.x16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          inq.maybeWhen(
            data: (list) => Text('Leads (${list.length})', style: t.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            orElse: () => Text('Leads', style: t.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          ),
          const SizedBox(height: AppSpacing.x8),
          inq.when(
            loading: () => const Padding(padding: EdgeInsets.all(8), child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))),
            error: (e, _) => Text(friendlyError(e), style: t.bodySmall),
            data: (list) {
              if (list.isEmpty) {
                return Text('No inquiries yet. Customer brochure/viewing/callback/offer requests land here.',
                    style: t.bodySmall?.copyWith(color: muted));
              }
              return Column(children: [
                for (final e in list)
                  Builder(builder: (_) {
                    final m = Map<String, dynamic>.from(e);
                    final kind = '${m['kind'] ?? 'callback'}';
                    final status = '${m['status'] ?? 'new'}';
                    final when = DateTime.tryParse('${m['created_at']}');
                    final offer = num.tryParse('${m['offer_amount'] ?? ''}');
                    final who = '${m['name'] ?? m['user_name'] ?? 'Customer'}';
                    final contact = [m['phone'], m['user_email'] ?? m['email']].where((x) => '$x'.trim().isNotEmpty).join(' · ');
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Icon(_inquiryKinds.firstWhere((k) => k.$1 == kind, orElse: () => _inquiryKinds[2]).$3, size: 18, color: muted),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('$who · ${_humanize(kind)}${offer != null ? ' · ${aed.format(offer)}' : ''}',
                                style: t.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                            if (contact.isNotEmpty) Text(contact, style: t.bodySmall?.copyWith(color: muted)),
                            if ('${m['message'] ?? ''}'.isNotEmpty) Text('${m['message']}', style: t.bodySmall),
                          ]),
                        ),
                        const SizedBox(width: 8),
                        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                          if (when != null) Text(df.format(when), style: t.labelSmall?.copyWith(color: muted)),
                          PopupMenuButton<String>(
                            onSelected: (s) => _setStatus(context, ref, '${m['id']}', s),
                            itemBuilder: (_) => [for (final s in _statuses) PopupMenuItem(value: s, child: Text(_humanize(s)))],
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(color: _leadStatusColor(status).withValues(alpha: 0.14), borderRadius: BorderRadius.circular(AppSpacing.rFull)),
                              child: Row(mainAxisSize: MainAxisSize.min, children: [
                                Text(_humanize(status), style: t.labelSmall?.copyWith(color: _leadStatusColor(status), fontWeight: FontWeight.w700)),
                                Icon(Icons.arrow_drop_down, size: 16, color: _leadStatusColor(status)),
                              ]),
                            ),
                          ),
                        ]),
                      ]),
                    );
                  }),
              ]);
            },
          ),
        ]),
      ),
    );
  }

  Future<void> _setStatus(BuildContext context, WidgetRef ref, String id, String status) async {
    try {
      await ref.read(apiClientProvider).patch('/inquiries/$id/status', body: {'status': status});
      ref.invalidate(projectInquiriesProvider(projectId));
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
    }
  }
}

const _progressPhases = ['foundation', 'structure', 'mep', 'finishing', 'landscaping', 'handover'];

/// Construction progress (spec §14): latest % per phase + a dated timeline with
/// optional site photos. Developers log milestones; everyone with read sees them.
class _ConstructionProgress extends ConsumerWidget {
  const _ConstructionProgress({required this.projectId});
  final String projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final muted = dark ? AppColors.dTextMuted : AppColors.textMuted;
    final prog = ref.watch(projectProgressProvider(projectId));
    final df = DateFormat('d MMM yyyy');
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.x16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text('Construction progress', style: t.titleMedium?.copyWith(fontWeight: FontWeight.w700))),
            TextButton.icon(
              onPressed: () => _logProgress(context, ref),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Log'),
              style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
            ),
          ]),
          const SizedBox(height: AppSpacing.x8),
          prog.when(
            loading: () => const Padding(padding: EdgeInsets.all(8), child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))),
            error: (e, _) => Text(friendlyError(e), style: t.bodySmall),
            data: (list) {
              // Latest pct per phase (entries are newest-first).
              final latest = <String, int>{};
              for (final e in list) {
                final m = Map<String, dynamic>.from(e);
                final ph = '${m['phase']}';
                if (!latest.containsKey(ph)) latest[ph] = int.tryParse('${m['pct'] ?? 0}') ?? 0;
              }
              final overall = _progressPhases.map((p) => latest[p] ?? 0).fold<int>(0, (a, b) => a + b) ~/ _progressPhases.length;
              return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Text('Overall', style: t.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
                  const Spacer(),
                  Text('$overall%', style: t.bodyMedium?.copyWith(fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.primary)),
                ]),
                const SizedBox(height: 8),
                for (final ph in _progressPhases) ...[
                  Row(children: [
                    SizedBox(width: 96, child: Text(_humanize(ph), style: t.bodySmall)),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(AppSpacing.rFull),
                        child: LinearProgressIndicator(
                          value: (latest[ph] ?? 0) / 100,
                          minHeight: 8,
                          backgroundColor: AppColors.surface2,
                          valueColor: AlwaysStoppedAnimation(Theme.of(context).colorScheme.primary),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(width: 36, child: Text('${latest[ph] ?? 0}%', textAlign: TextAlign.right, style: t.bodySmall)),
                  ]),
                  const SizedBox(height: 6),
                ],
                if (list.isNotEmpty) ...[
                  const Divider(height: AppSpacing.x24),
                  Text('Updates', style: t.labelLarge),
                  const SizedBox(height: 6),
                  for (final e in list.take(8))
                    Builder(builder: (_) {
                      final m = Map<String, dynamic>.from(e);
                      final when = DateTime.tryParse('${m['recorded_at']}');
                      final img = '${m['image_url'] ?? ''}'.trim();
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          if (img.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(AppSpacing.rSm),
                                child: Image.network(img, width: 44, height: 44, fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => const SizedBox(width: 44, height: 44)),
                              ),
                            ),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text('${_humanize('${m['phase']}')} · ${m['pct']}%', style: t.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
                              if ('${m['note'] ?? ''}'.isNotEmpty) Text('${m['note']}', style: t.bodySmall?.copyWith(color: muted)),
                            ]),
                          ),
                          if (when != null) Text(df.format(when), style: t.labelSmall?.copyWith(color: muted)),
                        ]),
                      );
                    }),
                ],
              ]);
            },
          ),
        ]),
      ),
    );
  }

  Future<void> _logProgress(BuildContext context, WidgetRef ref) async {
    var phase = 'structure';
    final pct = TextEditingController();
    final note = TextEditingController();
    String? imageUrl;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: EdgeInsets.fromLTRB(20, 4, 20, 20 + MediaQuery.of(ctx).viewInsets.bottom),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Log construction progress', style: Theme.of(ctx).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: AppSpacing.x12),
            DropdownButtonFormField<String>(
              initialValue: phase,
              decoration: const InputDecoration(labelText: 'Phase', isDense: true),
              items: [for (final p in _progressPhases) DropdownMenuItem(value: p, child: Text(_humanize(p)))],
              onChanged: (v) => setS(() => phase = v ?? 'structure'),
            ),
            const SizedBox(height: AppSpacing.x8),
            TextField(controller: pct, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Completion %', isDense: true)),
            const SizedBox(height: AppSpacing.x8),
            TextField(controller: note, maxLines: 2, decoration: const InputDecoration(labelText: 'Note (optional)', isDense: true)),
            const SizedBox(height: AppSpacing.x8),
            Row(children: [
              OutlinedButton.icon(
                onPressed: () async {
                  final res = await FilePicker.platform.pickFiles(type: FileType.image, withData: true);
                  final f = res?.files.firstOrNull;
                  if (f?.bytes == null) return;
                  final ext = (f!.extension ?? 'jpg').toLowerCase();
                  final ct = ext == 'png' ? 'image/png' : 'image/jpeg';
                  final url = await ref.read(uploadServiceProvider).upload(f.bytes!, f.name, ct);
                  if (url != null) setS(() => imageUrl = url);
                },
                icon: const Icon(Icons.photo_camera_outlined, size: 16),
                label: Text(imageUrl == null ? 'Add photo' : 'Photo added'),
              ),
              if (imageUrl != null) ...[
                const SizedBox(width: 8),
                const Icon(Icons.check_circle, size: 18, color: AppColors.success),
              ],
            ]),
            const SizedBox(height: AppSpacing.x12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () async {
                  try {
                    await ref.read(apiClientProvider).post('/projects/$projectId/progress', body: {
                      'phase': phase,
                      'pct': int.tryParse(pct.text.trim()) ?? 0,
                      'note': note.text.trim(),
                      'image_url': imageUrl,
                    });
                    ref.invalidate(projectProgressProvider(projectId));
                    if (ctx.mounted) {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Progress logged')));
                    }
                  } catch (e) {
                    if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(friendlyError(e))));
                  }
                },
                child: const Text('Save'),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

BadgeTone _projectTone(String s) => switch (s) {
      'ready' || 'completed' => BadgeTone.success,
      'under_construction' || 'launching' => BadgeTone.warning,
      'planning' => BadgeTone.gold,
      'sold_out' => BadgeTone.neutral,
      _ => BadgeTone.neutral,
    };

String _humanize(String k) => k
    .replaceAll('_', ' ')
    .split(' ')
    .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
    .join(' ');
