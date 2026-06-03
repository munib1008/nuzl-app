import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/network/api_client.dart';
import '../../../core/rbac/persona.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';

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

class ListingDetailScreen extends ConsumerWidget {
  const ListingDetailScreen({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(_detailProvider(id));
    return Scaffold(
      appBar: AppBar(title: const Text('Listing')),
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

  Future<void> _requestViewing(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(apiClientProvider).post('/activity', body: {
        'activity_type': 'viewing_request',
        'listing_id': listingId,
      });
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Viewing requested — the agent will be in touch.')));
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
            const SizedBox(height: AppSpacing.x12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => _requestViewing(context, ref),
                icon: const Icon(Icons.event_available_outlined),
                label: const Text('Request viewing'),
              ),
            ),
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

String _cap(String s) => s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';
