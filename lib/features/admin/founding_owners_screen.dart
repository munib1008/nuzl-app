import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/app_dialog.dart';
import '../../core/widgets/responsive.dart';
import '../shell/app_shell.dart';

/// Super-admin: the Founding Owner Program — who is a founding owner and how many
/// free properties each may manage. Grant by name search; adjust or revoke inline.
final foundingOwnersProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  try {
    final d = await ref.read(apiClientProvider).get('/admin/founding-owners');
    return d is List ? d : [];
  } catch (_) {
    return [];
  }
});

class FoundingOwnersScreen extends ConsumerWidget {
  const FoundingOwnersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final owners = ref.watch(foundingOwnersProvider);
    return Scaffold(
      appBar: const NuzlAppBar(title: 'Founding Owners'),
      drawer: const NuzlDrawer(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _grant(context, ref),
        icon: const Icon(Icons.workspace_premium_outlined),
        label: const Text('Grant founding'),
      ),
      body: ResponsiveCenter(
        child: owners.when(
          loading: () => const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator())),
          error: (e, _) => Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(friendlyError(e)))),
          data: (list) => ListView(
            padding: const EdgeInsets.all(AppSpacing.x16),
            children: [
              Text('Founding owners manage more properties free (standard 1, founding 5). '
                  'Grant by name, then adjust the free limit per owner.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textMuted)),
              const SizedBox(height: AppSpacing.x12),
              if (list.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(40),
                  child: Center(child: Text('No founding owners yet. Tap "Grant founding" to add one.')),
                )
              else
                ...list.map((e) => _OwnerTile(Map<String, dynamic>.from(e))),
            ],
          ),
        ),
      ),
    );
  }

  // Search a user by name and grant them founding status (default 5 free properties).
  Future<void> _grant(BuildContext context, WidgetRef ref) async {
    final picked = await _pickUser(context, ref);
    if (picked == null) return;
    try {
      await ref.read(apiClientProvider).patch('/admin/users/${picked['id']}/founding',
          body: {'is_founding_owner': true});
      ref.invalidate(foundingOwnersProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${picked['full_name'] ?? 'User'} is now a founding owner')));
      }
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
    }
  }
}

class _OwnerTile extends ConsumerWidget {
  const _OwnerTile(this.m);
  final Map<String, dynamic> m;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final limit = int.tryParse('${m['free_property_limit'] ?? 1}') ?? 1;
    final props = int.tryParse('${m['properties'] ?? 0}') ?? 0;
    return Card(
      child: ListTile(
        leading: const Icon(Icons.workspace_premium_outlined, color: AppColors.accentGold),
        title: Text('${m['full_name'] ?? 'User'}'),
        subtitle: Text([
          if ('${m['email'] ?? ''}'.isNotEmpty) '${m['email']}',
          '$props / ${limit == 0 ? '∞' : limit} properties used',
        ].join('\n')),
        isThreeLine: true,
        trailing: PopupMenuButton<String>(
          onSelected: (v) {
            if (v == 'adjust') _adjust(context, ref);
            if (v == 'revoke') _revoke(context, ref);
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'adjust', child: Text('Adjust free limit')),
            PopupMenuItem(value: 'revoke', child: Text('Revoke founding')),
          ],
        ),
      ),
    );
  }

  Future<void> _adjust(BuildContext context, WidgetRef ref) async {
    final ctl = TextEditingController(text: '${m['free_property_limit'] ?? 5}');
    final ok = await AppDialog.show<bool>(
      context,
      title: 'Free property limit',
      children: [
        TextField(
          controller: ctl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Free properties (0 = unlimited)'),
        ),
      ],
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save')),
      ],
    );
    if (ok != true) return;
    try {
      await ref.read(apiClientProvider).patch('/admin/users/${m['id']}/founding',
          body: {'is_founding_owner': true, 'free_property_limit': int.tryParse(ctl.text.trim()) ?? 5});
      ref.invalidate(foundingOwnersProvider);
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
    }
  }

  Future<void> _revoke(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(apiClientProvider).patch('/admin/users/${m['id']}/founding',
          body: {'is_founding_owner': false});
      ref.invalidate(foundingOwnersProvider);
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
    }
  }
}

/// Name-search picker → returns {id, full_name}.
Future<Map<String, dynamic>?> _pickUser(BuildContext context, WidgetRef ref) {
  final search = TextEditingController();
  var results = <Map<String, dynamic>>[];
  return showDialog<Map<String, dynamic>>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setS) {
        Future<void> run(String q) async {
          if (q.trim().length < 2) {
            setS(() => results = []);
            return;
          }
          try {
            final r = await ref.read(apiClientProvider).get('/users/search', query: {'q': q.trim()});
            setS(() => results = (r as List).cast<Map<String, dynamic>>());
          } catch (_) {
            setS(() => results = []);
          }
        }

        return AlertDialog(
          title: const Text('Grant founding owner'),
          content: SizedBox(
            width: 360,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(
                controller: search,
                autofocus: true,
                decoration: const InputDecoration(hintText: 'Search by name…', prefixIcon: Icon(Icons.search)),
                onChanged: run,
              ),
              const SizedBox(height: AppSpacing.x8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 280),
                child: results.isEmpty
                    ? const Padding(padding: EdgeInsets.all(16), child: Text('Type at least 2 letters to search'))
                    : ListView(
                        shrinkWrap: true,
                        children: [
                          for (final u in results)
                            ListTile(
                              dense: true,
                              leading: const CircleAvatar(child: Icon(Icons.person, size: 18)),
                              title: Text('${u['full_name'] ?? 'User'}'),
                              subtitle: u['role'] != null ? Text('${u['role']}') : null,
                              onTap: () => Navigator.pop(ctx, {'id': u['id'], 'full_name': u['full_name']}),
                            ),
                        ],
                      ),
              ),
            ]),
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))],
        );
      },
    ),
  );
}
