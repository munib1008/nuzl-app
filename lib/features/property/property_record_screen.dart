import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/responsive.dart';

/// The property record + linked lease / listing / participants. The hub for one
/// property — everything (lease, mortgage, maintenance, docs, timeline) hangs off
/// the permanent property record, matching the "everything revolves around the
/// property" model.
final propertyRecordProvider =
    FutureProvider.autoDispose.family<Map<String, dynamic>, String>((ref, id) async {
  final d = await ref.read(apiClientProvider).get('/properties/$id');
  return d is Map ? Map<String, dynamic>.from(d) : <String, dynamic>{};
});

List<Map<String, dynamic>> _asList(dynamic d) =>
    d is List ? d.map((e) => Map<String, dynamic>.from(e as Map)).toList() : <Map<String, dynamic>>[];

final _propMortgagesProvider =
    FutureProvider.autoDispose.family<List<Map<String, dynamic>>, String>((ref, id) async {
  try {
    return _asList(await ref.read(apiClientProvider).get('/mortgages/by-property/$id'));
  } catch (_) {
    return [];
  }
});

final _propTimelineProvider =
    FutureProvider.autoDispose.family<List<Map<String, dynamic>>, String>((ref, id) async {
  try {
    return _asList(await ref.read(apiClientProvider).get('/activity/timeline/$id'));
  } catch (_) {
    return [];
  }
});

final _propMaintenanceProvider =
    FutureProvider.autoDispose.family<List<Map<String, dynamic>>, String>((ref, id) async {
  try {
    final all = _asList(await ref.read(apiClientProvider).get('/maintenance/jobs', query: {'property_id': id}));
    // Defensively scope client-side in case the endpoint ignores the filter.
    final mine = all.where((m) => '${m['property_id'] ?? ''}' == id).toList();
    return mine.isNotEmpty ? mine : all;
  } catch (_) {
    return [];
  }
});

final _propDocsProvider =
    FutureProvider.autoDispose.family<List<Map<String, dynamic>>, String>((ref, id) async {
  try {
    return _asList(await ref.read(apiClientProvider).get('/properties/$id/documents'));
  } catch (_) {
    return [];
  }
});

class PropertyRecordScreen extends ConsumerWidget {
  const PropertyRecordScreen({super.key, required this.propertyId});
  final String propertyId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rec = ref.watch(propertyRecordProvider(propertyId));
    return Scaffold(
      appBar: AppBar(title: const Text('Property record')),
      body: rec.when(
        loading: () => const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator())),
        error: (e, _) => Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(friendlyError(e)))),
        data: (p) {
          if (p.isEmpty) {
            return const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('Property not found.')));
          }
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(propertyRecordProvider(propertyId));
              ref.invalidate(_propMortgagesProvider(propertyId));
              ref.invalidate(_propTimelineProvider(propertyId));
              ref.invalidate(_propMaintenanceProvider(propertyId));
              ref.invalidate(_propDocsProvider(propertyId));
            },
            child: ResponsiveCenter(
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.x16),
                children: [
                  _Header(p: p),
                  const SizedBox(height: AppSpacing.x16),
                  _LeaseCard(p: p),
                  const SizedBox(height: AppSpacing.x12),
                  _MortgageCard(propertyId: propertyId),
                  const SizedBox(height: AppSpacing.x12),
                  _MaintenanceCard(propertyId: propertyId),
                  const SizedBox(height: AppSpacing.x12),
                  _DocumentsCard(propertyId: propertyId),
                  const SizedBox(height: AppSpacing.x12),
                  _TimelineCard(propertyId: propertyId),
                  if (p['listing'] is Map && (p['listing'] as Map)['id'] != null) ...[
                    const SizedBox(height: AppSpacing.x16),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => context.push('/listings/${(p['listing'] as Map)['id']}'),
                        icon: const Icon(Icons.open_in_new, size: 18),
                        label: const Text('View public listing'),
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.x24),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.p});
  final Map<String, dynamic> p;
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final muted = dark ? AppColors.dTextMuted : AppColors.textMuted;
    final primary = Theme.of(context).colorScheme.primary;
    final ref = '${p['ref_code'] ?? ''}'.trim();
    final building = '${p['building_name'] ?? ''}'.trim();
    final unit = '${p['unit_no'] ?? ''}'.trim();
    final community = '${p['community'] ?? ''}'.trim();
    final ptype = '${p['property_type'] ?? ''}'.trim();
    final title = building.isNotEmpty
        ? (unit.isNotEmpty ? '$building · Unit $unit' : building)
        : (ptype.isNotEmpty ? _cap(ptype) : 'Property');
    final beds = '${p['bedrooms'] ?? '-'}';
    final baths = '${p['bathrooms'] ?? '-'}';
    final sqft = p['size_sqft'] != null ? '${(num.tryParse('${p['size_sqft']}') ?? 0).toStringAsFixed(0)} sqft' : null;
    final owner = '${p['owner_name'] ?? ''}'.trim();
    final tenancy = p['tenancy'] is Map ? Map<String, dynamic>.from(p['tenancy']) : null;
    final listing = p['listing'] is Map ? Map<String, dynamic>.from(p['listing']) : null;
    final agent = '${listing?['agent_name'] ?? ''}'.trim();
    final tenant = '${tenancy?['tenant_name'] ?? ''}'.trim();

    Widget chip(IconData i, String v) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(AppSpacing.rFull)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(i, size: 14, color: muted),
            const SizedBox(width: 4),
            Text(v, style: t.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
          ]),
        );
    Widget party(String role, String name, IconData i) => Row(children: [
          Icon(i, size: 15, color: muted),
          const SizedBox(width: 6),
          Text('$role  ', style: t.bodySmall?.copyWith(color: muted)),
          Expanded(
            child: Text(name.isEmpty ? '—' : name,
                style: t.bodySmall?.copyWith(fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
        ]);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.x16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Permanent property ID — the spine of the record.
          if (ref.isNotEmpty)
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                    color: primary.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(AppSpacing.rSm)),
                child: Text(ref, style: t.titleMedium?.copyWith(color: primary, fontWeight: FontWeight.w800, letterSpacing: 0.3)),
              ),
              IconButton(
                tooltip: 'Copy ID',
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.copy, size: 16),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: ref));
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Copied $ref')));
                },
              ),
            ]),
          const SizedBox(height: 4),
          Text(title, style: t.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          if (community.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Row(children: [
                Icon(Icons.place_outlined, size: 14, color: muted),
                const SizedBox(width: 4),
                Text(community, style: t.bodyMedium?.copyWith(color: muted)),
              ]),
            ),
          const SizedBox(height: AppSpacing.x12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            chip(Icons.bed_outlined, beds),
            chip(Icons.bathtub_outlined, baths),
            if (sqft != null) chip(Icons.straighten, sqft),
            if (ptype.isNotEmpty) chip(Icons.home_work_outlined, _cap(ptype)),
          ]),
          const Divider(height: AppSpacing.x24),
          party('Owner', owner, Icons.person_outline),
          const SizedBox(height: 6),
          party('Tenant', tenant.isEmpty ? 'Vacant' : tenant, Icons.key_outlined),
          if (agent.isNotEmpty) ...[
            const SizedBox(height: 6),
            party('Agent', agent, Icons.badge_outlined),
          ],
        ]),
      ),
    );
  }
}

