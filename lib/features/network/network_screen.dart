import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/responsive.dart';
import '../shell/app_shell.dart';

/// Directory of verified members (users module). Search + filter by role.
final networkProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  try {
    final d = await ref.read(apiClientProvider).get('/users');
    return d is List ? d : [];
  } catch (_) {
    return [];
  }
});

final _roleFilterProvider = StateProvider.autoDispose<String>((ref) => 'all');
final _searchProvider = StateProvider.autoDispose<String>((ref) => '');

class NetworkScreen extends ConsumerWidget {
  const NetworkScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final people = ref.watch(networkProvider);
    final role = ref.watch(_roleFilterProvider);
    final search = ref.watch(_searchProvider).toLowerCase();
    return Scaffold(
      appBar: const NuzlAppBar(title: 'Network'),
      drawer: const NuzlDrawer(),
      body: ResponsiveCenter(
        child: people.when(
          loading: () => const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator())),
          error: (e, _) => Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(friendlyError(e)))),
          data: (list) {
            final roles = <String>{
              'all',
              ...list.map((e) => '${(e as Map)['role'] ?? ''}').where((r) => r.isNotEmpty),
            };
            final filtered = list.where((e) {
              final m = Map<String, dynamic>.from(e);
              final matchRole = role == 'all' || '${m['role']}' == role;
              final matchSearch = search.isEmpty ||
                  '${m['full_name'] ?? ''}'.toLowerCase().contains(search) ||
                  '${m['email'] ?? ''}'.toLowerCase().contains(search);
              return matchRole && matchSearch;
            }).toList();
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.x16),
                  child: Column(children: [
                    TextField(
                      decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.search), hintText: 'Search name or email'),
                      onChanged: (v) => ref.read(_searchProvider.notifier).state = v,
                    ),
                    const SizedBox(height: AppSpacing.x8),
                    SizedBox(
                      height: 40,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: roles.map((r) {
                          return Padding(
                            padding: const EdgeInsets.only(right: AppSpacing.x8),
                            child: ChoiceChip(
                              label: Text(r == 'all' ? 'All' : _humanize(r)),
                              selected: r == role,
                              onSelected: (_) => ref.read(_roleFilterProvider.notifier).state = r,
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ]),
                ),
                Expanded(
                  child: filtered.isEmpty
                      ? const Center(child: Text('No people match.'))
                      : ListView.separated(
                          padding: const EdgeInsets.all(AppSpacing.x16),
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.x8),
                          itemBuilder: (_, i) {
                            final m = Map<String, dynamic>.from(filtered[i]);
                            final name = '${m['full_name'] ?? 'Member'}';
                            return Card(
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: AppColors.primary,
                                  child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                                      style: const TextStyle(color: Colors.white)),
                                ),
                                title: Text(name),
                                subtitle: Text([m['role'], m['email']]
                                    .where((x) => x != null && '$x'.isNotEmpty)
                                    .join(' · ')),
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
}

String _humanize(String k) => k
    .replaceAll('_', ' ')
    .split(' ')
    .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
    .join(' ');
