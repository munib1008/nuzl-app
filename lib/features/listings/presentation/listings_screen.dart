import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/network/api_client.dart';
import '../../../core/rbac/persona.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/empty_state.dart';
import '../../auth/application/auth_controller.dart';
import '../../saved/saved_searches.dart';
import '../../shell/app_shell.dart';
import 'listing_ribbons.dart';

final listingsRawProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  try {
    final d = await ref.read(apiClientProvider).get('/listings');
    return d is List ? d : [];
  } catch (_) {
    return [];
  }
});

final _fPurpose = StateProvider.autoDispose<String>((ref) => 'all');
final _fType = StateProvider.autoDispose<String>((ref) => 'all');
final _fBeds = StateProvider.autoDispose<int?>((ref) => null);
final _fPriceMin = StateProvider.autoDispose<double?>((ref) => null);
final _fPriceMax = StateProvider.autoDispose<double?>((ref) => null);
final _fSort = StateProvider.autoDispose<String>((ref) => 'latest');
final _fMine = StateProvider.autoDispose<bool>((ref) => false);
final _fQuery = StateProvider.autoDispose<String>((ref) => '');

class ListingsScreen extends ConsumerWidget {
  const ListingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listings = ref.watch(listingsRawProvider);
    final canList = ref.watch(personaProvider).canListProperty;
    final purpose = ref.watch(_fPurpose);
    final type = ref.watch(_fType);
    final beds = ref.watch(_fBeds);
    final priceMin = ref.watch(_fPriceMin);
    final priceMax = ref.watch(_fPriceMax);
    final sort = ref.watch(_fSort);
    final mine = ref.watch(_fMine);
    final query = ref.watch(_fQuery).trim().toLowerCase();
    final myId = ref.watch(authControllerProvider).user?.id;

    return Scaffold(
      appBar: NuzlAppBar(title: 'Properties', actions: [
        SaveSearchAction(filters: {
          if (purpose != 'all') 'purpose': purpose,
          if (type != 'all') 'property_type': type,
          if (beds != null) 'min_bedrooms': beds,
          if (priceMin != null) 'min_price': priceMin,
          if (priceMax != null) 'max_price': priceMax,
          if (query.isNotEmpty) 'q': query,
        }),
        const SavedSearchAlertsBell(),
      ]),
      drawer: const NuzlDrawer(),
      floatingActionButton: canList
          ? FloatingActionButton.extended(
              onPressed: () => context.push('/properties/new'),
              icon: const Icon(Icons.add),
              label: const Text('New listing'),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: () async => ref.refresh(listingsRawProvider.future),
        child: listings.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Padding(padding: const EdgeInsets.all(24), child: Text('$e'))),
          data: (raw) {
            final all = raw.map((e) => Map<String, dynamic>.from(e)).toList();
            final types = <String>{'all', ...all.map((m) => '${m['property_type'] ?? ''}').where((s) => s.isNotEmpty)};
            num priceOf(Map<String, dynamic> m) => num.tryParse('${m['price']}') ?? 0;
            int? bedsOf(Map<String, dynamic> m) => m['bedrooms'] is int ? m['bedrooms'] as int : int.tryParse('${m['bedrooms']}');
            final items = all.where((m) {
              if (mine && myId != null && '${m['listing_broker_id']}' != myId) return false;
              if (purpose != 'all' && '${m['purpose']}' != purpose) return false;
              if (type != 'all' && '${m['property_type']}' != type) return false;
              if (beds != null && (bedsOf(m) ?? -1) < beds) return false;
              if (priceMin != null && priceOf(m) < priceMin) return false;
              if (priceMax != null && priceOf(m) > priceMax) return false;
              if (query.isNotEmpty) {
                final hay = '${m['community'] ?? ''} ${m['property_type'] ?? ''} '
                        '${m['building_name'] ?? ''} ${m['description'] ?? ''}'
                    .toLowerCase();
                if (!hay.contains(query)) return false;
              }
              return true;
            }).toList();
            // sort — 'latest' keeps the server order (created_at desc)
            if (sort == 'price_asc') {
              items.sort((a, b) => priceOf(a).compareTo(priceOf(b)));
            } else if (sort == 'price_desc') {
              items.sort((a, b) => priceOf(b).compareTo(priceOf(a)));
            }

            return ListView(
              padding: const EdgeInsets.all(AppSpacing.x16),
              children: [
                _FilterBar(types: types.toList()),
                const SizedBox(height: AppSpacing.x12),
                if (items.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 40),
                    child: EmptyState(
                      icon: Icons.search_off_outlined,
                      title: 'No matching properties',
                      message: 'Try widening your filters to see more listings.',
                    ),
                  )
                else
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1100),
                      child: LayoutBuilder(
                        builder: (ctx, c) {
                          final cols = c.maxWidth >= 980 ? 3 : (c.maxWidth >= 620 ? 2 : 1);
                          final cardW = cols == 1 ? c.maxWidth : (c.maxWidth - (cols - 1) * AppSpacing.x16) / cols;
                          return Wrap(
                            spacing: AppSpacing.x16,
                            runSpacing: AppSpacing.x16,
                            children: items
                                .map((m) => SizedBox(width: cardW, child: _ListingCard(m)))
                                .toList(),
                          );
                        },
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _FilterBar extends ConsumerWidget {
  const _FilterBar({required this.types});
  final List<String> types;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      TextField(
        decoration: const InputDecoration(
          hintText: 'Search area, community or building…',
          prefixIcon: Icon(Icons.search),
          isDense: true,
        ),
        onChanged: (v) => ref.read(_fQuery.notifier).state = v,
      ),
      const SizedBox(height: AppSpacing.x8),
      SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _Drop<String>(
            label: 'Purpose',
            value: ref.watch(_fPurpose),
            items: const [('all', 'Any'), ('sale', 'For sale'), ('rent', 'For rent')],
            onChanged: (v) => ref.read(_fPurpose.notifier).state = v ?? 'all',
          ),
          const SizedBox(width: AppSpacing.x8),
          _Drop<String>(
            label: 'Type',
            value: ref.watch(_fType),
            items: types.map((t) => (t, t == 'all' ? 'Any type' : _cap(t))).toList(),
            onChanged: (v) => ref.read(_fType.notifier).state = v ?? 'all',
          ),
          const SizedBox(width: AppSpacing.x8),
          _Drop<int?>(
            label: 'Beds',
            value: ref.watch(_fBeds),
            items: const [(null, 'Any beds'), (0, 'Studio'), (1, '1+'), (2, '2+'), (3, '3+'), (4, '4+')],
            onChanged: (v) => ref.read(_fBeds.notifier).state = v,
          ),
          const SizedBox(width: AppSpacing.x8),
          _Drop<double?>(
            label: 'Min price',
            value: ref.watch(_fPriceMin),
            items: const [
              (null, 'Any min'),
              (500000.0, '≥ 500K'),
              (1000000.0, '≥ 1M'),
              (2000000.0, '≥ 2M'),
              (3000000.0, '≥ 3M'),
            ],
            onChanged: (v) => ref.read(_fPriceMin.notifier).state = v,
          ),
          const SizedBox(width: AppSpacing.x8),
          _Drop<double?>(
            label: 'Max price',
            value: ref.watch(_fPriceMax),
            items: const [
              (null, 'Any price'),
              (500000.0, '≤ 500K'),
              (1000000.0, '≤ 1M'),
              (2000000.0, '≤ 2M'),
              (5000000.0, '≤ 5M'),
            ],
            onChanged: (v) => ref.read(_fPriceMax.notifier).state = v,
          ),
          const SizedBox(width: AppSpacing.x8),
          _Drop<String>(
            label: 'Sort',
            value: ref.watch(_fSort),
            items: const [('latest', 'Latest'), ('price_asc', 'Price: low→high'), ('price_desc', 'Price: high→low')],
            onChanged: (v) => ref.read(_fSort.notifier).state = v ?? 'latest',
          ),
          if (ref.watch(personaProvider).canListProperty) ...[
            const SizedBox(width: AppSpacing.x8),
            FilterChip(
              label: const Text('My listings'),
              selected: ref.watch(_fMine),
              onSelected: (v) => ref.read(_fMine.notifier).state = v,
            ),
          ],
        ],
      ),
      ),
    ]);
  }
}

