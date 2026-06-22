import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/responsive.dart';
import '../shell/app_shell.dart';
import 'booking_schedule.dart';
import 'cart_repository.dart';
import 'orders_repository.dart' show bookablePropertiesProvider;
import 'marketplace_screen.dart' show marketplaceProvider;

final _itemProvider = FutureProvider.autoDispose.family<Map<String, dynamic>?, String>((ref, id) async {
  try {
    final d = await ref.read(apiClientProvider).get('/marketplace/$id');
    return d is Map ? Map<String, dynamic>.from(d) : null;
  } catch (_) {
    return null;
  }
});

final _reviewsProvider = FutureProvider.autoDispose.family<List<dynamic>, String>((ref, id) async {
  try {
    final d = await ref.read(apiClientProvider).get('/marketplace/$id/reviews');
    return d is List ? d : [];
  } catch (_) {
    return [];
  }
});

class MarketplaceItemScreen extends ConsumerWidget {
  const MarketplaceItemScreen({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final item = ref.watch(_itemProvider(id));
    return Scaffold(
      appBar: NuzlAppBar(title: context.tr('Details')),
      drawer: const NuzlDrawer(),
      body: item.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => _notFound(context),
        data: (m) => (m == null) ? _notFound(context) : _Detail(m: m, id: id),
      ),
    );
  }

  Widget _notFound(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.search_off, size: 44, color: dark ? AppColors.dTextMuted : AppColors.textMuted),
          const SizedBox(height: AppSpacing.x12),
          Text(context.tr('This item is no longer available.')),
          const SizedBox(height: AppSpacing.x16),
          FilledButton(onPressed: () => context.go('/marketplace'), child: Text(context.tr('Back to marketplace'))),
        ]),
      );
  }
}

class _Detail extends ConsumerWidget {
  const _Detail({required this.m, required this.id});
  final Map<String, dynamic> m;
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final aed = NumberFormat.currency(symbol: 'AED ', decimalDigits: 0);
    final price = num.tryParse('${m['price']}') ?? 0;
    final unit = '${m['price_unit'] ?? ''}'.trim();
    final img = '${m['image_url'] ?? ''}';
    final category = '${m['category'] ?? ''}'.trim();
    final isProduct = '${m['kind']}' == 'product';
    final desc = '${m['description'] ?? ''}'.trim();
    final org = '${m['supplier_org'] ?? ''}'.trim();
    final person = '${m['supplier_name'] ?? ''}'.trim();
    final supplier = org.isNotEmpty ? org : person;
    final rating = num.tryParse('${m['rating'] ?? ''}');
    final reviewCount = int.tryParse('${m['review_count'] ?? 0}') ?? 0;
    final delivery = int.tryParse('${m['delivery_days'] ?? ''}');
    // Prefer the assigned sales contact (Listing 2.0); fall back to legacy free-text.
    final contact = '${m['assigned_sales_name'] ?? m['contact'] ?? ''}'.trim();
    final reviews = ref.watch(_reviewsProvider(id));

