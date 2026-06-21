import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../core/network/api_client.dart';
import '../../core/rbac/persona.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/app_dialog.dart';
import '../../core/widgets/date_field.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/skeleton_loader.dart';
import '../../core/widgets/responsive.dart';
import '../shell/app_shell.dart';

final tenanciesProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  try { final d = await ref.read(apiClientProvider).get('/tenancies'); return d is List ? d : []; } catch (_) { return []; }
});
final chequesProvider = FutureProvider.autoDispose.family<List<dynamic>, String>((ref, id) async {
  try { final d = await ref.read(apiClientProvider).get('/tenancies/$id/cheques'); return d is List ? d : []; } catch (_) { return []; }
});

final rentPaymentsProvider = FutureProvider.autoDispose.family<List<dynamic>, String>((ref, id) async {
  try { final d = await ref.read(apiClientProvider).get('/tenancies/$id/payments'); return d is List ? d : []; } catch (_) { return []; }
});

/// Lease + documents attached to a tenancy (owner_table='tenancies'). Visible to
/// both the owner and the linked tenant (tenant has documents.manage).
final tenancyDocsProvider = FutureProvider.autoDispose.family<List<dynamic>, String>((ref, id) async {
  try {
    final d = await ref.read(apiClientProvider).get('/documents', query: {'owner_table': 'tenancies', 'owner_id': id});
    return d is List ? d : [];
  } catch (_) {
    return [];
  }
});

/// The owner's properties (for the Add-tenancy property picker).
final _ownerPropsProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  try { final d = await ref.read(apiClientProvider).get('/listings'); return d is List ? d : []; } catch (_) { return []; }
});

class RentalsScreen extends ConsumerWidget {
  const RentalsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tenancies = ref.watch(tenanciesProvider);
    final persona = ref.watch(personaProvider);
    final canManage = persona == Persona.owner || persona == Persona.investor ||
        persona == Persona.agent || persona == Persona.broker;
    final aed = NumberFormat.currency(symbol: 'AED ', decimalDigits: 0);
    return Scaffold(
      appBar: const NuzlAppBar(title: 'Rentals'),
      drawer: const NuzlDrawer(),
      floatingActionButton: canManage
          ? FloatingActionButton.extended(
              onPressed: () => _addTenancy(context, ref),
              icon: const Icon(Icons.add),
              label: const Text('Add tenancy'),
            )
          : null,
      body: ResponsiveCenter(
        child: RefreshIndicator(
          onRefresh: () async => ref.refresh(tenanciesProvider.future),
          child: tenancies.when(
            loading: () => const SkeletonList(),
            error: (e, _) => ListView(children: [Padding(padding: const EdgeInsets.all(24), child: Text(friendlyError(e)))]),
            data: (list) => list.isEmpty
                ? ListView(children: [
                    EmptyState(
                      icon: Icons.vpn_key_outlined,
                      title: canManage ? 'No tenancies yet' : 'No active tenancy',
                      message: canManage
                          ? 'Add a tenancy to track rent, cheques and the lease.'
                          : 'When your landlord adds you to a tenancy, it will appear here.',
                      actionLabel: canManage ? 'Add tenancy' : null,
                      onAction: canManage ? () => _addTenancy(context, ref) : null,
                    ),
                  ])
                : ListView(
                    padding: const EdgeInsets.all(AppSpacing.x16),
                    children: list.map((m) {
                      final tc = Map<String, dynamic>.from(m);
                      return Card(child: ExpansionTile(
                        title: Text(tc['tenant_name'] ?? 'Tenant'),
                        subtitle: Text('${aed.format(num.tryParse('${tc['rent_amount']}') ?? 0)} / yr · ${tc['status']}'),
                        children: [
                          _Renewal(tc: tc, canManage: canManage),
                          _RentSchedule(tenancyId: tc['id'].toString(), canManage: canManage),
                          _Cheques(tenancyId: tc['id'].toString(), canManage: canManage),
                          _Documents(tenancyId: tc['id'].toString(), canManage: canManage),
                        ],
                      ));
                    }).toList(),
                  ),
          ),
        ),
      ),
    );
  }
}

