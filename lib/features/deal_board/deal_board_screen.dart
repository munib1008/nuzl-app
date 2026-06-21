import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/async_view.dart';
import '../../core/widgets/place_field.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/user_avatar.dart';
import '../auth/application/auth_controller.dart';
import '../messages/data/messaging_repository.dart';
import '../crm/crm_scaffold.dart';
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
  const DealBoardScreen({super.key, this.embedded = false});

  /// When embedded (the Community "Deals" tab) render only the board body — no
  /// CrmScaffold and no FAB; the host supplies the app-bar + "Post a deal".
  final bool embedded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deals = ref.watch(dealBoardProvider);
    final myId = ref.watch(authControllerProvider).user?.id;
    final body = RefreshIndicator(
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
    );
    if (embedded) return body;
    return CrmScaffold(
      tab: CrmTab.dealBoard,
      title: 'Deal board',
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => openDealComposer(context, ref),
        icon: const Icon(Icons.campaign_outlined),
        label: const Text('Post a deal'),
      ),
      body: body,
    );
  }
}

/// Opens the "Post a deal" sheet and refreshes the board on save. Top-level so
/// both the standalone Deal Board and the Community "Deals" tab can trigger it.
Future<void> openDealComposer(BuildContext context, WidgetRef ref) async {
  final saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (_) => const _PostDealSheet(),
  );
  if (saved == true) ref.invalidate(dealBoardProvider);
}

class _DealCard extends ConsumerStatefulWidget {
  const _DealCard(this.d, {required this.mine});
  final Map<String, dynamic> d;
  final bool mine;
  @override
  ConsumerState<_DealCard> createState() => _DealCardState();
}

class _DealCardState extends ConsumerState<_DealCard> {
  bool _closed = false; // optimistic: hide as soon as Close is tapped
  Map<String, dynamic> get d => widget.d;
  bool get mine => widget.mine;

  @override
  Widget build(BuildContext context) {
    if (_closed) return const SizedBox.shrink();
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
          Text('${d['title'] ?? ''}', style: t.titleSmall, maxLines: 2, overflow: TextOverflow.ellipsis),
          if (propLine.isNotEmpty)
            Text(propLine, style: t.bodySmall?.copyWith(color: AppColors.textMuted),
                maxLines: 1, overflow: TextOverflow.ellipsis),
          Text([
            if (d['bedrooms'] != null) '${d['bedrooms']} BR',
            if (d['size_sqft'] != null) '${num.tryParse('${d['size_sqft']}')?.toStringAsFixed(0)} sqft',
            if ('${d['view'] ?? ''}'.isNotEmpty) '${d['view']}',
            if ('${d['commission_share'] ?? ''}'.isNotEmpty) 'comm ${d['commission_share']}',
          ].where((s) => s.isNotEmpty).join('  ·  '), style: t.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
          if ('${d['note'] ?? ''}'.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.x4),
            Text('${d['note']}', style: t.bodyMedium, maxLines: 8, overflow: TextOverflow.ellipsis),
          ],
          const SizedBox(height: AppSpacing.x8),
          Row(children: [
            UserAvatar(name: '${d['agent_name'] ?? ''}', url: '${d['agent_avatar'] ?? ''}', radius: 12),
            const SizedBox(width: AppSpacing.x8),
            Expanded(
              child: Text([
                if (d['agent_name'] != null) '${d['agent_name']}',
                if (expiry != null) 'until ${DateFormat.yMMMd().format(expiry)}',
              ].join('  ·  '), style: t.bodySmall?.copyWith(color: AppColors.textMuted),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
            if (mine)
              TextButton(
                onPressed: () async {
                  setState(() => _closed = true); // optimistic hide
                  try {
                    await ref.read(dealBoardRepoProvider).close('${d['id']}');
                  } catch (e) {
                    if (mounted) setState(() => _closed = false);
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
  double? _lat; // map pin from the place autocomplete
  double? _lng;

  @override
  void dispose() {
    for (final c in [_title, _building, _unit, _community, _beds, _price, _commission, _note]) {
      c.dispose();
    }
    super.dispose();
  }

  /// Paste a WhatsApp-style property message → fill the deal fields via the
  /// shared /deal-assistant/parse extractor (only fills empty fields).
  Future<void> _autoFill() async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Auto-fill from a message'),
        content: SizedBox(
          width: MediaQuery.sizeOf(ctx).width - 80 < 420 ? MediaQuery.sizeOf(ctx).width - 80 : 420,
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Paste a WhatsApp-style property message — we’ll extract the details.',
                style: TextStyle(fontSize: 13)),
            const SizedBox(height: AppSpacing.x12),
            TextField(
              controller: ctrl, autofocus: true, maxLines: 5,
              decoration: const InputDecoration(
                  hintText: 'e.g. Burj Crown 2BR 1066 sqft Canal View AED 3.1M', border: OutlineInputBorder()),
            ),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Extract')),
        ],
      ),
    );
    if (ok != true || ctrl.text.trim().isEmpty || !mounted) return;
    try {
      final res = await ref.read(apiClientProvider).post('/deal-assistant/parse', body: {'text': ctrl.text.trim()});
      final d = (res is Map && res['draft'] is Map) ? Map<String, dynamic>.from(res['draft']) : <String, dynamic>{};
      setState(() {
        if (d['building_name'] != null && _building.text.isEmpty) _building.text = '${d['building_name']}';
        if (d['unit_no'] != null && _unit.text.isEmpty) _unit.text = '${d['unit_no']}';
        if (d['community'] != null && _community.text.isEmpty) _community.text = '${d['community']}';
        if (d['bedrooms'] != null && _beds.text.isEmpty) _beds.text = '${d['bedrooms']}';
        if (d['price'] is num && _price.text.isEmpty) _price.text = (d['price'] as num).toStringAsFixed(0);
        if (_title.text.trim().isEmpty) {
          final br = d['bedrooms'] != null ? '${d['bedrooms']}BR ' : '';
          final t = '$br${d['building_name'] ?? d['community'] ?? ''}'.trim();
          if (t.isNotEmpty) _title.text = t;
        }
        final extra = [
          if ('${d['view'] ?? ''}'.trim().isNotEmpty) '${d['view']}',
          if (d['size_sqft'] is num) '${(d['size_sqft'] as num).toStringAsFixed(0)} sqft',
        ].join(' · ');
        if (extra.isNotEmpty && _note.text.trim().isEmpty) _note.text = extra;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Filled from your message — review and adjust.')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
    }
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
        if (_lat != null) 'latitude': _lat,
        if (_lng != null) 'longitude': _lng,
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
          const SizedBox(height: AppSpacing.x8),
          // Paste a WhatsApp-style blurb → pre-fill the deal (same extractor the
          // listing form uses).
          OutlinedButton.icon(
            onPressed: _saving ? null : _autoFill,
            icon: const Icon(Icons.auto_fix_high_outlined, size: 18),
            label: const Text('Auto-fill from a message'),
          ),
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
          PlaceField(
            controller: _community,
            label: 'Location / community',
            hint: 'Search a building, community or address…',
            onSelected: (p) => setState(() { _lat = p.lat; _lng = p.lng; }),
            onCleared: () => setState(() { _lat = null; _lng = null; }),
          ),
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