    return ResponsiveCenter(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: img.isNotEmpty
                ? Image.network(img, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _thumb())
                : _thumb(),
          ),
          if (m['gallery'] is List && (m['gallery'] as List).length > 1)
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.x16, AppSpacing.x12, AppSpacing.x16, 0),
              child: SizedBox(
                height: 64,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: (m['gallery'] as List).length,
                  separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.x8),
                  itemBuilder: (_, i) {
                    final url = '${(m['gallery'] as List)[i]}';
                    return GestureDetector(
                      onTap: () => showDialog<void>(
                        context: context,
                        builder: (dctx) => Dialog(
                          insetPadding: const EdgeInsets.all(AppSpacing.x16),
                          child: InteractiveViewer(maxScale: 5, child: Image.network(url, fit: BoxFit.contain)),
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(AppSpacing.rMd),
                        child: Image.network(url, width: 84, height: 64, fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const SizedBox(width: 84, height: 64)),
                      ),
                    );
                  },
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.x20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Approval status for a just-submitted draft (visible to the owner).
              if (m['is_active'] == false) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.x12),
                  decoration: BoxDecoration(
                    color: AppColors.accentGoldTint,
                    borderRadius: BorderRadius.circular(AppSpacing.rMd),
                  ),
                  child: Row(children: [
                    const Icon(Icons.hourglass_top, size: 16, color: AppColors.accentGold),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(context.tr('Pending approval — visible only to you until your company is verified, then it publishes automatically.'),
                          style: t.bodySmall?.copyWith(color: AppColors.accentGold, fontWeight: FontWeight.w600)),
                    ),
                  ]),
                ),
                const SizedBox(height: AppSpacing.x12),
              ],
              if (category.isNotEmpty)
                Text(category.toUpperCase(),
                    style: t.labelSmall?.copyWith(color: dark ? AppColors.dTextMuted : AppColors.textMuted, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
              const SizedBox(height: 4),
              Text('${m['title'] ?? ''}', style: t.headlineSmall),
              if (supplier.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.x8),
                Row(children: [
                  Icon(Icons.storefront_outlined, size: 16, color: dark ? AppColors.dTextMuted : AppColors.textMuted),
                  const SizedBox(width: 6),
                  Text(supplier, style: t.bodyMedium?.copyWith(color: dark ? AppColors.dTextMuted : AppColors.textMuted)),
                ]),
              ],
              if (rating != null && reviewCount > 0) ...[
                const SizedBox(height: 6),
                Row(children: [
                  for (var i = 1; i <= 5; i++)
                    Icon(i <= rating.round() ? Icons.star : Icons.star_border, size: 16, color: AppColors.accentGold),
                  const SizedBox(width: 6),
                  Text('${rating.toStringAsFixed(1)} · $reviewCount ${context.tr(reviewCount == 1 ? 'review' : 'reviews')}',
                      style: t.bodySmall?.copyWith(color: dark ? AppColors.dTextMuted : AppColors.textMuted)),
                ]),
              ],
              const SizedBox(height: AppSpacing.x12),
              if (price > 0)
                Text('${aed.format(price)}${unit.isNotEmpty ? ' · $unit' : ''}',
                    style: t.headlineMedium?.copyWith(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w800)),
              if (delivery != null && delivery > 0) ...[
                const SizedBox(height: 6),
                Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(isProduct ? Icons.local_shipping_outlined : Icons.schedule, size: 15, color: AppColors.success),
                  const SizedBox(width: 4),
                  Text('~$delivery ${context.tr(isProduct ? 'day delivery' : 'day lead time')}',
                      style: t.bodyMedium?.copyWith(color: AppColors.success, fontWeight: FontWeight.w600)),
                ]),
              ],
              if (desc.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.x20),
                Text(context.tr('About'), style: t.titleMedium),
                const SizedBox(height: AppSpacing.x8),
                Text(desc, style: t.bodyMedium?.copyWith(height: 1.5)),
              ],
              if (isProduct && (int.tryParse('${m['moq'] ?? ''}') ?? 0) > 0) ...[
                const SizedBox(height: AppSpacing.x12),
                Row(children: [
                  Icon(Icons.inventory_2_outlined, size: 16, color: dark ? AppColors.dTextMuted : AppColors.textMuted),
                  const SizedBox(width: 6),
                  Text('${context.tr('Minimum order')}: ${m['moq']}',
                      style: t.bodyMedium?.copyWith(color: dark ? AppColors.dTextMuted : AppColors.textMuted)),
                ]),
              ],
              if (!isProduct && '${m['coverage_areas'] ?? ''}'.trim().isNotEmpty) ...[
                const SizedBox(height: AppSpacing.x12),
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(Icons.place_outlined, size: 16, color: dark ? AppColors.dTextMuted : AppColors.textMuted),
                  const SizedBox(width: 6),
                  Expanded(child: Text('${context.tr('Coverage')}: ${m['coverage_areas']}', maxLines: 2, overflow: TextOverflow.ellipsis,
                      style: t.bodyMedium?.copyWith(color: dark ? AppColors.dTextMuted : AppColors.textMuted))),
                ]),
              ],
              if ('${m['brochure_url'] ?? ''}'.trim().isNotEmpty) ...[
                const SizedBox(height: AppSpacing.x12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed: () => launchUrl(Uri.parse('${m['brochure_url']}'), webOnlyWindowName: '_blank'),
                    icon: const Icon(Icons.description_outlined, size: 18),
                    label: Text(context.tr('Download brochure')),
                  ),
                ),
              ],
              if (contact.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.x16),
                Row(children: [
                  Icon(Icons.support_agent_outlined, size: 16, color: dark ? AppColors.dTextMuted : AppColors.textMuted),
                  const SizedBox(width: 6),
                  Text('${context.tr('Sales contact')}: $contact', style: t.bodyMedium?.copyWith(color: dark ? AppColors.dTextMuted : AppColors.textMuted)),
                ]),
              ],
              const SizedBox(height: AppSpacing.x24),
              Text(context.tr('Reviews'), style: t.titleMedium),
              const SizedBox(height: AppSpacing.x8),
              reviews.when(
                loading: () => const LinearProgressIndicator(),
                error: (_, __) => Text(context.tr('Couldn’t load reviews.'), style: t.bodySmall?.copyWith(color: dark ? AppColors.dTextMuted : AppColors.textMuted)),
                data: (list) => list.isEmpty
                    ? Text(context.tr('No reviews yet. Be the first after your order completes.'),
                        style: t.bodySmall?.copyWith(color: dark ? AppColors.dTextMuted : AppColors.textMuted))
                    : Column(children: list.map((r) => _ReviewRow(Map<String, dynamic>.from(r))).toList()),
              ),
              const SizedBox(height: AppSpacing.x24),
              Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _order(context, ref, quote: true),
                    child: Text(context.tr('Request quote')),
                  ),
                ),
                const SizedBox(width: AppSpacing.x12),
                Expanded(
                  child: FilledButton(
                    onPressed: () => isProduct ? addToCart(context, ref, id) : _order(context, ref),
                    child: Text(context.tr(isProduct ? 'Add to cart' : 'Book')),
                  ),
                ),
              ]),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _thumb() => Container(
        color: AppColors.surface2,
        child: const Center(child: Icon(Icons.storefront_outlined, color: AppColors.textMuted, size: 48)),
      );

  Future<void> _order(BuildContext context, WidgetRef ref, {bool quote = false}) async {
    final isProduct = '${m['kind'] ?? 'service'}' == 'product';
    // Booking a service → capture the preferred date & time so the provider
    // knows when to perform it. (Products & quote requests aren't scheduled.)
    String? scheduledAt;
    String? bookingNote;
    String? bookingProperty;
    if (!quote && !isProduct) {
      final props = await ref.read(bookablePropertiesProvider.future);
      if (!context.mounted) return;
      final booking = await pickServiceBooking(context, m, properties: props); // constrained to working hours
      if (booking == null) return; // customer cancelled
      scheduledAt = booking.when.toIso8601String();
      bookingNote = booking.note;
      bookingProperty = booking.propertyId;
    }
    try {
      await ref.read(apiClientProvider).post('/marketplace/orders', body: {
        'item_id': id,
        if (quote) 'quote': true,
        if (scheduledAt != null) 'scheduled_at': scheduledAt,
        if (bookingNote != null) 'note': bookingNote,
        if (bookingProperty != null) 'property_id': bookingProperty,
      });
      ref.invalidate(marketplaceProvider('${m['kind'] ?? 'service'}'));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(context.tr(quote
              ? 'Quotation requested — track it in Orders.'
              : (scheduledAt != null ? 'Service booked — track it in Orders.' : 'Order placed — track it in Orders.'))),
          action: SnackBarAction(label: context.tr('View'), onPressed: () => context.go('/orders')),
        ));
      }
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
    }
  }
}

