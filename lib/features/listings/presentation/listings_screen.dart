import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/network/api_client.dart';
import '../../../core/rbac/persona.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/util/mortgage_math.dart';
import '../../../core/widgets/hover_lift.dart';
import '../../../core/widgets/hover_zoom_image.dart';
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
final _fArea = StateProvider.autoDispose<String?>((ref) => null);
final _fSort = StateProvider.autoDispose<String>((ref) => 'latest');
final _fMine = StateProvider.autoDispose<bool>((ref) => false);
/// Global property search query (community / building / area / ref-code). Public
/// so the dashboard search bar can seed it before routing to /properties.
final listingsSearchProvider = StateProvider<String>((ref) => '');

/// Affordability ceiling (AED) seeded by the Finance Planner's "Browse in budget"
/// CTA — when set, the list only shows properties at or under this price.
final listingsBudgetProvider = StateProvider<double?>((ref) => null);

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
    final area = ref.watch(_fArea);
    final sort = ref.watch(_fSort);
    final mine = ref.watch(_fMine);
    final query = ref.watch(listingsSearchProvider).trim().toLowerCase();
    final budget = ref.watch(listingsBudgetProvider);
    final myId = ref.watch(authControllerProvider).user?.id;
    final t = Theme.of(context).textTheme;
    final dark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: NuzlAppBar(title: 'Properties', actions: [
        // Quick access to the viewings the user has booked / scheduled.
        IconButton(
          tooltip: 'Viewings booked',
          icon: const Icon(Icons.event_available_outlined),
          onPressed: () => context.push('/viewings'),
        ),
        // Saved lives inside Properties (combined nav) — bookmark opens it.
        IconButton(
          tooltip: 'Saved',
          icon: const Icon(Icons.bookmark_outline),
          onPressed: () => context.push('/saved'),
        ),
        if (canList)
          IconButton(
            tooltip: 'Import properties',
            icon: const Icon(Icons.upload_file_outlined),
            onPressed: () => context.push('/properties/import'),
          ),
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
          error: (e, _) => Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(friendlyError(e)))),
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
              if (area != null && '${m['community'] ?? ''}'.trim() != area) return false;
              if (budget != null && priceOf(m) > budget) return false;
              if (query.isNotEmpty) {
                final hay = '${m['community'] ?? ''} ${m['property_type'] ?? ''} '
                        '${m['building_name'] ?? ''} ${m['unit_no'] ?? ''} '
                        '${m['ref_code'] ?? ''} ${m['description'] ?? ''}'
                    .toLowerCase();
                if (!hay.contains(query)) return false;
              }
              return true;
            }).toList();
            // sort — 'latest' keeps the server order (created_at desc). When a
            // budget is active, default to most-affordable first (price asc).
            if (sort == 'price_asc') {
              items.sort((a, b) => priceOf(a).compareTo(priceOf(b)));
            } else if (sort == 'price_desc') {
              items.sort((a, b) => priceOf(b).compareTo(priceOf(a)));
            } else if (budget != null) {
              items.sort((a, b) => priceOf(a).compareTo(priceOf(b)));
            }

            // Popular communities (most-listed) for quick-search chips.
            final counts = <String, int>{};
            for (final m in all) {
              final c = '${m['community'] ?? ''}'.trim();
              if (c.isNotEmpty) counts[c] = (counts[c] ?? 0) + 1;
            }
            final topCommunities = (counts.keys.toList()
                  ..sort((a, b) => counts[b]!.compareTo(counts[a]!)))
                .take(8)
                .toList();
            final allCommunities = counts.keys.toList()..sort();
            final filtersActive = purpose != 'all' || type != 'all' || beds != null ||
                priceMin != null || priceMax != null || area != null || query.isNotEmpty || mine;

            Widget grid(List<Map<String, dynamic>> data) => LayoutBuilder(
                  builder: (ctx, c) {
                    // Slightly wider cards (fewer columns) so the photo is the hero.
                    final cols = c.maxWidth >= 1120 ? 3 : (c.maxWidth >= 680 ? 2 : 1);
                    final cardW = cols == 1 ? c.maxWidth : (c.maxWidth - (cols - 1) * AppSpacing.x16) / cols;
                    // Fixed card height = 3:2 hero image + a compact content area → all
                    // cards are exactly equal height (content can't overflow the buffer).
                    // Buffer fits the tightened card body (title + grouped location/ref +
                    // price + specs + tags + agent + button) on a fixed-aspect grid cell.
                    // +60 when a budget is active to fit the affordability strip.
                    final cardH = cardW * 2 / 3 + 232 + (budget != null ? 60 : 0);
                    return GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: cols,
                      crossAxisSpacing: AppSpacing.x16,
                      mainAxisSpacing: AppSpacing.x16,
                      childAspectRatio: cardW / cardH,
                      children: data.map((m) => HoverLift(child: _ListingCard(m, budget: budget))).toList(),
                    );
                  },
                );

            return ListView(
              padding: const EdgeInsets.all(AppSpacing.x16),
              children: [
                _DiscoveryHeader(
                  types: types.toList(),
                  popular: topCommunities,
                  communities: allCommunities,
                  resultCount: items.length,
                  filtersActive: filtersActive,
                ),
                if (budget != null) ...[
                  const SizedBox(height: AppSpacing.x12),
                  _BudgetBar(
                    budget: budget,
                    resultCount: items.length,
                    onClear: () => ref.read(listingsBudgetProvider.notifier).state = null,
                  ),
                ],
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
                              Icon(Icons.search_off_outlined, size: 40, color: dark ? AppColors.dTextMuted : AppColors.textMuted),
                              const SizedBox(height: AppSpacing.x8),
                              Text('No properties match your filters',
                                  style: t.titleMedium, textAlign: TextAlign.center),
                              const SizedBox(height: 4),
                              Text('Try a higher budget, a wider area, or fewer bedrooms.',
                                  textAlign: TextAlign.center, style: t.bodySmall?.copyWith(color: dark ? AppColors.dTextMuted : AppColors.textMuted)),
                              if (filtersActive) ...[
                                const SizedBox(height: AppSpacing.x12),
                                FilledButton.icon(
                                  onPressed: () {
                                    ref.read(_fPurpose.notifier).state = 'all';
                                    ref.read(_fType.notifier).state = 'all';
                                    ref.read(_fBeds.notifier).state = null;
                                    ref.read(_fPriceMin.notifier).state = null;
                                    ref.read(_fPriceMax.notifier).state = null;
                                    ref.read(listingsSearchProvider.notifier).state = '';
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
    required this.communities,
    required this.resultCount,
    required this.filtersActive,
  });
  final List<String> types;
  final List<String> popular;
  final List<String> communities;
  final int resultCount;
  final bool filtersActive;
  @override
  ConsumerState<_DiscoveryHeader> createState() => _DiscoveryHeaderState();
}

class _DiscoveryHeaderState extends ConsumerState<_DiscoveryHeader> {
  late final TextEditingController _qc = TextEditingController(text: ref.read(listingsSearchProvider));
  @override
  void dispose() {
    _qc.dispose();
    super.dispose();
  }

  // 0 Buy → for sale; 1 Rent → for rent; 2 Invest → for sale, cheapest first.
  void _setGoal(int i) {
    switch (i) {
      case 0:
        ref.read(_fPurpose.notifier).state = 'sale';
        if (ref.read(_fSort) == 'price_asc') ref.read(_fSort.notifier).state = 'latest';
        break;
      case 1:
        ref.read(_fPurpose.notifier).state = 'rent';
        break;
      case 2:
        ref.read(_fPurpose.notifier).state = 'sale';
        ref.read(_fSort.notifier).state = 'price_asc';
        break;
    }
  }

  void _clear() {
    ref.read(_fPurpose.notifier).state = 'all';
    ref.read(_fType.notifier).state = 'all';
    ref.read(_fBeds.notifier).state = null;
    ref.read(_fPriceMin.notifier).state = null;
    ref.read(_fPriceMax.notifier).state = null;
    ref.read(_fArea.notifier).state = null;
    ref.read(_fSort.notifier).state = 'latest';
    ref.read(listingsSearchProvider.notifier).state = '';
    ref.read(_fMine.notifier).state = false;
  }

  String _sortLabel(String sort, bool budgetOn) {
    if (sort == 'price_asc') return 'Price: low to high';
    if (sort == 'price_desc') return 'Price: high to low';
    return budgetOn ? 'Most affordable' : 'Newest';
  }

  // Filters tucked behind "More filters" (min price, area, my listings).
  int _advancedCount() {
    var n = 0;
    if (ref.read(_fPriceMin) != null) n++;
    if (ref.read(_fArea) != null) n++;
    if (ref.read(_fMine)) n++;
    return n;
  }

  Future<void> _openMoreFilters() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _MoreFiltersSheet(communities: widget.communities),
    );
    if (mounted) setState(() {}); // refresh the advanced-filter badge
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final q = ref.watch(listingsSearchProvider);
    // Keep the field's text in sync when the query is set elsewhere (chips / clear).
    if (_qc.text != q) {
      _qc.value = TextEditingValue(text: q, selection: TextSelection.collapsed(offset: q.length));
    }
    final purpose = ref.watch(_fPurpose);
    final sort = ref.watch(_fSort);
    final budgetOn = ref.watch(listingsBudgetProvider) != null;
    // Derive the active goal segment from purpose + sort so it stays in sync even
    // when the Purpose dropdown is changed directly. -1 = none selected.
    final goal = purpose == 'rent' ? 1 : (purpose == 'sale' ? (sort == 'price_asc' ? 2 : 0) : -1);
    final advanced = _advancedCount();

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // ── Search ──
      TextField(
        controller: _qc,
        onChanged: (v) => ref.read(listingsSearchProvider.notifier).state = v,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: 'Search area, building or ref (e.g. NUZL-DXB-90012)',
          prefixIcon: const Icon(Icons.search, size: 20),
          suffixIcon: q.isEmpty
              ? null
              : IconButton(icon: const Icon(Icons.close, size: 18), onPressed: () => ref.read(listingsSearchProvider.notifier).state = ''),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
      ),
      // ── Popular searches: single scrollable row of light pills ──
      if (widget.popular.isNotEmpty) ...[
        const SizedBox(height: AppSpacing.x8),
        SizedBox(
          height: 30,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: widget.popular.length,
            separatorBuilder: (_, __) => const SizedBox(width: 6),
            itemBuilder: (_, i) => _MiniPill(
              label: widget.popular[i],
              onTap: () => ref.read(listingsSearchProvider.notifier).state = widget.popular[i],
            ),
          ),
        ),
      ],
      // ── Goal segmented control ──
      const SizedBox(height: AppSpacing.x8),
      Align(
        alignment: Alignment.centerLeft,
        child: _GoalSegmented(active: goal, onSelect: _setGoal),
      ),
      // ── Primary filter pills + "Filters" on the same (3rd) row ──
      const SizedBox(height: AppSpacing.x8),
      Row(children: [
        Expanded(
          child: SingleChildScrollView(
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
            label: 'Price',
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
            items: const [('latest', 'Newest'), ('price_asc', 'Price: low → high'), ('price_desc', 'Price: high → low')],
            onChanged: (v) => ref.read(_fSort.notifier).state = v ?? 'latest',
          ),
            ]),
          ),
        ),
        const SizedBox(width: AppSpacing.x8),
        _MoreFiltersButton(count: advanced, onTap: _openMoreFilters),
      ]),
      // ── Result count + sort summary ──
      const SizedBox(height: AppSpacing.x12),
      Row(children: [
        Expanded(
          child: Text(
            '${widget.resultCount} ${widget.resultCount == 1 ? 'Result' : 'Results'} · Sorted by ${_sortLabel(sort, budgetOn)}',
            style: t.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        if (widget.filtersActive)
          TextButton.icon(
            onPressed: _clear,
            icon: const Icon(Icons.close, size: 16),
            label: const Text('Clear'),
            style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
          ),
      ]),
    ]);
  }
}

