import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/network/api_client.dart';
import '../../core/rbac/persona.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/app_dialog.dart';
import '../../core/widgets/hover_lift.dart';
import '../../core/widgets/skeleton_loader.dart';
import '../../core/widgets/status_badge.dart';
import '../shell/app_shell.dart';
import 'marketplace_taxonomy.dart';

final marketplaceProvider = FutureProvider.autoDispose.family<List<dynamic>, String>((ref, kind) async {
  try {
    final d = await ref.read(apiClientProvider).get('/marketplace', query: {'kind': kind});
    return d is List ? d : [];
  } catch (_) {
    return [];
  }
});

class MarketplaceScreen extends ConsumerWidget {
  const MarketplaceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final persona = ref.watch(personaProvider);
    final canAdd = persona.canListMarketplace;
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: const NuzlAppBar(title: 'Marketplace'),
        drawer: const NuzlDrawer(),
        floatingActionButton: canAdd
            ? FloatingActionButton.extended(
                onPressed: () => _addDialog(context, ref),
                icon: const Icon(Icons.add),
                label: const Text('List item'),
              )
            : null,
        body: const Column(children: [
          Material(child: TabBar(tabs: [Tab(text: 'Services'), Tab(text: 'Products')])),
          Expanded(
            child: TabBarView(children: [
              _MarketList(kind: 'service'),
              _MarketList(kind: 'product'),
            ]),
          ),
        ]),
      ),
    );
  }

  Future<void> _addDialog(BuildContext context, WidgetRef ref) async {
    var kind = 'service';
    String? category;
    String? subcategory;
    final title = TextEditingController();
    final desc = TextEditingController();
    final price = TextEditingController();
    final unit = TextEditingController();
    final delivery = TextEditingController();
    final contact = TextEditingController();
    final ok = await AppDialog.show<bool>(
      context,
      title: 'List a service / product',
      maxWidth: 460,
      children: [
        StatefulBuilder(
          builder: (ctx, setS) => Column(mainAxisSize: MainAxisSize.min, children: [
            DropdownButtonFormField<String>(
              initialValue: kind,
              decoration: const InputDecoration(labelText: 'Type'),
              items: const [
                DropdownMenuItem(value: 'service', child: Text('Service')),
                DropdownMenuItem(value: 'product', child: Text('Product')),
              ],
              // Switching kind invalidates the chosen category/subcategory.
              onChanged: (v) => setS(() { kind = v ?? 'service'; category = null; subcategory = null; }),
            ),
            const SizedBox(height: AppSpacing.x8),
            TextField(controller: title, decoration: const InputDecoration(labelText: 'Title')),
            const SizedBox(height: AppSpacing.x8),
            DropdownButtonFormField<String>(
              key: ValueKey('cat-$kind'),
              initialValue: category,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Category'),
              items: [
                for (final c in MarketplaceTaxonomy.categories(kind))
                  DropdownMenuItem(value: c, child: Text(c)),
              ],
              onChanged: (v) => setS(() { category = v; subcategory = null; }),
            ),
            const SizedBox(height: AppSpacing.x8),
            DropdownButtonFormField<String>(
              key: ValueKey('sub-$kind-$category'),
              initialValue: subcategory,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Subcategory'),
              items: [
                for (final s in MarketplaceTaxonomy.subcategories(kind, category))
                  DropdownMenuItem(value: s, child: Text(s)),
              ],
              onChanged: category == null ? null : (v) => setS(() => subcategory = v),
            ),
            const SizedBox(height: AppSpacing.x8),
            TextField(controller: desc, maxLines: 2, decoration: const InputDecoration(labelText: 'Description')),
            const SizedBox(height: AppSpacing.x8),
            Row(children: [
              Expanded(child: TextField(controller: price, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Price (AED)'))),
              const SizedBox(width: AppSpacing.x8),
              Expanded(child: TextField(controller: unit, decoration: const InputDecoration(labelText: 'Unit', hintText: 'each / from'))),
            ]),
            const SizedBox(height: AppSpacing.x8),
            Row(children: [
              Expanded(
                child: TextField(
                    controller: delivery,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Lead time (days)', hintText: 'e.g. 3')),
              ),
              const SizedBox(width: AppSpacing.x8),
              Expanded(child: TextField(controller: contact, decoration: const InputDecoration(labelText: 'Contact'))),
            ]),
          ]),
        ),
      ],
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        FilledButton(
          // Validate BEFORE closing so the form (and the user's input) stays put
          // on failure instead of being discarded.
          onPressed: () {
            final missing = <String>[
              if (title.text.trim().isEmpty) 'a title',
              if (category == null) 'a category',
            ];
            if (missing.isNotEmpty) {
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(SnackBar(content: Text('Please add ${missing.join(' and ')}.')));
              return;
            }
            Navigator.pop(context, true);
          },
          child: const Text('List'),
        ),
      ],
    );
    if (ok != true) return;
    try {
      final res = await ref.read(apiClientProvider).post('/marketplace', body: {
        'kind': kind,
        'title': title.text.trim(),
        'category': category,
        'subcategory': subcategory,
        'description': desc.text.trim(),
        'price': num.tryParse(price.text.trim()),
        'price_unit': unit.text.trim(),
        'delivery_days': int.tryParse(delivery.text.trim()),
        'contact': contact.text.trim(),
      });
      ref.invalidate(marketplaceProvider(kind));
      final draft = res is Map && res['is_active'] == false;
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(draft
              ? 'Saved as draft — it publishes once your company is verified.'
              : 'Listed'),
        ));
      }
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }
}

