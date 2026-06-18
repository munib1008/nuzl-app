import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_dialog.dart';
import '../../../core/widgets/responsive.dart';
import '../../../core/widgets/status_badge.dart';
import '../../shell/app_shell.dart';

final leadMarketProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  try {
    final d = await ref.read(apiClientProvider).get('/buyer-requirements/market');
    return d is List ? d : [];
  } catch (_) {
    return [];
  }
});

final myLeadClaimsProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  try {
    final d = await ref.read(apiClientProvider).get('/buyer-requirements/market/my-claims');
    return d is List ? d : [];
  } catch (_) {
    return [];
  }
});

final _myLeadsRawProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  try {
    final d = await ref.read(apiClientProvider).get('/buyer-requirements');
    return d is List ? d : [];
  } catch (_) {
    return [];
  }
});

final _aed = NumberFormat.currency(symbol: 'AED ', decimalDigits: 0);

class LeadMarketScreen extends ConsumerStatefulWidget {
  const LeadMarketScreen({super.key});
  @override
  ConsumerState<LeadMarketScreen> createState() => _LeadMarketScreenState();
}

class _LeadMarketScreenState extends ConsumerState<LeadMarketScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this);

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const NuzlAppBar(title: 'Lead Market'),
      drawer: const NuzlDrawer(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _listLead,
        icon: const Icon(Icons.sell_outlined),
        label: const Text('List a lead'),
      ),
      body: ResponsiveCenter(
        child: Column(children: [
          TabBar(controller: _tabs, tabs: const [Tab(text: 'Browse'), Tab(text: 'My claims')]),
          Expanded(child: TabBarView(controller: _tabs, children: [_browse(), _claims()])),
        ]),
      ),
    );
  }

  Widget _browse() {
    final market = ref.watch(leadMarketProvider);
    return RefreshIndicator(
      onRefresh: () async => ref.refresh(leadMarketProvider.future),
      child: market.when(
        loading: () => const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator())),
        error: (e, _) => ListView(children: [Padding(padding: const EdgeInsets.all(24), child: Text('$e'))]),
        data: (list) => list.isEmpty
            ? _empty('No leads on the market', 'Listed buyer leads from other members appear here to claim.')
            : ListView.separated(
                padding: const EdgeInsets.all(AppSpacing.x16),
                itemCount: list.length,
                separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.x8),
                itemBuilder: (_, i) => _MarketCard(Map<String, dynamic>.from(list[i])),
              ),
      ),
    );
  }

  Widget _claims() {
    final claims = ref.watch(myLeadClaimsProvider);
    return RefreshIndicator(
      onRefresh: () async => ref.refresh(myLeadClaimsProvider.future),
      child: claims.when(
        loading: () => const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator())),
        error: (e, _) => ListView(children: [Padding(padding: const EdgeInsets.all(24), child: Text('$e'))]),
        data: (list) => list.isEmpty
            ? _empty('No claimed leads', 'Leads you claim show their full contact details here.')
            : ListView.separated(
                padding: const EdgeInsets.all(AppSpacing.x16),
                itemCount: list.length,
                separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.x8),
                itemBuilder: (_, i) => _ClaimCard(Map<String, dynamic>.from(list[i])),
              ),
      ),
    );
  }

  Widget _empty(String title, String body) => ListView(children: [
        const SizedBox(height: 80),
        const Icon(Icons.sell_outlined, size: 48, color: AppColors.textSubtle),
        const SizedBox(height: 12),
        Center(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w700))),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Text(body, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textMuted)),
        ),
      ]);

  Future<void> _listLead() async {
    final leads = await ref.read(_myLeadsRawProvider.future);
    if (!mounted) return;
    final available = leads.map((e) => Map<String, dynamic>.from(e)).where((l) => l['is_listed'] != true).toList();
    if (available.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('You have no unlisted leads to put on the market.')));
      return;
    }
    String? leadId = available.first['id']?.toString();
    var exclusivity = 'shared';
    final price = TextEditingController();
    final ok = await AppDialog.show<bool>(
      context,
      title: 'List a lead for sale',
      maxWidth: 440,
      children: [
        StatefulBuilder(
          builder: (ctx, setS) => Column(mainAxisSize: MainAxisSize.min, children: [
            DropdownButtonFormField<String>(
              initialValue: leadId,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Lead'),
              items: [
                for (final l in available)
                  DropdownMenuItem(
                    value: l['id'].toString(),
                    child: Text(_leadLabel(l), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: (v) => setS(() => leadId = v),
            ),
            const SizedBox(height: AppSpacing.x8),
            TextField(controller: price, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Price (AED)')),
            const SizedBox(height: AppSpacing.x12),
            Align(
              alignment: Alignment.centerLeft,
              child: SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'shared', label: Text('Shared'), icon: Icon(Icons.groups_outlined, size: 16)),
                  ButtonSegment(value: 'exclusive', label: Text('Exclusive'), icon: Icon(Icons.lock_outline, size: 16)),
                ],
                selected: {exclusivity},
                onSelectionChanged: (s) => setS(() => exclusivity = s.first),
              ),
            ),
          ]),
        ),
      ],
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('List')),
      ],
    );
    if (ok != true || leadId == null) return;
    try {
      await ref.read(apiClientProvider).post('/buyer-requirements/$leadId/list', body: {
        'price': num.tryParse(price.text.trim()),
        'exclusivity': exclusivity,
      });
      ref.invalidate(leadMarketProvider);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lead listed on the market')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  String _leadLabel(Map<String, dynamic> l) {
    final parts = [
      if ('${l['property_type'] ?? ''}'.isNotEmpty) '${l['property_type']}',
      if ('${l['purpose'] ?? ''}'.isNotEmpty) 'for ${l['purpose']}',
      if (l['buyer_name'] != null) '· ${l['buyer_name']}',
    ];
    return parts.isEmpty ? 'Lead' : parts.join(' ');
  }
}