/// Owner flow to create a tenant + tenancy in one step (the endpoints existed
/// but were unreachable from the app — Rentals could never be populated).
Future<void> _addTenancy(BuildContext context, WidgetRef ref) async {
  final props = await ref.read(_ownerPropsProvider.future);
  if (!context.mounted) return;
  final seen = <String>{};
  final items = <DropdownMenuItem<String>>[];
  for (final e in props) {
    final mp = Map<String, dynamic>.from(e as Map);
    final pid = '${mp['property_id'] ?? ''}';
    if (pid.isEmpty || !seen.add(pid)) continue;
    final bn = '${mp['building_name'] ?? ''}'.trim();
    final un = '${mp['unit_no'] ?? ''}'.trim();
    final comm = '${mp['community'] ?? ''}'.trim();
    final label = bn.isNotEmpty
        ? (un.isNotEmpty ? '$bn · Unit $un' : bn)
        : (un.isNotEmpty ? 'Unit $un' : (comm.isNotEmpty ? comm : 'Property'));
    items.add(DropdownMenuItem(value: pid, child: Text(label, overflow: TextOverflow.ellipsis)));
  }

  String? propertyId = items.isNotEmpty ? items.first.value : null;
  var freq = 'annual';
  final name = TextEditingController();
  final email = TextEditingController();
  final phone = TextEditingController();
  final rent = TextEditingController();
  final start = TextEditingController();
  final end = TextEditingController();

  final ok = await AppDialog.show<bool>(
    context,
    title: 'Add tenancy',
    maxWidth: 460,
    children: [
      StatefulBuilder(
        builder: (ctx, setS) => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (items.isEmpty)
            const Text('You have no properties yet. Add a property first, then create its tenancy.')
          else
            DropdownButtonFormField<String>(
              initialValue: propertyId,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Property *'),
              items: items,
              onChanged: (v) => setS(() => propertyId = v),
            ),
          const SizedBox(height: AppSpacing.x8),
          TextField(controller: name, decoration: const InputDecoration(labelText: 'Tenant name *')),
          const SizedBox(height: AppSpacing.x8),
          Row(children: [
            Expanded(child: TextField(controller: email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Tenant email'))),
            const SizedBox(width: AppSpacing.x8),
            Expanded(child: TextField(controller: phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Phone'))),
          ]),
          const SizedBox(height: AppSpacing.x8),
          Row(children: [
            Expanded(child: TextField(controller: rent, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Annual rent (AED) *'))),
            const SizedBox(width: AppSpacing.x8),
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: freq,
                decoration: const InputDecoration(labelText: 'Frequency'),
                items: const [
                  DropdownMenuItem(value: 'monthly', child: Text('Monthly')),
                  DropdownMenuItem(value: 'quarterly', child: Text('Quarterly')),
                  DropdownMenuItem(value: 'annual', child: Text('Annual')),
                  DropdownMenuItem(value: 'cheques', child: Text('By cheques')),
                ],
                onChanged: (v) => setS(() => freq = v ?? 'annual'),
              ),
            ),
          ]),
          const SizedBox(height: AppSpacing.x8),
          Row(children: [
            Expanded(child: DateField(controller: start, label: 'Start date')),
            const SizedBox(width: AppSpacing.x8),
            Expanded(child: DateField(controller: end, label: 'End date')),
          ]),
        ]),
      ),
    ],
    actions: [
      TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
      FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Create tenancy')),
    ],
  );
  if (ok != true) return;
  if (propertyId == null || name.text.trim().isEmpty || (double.tryParse(rent.text.trim()) ?? 0) <= 0) {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Property, tenant name and a valid rent are required.')));
    }
    return;
  }
  try {
    final api = ref.read(apiClientProvider);
    final tenant = await api.post('/tenants', body: {
      'full_name': name.text.trim(),
      'email': email.text.trim(),
      'phone': phone.text.trim(),
    });
    final tenantId = (tenant is Map) ? tenant['id'] : null;
    await api.post('/tenancies', body: {
      'property_id': propertyId,
      'tenant_id': tenantId,
      'rent_amount': double.tryParse(rent.text.trim()),
      'payment_freq': freq,
      if (start.text.trim().isNotEmpty) 'start_date': start.text.trim(),
      if (end.text.trim().isNotEmpty) 'end_date': end.text.trim(),
    });
    ref.invalidate(tenanciesProvider);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tenancy created.')));
    }
  } catch (e) {
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
  }
}

