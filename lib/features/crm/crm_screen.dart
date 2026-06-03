import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/responsive.dart';
import '../../core/widgets/status_badge.dart';
import '../shell/app_shell.dart';

final crmLeadsProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  try {
    final d = await ref.read(apiClientProvider).get('/buyer-requirements');
    return d is List ? d : [];
  } catch (_) {
    return [];
  }
});

final crmUsersProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  try {
    final d = await ref.read(apiClientProvider).get('/users');
    return d is List ? d : [];
  } catch (_) {
    return [];
  }
});

final _ownershipProvider = FutureProvider.autoDispose.family<List<dynamic>, String>((ref, id) async {
  try {
    final d = await ref.read(apiClientProvider).get('/buyer-requirements/$id/ownership-history');
    return d is List ? d : [];
  } catch (_) {
    return [];
  }
});

final _statusFilter = StateProvider.autoDispose<String>((ref) => 'all');

const _statuses = ['new', 'contacted', 'qualified', 'viewing_scheduled', 'negotiating', 'converted', 'lost'];

BadgeTone _tone(String s) => switch (s) {
      'qualified' || 'converted' => BadgeTone.success,
      'lost' => BadgeTone.danger,
      'negotiating' || 'viewing_scheduled' => BadgeTone.warning,
      _ => BadgeTone.neutral,
    };

String _humanize(String k) => k
    .replaceAll('_', ' ')
    .split(' ')
    .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
    .join(' ');

class CrmScreen extends ConsumerWidget {
  const CrmScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final leads = ref.watch(crmLeadsProvider);
    final users = ref.watch(crmUsersProvider).asData?.value ?? const [];
    final usersById = {for (final u in users) '${(u as Map)['id']}': '${u['full_name'] ?? ''}'};
    final filter = ref.watch(_statusFilter);

