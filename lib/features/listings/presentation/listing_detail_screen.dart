import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/upload_service.dart';
import '../../../core/rbac/persona.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../auth/application/auth_controller.dart';
import '../../messages/data/messaging_repository.dart';
import '../../saved/saved_screen.dart';

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
        error: (e, _) => Center(child: Padding(padding: const EdgeInsets.all(24), child: Text('$e'))),
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
      if (l['community'] != null) ('Community', '${l['community']}'),
      if (l['building'] != null) ('Building', '${l['building']}'),
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
                        Text('${l['community']}', style: t.bodyLarge?.copyWith(color: AppColors.textMuted)),
                      ],
                      if (brokerId.isNotEmpty && ref.watch(authControllerProvider).user?.id == brokerId) ...[
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
                      ],
                      const SizedBox(height: AppSpacing.x16),
                      Text('Key facts', style: t.titleMedium),
                      const SizedBox(height: AppSpacing.x8),
                      ...facts.map((f) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(f.$1, style: t.bodyMedium?.copyWith(color: AppColors.textMuted)),
                                Text(f.$2, style: t.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                              ],
                            ),
                          )),
                      if ('${l['description'] ?? ''}'.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.x16),
                        Text('Description', style: t.titleMedium),
                        const SizedBox(height: AppSpacing.x4),
                        Text('${l['description']}', style: t.bodyMedium),
                      ],
                      _AmenitiesBlock(l: l),
                      _VerificationBlock(l: l),
                      const SizedBox(height: AppSpacing.x20),
                      if (brokerId.isNotEmpty) _AgentCard(brokerId: brokerId, listingId: id),
                      const SizedBox(height: AppSpacing.x20),
                      Text('Location', style: t.titleMedium),
                      const SizedBox(height: AppSpacing.x8),
                      const _MapPlaceholder(),
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

  @override
  Widget build(BuildContext context) {
    if (widget.images.isEmpty) {
      return AspectRatio(
        aspectRatio: 16 / 9,
        child: Container(
          color: AppColors.surface2,
          child: const Center(child: Icon(Icons.apartment_outlined, size: 56, color: AppColors.textSubtle)),
        ),
      );
    }
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          PageView.builder(
            controller: _controller,
            itemCount: widget.images.length,
            onPageChanged: (i) => setState(() => _page = i),
            itemBuilder: (_, i) => Image.network(widget.images[i], fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                    color: AppColors.surface2,
                    child: const Center(child: Icon(Icons.broken_image_outlined, size: 40, color: AppColors.textSubtle)))),
          ),
          if (widget.images.length > 1)
            Padding(
              padding: const EdgeInsets.all(AppSpacing.x8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  widget.images.length,
                  (i) => Container(
                    width: 7,
                    height: 7,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: i == _page ? Colors.white : Colors.white54,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
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
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
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
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
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
                      if (role.isNotEmpty) Text(role, style: t.bodySmall?.copyWith(color: AppColors.textMuted)),
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
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
                      }
                    }
                  },
                  icon: const Icon(Icons.chat_bubble_outline, size: 18),
                  label: const Text('Message agent'),
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.x12),
            ref.watch(_myViewingProvider(listingId)).maybeWhen(
              data: (v) => v == null
                  ? SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () => _requestViewing(context, ref),
                        icon: const Icon(Icons.event_available_outlined),
                        label: const Text('Request viewing'),
                      ),
                    )
                  : _BookingBox(v: v, onChange: () => _reschedule(context, ref, '${v['id']}')),
              orElse: () => SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: null,
                  icon: const Icon(Icons.event_available_outlined),
                  label: const Text('Request viewing'),
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
      final picked = await ImagePicker()
          .pickImage(source: ImageSource.gallery, maxWidth: 2200, imageQuality: 85);
      if (picked == null) return;
      setState(() => _busy = true);
      final bytes = await picked.readAsBytes();
      final url = await ref.read(uploadServiceProvider).upload(bytes, picked.name, 'image/jpeg');
      if (url == null) throw Exception('Upload failed — please try again.');
      await ref.read(apiClientProvider)
          .post('/listings/${widget.listingId}/ownership', body: {'doc_url': url});
      ref.invalidate(_detailProvider(widget.listingId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Title deed submitted — a Nuzler will review it.')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
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
          AppColors.textMuted,
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
            Text(sub, style: t.bodySmall?.copyWith(color: AppColors.textMuted)),
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

class _MapPlaceholder extends StatelessWidget {
  const _MapPlaceholder();
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 160,
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(AppSpacing.rMd),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.map_outlined, size: 32, color: AppColors.textSubtle),
            SizedBox(height: 6),
            Text('Map view coming soon', style: TextStyle(color: AppColors.textSubtle)),
          ],
        ),
      ),
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

/// Humanise an enum-ish value: drop underscores, capitalise the first letter.
/// e.g. "partly_furnished" → "Partly furnished", "hotel_apartment" → "Hotel apartment".
String _cap(String s) {
  final x = s.replaceAll('_', ' ').trim();
  return x.isEmpty ? x : '${x[0].toUpperCase()}${x.substring(1)}';
}
