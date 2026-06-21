import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/app_dialog.dart';
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

/// Agents the owner has assigned to market this property (owner module): the
/// owner manages the asset and DELEGATES marketing/publishing to these agents;
/// inquiries route to them. Backed by GET/POST/DELETE /properties/:id/agents.
final _propAgentsProvider =
    FutureProvider.autoDispose.family<List<Map<String, dynamic>>, String>((ref, id) async {
  try {
    return _asList(await ref.read(apiClientProvider).get('/properties/$id/agents'));
  } catch (_) {
    return [];
  }
});

/// Assigned-agents card — lists agents; the owner can assign (search) and remove.
class _AgentsCard extends ConsumerWidget {
  const _AgentsCard({required this.propertyId, required this.isOwner});
  final String propertyId;
  final bool isOwner;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final muted = dark ? AppColors.dTextMuted : AppColors.textMuted;
    final agents = ref.watch(_propAgentsProvider(propertyId));
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.x16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.handshake_outlined, size: 18, color: AppColors.primary),
            const SizedBox(width: AppSpacing.x8),
            Expanded(child: Text('Assigned agents', style: t.titleSmall)),
            if (isOwner)
              TextButton.icon(
                onPressed: () => _assign(context, ref),
                icon: const Icon(Icons.person_add_alt, size: 18),
                label: const Text('Assign'),
              ),
          ]),
          const SizedBox(height: AppSpacing.x4),
          agents.when(
            loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.x8), child: LinearProgressIndicator()),
            error: (e, _) => Text(friendlyError(e), style: t.bodySmall?.copyWith(color: muted)),
            data: (list) => list.isEmpty
                ? Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                        isOwner
                            ? 'No agents assigned yet. Assign an agent to market this property — they publish the listing and handle inquiries.'
                            : 'No agents assigned yet.',
                        style: t.bodySmall?.copyWith(color: muted)),
                  )
                : Column(
                    children: [
                      for (final a in list)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          leading: CircleAvatar(
                            radius: 18,
                            backgroundColor: AppColors.primaryTint,
                            backgroundImage:
                                '${a['avatar_url'] ?? ''}'.isNotEmpty ? NetworkImage('${a['avatar_url']}') : null,
                            child: '${a['avatar_url'] ?? ''}'.isEmpty
                                ? Text(
                                    '${a['full_name'] ?? '?'}'.isNotEmpty ? '${a['full_name']}'[0].toUpperCase() : '?',
                                    style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700))
                                : null,
                          ),
                          title: Text('${a['full_name'] ?? 'Agent'}'),
                          subtitle: Text('${a['role'] ?? a['user_role'] ?? 'agent'}'.replaceAll('_', ' ')),
                          trailing: isOwner
                              ? IconButton(
                                  icon: const Icon(Icons.close, size: 18),
                                  tooltip: 'Remove',
                                  onPressed: () =>
                                      _revoke(context, ref, '${a['agent_id']}', '${a['full_name'] ?? 'this agent'}'),
                                )
                              : null,
                          onTap: a['agent_id'] != null ? () => context.push('/u/${a['agent_id']}') : null,
                        ),
                    ],
                  ),
          ),
        ]),
      ),
    );
  }

  Future<void> _assign(BuildContext context, WidgetRef ref) async {
    final picked = await _searchAgent(context, ref);
    if (picked == null) return;
    try {
      await ref.read(apiClientProvider).post('/properties/$propertyId/agents', body: {'agent_id': picked['id']});
      ref.invalidate(_propAgentsProvider(propertyId));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Assigned ${picked['full_name'] ?? 'agent'} — inquiries will route to them.')));
      }
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
    }
  }

  Future<void> _revoke(BuildContext context, WidgetRef ref, String agentId, String name) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove agent'),
        content: Text('Remove $name from this property? Their access and inquiry routing stop.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Remove')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(apiClientProvider).delete('/properties/$propertyId/agents/$agentId');
      ref.invalidate(_propAgentsProvider(propertyId));
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
    }
  }
}

