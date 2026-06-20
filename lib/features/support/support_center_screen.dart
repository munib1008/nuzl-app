import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../shell/app_shell.dart';

const _statuses = ['new', 'acknowledged', 'in_progress', 'resolved', 'closed', 'rejected'];

String _label(String s) =>
    s.split('_').map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}').join(' ');

Color _priorityColor(String p) {
  switch (p) {
    case 'critical':
      return AppColors.danger;
    case 'high':
      return AppColors.accentGold;
    case 'low':
      return AppColors.textMuted;
    default:
      return AppColors.primary;
  }
}

final _statusFilterProvider = StateProvider.autoDispose<String?>((ref) => null);

final _ticketsProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  final status = ref.watch(_statusFilterProvider);
  final d = await ref.read(apiClientProvider).get('/feedback', query: status != null ? {'status': status} : null);
  return d is List ? d : [];
});

/// Super-admin support queue (feedback tickets users submit from anywhere).
class SupportCenterScreen extends ConsumerWidget {
  const SupportCenterScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tickets = ref.watch(_ticketsProvider);
    final filter = ref.watch(_statusFilterProvider);
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: const NuzlAppBar(title: 'Support Center'),
      drawer: const NuzlDrawer(),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(_ticketsProvider),
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.x16),
          children: [
            SizedBox(
              height: 40,
              child: ListView(scrollDirection: Axis.horizontal, children: [
                ChoiceChip(
                  label: const Text('All'),
                  selected: filter == null,
                  onSelected: (_) => ref.read(_statusFilterProvider.notifier).state = null,
                ),
                for (final s in _statuses) ...[
                  const SizedBox(width: AppSpacing.x8),
                  ChoiceChip(
                    label: Text(_label(s)),
                    selected: filter == s,
                    onSelected: (_) => ref.read(_statusFilterProvider.notifier).state = s,
                  ),
                ],
              ]),
            ),
            const SizedBox(height: AppSpacing.x12),
            tickets.when(
              loading: () => const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator())),
              error: (e, _) => Padding(padding: const EdgeInsets.all(24), child: Text(friendlyError(e))),
              data: (list) => list.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(40),
                      child: Center(child: Text('No tickets here.', style: t.bodyMedium?.copyWith(color: AppColors.textMuted))))
                  : Column(children: [for (final tk in list) _TicketCard(Map<String, dynamic>.from(tk as Map))]),
            ),
          ],
        ),
      ),
    );
  }
}

class _TicketCard extends ConsumerWidget {
  const _TicketCard(this.tk);
  final Map<String, dynamic> tk;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final priority = '${tk['priority'] ?? 'medium'}';
    final status = '${tk['status'] ?? 'new'}';
    final created = DateTime.tryParse('${tk['created_at'] ?? ''}');
    final dateStr = created != null ? DateFormat('d MMM yyyy · HH:mm').format(created) : '';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.x12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: _priorityColor(priority).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppSpacing.rFull),
              ),
              child: Text(_label(priority), style: t.labelSmall?.copyWith(color: _priorityColor(priority), fontWeight: FontWeight.w700)),
            ),
            const SizedBox(width: AppSpacing.x8),
            Expanded(
              child: Text('${tk['ticket_no'] ?? ''}', maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: t.labelMedium?.copyWith(color: AppColors.textMuted)),
            ),
            Text(_label('${tk['category'] ?? ''}'), style: t.labelSmall?.copyWith(color: AppColors.textMuted)),
          ]),
          const SizedBox(height: 6),
          Text('${tk['subject'] ?? ''}', style: t.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              maxLines: 2, overflow: TextOverflow.ellipsis),
          if ('${tk['description'] ?? ''}'.trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text('${tk['description']}', style: t.bodySmall?.copyWith(color: AppColors.textMuted),
                maxLines: 4, overflow: TextOverflow.ellipsis),
          ],
          const SizedBox(height: 6),
          Text(
            [
              if ('${tk['reporter_name'] ?? ''}'.trim().isNotEmpty) '${tk['reporter_name']}',
              if ('${tk['page'] ?? ''}'.trim().isNotEmpty) 'on ${tk['page']}',
              dateStr,
            ].where((s) => s.trim().isNotEmpty).join('  ·  '),
            style: t.labelSmall?.copyWith(color: AppColors.textMuted), maxLines: 1, overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: AppSpacing.x4),
          Row(children: [
            Text('Status', style: t.bodySmall?.copyWith(color: AppColors.textMuted)),
            const SizedBox(width: AppSpacing.x8),
            DropdownButton<String>(
              value: _statuses.contains(status) ? status : 'new',
              isDense: true,
              items: [for (final s in _statuses) DropdownMenuItem(value: s, child: Text(_label(s)))],
              onChanged: (v) async {
                if (v == null || v == status) return;
                try {
                  await ref.read(apiClientProvider).patch('/feedback/${tk['id']}', body: {'status': v});
                  ref.invalidate(_ticketsProvider);
                } catch (e) {
                  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
                }
              },
            ),
          ]),
        ]),
      ),
    );
  }
}
