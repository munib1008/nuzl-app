import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/upload_service.dart';
import '../../../core/rbac/persona.dart';
import '../../../core/util/mortgage_math.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/detail_grid.dart';
import '../../../core/widgets/location_map.dart';
import '../../auth/application/auth_controller.dart';
import '../../messages/data/messaging_repository.dart';
import '../../saved/saved_screen.dart';
import '../../collaboration/collaboration_repository.dart';
import 'listing_ribbons.dart';

final _detailProvider = FutureProvider.autoDispose.family<Map<String, dynamic>, String>((ref, id) async {
  final d = await ref.read(apiClientProvider).get('/listings/$id');
  return d is Map ? Map<String, dynamic>.from(d) : <String, dynamic>{};
});

final _agentProvider = FutureProvider.autoDispose.family<Map<String, dynamic>, String>((ref, brokerId) async {
  try {
    final d = await ref.read(apiClientProvider).get('/public/users/$brokerId');
    return d is Map ? Map<String, dynamic>.from(d) : <String, dynamic>{};
  } catch (_) {
    return <String, dynamic>{};
  }
});

/// The current user's active viewing request for this listing (if any), so the
/// "Request viewing" button reflects the booking until the agent rejects it.
final _myViewingProvider = FutureProvider.autoDispose.family<Map<String, dynamic>?, String>((ref, listingId) async {
  try {
    final myId = ref.read(authControllerProvider).user?.id;
    final d = await ref.read(apiClientProvider).get('/viewings');
    if (d is List && myId != null) {
      for (final e in d) {
        final m = Map<String, dynamic>.from(e);
        final active = !['cancelled', 'completed'].contains('${m['status']}');
        if ('${m['listing_id']}' == listingId && '${m['requested_by']}' == myId && active) return m;
      }
    }
    return null;
  } catch (_) {
    return null;
  }
});

/// Property Listing 2.0 (phase 1): the property's living-asset history. Party-gated
/// on the server; the section only renders for property parties (viewer_can_docs).
final _timelineProvider = FutureProvider.autoDispose.family<List<Map<String, dynamic>>, String>((ref, propertyId) async {
  try {
    final d = await ref.read(apiClientProvider).get('/properties/$propertyId/timeline');
    return d is List ? d.map((e) => Map<String, dynamic>.from(e as Map)).toList() : <Map<String, dynamic>>[];
  } catch (_) {
    return <Map<String, dynamic>>[];
  }
});

class ListingDetailScreen extends ConsumerWidget {
  const ListingDetailScreen({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(_detailProvider(id));
    return Scaffold(
      appBar: AppBar(title: const Text('Listing'), actions: [SaveListingButton(listingId: id)]),
      body: detail.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(friendlyError(e)))),
        data: (l) => _Detail(id: id, l: l),
      ),
    );
  }
}

class _Detail extends ConsumerWidget {
  const _Detail({required this.id, required this.l});
  final String id;
  final Map<String, dynamic> l;

