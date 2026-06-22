import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/app_dialog.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/responsive.dart';
import '../auth/application/auth_controller.dart';
import '../shell/app_shell.dart';

/// Full unit status lifecycle (developer phase 1). 'rented' is kept for
/// long-let inventory alongside the sales states.
const _unitStatuses = [
  'available', 'reserved', 'booked', 'sold', 'rented', 'blocked', 'cancelled', 'transferred',
];

final inventoryProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  try {
    final d = await ref.read(apiClientProvider).get('/inventory');
    return d is List ? d : [];
  } catch (_) {
    return [];
  }
});

final blockRequestsProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  try {
    final d = await ref.read(apiClientProvider).get('/inventory/block-requests');
    return d is List ? d : [];
  } catch (_) {
    return [];
  }
});

final _unitHistoryProvider = FutureProvider.autoDispose.family<List<dynamic>, String>((ref, id) async {
  try {
    final d = await ref.read(apiClientProvider).get('/inventory/$id/history');
    return d is List ? d : [];
  } catch (_) {
    return [];
  }
});

/// Status → board colour. Null = unreleased (held inventory, not yet on market).
Color _statusColor(String? s) => switch (s) {
      'available' => AppColors.statusAvailable,
      'reserved' => AppColors.statusReserved,
      'booked' => AppColors.statusNewLaunch,
      'sold' => AppColors.statusSold,
      'rented' => AppColors.statusReady,
      'blocked' => AppColors.danger,
      'cancelled' => AppColors.textMuted,
      'transferred' => AppColors.statusOffPlan,
      _ => AppColors.textSubtle, // unreleased
    };

String _statusLabel(String? s) => (s == null || s.isEmpty) ? 'Unreleased' : _humanize(s);

class InventoryScreen extends ConsumerWidget {
  const InventoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inventory = ref.watch(inventoryProvider);
    return Scaffold(
      appBar: NuzlAppBar(title: context.tr('Inventory')),
      drawer: const NuzlDrawer(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _createProject(context, ref),
        icon: const Icon(Icons.add),
        label: Text(context.tr('New project')),
      ),
      body: ResponsiveCenter(
        child: Column(children: [
          const _BlockRequestsPanel(),
          Expanded(
            child: inventory.when(
              loading: () => const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator())),
              error: (e, _) => Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(friendlyError(e)))),
              data: (list) {
                if (list.isEmpty) {
                  return Center(
                    child: EmptyState(
                      icon: Icons.meeting_room_outlined,
                      title: context.tr('No units yet'),
                      message: context.tr('Create a project, then add units to it to build your inventory.'),
                    ),
                  );
                }
                final groups = <String, List<Map<String, dynamic>>>{};
                for (final e in list) {
                  final m = Map<String, dynamic>.from(e);
                  final p = '${m['project'] ?? m['community'] ?? 'Unassigned'}';
                  (groups[p] ??= []).add(m);
                }
                final keys = groups.keys.toList();
                return ListView(
                  padding: const EdgeInsets.all(AppSpacing.x16),
                  children: [
                    const _Legend(),
                    const SizedBox(height: AppSpacing.x12),
                    for (final project in keys) _ProjectBoard(project: project, units: groups[project]!),
                  ],
                );
              },
            ),
          ),
        ]),
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
                DropdownMenuItem(value: 'launching', child: Text(context.tr('Launching'))),
                DropdownMenuItem(value: 'under_construction', child: Text(context.tr('Under construction'))),
                DropdownMenuItem(value: 'ready', child: Text(context.tr('Ready'))),
                DropdownMenuItem(value: 'completed', child: Text(context.tr('Completed'))),
                DropdownMenuItem(value: 'sold_out', child: Text(context.tr('Sold out'))),
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
      ref.invalidate(inventoryProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.tr('Project created'))));
      }
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
    }
  }
}

