import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/network/api_client.dart';
import '../../core/network/upload_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/app_dialog.dart';
import '../../core/widgets/responsive.dart';
import '../marketplace/orders_repository.dart' show propertyServicesProvider, orderStatusLabels;

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
    final salePrice = TextEditingController();
    final rentPrice = TextEditingController();
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
                DropdownMenuItem(value: 'both', child: Text('Sale & Rent')),
              ],
              onChanged: (v) => setS(() => purpose = v ?? 'sale'),
            ),
            if (purpose == 'sale' || purpose == 'both') ...[
              const SizedBox(height: AppSpacing.x8),
              TextField(
                controller: salePrice,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Sale price (AED)'),
              ),
            ],
            if (purpose == 'rent' || purpose == 'both') ...[
              const SizedBox(height: AppSpacing.x8),
              TextField(
                controller: rentPrice,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Annual rent (AED)'),
              ),
            ],
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
            final needSale = purpose == 'sale' || purpose == 'both';
            final needRent = purpose == 'rent' || purpose == 'both';
            final saleOk = !needSale || (double.tryParse(salePrice.text.trim()) ?? 0) > 0;
            final rentOk = !needRent || (double.tryParse(rentPrice.text.trim()) ?? 0) > 0;
            if (!saleOk || !rentOk) {
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(const SnackBar(content: Text('Enter a valid price for each selected type.')));
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
        if (purpose == 'sale' || purpose == 'both') 'sale_price': double.tryParse(salePrice.text.trim()),
        if (purpose == 'rent' || purpose == 'both') 'rent_price': double.tryParse(rentPrice.text.trim()),
        'agent_id': agentId,
      });
      ref.invalidate(propertyRecordProvider(propertyId));
      if (context.mounted) {
        final msg = purpose == 'both'
            ? 'Sale + rent listings created — sent to your agent to publish.'
            : 'Listing created — sent to your agent to publish.';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
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

/// Property photo gallery on the ASSET (owner deed model Step 6) — persists
/// across listings. Owner can add (upload), delete and set a cover (first photo).
class _GalleryCard extends ConsumerWidget {
  const _GalleryCard({required this.propertyId, required this.p, required this.isOwner});
  final String propertyId;
  final Map<String, dynamic> p;
  final bool isOwner;

  List<String> get _photos =>
      (p['photos'] is List) ? (p['photos'] as List).map((e) => '$e').where((e) => e.isNotEmpty).toList() : [];

  Future<void> _save(BuildContext context, WidgetRef ref, List<String> photos) async {
    try {
      await ref.read(apiClientProvider).patch('/properties/$propertyId', body: {'photos': photos});
      ref.invalidate(propertyRecordProvider(propertyId));
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
    }
  }

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final result = await FilePicker.platform.pickFiles(
        type: FileType.custom, allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp'], withData: true);
    if (result == null || result.files.isEmpty) return;
    final f = result.files.first;
    final bytes = f.bytes;
    if (bytes == null) return;
    final ext = (f.extension ?? '').toLowerCase();
    final ct = ext == 'png' ? 'image/png' : ext == 'webp' ? 'image/webp' : 'image/jpeg';
    try {
      final url = await ref.read(uploadServiceProvider).upload(bytes, f.name, ct);
      if (url == null) return;
      if (context.mounted) await _save(context, ref, [..._photos, url]);
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload failed: ${friendlyError(e)}')));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final muted = dark ? AppColors.dTextMuted : AppColors.textMuted;
    final photos = _photos;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.x16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.photo_library_outlined, size: 18, color: AppColors.primary),
            const SizedBox(width: AppSpacing.x8),
            Expanded(child: Text('Photos', style: t.titleSmall)),
            if (photos.isNotEmpty) Text('${photos.length}', style: t.bodySmall?.copyWith(color: muted)),
            if (isOwner)
              TextButton.icon(onPressed: () => _add(context, ref), icon: const Icon(Icons.add_a_photo_outlined, size: 18), label: const Text('Add')),
          ]),
          const SizedBox(height: AppSpacing.x8),
          if (photos.isEmpty)
            Text(isOwner ? 'No photos yet. Add photos of this property — they stay on the asset across listings.' : 'No photos yet.',
                style: t.bodySmall?.copyWith(color: muted))
          else
            Wrap(spacing: AppSpacing.x8, runSpacing: AppSpacing.x8, children: [
              for (var i = 0; i < photos.length; i++)
                _Thumb(
                  url: photos[i],
                  isCover: i == 0,
                  isOwner: isOwner,
                  onCover: i == 0 ? null : () => _save(context, ref, [photos[i], ...photos.where((u) => u != photos[i])]),
                  onDelete: () => _save(context, ref, photos.where((u) => u != photos[i]).toList()),
                ),
            ]),
        ]),
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({required this.url, required this.isCover, required this.isOwner, this.onCover, this.onDelete});
  final String url;
  final bool isCover, isOwner;
  final VoidCallback? onCover, onDelete;
  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(AppSpacing.rSm),
        child: Image.network(url, width: 96, height: 96, fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(width: 96, height: 96, color: AppColors.surface2, child: const Icon(Icons.broken_image_outlined))),
      ),
      if (isCover)
        Positioned(
          left: 4, top: 4,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(AppSpacing.rFull)),
            child: const Text('Cover', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
          ),
        ),
      if (isOwner)
        Positioned(
          right: 0, top: 0,
          child: InkWell(
            onTap: onDelete,
            child: Container(
              margin: const EdgeInsets.all(2),
              decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
              child: const Icon(Icons.close, size: 16, color: Colors.white),
            ),
          ),
        ),
      if (isOwner && onCover != null)
        Positioned(
          right: 2, bottom: 2,
          child: InkWell(
            onTap: onCover,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(AppSpacing.rFull)),
              child: const Text('Set cover', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w600)),
            ),
          ),
        ),
    ]);
  }
}