class _Drop<T> extends StatelessWidget {
  const _Drop({required this.label, required this.value, required this.items, required this.onChanged});
  final String label;
  final T value;
  final List<(T, String)> items;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppSpacing.rFull),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isDense: true,
          borderRadius: BorderRadius.circular(AppSpacing.rMd),
          hint: Text(label),
          items: items.map((it) => DropdownMenuItem<T>(value: it.$1, child: Text(it.$2))).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}

String _cap(String s) => s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

class _ListingCard extends StatelessWidget {
  const _ListingCard(this.l);
  final Map<String, dynamic> l;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final price = num.tryParse('${l['price']}') ?? 0;
    final money = NumberFormat.currency(symbol: 'AED ', decimalDigits: 0).format(price);
    final cover = '${l['cover_image'] ?? ''}';
    final isRent = '${l['purpose']}' == 'rent';
    final facts = [
      if (l['property_type'] != null) _cap('${l['property_type']}'),
      if (l['bedrooms'] != null) '${l['bedrooms']} BR',
      if (l['bathrooms'] != null) '${l['bathrooms']} BA',
      if (l['size_sqft'] != null) '${(num.tryParse('${l['size_sqft']}') ?? 0).toStringAsFixed(0)} sqft',
    ].join('  ·  ');

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/listings/${l['id']}'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: cover.isEmpty
                      ? Container(
                          color: AppColors.surface2,
                          child: const Center(child: Icon(Icons.apartment_outlined, size: 40, color: AppColors.textSubtle)),
                        )
                      : Image.network(cover, fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                              color: AppColors.surface2,
                              child: const Center(child: Icon(Icons.apartment_outlined, size: 40, color: AppColors.textSubtle)))),
                ),
                Positioned(
                  left: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: (isRent ? AppColors.info : AppColors.primary).withValues(alpha: 0.92),
                      borderRadius: BorderRadius.circular(AppSpacing.rFull),
                    ),
                    child: Text(isRent ? 'For rent' : 'For sale',
                        style: t.bodySmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w600)),
                  ),
                ),
                if (l['is_visible'] == false)
                  Positioned(
                    right: 8,
                    top: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withValues(alpha: 0.95),
                        borderRadius: BorderRadius.circular(AppSpacing.rFull),
                      ),
                      child: Text('Draft',
                          style: t.bodySmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w600)),
                    ),
                  ),
                // Status ribbons (Verified / Exclusive / Hot deal / Price reduced / New).
                Positioned(left: 8, bottom: 8, right: 8, child: ListingRibbons(listing: l)),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.x12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(money, style: t.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  if (l['community'] != null)
                    Text('${l['community']}', style: t.bodyMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(facts, style: t.bodySmall?.copyWith(color: AppColors.textMuted),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
