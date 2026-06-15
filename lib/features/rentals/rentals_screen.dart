import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/app_dialog.dart';
import '../../core/widgets/responsive.dart';
import '../shell/app_shell.dart';

final tenanciesProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  try { final d = await ref.read(apiClientProvider).get('/tenancies'); return d is List ? d : []; } catch (_) { return []; }
});
final chequesProvider = FutureProvider.autoDispose.family<List<dynamic>, String>((ref, id) async {
  try { final d = await ref.read(apiClientProvider).get('/tenancies/$id/cheques'); return d is List ? d : []; } catch (_) { return []; }
});

class RentalsScreen extends ConsumerWidget {
  const RentalsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tenancies = ref.watch(tenanciesProvider);
    final aed = NumberFormat.currency(symbol: 'AED ', decimalDigits: 0);
    return Scaffold(
      appBar: const NuzlAppBar(title: 'Rentals'),
      drawer: const NuzlDrawer(),
      body: ResponsiveCenter(
        child: RefreshIndicator(
          onRefresh: () async => ref.refresh(tenanciesProvider.future),
          child: tenancies.when(
            loading: () => const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator())),
            error: (e, _) => ListView(children: [Padding(padding: const EdgeInsets.all(24), child: Text('$e'))]),
            data: (list) => list.isEmpty
                ? ListView(children: [Padding(padding: const EdgeInsets.all(40), child: Column(children: [
                    Icon(Icons.vpn_key_outlined, size: 44, color: Theme.of(context).hintColor),
                    const SizedBox(height: 12), const Text('No tenancies yet'),
                  ]))])
                : ListView(
                    padding: const EdgeInsets.all(AppSpacing.x16),
                    children: list.map((m) {
                      final tc = Map<String, dynamic>.from(m);
                      return Card(child: ExpansionTile(
                        title: Text(tc['tenant_name'] ?? 'Tenant'),
                        subtitle: Text('${aed.format(num.tryParse('${tc['rent_amount']}') ?? 0)} / yr · ${tc['status']}'),
                        children: [_Renewal(tc: tc), _Cheques(tenancyId: tc['id'].toString())],
                      ));
                    }).toList(),
                  ),
          ),
        ),
      ),
    );
  }
}

/// Renewal + rent-increase compliance (UAT #6). Shows the term end, an expiring
/// badge, the 90-day-notice status, and the owner actions (issue notice / renew).
class _Renewal extends ConsumerWidget {
  const _Renewal({required this.tc});
  final Map<String, dynamic> tc;

