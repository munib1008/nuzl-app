import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/app_dialog.dart';
import '../../core/widgets/async_view.dart';
import '../../core/widgets/status_badge.dart';
import '../shell/app_shell.dart';
import 'contacts_repository.dart';

BadgeTone _lifeTone(String l) => switch (l) {
      'customer' || 'owner' => BadgeTone.success,
      'qualified' => BadgeTone.gold,
      'tenant' => BadgeTone.warning,
      'lost' => BadgeTone.danger,
      _ => BadgeTone.neutral, // lead
    };

/// Unified contacts directory (CRM merge, Slice 2): one record per person across
/// the lead CRM and the customer book, grouped by macro lifecycle.
class ContactsScreen extends ConsumerWidget {
  const ContactsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contacts = ref.watch(contactsProvider);
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: NuzlAppBar(
        title: 'Contacts',
        actions: [
          IconButton(
            tooltip: 'Pipeline',
            icon: const Icon(Icons.view_kanban_outlined),
            onPressed: () => context.push('/opportunities'),
          ),
        ],
      ),
      drawer: const NuzlDrawer(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addContact(context, ref),
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Add contact'),
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(contactsProvider),
        child: AsyncView<List<Map<String, dynamic>>>(
          value: contacts,
          onRetry: () => ref.invalidate(contactsProvider),
          data: (list) {
            if (list.isEmpty) {
              return ListView(children: [
                Padding(
                  padding: const EdgeInsets.all(48),
                  child: Center(child: Text('No contacts yet.',
                      style: t.bodyMedium?.copyWith(color: AppColors.textMuted))),
                ),
              ]);
            }
            final byLife = <String, List<Map<String, dynamic>>>{};
            for (final c in list) {
              (byLife['${c['lifecycle'] ?? 'lead'}'] ??= []).add(c);
            }
            return ListView(
              padding: const EdgeInsets.all(AppSpacing.x16),
              children: [
                _summaryStrip(byLife, list.length, t),
                const SizedBox(height: AppSpacing.x16),
                for (final l in contactLifecycleOrder)
                  if (byLife[l]?.isNotEmpty == true) ...[
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.x8, bottom: AppSpacing.x8),
                      child: Row(children: [
                        Text(contactLifecycleLabels[l] ?? l, style: t.titleSmall),
                        const SizedBox(width: AppSpacing.x8),
                        Text('${byLife[l]!.length}', style: t.bodySmall?.copyWith(color: AppColors.textMuted)),
                      ]),
                    ),
                    for (final c in byLife[l]!) _ContactCard(c, onTap: () => _openContact(context, ref, c)),
                  ],
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _summaryStrip(Map<String, List> byLife, int total, TextTheme t) {
    final customers = (byLife['customer']?.length ?? 0) + (byLife['owner']?.length ?? 0) + (byLife['tenant']?.length ?? 0);
    final leads = (byLife['lead']?.length ?? 0) + (byLife['qualified']?.length ?? 0);
    final stats = <(String, String)>[
      ('Total', '$total'),
      ('Leads', '$leads'),
      ('Customers', '$customers'),
      ('Lost', '${byLife['lost']?.length ?? 0}'),
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.x16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (final s in stats)
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(s.$2, style: t.titleLarge),
                Text(s.$1, style: t.bodySmall?.copyWith(color: AppColors.textMuted)),
              ]),
          ],
        ),
      ),
    );
  }

  // ── Manual add ───────────────────────────────────────────────────────────
  Future<void> _addContact(BuildContext context, WidgetRef ref) async {
    final name = TextEditingController();
    final email = TextEditingController();
    final phone = TextEditingController();
    var lifecycle = 'lead';
    final ok = await AppDialog.show<bool>(
      context,
      title: 'Add contact',
      children: [
        StatefulBuilder(
          builder: (ctx, setS) => Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: name, decoration: const InputDecoration(labelText: 'Full name')),
            const SizedBox(height: AppSpacing.x8),
            TextField(controller: phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Phone')),
            const SizedBox(height: AppSpacing.x8),
            TextField(controller: email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email')),
            const SizedBox(height: AppSpacing.x8),
            DropdownButtonFormField<String>(
              initialValue: lifecycle,
              decoration: const InputDecoration(labelText: 'Lifecycle'),
              items: [for (final l in contactLifecycleOrder) DropdownMenuItem(value: l, child: Text(contactLifecycleLabels[l] ?? l))],
              onChanged: (v) => setS(() => lifecycle = v ?? 'lead'),
            ),
          ]),
        ),
      ],
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Add')),
      ],
    );
    if (ok != true) return;
    if (name.text.trim().isEmpty) return;
    try {
      await ref.read(apiClientProvider).post('/contacts', body: {
        'full_name': name.text.trim(),
        if (email.text.trim().isNotEmpty) 'email': email.text.trim(),
        if (phone.text.trim().isNotEmpty) 'phone': phone.text.trim(),
        'lifecycle': lifecycle,
      });
      ref.invalidate(contactsProvider);
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Contact added')));
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  // ── Detail + lifecycle update ──────────────────────────────────────────────
  void _openContact(BuildContext context, WidgetRef ref, Map<String, dynamic> c) {
    var lifecycle = '${c['lifecycle'] ?? 'lead'}';
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetCtx) => StatefulBuilder(
        builder: (sheetCtx, setS) {
          final t = Theme.of(sheetCtx).textTheme;
          final phone = '${c['phone'] ?? ''}'.trim();
          final email = '${c['email'] ?? ''}'.trim();
          final owner = '${c['owner_name'] ?? ''}'.trim();
          final hasLead = c['has_lead'] == true;
          final props = int.tryParse('${c['properties'] ?? 0}') ?? 0;
          return Padding(
            padding: EdgeInsets.fromLTRB(AppSpacing.x20, 0, AppSpacing.x20,
                AppSpacing.x20 + MediaQuery.of(sheetCtx).viewInsets.bottom),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text('${c['full_name'] ?? 'Contact'}', style: t.titleLarge)),
                StatusBadge(contactLifecycleLabels[lifecycle] ?? lifecycle, tone: _lifeTone(lifecycle)),
              ]),
              const SizedBox(height: AppSpacing.x8),
              if (phone.isNotEmpty) _line(Icons.phone_outlined, phone, t),
              if (email.isNotEmpty) _line(Icons.email_outlined, email, t),
              if (owner.isNotEmpty) _line(Icons.person_outline, 'Owner: $owner', t),
              if (props > 0) _line(Icons.home_work_outlined, '$props propert${props == 1 ? 'y' : 'ies'}', t),
              const SizedBox(height: AppSpacing.x16),
              DropdownButtonFormField<String>(
                initialValue: lifecycle,
                decoration: const InputDecoration(labelText: 'Lifecycle'),
                items: [for (final l in contactLifecycleOrder) DropdownMenuItem(value: l, child: Text(contactLifecycleLabels[l] ?? l))],
                onChanged: (v) async {
                  if (v == null || v == lifecycle) return;
                  final prev = lifecycle;
                  setS(() => lifecycle = v);
                  try {
                    await ref.read(apiClientProvider).patch('/contacts/${c['id']}', body: {'lifecycle': v});
                    ref.invalidate(contactsProvider);
                  } catch (e) {
                    setS(() => lifecycle = prev);
                    if (sheetCtx.mounted) ScaffoldMessenger.of(sheetCtx).showSnackBar(SnackBar(content: Text('$e')));
                  }
                },
              ),
              if (hasLead) ...[
                const SizedBox(height: AppSpacing.x12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(sheetCtx);
                      context.push('/leads/${c['lead_id']}');
                    },
                    icon: const Icon(Icons.open_in_new, size: 18),
                    label: const Text('Open lead'),
                  ),
                ),
              ],
            ]),
          );
        },
      ),
    );
  }

  Widget _line(IconData icon, String text, TextTheme t) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [
          Icon(icon, size: 16, color: AppColors.textMuted),
          const SizedBox(width: AppSpacing.x8),
          Expanded(child: Text(text, style: t.bodyMedium)),
        ]),
      );
}