/// Lease + documents on a tenancy. Either party can view; the owner can attach.
class _Documents extends ConsumerWidget {
  const _Documents({required this.tenancyId, required this.canManage});
  final String tenancyId;
  final bool canManage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final docs = ref.watch(tenancyDocsProvider(tenancyId));
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.x16, 0, AppSpacing.x16, AppSpacing.x12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('Lease & documents', style: TextStyle(fontWeight: FontWeight.w600)),
          if (canManage)
            TextButton.icon(
              onPressed: () => _attach(context, ref),
              icon: const Icon(Icons.upload_file, size: 18),
              label: const Text('Attach'),
            ),
        ]),
        docs.when(
          loading: () => const LinearProgressIndicator(),
          error: (e, _) => Text(friendlyError(e)),
          data: (list) => list.isEmpty
              ? Text(
                  canManage
                      ? 'No lease attached yet. Attach the tenancy contract so your tenant can access it.'
                      : 'No documents shared yet.',
                  style: t.bodySmall?.copyWith(color: dark ? AppColors.dTextMuted : AppColors.textMuted))
              : Column(children: list.map((m) {
                  final d = Map<String, dynamic>.from(m);
                  final created = DateTime.tryParse('${d['created_at']}');
                  final when = created != null ? DateFormat('d MMM y').format(created) : '';
                  final key = '${d['storage_key'] ?? ''}';
                  return ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.description_outlined, size: 20),
                    title: Text(_humanizeDoc('${d['doc_type'] ?? 'document'}')),
                    subtitle: Text(when, style: t.bodySmall?.copyWith(color: dark ? AppColors.dTextMuted : AppColors.textMuted)),
                    trailing: key.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Copy link',
                            icon: const Icon(Icons.copy_outlined, size: 18),
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: key));
                              ScaffoldMessenger.of(context)
                                  .showSnackBar(const SnackBar(content: Text('Document link copied.')));
                            },
                          ),
                  );
                }).toList()),
        ),
      ]),
    );
  }

  Future<void> _attach(BuildContext context, WidgetRef ref) async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 2200, imageQuality: 85);
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    if (!context.mounted) return;
    var type = 'tenancy_contract';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Document type'),
        content: StatefulBuilder(
          builder: (ctx, setS) => DropdownButtonFormField<String>(
            initialValue: type,
            decoration: const InputDecoration(labelText: 'Type'),
            items: const [
              DropdownMenuItem(value: 'tenancy_contract', child: Text('Tenancy contract')),
              DropdownMenuItem(value: 'ejari', child: Text('Ejari')),
              DropdownMenuItem(value: 'other', child: Text('Other')),
            ],
            onChanged: (v) => setS(() => type = v ?? 'tenancy_contract'),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Attach')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final api = ref.read(apiClientProvider);
      final up = await api.post('/uploads', body: {
        'filename': picked.name,
        'contentType': 'image/jpeg',
        'dataBase64': base64Encode(bytes),
      });
      final key = (up is Map) ? (up['path'] ?? up['url']) : null;
      if (key == null) throw Exception('Upload failed — storage not configured');
      await api.post('/documents', body: {
        'owner_table': 'tenancies',
        'owner_id': tenancyId,
        'doc_type': type,
        'storage_key': key,
      });
      ref.invalidate(tenancyDocsProvider(tenancyId));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Document attached.')));
      }
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
    }
  }
}

String _humanizeDoc(String k) => k
    .replaceAll('_', ' ')
    .split(' ')
    .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
    .join(' ');