/// Compact, light popular-search pill (32px) — hover/tap only, no heavy border.
class _MiniPill extends StatelessWidget {
  const _MiniPill({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final t = Theme.of(context).textTheme;
    return Material(
      color: dark ? AppColors.dSurface2 : AppColors.surface2,
      borderRadius: BorderRadius.circular(AppSpacing.rFull),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSpacing.rFull),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Center(
            child: Text(label,
                style: t.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600, color: dark ? AppColors.dTextMuted : AppColors.text)),
          ),
        ),
      ),
    );
  }
}

/// Segmented Buy | Rent | Invest control — one container, active segment filled.
class _GoalSegmented extends StatelessWidget {
  const _GoalSegmented({required this.active, required this.onSelect});
  final int active; // -1 none, 0 Buy, 1 Rent, 2 Invest
  final ValueChanged<int> onSelect;
  static const _labels = ['Buy', 'Rent', 'Invest'];
  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final t = Theme.of(context).textTheme;
    final primary = Theme.of(context).colorScheme.primary;
    return Container(
      height: 36,
      decoration: BoxDecoration(
        color: dark ? AppColors.dSurface2 : AppColors.surface2,
        borderRadius: BorderRadius.circular(AppSpacing.rMd),
      ),
      padding: const EdgeInsets.all(3),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        for (var i = 0; i < _labels.length; i++)
          GestureDetector(
            onTap: () => onSelect(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: i == active ? (dark ? AppColors.dSurface : Colors.white) : Colors.transparent,
                borderRadius: BorderRadius.circular(AppSpacing.rSm),
                boxShadow: i == active
                    ? [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 4, offset: const Offset(0, 1))]
                    : null,
              ),
              child: Text(_labels[i],
                  style: t.bodySmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: i == active ? primary : (dark ? AppColors.dTextMuted : AppColors.textMuted))),
            ),
          ),
      ]),
    );
  }
}