class _ReviewRow extends StatelessWidget {
  const _ReviewRow(this.r);
  final Map<String, dynamic> r;
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final rating = num.tryParse('${r['rating'] ?? ''}')?.round() ?? 0;
    final name = '${r['customer_name'] ?? 'Customer'}'.trim();
    final review = '${r['review'] ?? ''}'.trim();
    final created = DateTime.tryParse('${r['created_at']}');
    final when = created != null ? DateFormat('d MMM y').format(created) : '';
    final recommend = r['review_recommend'];
    final photos = (r['review_photos'] is List)
        ? (r['review_photos'] as List).map((e) => '$e').where((s) => s.isNotEmpty).toList()
        : <String>[];
    final providerReply = '${r['provider_reply'] ?? ''}'.trim();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.x8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          for (var i = 1; i <= 5; i++)
            Icon(i <= rating ? Icons.star : Icons.star_border, size: 13, color: AppColors.accentGold),
          const SizedBox(width: 8),
          Expanded(
            child: Text(name.isEmpty ? context.tr('Customer') : name,
                style: t.bodySmall?.copyWith(fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          if (when.isNotEmpty) Text(when, style: t.bodySmall?.copyWith(color: dark ? AppColors.dTextMuted : AppColors.textMuted)),
        ]),
        if (review.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(review, style: t.bodyMedium),
        ],
        if (recommend == true || recommend == false) ...[
          const SizedBox(height: 4),
          Text(recommend == true ? '👍 ${context.tr('Recommends')}' : '👎 ${context.tr('Doesn’t recommend')}',
              style: t.bodySmall?.copyWith(
                  color: recommend == true ? AppColors.success : (dark ? AppColors.dTextMuted : AppColors.textMuted),
                  fontWeight: FontWeight.w600)),
        ],
        if (photos.isNotEmpty) ...[
          const SizedBox(height: 6),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final url in photos)
              ClipRRect(
                borderRadius: BorderRadius.circular(AppSpacing.rMd),
                child: Image.network(url, width: 56, height: 56, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const SizedBox(width: 56, height: 56)),
              ),
          ]),
        ],
        if (providerReply.isNotEmpty) ...[
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.all(AppSpacing.x8),
            decoration: BoxDecoration(
              color: Theme.of(context).dividerColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(AppSpacing.rMd),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(context.tr('Provider response'), style: t.bodySmall?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(providerReply, style: t.bodySmall),
            ]),
          ),
        ],
      ]),
    );
  }
}
