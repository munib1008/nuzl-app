import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/responsive.dart';
import '../../shell/app_shell.dart';

final dealsProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  try {
    final d = await ref.read(apiClientProvider).get('/deals');
    return d is List ? d : [];
  } catch (_) { return []; }
});

const _stages = ['lead','viewing','offer','negotiation','reservation','mortgage','dld','transfer','completed','cancelled'];

class DealsScreen extends ConsumerWidget {
  const DealsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deals = ref.watch(dealsProvider);
    final aed = NumberFormat.currency(symbol: 'AED ', decimalDigits: 0);
    return Scaffold(
      appBar: const NuzlAppBar(title: 'Deals'),
      drawer: const NuzlDrawer(),
      body: ResponsiveCenter(
        child: RefreshIndicator(
          onRefresh: () async => ref.refresh(dealsProvider.future),
          child: deals.when(
            loading: () => const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator())),
            error: (e, _) => ListView(children: [Padding(padding: const EdgeInsets.all(24), child: Text(friendlyError(e)))]),
            data: (list) => list.isEmpty
                ? ListView(children: [Padding(
                    padding: const EdgeInsets.all(40),
                    child: Column(children: [
                      Icon(Icons.handshake_outlined, size: 44, color: Theme.of(context).hintColor),
                      const SizedBox(height: 12),
                      const Text('No deals yet', textAlign: TextAlign.center),
                      const SizedBox(height: 4),
                      Text('Deals appear here when an offer is accepted.',
                          textAlign: TextAlign.center, style: TextStyle(color: Theme.of(context).hintColor)),
                    ]))])
                : ListView.separated(
                    padding: const EdgeInsets.all(AppSpacing.x16),
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.x8),
                    itemBuilder: (_, i) {
                      final d = Map<String, dynamic>.from(list[i]);
                      final stage = (d['stage'] ?? 'lead').toString();
                      final id = d['id'].toString();
                      final commAmt = num.tryParse('${d['commission_amount']}');
                      final split = (d['commission_split'] ?? '').toString();
                      final agreed = num.tryParse('${d['agreed_amount']}');
                      final price = agreed ?? num.tryParse('${d['listing_price']}');
                      return Card(child: Padding(
                        padding: const EdgeInsets.fromLTRB(AppSpacing.x16, AppSpacing.x12, AppSpacing.x8, AppSpacing.x8),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            Expanded(child: Text(price != null ? aed.format(price) : 'Deal',
                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16))),
                            _StageChip(stage: stage),
                          ]),
                          const SizedBox(height: AppSpacing.x8),
                          Row(children: [
                            Icon(Icons.payments_outlined, size: 16, color: Theme.of(context).hintColor),
                            const SizedBox(width: 6),
                            Expanded(child: Text.rich(TextSpan(children: [
                              const TextSpan(text: 'Commission  '),
                              TextSpan(
                                text: commAmt != null ? aed.format(commAmt) : 'Not set',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: commAmt != null ? AppColors.success : Theme.of(context).hintColor)),
                              if (split.isNotEmpty) TextSpan(text: '   ·   split $split'),
                            ]), style: TextStyle(fontSize: 13, color: Theme.of(context).textTheme.bodyMedium?.color))),
                          ]),
                          const SizedBox(height: AppSpacing.x4),
                          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                            TextButton.icon(
                              onPressed: () => _editCommission(context, ref, id, commAmt, split),
                              icon: const Icon(Icons.edit_outlined, size: 16),
                              label: const Text('Commission')),
                            TextButton.icon(
                              onPressed: () => _changeStage(context, ref, id, stage),
                              icon: const Icon(Icons.swap_horiz, size: 16),
                              label: const Text('Stage')),
                          ]),
                        ]),
                      ));
                    }),
          ),
        ),
      ),
    );
  }

  Future<void> _changeStage(BuildContext context, WidgetRef ref, String id, String current) async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(child: ListView(shrinkWrap: true, children: [
        const Padding(padding: EdgeInsets.all(16), child: Text('Move deal to stage', style: TextStyle(fontWeight: FontWeight.w600))),
        ..._stages.map((s) => ListTile(
          title: Text(s[0].toUpperCase() + s.substring(1)),
          trailing: s == current ? const Icon(Icons.check, color: AppColors.primary) : null,
          onTap: () => Navigator.pop(ctx, s),
        )),
      ])),
    );
    if (picked == null || picked == current) return;
    try {
      await ref.read(apiClientProvider).patch('/deals/$id/stage', body: {'stage': picked});
      ref.invalidate(dealsProvider);
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
    }
  }

  Future<void> _editCommission(BuildContext context, WidgetRef ref, String id, num? amount, String split) async {
    final amtCtrl = TextEditingController(text: amount != null ? '$amount' : '');
    final splitCtrl = TextEditingController(text: split);
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit commission'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
            controller: amtCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Commission amount (AED)', prefixText: 'AED '),
          ),
          const SizedBox(height: AppSpacing.x12),
          TextField(
            controller: splitCtrl,
            decoration: const InputDecoration(
              labelText: 'Split', hintText: 'e.g. 50% / 50%'),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
        ],
      ),
    );
    if (saved != true) return;
    final amtText = amtCtrl.text.trim();
    final body = <String, dynamic>{
      'commission_amount': amtText.isEmpty ? null : num.tryParse(amtText),
      'commission_split': splitCtrl.text.trim().isEmpty ? null : splitCtrl.text.trim(),
    };
    try {
      await ref.read(apiClientProvider).patch('/deals/$id', body: body);
      ref.invalidate(dealsProvider);
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
    }
  }
}

class _StageChip extends StatelessWidget {
  const _StageChip({required this.stage});
  final String stage;
  @override
  Widget build(BuildContext context) {
    final done = stage == 'completed';
    final cancelled = stage == 'cancelled';
    final color = cancelled ? Colors.redAccent : done ? AppColors.primary : AppColors.accentGold;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(AppSpacing.rFull)),
      child: Text(stage, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12)),
    );
  }
}
