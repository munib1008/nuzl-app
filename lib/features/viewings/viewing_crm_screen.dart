import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/async_view.dart';
import '../auth/application/auth_controller.dart';
import 'viewing_leads_repository.dart';

String _title(Map v) {
  final bn = '${v['building_name'] ?? ''}'.trim();
  final un = '${v['unit_no'] ?? ''}'.trim();
  final comm = '${v['community'] ?? ''}'.trim();
  if (bn.isNotEmpty) return un.isNotEmpty ? '$bn - $un' : bn;
  if (un.isNotEmpty) return 'Unit $un';
  return comm.isNotEmpty ? comm : 'Property';
}

/// CRM for one viewing-request lead (agent #24/#25): the 12-stage pipeline + an
/// activity log. Only the assigned agent can advance the stage or log activity;
/// owners / managers can follow progress read-only.
class ViewingCrmScreen extends ConsumerWidget {
  const ViewingCrmScreen({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final crm = ref.watch(viewingCrmProvider(id));
    final t = Theme.of(context).textTheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final myId = ref.watch(authControllerProvider).user?.id;
    return Scaffold(
      appBar: AppBar(title: const Text('Lead')),
      body: RefreshIndicator(
        onRefresh: () async => ref.refresh(viewingCrmProvider(id).future),
        child: AsyncView<Map<String, dynamic>>(
          value: crm,
          onRetry: () => ref.invalidate(viewingCrmProvider(id)),
          data: (d) {
            final v = Map<String, dynamic>.from(d['viewing'] ?? {});
            final stages = (d['stages'] is List) ? List<String>.from(d['stages']) : viewingStageLabels.keys.toList();
            final activities = (d['activities'] is List) ? List.from(d['activities']) : const [];
            final stage = '${v['crm_stage'] ?? 'new_inquiry'}';
            final isAssigned = myId != null && '${v['assigned_agent_id']}' == myId;
            final isCustomer = myId != null && '${v['requested_by']}' == myId;
            return ListView(
              padding: const EdgeInsets.all(AppSpacing.x16),
              children: [
                Text(_title(v), style: t.headlineSmall),
                const SizedBox(height: AppSpacing.x4),
                Text([
                  if ('${v['requested_by_name'] ?? ''}'.isNotEmpty) 'Customer: ${v['requested_by_name']}',
                  if ('${v['assigned_agent_name'] ?? ''}'.isNotEmpty) 'Agent: ${v['assigned_agent_name']}',
                ].join('  ·  '), style: t.bodyMedium?.copyWith(color: dark ? AppColors.dTextMuted : AppColors.textMuted)),
                const SizedBox(height: AppSpacing.x20),

                Text('Leasing pipeline', style: t.titleSmall),
                const SizedBox(height: AppSpacing.x8),
                if (!isAssigned)
                  Text(
                    v['assigned_agent_id'] == null
                        ? 'Not yet assigned.'
                        : 'Assigned to another agent — read only.',
                    style: t.bodySmall?.copyWith(color: dark ? AppColors.dTextMuted : AppColors.textMuted),
                  ),
                const SizedBox(height: AppSpacing.x8),
                Wrap(spacing: AppSpacing.x8, runSpacing: AppSpacing.x8, children: [
                  for (final s in stages)
                    ChoiceChip(
                      label: Text(viewingStageLabels[s] ?? s),
                      selected: s == stage,
                      onSelected: isAssigned && s != stage ? (_) => _setStage(context, ref, s) : null,
                    ),
                ]),
                const SizedBox(height: AppSpacing.x20),

                // Communication — only the assigned agent and the customer (#23).
                if (isAssigned || isCustomer) ...[
                  Wrap(spacing: AppSpacing.x8, runSpacing: AppSpacing.x8, children: [
                    FilledButton.icon(
                      onPressed: () => _openChat(context, ref),
                      icon: const Icon(Icons.chat_bubble_outline, size: 18),
                      label: Text(isAssigned ? 'Message customer' : 'Message agent'),
                    ),
                    if (isAssigned)
                      OutlinedButton.icon(
                        onPressed: () => _scheduleCall(context, ref),
                        icon: const Icon(Icons.call_outlined, size: 18),
                        label: const Text('Schedule call'),
                      ),
                  ]),
                  const SizedBox(height: AppSpacing.x20),
                ],

                Row(children: [
                  Text('Activity & communications', style: t.titleSmall),
                  const Spacer(),
                  if (isAssigned)
                    TextButton.icon(
                      onPressed: () => _logActivity(context, ref),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Log'),
                    ),
                ]),
                const SizedBox(height: AppSpacing.x8),
                if (activities.isEmpty)
                  Text('No activity yet.', style: t.bodySmall?.copyWith(color: dark ? AppColors.dTextMuted : AppColors.textMuted))
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
      if (a['activity_type'] != null && a['activity_type'] != 'note') '${a['activity_type']}',
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

  Future<void> _openChat(BuildContext context, WidgetRef ref) async {
    try {
      final convId = await ref.read(viewingLeadsRepoProvider).openConversation(id);
      if (context.mounted) context.push('/messages/$convId');
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
    }
  }

  Future<void> _scheduleCall(BuildContext context, WidgetRef ref) async {
    final now = DateTime.now();
    final date = await showDatePicker(
        context: context, initialDate: now, firstDate: now, lastDate: now.add(const Duration(days: 365)));
    if (date == null || !context.mounted) return;
    final time = await showTimePicker(
        context: context, initialTime: TimeOfDay.fromDateTime(now.add(const Duration(hours: 1))));
    if (time == null || !context.mounted) return;
    final dt = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    final note = 'Call scheduled for ${DateFormat('EEE d MMM, h:mm a').format(dt)}';
    try {
      await ref.read(viewingLeadsRepoProvider).scheduleCall(id, dt.toIso8601String(), note);
      ref.invalidate(viewingCrmProvider(id));
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(note)));
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
    }
  }

  Future<void> _setStage(BuildContext context, WidgetRef ref, String stage) async {
    try {
      await ref.read(viewingLeadsRepoProvider).setStage(id, stage);
      ref.invalidate(viewingCrmProvider(id));
      ref.invalidate(viewingAssignedProvider);
      ref.invalidate(viewingMetricsProvider);
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
    }
  }

  Future<void> _logActivity(BuildContext context, WidgetRef ref) async {
    final ctrl = TextEditingController();
    String type = 'note';
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Log an interaction'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            DropdownButtonFormField<String>(
              initialValue: type,
              decoration: const InputDecoration(labelText: 'Type'),
              items: const [
                DropdownMenuItem(value: 'note', child: Text('Note')),
                DropdownMenuItem(value: 'call', child: Text('Call')),
                DropdownMenuItem(value: 'message', child: Text('Message')),
                DropdownMenuItem(value: 'follow_up', child: Text('Follow-up')),
                DropdownMenuItem(value: 'viewing', child: Text('Appointment')),
                DropdownMenuItem(value: 'offer', child: Text('Offer')),
              ],
              onChanged: (val) => setLocal(() => type = val ?? 'note'),
            ),
            const SizedBox(height: AppSpacing.x12),
            TextField(controller: ctrl, autofocus: true, maxLines: 3,
                decoration: const InputDecoration(hintText: 'What happened?')),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
          ],
        ),
      ),
    );
    if (saved != true || ctrl.text.trim().isEmpty) return;
    try {
      await ref.read(viewingLeadsRepoProvider).logActivity(id, type, ctrl.text.trim());
      ref.invalidate(viewingCrmProvider(id));
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
    }
  }
}