/// Shared shell for a hub section: icon, title, optional "Open" deep-link, body.
class _Section extends StatelessWidget {
  const _Section({required this.icon, required this.title, required this.child, this.onOpen, this.openLabel = 'Open'});
  final IconData icon;
  final String title;
  final Widget child;
  final VoidCallback? onOpen;
  final String openLabel;
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final primary = Theme.of(context).colorScheme.primary;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.x16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(icon, size: 18, color: primary),
            const SizedBox(width: 8),
            Expanded(child: Text(title, style: t.titleSmall?.copyWith(fontWeight: FontWeight.w700))),
            if (onOpen != null)
              TextButton(
                onPressed: onOpen,
                style: TextButton.styleFrom(visualDensity: VisualDensity.compact, padding: const EdgeInsets.symmetric(horizontal: 8)),
                child: Text(openLabel),
              ),
          ]),
          const SizedBox(height: 6),
          child,
        ]),
      ),
    );
  }
}

Widget _emptyLine(BuildContext context, String s) {
  final dark = Theme.of(context).brightness == Brightness.dark;
  return Text(s, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: dark ? AppColors.dTextMuted : AppColors.textMuted));
}

class _LeaseCard extends StatelessWidget {
  const _LeaseCard({required this.p});
  final Map<String, dynamic> p;
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final tenancy = p['tenancy'] is Map ? Map<String, dynamic>.from(p['tenancy']) : null;
    final aed = NumberFormat.currency(symbol: 'AED ', decimalDigits: 0);
    final df = DateFormat('d MMM yyyy');
    DateTime? end;
    if (tenancy?['end_date'] != null) end = DateTime.tryParse('${tenancy!['end_date']}');
    final rent = num.tryParse('${tenancy?['rent_amount'] ?? ''}');
    final freq = '${tenancy?['payment_freq'] ?? 'annual'}';
    final status = '${tenancy?['status'] ?? ''}';
    return _Section(
      icon: Icons.receipt_long_outlined,
      title: 'Lease',
      onOpen: () => context.push('/rentals'),
      openLabel: tenancy != null ? 'Manage' : 'Add',
      child: tenancy == null
          ? _emptyLine(context, 'No active lease on this property.')
          : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (rent != null)
                Text('${aed.format(rent)} / ${freq == 'monthly' ? 'mo' : 'yr'}',
                    style: t.titleMedium?.copyWith(fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.primary)),
              const SizedBox(height: 2),
              _emptyLine(context, [
                if (status.isNotEmpty) _cap(status),
                if (end != null) 'ends ${df.format(end)}',
              ].join('  ·  ')),
            ]),
    );
  }
}