  List<String> get _images {
    final out = <String>[];
    final cover = '${l['cover_image'] ?? ''}';
    if (cover.isNotEmpty) out.add(cover);
    final im = l['images'];
    if (im is List) out.addAll(im.map((e) => '$e').where((s) => s.isNotEmpty));
    return out.toSet().toList();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final price = num.tryParse('${l['price']}') ?? 0;
    final money = NumberFormat.currency(symbol: 'AED ', decimalDigits: 0).format(price);
    final isRent = '${l['purpose']}' == 'rent';
    final brokerId = '${l['listing_broker_id'] ?? ''}';

    final facts = <(String, String)>[
      if (l['property_type'] != null) ('Type', _cap('${l['property_type']}')),
      if (l['bedrooms'] != null) ('Bedrooms', '${l['bedrooms']}'),
      if (l['bathrooms'] != null) ('Bathrooms', '${l['bathrooms']}'),
      if (l['size_sqft'] != null) ('Size', '${(num.tryParse('${l['size_sqft']}') ?? 0).toStringAsFixed(0)} sqft'),
      if (l['furnishing'] != null) ('Furnishing', _cap('${l['furnishing']}')),
      if ('${l['developer'] ?? ''}'.trim().isNotEmpty) ('Developer', '${l['developer']}'),
      if ('${l['view'] ?? ''}'.trim().isNotEmpty) ('View', '${l['view']}'),
      if (l['parking'] != null) ('Parking', '${l['parking']}'),
      if (l['service_charge'] != null)
        ('Service charge', 'AED ${(num.tryParse('${l['service_charge']}') ?? 0).toStringAsFixed(0)}/sqft/yr'),
      if ('${l['handover_date'] ?? ''}'.trim().isNotEmpty)
        ('Handover', '${l['handover_date']}'.split('T').first),
      if (l['community'] != null) ('Community', '${l['community']}'),
      if (l['building'] != null)
        ('Building', '${l['building']}')
      else if ('${l['building_name'] ?? ''}'.trim().isNotEmpty)
        ('Building', '${l['building_name']}'),
      if (l['unit_no'] != null) ('Unit', '${l['unit_no']}'),
      if (l['status'] != null) ('Status', _cap('${l['status']}')),
    ];

    return ListView(
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Gallery(images: _images),
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.x16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(child: Text(money, style: t.headlineSmall?.copyWith(fontWeight: FontWeight.w700))),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                                color: (isRent ? AppColors.info : AppColors.primary).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(AppSpacing.rFull)),
                            child: Text(isRent ? 'For rent' : 'For sale',
                                style: t.bodySmall?.copyWith(
                                    color: isRent ? AppColors.info : AppColors.primary, fontWeight: FontWeight.w700)),
                          ),
                        ],
                      ),
                      if (l['community'] != null) ...[
                        const SizedBox(height: AppSpacing.x4),
                        Text('${l['community']}', style: t.bodyLarge?.copyWith(color: dark ? AppColors.dTextMuted : AppColors.textMuted)),
                      ],
                      if ('${l['ref_code'] ?? ''}'.trim().isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text('Ref ${l['ref_code']}',
                            style: t.bodySmall?.copyWith(color: dark ? AppColors.dTextMuted : AppColors.textMuted, fontWeight: FontWeight.w600)),
                      ],
                      const SizedBox(height: AppSpacing.x8),
                      ListingRibbons(listing: l),
                      // Owner-management actions (edit / documents / ownership / publish /
                      // agents) are hidden in Customer/buyer mode (owner #12) — gated by the
                      // same capability as the listings FAB, not just broker identity.
                      if (brokerId.isNotEmpty &&
                          ref.watch(authControllerProvider).user?.id == brokerId &&
                          ref.watch(personaProvider).canListProperty) ...[
                        const SizedBox(height: AppSpacing.x12),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: OutlinedButton.icon(
                            onPressed: () => context.push('/properties/$id/edit', extra: l),
                            icon: const Icon(Icons.edit_outlined, size: 18),
                            label: const Text('Edit listing'),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.x12),
                        _OwnershipCard(listingId: id, listing: l),
                        _PublishRow(listingId: id, listing: l),
                        if ('${l['property_id'] ?? ''}'.isNotEmpty)
                          _PropertyAgentsCard(propertyId: '${l['property_id']}'),
                      ],
                      // Document collaboration is open to ANY property party — owner,
                      // lister, or a delegated agent (owner #9) — but only in lister
                      // modes (hidden for customers, like the owner actions).
                      if (l['viewer_can_docs'] == true &&
                          '${l['property_id'] ?? ''}'.isNotEmpty &&
                          ref.watch(personaProvider).canListProperty) ...[
                        const SizedBox(height: AppSpacing.x12),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: OutlinedButton.icon(
                            onPressed: () => context.push('/properties/${l['property_id']}/documents'),
                            icon: const Icon(Icons.folder_open_outlined, size: 18),
                            label: const Text('Documents'),
                          ),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.x16),
                      Text('Key facts', style: t.titleMedium),
                      const SizedBox(height: AppSpacing.x12),
                      // Headline facts as scannable stat cards (the full table
                      // below still carries every detail).
                      Wrap(spacing: AppSpacing.x12, runSpacing: AppSpacing.x12, children: [
                        if (l['bedrooms'] != null) _statCard(context, Icons.bed_outlined, '${l['bedrooms']}', 'Bedrooms'),
                        if (l['bathrooms'] != null) _statCard(context, Icons.bathtub_outlined, '${l['bathrooms']}', 'Bathrooms'),
                        if (l['size_sqft'] != null)
                          _statCard(context, Icons.straighten, (num.tryParse('${l['size_sqft']}') ?? 0).toStringAsFixed(0), 'Sq ft'),
                        if (l['property_type'] != null) _statCard(context, Icons.home_work_outlined, _cap('${l['property_type']}'), 'Type'),
                      ]),
                      const SizedBox(height: AppSpacing.x16),
                      // Remaining facts as a balanced, distributed grid (the
                      // headline four are already the stat cards above).
                      DetailGrid(
                        items: facts
                            .where((f) => !const {'Type', 'Bedrooms', 'Bathrooms', 'Size'}.contains(f.$1))
                            .map((f) => (detailIcon(f.$1), f.$1, f.$2))
                            .toList(),
                      ),
                      if ('${l['description'] ?? ''}'.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.x16),
                        Text('Description', style: t.titleMedium),
                        const SizedBox(height: AppSpacing.x4),
                        Text('${l['description']}', style: t.bodyMedium),
                      ],
                      _FloorPlanBlock(url: '${l['floorplan_url'] ?? ''}'),
                      _AmenitiesBlock(l: l),
                      _IncentivesBlock(l: l),
                      _VerificationBlock(l: l),
                      // Mortgage estimate is shown ONLY on for-sale listings (Customer
                      // module spec — no standalone calculator for buyers).
                      if (!isRent) _MortgageEstimate(
                        price: price.toDouble(),
                        dldWaiverPct: (num.tryParse('${l['dld_waiver_pct'] ?? 0}') ?? 0).toDouble(),
                        processingWaiverPct: (num.tryParse('${l['processing_waiver_pct'] ?? 0}') ?? 0).toDouble(),
                        incentiveNote: '${l['incentive_note'] ?? ''}',
                      ),
                      // Indicative rental ROI from comparable rentals (for-sale only) —
                      // an investor-facing yield read on the property page.
                      if (!isRent) _RoiEstimate(listingId: id),
                      // Living-asset history — property parties only (Listing 2.0).
                      if (l['viewer_can_docs'] == true && '${l['property_id'] ?? ''}'.isNotEmpty)
                        _TimelineBlock(propertyId: '${l['property_id']}'),
                      const SizedBox(height: AppSpacing.x20),
                      if (brokerId.isNotEmpty) _AgentCard(brokerId: brokerId, listingId: id),
                      const SizedBox(height: AppSpacing.x20),
                      Text('Location', style: t.titleMedium),
                      const SizedBox(height: AppSpacing.x8),
                      LocationMap(
                        lat: double.tryParse('${l['latitude'] ?? ''}'),
                        lng: double.tryParse('${l['longitude'] ?? ''}'),
                      ),
                      const SizedBox(height: AppSpacing.x24),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Gallery extends StatefulWidget {
  const _Gallery({required this.images});
  final List<String> images;
  @override
  State<_Gallery> createState() => _GalleryState();
}

class _GalleryState extends State<_Gallery> {
  final _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _go(int delta) {
    final n = widget.images.length;
    if (n < 2) return;
    _controller.animateToPage((_page + delta).clamp(0, n - 1),
        duration: const Duration(milliseconds: 280), curve: Curves.easeOut);
  }

  Widget _navArrow(IconData icon, VoidCallback onTap) => Material(
        color: Colors.black.withValues(alpha: 0.42),
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(padding: const EdgeInsets.all(8), child: Icon(icon, color: Colors.white, size: 22)),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 760;
    final multi = widget.images.length > 1;
    final Widget content = widget.images.isEmpty
        ? Container(
            color: AppColors.surface2,
            child: const Center(child: Icon(Icons.apartment_outlined, size: 56, color: AppColors.textSubtle)))
        : Stack(fit: StackFit.expand, children: [
            PageView.builder(
              controller: _controller,
              itemCount: widget.images.length,
              onPageChanged: (i) => setState(() => _page = i),
              itemBuilder: (_, i) => Image.network(widget.images[i], fit: BoxFit.cover,
                  loadingBuilder: (c, child, p) => p == null ? child : Container(color: AppColors.surface2),
                  errorBuilder: (_, __, ___) => Container(
                      color: AppColors.surface2,
                      child: const Center(child: Icon(Icons.broken_image_outlined, size: 40, color: AppColors.textSubtle)))),
            ),
            const Positioned(
              left: 0, right: 0, bottom: 0, height: 64,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter, end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Color(0x55000000)],
                    ),
                  ),
                ),
              ),
            ),
            if (multi)
              Positioned(
                bottom: AppSpacing.x12, left: 0, right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    widget.images.length,
                    (i) => Container(
                      width: 7, height: 7,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(shape: BoxShape.circle, color: i == _page ? Colors.white : Colors.white54),
                    ),
                  ),
                ),
              ),
            if (multi && wide) ...[
              Positioned(left: 14, top: 0, bottom: 0, child: Center(child: _navArrow(Icons.chevron_left, () => _go(-1)))),
              Positioned(right: 14, top: 0, bottom: 0, child: Center(child: _navArrow(Icons.chevron_right, () => _go(1)))),
            ],
          ]);
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppSpacing.rXl),
      child: AspectRatio(aspectRatio: 16 / 9, child: content),
    );
  }
}

