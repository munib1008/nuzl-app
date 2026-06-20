import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/app_dialog.dart';
import '../../core/widgets/responsive.dart';
import '../../core/widgets/user_avatar.dart';
import '../auth/application/auth_controller.dart';
import '../shell/app_shell.dart';

const _teamRoles = [
  'director', 'sales_manager', 'team_leader', 'senior_agent', 'agent',
  'inventory_manager', 'project_manager', 'marketing_manager',
  'sales_executive', 'customer_service', 'member',
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

final teamsProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  final orgId = ref.watch(authControllerProvider).user?.organizationId;
  if (orgId == null) return [];
  try {
    final d = await ref.read(apiClientProvider).get('/organizations/$orgId/teams');
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
                  if (isOwner) _TeamsSection(orgId: orgId),
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
                        final teamName = '${u['team_name'] ?? ''}'.trim();
                        return Card(
                          child: ListTile(
                            onTap: (isOwner && !isMe)
                                ? () => _assignTeam(context, ref, orgId, '${u['id']}', '${u['team_id'] ?? ''}')
                                : null,
                            leading: UserAvatar(name: '${u['full_name'] ?? '?'}', url: '${u['avatar_url'] ?? ''}'),
                            title: Text('${u['full_name'] ?? 'Member'}${isMe ? ' (you)' : ''}',
                                maxLines: 1, overflow: TextOverflow.ellipsis),
                            subtitle: Text(
                              [
                                '${u['email'] ?? ''}',
                                if (teamName.isNotEmpty) 'Team: $teamName',
                              ].where((s) => s.trim().isNotEmpty).join('  ·  '),
                              maxLines: 1, overflow: TextOverflow.ellipsis,
                            ),
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

/// Named teams: create, list with member counts, and activate / deactivate.
class _TeamsSection extends ConsumerWidget {
  const _TeamsSection({required this.orgId});
  final String orgId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final teams = ref.watch(teamsProvider);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Text('Teams', style: t.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
        const Spacer(),
        TextButton.icon(
          onPressed: () => _createTeam(context, ref),
          icon: const Icon(Icons.add, size: 18),
          label: const Text('New team'),
        ),
      ]),
      teams.maybeWhen(
        data: (list) => list.isEmpty
            ? Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.x8),
                child: Text('No teams yet — create one to group your agents, then tap a member to assign them.',
                    style: t.bodySmall?.copyWith(color: Theme.of(context).hintColor)))
            : Column(children: [for (final tm in list) _teamCard(context, ref, Map<String, dynamic>.from(tm as Map))]),
        orElse: () => const SizedBox.shrink(),
      ),
      const SizedBox(height: AppSpacing.x12),
    ]);
  }

  Widget _teamCard(BuildContext context, WidgetRef ref, Map<String, dynamic> tm) {
    final active = tm['is_active'] != false;
    final count = int.tryParse('${tm['member_count'] ?? 0}') ?? 0;
    return Card(
      child: ListTile(
        leading: const Icon(Icons.groups_outlined),
        title: Text('${tm['name'] ?? 'Team'}', maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text('$count member${count == 1 ? '' : 's'}${active ? '' : '  ·  inactive'}'),
        trailing: Switch(
          value: active,
          onChanged: (v) async {
            try {
              await ref.read(apiClientProvider).patch('/organizations/$orgId/teams/${tm['id']}', body: {'is_active': v});
              ref.invalidate(teamsProvider);
            } catch (e) {
              if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
            }
          },
        ),
      ),
    );
  }

  Future<void> _createTeam(BuildContext context, WidgetRef ref) async {
    final name = TextEditingController();
    final ok = await AppDialog.show<bool>(
      context,
      title: 'New team',
      maxWidth: 380,
      children: [
        TextField(controller: name, decoration: const InputDecoration(labelText: 'Team name', hintText: 'e.g. Marina Sales')),
      ],
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Create')),
      ],
    );
    if (ok != true || name.text.trim().isEmpty) return;
    try {
      await ref.read(apiClientProvider).post('/organizations/$orgId/teams', body: {'name': name.text.trim()});
      ref.invalidate(teamsProvider);
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Team created')));
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
    }
  }
}

/// Assign a member to a team (or clear it). Owner-only — tapped from a member row.
Future<void> _assignTeam(BuildContext context, WidgetRef ref, String orgId, String userId, String currentTeamId) async {
  final teams = await ref.read(teamsProvider.future);
  if (!context.mounted) return;
  String? selected = currentTeamId.isEmpty ? null : currentTeamId;
  if (selected != null && !teams.any((t) => '${(t as Map)['id']}' == selected)) selected = null;
  final ok = await AppDialog.show<bool>(
    context,
    title: 'Assign to team',
    maxWidth: 380,
    children: [
      StatefulBuilder(
        builder: (ctx, setS) => DropdownButtonFormField<String?>(
          initialValue: selected,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Team'),
          items: [
            const DropdownMenuItem<String?>(value: null, child: Text('No team')),
            for (final t in teams)
              DropdownMenuItem<String?>(value: '${(t as Map)['id']}', child: Text('${t['name']}')),
          ],
          onChanged: (v) => setS(() => selected = v),
        ),
      ),
    ],
    actions: [
      TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
      FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save')),
    ],
  );
  if (ok != true) return;
  try {
    await ref.read(apiClientProvider).patch('/organizations/$orgId/members/$userId/team', body: {'team_id': selected});
    ref.invalidate(teamMembersProvider);
    ref.invalidate(teamsProvider);
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Team updated')));
  } catch (e) {
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
  }
}
