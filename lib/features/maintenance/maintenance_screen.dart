import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/network/api_client.dart';
import '../../core/network/upload_service.dart';
import '../../core/rbac/persona.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/responsive.dart';
import '../shell/app_shell.dart';

final jobsProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  try { final d = await ref.read(apiClientProvider).get('/maintenance/jobs'); return d is List ? d : []; } catch (_) { return []; }
});
final maintPropertiesProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  try { final d = await ref.read(apiClientProvider).get('/maintenance/properties'); return d is List ? d : []; } catch (_) { return []; }
});
final providersProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  try { final d = await ref.read(apiClientProvider).get('/service-providers'); return d is List ? d : []; } catch (_) { return []; }
});
final maintSummaryProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  try { return Map<String, dynamic>.from(await ref.read(apiClientProvider).get('/maintenance/summary')); } catch (_) { return {}; }
});

class MaintenanceScreen extends ConsumerWidget {
  const MaintenanceScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jobs = ref.watch(jobsProvider);
    final providers = ref.watch(providersProvider);
    return Scaffold(
      appBar: NuzlAppBar(title: context.tr('Maintenance')),
      drawer: const NuzlDrawer(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openRequest(context),
        icon: const Icon(Icons.build_outlined),
        label: Text(context.tr('Request job')),
      ),
      body: ResponsiveCenter(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(jobsProvider);
            ref.invalidate(providersProvider);
            ref.invalidate(maintSummaryProvider);
          },
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.x16),
            children: [
              ref.watch(maintSummaryProvider).maybeWhen(
                data: (s) {
                  final total = num.tryParse('${s['total_cost'] ?? 0}') ?? 0;
                  final open = s['open'] ?? 0;
                  final completed = s['completed'] ?? 0;
                  if (total == 0 && open == 0 && completed == 0) return const SizedBox.shrink();
                  final aed = NumberFormat.compactCurrency(symbol: 'AED ', decimalDigits: 0);
                  final tt = Theme.of(context).textTheme;
                  final dark = Theme.of(context).brightness == Brightness.dark;
                  Widget metric(String label, String value) => Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [Text(value, style: tt.titleLarge),
                          Text(context.tr(label), style: tt.bodySmall?.copyWith(color: dark ? AppColors.dTextMuted : AppColors.textMuted))],
                      );
                  return Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.x16),
                    child: Card(child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.x16),
                      child: Wrap(spacing: AppSpacing.x16, runSpacing: AppSpacing.x12, children: [
                        metric('Total spend', aed.format(total)),
                        metric('Open', '$open'),
                        metric('Completed', '$completed'),
                      ]),
                    )),
                  );
                },
                orElse: () => const SizedBox.shrink(),
              ),
              Text(context.tr('Requests'), style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: AppSpacing.x8),
              jobs.when(
                loading: () => const LinearProgressIndicator(),
                error: (e, _) => Text(friendlyError(e)),
                data: (list) => list.isEmpty
                    ? Text(context.tr('No requests yet — raise one with the button below.'))
                    : Column(children: list.map((m) => _JobCard(j: Map<String, dynamic>.from(m))).toList()),
              ),
              const SizedBox(height: AppSpacing.x24),
              Text(context.tr('Service providers'), style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: AppSpacing.x8),
              providers.when(
                loading: () => const LinearProgressIndicator(),
                error: (e, _) => Text(friendlyError(e)),
                data: (list) => list.isEmpty
                    ? Text(context.tr('No providers listed yet.'))
                    : Column(children: list.map((m) {
                        final p = Map<String, dynamic>.from(m);
                        final cats = (p['categories'] is List) ? (p['categories'] as List).join(', ') : '';
                        return Card(child: ListTile(
                          leading: const CircleAvatar(child: Icon(Icons.handyman_outlined)),
                          title: Text(p['name'] ?? context.tr('Provider')),
                          subtitle: Text(cats),
                          trailing: Text('★ ${p['rating'] ?? 0}'),
                        ));
                      }).toList()),
              ),
              const SizedBox(height: AppSpacing.x24),
            ],
          ),
        ),
      ),
    );
  }

  void _openRequest(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => const _RequestSheet(),
    );
  }
}

class _JobCard extends ConsumerWidget {
  const _JobCard({required this.j});
  final Map<String, dynamic> j;