class _AgentCard extends ConsumerWidget {
  const _AgentCard({required this.brokerId, required this.listingId});
  final String brokerId;
  final String listingId;

  Future<DateTime?> _pickDateTime(BuildContext context) async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 90)),
      helpText: 'Preferred viewing date',
    );
    if (date == null || !context.mounted) return null;
    final time = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 11, minute: 0),
      helpText: 'Preferred time',
    );
    if (time == null) return null;
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  Future<void> _requestCollab(BuildContext context, WidgetRef ref) async {
    final split = TextEditingController();
    final msg = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Request collaboration'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Propose a commission split to co-broke this listing.', style: TextStyle(fontSize: 13)),
          const SizedBox(height: AppSpacing.x12),
          TextField(controller: split, keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Your split (%)')),
          const SizedBox(height: AppSpacing.x8),
          TextField(controller: msg, maxLines: 2, decoration: const InputDecoration(labelText: 'Message (optional)')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Send')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(collabRepoProvider).request(listingId, double.tryParse(split.text.trim()), msg.text.trim());
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Request sent to the listing agent')));
      }
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
    }
  }

  Future<void> _requestViewing(BuildContext context, WidgetRef ref) async {
    final dt = await _pickDateTime(context);
    if (dt == null || !context.mounted) return;
    try {
      await ref.read(apiClientProvider).post('/viewings', body: {
        'listing_id': listingId,
        'scheduled_at': dt.toIso8601String(),
      });
      ref.invalidate(_myViewingProvider(listingId));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Viewing requested — the agent will confirm your slot.')));
      }
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
    }
  }

  Future<void> _reschedule(BuildContext context, WidgetRef ref, String viewingId) async {
    final dt = await _pickDateTime(context);
    if (dt == null || !context.mounted) return;
    try {
      await ref.read(apiClientProvider).patch('/viewings/$viewingId/reschedule', body: {
        'scheduled_at': dt.toIso8601String(),
      });
      ref.invalidate(_myViewingProvider(listingId));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('New time proposed — the agent will confirm.')));
      }
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final agent = ref.watch(_agentProvider(brokerId));
    final name = agent.maybeWhen(data: (m) => '${m['full_name'] ?? 'Listing agent'}', orElse: () => 'Listing agent');
    final role = agent.maybeWhen(data: (m) => personaFromRole('${m['role'] ?? ''}').label, orElse: () => '');
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.x16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppColors.primary,
                  child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?', style: const TextStyle(color: Colors.white)),
                ),
                const SizedBox(width: AppSpacing.x12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: t.titleSmall),
                      if (role.isNotEmpty) Text(role, style: t.bodySmall?.copyWith(color: dark ? AppColors.dTextMuted : AppColors.textMuted)),
                    ],
                  ),
                ),
                TextButton(onPressed: () => context.push('/u/$brokerId'), child: const Text('Profile')),
              ],
            ),
            if (ref.watch(authControllerProvider).user?.id != null &&
                ref.watch(authControllerProvider).user?.id != brokerId) ...[
              const SizedBox(height: AppSpacing.x8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    try {
                      final convId = await ref
                          .read(messagingRepositoryProvider)
                          .startDirect(brokerId, contextTable: 'listings', contextId: listingId);
                      if (convId.isNotEmpty && context.mounted) context.push('/messages/$convId');
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
                      }
                    }
                  },
                  icon: const Icon(Icons.chat_bubble_outline, size: 18),
                  label: const Text('Message agent'),
                ),
              ),
              if (ref.watch(personaProvider).canListProperty) ...[
                const SizedBox(height: AppSpacing.x8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _requestCollab(context, ref),
                    icon: const Icon(Icons.diversity_3_outlined, size: 18),
                    label: const Text('Request collaboration'),
                  ),
                ),
              ],
            ],
            const SizedBox(height: AppSpacing.x12),
            ref.watch(_myViewingProvider(listingId)).maybeWhen(
              data: (v) => v == null
                  ? SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () => _requestViewing(context, ref),
                        icon: const Icon(Icons.event_available_outlined),
                        label: const Text('Schedule viewing'),
                      ),
                    )
                  : _BookingBox(v: v, onChange: () => _reschedule(context, ref, '${v['id']}')),
              orElse: () => SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  // Stay actionable even if the existing-viewing lookup is loading
                  // or errored — scheduling doesn't depend on that data.
                  onPressed: () => _requestViewing(context, ref),
                  icon: const Icon(Icons.event_available_outlined),
                  label: const Text('Schedule viewing'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shows the customer's pending booking (date/time + status) on the listing,
/// with a "change" action — until the agent rejects, when it reverts to the button.
class _BookingBox extends StatelessWidget {
  const _BookingBox({required this.v, required this.onChange});
  final Map<String, dynamic> v;
  final VoidCallback onChange;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final sched = DateTime.tryParse('${v['scheduled_at']}');
    final status = '${v['status']}';
    final when = sched != null ? DateFormat('EEE d MMM · HH:mm').format(sched) : 'time to be confirmed';
    final label = switch (status) {
      'scheduled' => 'confirmed',
      'approved' => 'approved',
      _ => 'requested',
    };
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.x12),
      decoration: BoxDecoration(color: AppColors.primaryTint, borderRadius: BorderRadius.circular(AppSpacing.rCard)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.event_available_outlined, size: 18, color: AppColors.primary),
          const SizedBox(width: AppSpacing.x8),
          Expanded(child: Text('Viewing $label', style: t.titleSmall?.copyWith(color: AppColors.primaryDark))),
        ]),
        const SizedBox(height: 2),
        Text(when, style: t.bodyMedium?.copyWith(color: AppColors.primaryDark, fontWeight: FontWeight.w600)),
        if (status != 'scheduled') ...[
          const SizedBox(height: AppSpacing.x8),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: onChange,
              icon: const Icon(Icons.edit_calendar_outlined, size: 16),
              label: const Text('Change date / time'),
            ),
          ),
        ],
      ]),
    );
  }
}