  Future<void> _issueNotice(BuildContext context, WidgetRef ref) async {
    final pct = TextEditingController();
    final ok = await AppDialog.show<bool>(context, title: 'Issue renewal notice', children: [
      const Text('Records a 90-day notice to the tenant. A rent increase can take '
          'effect 90 days from today (UAE Law 26/2007).'),
      const SizedBox(height: AppSpacing.x12),
      TextField(
        controller: pct,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(labelText: 'Proposed rent increase %', hintText: 'e.g. 5'),
      ),
    ], actions: [
      TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
      FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Issue notice')),
    ]);
    if (ok != true) return;
    try {
      await ref.read(apiClientProvider)
          .post('/tenancies/${tc['id']}/notice', body: {'rent_increase_pct': double.tryParse(pct.text)});
      ref.invalidate(tenanciesProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Renewal notice recorded.')));
      }
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _renew(BuildContext context, WidgetRef ref) async {
    final pct = TextEditingController();
    final months = TextEditingController(text: '12');
    final ok = await AppDialog.show<bool>(context, title: 'Renew tenancy', children: [
      TextField(
        controller: pct,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(labelText: 'Rent increase % (0 for no change)'),
      ),
      TextField(
        controller: months,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(labelText: 'New term (months)'),
      ),
    ], actions: [
      TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
      FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Renew')),
    ]);
    if (ok != true) return;
    try {
      await ref.read(apiClientProvider).post('/tenancies/${tc['id']}/renew', body: {
        'escalation_pct': double.tryParse(pct.text) ?? 0,
        'months': int.tryParse(months.text) ?? 12,
      });
      ref.invalidate(tenanciesProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tenancy renewed.')));
      }
    } catch (e) {
      // Surfaces the server-side 90-day-notice block message when applicable.
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _terminate(BuildContext context, WidgetRef ref) async {
    final reason = TextEditingController();
    final ok = await AppDialog.show<bool>(context, title: 'Terminate tenancy', children: [
      const Text('Ends the tenancy now. The other party is notified.'),
      const SizedBox(height: AppSpacing.x12),
      TextField(controller: reason, decoration: const InputDecoration(labelText: 'Reason (optional)')),
    ], actions: [
      TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
      FilledButton(
        style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
        onPressed: () => Navigator.pop(context, true),
        child: const Text('Terminate'),
      ),
    ]);
    if (ok != true) return;
    try {
      await ref.read(apiClientProvider).post('/tenancies/${tc['id']}/terminate', body: {'reason': reason.text.trim()});
      ref.invalidate(tenanciesProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tenancy terminated.')));
      }
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _declineRenewal(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(apiClientProvider).post('/tenancies/${tc['id']}/decline-renewal');
      ref.invalidate(tenanciesProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Renewal declined — the other party was notified.')));
      }
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _linkTenant(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(apiClientProvider).post('/tenancies/${tc['id']}/link-tenant');
      ref.invalidate(tenanciesProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Tenant linked to their NUZL account.')));
      }
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final end = DateTime.tryParse('${tc['end_date'] ?? ''}');
    final noticeAt = DateTime.tryParse('${tc['notice_issued_at'] ?? ''}');
    final daysLeft = end?.difference(DateTime.now()).inDays;
    final expiringSoon = daysLeft != null && daysLeft <= 60;
    final eligibleFrom = noticeAt?.add(const Duration(days: 90));
    final increaseAllowed = eligibleFrom != null && !DateTime.now().isBefore(eligibleFrom);
    final df = DateFormat('d MMM yyyy');
    final terminated = '${tc['status']}' == 'terminated';
    final terminationReason = '${tc['termination_reason'] ?? ''}'.trim();
    final declined = DateTime.tryParse('${tc['renewal_declined_at'] ?? ''}') != null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.x16, AppSpacing.x8, AppSpacing.x16, AppSpacing.x8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Text('Renewal', style: TextStyle(fontWeight: FontWeight.w600)),
          const Spacer(),
          if (expiringSoon)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppSpacing.rFull),
              ),
              child: Text(
                daysLeft >= 0 ? 'Ends in $daysLeft days' : 'Expired',
                style: const TextStyle(color: AppColors.warning, fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
        ]),
        const SizedBox(height: 4),
        if (end != null)
          Text('Term ends ${df.format(end)}', style: t.bodySmall?.copyWith(color: AppColors.textMuted)),
        if ('${tc['tenant_user_id'] ?? ''}'.isNotEmpty)
          Row(children: [
            const Icon(Icons.link, size: 14, color: AppColors.success),
            const SizedBox(width: 4),
            Text('Tenant has a NUZL account', style: t.bodySmall?.copyWith(color: AppColors.success)),
          ])
        else if ('${tc['tenant_email'] ?? ''}'.trim().isNotEmpty && !terminated)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => _linkTenant(context, ref),
              icon: const Icon(Icons.link, size: 16),
              label: const Text('Link tenant to NUZL'),
              style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 0),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap),
            ),
          ),
        if (terminated)
          Text('Terminated${terminationReason.isNotEmpty ? ' · $terminationReason' : ''}',
              style: t.bodySmall?.copyWith(color: AppColors.danger, fontWeight: FontWeight.w600))
        else ...[
          Text(
            noticeAt == null
                ? 'No renewal notice issued. A rent increase needs 90 days’ notice.'
                : increaseAllowed
                    ? 'Notice issued ${df.format(noticeAt)} · rent increase allowed now'
                    : 'Notice issued ${df.format(noticeAt)} · increase allowed from ${df.format(eligibleFrom!)}',
            style: t.bodySmall?.copyWith(
                color: (noticeAt != null && increaseAllowed) ? AppColors.success : AppColors.textMuted),
          ),
          if (declined)
            Text('Renewal declined — runs to term end',
                style: t.bodySmall?.copyWith(color: AppColors.warning)),
          const SizedBox(height: AppSpacing.x8),
          Wrap(spacing: AppSpacing.x8, runSpacing: AppSpacing.x8, children: [
            OutlinedButton.icon(
              onPressed: () => _issueNotice(context, ref),
              icon: const Icon(Icons.campaign_outlined, size: 18),
              label: const Text('Issue notice'),
            ),
            FilledButton.icon(
              onPressed: () => _renew(context, ref),
              icon: const Icon(Icons.autorenew, size: 18),
              label: const Text('Renew'),
            ),
            if (!declined)
              OutlinedButton.icon(
                onPressed: () => _declineRenewal(context, ref),
                icon: const Icon(Icons.event_busy_outlined, size: 18),
                label: const Text('Decline renewal'),
              ),
            OutlinedButton.icon(
              onPressed: () => _terminate(context, ref),
              style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger),
              icon: const Icon(Icons.cancel_outlined, size: 18),
              label: const Text('Terminate'),
            ),
          ]),
        ],
        const Divider(height: AppSpacing.x24),
      ]),
    );
  }
}