class _MortgageCard extends ConsumerWidget {
  const _MortgageCard({required this.propertyId});
  final String propertyId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final m = ref.watch(_propMortgagesProvider(propertyId));
    final aed = NumberFormat.currency(symbol: 'AED ', decimalDigits: 0);
    return _Section(
      icon: Icons.account_balance_outlined,
      title: 'Mortgage',
      onOpen: () => context.push('/mortgages'),
      openLabel: 'Track',
      child: m.when(
        loading: () => _emptyLine(context, 'Loading…'),
        error: (_, __) => _emptyLine(context, 'No mortgage tracked.'),
        data: (list) {
          if (list.isEmpty) return _emptyLine(context, 'No mortgage tracked on this property.');
          final first = list.first;
          final monthly = num.tryParse('${first['monthly_payment'] ?? ''}');
          final outstanding = num.tryParse('${first['outstanding'] ?? first['balance'] ?? ''}');
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (outstanding != null)
              Text('${aed.format(outstanding)} outstanding',
                  style: t.titleMedium?.copyWith(fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.primary)),
            if (monthly != null) _emptyLine(context, '${aed.format(monthly)} / mo'),
            if (list.length > 1) _emptyLine(context, '${list.length} finance records'),
          ]);
        },
      ),
    );
  }
}

class _MaintenanceCard extends ConsumerWidget {
  const _MaintenanceCard({required this.propertyId});
  final String propertyId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jobs = ref.watch(_propMaintenanceProvider(propertyId));
    return _Section(
      icon: Icons.build_outlined,
      title: 'Maintenance',
      onOpen: () => context.push('/maintenance'),
      child: jobs.when(
        loading: () => _emptyLine(context, 'Loading…'),
        error: (_, __) => _emptyLine(context, 'No maintenance history.'),
        data: (list) {
          if (list.isEmpty) return _emptyLine(context, 'No maintenance requests on this property.');
          final open = list.where((j) {
            final s = '${j['status'] ?? ''}'.toLowerCase();
            return s != 'completed' && s != 'cancelled' && s != 'closed' && s != 'done';
          }).length;
          return _emptyLine(context, '${list.length} request${list.length == 1 ? '' : 's'}'
              '${open > 0 ? '  ·  $open open' : ''}');
        },
      ),
    );
  }
}

class _DocumentsCard extends ConsumerWidget {
  const _DocumentsCard({required this.propertyId});
  final String propertyId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final docs = ref.watch(_propDocsProvider(propertyId));
    return _Section(
      icon: Icons.folder_outlined,
      title: 'Documents',
      child: docs.when(
        loading: () => _emptyLine(context, 'Loading…'),
        error: (_, __) => _emptyLine(context, 'No documents.'),
        data: (list) {
          if (list.isEmpty) return _emptyLine(context, 'No documents uploaded for this property.');
          return Wrap(spacing: 8, runSpacing: 8, children: [
            for (final d in list.take(8))
              ActionChip(
                avatar: const Icon(Icons.description_outlined, size: 15),
                label: Text('${d['label'] ?? d['doc_type'] ?? 'Document'}'),
                onPressed: () async {
                  final url = '${d['file_url'] ?? ''}'.trim();
                  if (url.isEmpty) return;
                  final uri = Uri.tryParse(url);
                  if (uri != null) await launchUrl(uri, mode: LaunchMode.externalApplication);
                },
              ),
            if (list.length > 8) Text('+${list.length - 8} more', style: t.bodySmall),
          ]);
        },
      ),
    );
  }
}

class _TimelineCard extends ConsumerWidget {
  const _TimelineCard({required this.propertyId});
  final String propertyId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final muted = dark ? AppColors.dTextMuted : AppColors.textMuted;
    final tl = ref.watch(_propTimelineProvider(propertyId));
    final df = DateFormat('d MMM yyyy');
    return _Section(
      icon: Icons.timeline_outlined,
      title: 'Timeline',
      child: tl.when(
        loading: () => _emptyLine(context, 'Loading…'),
        error: (_, __) => _emptyLine(context, 'No activity yet.'),
        data: (list) {
          if (list.isEmpty) return _emptyLine(context, 'No activity recorded yet.');
          return Column(children: [
            for (final e in list.take(6))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 5, right: 8),
                    child: Container(width: 7, height: 7,
                        decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary, shape: BoxShape.circle)),
                  ),
                  Expanded(
                    child: Text(_cap('${e['event'] ?? 'event'}'.replaceAll('_', ' ')),
                        style: t.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
                  ),
                  if (e['created_at'] != null)
                    Text(df.format(DateTime.tryParse('${e['created_at']}') ?? DateTime(2000)),
                        style: t.bodySmall?.copyWith(color: muted)),
                ]),
              ),
          ]);
        },
      ),
    );
  }
}

String _cap(String s) => s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';