/// Owner-facing ownership-verification card (UAT #2B). Shows the current status
/// and lets the lister submit / resubmit a title-deed for a Nuzler to review.
class _OwnershipCard extends ConsumerStatefulWidget {
  const _OwnershipCard({required this.listingId, required this.listing});
  final String listingId;
  final Map<String, dynamic> listing;
  @override
  ConsumerState<_OwnershipCard> createState() => _OwnershipCardState();
}

class _OwnershipCardState extends ConsumerState<_OwnershipCard> {
  bool _busy = false;

  Future<void> _submit() async {
    if (_busy) return;
    try {
      // Accept a PDF or an image for the title deed (#3).
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png', 'webp'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;
      final f = result.files.first;
      final bytes = f.bytes;
      if (bytes == null) throw Exception('Could not read the file.');
      setState(() => _busy = true);
      final ext = (f.extension ?? '').toLowerCase();
      final ct = ext == 'pdf'
          ? 'application/pdf'
          : ext == 'png'
              ? 'image/png'
              : ext == 'webp'
                  ? 'image/webp'
                  : 'image/jpeg';
      final url = await ref.read(uploadServiceProvider).upload(bytes, f.name, ct);
      if (url == null) throw Exception('Upload failed — please try again.');
      await ref.read(apiClientProvider)
          .post('/listings/${widget.listingId}/ownership', body: {'doc_url': url});
      ref.invalidate(_detailProvider(widget.listingId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Title deed submitted — a Nuzler will review it.')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final status = '${widget.listing['ownership_status'] ?? 'none'}';
    final reason = '${widget.listing['ownership_rejection_reason'] ?? ''}'.trim();
    final (IconData icon, Color color, String label, String sub) = switch (status) {
      'verified' => (
          Icons.verified_user,
          AppColors.accentGold,
          'Ownership verified',
          'Buyers see a verified badge on this listing.'
        ),
      'pending' => (
          Icons.hourglass_top,
          AppColors.info,
          'Verification pending',
          'A Nuzler is reviewing your title deed.'
        ),
      'rejected' => (
          Icons.error_outline,
          AppColors.danger,
          'Verification declined',
          reason.isNotEmpty ? reason : 'Please resubmit a clear title deed.'
        ),
      _ => (
          Icons.shield_outlined,
          dark ? AppColors.dTextMuted : AppColors.textMuted,
          'Verify ownership',
          'Submit a title deed so buyers can trust this listing.'
        ),
    };
    final canSubmit = status == 'none' || status == 'rejected';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.x16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(label, style: t.titleSmall?.copyWith(color: color)),
            ]),
            const SizedBox(height: 4),
            Text(sub, style: t.bodySmall?.copyWith(color: dark ? AppColors.dTextMuted : AppColors.textMuted)),
            if (canSubmit) ...[
              const SizedBox(height: AppSpacing.x12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _busy ? null : _submit,
                  icon: _busy
                      ? const SizedBox(
                          width: 18, height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.upload_file_outlined),
                  label: Text(status == 'rejected' ? 'Resubmit title deed' : 'Submit title deed'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Owner publish / take-offline. Publish surfaces the server gate (permit + 3
/// photos, and for owners a submitted title deed).
class _PublishRow extends ConsumerWidget {
  const _PublishRow({required this.listingId, required this.listing});
  final String listingId;
  final Map<String, dynamic> listing;

  Future<void> _act(BuildContext context, WidgetRef ref, String action) async {
    try {
      await ref.read(apiClientProvider).post('/listings/$listingId/$action');
      ref.invalidate(_detailProvider(listingId));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(action == 'publish' ? 'Listing published.' : 'Listing taken offline.')));
      }
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final live = listing['is_visible'] == true;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.x12),
      child: SizedBox(
        width: double.infinity,
        child: live
            ? OutlinedButton.icon(
                onPressed: () => _act(context, ref, 'unpublish'),
                icon: const Icon(Icons.visibility_off_outlined, size: 18),
                label: const Text('Take offline'),
              )
            : FilledButton.icon(
                onPressed: () => _act(context, ref, 'publish'),
                icon: const Icon(Icons.publish_outlined, size: 18),
                label: const Text('Publish (go live)'),
              ),
      ),
    );
  }
}

final _propertyAgentsProvider = FutureProvider.autoDispose.family<List<dynamic>, String>((ref, propertyId) async {
  try {
    final d = await ref.read(apiClientProvider).get('/properties/$propertyId/agents');
    return d is List ? d : [];
  } catch (_) {
    return [];
  }
});

/// Owner-only: delegate this property to agent(s) → they get its rentals + viewings.
class _PropertyAgentsCard extends ConsumerWidget {
  const _PropertyAgentsCard({required this.propertyId});
  final String propertyId;

  Future<void> _revoke(BuildContext context, WidgetRef ref, String agentId) async {
    try {
      await ref.read(apiClientProvider).delete('/properties/$propertyId/agents/$agentId');
      ref.invalidate(_propertyAgentsProvider(propertyId));
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final agents = ref.watch(_propertyAgentsProvider(propertyId));
    return Card(
      margin: const EdgeInsets.only(top: AppSpacing.x12),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.x16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.support_agent_outlined, size: 20, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 8),
            Expanded(child: Text('Assigned agents', style: t.titleSmall)),
            TextButton.icon(
              onPressed: () async {
                final ok = await showDialog<bool>(
                    context: context, builder: (_) => _AssignAgentDialog(propertyId: propertyId));
                if (ok == true) ref.invalidate(_propertyAgentsProvider(propertyId));
              },
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add'),
            ),
          ]),
          Text('Agents you assign can see this property’s rental requests and viewings.',
              style: t.bodySmall?.copyWith(color: dark ? AppColors.dTextMuted : AppColors.textMuted)),
          const SizedBox(height: AppSpacing.x8),
          agents.when(
            loading: () => const Padding(padding: EdgeInsets.all(8), child: LinearProgressIndicator()),
            error: (e, _) => Text('$e', style: t.bodySmall),
            data: (list) => list.isEmpty
                ? Text('No agents assigned.', style: t.bodySmall?.copyWith(color: dark ? AppColors.dTextMuted : AppColors.textMuted))
                : Column(
                    children: list.map((m) {
                      final a = Map<String, dynamic>.from(m);
                      final name = '${a['full_name'] ?? 'Agent'}';
                      return ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          radius: 16,
                          backgroundColor: AppColors.primaryTint,
                          child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                              style: const TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w700)),
                        ),
                        title: Text(name),
                        subtitle: Text('${a['user_role'] ?? ''}', style: t.bodySmall?.copyWith(color: dark ? AppColors.dTextMuted : AppColors.textMuted)),
                        trailing: IconButton(
                            icon: const Icon(Icons.close, size: 18),
                            tooltip: 'Revoke',
                            onPressed: () => _revoke(context, ref, '${a['agent_id']}')),
                      );
                    }).toList(),
                  ),
          ),
        ]),
      ),
    );
  }
}

