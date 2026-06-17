import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/network/api_client.dart';
import '../../../core/rbac/persona.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/hover_lift.dart';
import '../../../core/widgets/skeleton_loader.dart';
import '../../saved/saved_screen.dart';
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
    final t = Theme.of(context).textTheme;

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
          loading: () => const Padding(
              padding: EdgeInsets.all(AppSpacing.x16), child: SkeletonListingGrid()),
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
                        '${m['building_name'] ?? ''} ${m['unit_no'] ?? ''} '
                        '${m['ref_code'] ?? ''} ${m['description'] ?? ''}'
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

            // Popular communities (most-listed) for quick-search chips.
            final counts = <String, int>{};
            for (final m in all) {
              final c = '${m['community'] ?? ''}'.trim();
              if (c.isNotEmpty) counts[c] = (counts[c] ?? 0) + 1;
            }
            final topCommunities = (counts.keys.toList()
                  ..sort((a, b) => counts[b]!.compareTo(counts[a]!)))
                .take(6)
                .toList();
            final filtersActive = purpose != 'all' || type != 'all' || beds != null ||
                priceMin != null || priceMax != null || query.isNotEmpty || mine;

            Widget grid(List<Map<String, dynamic>> data) => LayoutBuilder(
                  builder: (ctx, c) {
                    final cols = c.maxWidth >= 980 ? 3 : (c.maxWidth >= 620 ? 2 : 1);
                    final cardW = cols == 1 ? c.maxWidth : (c.maxWidth - (cols - 1) * AppSpacing.x16) / cols;
                    return Wrap(
                      spacing: AppSpacing.x16,
                      runSpacing: AppSpacing.x16,
                      children: data
                          .map((m) => SizedBox(width: cardW, child: HoverLift(child: _ListingCard(m))))
                          .toList(),
                    );
                  },
                );

            return ListView(
              padding: const EdgeInsets.all(AppSpacing.x16),
              children: [
                _DiscoveryHeader(
                  types: types.toList(),
                  popular: topCommunities,
                  resultCount: items.length,
                  filtersActive: filtersActive,
                ),
                const SizedBox(height: AppSpacing.x16),
                if (items.isEmpty)
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1100),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: AppSpacing.x16),
                          child: Center(
                            child: Column(children: [
                              const Icon(Icons.search_off_outlined, size: 40, color: AppColors.textMuted),
                              const SizedBox(height: AppSpacing.x8),
                              Text('No properties match your filters',
                                  style: t.titleMedium, textAlign: TextAlign.center),
                              const SizedBox(height: 4),
                              Text('Try a higher budget, a wider area, or fewer bedrooms.',
                                  textAlign: TextAlign.center, style: t.bodySmall?.copyWith(color: AppColors.textMuted)),
                              if (filtersActive) ...[
                                const SizedBox(height: AppSpacing.x12),
                                FilledButton.icon(
                                  onPressed: () {
                                    ref.read(_fPurpose.notifier).state = 'all';
                                    ref.read(_fType.notifier).state = 'all';
                                    ref.read(_fBeds.notifier).state = null;
                                    ref.read(_fPriceMin.notifier).state = null;
                                    ref.read(_fPriceMax.notifier).state = null;
                                    ref.read(_fQuery.notifier).state = '';
                                    ref.read(_fMine.notifier).state = false;
                                  },
                                  icon: const Icon(Icons.refresh, size: 18),
                                  label: const Text('Clear filters'),
                                ),
                              ],
                            ]),
                          ),
                        ),
                        if (all.isNotEmpty) ...[
                          const SizedBox(height: AppSpacing.x8),
                          Text('Recommended', style: t.titleMedium),
                          const SizedBox(height: AppSpacing.x8),
                          grid(all.take(6).toList()),
                        ],
                      ]),
                    ),
                  )
                else
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1100),
                      child: grid(items),
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

/// Premium discovery header: search (community / building / area / ref),
/// popular-community shortcuts, explore-by-goal, the compact filter pills, and a
/// live result count with a clear-all. Replaces the ERP-style filter row.
class _DiscoveryHeader extends ConsumerStatefulWidget {
  const _DiscoveryHeader({
    required this.types,
    required this.popular,
    required this.resultCount,
    required this.filtersActive,
  });
  final List<String> types;
  final List<String> popular;
  final int resultCount;
  final bool filtersActive;
  @override
  ConsumerState<_DiscoveryHeader> createState() => _DiscoveryHeaderState();
}

class _DiscoveryHeaderState extends ConsumerState<_DiscoveryHeader> {
  late final TextEditingController _qc = TextEditingController(text: ref.read(_fQuery));
  @override
  void dispose() {
    _qc.dispose();
    super.dispose();
  }

  void _goal(String purpose, String? sort) {
    ref.read(_fPurpose.notifier).state = purpose;
    if (sort != null) ref.read(_fSort.notifier).state = sort;
  }

