import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/app_dialog.dart';
import '../../core/widgets/responsive.dart';
import '../../core/widgets/status_badge.dart';
import '../marketplace/marketplace_taxonomy.dart';
import '../shell/app_shell.dart';

final myTendersProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  try {
    final d = await ref.read(apiClientProvider).get('/tenders/mine');
    return d is List ? d : [];
  } catch (_) {
    return [];
  }
});

final openTendersProvider = FutureProvider.autoDispose.family<List<dynamic>, String>((ref, kind) async {
  try {
    final d = await ref.read(apiClientProvider)
        .get('/tenders/open', query: kind == 'all' ? null : {'kind': kind});
    return d is List ? d : [];
  } catch (_) {
    return [];
  }
});

/// Tone for a tender request's lifecycle status.
BadgeTone tenderTone(String s) => switch (s) {
      'awarded' => BadgeTone.gold,
      'in_progress' => BadgeTone.warning,
      'completed' => BadgeTone.success,
      'cancelled' => BadgeTone.danger,
      _ => BadgeTone.neutral,
    };

class TendersScreen extends ConsumerStatefulWidget {
  const TendersScreen({super.key});
  @override
  ConsumerState<TendersScreen> createState() => _TendersScreenState();
}

class _TendersScreenState extends ConsumerState<TendersScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this);
  String _openKind = 'all';

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: NuzlAppBar(title: context.tr('Requests')),
      drawer: const NuzlDrawer(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _postDialog(context),
        icon: const Icon(Icons.post_add),
        label: Text(context.tr('Post request')),
      ),
      body: ResponsiveCenter(
        child: Column(children: [
          TabBar(controller: _tabs, tabs: [Tab(text: context.tr('My requests')), Tab(text: context.tr('Open to bid'))]),
          Expanded(child: TabBarView(controller: _tabs, children: [
            _myRequests(),
            _openRequests(),
          ])),
        ]),
      ),
    );
  }

  Widget _myRequests() {
    final reqs = ref.watch(myTendersProvider);
    return RefreshIndicator(
      onRefresh: () async => ref.refresh(myTendersProvider.future),
      child: reqs.when(
        loading: () => const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator())),
        error: (e, _) => ListView(children: [Padding(padding: const EdgeInsets.all(24), child: Text(friendlyError(e)))]),
        data: (list) => list.isEmpty
            ? _empty(context.tr('No requests yet'), context.tr('Post a service request or product RFQ and let providers quote.'))
            : ListView.separated(
                padding: const EdgeInsets.all(AppSpacing.x16),
                itemCount: list.length,
                separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.x8),
                itemBuilder: (_, i) => _TenderCard(Map<String, dynamic>.from(list[i]), mine: true),
              ),
      ),
    );
  }

  Widget _openRequests() {
    final reqs = ref.watch(openTendersProvider(_openKind));
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.x16, AppSpacing.x12, AppSpacing.x16, 0),
        child: Wrap(spacing: AppSpacing.x8, children: [
          for (final k in const ['all', 'service', 'product'])
            ChoiceChip(
              label: Text(context.tr(k == 'all' ? 'All' : k == 'service' ? 'Services' : 'Products')),
              selected: _openKind == k,
              onSelected: (_) => setState(() => _openKind = k),
            ),
        ]),
      ),
      Expanded(
        child: RefreshIndicator(
          onRefresh: () async => ref.refresh(openTendersProvider(_openKind).future),
          child: reqs.when(
            loading: () => const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator())),
            error: (e, _) => ListView(children: [Padding(padding: const EdgeInsets.all(24), child: Text(friendlyError(e)))]),
            data: (list) => list.isEmpty
                ? _empty(context.tr('No open requests'), context.tr('New service requests and RFQs in your categories appear here to bid on.'))
                : ListView.separated(
                    padding: const EdgeInsets.all(AppSpacing.x16),
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.x8),
                    itemBuilder: (_, i) => _TenderCard(Map<String, dynamic>.from(list[i]), mine: false),
                  ),
          ),
        ),
      ),
    ]);
  }

  Widget _empty(String title, String body) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return ListView(children: [
        const SizedBox(height: 80),
        Icon(Icons.assignment_outlined, size: 48, color: dark ? AppColors.dTextSubtle : AppColors.textSubtle),
        const SizedBox(height: 12),
        Center(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w700))),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Text(body, textAlign: TextAlign.center, style: TextStyle(color: dark ? AppColors.dTextMuted : AppColors.textMuted)),
        ),
      ]);
  }

  Future<void> _postDialog(BuildContext context) async {
    var kind = 'service';
    String? category;
    String? subcategory;
    DateTime? preferred;
    final title = TextEditingController();
    final desc = TextEditingController();
    final location = TextEditingController();
    final budget = TextEditingController();
    final qty = TextEditingController();
    final ok = await AppDialog.show<bool>(
      context,
      title: context.tr('Post a request'),
      maxWidth: 480,
      children: [
        StatefulBuilder(
          builder: (ctx, setS) {
          final dark = Theme.of(ctx).brightness == Brightness.dark;
          return Column(mainAxisSize: MainAxisSize.min, children: [
            DropdownButtonFormField<String>(
              initialValue: kind,
              decoration: InputDecoration(labelText: ctx.tr('Type')),
              items: [
                DropdownMenuItem(value: 'service', child: Text(ctx.tr('Service request'))),
                DropdownMenuItem(value: 'product', child: Text(ctx.tr('Product RFQ'))),
              ],
              onChanged: (v) => setS(() { kind = v ?? 'service'; category = null; subcategory = null; }),
            ),
            const SizedBox(height: AppSpacing.x8),
            DropdownButtonFormField<String>(
              key: ValueKey('tc-$kind'),
              initialValue: category,
              isExpanded: true,
              decoration: InputDecoration(labelText: ctx.tr('Category')),
              items: [for (final c in MarketplaceTaxonomy.categories(kind)) DropdownMenuItem(value: c, child: Text(c))],
              onChanged: (v) => setS(() { category = v; subcategory = null; }),
            ),
            const SizedBox(height: AppSpacing.x8),
            DropdownButtonFormField<String>(
              key: ValueKey('ts-$kind-$category'),
              initialValue: subcategory,
              isExpanded: true,
              decoration: InputDecoration(labelText: ctx.tr('Subcategory')),
              items: [for (final s in MarketplaceTaxonomy.subcategories(kind, category)) DropdownMenuItem(value: s, child: Text(s))],
              onChanged: category == null ? null : (v) => setS(() => subcategory = v),
            ),
            const SizedBox(height: AppSpacing.x8),
            TextField(controller: title, decoration: InputDecoration(labelText: '${ctx.tr('Title')} *', hintText: ctx.tr('e.g. Apartment painting'))),
            const SizedBox(height: AppSpacing.x8),
            TextField(controller: desc, maxLines: 2, decoration: InputDecoration(labelText: ctx.tr('Description'))),
            const SizedBox(height: AppSpacing.x8),
            TextField(controller: location, decoration: InputDecoration(labelText: ctx.tr('Location'), hintText: ctx.tr('e.g. Marina Heights'))),
            const SizedBox(height: AppSpacing.x8),
            Row(children: [
              Expanded(child: TextField(controller: budget, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: ctx.tr('Budget (AED)')))),
              if (kind == 'product') ...[
                const SizedBox(width: AppSpacing.x8),
                Expanded(child: TextField(controller: qty, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: ctx.tr('Quantity')))),
              ],
            ]),
            const SizedBox(height: AppSpacing.x8),
            Row(children: [
              Expanded(child: Text(preferred == null ? ctx.tr('Preferred date (optional)') : '${ctx.tr('Preferred')}: ${DateFormat('d MMM yyyy').format(preferred!)}',
                  style: TextStyle(color: dark ? AppColors.dTextMuted : AppColors.textMuted))),
              TextButton.icon(
                onPressed: () async {
                  final now = DateTime.now();
                  final d = await showDatePicker(context: ctx, firstDate: now, lastDate: now.add(const Duration(days: 365)), initialDate: now);
                  if (d != null) setS(() => preferred = d);
                },
                icon: const Icon(Icons.event, size: 18),
                label: Text(ctx.tr('Pick date')),
              ),
            ]),
          ]);
          },
        ),
      ],
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: Text(context.tr('Cancel'))),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(context.tr('Post'))),
      ],
    );
    if (ok != true) return;
    if (title.text.trim().isEmpty) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.tr('A title is required.'))));
      return;
    }
    try {
      await ref.read(apiClientProvider).post('/tenders', body: {
        'kind': kind,
        'category': category,
        'subcategory': subcategory,
        'title': title.text.trim(),
        'description': desc.text.trim(),
        'location': location.text.trim(),
        'budget': num.tryParse(budget.text.trim()),
        'quantity': kind == 'product' ? int.tryParse(qty.text.trim()) : null,
        'preferred_date': preferred?.toIso8601String().split('T').first,
      });
      ref.invalidate(myTendersProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.tr('Request posted — providers will be notified.'))));
      }
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
    }
  }
}