class _MarketCard extends ConsumerWidget {
  const _MarketCard(this.m);
  final Map<String, dynamic> m;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final exclusive = '${m['lead_exclusivity']}' == 'exclusive';
    final price = num.tryParse('${m['lead_price']}');
    final claimedByMe = m['claimed_by_me'] == true;
    final claims = int.tryParse('${m['claim_count'] ?? 0}') ?? 0;
    final budget = [num.tryParse('${m['min_budget']}'), num.tryParse('${m['max_budget']}')];
    final specs = [
      if ('${m['community'] ?? ''}'.isNotEmpty) '${m['community']}',
      if ('${m['property_type'] ?? ''}'.isNotEmpty) '${m['property_type']}',
      if ('${m['purpose'] ?? ''}'.isNotEmpty) 'for ${m['purpose']}',
    ].join(' · ');
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.x16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            StatusBadge(exclusive ? 'Exclusive' : 'Shared', tone: exclusive ? BadgeTone.gold : BadgeTone.neutral),
            const Spacer(),
            if (price != null)
              Text(_aed.format(price), style: t.titleSmall?.copyWith(fontWeight: FontWeight.w700, color: AppColors.primary)),
          ]),
          const SizedBox(height: 6),
          if (specs.isNotEmpty) Text(specs, style: t.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
          if (budget[0] != null || budget[1] != null) ...[
            const SizedBox(height: 2),
            Text('Budget ${_aed.format(budget[0] ?? budget[1])}${budget[1] != null && budget[0] != null ? ' – ${_aed.format(budget[1])}' : ''}',
                style: t.bodySmall?.copyWith(color: AppColors.textMuted)),
          ],
          const SizedBox(height: AppSpacing.x12),
          Row(children: [
            Text(exclusive ? 'One buyer only' : '$claims ${claims == 1 ? 'buyer' : 'buyers'} so far',
                style: t.bodySmall?.copyWith(color: AppColors.textMuted)),
            const Spacer(),
            claimedByMe
                ? const StatusBadge('Claimed', tone: BadgeTone.success)
                : FilledButton(onPressed: () => _claim(context, ref), child: const Text('Claim lead')),
          ]),
        ]),
      ),
    );
  }

  Future<void> _claim(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(apiClientProvider).post('/buyer-requirements/market/${m['id']}/claim');
      ref.invalidate(leadMarketProvider);
      ref.invalidate(myLeadClaimsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lead claimed — see it under My claims.')));
      }
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }
}

class _ClaimCard extends StatelessWidget {
  const _ClaimCard(this.m);
  final Map<String, dynamic> m;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final paid = '${m['claim_status']}' == 'paid';
    final phone = '${m['buyer_phone'] ?? ''}'.trim();
    final specs = [
      if ('${m['community'] ?? ''}'.isNotEmpty) '${m['community']}',
      if ('${m['property_type'] ?? ''}'.isNotEmpty) '${m['property_type']}',
      if ('${m['purpose'] ?? ''}'.isNotEmpty) 'for ${m['purpose']}',
    ].join(' · ');
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.x16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text('${m['buyer_name'] ?? 'Buyer'}', style: t.titleSmall?.copyWith(fontWeight: FontWeight.w700))),
            StatusBadge(paid ? 'Paid' : 'Reserved', tone: paid ? BadgeTone.success : BadgeTone.warning),
          ]),
          if (specs.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(specs, style: t.bodySmall?.copyWith(color: AppColors.textMuted)),
          ],
          if (phone.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.x8),
            Row(children: [
              const Icon(Icons.phone_outlined, size: 16, color: AppColors.success),
              const SizedBox(width: 6),
              Text(phone, style: t.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
              const Spacer(),
              TextButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: phone));
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Phone copied')));
                },
                icon: const Icon(Icons.copy, size: 15),
                label: const Text('Copy'),
              ),
            ]),
          ],
        ]),
      ),
    );
  }
}