/// Renewal + rent-increase compliance (UAT #6). Shows the term end, an expiring
/// badge, the 90-day-notice status, and the owner actions (issue notice / renew).
class _Renewal extends ConsumerWidget {
  const _Renewal({required this.tc, required this.canManage});
  final Map<String, dynamic> tc;
  final bool canManage;

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
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
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
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
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
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
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
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
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
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
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
          Text('Term ends ${df.format(end)}', style: t.bodySmall?.copyWith(color: dark ? AppColors.dTextMuted : AppColors.textMuted)),
        if ('${tc['tenant_user_id'] ?? ''}'.isNotEmpty)
          Row(children: [
            const Icon(Icons.link, size: 14, color: AppColors.success),
            const SizedBox(width: 4),
            Text('Tenant has a NUZL account', style: t.bodySmall?.copyWith(color: AppColors.success)),
          ])
        else if (canManage && '${tc['tenant_email'] ?? ''}'.trim().isNotEmpty && !terminated)
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
                color: (noticeAt != null && increaseAllowed) ? AppColors.success : (dark ? AppColors.dTextMuted : AppColors.textMuted)),
          ),
          if (declined)
            Text('Renewal declined — runs to term end',
                style: t.bodySmall?.copyWith(color: AppColors.warning)),
          // Owner-only renewal actions — a tenant gets a read-only renewal status.
          if (canManage) ...[
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
        ],
        const Divider(height: AppSpacing.x24),
      ]),
    );
  }
}