/// "Complete your property" details card (owner deed model Step 6) — description,
/// market value, service charge, furnishing, amenities, with an owner editor.
class _DetailsCard extends ConsumerWidget {
  const _DetailsCard({required this.propertyId, required this.p, required this.isOwner});
  final String propertyId;
  final Map<String, dynamic> p;
  final bool isOwner;

  Future<void> _edit(BuildContext context, WidgetRef ref) async {
    final desc = TextEditingController(text: '${p['description'] ?? ''}');
    final beds = TextEditingController(text: '${p['bedrooms'] ?? ''}');
    final baths = TextEditingController(text: '${p['bathrooms'] ?? ''}');
    final size = TextEditingController(text: '${p['size_sqft'] ?? ''}');
    final svc = TextEditingController(text: '${p['service_charge'] ?? ''}');
    final price = TextEditingController(text: '${p['purchase_price'] ?? ''}');
    final value = TextEditingController(text: '${p['current_value'] ?? ''}');
    final amen = TextEditingController(
        text: (p['amenities'] is List) ? (p['amenities'] as List).join(', ') : '');
    var furn = '${p['furnishing'] ?? ''}'.isEmpty ? 'unfurnished' : '${p['furnishing']}';
    const furnOpts = ['unfurnished', 'semi_furnished', 'furnished'];
    if (!furnOpts.contains(furn)) furn = 'unfurnished';
    final ok = await AppDialog.show<bool>(
      context,
      title: 'Edit property details',
      children: [
        StatefulBuilder(
          builder: (ctx, setS) => Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: desc, minLines: 2, maxLines: 4, decoration: const InputDecoration(labelText: 'Description')),
            const SizedBox(height: AppSpacing.x8),
            Row(children: [
              Expanded(child: TextField(controller: beds, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Beds'))),
              const SizedBox(width: AppSpacing.x8),
              Expanded(child: TextField(controller: baths, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Baths'))),
              const SizedBox(width: AppSpacing.x8),
              Expanded(child: TextField(controller: size, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Size (sqft)'))),
            ]),
            const SizedBox(height: AppSpacing.x8),
            DropdownButtonFormField<String>(
              initialValue: furn,
              decoration: const InputDecoration(labelText: 'Furnishing'),
              items: const [
                DropdownMenuItem(value: 'unfurnished', child: Text('Unfurnished')),
                DropdownMenuItem(value: 'semi_furnished', child: Text('Semi-furnished')),
                DropdownMenuItem(value: 'furnished', child: Text('Furnished')),
              ],
              onChanged: (v) => setS(() => furn = v ?? 'unfurnished'),
            ),
            const SizedBox(height: AppSpacing.x8),
            TextField(controller: svc, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Service charge (AED / sqft / yr)')),
            const SizedBox(height: AppSpacing.x8),
            Row(children: [
              Expanded(child: TextField(controller: price, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Purchase price'))),
              const SizedBox(width: AppSpacing.x8),
              Expanded(child: TextField(controller: value, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Current value'))),
            ]),
            const SizedBox(height: AppSpacing.x8),
            TextField(controller: amen, decoration: const InputDecoration(labelText: 'Amenities', hintText: 'Pool, Gym, Parking …')),
          ]),
        ),
      ],
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save')),
      ],
    );
    if (ok != true) return;
    final amenList = amen.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    try {
      await ref.read(apiClientProvider).patch('/properties/$propertyId', body: {
        'description': desc.text.trim(),
        'bedrooms': int.tryParse(beds.text.trim()),
        'bathrooms': int.tryParse(baths.text.trim()),
        'size_sqft': double.tryParse(size.text.trim()),
        'furnishing': furn,
        'service_charge': double.tryParse(svc.text.trim()),
        'purchase_price': double.tryParse(price.text.trim()),
        'current_value': double.tryParse(value.text.trim()),
        'amenities': amenList,
      });
      ref.invalidate(propertyRecordProvider(propertyId));
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Property details saved.')));
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final muted = dark ? AppColors.dTextMuted : AppColors.textMuted;
    final aed = NumberFormat.compactCurrency(symbol: 'AED ', decimalDigits: 0);
    final desc = '${p['description'] ?? ''}'.trim();
    final value = num.tryParse('${p['current_value'] ?? ''}');
    final svc = num.tryParse('${p['service_charge'] ?? ''}');
    final furn = '${p['furnishing'] ?? ''}'.replaceAll('_', ' ').trim();
    final amenities = (p['amenities'] is List) ? (p['amenities'] as List).map((e) => '$e').toList() : <String>[];
    final incomplete = desc.isEmpty && value == null && amenities.isEmpty;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.x16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.tune, size: 18, color: AppColors.primary),
            const SizedBox(width: AppSpacing.x8),
            Expanded(child: Text('Details', style: t.titleSmall)),
            if (isOwner)
              TextButton.icon(
                onPressed: () => _edit(context, ref),
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: Text(incomplete ? 'Complete' : 'Edit'),
              ),
          ]),
          const SizedBox(height: AppSpacing.x4),
          if (desc.isNotEmpty) ...[
            Text(desc, style: t.bodyMedium),
            const SizedBox(height: AppSpacing.x12),
          ],
          Wrap(spacing: AppSpacing.x16, runSpacing: AppSpacing.x8, children: [
            if (value != null) _fact(context, muted, 'Market value', aed.format(value)),
            if (svc != null) _fact(context, muted, 'Service charge', '${aed.format(svc)}/sqft'),
            if (furn.isNotEmpty) _fact(context, muted, 'Furnishing', furn[0].toUpperCase() + furn.substring(1)),
          ]),
          if (amenities.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.x12),
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final a in amenities)
                Chip(label: Text(a), visualDensity: VisualDensity.compact, materialTapTargetSize: MaterialTapTargetSize.shrinkWrap),
            ]),
          ],
          if (incomplete && !isOwner) Text('No details added yet.', style: t.bodySmall?.copyWith(color: muted)),
        ]),
      ),
    );
  }

  Widget _fact(BuildContext context, Color muted, String label, String value) {
    final t = Theme.of(context).textTheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      Text(label, style: t.bodySmall?.copyWith(color: muted)),
      Text(value, style: t.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
    ]);
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
                  _GalleryCard(propertyId: propertyId, p: p, isOwner: p['is_owner'] == true),
                  const SizedBox(height: AppSpacing.x12),
                  _DetailsCard(propertyId: propertyId, p: p, isOwner: p['is_owner'] == true),
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
                  _MortgageCard(propertyId: propertyId, isOwner: p['is_owner'] == true),
                  const SizedBox(height: AppSpacing.x12),
                  _MaintenanceCard(propertyId: propertyId),
                  const SizedBox(height: AppSpacing.x12),
                  _ServiceHistoryCard(propertyId: propertyId),
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
          // Asset lifecycle (owner deed model Step 5): Draft until a listing goes
          // live; then Live / Leased. Derived from the listing + tenancy state.
          Builder(builder: (_) {
            final (lc, lcColor) = tenancy != null && tenancy['id'] != null
                ? ('Leased', AppColors.statusReserved)
                : (listing != null && listing['is_visible'] == true)
                    ? ('Live', AppColors.success)
                    : (listing != null)
                        ? ('Draft listing', AppColors.warning)
                        : ('Draft', muted);
            return Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                      color: lcColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(AppSpacing.rFull)),
                  child: Text(lc, style: t.labelSmall?.copyWith(color: lcColor, fontWeight: FontWeight.w700)),
                ),
              ),
            );
          }),
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