/// Search the user directory for an agent to assign (GET /users/search).
Future<Map<String, dynamic>?> _searchAgent(BuildContext context, WidgetRef ref) {
  final search = TextEditingController();
  var results = <Map<String, dynamic>>[];
  return showDialog<Map<String, dynamic>>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setS) {
        Future<void> run(String q) async {
          if (q.trim().length < 2) {
            setS(() => results = []);
            return;
          }
          try {
            final r = await ref.read(apiClientProvider).get('/users/search', query: {'q': q.trim()});
            setS(() => results = (r as List).map((e) => Map<String, dynamic>.from(e as Map)).toList());
          } catch (_) {
            setS(() => results = []);
          }
        }

        return AlertDialog(
          title: const Text('Assign an agent'),
          content: SizedBox(
            width: MediaQuery.sizeOf(ctx).width - 80 < 380 ? MediaQuery.sizeOf(ctx).width - 80 : 380,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(
                controller: search,
                autofocus: true,
                decoration: const InputDecoration(hintText: 'Search agent by name…', prefixIcon: Icon(Icons.search)),
                onChanged: run,
              ),
              const SizedBox(height: AppSpacing.x8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 280),
                child: results.isEmpty
                    ? const Padding(padding: EdgeInsets.all(16), child: Text('Type at least 2 letters to search'))
                    : ListView(
                        shrinkWrap: true,
                        children: [
                          for (final u in results)
                            ListTile(
                              dense: true,
                              leading: CircleAvatar(
                                radius: 16,
                                backgroundColor: AppColors.primaryTint,
                                backgroundImage:
                                    '${u['avatar_url'] ?? ''}'.isNotEmpty ? NetworkImage('${u['avatar_url']}') : null,
                                child: '${u['avatar_url'] ?? ''}'.isEmpty
                                    ? Text(
                                        '${u['full_name'] ?? '?'}'.isNotEmpty ? '${u['full_name']}'[0].toUpperCase() : '?',
                                        style: const TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w700))
                                    : null,
                              ),
                              title: Text('${u['full_name'] ?? 'User'}'),
                              subtitle: u['role'] != null ? Text('${u['role']}'.replaceAll('_', ' ')) : null,
                              onTap: () => Navigator.pop(ctx, Map<String, dynamic>.from(u)),
                            ),
                        ],
                      ),
              ),
            ]),
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))],
        );
      },
    ),
  );
}

/// Marketing status (derived from listing + tenancy) + performance counters
/// (views/leads/viewings/offers) — owner module §3.
class _MarketingPerformanceCard extends StatelessWidget {
  const _MarketingPerformanceCard({required this.p});
  final Map<String, dynamic> p;

  (String, Color) _status(Map? listing, Map? tenancy) {
    if (tenancy != null && tenancy['id'] != null) return ('Leased', AppColors.statusReserved);
    if (listing != null && listing['id'] != null) {
      if (listing['is_visible'] != true) return ('Draft · off-market', AppColors.statusSold);
      final rent = '${listing['purpose']}' == 'rent';
      return (rent ? 'For rent' : 'For sale', AppColors.statusAvailable);
    }
    return ('Off-market', AppColors.statusSold);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final muted = dark ? AppColors.dTextMuted : AppColors.textMuted;
    final listing = p['listing'] is Map ? Map<String, dynamic>.from(p['listing'] as Map) : null;
    final tenancy = p['tenancy'] is Map ? Map<String, dynamic>.from(p['tenancy'] as Map) : null;
    final perf = p['performance'] is Map ? Map<String, dynamic>.from(p['performance'] as Map) : const {};
    int n(String k) => int.tryParse('${perf[k] ?? 0}') ?? 0;
    final (label, color) = _status(listing, tenancy);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.x16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text('Marketing & performance', style: t.titleSmall)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(AppSpacing.rFull)),
              child: Text(label, style: t.labelMedium?.copyWith(color: color, fontWeight: FontWeight.w700)),
            ),
          ]),
          const SizedBox(height: AppSpacing.x12),
          Row(children: [
            _metric(context, muted, 'Viewings', '${n('viewings')}', Icons.event_available_outlined),
            _metric(context, muted, 'Offers', '${n('offers')}', Icons.local_offer_outlined),
            _metric(context, muted, 'Leads', '${n('leads')}', Icons.people_outline),
          ]),
        ]),
      ),
    );
  }

  Widget _metric(BuildContext context, Color muted, String label, String value, IconData icon) {
    final t = Theme.of(context).textTheme;
    return Expanded(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 18, color: muted),
        const SizedBox(height: 4),
        Text(value, style: t.titleLarge),
        Text(label, style: t.bodySmall?.copyWith(color: muted)),
      ]),
    );
  }
}