class _AssignAgentDialog extends ConsumerStatefulWidget {
  const _AssignAgentDialog({required this.propertyId});
  final String propertyId;
  @override
  ConsumerState<_AssignAgentDialog> createState() => _AssignAgentDialogState();
}

class _AssignAgentDialogState extends ConsumerState<_AssignAgentDialog> {
  final _q = TextEditingController();
  List<dynamic> _results = [];
  bool _loading = false;
  int _seq = 0;

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  Future<void> _search(String q) async {
    final term = q.trim();
    final seq = ++_seq; // ignore out-of-order responses from earlier keystrokes
    if (term.length < 2) {
      setState(() {
        _results = [];
        _loading = false;
      });
      return;
    }
    setState(() => _loading = true);
    try {
      final d = await ref.read(apiClientProvider).get('/users/search', query: {'q': term});
      if (!mounted || seq != _seq) return; // a newer keystroke superseded this one
      setState(() => _results = d is List ? d : []);
    } catch (_) {
      if (mounted && seq == _seq) setState(() => _results = []);
    } finally {
      if (mounted && seq == _seq) setState(() => _loading = false);
    }
  }

  Future<void> _assign(String agentId) async {
    try {
      await ref.read(apiClientProvider)
          .post('/properties/${widget.propertyId}/agents', body: {'agent_id': agentId});
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return AlertDialog(
      title: const Text('Assign an agent'),
      content: SizedBox(
        width: MediaQuery.sizeOf(context).width - 80 < 360 ? MediaQuery.sizeOf(context).width - 80 : 360,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
            controller: _q,
            autofocus: true,
            decoration: const InputDecoration(hintText: 'Search by name', prefixIcon: Icon(Icons.search)),
            onChanged: _search,
          ),
          const SizedBox(height: AppSpacing.x12),
          if (_loading)
            const LinearProgressIndicator()
          else if (_results.isEmpty)
            Padding(padding: const EdgeInsets.all(12), child: Text('Type a name to search.', style: t.bodySmall))
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 280),
              child: ListView(
                shrinkWrap: true,
                children: _results.map((m) {
                  final u = Map<String, dynamic>.from(m);
                  return ListTile(
                    dense: true,
                    leading: const Icon(Icons.person_outline),
                    title: Text('${u['full_name'] ?? 'User'}'),
                    subtitle: Text('${u['role'] ?? ''}'),
                    onTap: () => _assign('${u['id']}'),
                  );
                }).toList(),
              ),
            ),
        ]),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Close'))],
    );
  }
}

/// Amenities chips (from the listing's `amenities` array). Hidden when empty.
class _AmenitiesBlock extends StatelessWidget {
  const _AmenitiesBlock({required this.l});
  final Map<String, dynamic> l;

  @override
  Widget build(BuildContext context) {
    final raw = l['amenities'];
    final items = raw is List
        ? raw.map((e) {
            final m = e is Map ? e : const {};
            return '${m['label'] ?? m['code'] ?? ''}';
          }).where((s) => s.isNotEmpty).toList()
        : <String>[];
    if (items.isEmpty) return const SizedBox.shrink();
    final t = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: AppSpacing.x16),
        Text('Amenities', style: t.titleMedium),
        const SizedBox(height: AppSpacing.x8),
        Wrap(
          spacing: AppSpacing.x8,
          runSpacing: AppSpacing.x8,
          children: items
              .map((a) => Chip(label: Text(a), visualDensity: VisualDensity.compact))
              .toList(),
        ),
      ],
    );
  }
}

/// Verification & compliance: verified badge, permit / RERA numbers, quality meter.
/// Hidden entirely when there's nothing to show.
class _VerificationBlock extends StatelessWidget {
  const _VerificationBlock({required this.l});
  final Map<String, dynamic> l;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final permit = '${l['permit_number'] ?? ''}'.trim();
    final rera = '${l['rera_number'] ?? ''}'.trim();
    final quality = int.tryParse('${l['quality_score'] ?? 0}') ?? 0;
    final verified = '${l['availability_status']}' == 'verified';
    final ownershipVerified = '${l['ownership_status']}' == 'verified';
    if (permit.isEmpty && rera.isEmpty && quality <= 0 && !verified && !ownershipVerified) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: AppSpacing.x16),
        Text('Verification & compliance', style: t.titleMedium),
        const SizedBox(height: AppSpacing.x8),
        Container(
          padding: const EdgeInsets.all(AppSpacing.x12),
          decoration: BoxDecoration(
            color: AppColors.surface2,
            borderRadius: BorderRadius.circular(AppSpacing.rCard),
            border: Border.all(color: Theme.of(context).dividerColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (ownershipVerified) ...[
                Row(children: [
                  const Icon(Icons.verified_user, size: 18, color: AppColors.accentGold),
                  const SizedBox(width: 6),
                  Text('Ownership verified',
                      style: t.bodyMedium?.copyWith(color: AppColors.accentGold, fontWeight: FontWeight.w600)),
                ]),
                const SizedBox(height: AppSpacing.x8),
              ],
              if (verified) ...[
                Row(children: [
                  const Icon(Icons.verified, size: 18, color: AppColors.success),
                  const SizedBox(width: 6),
                  Text('Verified listing',
                      style: t.bodyMedium?.copyWith(color: AppColors.success, fontWeight: FontWeight.w600)),
                ]),
                const SizedBox(height: AppSpacing.x8),
              ],
              if (permit.isNotEmpty) _kv(context, 'Permit no.', permit),
              if (rera.isNotEmpty) _kv(context, 'RERA no.', rera),
              if (quality > 0) ...[
                const SizedBox(height: AppSpacing.x8),
                Row(children: [
                  Text('Listing quality', style: t.bodyMedium?.copyWith(color: AppColors.textMuted)),
                  const Spacer(),
                  Text('$quality/100', style: t.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
                ]),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: quality / 100,
                    minHeight: 8,
                    backgroundColor: AppColors.surface,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _kv(BuildContext c, String k, String v) {
    final t = Theme.of(c).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(k, style: t.bodyMedium?.copyWith(color: AppColors.textMuted)),
          Flexible(
            child: Text(v,
                style: t.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                textAlign: TextAlign.right)),
        ],
      ),
    );
  }
}

/// In-context mortgage estimate for a FOR-SALE listing (Customer module spec):
/// the only place buyers see mortgage math — there is no standalone calculator.
/// Pure client-side amortisation + UAE acquisition costs (DLD 4%, ~1% processing).
/// Structured developer incentives — a gold-tinted "Incentives & offers" card
/// listing each typed offer with an icon and (optional) value.
class _IncentivesBlock extends StatelessWidget {
  const _IncentivesBlock({required this.l});
  final Map<String, dynamic> l;

  @override
  Widget build(BuildContext context) {
    final raw = l['incentives'];
    final items = (raw is List) ? raw : const [];
    if (items.isEmpty) return const SizedBox.shrink();
    final t = Theme.of(context).textTheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SizedBox(height: AppSpacing.x16),
      Row(children: [
        const Icon(Icons.card_giftcard, size: 18, color: AppColors.accentGold),
        const SizedBox(width: AppSpacing.x8),
        Text('Incentives & offers', style: t.titleMedium),
      ]),
      const SizedBox(height: AppSpacing.x8),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.x12),
        decoration: BoxDecoration(
          color: AppColors.accentGold.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppSpacing.rCard),
          border: Border.all(color: AppColors.accentGold.withValues(alpha: 0.25)),
        ),
        child: Column(children: [
          for (final it in items) _row(context, Map<String, dynamic>.from(it as Map)),
        ]),
      ),
    ]);
  }

  Widget _row(BuildContext context, Map<String, dynamic> it) {
    final t = Theme.of(context).textTheme;
    final meta = _incentiveMeta('${it['type'] ?? 'other'}');
    final label = '${it['label'] ?? ''}'.trim().isNotEmpty ? '${it['label']}' : meta.$2;
    final value = _formatIncentiveValue(it['value'], '${it['unit'] ?? ''}');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        Icon(meta.$1, size: 18, color: AppColors.accentGold),
        const SizedBox(width: AppSpacing.x8),
        Expanded(child: Text(label, style: t.bodyMedium?.copyWith(fontWeight: FontWeight.w600))),
        if (value.isNotEmpty)
          Text(value, style: t.bodyMedium?.copyWith(fontWeight: FontWeight.w700, color: AppColors.success)),
      ]),
    );
  }
}