  void _clear() {
    ref.read(_fPurpose.notifier).state = 'all';
    ref.read(_fType.notifier).state = 'all';
    ref.read(_fBeds.notifier).state = null;
    ref.read(_fPriceMin.notifier).state = null;
    ref.read(_fPriceMax.notifier).state = null;
    ref.read(_fQuery.notifier).state = '';
    ref.read(_fMine.notifier).state = false;
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final q = ref.watch(_fQuery);
    // Keep the field's text in sync when the query is set elsewhere (chips / clear).
    if (_qc.text != q) {
      _qc.value = TextEditingValue(text: q, selection: TextSelection.collapsed(offset: q.length));
    }
    Widget heading(String s) => Text(s,
        style: t.labelSmall?.copyWith(color: AppColors.textMuted, fontWeight: FontWeight.w700, letterSpacing: 0.5));

    const goals = [
      ('Buy a home', Icons.home_outlined, 'sale', null),
      ('Rent', Icons.vpn_key_outlined, 'rent', null),
      ('Invest', Icons.trending_up, 'sale', 'price_asc'),
    ];

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      TextField(
        controller: _qc,
        onChanged: (v) => ref.read(_fQuery.notifier).state = v,
        decoration: InputDecoration(
          hintText: 'Search community, building, area or ref…',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: q.isEmpty
              ? null
              : IconButton(icon: const Icon(Icons.close), onPressed: () => ref.read(_fQuery.notifier).state = ''),
          isDense: true,
        ),
      ),
      if (widget.popular.isNotEmpty) ...[
        const SizedBox(height: AppSpacing.x12),
        heading('POPULAR SEARCHES'),
        const SizedBox(height: 6),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final c in widget.popular)
            ActionChip(label: Text(c), onPressed: () => ref.read(_fQuery.notifier).state = c),
        ]),
      ],
      const SizedBox(height: AppSpacing.x12),
      heading('EXPLORE BY GOAL'),
      const SizedBox(height: 6),
      Wrap(spacing: 6, runSpacing: 6, children: [
        for (final g in goals)
          ActionChip(
            avatar: Icon(g.$2, size: 16, color: AppColors.primary),
            label: Text(g.$1),
            onPressed: () => _goal(g.$3, g.$4),
          ),
      ]),
      const SizedBox(height: AppSpacing.x12),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
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
            items: widget.types.map((tp) => (tp, tp == 'all' ? 'Any type' : _cap(tp))).toList(),
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
            label: 'Sort by',
            value: ref.watch(_fSort),
            items: const [('latest', 'Newest'), ('price_asc', 'Price: low → high'), ('price_desc', 'Price: high → low')],
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
        ]),
      ),
      const SizedBox(height: AppSpacing.x8),
      Row(children: [
        Expanded(
          child: Text('${widget.resultCount} ${widget.resultCount == 1 ? 'property' : 'properties'} found',
              style: t.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
        ),
        if (widget.filtersActive)
          TextButton.icon(onPressed: _clear, icon: const Icon(Icons.close, size: 16), label: const Text('Clear')),
      ]),
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

/// Photo count for a listing card overlay (cover + images array).
int _photoCount(Map<String, dynamic> l) {
  var n = '${l['cover_image'] ?? ''}'.trim().isNotEmpty ? 1 : 0;
  final im = l['images'];
  if (im is List) n += im.length;
  return n;
}

class _ListingCard extends StatelessWidget {
  const _ListingCard(this.l);
  final Map<String, dynamic> l;

  static Widget _pill(String text, Color c, TextTheme t) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: c.withValues(alpha: 0.92), borderRadius: BorderRadius.circular(AppSpacing.rFull)),
        child: Text(text, style: t.bodySmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w600)),
      );

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final price = num.tryParse('${l['price']}') ?? 0;
    final money = NumberFormat.currency(symbol: 'AED ', decimalDigits: 0).format(price);
    final cover = '${l['cover_image'] ?? ''}';
    final isRent = '${l['purpose']}' == 'rent';
    final building = '${l['building_name'] ?? ''}'.trim();
    final unit = '${l['unit_no'] ?? ''}'.trim();
    final community = '${l['community'] ?? ''}'.trim();
    final ptype = '${l['property_type'] ?? ''}'.trim();
    final agent = '${l['agent_name'] ?? ''}'.trim();
    final score = num.tryParse('${l['agent_score'] ?? ''}');
    final draft = l['is_visible'] == false;
    final title = building.isNotEmpty
        ? (unit.isNotEmpty ? '$building · Unit $unit' : building)
        : (ptype.isNotEmpty ? _cap(ptype) : 'Property');
    final beds = '${l['bedrooms'] ?? '-'}';
    final baths = '${l['bathrooms'] ?? '-'}';
    final sqft = l['size_sqft'] != null ? '${(num.tryParse('${l['size_sqft']}') ?? 0).toStringAsFixed(0)} sqft' : null;
    final highlights = <String>[
      if ('${l['furnishing'] ?? ''}'.trim().isNotEmpty) _cap('${l['furnishing']}'),
      if ('${l['view'] ?? ''}'.trim().isNotEmpty) '${l['view']}',
      if ('${l['status'] ?? ''}'.trim().isNotEmpty) _cap('${l['status']}'),
    ];

    Widget placeholder() => Container(
        color: AppColors.surface2,
        child: const Center(child: Icon(Icons.apartment_outlined, size: 40, color: AppColors.textSubtle)));
    Widget metric(IconData i, String v) => Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(i, size: 15, color: AppColors.textMuted),
          const SizedBox(width: 3),
          Text(v, style: t.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
        ]);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/listings/${l['id']}'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Image with overlays ──
            Stack(
              children: [
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: cover.isEmpty
                      ? placeholder()
                      : Image.network(cover, fit: BoxFit.cover, errorBuilder: (_, __, ___) => placeholder()),
                ),
                // Trust ribbons (Verified / New / Exclusive / Hot / Price reduced) — top-left.
                if (draft)
                  Positioned(left: 8, top: 8, child: _pill('Draft', AppColors.warning, t))
                else
                  Positioned(left: 8, top: 8, right: 56, child: ListingRibbons(listing: l)),
                // Save (top-right) — published only.
                if (!draft)
                  Positioned(
                    top: 4, right: 4,
                    child: DecoratedBox(
                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.85), shape: BoxShape.circle),
                      child: SaveListingButton(listingId: '${l['id']}'),
                    ),
                  ),
                if (_photoCount(l) > 1)
                  Positioned(
                    top: 54, right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.55), borderRadius: BorderRadius.circular(AppSpacing.rFull)),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.photo_library_outlined, size: 12, color: Colors.white),
                        const SizedBox(width: 3),
                        Text('${_photoCount(l)}',
                            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                      ]),
                    ),
                  ),
                // Location scrim overlay (bottom) — community + for-sale/rent.
                Positioned(
                  left: 0, right: 0, bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(10, 24, 8, 8),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                          begin: Alignment.topCenter, end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Color(0x99000000)]),
                    ),
                    child: Row(children: [
                      const Icon(Icons.place, size: 14, color: Colors.white),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(community.isNotEmpty ? community : 'UAE',
                            style: t.bodySmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w600),
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                      _pill(isRent ? 'For rent' : 'For sale', isRent ? AppColors.info : AppColors.primary, t),
                    ]),
                  ),
                ),
              ],
            ),
            // ── Decision-first info ──
            Padding(
              padding: const EdgeInsets.all(AppSpacing.x12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: t.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                if (community.isNotEmpty)
                  Text(community, style: t.bodySmall?.copyWith(color: AppColors.textMuted),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                if ('${l['ref_code'] ?? ''}'.trim().isNotEmpty)
                  Text('Ref ${l['ref_code']}',
                      style: t.bodySmall?.copyWith(color: AppColors.textSubtle, fontWeight: FontWeight.w600)),
                const SizedBox(height: AppSpacing.x4),
                Row(children: [
                  Expanded(
                    child: Text('$money${isRent ? ' / yr' : ''}',
                        style: t.titleLarge?.copyWith(fontWeight: FontWeight.w700, color: AppColors.primary)),
                  ),
                  if (ptype.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                          color: AppColors.surface2, borderRadius: BorderRadius.circular(AppSpacing.rFull)),
                      child: Text(_cap(ptype), style: t.labelSmall?.copyWith(color: AppColors.textMuted, fontWeight: FontWeight.w600)),
                    ),
                ]),
                const SizedBox(height: AppSpacing.x8),
                Row(children: [
                  metric(Icons.bed_outlined, beds),
                  const SizedBox(width: AppSpacing.x12),
                  metric(Icons.bathtub_outlined, baths),
                  if (sqft != null) ...[
                    const SizedBox(width: AppSpacing.x12),
                    metric(Icons.straighten, sqft),
                  ],
                ]),
                if (highlights.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.x8),
                  Wrap(spacing: 6, runSpacing: 4, children: [
                    for (final h in highlights.take(3))
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                            color: AppColors.success.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(AppSpacing.rFull)),
                        child: Text(h, style: t.labelSmall?.copyWith(color: AppColors.success, fontWeight: FontWeight.w600)),
                      ),
                  ]),
                ],
                if (agent.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.x8),
                  Row(children: [
                    CircleAvatar(
                      radius: 12, backgroundColor: AppColors.primaryTint,
                      child: Text(agent[0].toUpperCase(),
                          style: t.labelSmall?.copyWith(color: AppColors.primary, fontWeight: FontWeight.w700)),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(agent, style: t.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                    if (score != null && score > 0 && score <= 5) ...[
                      const Icon(Icons.star, size: 13, color: AppColors.accentGold),
                      const SizedBox(width: 2),
                      Text(score.toStringAsFixed(1), style: t.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
                    ],
                  ]),
                ],
                const SizedBox(height: AppSpacing.x12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => context.push('/listings/${l['id']}'),
                    child: const Text('View details'),
                  ),
                ),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}