/// One-click publish (owner spec §10): the owner turns the property RECORD into a
/// public listing handed to one of its assigned agents — no duplicate data entry.
/// The agent then adds a permit + photos and takes it live.
class _PublishCard extends ConsumerWidget {
  const _PublishCard({required this.propertyId, required this.p});
  final String propertyId;
  final Map<String, dynamic> p;

  Future<void> _publish(BuildContext context, WidgetRef ref, List<Map<String, dynamic>> agents) async {
    final price = TextEditingController();
    var purpose = 'sale';
    var agentId = '${agents.first['agent_id']}';
    final ok = await AppDialog.show<bool>(
      context,
      title: 'Publish property',
      children: [
        StatefulBuilder(
          builder: (ctx, setS) => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            DropdownButtonFormField<String>(
              initialValue: purpose,
              decoration: const InputDecoration(labelText: 'Publish for'),
              items: const [
                DropdownMenuItem(value: 'sale', child: Text('Sale')),
                DropdownMenuItem(value: 'rent', child: Text('Rent')),
              ],
              onChanged: (v) => setS(() => purpose = v ?? 'sale'),
            ),
            const SizedBox(height: AppSpacing.x8),
            TextField(
              controller: price,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Asking price (AED)'),
            ),
            const SizedBox(height: AppSpacing.x8),
            DropdownButtonFormField<String>(
              initialValue: agentId,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Marketing agent'),
              items: [
                for (final a in agents)
                  DropdownMenuItem(value: '${a['agent_id']}', child: Text('${a['full_name'] ?? 'Agent'}')),
              ],
              onChanged: (v) => setS(() => agentId = v ?? agentId),
            ),
            const SizedBox(height: AppSpacing.x12),
            Text(
              'A draft listing is created from this property and handed to your agent, who adds the '
              'permit + photos and takes it live. No re-entering details.',
              style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                  color: Theme.of(ctx).brightness == Brightness.dark ? AppColors.dTextMuted : AppColors.textMuted),
            ),
          ]),
        ),
      ],
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            if ((double.tryParse(price.text.trim()) ?? 0) <= 0) {
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(const SnackBar(content: Text('Enter an asking price.')));
              return;
            }
            Navigator.pop(context, true);
          },
          child: const Text('Create listing'),
        ),
      ],
    );
    if (ok != true) return;
    try {
      await ref.read(apiClientProvider).post('/listings/from-property/$propertyId', body: {
        'purpose': purpose,
        'price': double.tryParse(price.text.trim()),
        'agent_id': agentId,
      });
      ref.invalidate(propertyRecordProvider(propertyId));
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Listing created — sent to your agent to publish.')));
      }
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (p['is_owner'] != true) return const SizedBox.shrink();
    final t = Theme.of(context).textTheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final muted = dark ? AppColors.dTextMuted : AppColors.textMuted;
    final listing = p['listing'] is Map ? Map<String, dynamic>.from(p['listing'] as Map) : null;
    final live = listing != null && listing['is_visible'] == true;
    final agents = ref.watch(_propAgentsProvider(propertyId));
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.x16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.campaign_outlined, size: 18, color: AppColors.primary),
            const SizedBox(width: AppSpacing.x8),
            Expanded(child: Text('Publish to the marketplace', style: t.titleSmall)),
          ]),
          const SizedBox(height: AppSpacing.x8),
          if (live)
            Text('This property is published. Manage it from “View public listing” below.',
                style: t.bodySmall?.copyWith(color: muted))
          else
            agents.when(
              loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: AppSpacing.x8), child: LinearProgressIndicator()),
              error: (e, _) => Text(friendlyError(e), style: t.bodySmall?.copyWith(color: muted)),
              data: (list) => list.isEmpty
                  ? Text('Assign an agent above first — they market and publish this property for you.',
                      style: t.bodySmall?.copyWith(color: muted))
                  : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(
                        listing != null
                            ? 'A draft listing exists. Publish for sale or rent — your agent finishes and takes it live.'
                            : 'Create a listing from this property and hand it to your assigned agent.',
                        style: t.bodySmall?.copyWith(color: muted),
                      ),
                      const SizedBox(height: AppSpacing.x12),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: () => _publish(context, ref, list),
                          icon: const Icon(Icons.publish_outlined, size: 18),
                          label: const Text('Publish property'),
                        ),
                      ),
                    ]),
            ),
        ]),
      ),
    );
  }
}

