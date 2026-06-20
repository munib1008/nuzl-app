import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/async_view.dart';
import '../../core/widgets/empty_state.dart';
import '../auth/application/auth_controller.dart';
import '../messages/data/messaging_repository.dart';
import '../shell/app_shell.dart';
import 'deal_board_repository.dart';

String _propLine(Map d) {
  final bn = '${d['building_name'] ?? ''}'.trim();
  final un = '${d['unit_no'] ?? ''}'.trim();
  final comm = '${d['community'] ?? ''}'.trim();
  final head = bn.isNotEmpty ? (un.isNotEmpty ? '$bn - $un' : bn) : (un.isNotEmpty ? 'Unit $un' : comm);
  return [head, if (head != comm) comm].where((s) => s.isNotEmpty).join(' · ');
}

/// Internal deal board (marketplace): agents broadcast deals; others browse,
/// filter by category, and chat the poster.
class DealBoardScreen extends ConsumerWidget {
  const DealBoardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deals = ref.watch(dealBoardProvider);
    final myId = ref.watch(authControllerProvider).user?.id;
    return Scaffold(
      appBar: const NuzlAppBar(title: 'Deal board'),
      drawer: const NuzlDrawer(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _postDeal(context, ref),
        icon: const Icon(Icons.campaign_outlined),
        label: const Text('Post a deal'),
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(dealBoardProvider),
        child: AsyncView<List<Map<String, dynamic>>>(
          value: deals,
          onRetry: () => ref.invalidate(dealBoardProvider),
          data: (list) => list.isEmpty
              ? ListView(children: const [
                  EmptyState(
                    icon: Icons.campaign_outlined,
                    title: 'No deals on the board yet',
                    message: 'Post a deal to share it with the network and find a co-broker.',
                  ),
                ])
              : ListView(
                  padding: const EdgeInsets.all(AppSpacing.x16),
                  children: [for (final d in list) _DealCard(d, mine: '${d['agent_id']}' == myId)],
                ),
        ),
      ),
    );
  }

  Future<void> _postDeal(BuildContext context, WidgetRef ref) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _PostDealSheet(),
    );
    if (saved == true) ref.invalidate(dealBoardProvider);
  }
}

class _DealCard extends ConsumerWidget {
  const _DealCard(this.d, {required this.mine});
  final Map<String, dynamic> d;
  final bool mine;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final cat = '${d['category'] ?? ''}';
    final price = num.tryParse('${d['asking_price']}') ?? 0;
    final money = price > 0 ? NumberFormat.compactCurrency(symbol: 'AED ', decimalDigits: 0).format(price) : null;
    final expiry = DateTime.tryParse('${d['expiry'] ?? ''}');
    final propLine = _propLine(d);
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.x12),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.x16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: AppColors.accentGoldTint, borderRadius: BorderRadius.circular(AppSpacing.rFull)),
              child: Text(dealCategoryLabels[cat] ?? cat,
                  style: t.labelSmall?.copyWith(color: AppColors.accentGold, fontWeight: FontWeight.w700)),
            ),
            const Spacer(),
            if (money != null) Text(money, style: t.titleMedium),
          ]),
          const SizedBox(height: AppSpacing.x8),
          Text('${d['title'] ?? ''}', style: t.titleSmall),
          if (propLine.isNotEmpty)
            Text(propLine, style: t.bodySmall?.copyWith(color: AppColors.textMuted)),
          Text([
            if (d['bedrooms'] != null) '${d['bedrooms']} BR',
            if (d['size_sqft'] != null) '${num.tryParse('${d['size_sqft']}')?.toStringAsFixed(0)} sqft',
            if ('${d['view'] ?? ''}'.isNotEmpty) '${d['view']}',
            if ('${d['commission_share'] ?? ''}'.isNotEmpty) 'comm ${d['commission_share']}',
          ].where((s) => s.isNotEmpty).join('  ·  '), style: t.bodySmall),
          if ('${d['note'] ?? ''}'.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.x4),
            Text('${d['note']}', style: t.bodyMedium),
          ],
          const SizedBox(height: AppSpacing.x8),
          Row(children: [
            Expanded(
              child: Text([
                if (d['agent_name'] != null) '${d['agent_name']}',
                if (expiry != null) 'until ${DateFormat.yMMMd().format(expiry)}',
              ].join('  ·  '), style: t.bodySmall?.copyWith(color: AppColors.textMuted)),
            ),
            if (mine)
              TextButton(
                onPressed: () async {
                  try {
                    await ref.read(dealBoardRepoProvider).close('${d['id']}');
                    ref.invalidate(dealBoardProvider);
                  } catch (e) {
                    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
                  }
                },
                child: const Text('Close'),
              )
            else
              FilledButton.icon(
                onPressed: () => _chat(context, ref),
                icon: const Icon(Icons.chat_bubble_outline, size: 16),
                label: const Text('Chat'),
              ),
          ]),
        ]),
      ),
    );
  }

  Future<void> _chat(BuildContext context, WidgetRef ref) async {
    try {
      final convId = await ref.read(messagingRepositoryProvider)
          .startDirect('${d['agent_id']}', contextTable: 'deal_broadcasts', contextId: '${d['id']}');
      if (convId.isNotEmpty && context.mounted) context.push('/messages/$convId');
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
    }
  }
}