/// Colour key so the board reads at a glance.
class _Legend extends StatelessWidget {
  const _Legend();
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Wrap(spacing: 12, runSpacing: 6, children: [
      for (final s in ['available', 'reserved', 'booked', 'sold', 'blocked', null])
        Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 10, height: 10, decoration: BoxDecoration(color: _statusColor(s), shape: BoxShape.circle)),
          const SizedBox(width: 4),
          Text(context.tr(_statusLabel(s)), style: t.labelSmall),
        ]),
    ]);
  }
}

/// One project's board: header (name + status counts + Add units) and a
/// colour-coded unit grid grouped by tower.
class _ProjectBoard extends ConsumerWidget {
  const _ProjectBoard({required this.project, required this.units});
  final String project;
  final List<Map<String, dynamic>> units;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    // Status counts for the header summary.
    final counts = <String, int>{};
    for (final u in units) {
      final s = '${u['inventory_status'] ?? 'unreleased'}';
      counts[s] = (counts[s] ?? 0) + 1;
    }
    final available = counts['available'] ?? 0;
    final sold = counts['sold'] ?? 0;
    // Group by tower (NULL → "Units").
    final towers = <String, List<Map<String, dynamic>>>{};
    for (final u in units) {
      final tw = '${u['tower'] ?? ''}'.trim();
      (towers[tw.isEmpty ? context.tr('Units') : '${context.tr('Building')} $tw'] ??= []).add(u);
    }
    final projectId = '${units.first['project_id'] ?? ''}';
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.x12),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.x16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(project, style: t.titleMedium?.copyWith(fontWeight: FontWeight.w700))),
            if (projectId.isNotEmpty)
              TextButton.icon(
                onPressed: () => _addUnits(context, ref, projectId),
                icon: const Icon(Icons.add, size: 16),
                label: Text(context.tr('Add units')),
                style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
              ),
          ]),
          Text('${units.length} ${context.tr('units')} · $available ${context.tr('available')} · $sold ${context.tr('sold')}',
              style: t.bodySmall?.copyWith(color: Theme.of(context).hintColor)),
          const SizedBox(height: AppSpacing.x12),
          for (final tw in towers.keys) ...[
            if (towers.length > 1)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(tw, style: t.labelLarge?.copyWith(fontWeight: FontWeight.w700)),
              ),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [for (final u in towers[tw]!) _UnitChip(u)],
            ),
            const SizedBox(height: AppSpacing.x8),
          ],
        ]),
      ),
    );
  }

  Future<void> _addUnits(BuildContext context, WidgetRef ref, String projectId) =>
      _showAddUnitsSheet(context, ref, projectId);
}

/// A colour-coded unit cell. Tap to open the unit sheet (details + status + history).
class _UnitChip extends StatelessWidget {
  const _UnitChip(this.u);
  final Map<String, dynamic> u;
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final status = u['inventory_status'] as String?;
    final c = _statusColor(status);
    return InkWell(
      borderRadius: BorderRadius.circular(AppSpacing.rSm),
      onTap: () => _showUnitSheet(context, u),
      child: Container(
        width: 64,
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        decoration: BoxDecoration(
          color: c.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppSpacing.rSm),
          border: Border.all(color: c.withValues(alpha: 0.55)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('${u['unit_no'] ?? '—'}',
              style: t.labelMedium?.copyWith(fontWeight: FontWeight.w700, color: c),
              maxLines: 1, overflow: TextOverflow.ellipsis),
          if (u['floor'] != null)
            Text('L${u['floor']}', style: t.labelSmall?.copyWith(color: c)),
        ]),
      ),
    );
  }
}

Future<void> _showUnitSheet(BuildContext context, Map<String, dynamic> u) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _UnitSheet(u),
  );
}