(IconData, String) _incentiveMeta(String type) {
  switch (type) {
    case 'dld_waiver':
      return (Icons.savings_outlined, 'DLD fee waiver');
    case 'processing_waiver':
      return (Icons.receipt_long_outlined, 'Processing fee waiver');
    case 'service_charge_holiday':
      return (Icons.event_busy_outlined, 'Service-charge holiday');
    case 'cash_back':
      return (Icons.payments_outlined, 'Cash-back');
    case 'furniture':
      return (Icons.chair_outlined, 'Furniture allowance');
    case 'payment_plan':
      return (Icons.calendar_month_outlined, 'Payment plan');
    case 'free_management':
      return (Icons.manage_accounts_outlined, 'Free property management');
    default:
      return (Icons.card_giftcard, 'Incentive');
  }
}

String _formatIncentiveValue(dynamic value, String unit) {
  final v = num.tryParse('${value ?? ''}');
  if (v == null) return '';
  switch (unit) {
    case 'percent':
      return '${v % 1 == 0 ? v.toInt() : v}%';
    case 'aed':
      return NumberFormat.currency(symbol: 'AED ', decimalDigits: 0).format(v);
    case 'months':
      return '${v.toInt()} ${v.toInt() == 1 ? 'month' : 'months'}';
    default:
      return '$v';
  }
}

/// Floor-plan image (if the property has one). Tap to view full-size + zoom.
class _FloorPlanBlock extends StatelessWidget {
  const _FloorPlanBlock({required this.url});
  final String url;

  @override
  Widget build(BuildContext context) {
    if (url.trim().isEmpty) return const SizedBox.shrink();
    final t = Theme.of(context).textTheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SizedBox(height: AppSpacing.x16),
      Row(children: [
        const Icon(Icons.architecture_outlined, size: 18, color: AppColors.primary),
        const SizedBox(width: AppSpacing.x8),
        Text('Floor plan', style: t.titleMedium),
      ]),
      const SizedBox(height: AppSpacing.x8),
      GestureDetector(
        onTap: () => showDialog<void>(
          context: context,
          builder: (dctx) => Dialog(
            insetPadding: const EdgeInsets.all(AppSpacing.x16),
            child: Stack(children: [
              InteractiveViewer(
                maxScale: 5,
                child: Image.network(url, fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Padding(
                        padding: EdgeInsets.all(AppSpacing.x24), child: Text('Floor plan unavailable'))),
              ),
              Positioned(
                top: 4, right: 4,
                child: IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.of(dctx).pop()),
              ),
            ]),
          ),
        ),
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxHeight: 420),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSpacing.rCard),
            border: Border.all(color: Theme.of(context).dividerColor),
          ),
          clipBehavior: Clip.antiAlias,
          child: Image.network(url, fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const SizedBox.shrink()),
        ),
      ),
      const SizedBox(height: 4),
      Text('Tap to enlarge', style: t.bodySmall?.copyWith(color: AppColors.textMuted)),
    ]);
  }
}

/// Indicative rental ROI from comparable rentals (for-sale only). Hidden when
/// the backend has no comparable rentals to base an estimate on.
final _yieldProvider = FutureProvider.autoDispose.family<Map<String, dynamic>, String>((ref, id) async {
  try {
    final d = await ref.read(apiClientProvider).get('/listings/$id/yield');
    return d is Map ? Map<String, dynamic>.from(d) : <String, dynamic>{};
  } catch (_) {
    return <String, dynamic>{};
  }
});

