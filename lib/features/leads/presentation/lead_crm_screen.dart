import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../core/network/api_client.dart';
import '../../../core/rbac/persona.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/async_view.dart';
import '../../../core/widgets/contact_actions.dart';
import '../data/leads_repository.dart';

const _stageLabels = {
  'new': 'New',
  'contacted': 'Contacted',
  'viewing': 'Viewing',
  'negotiation': 'Negotiation',
  'agreement': 'Agreement',
  'closed_won': 'Closed won',
  'closed_lost': 'Closed lost',
};

/// Agent CRM for one lead (agent #7): leasing stage + activity/communication log,
/// plus distribute-to-agents for a lead the caller owns (agent #6).
class LeadCrmScreen extends ConsumerWidget {
  const LeadCrmScreen({super.key, required this.id});
  final String id;

  static num _n(dynamic v) => v is num ? v : num.tryParse('$v') ?? 0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final crm = ref.watch(leadCrmProvider(id));
    final t = Theme.of(context).textTheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final canManage = ref.watch(personaProvider).canManageLeads;
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('Lead'))),
      body: RefreshIndicator(
        onRefresh: () async => ref.refresh(leadCrmProvider(id).future),
        child: AsyncView<Map<String, dynamic>>(
          value: crm,
          onRetry: () => ref.refresh(leadCrmProvider(id)),
          data: (d) {
            final lead = Map<String, dynamic>.from(d['lead'] ?? {});
            final record = d['record'] is Map ? Map<String, dynamic>.from(d['record']) : null;
            final stages = (d['stages'] is List) ? List<String>.from(d['stages']) : _stageLabels.keys.toList();
            final activities = (d['activities'] is List) ? List.from(d['activities']) : const [];
            final stage = record?['stage'] as String? ?? 'new';
            final aed = NumberFormat.compactCurrency(symbol: 'AED ', decimalDigits: 0);
            final budget = (lead['min_budget'] != null && lead['max_budget'] != null)
                ? '${aed.format(_n(lead['min_budget']))} – ${aed.format(_n(lead['max_budget']))}'
                : null;
            final subtitle = [
              if (lead['community'] != null) '${lead['community']}',
              if (lead['property_type'] != null) '${lead['property_type']}'.replaceAll('_', ' '),
              if (budget != null) budget,
            ].whereType<String>().join('  ·  ');
            return ListView(
              padding: const EdgeInsets.all(AppSpacing.x16),
              children: [
                Text(lead['buyer_name'] ?? context.tr('Lead'), style: t.headlineSmall),
                if (lead['buyer_phone'] != null && '${lead['buyer_phone']}'.isNotEmpty) ...[
                  Text('${lead['buyer_phone']}', style: t.bodyMedium?.copyWith(color: dark ? AppColors.dTextMuted : AppColors.textMuted)),
                  const SizedBox(height: AppSpacing.x12),
                  // One-tap reach-out — Call / WhatsApp / Copy.
                  ContactActions(phone: '${lead['buyer_phone']}'),
                ],
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.x8),
                  Text(subtitle, style: t.bodyMedium),
                ],
                const SizedBox(height: AppSpacing.x20),

                Text(context.tr('Leasing stage'), style: t.titleSmall),
                const SizedBox(height: AppSpacing.x8),
                Wrap(spacing: AppSpacing.x8, runSpacing: AppSpacing.x8, children: [
                  for (final s in stages)
                    ChoiceChip(
                      label: Text(context.tr(_stageLabels[s] ?? s)),
                      selected: s == stage,
                      onSelected: (_) {
                        if (s != stage) _setStage(context, ref, s);
                      },
                    ),
                ]),
                const SizedBox(height: AppSpacing.x20),

                if (canManage) ...[
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      onPressed: () => _assignDialog(context, ref),
                      // Override the theme's full-width minimum so this reads as a
                      // button, not a large empty container.
                      style: OutlinedButton.styleFrom(minimumSize: const Size(0, 40)),
                      icon: const Icon(Icons.group_add_outlined, size: 18),
                      label: Text(context.tr('Offer to agents')),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.x20),
                ],

                Row(children: [
                  Text(context.tr('Activity & communications'), style: t.titleSmall),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () => _addNote(context, ref),
                    icon: const Icon(Icons.add, size: 18),
                    label: Text(context.tr('Log update')),
                  ),
                ]),
                const SizedBox(height: AppSpacing.x8),
                // Frictionless note — type and tap away (or press send) to log it.
                _QuickNote(id),
                const SizedBox(height: AppSpacing.x12),
                if (activities.isEmpty)
                  Text(context.tr('No activity yet.'), style: t.bodySmall?.copyWith(color: dark ? AppColors.dTextMuted : AppColors.textMuted))
                else
                  for (final a in activities)
                    _activityTile(Map<String, dynamic>.from(a), t, dark, Theme.of(context).colorScheme.primary),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _activityTile(Map<String, dynamic> a, TextTheme t, bool dark, Color primary) {
    final when = DateTime.tryParse('${a['created_at'] ?? ''}');
    final sub = [
      if (a['actor_name'] != null) '${a['actor_name']}',
      if (when != null) DateFormat.yMMMd().add_jm().format(when),
    ].join('  ·  ');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.x8),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(padding: const EdgeInsets.only(top: 4),
            child: Icon(Icons.circle, size: 8, color: primary)),
        const SizedBox(width: AppSpacing.x12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${a['note'] ?? a['activity_type'] ?? ''}', style: t.bodyMedium),
            if (sub.isNotEmpty) Text(sub, style: t.bodySmall?.copyWith(color: dark ? AppColors.dTextMuted : AppColors.textMuted)),
          ]),
        ),
      ]),
    );
  }

  Future<void> _setStage(BuildContext context, WidgetRef ref, String stage) async {
    try {
      await ref.read(leadsRepositoryProvider).setCrmStage(id, stage);
      ref.invalidate(leadCrmProvider(id));
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
    }
  }

  Future<void> _addNote(BuildContext context, WidgetRef ref) async {
    final ctrl = TextEditingController();
    String type = 'note';
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text(context.tr('Log an update')),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            DropdownButtonFormField<String>(
              initialValue: type,
              decoration: InputDecoration(labelText: context.tr('Type')),
              items: [
                DropdownMenuItem(value: 'note', child: Text(context.tr('Note'))),
                DropdownMenuItem(value: 'call', child: Text(context.tr('Call'))),
                DropdownMenuItem(value: 'message', child: Text(context.tr('Message'))),
                DropdownMenuItem(value: 'follow_up', child: Text(context.tr('Follow-up'))),
                DropdownMenuItem(value: 'viewing', child: Text(context.tr('Viewing'))),
                DropdownMenuItem(value: 'offer', child: Text(context.tr('Offer'))),
              ],
              onChanged: (v) => setLocal(() => type = v ?? 'note'),
            ),
            const SizedBox(height: AppSpacing.x12),
            TextField(controller: ctrl, autofocus: true, maxLines: 3,
                decoration: InputDecoration(hintText: context.tr('What happened?'))),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(context.tr('Cancel'))),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(context.tr('Save'))),
          ],
        ),
      ),
    );
    if (saved != true || ctrl.text.trim().isEmpty) return;
    try {
      await ref.read(leadsRepositoryProvider).addCrmActivity(id, type, ctrl.text.trim());
      ref.invalidate(leadCrmProvider(id));
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
    }
  }

  Future<void> _assignDialog(BuildContext context, WidgetRef ref) async {
    final picked = await showDialog<List<String>>(
      context: context,
      builder: (ctx) => const _AssignAgentsDialog(),
    );
    if (picked == null || picked.isEmpty) return;
    try {
      await ref.read(leadsRepositoryProvider).assign(id, picked);
      ref.invalidate(leadCrmProvider(id));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${context.tr('Offered to')} ${picked.length} ${context.tr('agent(s) — first to accept gets it')}')));
      }
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
    }
  }
}