class _UnitSheet extends ConsumerWidget {
  const _UnitSheet(this.u);
  final Map<String, dynamic> u;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final id = '${u['id']}';
    final status = u['inventory_status'] as String?;
    final aed = NumberFormat.currency(symbol: 'AED ', decimalDigits: 0);
    final price = num.tryParse('${u['unit_price'] ?? ''}');
    final spec = [
      if (u['property_type'] != null) _humanize('${u['property_type']}'),
      if (u['bedrooms'] != null) '${u['bedrooms']} ${context.tr('BR')}',
      if (u['bathrooms'] != null) '${u['bathrooms']} ${context.tr('bath')}',
      if (u['size_sqft'] != null) '${(num.tryParse('${u['size_sqft']}') ?? 0).toStringAsFixed(0)} ${context.tr('sqft')}',
    ].join('  ·  ');
    final extra = [
      if ('${u['tower'] ?? ''}'.isNotEmpty) '${context.tr('Building')} ${u['tower']}',
      if (u['floor'] != null) '${context.tr('Floor')} ${u['floor']}',
      if (u['parking'] != null) '${u['parking']} ${context.tr('parking')}',
      if ('${u['view'] ?? ''}'.isNotEmpty) '${u['view']} ${context.tr('view')}',
      if ('${u['furnishing'] ?? ''}'.isNotEmpty) _humanize('${u['furnishing']}'),
    ].join('  ·  ');
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 4, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text('${u['unit_no'] ?? context.tr('Unit')}', style: t.titleLarge?.copyWith(fontWeight: FontWeight.w800))),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: _statusColor(status).withValues(alpha: 0.14), borderRadius: BorderRadius.circular(AppSpacing.rFull)),
              child: Text(context.tr(_statusLabel(status)), style: t.labelMedium?.copyWith(color: _statusColor(status), fontWeight: FontWeight.w700)),
            ),
          ]),
          if ('${u['project'] ?? ''}'.isNotEmpty)
            Text('${u['project']}', style: t.bodyMedium?.copyWith(color: Theme.of(context).hintColor)),
          const SizedBox(height: AppSpacing.x12),
          if (spec.isNotEmpty) Text(spec, style: t.bodyMedium),
          if (extra.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text(extra, style: t.bodySmall?.copyWith(color: Theme.of(context).hintColor))),
          if (price != null && price > 0) ...[
            const SizedBox(height: AppSpacing.x8),
            Text(aed.format(price), style: t.titleMedium?.copyWith(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w800)),
            if (u['down_payment_pct'] != null || '${u['payment_plan'] ?? ''}'.isNotEmpty)
              Text([
                if (u['down_payment_pct'] != null) '${u['down_payment_pct']}% ${context.tr('down')}',
                if ('${u['payment_plan'] ?? ''}'.isNotEmpty) '${u['payment_plan']}',
              ].join('  ·  '), style: t.bodySmall?.copyWith(color: Theme.of(context).hintColor)),
          ],
          const Divider(height: AppSpacing.x24),
          // Deal — the buyer + price behind a reserved/booked/sold status.
          Row(children: [
            Expanded(child: Text(context.tr('Deal'), style: t.labelLarge)),
            TextButton.icon(
              onPressed: () => _editDeal(context, ref, u),
              icon: const Icon(Icons.edit_outlined, size: 14),
              label: Text('${u['sale_buyer'] ?? ''}'.trim().isEmpty ? context.tr('Add') : context.tr('Edit')),
              style: TextButton.styleFrom(visualDensity: VisualDensity.compact, padding: const EdgeInsets.symmetric(horizontal: 8)),
            ),
          ]),
          Builder(builder: (_) {
            final buyer = '${u['sale_buyer'] ?? ''}'.trim();
            final sp = num.tryParse('${u['sale_price'] ?? ''}');
            if (buyer.isEmpty && sp == null) {
              return Text(context.tr('No buyer recorded.'), style: t.bodySmall?.copyWith(color: Theme.of(context).hintColor));
            }
            return Text([
              if (buyer.isNotEmpty) buyer,
              if ('${u['sale_buyer_phone'] ?? ''}'.trim().isNotEmpty) '${u['sale_buyer_phone']}',
              if (sp != null) aed.format(sp),
              if ('${u['sale_date'] ?? ''}'.trim().isNotEmpty) '${u['sale_date']}'.split('T').first,
            ].join('  ·  '), style: t.bodyMedium);
          }),
          const SizedBox(height: AppSpacing.x16),
          Text(context.tr('Set status'), style: t.labelLarge),
          const SizedBox(height: 6),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final s in _unitStatuses)
              ChoiceChip(
                label: Text(context.tr(_humanize(s))),
                selected: status == s,
                selectedColor: _statusColor(s).withValues(alpha: 0.18),
                onSelected: (_) async {
                  await _setStatus(context, ref, id, s);
                  if (context.mounted) Navigator.pop(context);
                },
              ),
          ]),
          const SizedBox(height: 6),
          // Agents (no direct status rights) can request the developer to block a
          // unit for a client; the developer approves it from the panel above.
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => _requestBlock(context, ref, id),
              icon: const Icon(Icons.lock_clock_outlined, size: 16),
              label: Text(context.tr('Request to block')),
              style: TextButton.styleFrom(visualDensity: VisualDensity.compact, padding: EdgeInsets.zero),
            ),
          ),
          const SizedBox(height: AppSpacing.x16),
          Text(context.tr('History'), style: t.labelLarge),
          const SizedBox(height: 6),
          Consumer(builder: (_, r, __) {
            final h = r.watch(_unitHistoryProvider(id));
            return h.maybeWhen(
              data: (list) => list.isEmpty
                  ? Text(context.tr('No status changes yet.'), style: t.bodySmall?.copyWith(color: Theme.of(context).hintColor))
                  : Column(children: [
                      for (final e in list.take(12))
                        Builder(builder: (_) {
                          final m = Map<String, dynamic>.from(e);
                          final when = DateTime.tryParse('${m['changed_at']}');
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 3),
                            child: Row(children: [
                              Expanded(
                                child: Text([
                                  if (m['from_status'] != null) context.tr(_humanize('${m['from_status']}')),
                                  '→ ${context.tr(_humanize('${m['to_status'] ?? ''}'))}',
                                  if ('${m['note'] ?? ''}'.isNotEmpty) '· ${m['note']}',
                                ].join(' '), style: t.bodySmall),
                              ),
                              if (when != null) Text(DateFormat('d MMM').format(when), style: t.labelSmall?.copyWith(color: Theme.of(context).hintColor)),
                            ]),
                          );
                        }),
                    ]),
              orElse: () => const Padding(padding: EdgeInsets.all(8), child: Center(child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)))),
            );
          }),
        ]),
      ),
    );
  }

  Future<void> _setStatus(BuildContext context, WidgetRef ref, String id, String status) async {
    try {
      await ref.read(apiClientProvider).patch('/inventory/$id/status', body: {'status': status});
      ref.invalidate(inventoryProvider);
      ref.invalidate(_unitHistoryProvider(id));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${context.tr('Unit set to')} ${context.tr(_humanize(status))}')));
      }
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
    }
  }

  Future<void> _editDeal(BuildContext context, WidgetRef ref, Map<String, dynamic> u) async {
    final buyer = TextEditingController(text: '${u['sale_buyer'] ?? ''}');
    final phone = TextEditingController(text: '${u['sale_buyer_phone'] ?? ''}');
    final price = TextEditingController(text: u['sale_price'] != null ? '${u['sale_price']}' : '');
    final date = TextEditingController(text: '${u['sale_date'] ?? ''}'.split('T').first);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.tr('Deal details')),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: buyer, decoration: InputDecoration(labelText: context.tr('Buyer name'))),
            const SizedBox(height: AppSpacing.x8),
            TextField(controller: phone, keyboardType: TextInputType.phone, decoration: InputDecoration(labelText: context.tr('Buyer phone'))),
            const SizedBox(height: AppSpacing.x8),
            TextField(controller: price, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: context.tr('Sale price (AED)'))),
            const SizedBox(height: AppSpacing.x8),
            TextField(controller: date, decoration: InputDecoration(labelText: context.tr('Date (YYYY-MM-DD)'))),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(context.tr('Cancel'))),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(context.tr('Save'))),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(apiClientProvider).patch('/inventory/${u['id']}/deal', body: {
        'sale_buyer': buyer.text.trim(),
        'sale_buyer_phone': phone.text.trim(),
        'sale_price': price.text.trim(),
        'sale_date': date.text.trim(),
      });
      ref.invalidate(inventoryProvider);
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.tr('Deal saved'))));
      }
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
    }
  }

  Future<void> _requestBlock(BuildContext context, WidgetRef ref, String id) async {
    final note = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.tr('Request to block')),
        content: TextField(controller: note, maxLines: 2,
            decoration: InputDecoration(labelText: context.tr('Note (client / reservation)'))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(context.tr('Cancel'))),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(context.tr('Send'))),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(apiClientProvider).post('/inventory/units/$id/block-request', body: {'note': note.text.trim()});
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.tr('Block request sent'))));
      }
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
    }
  }
}