/// Property-centric mortgage dashboard (mortgage redesign): mortgage is a
/// sub-module OF this property — the workspace header carries the property ref.
/// Shows status + summary (bank · outstanding · monthly · rate · maturity ·
/// progress); the owner adds a property-bound mortgage or marks it complete.
/// No navigation to a standalone mortgage list.
class _MortgageCard extends ConsumerWidget {
  const _MortgageCard({required this.propertyId, required this.isOwner});
  final String propertyId;
  final bool isOwner;

  (String, Color) _status(String s, bool has) {
    if (!has) return ('No mortgage', AppColors.textMuted);
    switch (s) {
      case 'settled': return ('Fully paid', AppColors.success);
      case 'refinanced': return ('Refinanced', AppColors.warning);
      default: return ('Active', AppColors.primary);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final muted = dark ? AppColors.dTextMuted : AppColors.textMuted;
    final aed = NumberFormat.currency(symbol: 'AED ', decimalDigits: 0);
    final df = DateFormat('d MMM yyyy');
    final m = ref.watch(_propMortgagesProvider(propertyId));
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.x16),
        child: m.when(
          loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.x8), child: LinearProgressIndicator()),
          error: (e, _) => Row(children: [
            const Icon(Icons.account_balance_outlined, size: 18, color: AppColors.primary),
            const SizedBox(width: AppSpacing.x8),
            Expanded(child: Text('Mortgage', style: t.titleSmall)),
          ]),
          data: (list) {
            final has = list.isNotEmpty;
            final first = has ? Map<String, dynamic>.from(list.first) : const <String, dynamic>{};
            final status = '${first['status'] ?? 'active'}';
            final (label, color) = _status(status, has);
            final lender = '${first['lender'] ?? ''}'.trim();
            final outstanding = num.tryParse('${first['outstanding'] ?? ''}');
            final monthly = num.tryParse('${first['monthly_payment'] ?? ''}');
            final rate = num.tryParse('${first['interest_rate'] ?? ''}');
            final progress = num.tryParse('${first['progress_pct'] ?? ''}') ?? 0;
            final term = int.tryParse('${first['term_months'] ?? ''}');
            final mortgageId = '${first['id'] ?? ''}';
            final active = has && status != 'settled';
            DateTime? start;
            if (first['start_date'] != null) start = DateTime.tryParse('${first['start_date']}');
            final maturity = (start != null && term != null && term > 0)
                ? DateTime(start.year, start.month + term, start.day)
                : null;

            return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Icon(Icons.account_balance_outlined, size: 18, color: AppColors.primary),
                const SizedBox(width: AppSpacing.x8),
                Expanded(child: Text('Mortgage', style: t.titleSmall?.copyWith(fontWeight: FontWeight.w700))),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(AppSpacing.rFull)),
                  child: Text(label, style: t.labelMedium?.copyWith(color: color, fontWeight: FontWeight.w700)),
                ),
              ]),
              const SizedBox(height: AppSpacing.x8),
              if (!has)
                Text(
                    isOwner
                        ? 'No mortgage on this property. Add one to track payments, payoff and equity.'
                        : 'No mortgage tracked on this property.',
                    style: t.bodySmall?.copyWith(color: muted))
              else ...[
                if (outstanding != null)
                  Text('${aed.format(outstanding)} outstanding',
                      style: t.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.primary)),
                const SizedBox(height: AppSpacing.x8),
                Wrap(spacing: AppSpacing.x16, runSpacing: AppSpacing.x8, children: [
                  if (lender.isNotEmpty) _fact(context, muted, 'Bank', lender),
                  if (monthly != null) _fact(context, muted, 'Monthly', aed.format(monthly)),
                  if (rate != null) _fact(context, muted, 'Rate', '${rate.toStringAsFixed(2)}%'),
                  if (maturity != null) _fact(context, muted, 'Maturity', df.format(maturity)),
                ]),
                const SizedBox(height: AppSpacing.x12),
                Row(children: [
                  Text('Paid off', style: t.bodySmall?.copyWith(color: muted)),
                  const Spacer(),
                  Text('${progress.toStringAsFixed(0)}%', style: t.bodySmall?.copyWith(fontWeight: FontWeight.w700)),
                ]),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppSpacing.rFull),
                  child: LinearProgressIndicator(
                      value: (progress / 100).clamp(0, 1).toDouble(),
                      minHeight: 6, color: color, backgroundColor: muted.withValues(alpha: 0.15)),
                ),
              ],
              const SizedBox(height: AppSpacing.x12),
              if (!has && isOwner)
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => _add(context, ref),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add mortgage'),
                  ),
                )
              else if (has)
                Wrap(spacing: AppSpacing.x8, runSpacing: AppSpacing.x8, children: [
                  OutlinedButton.icon(
                    onPressed: mortgageId.isEmpty ? null : () => context.push('/mortgages/$mortgageId'),
                    icon: const Icon(Icons.timeline_outlined, size: 18),
                    label: const Text('Payments & schedule'),
                  ),
                  if (active && isOwner)
                    FilledButton.icon(
                      onPressed: () => _complete(context, ref, mortgageId),
                      icon: const Icon(Icons.task_alt, size: 18),
                      label: const Text('Mark complete'),
                    ),
                ]),
            ]);
          },
        ),
      ),
    );
  }

  Widget _fact(BuildContext context, Color muted, String label, String value) {
    final t = Theme.of(context).textTheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      Text(label, style: t.bodySmall?.copyWith(color: muted)),
      Text(value, style: t.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
    ]);
  }

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final lender = TextEditingController();
    final principal = TextEditingController();
    final rate = TextEditingController();
    final term = TextEditingController();
    DateTime? start;
    final ok = await AppDialog.show<bool>(
      context,
      title: 'Add mortgage',
      children: [
        StatefulBuilder(
          builder: (ctx, setS) => Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: lender, decoration: const InputDecoration(labelText: 'Bank / lender')),
            const SizedBox(height: AppSpacing.x8),
            TextField(controller: principal, keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Original amount (AED)')),
            const SizedBox(height: AppSpacing.x8),
            Row(children: [
              Expanded(child: TextField(controller: rate, keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Interest rate %'))),
              const SizedBox(width: AppSpacing.x8),
              Expanded(child: TextField(controller: term, keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Term (months)'))),
            ]),
            const SizedBox(height: AppSpacing.x8),
            InkWell(
              onTap: () async {
                final d = await showDatePicker(
                    context: ctx, initialDate: start ?? DateTime(2022),
                    firstDate: DateTime(1990), lastDate: DateTime(2100));
                if (d != null) setS(() => start = d);
              },
              child: InputDecorator(
                decoration: const InputDecoration(labelText: 'Start date', suffixIcon: Icon(Icons.calendar_today, size: 18)),
                child: Text(start == null ? 'Select date' : DateFormat('d MMM yyyy').format(start!)),
              ),
            ),
          ]),
        ),
      ],
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            if ((double.tryParse(principal.text.trim()) ?? 0) <= 0) {
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(const SnackBar(content: Text('Enter the original mortgage amount.')));
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
      await ref.read(apiClientProvider).post('/mortgages', body: {
        'property_id': propertyId,
        'lender': lender.text.trim(),
        'principal': double.tryParse(principal.text.trim()),
        'interest_rate': double.tryParse(rate.text.trim()) ?? 0,
        'term_months': int.tryParse(term.text.trim()) ?? 300,
        if (start != null) 'start_date': start!.toIso8601String().split('T').first,
      });
      ref.invalidate(_propMortgagesProvider(propertyId));
      ref.invalidate(propertyRecordProvider(propertyId));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Mortgage added to this property.')));
      }
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
    }
  }

  Future<void> _complete(BuildContext context, WidgetRef ref, String mortgageId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Mark mortgage complete'),
        content: const Text(
            'This records the settlement, zeroes the outstanding balance and marks the property mortgage-free. Continue?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Mark complete')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(apiClientProvider).post('/mortgages/$mortgageId/complete', body: {'status': 'settled'});
      ref.invalidate(_propMortgagesProvider(propertyId));
      ref.invalidate(propertyRecordProvider(propertyId));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Mortgage settled — property is mortgage-free.')));
      }
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
    }
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