class _Cheques extends ConsumerWidget {
  const _Cheques({required this.tenancyId});
  final String tenancyId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cheques = ref.watch(chequesProvider(tenancyId));
    final aed = NumberFormat.currency(symbol: 'AED ', decimalDigits: 0);
    Color c(String s) => s == 'cleared' ? AppColors.primary : s == 'bounced' ? Colors.redAccent : AppColors.accentGold;
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.x16, 0, AppSpacing.x16, AppSpacing.x12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('Post-dated cheques', style: TextStyle(fontWeight: FontWeight.w600)),
          TextButton.icon(onPressed: () => _add(context, ref), icon: const Icon(Icons.add, size: 18), label: const Text('Add')),
        ]),
        cheques.when(
          loading: () => const LinearProgressIndicator(),
          error: (e, _) => Text('$e'),
          data: (list) => list.isEmpty
              ? const Text('No cheques recorded.')
              : Column(children: list.map((m) {
                  final ch = Map<String, dynamic>.from(m);
                  return ListTile(
                    dense: true, contentPadding: EdgeInsets.zero,
                    title: Text('${ch['cheque_no'] ?? 'Cheque'} · ${aed.format(num.tryParse('${ch['amount']}') ?? 0)}'),
                    subtitle: Text('${ch['bank'] ?? ''} · due ${ch['due_date']?.toString().split('T').first ?? ''}'),
                    trailing: PopupMenuButton<String>(
                      onSelected: (v) async {
                        await ref.read(apiClientProvider).patch('/cheques/${ch['id']}/status', body: {'status': v});
                        ref.invalidate(chequesProvider(tenancyId));
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'cleared', child: Text('Mark cleared')),
                        PopupMenuItem(value: 'bounced', child: Text('Mark bounced')),
                        PopupMenuItem(value: 'pending', child: Text('Mark pending')),
                      ],
                      child: Chip(label: Text(ch['status'] ?? 'pending'),
                          backgroundColor: c('${ch['status']}').withValues(alpha: 0.15),
                          labelStyle: TextStyle(color: c('${ch['status']}'), fontSize: 12)),
                    ),
                  );
                }).toList()),
        ),
      ]),
    );
  }

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final no = TextEditingController(); final bank = TextEditingController(); final amount = TextEditingController(); final due = TextEditingController();
    final ok = await AppDialog.show<bool>(context, title: 'Add cheque', children: [
      TextField(controller: no, decoration: const InputDecoration(labelText: 'Cheque no.')),
      TextField(controller: bank, decoration: const InputDecoration(labelText: 'Bank')),
      TextField(controller: amount, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Amount (AED)')),
      TextField(controller: due, decoration: const InputDecoration(labelText: 'Due date (YYYY-MM-DD)')),
    ], actions: [
      TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
      FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save')),
    ]);
    if (ok != true) return;
    await ref.read(apiClientProvider).post('/tenancies/$tenancyId/cheques', body: {
      'cheque_no': no.text.trim(), 'bank': bank.text.trim(), 'amount': double.tryParse(amount.text), 'due_date': due.text.trim(),
    });
    ref.invalidate(chequesProvider(tenancyId));
  }
}