class _RoiEstimate extends ConsumerWidget {
  const _RoiEstimate({required this.listingId});
  final String listingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final async = ref.watch(_yieldProvider(listingId));
    return async.maybeWhen(
      data: (m) {
        if (m['available'] != true) return const SizedBox.shrink();
        final gross = num.tryParse('${m['grossYieldPct'] ?? 0}') ?? 0;
        final net = num.tryParse('${m['netYieldPct'] ?? 0}') ?? 0;
        final rent = num.tryParse('${m['estAnnualRent'] ?? 0}') ?? 0;
        final n = m['sampleSize'] ?? 0;
        final money = NumberFormat.currency(symbol: 'AED ', decimalDigits: 0);
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SizedBox(height: AppSpacing.x16),
          Row(children: [
            const Icon(Icons.trending_up, size: 18, color: AppColors.success),
            const SizedBox(width: AppSpacing.x8),
            Text('Investor view — rental ROI', style: t.titleMedium),
          ]),
          const SizedBox(height: AppSpacing.x8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.x16),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(AppSpacing.rCard),
              border: Border.all(color: AppColors.success.withValues(alpha: 0.22)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: _metric(context, '${gross.toStringAsFixed(1)}%', 'Gross yield')),
                Expanded(child: _metric(context, '${net.toStringAsFixed(1)}%', 'Net yield')),
                Expanded(child: _metric(context, money.format(rent), 'Est. annual rent')),
              ]),
              const SizedBox(height: AppSpacing.x8),
              Text(
                'Indicative, based on $n comparable ${m['basis'] ?? 'rentals'}. '
                'Net yield deducts the service charge and a 10% management / vacancy allowance.',
                style: t.bodySmall?.copyWith(color: AppColors.textMuted),
              ),
            ]),
          ),
        ]);
      },
      orElse: () => const SizedBox.shrink(),
    );
  }

  Widget _metric(BuildContext context, String value, String label) {
    final t = Theme.of(context).textTheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Text(value, maxLines: 1,
            style: t.titleMedium?.copyWith(fontWeight: FontWeight.w800, color: AppColors.success)),
      ),
      Text(label, style: t.bodySmall?.copyWith(color: AppColors.textMuted)),
    ]);
  }
}

class _MortgageEstimate extends StatefulWidget {
  const _MortgageEstimate({
    required this.price,
    this.dldWaiverPct = 0,
    this.processingWaiverPct = 0,
    this.incentiveNote = '',
  });
  final double price;
  // % of each fee the developer covers (0 = none, 100 = full waiver).
  final double dldWaiverPct;
  final double processingWaiverPct;
  final String incentiveNote;
  @override
  State<_MortgageEstimate> createState() => _MortgageEstimateState();
}

class _MortgageEstimateState extends State<_MortgageEstimate> {
  double _downPct = 20;
  double _ratePct = 4.5;
  int _years = 25;

  double get _downPayment => widget.price * _downPct / 100;
  double get _loan => widget.price - _downPayment;
  double get _monthly => MortgageMath.monthlyPayment(_loan, _ratePct, _years * 12);
  double get _dldFull => widget.price * 0.04;
  double get _processingFull => _loan * 0.01;
  double get _dld => _dldFull * (1 - widget.dldWaiverPct.clamp(0, 100) / 100);
  double get _processing => _processingFull * (1 - widget.processingWaiverPct.clamp(0, 100) / 100);
  double get _acquisition => widget.price + _dld + _processing;
  bool get _hasIncentive =>
      widget.dldWaiverPct > 0 || widget.processingWaiverPct > 0 || widget.incentiveNote.trim().isNotEmpty;
  String get _incentiveSummary {
    final parts = <String>[];
    if (widget.dldWaiverPct >= 100) {
      parts.add('DLD waived');
    } else if (widget.dldWaiverPct > 0) {
      parts.add('${widget.dldWaiverPct.round()}% DLD covered');
    }
    if (widget.processingWaiverPct >= 100) {
      parts.add('processing fee waived');
    } else if (widget.processingWaiverPct > 0) {
      parts.add('${widget.processingWaiverPct.round()}% processing covered');
    }
    if (widget.incentiveNote.trim().isNotEmpty) parts.add(widget.incentiveNote.trim());
    return parts.join('  ·  ');
  }

  @override
  Widget build(BuildContext context) {
    if (widget.price <= 0) return const SizedBox.shrink();
    final t = Theme.of(context).textTheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final aed = NumberFormat.currency(symbol: 'AED ', decimalDigits: 0);

    Widget control(String label, String value, double v, double min, double max, int divisions, ValueChanged<double> onChanged) =>
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(label, style: t.bodyMedium?.copyWith(color: dark ? AppColors.dTextMuted : AppColors.textMuted)),
            Text(value, style: t.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
          ]),
          Slider(value: v, min: min, max: max, divisions: divisions, onChanged: onChanged),
        ]);

    Widget row(String k, String v, {bool strong = false}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(k, style: t.bodyMedium?.copyWith(
                color: strong ? null : (dark ? AppColors.dTextMuted : AppColors.textMuted),
                fontWeight: strong ? FontWeight.w700 : null)),
            Text(v, style: t.bodyMedium?.copyWith(fontWeight: strong ? FontWeight.w700 : FontWeight.w600)),
          ]),
        );

    // Fee row: when the developer covers part/all of a fee, show the original
    // struck-through next to the discounted amount.
    Widget feeRow(String label, double full, double net, double waiverPct) {
      final waived = waiverPct > 0;
      final suffix = !waived
          ? ''
          : (waiverPct >= 100 ? '  ·  waived' : '  ·  ${waiverPct.round()}% covered');
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Expanded(child: Text('$label$suffix', style: t.bodyMedium?.copyWith(color: dark ? AppColors.dTextMuted : AppColors.textMuted))),
          if (waived) ...[
            Text(aed.format(full),
                style: t.bodySmall?.copyWith(color: dark ? AppColors.dTextMuted : AppColors.textMuted, decoration: TextDecoration.lineThrough)),
            const SizedBox(width: AppSpacing.x8),
            Text(aed.format(net),
                style: t.bodyMedium?.copyWith(fontWeight: FontWeight.w700, color: AppColors.success)),
          ] else
            Text(aed.format(net), style: t.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
        ]),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: AppSpacing.x16),
        Row(children: [
          Icon(Icons.account_balance_outlined, size: 18, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: AppSpacing.x8),
          Text('Mortgage estimate', style: t.titleMedium),
        ]),
        const SizedBox(height: AppSpacing.x8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.x16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (_hasIncentive) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.x12),
                  decoration: BoxDecoration(
                    color: AppColors.accentGold.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppSpacing.rMd),
                  ),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Icon(Icons.card_giftcard, size: 18, color: AppColors.accentGold),
                    const SizedBox(width: AppSpacing.x8),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Developer incentive',
                            style: t.bodyMedium?.copyWith(fontWeight: FontWeight.w700, color: AppColors.accentGold)),
                        if (_incentiveSummary.isNotEmpty)
                          Text(_incentiveSummary, style: t.bodySmall?.copyWith(color: AppColors.textMuted)),
                      ]),
                    ),
                  ]),
                ),
                const SizedBox(height: AppSpacing.x12),
              ],
              control('Down payment', '${_downPct.round()}%  ·  ${aed.format(_downPayment)}',
                  _downPct, 10, 50, 8, (v) => setState(() => _downPct = v)),
              control('Interest rate', '${_ratePct.toStringAsFixed(2)}%',
                  _ratePct, 2, 8, 24, (v) => setState(() => _ratePct = v)),
              control('Loan term', '$_years years',
                  _years.toDouble(), 5, 30, 25, (v) => setState(() => _years = v.round())),
              const Divider(height: AppSpacing.x16),
              Text('Estimated monthly payment', style: t.bodySmall?.copyWith(color: dark ? AppColors.dTextMuted : AppColors.textMuted)),
              Text(aed.format(_monthly),
                  style: t.headlineSmall?.copyWith(
                      // Brighter teal in dark mode — the colorScheme primary is too
                      // dim against the dark card.
                      color: Theme.of(context).brightness == Brightness.dark
                          ? const Color(0xFF6FC3DA)
                          : Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: AppSpacing.x8),
              row('Loan amount', aed.format(_loan)),
              row('Down payment', aed.format(_downPayment)),
              feeRow('DLD fee (4%)', _dldFull, _dld, widget.dldWaiverPct),
              feeRow('Processing fee (~1%)', _processingFull, _processing, widget.processingWaiverPct),
              const Divider(height: AppSpacing.x16),
              row('Total acquisition cost', aed.format(_acquisition), strong: true),
              const SizedBox(height: AppSpacing.x8),
              Text('Estimate only — final terms depend on the lender.',
                  style: t.bodySmall?.copyWith(color: dark ? AppColors.dTextMuted : AppColors.textMuted)),
            ]),
          ),
        ),
      ],
    );
  }
}