/// "More filters" button with a count badge for the advanced filters in the sheet.
class _MoreFiltersButton extends StatelessWidget {
  const _MoreFiltersButton({required this.count, required this.onTap});
  final int count;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final primary = Theme.of(context).colorScheme.primary;
    final on = count > 0;
    return Material(
      color: on ? primary.withValues(alpha: 0.10) : Colors.transparent,
      borderRadius: BorderRadius.circular(AppSpacing.rMd),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSpacing.rMd),
        onTap: onTap,
        child: Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSpacing.rMd),
            border: Border.all(color: on ? primary.withValues(alpha: 0.35) : Theme.of(context).dividerColor),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.tune, size: 16, color: on ? primary : null),
            const SizedBox(width: 6),
            Text(on ? 'Filters · $count' : 'Filters',
                style: t.bodySmall?.copyWith(fontWeight: FontWeight.w600, color: on ? primary : null)),
          ]),
        ),
      ),
    );
  }
}

/// Progressive-disclosure sheet for advanced filters: min price, area, my listings.
class _MoreFiltersSheet extends ConsumerWidget {
  const _MoreFiltersSheet({required this.communities});
  final List<String> communities;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final canList = ref.watch(personaProvider).canListProperty;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 4, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('More filters', style: t.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: AppSpacing.x16),
        Text('Minimum price', style: t.labelLarge),
        const SizedBox(height: 6),
        _Drop<double?>(
          label: 'Min price',
          value: ref.watch(_fPriceMin),
          items: const [
            (null, 'Any min'),
            (500000.0, '≥ 500K'),
            (1000000.0, '≥ 1M'),
            (2000000.0, '≥ 2M'),
            (3000000.0, '≥ 3M'),
            (5000000.0, '≥ 5M'),
          ],
          onChanged: (v) => ref.read(_fPriceMin.notifier).state = v,
        ),
        const SizedBox(height: AppSpacing.x16),
        Text('Area', style: t.labelLarge),
        const SizedBox(height: 6),
        _Drop<String?>(
          label: 'Any area',
          value: ref.watch(_fArea),
          items: [(null, 'Any area'), for (final c in communities) (c, c)],
          onChanged: (v) => ref.read(_fArea.notifier).state = v,
        ),
        if (canList) ...[
          const SizedBox(height: AppSpacing.x16),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: Text('My listings only', style: t.bodyMedium),
            value: ref.watch(_fMine),
            onChanged: (v) => ref.read(_fMine.notifier).state = v,
          ),
        ],
        const SizedBox(height: AppSpacing.x16),
        Row(children: [
          TextButton(
            onPressed: () {
              ref.read(_fPriceMin.notifier).state = null;
              ref.read(_fArea.notifier).state = null;
              ref.read(_fMine.notifier).state = false;
            },
            child: const Text('Reset'),
          ),
          const Spacer(),
          FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Show results')),
        ]),
      ]),
    );
  }
}

