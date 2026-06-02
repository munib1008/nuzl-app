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
            error: (e, _) => ListView(children: [Padding(padding: const EdgeInsets.all(24), child: Text('$e'))]),
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
                      return Card(child: ListTile(
                        title: Text(d['listing_price'] != null ? aed.format(num.tryParse('${d['listing_price']}') ?? 0) : 'Deal'),
                        subtitle: Text('Commission: ${d['commission_amount'] ?? '—'}'),
                        trailing: _StageChip(stage: stage),
                        onTap: () => _changeStage(context, ref, d['id'].toString(), stage),
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
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
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
      decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(AppSpacing.rFull)),
      child: Text(stage, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12)),
    );
  }
}