    return Scaffold(
      appBar: const NuzlAppBar(title: 'CRM'),
      drawer: const NuzlDrawer(),
      body: ResponsiveCenter(
        child: leads.when(
          loading: () => const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator())),
          error: (e, _) => Center(child: Padding(padding: const EdgeInsets.all(24), child: Text('$e'))),
          data: (raw) {
            final all = raw.map((e) => Map<String, dynamic>.from(e)).toList();
            final items = filter == 'all' ? all : all.where((m) => '${m['status']}' == filter).toList();
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.x16),
                  child: DropdownButtonFormField<String>(
                    initialValue: filter,
                    decoration: const InputDecoration(labelText: 'Status', prefixIcon: Icon(Icons.filter_list)),
                    items: [
                      const DropdownMenuItem(value: 'all', child: Text('All leads')),
                      ..._statuses.map((s) => DropdownMenuItem(value: s, child: Text(_humanize(s)))),
                    ],
                    onChanged: (v) => ref.read(_statusFilter.notifier).state = v ?? 'all',
                  ),
                ),
                Expanded(
                  child: items.isEmpty
                      ? const Center(child: Text('No leads in this stage.'))
                      : ListView.separated(
                          padding: const EdgeInsets.all(AppSpacing.x16),
                          itemCount: items.length,
                          separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.x8),
                          itemBuilder: (_, i) {
                            final m = items[i];
                            final owner = usersById['${m['broker_id']}'] ?? '';
                            return Card(
                              child: ListTile(
                                title: Text('${m['buyer_name'] ?? 'Unnamed buyer'}'),
                                subtitle: Text([
                                  if (m['community'] != null) '${m['community']}',
                                  if (owner.isNotEmpty) 'Owner: $owner',
                                ].join('  ·  ')),
                                trailing: StatusBadge(_humanize('${m['status'] ?? 'new'}'), tone: _tone('${m['status'] ?? 'new'}')),
                                onTap: () => _showLead(context, ref, m, users),
                              ),
                            );
                          },
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  void _showLead(BuildContext context, WidgetRef ref, Map<String, dynamic> lead, List<dynamic> users) {
    final id = '${lead['id']}';
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        builder: (sheetCtx, scroll) => Consumer(
          builder: (ctx, r, _) {
            final history = r.watch(_ownershipProvider(id));
            final f = NumberFormat.compactCurrency(symbol: 'AED ', decimalDigits: 0);
            final budget = (lead['min_budget'] != null && lead['max_budget'] != null)
                ? '${f.format(num.tryParse('${lead['min_budget']}') ?? 0)} – ${f.format(num.tryParse('${lead['max_budget']}') ?? 0)}'
                : null;
            return ListView(
              controller: scroll,
              padding: const EdgeInsets.all(AppSpacing.x16),
              children: [
                Text('${lead['buyer_name'] ?? 'Unnamed buyer'}', style: Theme.of(ctx).textTheme.titleLarge),
                const SizedBox(height: AppSpacing.x4),
                Text([
                  if (lead['buyer_type'] != null) _humanize('${lead['buyer_type']}'),
                  if (lead['purpose'] != null) '${lead['purpose']}',
                  if (budget != null) budget,
                ].join('  ·  '), style: Theme.of(ctx).textTheme.bodyMedium),
                const SizedBox(height: AppSpacing.x16),

                // lifecycle actions
                Wrap(spacing: AppSpacing.x8, runSpacing: AppSpacing.x8, children: [
                  FilledButton.tonalIcon(
                      onPressed: () => _setStatus(ctx, r, id, 'qualified'),
                      icon: const Icon(Icons.verified_outlined, size: 18), label: const Text('Qualify')),
                  FilledButton.tonalIcon(
                      onPressed: () => _setStatus(ctx, r, id, 'lost'),
                      icon: const Icon(Icons.cancel_outlined, size: 18), label: const Text('Unqualify')),
                  FilledButton.tonalIcon(
                      onPressed: () => _transfer(ctx, r, id, users),
                      icon: const Icon(Icons.swap_horiz, size: 18), label: const Text('Assign')),
                  FilledButton.tonalIcon(
                      onPressed: () => _convert(ctx, r, lead),
                      icon: const Icon(Icons.person_add_alt, size: 18), label: const Text('Convert')),
                  FilledButton.tonalIcon(
                      onPressed: () => _findMatches(ctx, r, id),
                      icon: const Icon(Icons.auto_awesome_outlined, size: 18), label: const Text('Match')),
                  FilledButton.tonalIcon(
                      onPressed: () => _logActivity(ctx, r, id),
                      icon: const Icon(Icons.add_comment_outlined, size: 18), label: const Text('Log')),
                ]),
                const SizedBox(height: AppSpacing.x20),

                Text('Set stage', style: Theme.of(ctx).textTheme.titleSmall),
                const SizedBox(height: AppSpacing.x8),
                DropdownButtonFormField<String>(
                  initialValue: _statuses.contains('${lead['status']}') ? '${lead['status']}' : null,
                  decoration: const InputDecoration(labelText: 'Stage'),
                  items: _statuses.map((s) => DropdownMenuItem(value: s, child: Text(_humanize(s)))).toList(),
                  onChanged: (v) { if (v != null) _setStatus(ctx, r, id, v); },
                ),
                const SizedBox(height: AppSpacing.x20),

                Text('Ownership history', style: Theme.of(ctx).textTheme.titleSmall),
                const SizedBox(height: AppSpacing.x8),
                history.when(
                  loading: () => const Padding(padding: EdgeInsets.all(12), child: LinearProgressIndicator()),
                  error: (e, _) => const Text('No history.'),
                  data: (list) => list.isEmpty
                      ? Text('No transfers yet.', style: TextStyle(color: Theme.of(ctx).hintColor))
                      : Column(
                          children: list.map((e) {
                            final h = Map<String, dynamic>.from(e);
                            final when = DateTime.tryParse('${h['changed_at']}');
                            return ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(Icons.history),
                              title: Text('${h['from_name'] ?? '—'} → ${h['to_name'] ?? '—'}'),
                              subtitle: Text([
                                if (h['reason'] != null && '${h['reason']}'.isNotEmpty) '${h['reason']}',
                                if (when != null) DateFormat('d MMM y').format(when),
                              ].join('  ·  ')),
                            );
                          }).toList(),
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _setStatus(BuildContext context, WidgetRef ref, String id, String status) async {
    try {
      await ref.read(apiClientProvider).patch('/buyer-requirements/$id/status', body: {'status': status});
      ref.invalidate(crmLeadsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lead marked ${_humanize(status)}')));
      }
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _transfer(BuildContext context, WidgetRef ref, String id, List<dynamic> users) async {
    String? toUser;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Assign to agent'),
        content: StatefulBuilder(
          builder: (ctx, setS) => DropdownButtonFormField<String>(
            initialValue: toUser,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Agent'),
            items: users.map((u) {
              final m = Map<String, dynamic>.from(u);
              return DropdownMenuItem(value: '${m['id']}', child: Text('${m['full_name'] ?? m['email'] ?? 'User'}'));
            }).toList(),
            onChanged: (v) => setS(() => toUser = v),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Assign')),
        ],
      ),
    );
    if (ok != true || toUser == null) return;
    try {
      await ref.read(apiClientProvider).post('/buyer-requirements/$id/transfer', body: {'to_user': toUser});
      ref.invalidate(crmLeadsProvider);
      ref.invalidate(_ownershipProvider(id));
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lead reassigned')));
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _convert(BuildContext context, WidgetRef ref, Map<String, dynamic> lead) async {
    try {
      await ref.read(apiClientProvider).post('/customers/from-lead/${lead['id']}', body: {
        'full_name': '${lead['buyer_name'] ?? 'New customer'}',
        if (lead['buyer_phone'] != null) 'phone': '${lead['buyer_phone']}',
        'customer_type': 'client',
      });
      ref.invalidate(crmLeadsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lead converted to customer')));
      }
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _findMatches(BuildContext context, WidgetRef ref, String id) async {
    try {
      final d = await ref.read(apiClientProvider).post('/matching/requirements/$id/run');
      final matches = d is List ? d : [];
      if (!context.mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('${matches.length} matching listings'),
          content: matches.isEmpty
              ? const Text('No strong matches yet.')
              : SizedBox(
                  width: 320,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: matches.take(6).map((e) {
                      final m = Map<String, dynamic>.from(e);
                      final score = (num.tryParse('${m['score']}') ?? 0).round();
                      return ListTile(
                        dense: true,
                        leading: CircleAvatar(radius: 14, child: Text('$score', style: const TextStyle(fontSize: 11))),
                        title: Text('Listing ${'${m['listing_id'] ?? ''}'.split('-').first}'),
                      );
                    }).toList(),
                  ),
                ),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))],
        ),
      );
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _logActivity(BuildContext context, WidgetRef ref, String id) async {
    final note = TextEditingController();
    var type = 'call';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log activity'),
        content: StatefulBuilder(
          builder: (ctx, setS) => Column(mainAxisSize: MainAxisSize.min, children: [
            DropdownButtonFormField<String>(
              initialValue: type,
              decoration: const InputDecoration(labelText: 'Type'),
              items: const [
                DropdownMenuItem(value: 'call', child: Text('Call')),
                DropdownMenuItem(value: 'message', child: Text('Message')),
                DropdownMenuItem(value: 'viewing', child: Text('Viewing')),
                DropdownMenuItem(value: 'follow_up', child: Text('Follow up')),
                DropdownMenuItem(value: 'note', child: Text('Note')),
              ],
              onChanged: (v) => setS(() => type = v ?? 'call'),
            ),
            TextField(controller: note, decoration: const InputDecoration(labelText: 'Note'), maxLines: 2),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(apiClientProvider).post('/activity', body: {
        'activity_type': type,
        'requirement_id': id,
        if (note.text.trim().isNotEmpty) 'note': note.text.trim(),
      });
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Activity logged')));
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }
}