  Future<void> _advance(BuildContext context, WidgetRef ref) async {
    const flow = ['requested', 'matched', 'accepted', 'in_progress', 'completed', 'cancelled'];
    final current = '${j['status']}';
    final picked = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: ListView(shrinkWrap: true, children: flow.map((s) => ListTile(
          title: Text(context.tr(s)),
          trailing: s == current ? Icon(Icons.check, color: Theme.of(ctx).colorScheme.primary) : null,
          onTap: () => Navigator.pop(ctx, s),
        )).toList()),
      ),
    );
    if (picked == null || picked == current) return;
    try {
      await ref.read(apiClientProvider).patch('/maintenance/jobs/${j['id']}/status', body: {'status': picked});
      ref.invalidate(jobsProvider);
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
    }
  }

  Future<void> _actions(BuildContext context, WidgetRef ref,
      {required bool canAssign, required bool canUpdate}) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: ListView(shrinkWrap: true, children: [
          // "Assign provider" is the property holder hiring a contractor;
          // "Update status" is the service provider's job-progress workflow.
          if (canAssign)
            ListTile(
                leading: const Icon(Icons.handyman_outlined),
                title: Text(context.tr('Assign provider')),
                onTap: () => Navigator.pop(ctx, 'assign')),
          if (canUpdate)
            ListTile(
                leading: const Icon(Icons.flag_outlined),
                title: Text(context.tr('Update status')),
                onTap: () => Navigator.pop(ctx, 'status')),
        ]),
      ),
    );
    if (action == 'assign' && context.mounted) {
      await _assign(context, ref);
    } else if (action == 'status' && context.mounted) {
      await _advance(context, ref);
    }
  }

  /// Owner picks a service provider from the marketplace of providers (owner #4).
  Future<void> _assign(BuildContext context, WidgetRef ref) async {
    List<dynamic> providers = [];
    try {
      final d = await ref.read(apiClientProvider).get('/service-providers');
      providers = d is List ? d : [];
    } catch (_) {/* show empty below */}
    if (!context.mounted) return;
    if (providers.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(context.tr('No service providers available yet.'))));
      return;
    }
    final picked = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: providers.map((m) {
            final p = Map<String, dynamic>.from(m);
            final cats = (p['categories'] is List) ? (p['categories'] as List).join(', ') : '';
            return ListTile(
              leading: const Icon(Icons.handyman_outlined),
              title: Text('${p['name'] ?? context.tr('Provider')}'),
              subtitle: cats.isNotEmpty ? Text(cats) : null,
              trailing: Text('★ ${p['rating'] ?? 0}'),
              onTap: () => Navigator.pop(ctx, '${p['id']}'),
            );
          }).toList(),
        ),
      ),
    );
    if (picked == null) return;
    try {
      await ref.read(apiClientProvider)
          .patch('/maintenance/jobs/${j['id']}/assign', body: {'provider_id': picked});
      ref.invalidate(jobsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.tr('Provider assigned.'))));
      }
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final persona = ref.watch(personaProvider);
    // Property holders (owner / investor / admin) hire a provider; service
    // providers progress the job's status. Others just view their request.
    final canAssign = persona.canManagePortfolio;
    final canUpdate = persona.isServiceProvider;
    final canAct = canAssign || canUpdate;
    final images = (j['images'] is List) ? (j['images'] as List).map((e) => '$e').where((s) => s.isNotEmpty).toList() : <String>[];
    final where = [
      if ('${j['community'] ?? ''}'.isNotEmpty) '${j['community']}',
      if ('${j['unit_no'] ?? ''}'.isNotEmpty) '${context.tr('Unit')} ${j['unit_no']}',
    ].join(' · ');
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: canAct ? () => _actions(context, ref, canAssign: canAssign, canUpdate: canUpdate) : null,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.x12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (images.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppSpacing.rSm),
                  child: Image.network(images.first, width: 52, height: 52, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const SizedBox(width: 52, height: 52)),
                )
              else
                Container(
                  width: 52, height: 52,
                  decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(AppSpacing.rSm)),
                  child: const Icon(Icons.build_outlined, color: AppColors.textSubtle),
                ),
              const SizedBox(width: AppSpacing.x12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${_cap('${j['category'] ?? 'Maintenance'}')}${where.isNotEmpty ? ' · $where' : ''}',
                        style: t.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                    if ('${j['description'] ?? ''}'.isNotEmpty)
                      Text('${j['description']}', style: t.bodySmall?.copyWith(color: dark ? AppColors.dTextMuted : AppColors.textMuted),
                          maxLines: 2, overflow: TextOverflow.ellipsis),
                    if ('${j['provider_name'] ?? ''}'.isNotEmpty)
                      Text('${context.tr('Assigned')}: ${j['provider_name']}', style: t.labelSmall?.copyWith(color: dark ? AppColors.dTextMuted : AppColors.textMuted)),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.x8),
              _StatusChip(status: '${j['status']}'),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bottom-sheet form: pick a property you own/tenant, category, description, photo.
class _RequestSheet extends ConsumerStatefulWidget {
  const _RequestSheet();
  @override
  ConsumerState<_RequestSheet> createState() => _RequestSheetState();
}

