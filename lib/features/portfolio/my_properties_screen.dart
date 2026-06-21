import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/network/api_client.dart';
import '../../core/network/upload_service.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/app_dialog.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/place_field.dart';
import '../../core/widgets/responsive.dart';
import '../shell/app_shell.dart';

final _portfoliosProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  try {
    final d = await ref.read(apiClientProvider).get('/portfolio');
    return d is List ? d : [];
  } catch (_) {
    return [];
  }
});

final _selectedPortfolioProvider = StateProvider.autoDispose<String?>((ref) => null);

final _overviewProvider = FutureProvider.autoDispose.family<Map<String, dynamic>, String>((ref, id) async {
  try {
    final d = await ref.read(apiClientProvider).get('/portfolio/$id/overview');
    return d is Map ? Map<String, dynamic>.from(d) : <String, dynamic>{};
  } catch (_) {
    return <String, dynamic>{};
  }
});

String _money(dynamic v) {
  final n = v is num ? v : num.tryParse('${v ?? ''}');
  if (n == null) return '—';
  return NumberFormat.compactCurrency(symbol: 'AED ', decimalDigits: 0).format(n);
}

class MyPropertiesScreen extends ConsumerWidget {
  const MyPropertiesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final portfolios = ref.watch(_portfoliosProvider);
    final selected = ref.watch(_selectedPortfolioProvider);
    return Scaffold(
      appBar: const NuzlAppBar(title: 'My Properties'),
      drawer: const NuzlDrawer(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _verifyOwnership(context, ref),
        icon: const Icon(Icons.verified_user_outlined),
        label: const Text('Verify ownership'),
      ),
      body: ResponsiveCenter(
        child: portfolios.when(
          loading: () => const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator())),
          error: (e, _) => Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(friendlyError(e)))),
          data: (list) {
            if (list.isEmpty) {
              return EmptyState(
                icon: Icons.verified_user_outlined,
                title: 'Start with ownership',
                message: 'Verify a property you own — upload your title deed and we’ll create the '
                    'record for you. (Off-plan, international or commercial without a deed? '
                    'Use “Add unverified property”.)',
                actionLabel: 'Verify property ownership',
                onAction: () => _verifyOwnership(context, ref),
              );
            }
            final ids = list.map((e) => '${(e as Map)['id']}').toList();
            final active = (selected != null && ids.contains(selected)) ? selected : ids.first;
            return ListView(
              padding: const EdgeInsets.all(AppSpacing.x16),
              children: [
                // Primary path is the "Verify ownership" FAB. Manual entry is the
                // exception (off-plan / international / commercial / no deed) and
                // lands as an Unverified asset until a deed is verified.
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => _addProperty(context, ref),
                    icon: const Icon(Icons.add_home_outlined, size: 18),
                    label: const Text('Add unverified property'),
                  ),
                ),
                const SizedBox(height: AppSpacing.x8),
                if (list.length > 1) ...[
                  DropdownButtonFormField<String>(
                    initialValue: active,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Portfolio'),
                    items: list.map((e) {
                      final m = Map<String, dynamic>.from(e);
                      return DropdownMenuItem(value: '${m['id']}', child: Text('${m['name'] ?? 'Portfolio'}'));
                    }).toList(),
                    onChanged: (v) => ref.read(_selectedPortfolioProvider.notifier).state = v,
                  ),
                  const SizedBox(height: AppSpacing.x16),
                ],
                _Overview(portfolioId: active),
              ],
            );
          },
        ),
      ),
    );
  }

  /// Owner adds a property RECORD they own (creates the asset + links it to their
  /// portfolio). No public listing is created — they assign an agent on the
  /// property workspace, and the agent publishes it.
  Future<void> _addProperty(BuildContext context, WidgetRef ref) async {
    final building = TextEditingController();
    final unit = TextEditingController();
    final beds = TextEditingController();
    final baths = TextEditingController();
    final size = TextEditingController();
    final price = TextEditingController();
    var type = 'apartment';
    double? lat, lng;
    final ok = await AppDialog.show<bool>(
      context,
      title: 'Add unverified property',
      children: [
        StatefulBuilder(
          builder: (ctx, setS) => Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.x12),
              decoration: BoxDecoration(
                color: Theme.of(ctx).colorScheme.primary.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(AppSpacing.rSm),
              ),
              child: Row(children: [
                Icon(Icons.info_outline, size: 18, color: Theme.of(ctx).colorScheme.primary),
                const SizedBox(width: AppSpacing.x8),
                Expanded(
                  child: Text(
                    'For off-plan (Oqood), international or commercial properties without a title deed. '
                    'It will be marked Unverified until you verify ownership.',
                    style: Theme.of(ctx).textTheme.bodySmall,
                  ),
                ),
              ]),
            ),
            const SizedBox(height: AppSpacing.x12),
            PlaceField(
              controller: building,
              label: 'Building / location',
              onSelected: (p) { lat = p.lat; lng = p.lng; },
              onCleared: () { lat = null; lng = null; },
            ),
            const SizedBox(height: AppSpacing.x8),
            TextField(controller: unit, decoration: const InputDecoration(labelText: 'Unit no.')),
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
            const SizedBox(height: AppSpacing.x8),
            Row(children: [
              Expanded(child: TextField(controller: beds, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Beds'))),
              const SizedBox(width: AppSpacing.x8),
              Expanded(child: TextField(controller: baths, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Baths'))),
            ]),
            const SizedBox(height: AppSpacing.x8),
            Row(children: [
              Expanded(child: TextField(controller: size, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Size (sqft)'))),
              const SizedBox(width: AppSpacing.x8),
              Expanded(child: TextField(controller: price, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Purchase price'))),
            ]),
          ]),
        ),
      ],
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            if (building.text.trim().isEmpty) {
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(const SnackBar(content: Text('Add a building or location.')));
              return;
            }
            Navigator.pop(context, true);
          },
          child: const Text('Add'),
        ),
      ],
    );
    if (ok != true) return;
    try {
      final res = await ref.read(apiClientProvider).post('/portfolio/property', body: {
        'building_name': building.text.trim(),
        'unit_no': unit.text.trim(),
        'property_type': type,
        'bedrooms': int.tryParse(beds.text.trim()),
        'bathrooms': int.tryParse(baths.text.trim()),
        'size_sqft': double.tryParse(size.text.trim()),
        'purchase_price': double.tryParse(price.text.trim()),
        if (lat != null) 'latitude': lat,
        if (lng != null) 'longitude': lng,
      });
      ref.invalidate(_portfoliosProvider);
      ref.invalidate(_overviewProvider);
      final id = res is Map ? '${res['id'] ?? ''}' : '';
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Property added to your portfolio.')));
        if (id.isNotEmpty) context.push('/property-record/$id');
      }
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
    }
  }

  /// Pick a Title Deed (PDF/image) and upload it → (url, filename) or null.
  Future<(String, String)?> _pickDeed(BuildContext context, WidgetRef ref) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom, allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png', 'webp'], withData: true);
    if (result == null || result.files.isEmpty) return null;
    final f = result.files.first;
    final bytes = f.bytes;
    if (bytes == null) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not read the file')));
      return null;
    }
    final ext = (f.extension ?? '').toLowerCase();
    final ct = ext == 'pdf'
        ? 'application/pdf'
        : ext == 'png' ? 'image/png' : ext == 'webp' ? 'image/webp' : 'image/jpeg';
    try {
      final url = await ref.read(uploadServiceProvider).upload(bytes, f.name, ct);
      if (url == null) {
        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Upload returned no URL')));
        return null;
      }
      return (url, f.name);
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload failed: ${friendlyError(e)}')));
      return null;
    }
  }

  /// Verify Property Ownership wizard (owner deed spec §2/§4/§5): upload the
  /// title deed, confirm the details (auto-extraction lights up when document AI
  /// is enabled), then the record is created with an ownership status from a
  /// name-match of the account holder against the name on the deed.
  Future<void> _verifyOwnership(BuildContext context, WidgetRef ref) async {
    final deedName = TextEditingController();
    final deedNo = TextEditingController();
    final building = TextEditingController();
    final unit = TextEditingController();
    final beds = TextEditingController();
    final baths = TextEditingController();
    final size = TextEditingController();
    final price = TextEditingController();
    final plot = TextEditingController();
    final muni = TextEditingController();
    var type = 'apartment';
    double? lat, lng;
    String? deedUrl, deedFile;
    DateTime? purchaseDate;
    var uploading = false;

    final ok = await AppDialog.show<bool>(
      context,
      title: 'Verify property ownership',
      children: [
        StatefulBuilder(builder: (ctx, setS) {
          Future<void> pick() async {
            setS(() => uploading = true);
            final picked = await _pickDeed(ctx, ref);
            setS(() {
              uploading = false;
              if (picked != null) { deedUrl = picked.$1; deedFile = picked.$2; }
            });
          }

          final theme = Theme.of(ctx);
          return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.x12),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(AppSpacing.rSm),
              ),
              child: Row(children: [
                Icon(Icons.info_outline, size: 18, color: theme.colorScheme.primary),
                const SizedBox(width: AppSpacing.x8),
                Expanded(
                  child: Text('Upload your title deed and confirm the details below. Automatic extraction '
                      'turns on when document AI is enabled.', style: theme.textTheme.bodySmall),
                ),
              ]),
            ),
            const SizedBox(height: AppSpacing.x12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: uploading ? null : pick,
                icon: uploading
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : Icon(deedUrl != null ? Icons.check_circle_outline : Icons.upload_file_outlined),
                label: Text(deedFile ?? 'Upload title deed (PDF / JPG / PNG)', overflow: TextOverflow.ellipsis),
              ),
            ),
            const SizedBox(height: AppSpacing.x8),
            TextField(controller: deedName, decoration: const InputDecoration(
                labelText: 'Owner name (exactly as on the deed)')),
            const SizedBox(height: AppSpacing.x8),
            TextField(controller: deedNo, decoration: const InputDecoration(labelText: 'Title deed number')),
            const Divider(height: AppSpacing.x24),
            PlaceField(
              controller: building,
              label: 'Building / location',
              onSelected: (p) { lat = p.lat; lng = p.lng; },
              onCleared: () { lat = null; lng = null; },
            ),
            const SizedBox(height: AppSpacing.x8),
            TextField(controller: unit, decoration: const InputDecoration(labelText: 'Unit no.')),
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
            const SizedBox(height: AppSpacing.x8),
            Row(children: [
              Expanded(child: TextField(controller: beds, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Beds'))),
              const SizedBox(width: AppSpacing.x8),
              Expanded(child: TextField(controller: baths, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Baths'))),
            ]),
            const SizedBox(height: AppSpacing.x8),
            Row(children: [
              Expanded(child: TextField(controller: size, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Size (sqft)'))),
              const SizedBox(width: AppSpacing.x8),
              Expanded(child: TextField(controller: price, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Purchase price'))),
            ]),
            const SizedBox(height: AppSpacing.x8),
            Row(children: [
              Expanded(child: TextField(controller: plot, decoration: const InputDecoration(labelText: 'Plot no.'))),
              const SizedBox(width: AppSpacing.x8),
              Expanded(child: TextField(controller: muni, decoration: const InputDecoration(labelText: 'Municipality no.'))),
            ]),
            const SizedBox(height: AppSpacing.x8),
            InkWell(
              onTap: () async {
                final d = await showDatePicker(
                  context: ctx,
                  initialDate: purchaseDate ?? DateTime(2020),
                  firstDate: DateTime(1980),
                  lastDate: DateTime(2100),
                );
                if (d != null) setS(() => purchaseDate = d);
              },
              child: InputDecorator(
                decoration: const InputDecoration(labelText: 'Purchase date', suffixIcon: Icon(Icons.calendar_today, size: 18)),
                child: Text(purchaseDate == null ? 'Select date' : DateFormat('d MMM yyyy').format(purchaseDate!)),
              ),
            ),
          ]);
        }),
      ],
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            if (building.text.trim().isEmpty) {
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(const SnackBar(content: Text('Add a building or location.')));
              return;
            }
            Navigator.pop(context, true);
          },
          child: const Text('Verify & add'),
        ),
      ],
    );
    if (ok != true) return;
    try {
      final res = await ref.read(apiClientProvider).post('/portfolio/property', body: {
        'building_name': building.text.trim(),
        'unit_no': unit.text.trim(),
        'property_type': type,
        'bedrooms': int.tryParse(beds.text.trim()),
        'bathrooms': int.tryParse(baths.text.trim()),
        'size_sqft': double.tryParse(size.text.trim()),
        'purchase_price': double.tryParse(price.text.trim()),
        if (lat != null) 'latitude': lat,
        if (lng != null) 'longitude': lng,
        if (deedUrl != null) 'title_deed_url': deedUrl,
        if (deedName.text.trim().isNotEmpty) 'owner_name_on_deed': deedName.text.trim(),
        if (deedNo.text.trim().isNotEmpty) 'title_deed_number': deedNo.text.trim(),
        if (plot.text.trim().isNotEmpty) 'plot_number': plot.text.trim(),
        if (muni.text.trim().isNotEmpty) 'municipality_number': muni.text.trim(),
        if (purchaseDate != null) 'purchase_date': purchaseDate!.toIso8601String().split('T').first,
      });
      ref.invalidate(_portfoliosProvider);
      ref.invalidate(_overviewProvider);
      final id = res is Map ? '${res['id'] ?? ''}' : '';
      final status = res is Map ? '${res['ownership_status'] ?? ''}' : '';
      if (context.mounted) {
        final msg = status == 'verified'
            ? 'Ownership verified ✓ — property added.'
            : status == 'pending'
                ? 'Property added — ownership pending review.'
                : 'Property added to your portfolio.';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
        if (id.isNotEmpty) context.push('/property-record/$id');
      }
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
    }
  }
}