class _PostDealSheet extends ConsumerStatefulWidget {
  const _PostDealSheet();
  @override
  ConsumerState<_PostDealSheet> createState() => _PostDealSheetState();
}

class _PostDealSheetState extends ConsumerState<_PostDealSheet> {
  final _title = TextEditingController();
  final _building = TextEditingController();
  final _unit = TextEditingController();
  final _community = TextEditingController();
  final _beds = TextEditingController();
  final _price = TextEditingController();
  final _commission = TextEditingController();
  final _note = TextEditingController();
  String _category = 'hot_deal';
  String _visibility = 'verified';
  bool _saving = false;

  @override
  void dispose() {
    for (final c in [_title, _building, _unit, _community, _beds, _price, _commission, _note]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Add a title')));
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(dealBoardRepoProvider).create({
        'category': _category,
        'visibility': _visibility,
        'title': _title.text.trim(),
        'building_name': _building.text.trim(),
        'unit_no': _unit.text.trim(),
        'community': _community.text.trim(),
        'bedrooms': int.tryParse(_beds.text.trim()),
        'asking_price': double.tryParse(_price.text.trim()),
        'commission_share': _commission.text.trim(),
        'note': _note.text.trim(),
      });
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(AppSpacing.x16, AppSpacing.x16, AppSpacing.x16, bottom + AppSpacing.x16),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Post a deal', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.x12),
          DropdownButtonFormField<String>(
            initialValue: _category,
            decoration: const InputDecoration(labelText: 'Category'),
            items: [for (final e in dealCategoryLabels.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
            onChanged: (v) => setState(() => _category = v ?? 'hot_deal'),
          ),
          const SizedBox(height: AppSpacing.x8),
          DropdownButtonFormField<String>(
            initialValue: _visibility,
            decoration: const InputDecoration(labelText: 'Visible to'),
            items: const [
              DropdownMenuItem(value: 'verified', child: Text('Verified agents')),
              DropdownMenuItem(value: 'company', child: Text('My company')),
              DropdownMenuItem(value: 'team', child: Text('My team')),
              DropdownMenuItem(value: 'public', child: Text('Public — incl. customers')),
            ],
            onChanged: (v) => setState(() => _visibility = v ?? 'verified'),
          ),
          const SizedBox(height: AppSpacing.x8),
          TextField(controller: _title, decoration: const InputDecoration(labelText: 'Title *', hintText: 'e.g. Distress 2BR Marina')),
          const SizedBox(height: AppSpacing.x8),
          Row(children: [
            Expanded(child: TextField(controller: _building, decoration: const InputDecoration(labelText: 'Building'))),
            const SizedBox(width: AppSpacing.x8),
            Expanded(child: TextField(controller: _unit, decoration: const InputDecoration(labelText: 'Unit'))),
          ]),
          const SizedBox(height: AppSpacing.x8),
          TextField(controller: _community, decoration: const InputDecoration(labelText: 'Community')),
          const SizedBox(height: AppSpacing.x8),
          Row(children: [
            Expanded(child: TextField(controller: _beds, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Bedrooms'))),
            const SizedBox(width: AppSpacing.x8),
            Expanded(child: TextField(controller: _price, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Asking price (AED)'))),
          ]),
          const SizedBox(height: AppSpacing.x8),
          TextField(controller: _commission, decoration: const InputDecoration(labelText: 'Commission share', hintText: 'e.g. 50/50')),
          const SizedBox(height: AppSpacing.x8),
          TextField(controller: _note, maxLines: 2, decoration: const InputDecoration(labelText: 'Note')),
          const SizedBox(height: AppSpacing.x16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Broadcast'),
            ),
          ),
        ]),
      ),
    );
  }
}
