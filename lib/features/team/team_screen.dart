import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/responsive.dart';
import '../auth/application/auth_controller.dart';
import '../shell/app_shell.dart';

final teamMembersProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  final orgId = ref.watch(authControllerProvider).user?.organizationId;
  if (orgId == null) return [];
  try {
    final d = await ref.read(apiClientProvider).get('/organizations/$orgId/members');
    return d is List ? d : [];
  } catch (_) { return []; }
});

class TeamScreen extends ConsumerWidget {
  const TeamScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orgId = ref.watch(authControllerProvider).user?.organizationId;
    final members = ref.watch(teamMembersProvider);
    return Scaffold(
      appBar: const NuzlAppBar(title: 'Team'),
      drawer: const NuzlDrawer(),
      body: ResponsiveCenter(
        child: orgId == null
            ? Center(child: Padding(
                padding: const EdgeInsets.all(40),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.groups_outlined, size: 44, color: Theme.of(context).hintColor),
                  const SizedBox(height: 12),
                  const Text('No organization yet'),
                  const SizedBox(height: 4),
                  Text('You need to belong to an organization to manage a team. An admin can create one and add you.',
                      textAlign: TextAlign.center, style: TextStyle(color: Theme.of(context).hintColor)),
                ])))
            : members.when(
                loading: () => const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator())),
                error: (e, _) => Center(child: Text(friendlyError(e))),
                data: (list) => ListView(
                  padding: const EdgeInsets.all(AppSpacing.x16),
                  children: [
                    Text('${list.length} member${list.length == 1 ? '' : 's'}', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: AppSpacing.x12),
                    ...list.map((m) {
                      final u = Map<String, dynamic>.from(m);
                      return Card(child: ListTile(
                        leading: CircleAvatar(child: Text((u['full_name'] ?? '?').toString().characters.first.toUpperCase())),
                        title: Text(u['full_name'] ?? 'Member'),
                        subtitle: Text([u['role'], u['email']].where((e) => e != null).join(' · ')),
                      ));
                    }),
                  ],
                ),
              ),
      ),
    );
  }
}