/// Frictionless note composer — logs to the lead timeline when focus leaves the
/// field (or the user presses send), so jotting a quick note takes no dialog.
class _QuickNote extends ConsumerStatefulWidget {
  const _QuickNote(this.id);
  final String id;
  @override
  ConsumerState<_QuickNote> createState() => _QuickNoteState();
}

class _QuickNoteState extends ConsumerState<_QuickNote> {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    if (!_focus.hasFocus) _save();
  }

  Future<void> _save() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _saving) return;
    setState(() => _saving = true);
    try {
      await ref.read(leadsRepositoryProvider).addCrmActivity(widget.id, 'note', text);
      _ctrl.clear();
      ref.invalidate(leadCrmProvider(widget.id));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.tr('Note saved'))));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _focus.removeListener(_onFocusChange);
    _focus.dispose();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _ctrl,
      focusNode: _focus,
      maxLines: 2,
      minLines: 1,
      textInputAction: TextInputAction.newline,
      decoration: InputDecoration(
        hintText: context.tr('Add a quick note — saved to the timeline when you tap away'),
        suffixIcon: _saving
            ? const Padding(
                padding: EdgeInsets.all(12),
                child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)))
            : IconButton(
                tooltip: context.tr('Save note'),
                icon: const Icon(Icons.send_outlined, size: 18),
                onPressed: _save),
      ),
    );
  }
}