/// Marketplace services booked against this property (§9 service history).
class _ServiceHistoryCard extends ConsumerWidget {
  const _ServiceHistoryCard({required this.propertyId});
  final String propertyId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final muted = Theme.of(context).hintColor;
    final async = ref.watch(propertyServicesProvider(propertyId));
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.x16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.home_repair_service_outlined, size: 18),
            const SizedBox(width: AppSpacing.x8),
            Expanded(child: Text('Service history', style: t.titleSmall?.copyWith(fontWeight: FontWeight.w700))),
            TextButton.icon(
              onPressed: () => context.push('/marketplace'),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Book'),
            ),
          ]),
          const SizedBox(height: AppSpacing.x4),
          async.when(
            loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 8), child: LinearProgressIndicator()),
            error: (e, _) => Text(friendlyError(e), style: t.bodySmall?.copyWith(color: muted)),
            data: (list) => list.isEmpty
                ? Text('No services booked for this property yet. Book one from the marketplace.',
                    style: t.bodySmall?.copyWith(color: muted))
                : Column(children: [for (final raw in list) _row(context, raw)]),
          ),
        ]),
      ),
    );
  }

  Widget _row(BuildContext context, Map<String, dynamic> o) {
    final t = Theme.of(context).textTheme;
    final muted = Theme.of(context).hintColor;
    final title = '${o['title'] ?? 'Service'}';
    final status = '${o['status'] ?? ''}';
    final provider = '${o['provider_name'] ?? ''}'.trim();
    final sched = DateTime.tryParse('${o['scheduled_at'] ?? ''}');
    final sub = [
      if (provider.isNotEmpty) provider,
      if (sched != null) DateFormat('d MMM yyyy · h:mm a').format(sched),
    ].join('  ·  ');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: t.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            if (sub.isNotEmpty)
              Text(sub, style: t.bodySmall?.copyWith(color: muted), maxLines: 1, overflow: TextOverflow.ellipsis),
          ]),
        ),
        const SizedBox(width: AppSpacing.x8),
        Text(context.tr(orderStatusLabels[status] ?? status),
            style: t.labelSmall?.copyWith(color: AppColors.primary, fontWeight: FontWeight.w700)),
      ]),
    );
  }
}