class _Overview extends ConsumerWidget {
  const _Overview({required this.portfolioId});
  final String portfolioId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ov = ref.watch(_overviewProvider(portfolioId));
    return ov.when(
      loading: () => const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator())),
      error: (e, _) => Padding(padding: const EdgeInsets.all(24), child: Text(friendlyError(e))),
      data: (m) {
        final totals = m['totals'] is Map ? Map<String, dynamic>.from(m['totals']) : <String, dynamic>{};
        final properties = m['properties'] is List ? (m['properties'] as List) : const [];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GridView(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: AppSpacing.x12,
                crossAxisSpacing: AppSpacing.x12,
                mainAxisExtent: 104,
              ),
              children: [
                _Stat('Market value', _money(totals['market_value'])),
                _Stat('Equity', _money(totals['equity'])),
                _Stat('Net operating income', _money(totals['net_operating_income'])),
                _Stat('Outstanding debt', _money(totals['outstanding_debt'])),
              ],
            ),
            const SizedBox(height: AppSpacing.x24),
            Text('Properties', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppSpacing.x8),
            if (properties.isEmpty)
              Text('No properties in this portfolio yet.',
                  style: TextStyle(color: Theme.of(context).hintColor))
            else
              ...properties.map((e) => _PropCard(Map<String, dynamic>.from(e))),
          ],
        );
      },
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value);
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.x16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(value, style: t.titleLarge?.copyWith(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w700)),
            const SizedBox(height: AppSpacing.x4),
            Text(label, style: t.bodySmall?.copyWith(color: Theme.of(context).hintColor)),
          ],
        ),
      ),
    );
  }
}