/// Property Verification Score (owner spec §18) — 0-100 trust score with an
/// itemised checklist; >=70 shows the Verified badge. The server computes the
/// score from signals that already exist (deed, owner, mortgage, photos, agent,
/// listing, lease, documents) so it stays a single source of truth.
class _VerificationCard extends StatelessWidget {
  const _VerificationCard({required this.p});
  final Map<String, dynamic> p;

  static const _labels = <String, String>{
    'title_deed': 'Title deed',
    'owner_verified': 'Owner verified',
    'mortgage': 'Mortgage',
    'photos': 'Photos',
    'agent': 'Agent assigned',
    'listing_published': 'Listing published',
    'lease': 'Lease',
    'documents': 'Documents',
  };

  @override
  Widget build(BuildContext context) {
    final v = p['verification'] is Map ? Map<String, dynamic>.from(p['verification'] as Map) : null;
    if (v == null) return const SizedBox.shrink();
    final t = Theme.of(context).textTheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final muted = dark ? AppColors.dTextMuted : AppColors.textMuted;
    final score = int.tryParse('${v['score'] ?? 0}') ?? 0;
    final verified = v['verified'] == true;
    final items = v['items'] is Map ? Map<String, dynamic>.from(v['items'] as Map) : const {};
    final color = verified ? AppColors.success : (score >= 40 ? AppColors.warning : muted);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.x16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.verified_user_outlined, size: 18, color: AppColors.primary),
            const SizedBox(width: AppSpacing.x8),
            Expanded(child: Text('Verification', style: t.titleSmall)),
            if (verified)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppSpacing.rFull)),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.verified, size: 14, color: AppColors.success),
                  SizedBox(width: 4),
                  Text('Verified', style: TextStyle(color: AppColors.success, fontWeight: FontWeight.w700, fontSize: 12)),
                ]),
              ),
          ]),
          const SizedBox(height: AppSpacing.x8),
          Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
            Text('$score', style: t.headlineMedium?.copyWith(color: color, fontWeight: FontWeight.w800)),
            Text(' / 100', style: t.bodyMedium?.copyWith(color: muted)),
          ]),
          const SizedBox(height: AppSpacing.x4),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppSpacing.rFull),
            child: LinearProgressIndicator(
                value: (score / 100).clamp(0, 1), minHeight: 6, color: color, backgroundColor: muted.withValues(alpha: 0.15)),
          ),
          const SizedBox(height: AppSpacing.x12),
          Wrap(spacing: AppSpacing.x12, runSpacing: AppSpacing.x8, children: [
            for (final e in _labels.entries)
              Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(items[e.key] == true ? Icons.check_circle : Icons.radio_button_unchecked,
                    size: 16, color: items[e.key] == true ? AppColors.success : muted),
                const SizedBox(width: 4),
                Text(e.value, style: t.bodySmall?.copyWith(color: items[e.key] == true ? null : muted)),
              ]),
          ]),
        ]),
      ),
    );
  }
}

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
              ref.invalidate(_propAgentsProvider(propertyId));
            },
            child: ResponsiveCenter(
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.x16),
                children: [
                  _Header(p: p),
                  const SizedBox(height: AppSpacing.x16),
                  _VerificationCard(p: p),
                  const SizedBox(height: AppSpacing.x12),
                  _AgentsCard(propertyId: propertyId, isOwner: p['is_owner'] == true),
                  const SizedBox(height: AppSpacing.x12),
                  _MarketingPerformanceCard(p: p),
                  if (p['is_owner'] == true) ...[
                    const SizedBox(height: AppSpacing.x12),
                    _PublishCard(propertyId: propertyId, p: p),
                  ],
                  const SizedBox(height: AppSpacing.x12),
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