/// Compact budget chip-bar: [✓ Budget Match] [AED 1.63M] [N results]  Clear.
class _BudgetBar extends StatelessWidget {
  const _BudgetBar({required this.budget, required this.resultCount, required this.onClear});
  final double budget;
  final int resultCount;
  final VoidCallback onClear;
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final primary = Theme.of(context).colorScheme.primary;
    final aed = NumberFormat.compactCurrency(symbol: 'AED ', decimalDigits: 2);
    Widget chip(Widget child, {Color? color}) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
              color: (color ?? primary).withValues(alpha: 0.10), borderRadius: BorderRadius.circular(AppSpacing.rFull)),
          child: child,
        );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(AppSpacing.rMd),
        border: Border.all(color: primary.withValues(alpha: 0.18)),
      ),
      child: Row(children: [
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              chip(Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.check_circle, size: 14, color: AppColors.success),
                const SizedBox(width: 4),
                Text('Budget match', style: t.labelMedium?.copyWith(color: AppColors.success, fontWeight: FontWeight.w700)),
              ]), color: AppColors.success),
              const SizedBox(width: 6),
              chip(Text('Up to ${aed.format(budget)}',
                  style: t.labelMedium?.copyWith(color: primary, fontWeight: FontWeight.w700))),
              const SizedBox(width: 6),
              chip(Text(resultCount == 1 ? '1 result' : '$resultCount results',
                  style: t.labelMedium?.copyWith(color: primary, fontWeight: FontWeight.w700))),
            ]),
          ),
        ),
        TextButton(
          onPressed: onClear,
          style: TextButton.styleFrom(visualDensity: VisualDensity.compact, padding: const EdgeInsets.symmetric(horizontal: 8)),
          child: const Text('Clear'),
        ),
      ]),
    );
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
    // "Active" = a non-default selection. 'all'/'latest'/null are the defaults.
    final on = value != null && '$value' != 'all' && '$value' != 'latest';
    final primary = Theme.of(context).colorScheme.primary;
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x12),
      decoration: BoxDecoration(
        color: on ? primary.withValues(alpha: 0.08) : null,
        borderRadius: BorderRadius.circular(AppSpacing.rMd),
        border: Border.all(color: on ? primary.withValues(alpha: 0.35) : Theme.of(context).dividerColor),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isDense: true,
          // No grey focus/hover fill — keep every pill visually identical.
          focusColor: Colors.transparent,
          icon: Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: on ? primary : Theme.of(context).hintColor),
          ),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600, color: on ? primary : Theme.of(context).textTheme.bodyMedium?.color),
          borderRadius: BorderRadius.circular(AppSpacing.rMd),
          hint: Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
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
  const _ListingCard(this.l, {this.budget});
  final Map<String, dynamic> l;
  /// When set (Browse-in-budget flow), the card shows per-property affordability.
  final double? budget;

  static Widget _pill(String text, Color c, TextTheme t) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: c.withValues(alpha: 0.92), borderRadius: BorderRadius.circular(AppSpacing.rFull)),
        child: Text(text, style: t.bodySmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w600)),
      );

  /// Per-property affordability for the Browse-in-budget flow: it passed the
  /// price filter, so it's finance-eligible — show the 20% down payment and an
  /// estimated monthly (80% LTV, 4.5%, 25yr).
  Widget _affordability(BuildContext context, double price, Color muted) {
    final t = Theme.of(context).textTheme;
    final c = Theme.of(context).colorScheme.primary;
    final aed = NumberFormat.compactCurrency(symbol: 'AED ', decimalDigits: 0);
    final down = price * 0.20;
    final monthly = MortgageMath.monthlyPayment(price * 0.80, 4.5, 300);
    Widget line(String label, String value) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: t.labelSmall?.copyWith(color: muted)),
          Text(value, style: t.bodySmall?.copyWith(fontWeight: FontWeight.w700)),
        ]);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.x8),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppSpacing.rMd),
        border: Border.all(color: c.withValues(alpha: 0.18)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.verified_outlined, size: 13, color: AppColors.success),
          const SizedBox(width: 4),
          Text('Finance-eligible', style: t.labelSmall?.copyWith(color: AppColors.success, fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 4),
        Row(children: [
          Expanded(child: line('Down (20%)', aed.format(down))),
          Expanded(child: line('Est. monthly', '${aed.format(monthly)}/mo')),
        ]),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    // Theme-aware muted tokens — textMuted/textSubtle are dim on a dark card.
    final dark = Theme.of(context).brightness == Brightness.dark;
    final muted = dark ? AppColors.dTextMuted : AppColors.textMuted;
    final subtle = dark ? AppColors.dTextSubtle : AppColors.textSubtle;
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
          Icon(i, size: 15, color: muted),
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
                ClipRect(
                  child: AspectRatio(
                    aspectRatio: 3 / 2,
                    child: cover.isEmpty
                        ? placeholder()
                        : HoverZoomImage(url: cover, placeholder: placeholder()),
                  ),
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
            // ── Decision-first info (price → title → location/ref grouped) ──
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.x12, AppSpacing.x12, AppSpacing.x12, AppSpacing.x12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                  Expanded(
                    child: Text('$money${isRent ? ' / yr' : ''}',
                        style: t.titleLarge?.copyWith(
                            fontSize: 21, fontWeight: FontWeight.w800, color: Theme.of(context).colorScheme.primary),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                  if (ptype.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                          color: AppColors.surface2, borderRadius: BorderRadius.circular(AppSpacing.rFull)),
                      child: Text(_cap(ptype), style: t.labelSmall?.copyWith(color: AppColors.textMuted, fontWeight: FontWeight.w600)),
                    ),
                ]),
                const SizedBox(height: 2),
                Text(title, style: t.titleSmall?.copyWith(fontSize: 15.5, fontWeight: FontWeight.w700),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Row(children: [
                  if (community.isNotEmpty)
                    Flexible(
                      child: Text(community, style: t.bodySmall?.copyWith(color: muted),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                  if (community.isNotEmpty && '${l['ref_code'] ?? ''}'.trim().isNotEmpty)
                    Text('  ·  ', style: t.bodySmall?.copyWith(color: subtle)),
                  if ('${l['ref_code'] ?? ''}'.trim().isNotEmpty)
                    Text('${l['ref_code']}',
                        style: t.bodySmall?.copyWith(color: subtle, fontWeight: FontWeight.w700, letterSpacing: 0.2)),
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
                if (budget != null && !isRent && price > 0) ...[
                  const SizedBox(height: AppSpacing.x8),
                  _affordability(context, price.toDouble(), muted),
                ],
                if (highlights.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.x8),
                  Wrap(spacing: 6, runSpacing: 4, children: [
                    for (final h in highlights.take(2))
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
                          style: t.labelSmall?.copyWith(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w700)),
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
                const SizedBox(height: AppSpacing.x8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => context.push('/listings/${l['id']}'),
                    style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
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