class _Cheques extends ConsumerWidget {
  const _Cheques({required this.tenancyId, required this.canManage});
  final String tenancyId;
  final bool canManage;
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
          if (canManage)
            TextButton.icon(onPressed: () => _add(context, ref), icon: const Icon(Icons.add, size: 18), label: const Text('Add')),
        ]),
        cheques.when(
          loading: () => const LinearProgressIndicator(),
          error: (e, _) => Text(friendlyError(e)),
          data: (list) => list.isEmpty
              ? const Text('No cheques recorded.')
              : Column(children: list.map((m) {
                  final ch = Map<String, dynamic>.from(m);
                  return ListTile(
                    dense: true, contentPadding: EdgeInsets.zero,
                    title: Text('${ch['cheque_no'] ?? 'Cheque'} · ${aed.format(num.tryParse('${ch['amount']}') ?? 0)}'),
                    subtitle: Text('${ch['bank'] ?? ''} · due ${ch['due_date']?.toString().split('T').first ?? ''}'),
                    trailing: canManage
                        ? PopupMenuButton<String>(
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
                          )
                        : Chip(label: Text(ch['status'] ?? 'pending'),
                            backgroundColor: c('${ch['status']}').withValues(alpha: 0.15),
                            labelStyle: TextStyle(color: c('${ch['status']}'), fontSize: 12)),
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
      DateField(controller: due, label: 'Due date'),
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

/// Rent payment schedule (due / paid) for a tenancy — generate + mark paid.
class _RentSchedule extends ConsumerWidget {
  const _RentSchedule({required this.tenancyId, required this.canManage});
  final String tenancyId;
  final bool canManage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final payments = ref.watch(rentPaymentsProvider(tenancyId));
    final aed = NumberFormat.currency(symbol: 'AED ', decimalDigits: 0);
    final primary = Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.x16, 0, AppSpacing.x16, AppSpacing.x12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('Rent schedule', style: TextStyle(fontWeight: FontWeight.w600)),
          if (canManage)
            payments.maybeWhen(
              data: (l) => l.isEmpty
                  ? TextButton.icon(onPressed: () => _generate(context, ref),
                      icon: const Icon(Icons.event_repeat, size: 18), label: const Text('Generate'))
                  : const SizedBox.shrink(),
              orElse: () => const SizedBox.shrink(),
            ),
        ]),
        payments.when(
          loading: () => const LinearProgressIndicator(),
          error: (e, _) => Text(friendlyError(e)),
          data: (list) => list.isEmpty
              ? Text(
                  canManage
                      ? 'No schedule yet — generate one to track due/paid installments.'
                      : 'No rent schedule yet.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).brightness == Brightness.dark ? AppColors.dTextMuted : AppColors.textMuted))
              : Column(children: list.map((m) {
                  final p = Map<String, dynamic>.from(m);
                  final status = '${p['status']}';
                  final paid = status == 'paid';
                  final submitted = !paid && (status == 'submitted' || '${p['proof_url'] ?? ''}'.isNotEmpty);
                  final due = '${p['due_on'] ?? ''}'.split('T').first;
                  return ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                        paid ? Icons.check_circle : submitted ? Icons.hourglass_bottom : Icons.schedule,
                        color: paid ? primary : submitted ? AppColors.warning : AppColors.accentGold, size: 20),
                    title: Text(aed.format(num.tryParse('${p['amount']}') ?? 0)),
                    subtitle: Text(
                        submitted ? 'due $due · receipt awaiting confirmation' : 'due $due',
                        style: TextStyle(fontSize: 12, color: submitted ? AppColors.warning : null)),
                    trailing: _trailing(context, ref, p, paid),
                  );
                }).toList()),
        ),
      ]),
    );
  }

  Future<void> _generate(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(apiClientProvider).post('/tenancies/$tenancyId/schedule');
      ref.invalidate(rentPaymentsProvider(tenancyId));
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
    }
  }

  Future<void> _markPaid(BuildContext context, WidgetRef ref, String id) async {
    try {
      await ref.read(apiClientProvider).patch('/rent-payments/$id/paid');
      ref.invalidate(rentPaymentsProvider(tenancyId));
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
    }
  }

  /// Trailing action per installment — owner verifies/marks paid, tenant uploads a receipt.
  Widget _trailing(BuildContext context, WidgetRef ref, Map<String, dynamic> p, bool paid) {
    final id = '${p['id']}';
    final proofUrl = '${p['proof_url'] ?? ''}';
    final hasProof = proofUrl.isNotEmpty;
    final viewBtn = IconButton(
      tooltip: 'View receipt',
      visualDensity: VisualDensity.compact,
      icon: const Icon(Icons.receipt_long, size: 18, color: AppColors.success),
      onPressed: () => _viewProof(context, proofUrl),
    );
    if (paid) {
      return Row(mainAxisSize: MainAxisSize.min, children: [
        if (hasProof) viewBtn,
        Text('Paid', style: TextStyle(color: Theme.of(context).colorScheme.primary, fontSize: 12)),
      ]);
    }
    if (canManage) {
      return Row(mainAxisSize: MainAxisSize.min, children: [
        if (hasProof) viewBtn,
        TextButton(onPressed: () => _markPaid(context, ref, id), child: const Text('Mark paid')),
      ]);
    }
    // Tenant: upload (or replace) a payment receipt.
    return TextButton.icon(
      onPressed: () => _uploadProof(context, ref, id),
      icon: Icon(hasProof ? Icons.check_circle : Icons.upload_file,
          size: 16, color: hasProof ? AppColors.success : null),
      label: Text(hasProof ? 'Sent · replace' : 'Upload proof'),
    );
  }

  Future<void> _uploadProof(BuildContext context, WidgetRef ref, String id) async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 2200, imageQuality: 85);
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    if (!context.mounted) return;
    try {
      final api = ref.read(apiClientProvider);
      final up = await api.post('/uploads', body: {
        'filename': picked.name,
        'contentType': 'image/jpeg',
        'dataBase64': base64Encode(bytes),
      });
      final url = (up is Map) ? up['url'] : null;
      if (url == null) throw Exception('Upload failed — storage not configured');
      await api.patch('/rent-payments/$id/proof', body: {'proof_url': url});
      ref.invalidate(rentPaymentsProvider(tenancyId));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Receipt uploaded — your landlord has been notified.')));
      }
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
    }
  }

  void _viewProof(BuildContext context, String url) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Payment receipt'),
        content: SizedBox(
          width: MediaQuery.sizeOf(ctx).width - 80 < 360 ? MediaQuery.sizeOf(ctx).width - 80 : 360,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppSpacing.rSm),
            child: Image.network(url, fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('Preview unavailable. Copy the link to open it in a new tab.'))),
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: url));
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Link copied')));
            },
            icon: const Icon(Icons.link, size: 16),
            label: const Text('Copy link')),
          FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }
}