class _MarketList extends ConsumerStatefulWidget {
  const _MarketList({required this.kind});
  final String kind;
  @override
  ConsumerState<_MarketList> createState() => _MarketListState();
}

class _MarketListState extends ConsumerState<_MarketList> {
  String _q = '';
  String? _cat;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final items = ref.watch(marketplaceProvider(widget.kind));
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(marketplaceProvider(widget.kind));
        await ref.read(marketplaceProvider(widget.kind).future);
      },
      child: items.when(
        loading: () => ListView(
          padding: const EdgeInsets.all(AppSpacing.x16),
          children: const [SkeletonListingGrid(count: 6)],
        ),
        error: (e, _) => ListView(children: [Padding(padding: const EdgeInsets.all(24), child: Center(child: Text('$e')))]),
        data: (raw) {
          final all = raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
          final cats = <String>{
            for (final m in all)
              if ('${m['category'] ?? ''}'.trim().isNotEmpty) '${m['category']}'.trim()
          }.toList()
            ..sort();
          final q = _q.trim().toLowerCase();
          final filtered = all.where((m) {
            if (_cat != null && '${m['category'] ?? ''}'.trim() != _cat) return false;
            if (q.isNotEmpty) {
              final hay =
                  '${m['title'] ?? ''} ${m['description'] ?? ''} ${m['category'] ?? ''} ${m['supplier_org'] ?? ''} ${m['supplier_name'] ?? ''}'
                      .toLowerCase();
              if (!hay.contains(q)) return false;
            }
            return true;
          }).toList();

          return ListView(
            padding: const EdgeInsets.all(AppSpacing.x16),
            children: [
              TextField(
                onChanged: (v) => setState(() => _q = v),
                decoration: InputDecoration(
                  hintText: 'Search ${widget.kind == 'product' ? 'products' : 'services'}, suppliers…',
                  prefixIcon: const Icon(Icons.search),
                  isDense: true,
                ),
              ),
              if (cats.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.x12),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  ChoiceChip(
                      label: const Text('All'),
                      selected: _cat == null,
                      onSelected: (_) => setState(() => _cat = null)),
                  for (final c in cats)
                    ChoiceChip(
                        label: Text(c),
                        selected: _cat == c,
                        onSelected: (_) => setState(() => _cat = _cat == c ? null : c)),
                ]),
              ],
              const SizedBox(height: AppSpacing.x16),
              if (filtered.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(40),
                  child: Center(
                      child: Text(all.isEmpty ? 'Nothing here yet.' : 'No matches — try a different search or category.',
                          style: t.bodyMedium?.copyWith(color: AppColors.textMuted))),
                )
              else
                LayoutBuilder(builder: (ctx, cons) {
                  final cols = (cons.maxWidth / 320).floor().clamp(1, 4);
                  final w = (cons.maxWidth - (cols - 1) * AppSpacing.x12) / cols;
                  return Wrap(
                    spacing: AppSpacing.x12,
                    runSpacing: AppSpacing.x12,
                    children: [for (final m in filtered) SizedBox(width: w, child: _ItemCard(m))],
                  );
                }),
            ],
          );
        },
      ),
    );
  }
}