class _RequestSheetState extends ConsumerState<_RequestSheet> {
  static const _categories = ['ac', 'plumbing', 'electrical', 'appliance', 'cleaning', 'general'];
  String? _propertyId;
  String _category = 'ac';
  final _desc = TextEditingController();
  String? _imageUrl;
  bool _uploading = false;
  bool _submitting = false;

  @override
  void dispose() {
    _desc.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    try {
      final picked = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1600, imageQuality: 80);
      if (picked == null) return;
      setState(() => _uploading = true);
      final bytes = await picked.readAsBytes();
      final url = await ref.read(uploadServiceProvider).upload(bytes, picked.name, 'image/jpeg');
      setState(() => _imageUrl = url);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${context.tr('Photo not added')} — ${friendlyError(e)}')));
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _submit() async {
    if (_propertyId == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.tr('Pick a property first.'))));
      return;
    }
    setState(() => _submitting = true);
    try {
      await ref.read(apiClientProvider).post('/maintenance/jobs', body: {
        'property_id': _propertyId,
        'category': _category,
        'description': _desc.text.trim(),
        if (_imageUrl != null) 'images': [_imageUrl],
      });
      ref.invalidate(jobsProvider);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final props = ref.watch(maintPropertiesProvider);
    return Padding(
      padding: EdgeInsets.fromLTRB(
          AppSpacing.x20, AppSpacing.x8, AppSpacing.x20, MediaQuery.viewInsetsOf(context).bottom + AppSpacing.x20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(context.tr('Request maintenance'), style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppSpacing.x16),
          props.when(
            loading: () => const Padding(padding: EdgeInsets.all(8), child: LinearProgressIndicator()),
            error: (e, _) => Text(friendlyError(e)),
            data: (list) => list.isEmpty
                ? Text(context.tr('No properties found. You can raise maintenance once you own a property or have an active tenancy.'))
                : DropdownButtonFormField<String>(
                    initialValue: _propertyId,
                    isExpanded: true,
                    decoration: InputDecoration(labelText: context.tr('Property'), prefixIcon: const Icon(Icons.home_outlined)),
                    items: list.map((m) {
                      final p = Map<String, dynamic>.from(m);
                      final label = [
                        if ('${p['community'] ?? ''}'.isNotEmpty) '${p['community']}',
                        if ('${p['unit_no'] ?? ''}'.isNotEmpty) '${context.tr('Unit')} ${p['unit_no']}',
                        if ('${p['community'] ?? ''}'.isEmpty && '${p['unit_no'] ?? ''}'.isEmpty) _cap('${p['property_type'] ?? 'Property'}'),
                      ].join(' · ');
                      return DropdownMenuItem(
                        value: '${p['id']}',
                        child: Text('$label${p['is_owner'] == true ? '' : ' (${context.tr('tenancy')})'}',
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                      );
                    }).toList(),
                    onChanged: (v) => setState(() => _propertyId = v),
                  ),
          ),
          const SizedBox(height: AppSpacing.x12),
          DropdownButtonFormField<String>(
            initialValue: _category,
            decoration: InputDecoration(labelText: context.tr('Category'), prefixIcon: const Icon(Icons.category_outlined)),
            items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(_cap(c)))).toList(),
            onChanged: (v) => setState(() => _category = v ?? 'general'),
          ),
          const SizedBox(height: AppSpacing.x12),
          TextField(
            controller: _desc,
            minLines: 2, maxLines: 4,
            decoration: InputDecoration(labelText: context.tr('Describe the issue'), alignLabelWithHint: true),
          ),
          const SizedBox(height: AppSpacing.x12),
          Row(children: [
            OutlinedButton.icon(
              onPressed: _uploading ? null : _pickPhoto,
              icon: _uploading
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.add_a_photo_outlined, size: 18),
              label: Text(context.tr(_imageUrl == null ? 'Add photo' : 'Photo added')),
            ),
            const SizedBox(width: AppSpacing.x12),
            if (_imageUrl != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(AppSpacing.rSm),
                child: Image.network(_imageUrl!, width: 44, height: 44, fit: BoxFit.cover),
              ),
          ]),
          const SizedBox(height: AppSpacing.x20),
          FilledButton(
            onPressed: _submitting ? null : _submit,
            child: _submitting
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Text(context.tr('Submit request')),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final String status;
  @override
  Widget build(BuildContext context) {
    final done = status == 'completed';
    final cancelled = status == 'cancelled';
    final color = cancelled ? Colors.redAccent : done ? AppColors.primary : AppColors.accentGold;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(AppSpacing.rFull)),
      child: Text(context.tr(status), style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12)),
    );
  }
}

String _cap(String s) {
  final x = s.replaceAll('_', ' ').trim();
  return x.isEmpty ? x : '${x[0].toUpperCase()}${x.substring(1)}';
}
