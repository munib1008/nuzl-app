import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/app_dialog.dart';
import '../../core/widgets/responsive.dart';
import '../auth/application/auth_controller.dart';
import '../shell/app_shell.dart';

const _teamRoles = [
  'director', 'sales_head', 'project_manager', 'inventory_manager',
  'marketing_manager', 'sales_executive', 'customer_service', 'member',
];

String _roleLabel(String? r) => (r == null || r.isEmpty)
    ? 'Member'
    : r.split('_').map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}').join(' ');

final teamMembersProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  final orgId = ref.watch(authControllerProvider).user?.organizationId;
  if (orgId == null) return [];
  try {
    final d = await ref.read(apiClientProvider).get('/organizations/$orgId/members');
    return d is List ? d : [];
  } catch (_) {
    return [];
  }
});

final _myOrgProvider = FutureProvider.autoDispose<Map<String, dynamic>?>((ref) async {
  try {
    final d = await ref.read(apiClientProvider).get('/organizations/mine/current');
    return d is Map ? Map<String, dynamic>.from(d) : null;
  } catch (_) {
    return null;
  }
});

final _joinRequestsProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  try {
    final d = await ref.read(apiClientProvider).get('/organizations/mine/join-requests');
    return d is List ? d : [];
  } catch (_) {
    return [];
  }
});

class TeamScreen extends ConsumerWidget {
  const TeamScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).user;
    final orgId = user?.organizationId;
    final members = ref.watch(teamMembersProvider);
    final org = ref.watch(_myOrgProvider).asData?.value;
    final isOwner = org != null && '${org['owner_id']}' == user?.id;
    return Scaffold(
      appBar: const NuzlAppBar(title: 'Team'),
      drawer: const NuzlDrawer(),
      floatingActionButton: (orgId != null && isOwner)
          ? FloatingActionButton.extended(
              onPressed: () => _invite(context, ref, orgId),
              icon: const Icon(Icons.person_add_alt_1),
              label: const Text('Invite'),
            )
          : null,
      body: ResponsiveCenter(
        child: orgId == null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(40),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.groups_outlined, size: 44, color: Theme.of(context).hintColor),
                    const SizedBox(height: 12),
                    const Text('No company yet'),
                    const SizedBox(height: 4),
                    Text('Create your company in My Company to build a team.',
                        textAlign: TextAlign.center, style: TextStyle(color: Theme.of(context).hintColor)),
                  ]),
                ),
              )
            : ListView(
                padding: const EdgeInsets.all(AppSpacing.x16),
                children: [
                  if (isOwner) const _JoinRequests(),
                  members.when(
                    loading: () => const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator())),
                    error: (e, _) => Text(friendlyError(e)),
                    data: (list) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('${list.length} member${list.length == 1 ? '' : 's'}',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: AppSpacing.x8),
                      ...list.map((m) {
                        final u = Map<String, dynamic>.from(m);
                        final isMe = '${u['id']}' == user?.id;
                        return Card(
                          child: ListTile(
                            leading: CircleAvatar(child: Text('${u['full_name'] ?? '?'}'.characters.first.toUpperCase())),
                            title: Text('${u['full_name'] ?? 'Member'}${isMe ? ' (you)' : ''}'),
                            subtitle: Text('${u['email'] ?? ''}'),
                            trailing: isOwner && !isMe
                                ? _RolePicker(orgId: orgId, userId: '${u['id']}', current: '${u['team_role'] ?? ''}')
                                : Chip(
                                    label: Text(_roleLabel('${u['team_role'] ?? ''}')),
                                    visualDensity: VisualDensity.compact,
                                  ),
                          ),
                        );
                      }),
                    ]),
                  ),
                ],
              ),
      ),
    );
  }

  Future<void> _invite(BuildContext context, WidgetRef ref, String orgId) async {
    final email = TextEditingController();
    var role = 'sales_executive';
    final ok = await AppDialog.show<bool>(
      context,
      title: 'Invite team member',
      children: [
        const Text('Add an existing NUZL user to your company team by email.'),
        const SizedBox(height: AppSpacing.x12),
        StatefulBuilder(
          builder: (ctx, setS) => Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: email, keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.email_outlined))),
            const SizedBox(height: AppSpacing.x8),
            DropdownButtonFormField<String>(
              initialValue: role,
              decoration: const InputDecoration(labelText: 'Team role'),
              items: [for (final r in _teamRoles) DropdownMenuItem(value: r, child: Text(_roleLabel(r)))],
              onChanged: (v) => setS(() => role = v ?? 'member'),
            ),
          ]),
        ),
      ],
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Invite')),
      ],
    );
    if (ok != true || email.text.trim().isEmpty) return;
    try {
      await ref.read(apiClientProvider).post('/organizations/$orgId/invite',
          body: {'email': email.text.trim(), 'team_role': role});
      ref.invalidate(teamMembersProvider);
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Member added to the team')));
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
    }
  }
}

class _RolePicker extends ConsumerWidget {
  const _RolePicker({required this.orgId, required this.userId, required this.current});
  final String orgId;
  final String userId;
  final String current;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<String>(
      tooltip: 'Set role',
      onSelected: (r) async {
        try {
          await ref.read(apiClientProvider).patch('/organizations/$orgId/members/$userId/role', body: {'team_role': r});
          ref.invalidate(teamMembersProvider);
        } catch (e) {
          if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
        }
      },
      itemBuilder: (_) => [for (final r in _teamRoles) PopupMenuItem(value: r, child: Text(_roleLabel(r)))],
      child: Chip(
        label: Text(_roleLabel(current)),
        deleteIcon: const Icon(Icons.arrow_drop_down, size: 18),
        onDeleted: null,
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}

/// Pending company join-requests the owner can approve / decline.
class _JoinRequests extends ConsumerWidget {
  const _JoinRequests();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reqs = ref.watch(_joinRequestsProvider);
    return reqs.maybeWhen(
      data: (list) {
        final pending = list
            .map((e) => Map<String, dynamic>.from(e))
            .where((r) => '${r['status']}' == 'pending' && r['i_am_owner'] == true)
            .toList();
        if (pending.isEmpty) return const SizedBox.shrink();
        final t = Theme.of(context).textTheme;
        return Card(
          margin: const EdgeInsets.only(bottom: AppSpacing.x12),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.x12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Join requests (${pending.length})', style: t.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
              for (final r in pending)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text('${r['requester_name'] ?? 'Someone'}'),
                  subtitle: Text('${r['requester_email'] ?? ''}'),
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    TextButton(onPressed: () => _decide(context, ref, '${r['id']}', true), child: const Text('Approve')),
                    TextButton(
                      style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
                      onPressed: () => _decide(context, ref, '${r['id']}', false),
                      child: const Text('Decline'),
                    ),
                  ]),
                ),
            ]),
          ),
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }

  Future<void> _decide(BuildContext context, WidgetRef ref, String id, bool approve) async {
    try {
      await ref.read(apiClientProvider).post('/organizations/join-requests/$id/decide', body: {'approve': approve});
      ref.invalidate(_joinRequestsProvider);
      ref.invalidate(teamMembersProvider);
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
    }
  }
}