class _ContactCard extends StatelessWidget {
  const _ContactCard(this.c, {required this.onTap});
  final Map<String, dynamic> c;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final name = '${c['full_name'] ?? '—'}';
    final life = '${c['lifecycle'] ?? 'lead'}';
    final subtitleParts = <String>[
      if ('${c['phone'] ?? ''}'.trim().isNotEmpty) '${c['phone']}',
      if ('${c['owner_name'] ?? ''}'.trim().isNotEmpty) '${c['owner_name']}',
    ];
    final props = int.tryParse('${c['properties'] ?? 0}') ?? 0;
    return Card(
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.only(bottom: AppSpacing.x8),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.x12),
          child: Row(children: [
            CircleAvatar(radius: 18, child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?')),
            const SizedBox(width: AppSpacing.x12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(name, style: t.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                if (subtitleParts.isNotEmpty)
                  Text(subtitleParts.join('  ·  '),
                      style: t.bodySmall?.copyWith(color: AppColors.textMuted), maxLines: 1, overflow: TextOverflow.ellipsis),
              ]),
            ),
            const SizedBox(width: AppSpacing.x8),
            if (props > 0) ...[
              const Icon(Icons.home_work_outlined, size: 14, color: AppColors.textMuted),
              const SizedBox(width: 2),
              Text('$props', style: t.bodySmall?.copyWith(color: AppColors.textMuted)),
              const SizedBox(width: AppSpacing.x8),
            ],
            StatusBadge(contactLifecycleLabels[life] ?? life, tone: _lifeTone(life)),
          ]),
        ),
      ),
    );
  }
}