/// Rich "Add units" sheet — generates a batch with shared specs + pricing.
Future<void> _showAddUnitsSheet(BuildContext context, WidgetRef ref, String projectId) async {
  final count = TextEditingController(text: '1');
  final prefix = TextEditingController(text: 'Unit');
  final startNo = TextEditingController(text: '1');
  final tower = TextEditingController();
  final floor = TextEditingController();
  final beds = TextEditingController();
  final baths = TextEditingController();
  final sqft = TextEditingController();
  final parking = TextEditingController();
  final view = TextEditingController();
  final price = TextEditingController();
  final downPct = TextEditingController();
  final plan = TextEditingController();
  var ptype = 'apartment';
  var furnishing = 'unfurnished';

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) {
      Widget field(TextEditingController c, String label, {bool num = false}) => Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.x8),
            child: TextField(
              controller: c,
              keyboardType: num ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
              decoration: InputDecoration(labelText: label, isDense: true),
            ),
          );
      return StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: EdgeInsets.fromLTRB(20, 4, 20, 20 + MediaQuery.of(ctx).viewInsets.bottom),
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(context.tr('Add units'), style: Theme.of(ctx).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: AppSpacing.x12),
              Row(children: [
                Expanded(child: field(count, context.tr('How many'), num: true)),
                const SizedBox(width: AppSpacing.x8),
                Expanded(child: field(prefix, context.tr('Name prefix'))),
                const SizedBox(width: AppSpacing.x8),
                Expanded(child: field(startNo, context.tr('Start #'), num: true)),
              ]),
              Row(children: [
                Expanded(child: field(tower, context.tr('Building'))),
                const SizedBox(width: AppSpacing.x8),
                Expanded(child: field(floor, context.tr('Floor'), num: true)),
              ]),
              DropdownButtonFormField<String>(
                initialValue: ptype,
                decoration: InputDecoration(labelText: context.tr('Type'), isDense: true),
                items: [
                  DropdownMenuItem(value: 'apartment', child: Text(context.tr('Apartment'))),
                  DropdownMenuItem(value: 'villa', child: Text(context.tr('Villa'))),
                  DropdownMenuItem(value: 'townhouse', child: Text(context.tr('Townhouse'))),
                  DropdownMenuItem(value: 'penthouse', child: Text(context.tr('Penthouse'))),
                  DropdownMenuItem(value: 'office', child: Text(context.tr('Office'))),
                  DropdownMenuItem(value: 'retail', child: Text(context.tr('Retail'))),
                ],
                onChanged: (v) => setS(() => ptype = v ?? 'apartment'),
              ),
              const SizedBox(height: AppSpacing.x8),
              Row(children: [
                Expanded(child: field(beds, context.tr('Beds'), num: true)),
                const SizedBox(width: AppSpacing.x8),
                Expanded(child: field(baths, context.tr('Baths'), num: true)),
                const SizedBox(width: AppSpacing.x8),
                Expanded(child: field(sqft, context.tr('Area (sqft)'), num: true)),
              ]),
              Row(children: [
                Expanded(child: field(parking, context.tr('Parking'), num: true)),
                const SizedBox(width: AppSpacing.x8),
                Expanded(child: field(view, context.tr('View'))),
              ]),
              DropdownButtonFormField<String>(
                initialValue: furnishing,
                decoration: InputDecoration(labelText: context.tr('Furnishing'), isDense: true),
                items: [
                  DropdownMenuItem(value: 'unfurnished', child: Text(context.tr('Unfurnished'))),
                  DropdownMenuItem(value: 'partly_furnished', child: Text(context.tr('Partly furnished'))),
                  DropdownMenuItem(value: 'furnished', child: Text(context.tr('Furnished'))),
                ],
                onChanged: (v) => setS(() => furnishing = v ?? 'unfurnished'),
              ),
              const SizedBox(height: AppSpacing.x8),
              Row(children: [
                Expanded(child: field(price, context.tr('Price (AED)'), num: true)),
                const SizedBox(width: AppSpacing.x8),
                Expanded(child: field(downPct, context.tr('Down %'), num: true)),
              ]),
              field(plan, context.tr('Payment plan (e.g. 60/40 on handover)')),
              const SizedBox(height: AppSpacing.x8),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () async {
                    final n = int.tryParse(count.text.trim()) ?? 0;
                    if (n <= 0) return;
                    try {
                      await ref.read(apiClientProvider).post('/projects/$projectId/units', body: {
                        'count': n,
                        'prefix': prefix.text.trim().isEmpty ? 'Unit' : prefix.text.trim(),
                        'start_no': int.tryParse(startNo.text.trim()) ?? 1,
                        'tower': tower.text.trim(),
                        'floor': floor.text.trim(),
                        'property_type': ptype,
                        'bedrooms': beds.text.trim(),
                        'bathrooms': baths.text.trim(),
                        'size_sqft': sqft.text.trim(),
                        'parking': parking.text.trim(),
                        'view': view.text.trim(),
                        'furnishing': furnishing,
                        'unit_price': price.text.trim(),
                        'down_payment_pct': downPct.text.trim(),
                        'payment_plan': plan.text.trim(),
                      });
                      ref.invalidate(inventoryProvider);
                      if (ctx.mounted) {
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$n ${context.tr(n == 1 ? 'unit' : 'units')} ${context.tr('added')}')));
                      }
                    } catch (e) {
                      if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(friendlyError(e))));
                    }
                  },
                  child: Text(context.tr('Add units')),
                ),
              ),
            ]),
          ),
        ),
      );
    },
  );
}

