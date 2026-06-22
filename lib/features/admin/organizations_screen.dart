import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/app_dialog.dart';
import '../../core/widgets/responsive.dart';
import '../shell/app_shell.dart';

final organizationsProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  try {
    final d = await ref.read(apiClientProvider).get('/organizations');
    return d is List ? d : [];
  } catch (_) {
    return [];
  }
});

final _membersProvider = FutureProvider.autoDispose.family<List<dynamic>, String>((ref, orgId) async {
  try {
    final d = await ref.read(apiClientProvider).get('/organizations/$orgId/members');
    return d is List ? d : [];
  } catch (_) {
    return [];
  }
});

const _assignableRoles = ['agent', 'broker', 'agency', 'developer', 'investor', 'lead_generator', 'admin'];

class OrganizationsScreen extends ConsumerWidget {
  const OrganizationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orgs = ref.watch(organizationsProvider);
    return Scaffold(
      appBar: NuzlAppBar(title: context.tr('Organizations')),
      drawer: const NuzlDrawer(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _createOrg(context, ref),
        icon: const Icon(Icons.add),
        label: Text(context.tr('New org')),
      ),
      body: ResponsiveCenter(
        child: orgs.when(
          loading: () => const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator())),
          error: (e, _) => Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(friendlyError(e)))),
          data: (list) => list.isEmpty
              ? Center(child: Padding(padding: const EdgeInsets.all(40), child: Text(context.tr('No organizations yet.'))))
              : ListView.separated(
                  padding: const EdgeInsets.all(AppSpacing.x16),
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.x8),
                  itemBuilder: (_, i) {
                    final o = Map<String, dynamic>.from(list[i]);
                    return Card(
                      child: ListTile(
                        leading: const Icon(Icons.business_outlined),
                        title: Text('${o['name'] ?? context.tr('Organization')}'),
                        subtitle: Text([o['org_type'], o['rera_orn']]
                            .where((x) => x != null && '$x'.isNotEmpty)
                            .join('  ·  ')),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _showMembers(context, '${o['id']}', '${o['name'] ?? ''}'),
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }

  Future<void> _createOrg(BuildContext context, WidgetRef ref) async {
    final name = TextEditingController();
    var type = 'agency';
    final ok = await AppDialog.show<bool>(
      context,
      title: context.tr('New organization'),
      children: [
        TextField(controller: name, decoration: InputDecoration(labelText: context.tr('Name'))),
        const SizedBox(height: AppSpacing.x12),
        StatefulBuilder(
          builder: (ctx, setS) => DropdownButtonFormField<String>(
            initialValue: type,
            decoration: InputDecoration(labelText: context.tr('Type')),
            items: [
              DropdownMenuItem(value: 'agency', child: Text(context.tr('Agency'))),
              DropdownMenuItem(value: 'developer', child: Text(context.tr('Developer'))),
              DropdownMenuItem(value: 'bank', child: Text(context.tr('Bank'))),
              DropdownMenuItem(value: 'maintenance', child: Text(context.tr('Maintenance'))),
              DropdownMenuItem(value: 'interior_gardens', child: Text(context.tr('Interior & Gardens'))),
              DropdownMenuItem(value: 'seller', child: Text(context.tr('Seller'))),
              DropdownMenuItem(value: 'investor', child: Text(context.tr('Investor'))),
            ],
            onChanged: (v) => setS(() => type = v ?? 'agency'),
          ),
        ),
      ],
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: Text(context.tr('Cancel'))),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(context.tr('Create'))),
      ],
    );
    if (ok != true) return;
    if (name.text.trim().isEmpty) return;
    try {
      await ref.read(apiClientProvider).post('/organizations', body: {
        'name': name.text.trim(),
        'org_type': type,
      });
      ref.invalidate(organizationsProvider);
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
    }
  }

  void _showMembers(BuildContext context, String orgId, String orgName) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        builder: (sheetCtx, scroll) => Consumer(
          builder: (ctx, ref, _) {
            final members = ref.watch(_membersProvider(orgId));
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.x16),
                  child: Text(orgName.isEmpty ? context.tr('Members') : '$orgName · ${context.tr('Members')}',
                      style: Theme.of(ctx).textTheme.titleMedium),
                ),
                Expanded(
                  child: members.when(
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(friendlyError(e)))),
                    data: (list) => list.isEmpty
                        ? Center(child: Text(context.tr('No members.')))
                        : ListView(
                            controller: scroll,
                            children: list.map((e) {
                              final m = Map<String, dynamic>.from(e);
                              return ListTile(
                                title: Text('${m['full_name'] ?? context.tr('Member')}'),
                                subtitle: Text('${m['role'] ?? ''}'),
                                trailing: PopupMenuButton<String>(
                                  icon: const Icon(Icons.manage_accounts_outlined),
                                  onSelected: (role) => _assignRole(ctx, ref, '${m['id']}', role, orgId),
                                  itemBuilder: (_) => _assignableRoles
                                      .map((role) => PopupMenuItem(value: role, child: Text('${context.tr('Make')} ${_humanize(role)}')))
                                      .toList(),
                                ),
                              );
                            }).toList(),
                          ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _assignRole(BuildContext context, WidgetRef ref, String userId, String role, String orgId) async {
    try {
      await ref.read(apiClientProvider).post('/users/$userId/roles', body: {
        'role': role,
        'organization_id': orgId,
      });
      ref.invalidate(_membersProvider(orgId));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${context.tr('Role set to')} ${_humanize(role)}')));
      }
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
    }
  }
}

String _humanize(String k) => k
    .replaceAll('_', ' ')
    .split(' ')
    .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
    .join(' ');