class _ItemCard extends ConsumerWidget {
  const _ItemCard(this.m);
  final Map<String, dynamic> m;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final price = num.tryParse('${m['price']}') ?? 0;
    final money = price > 0 ? NumberFormat.currency(symbol: 'AED ', decimalDigits: 0).format(price) : '';
    final unit = '${m['price_unit'] ?? ''}'.trim();
    final category = '${m['category'] ?? ''}'.trim();
    final img = '${m['image_url'] ?? ''}';
    final isProduct = '${m['kind']}' == 'product';
    final org = '${m['supplier_org'] ?? ''}'.trim();
    final person = '${m['supplier_name'] ?? ''}'.trim();
    final supplier = org.isNotEmpty ? org : person;
    final rating = num.tryParse('${m['rating'] ?? ''}');
    final reviews = int.tryParse('${m['review_count'] ?? 0}') ?? 0;
    final delivery = int.tryParse('${m['delivery_days'] ?? ''}');
    final isActive = m['is_active'] != false; // legacy rows (null) treated as live
    final verified = m['supplier_verified'] == true;
    final logo = '${m['supplier_logo'] ?? ''}'.trim();

    return HoverLift(
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => context.push('/marketplace/${m['id']}'),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Stack(children: [
            AspectRatio(
              aspectRatio: 16 / 10,
              child: img.isNotEmpty
                  ? Image.network(img, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _thumb())
                  : _thumb(),
            ),
            if (category.isNotEmpty)
              Positioned(top: 8, left: 8, child: StatusBadge(category, tone: BadgeTone.neutral)),
            if (!isActive)
              const Positioned(top: 8, right: 8, child: StatusBadge('Draft', tone: BadgeTone.warning)),
          ]),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.x12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${m['title'] ?? ''}',
                  style: t.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                  maxLines: 2, overflow: TextOverflow.ellipsis),
              if (supplier.isNotEmpty) ...[
                const SizedBox(height: 3),
                Row(children: [
                  if (logo.isNotEmpty)
                    Container(
                      width: 16, height: 16,
                      margin: const EdgeInsets.only(right: 4),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        image: DecorationImage(image: NetworkImage(logo), fit: BoxFit.cover),
                      ),
                    )
                  else ...[
                    const Icon(Icons.storefront_outlined, size: 13, color: AppColors.textMuted),
                    const SizedBox(width: 4),
                  ],
                  Flexible(
                    child: Text(supplier,
                        style: t.bodySmall?.copyWith(color: AppColors.textMuted),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                  if (verified) ...[
                    const SizedBox(width: 4),
                    const Icon(Icons.verified, size: 13, color: AppColors.success),
                  ],
                ]),
              ],
              if (rating != null && reviews > 0) ...[
                const SizedBox(height: 4),
                Row(children: [
                  for (var i = 1; i <= 5; i++)
                    Icon(i <= rating.round() ? Icons.star : Icons.star_border, size: 13, color: AppColors.accentGold),
                  const SizedBox(width: 4),
                  Text('${rating.toStringAsFixed(1)} ($reviews)',
                      style: t.bodySmall?.copyWith(color: AppColors.textMuted)),
                ]),
              ],
              if (money.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text('$money${unit.isNotEmpty ? ' · $unit' : ''}',
                    style: t.titleMedium?.copyWith(color: AppColors.primary, fontWeight: FontWeight.w700)),
              ],
              if (delivery != null && delivery > 0) ...[
                const SizedBox(height: 6),
                Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(isProduct ? Icons.local_shipping_outlined : Icons.schedule, size: 13, color: AppColors.success),
                  const SizedBox(width: 4),
                  Text(isProduct ? '~$delivery-day delivery' : '~$delivery-day lead time',
                      style: t.bodySmall?.copyWith(color: AppColors.success, fontWeight: FontWeight.w600)),
                ]),
              ],
              const SizedBox(height: AppSpacing.x12),
              Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _order(context, ref, quote: true),
                    style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(36), padding: EdgeInsets.zero),
                    child: const Text('Quote'),
                  ),
                ),
                const SizedBox(width: AppSpacing.x8),
                Expanded(
                  child: FilledButton(
                    onPressed: () => _order(context, ref),
                    style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(36), padding: EdgeInsets.zero),
                    child: Text(isProduct ? 'Buy' : 'Book'),
                  ),
                ),
              ]),
            ]),
          ),
        ]),
        ),
      ),
    );
  }

  Widget _thumb() => Container(
        color: AppColors.surface2,
        child: const Center(child: Icon(Icons.storefront_outlined, color: AppColors.textMuted, size: 36)),
      );

  /// Place an order (product) or book a service. `quote` records a quotation request.
  Future<void> _order(BuildContext context, WidgetRef ref, {bool quote = false}) async {
    try {
      await ref.read(apiClientProvider).post('/marketplace/orders', body: {
        'item_id': m['id'],
        if (quote) 'quote': true,
      });
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(quote ? 'Quotation requested — track it in Orders.' : 'Order placed — track it in Orders.'),
          action: SnackBarAction(label: 'View', onPressed: () => context.go('/orders')),
        ));
      }
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }
}