/// Developer-facing pending unit-block requests with approve / reject.
class _BlockRequestsPanel extends ConsumerWidget {
  const _BlockRequestsPanel();

  Future<void> _decide(BuildContext context, WidgetRef ref, String id, String action) async {
    try {
      await ref.read(apiClientProvider).post('/inventory/block-requests/$id/decide', body: {'action': action});
      ref.invalidate(blockRequestsProvider);
      ref.invalidate(inventoryProvider);
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reqs = ref.watch(blockRequestsProvider);
    return reqs.maybeWhen(
      data: (list) {
        if (list.isEmpty) return const SizedBox.shrink();
        final t = Theme.of(context).textTheme;
        return Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.x16, AppSpacing.x16, AppSpacing.x16, 0),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.x12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${context.tr('Block requests')} (${list.length})', style: t.titleSmall),
                for (final m in list)
                  Builder(builder: (_) {
                    final r = Map<String, dynamic>.from(m);
                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text('${r['unit_no'] ?? context.tr('Unit')} · ${r['project'] ?? ''}'),
                      subtitle: Text([
                        if (r['agent_name'] != null) '${context.tr('by')} ${r['agent_name']}',
                        if ('${r['note'] ?? ''}'.isNotEmpty) '${r['note']}',
                      ].join('  ·  ')),
                      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                        TextButton(onPressed: () => _decide(context, ref, '${r['id']}', 'approve'), child: Text(context.tr('Approve'))),
                        TextButton(
                          style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
                          onPressed: () => _decide(context, ref, '${r['id']}', 'reject'),
                          child: Text(context.tr('Reject')),
                        ),
                      ]),
                    );
                  }),
              ]),
            ),
          ),
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }
}

String _humanize(String k) => k
    .replaceAll('_', ' ')
    .split(' ')
    .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
    .join(' ');