/// Name-search multi-select for distributing a lead to agents.
class _AssignAgentsDialog extends ConsumerStatefulWidget {
  const _AssignAgentsDialog();
  @override
  ConsumerState<_AssignAgentsDialog> createState() => _AssignAgentsDialogState();
}

class _AssignAgentsDialogState extends ConsumerState<_AssignAgentsDialog> {
  final _q = TextEditingController();
  List<Map<String, dynamic>> _results = [];
  final Map<String, String> _selected = {}; // id -> name
  bool _loading = false;
  int _seq = 0;

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  Future<void> _search(String q) async {
    if (q.trim().length < 2) {
      setState(() => _results = []);
      return;
    }
    final mySeq = ++_seq;
    setState(() => _loading = true);
    try {
      final r = await ref.read(leadsRepositoryProvider).searchUsers(q.trim());
      if (mySeq != _seq) return; // a newer search superseded this one
      setState(() {
        _results = r;
        _loading = false;
      });
    } catch (_) {
      if (mySeq == _seq) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(context.tr('Offer to agents')),
      content: SizedBox(
        width: 360,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
            controller: _q,
            autofocus: true,
            onChanged: _search,
            decoration: InputDecoration(hintText: context.tr('Search agents by name'), prefixIcon: const Icon(Icons.search)),
          ),
          const SizedBox(height: AppSpacing.x8),
          if (_selected.isNotEmpty)
            Align(
              alignment: Alignment.centerLeft,
              child: Wrap(spacing: 6, runSpacing: 4, children: [
                for (final e in _selected.entries)
                  Chip(label: Text(e.value), onDeleted: () => setState(() => _selected.remove(e.key))),
              ]),
            ),
          SizedBox(
            height: 220,
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : (_results.isEmpty
                    ? Center(child: Text(context.tr('Type a name to search')))
                    : ListView(children: [
                        for (final u in _results)
                          CheckboxListTile(
                            value: _selected.containsKey('${u['id']}'),
                            title: Text('${u['full_name'] ?? context.tr('User')}'),
                            subtitle: u['role'] != null ? Text('${u['role']}') : null,
                            onChanged: (v) => setState(() {
                              final uid = '${u['id']}';
                              if (v == true) {
                                _selected[uid] = '${u['full_name'] ?? context.tr('User')}';
                              } else {
                                _selected.remove(uid);
                              }
                            }),
                          ),
                      ])),
          ),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(context.tr('Cancel'))),
        FilledButton(
          onPressed: _selected.isEmpty ? null : () => Navigator.pop(context, _selected.keys.toList()),
          child: Text('${context.tr('Offer')} (${_selected.length})'),
        ),
      ],
    );
  }
}