class _TenderCard extends StatelessWidget {
  const _TenderCard(this.m, {required this.mine});
  final Map<String, dynamic> m;
  final bool mine;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final status = '${m['status'] ?? 'open'}';
    final isProduct = '${m['kind']}' == 'product';
    final bids = int.tryParse('${m['bid_count'] ?? 0}') ?? 0;
    final budget = num.tryParse('${m['budget']}');
    final aed = NumberFormat.currency(symbol: 'AED ', decimalDigits: 0);
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSpacing.rCard),
        onTap: () => context.push('/tenders/${m['id']}'),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.x16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(isProduct ? Icons.inventory_2_outlined : Icons.handyman_outlined, size: 16, color: dark ? AppColors.dTextMuted : AppColors.textMuted),
              const SizedBox(width: 6),
              Text('${m['ref_code'] ?? ''}', style: t.labelSmall?.copyWith(color: dark ? AppColors.dTextMuted : AppColors.textMuted, fontWeight: FontWeight.w700)),
              const Spacer(),
              StatusBadge(status.replaceAll('_', ' '), tone: tenderTone(status)),
            ]),
            const SizedBox(height: 6),
            Text('${m['title'] ?? ''}', style: t.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
            if ('${m['category'] ?? ''}'.isNotEmpty || budget != null) ...[
              const SizedBox(height: 2),
              Text([
                if ('${m['category'] ?? ''}'.isNotEmpty) '${m['category']}',
                if (budget != null) '${context.tr('Budget')} ${aed.format(budget)}',
              ].join(' · '), style: t.bodySmall?.copyWith(color: dark ? AppColors.dTextMuted : AppColors.textMuted)),
            ],
            const SizedBox(height: AppSpacing.x8),
            Row(children: [
              Icon(Icons.request_quote_outlined, size: 14, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 4),
              Text(mine
                      ? '$bids ${context.tr(bids == 1 ? 'quote' : 'quotes')} ${context.tr('received')}'
                      : '$bids ${context.tr(bids == 1 ? 'quote' : 'quotes')} ${context.tr('so far')}',
                  style: t.bodySmall?.copyWith(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w600)),
              const Spacer(),
              Text(context.tr(mine ? 'Compare →' : 'View & bid →'), style: t.bodySmall?.copyWith(color: Theme.of(context).colorScheme.primary)),
            ]),
          ]),
        ),
      ),
    );
  }
}