/// Property Listing 2.0 (phase 1): the living-asset timeline section.
class _TimelineBlock extends ConsumerWidget {
  const _TimelineBlock({required this.propertyId});
  final String propertyId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final tl = ref.watch(_timelineProvider(propertyId));
    return tl.maybeWhen(
      data: (events) {
        if (events.isEmpty) return const SizedBox.shrink();
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SizedBox(height: AppSpacing.x16),
          Row(children: [
            Icon(Icons.history_outlined, size: 18, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: AppSpacing.x8),
            Text('Property timeline', style: t.titleMedium),
          ]),
          const SizedBox(height: AppSpacing.x8),
          for (var i = 0; i < events.length; i++) _TimelineRow(e: events[i], isLast: i == events.length - 1),
        ]);
      },
      orElse: () => const SizedBox.shrink(),
    );
  }
}

(IconData, String) _eventMeta(String event) => switch (event) {
      'created' => (Icons.add_home_outlined, 'Property created'),
      'listed' => (Icons.sell_outlined, 'Listed'),
      'published' => (Icons.publish_outlined, 'Published — went live'),
      'unpublished' => (Icons.visibility_off_outlined, 'Taken offline'),
      'price_changed' => (Icons.trending_down, 'Price changed'),
      'viewed' => (Icons.visibility_outlined, 'Viewing'),
      'held' => (Icons.lock_clock_outlined, 'Placed on hold'),
      'offer_submitted' => (Icons.local_offer_outlined, 'Offer submitted'),
      'offer_accepted' => (Icons.handshake_outlined, 'Offer accepted'),
      'sold' => (Icons.done_all, 'Sold'),
      'leased' => (Icons.vpn_key_outlined, 'Leased'),
      'maintenance' => (Icons.build_outlined, 'Maintenance'),
      'tenant_change' => (Icons.people_outline, 'Tenant change'),
      'ownership_verified' => (Icons.verified_user_outlined, 'Ownership verified'),
      _ => (Icons.circle_outlined, _cap(event)),
    };

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({required this.e, required this.isLast});
  final Map<String, dynamic> e;
  final bool isLast;

  String? _detailText() {
    final d = e['detail'];
    if (d is Map && '${e['event']}' == 'price_changed' && d['from'] != null && d['to'] != null) {
      final f = NumberFormat.compactCurrency(symbol: 'AED ', decimalDigits: 0);
      return '${f.format(num.tryParse('${d['from']}') ?? 0)} → ${f.format(num.tryParse('${d['to']}') ?? 0)}';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final (icon, label) = _eventMeta('${e['event']}');
    final when = DateTime.tryParse('${e['created_at']}');
    final actor = '${e['actor_name'] ?? ''}'.trim();
    final detail = _detailText();
    return IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Column(children: [
          CircleAvatar(radius: 14, backgroundColor: AppColors.primaryTint, child: Icon(icon, size: 15, color: AppColors.primary)),
          if (!isLast) Expanded(child: Container(width: 2, color: Theme.of(context).dividerColor)),
        ]),
        const SizedBox(width: AppSpacing.x12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.x12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: t.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
              if (detail != null) Text(detail, style: t.bodySmall?.copyWith(color: dark ? AppColors.dTextMuted : AppColors.textMuted)),
              Text([
                if (when != null) DateFormat('d MMM yyyy').format(when),
                if (actor.isNotEmpty) actor,
              ].join('  ·  '), style: t.bodySmall?.copyWith(color: dark ? AppColors.dTextMuted : AppColors.textMuted)),
            ]),
          ),
        ),
      ]),
    );
  }
}

/// Humanise an enum-ish value: drop underscores, capitalise the first letter.
/// e.g. "partly_furnished" → "Partly furnished", "hotel_apartment" → "Hotel apartment".
String _cap(String s) {
  final x = s.replaceAll('_', ' ').trim();
  return x.isEmpty ? x : '${x[0].toUpperCase()}${x.substring(1)}';
}

/// A premium, scannable key-fact stat card (icon + bold value + label).
Widget _statCard(BuildContext context, IconData icon, String value, String label) {
  final t = Theme.of(context).textTheme;
  final dark = Theme.of(context).brightness == Brightness.dark;
  return Container(
    constraints: const BoxConstraints(minWidth: 92),
    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x16, vertical: AppSpacing.x12),
    decoration: BoxDecoration(
      color: Theme.of(context).cardColor,
      borderRadius: BorderRadius.circular(AppSpacing.rLg),
      border: Border.all(color: Theme.of(context).dividerColor),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 22, color: Theme.of(context).colorScheme.primary),
      const SizedBox(height: AppSpacing.x8),
      Text(value, style: t.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
      Text(label, style: t.bodySmall?.copyWith(color: dark ? AppColors.dTextMuted : AppColors.textMuted)),
    ]),
  );
}
