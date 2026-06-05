import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/network/api_client.dart';
import '../../core/rbac/persona.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/status_badge.dart';
import '../shell/app_shell.dart';

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
    final canAdd = persona.canListProperty || persona.canManageLeads || persona == Persona.admin;
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
    final title = TextEditingController();
    final category = TextEditingController();
    final desc = TextEditingController();
    final price = TextEditingController();
    final unit = TextEditingController();
    final contact = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('List a service / product'),
        content: StatefulBuilder(
          builder: (ctx, setS) => SizedBox(
            width: 400,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                DropdownButtonFormField<String>(
                  initialValue: kind,
                  decoration: const InputDecoration(labelText: 'Type'),
                  items: const [
                    DropdownMenuItem(value: 'service', child: Text('Service')),
                    DropdownMenuItem(value: 'product', child: Text('Product')),
                  ],
                  onChanged: (v) => setS(() => kind = v ?? 'service'),
                ),
                const SizedBox(height: AppSpacing.x8),
                TextField(controller: title, decoration: const InputDecoration(labelText: 'Title')),
                const SizedBox(height: AppSpacing.x8),
                TextField(controller: category, decoration: const InputDecoration(labelText: 'Category')),
                const SizedBox(height: AppSpacing.x8),
                TextField(controller: desc, maxLines: 2, decoration: const InputDecoration(labelText: 'Description')),
                const SizedBox(height: AppSpacing.x8),
                Row(children: [
                  Expanded(child: TextField(controller: price, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Price (AED)'))),
                  const SizedBox(width: AppSpacing.x8),
                  Expanded(child: TextField(controller: unit, decoration: const InputDecoration(labelText: 'Unit', hintText: 'each / from'))),
                ]),
                const SizedBox(height: AppSpacing.x8),
                TextField(controller: contact, decoration: const InputDecoration(labelText: 'Contact')),
              ]),
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('List')),
        ],
      ),
    );
    if (ok != true || title.text.trim().isEmpty) return;
    try {
      await ref.read(apiClientProvider).post('/marketplace', body: {
        'kind': kind,
        'title': title.text.trim(),
        'category': category.text.trim(),
        'description': desc.text.trim(),
        'price': num.tryParse(price.text.trim()),
        'price_unit': unit.text.trim(),
        'contact': contact.text.trim(),
      });
      ref.invalidate(marketplaceProvider(kind));
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Listed')));
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }
}

class _MarketList extends ConsumerWidget {
  const _MarketList({required this.kind});
  final String kind;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(marketplaceProvider(kind));
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(marketplaceProvider(kind));
        await ref.read(marketplaceProvider(kind).future);
      },
      child: items.when(
        loading: () => const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator())),
        error: (e, _) => ListView(children: [Padding(padding: const EdgeInsets.all(24), child: Center(child: Text('$e')))]),
        data: (list) => list.isEmpty
            ? ListView(children: const [Padding(padding: EdgeInsets.all(48), child: Center(child: Text('Nothing here yet.')))])
            : ListView.separated(
                padding: const EdgeInsets.all(AppSpacing.x16),
                itemCount: list.length,
                separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.x12),
                itemBuilder: (_, i) => _ItemCard(Map<String, dynamic>.from(list[i])),
              ),
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
    final unit = '${m['price_unit'] ?? ''}';
    final category = '${m['category'] ?? ''}';
    final contact = '${m['contact'] ?? ''}';
    final img = '${m['image_url'] ?? ''}';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.x12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(AppSpacing.rSm),
              child: img.isNotEmpty
                  ? Image.network(img, width: 64, height: 64, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _thumb())
                  : _thumb(),
            ),
            const SizedBox(width: AppSpacing.x12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text('${m['title'] ?? ''}', style: t.titleSmall)),
                  if (category.isNotEmpty) StatusBadge(category, tone: BadgeTone.neutral),
                ]),
                if ('${m['description'] ?? ''}'.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text('${m['description']}', style: t.bodySmall?.copyWith(color: AppColors.textMuted)),
                ],
                if (money.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text('$money${unit.isNotEmpty ? ' · $unit' : ''}',
                      style: t.titleMedium?.copyWith(color: AppColors.primary, fontWeight: FontWeight.w700)),
                ],
              ]),
            ),
          ]),
          const SizedBox(height: AppSpacing.x8),
          Row(children: [
            if (contact.isNotEmpty)
              Expanded(child: Text(contact, style: t.bodySmall?.copyWith(color: AppColors.textMuted)))
            else
              const Spacer(),
            FilledButton(onPressed: () => _request(context, ref), child: const Text('Request')),
          ]),
        ]),
      ),
    );
  }

  Widget _thumb() => Container(
        width: 64,
        height: 64,
        color: AppColors.surface2,
        child: const Icon(Icons.storefront_outlined, color: AppColors.textMuted),
      );

  Future<void> _request(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(apiClientProvider).post('/marketplace/${m['id']}/request');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Request sent — the provider will reach out.')));
      }
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }
}