class _PropCard extends StatelessWidget {
  const _PropCard(this.p);
  final Map<String, dynamic> p;
  @override
  Widget build(BuildContext context) {
    final yield_ = p['net_yield_pct'];
    final pid = '${p['property_id'] ?? ''}'.trim();
    final title = [
      p['building_name'] ?? p['community'],
      p['property_type'],
      if ('${p['unit_no'] ?? ''}'.trim().isNotEmpty) 'Unit ${p['unit_no']}',
    ].where((x) => x != null && '$x'.trim().isNotEmpty).join('  ·  ');
    return Card(
      child: ListTile(
        leading: const Icon(Icons.home_outlined),
        title: Row(children: [
          Expanded(child: Text(title.isEmpty ? 'Property' : title, overflow: TextOverflow.ellipsis)),
          _ownershipChip(context, '${p['ownership_status'] ?? ''}'),
        ]),
        subtitle: Text('Equity ${_money(p['equity'])}'),
        // Open the full property record hub (lease, mortgage, maintenance, docs, timeline).
        onTap: pid.isEmpty ? null : () => context.push('/property-record/$pid'),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          if (yield_ != null)
            Text('${(num.tryParse('$yield_') ?? 0).toStringAsFixed(1)}%',
                style: TextStyle(fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurface)),
          if (pid.isNotEmpty)
            const Padding(padding: EdgeInsets.only(left: 4), child: Icon(Icons.chevron_right, size: 18)),
        ]),
      ),
    );
  }

  /// Ownership-status pill — leads with the verified/unverified distinction so the
  /// asset's trust state is visible at a glance (Verify-ownership-first model).
  Widget _ownershipChip(BuildContext context, String status) {
    final (label, color) = switch (status) {
      'verified' => ('Verified', Colors.green),
      'pending' => ('Pending', Colors.orange),
      'rejected' => ('Rejected', Colors.red),
      _ => ('Unverified', Theme.of(context).hintColor),
    };
    return Container(
      margin: const EdgeInsets.only(left: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSpacing.rFull),
      ),
      child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 11)),
    );
  }
}
