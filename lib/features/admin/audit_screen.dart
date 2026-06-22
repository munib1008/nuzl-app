import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/responsive.dart';
import '../../core/widgets/status_badge.dart';
import '../shell/app_shell.dart';

/// Read-only audit viewer (super-admin). GET /admin/audit.
final auditProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  try {
    final d = await ref.read(apiClientProvider).get('/admin/audit', query: {'limit': '200'});
    return d is List ? d : [];
  } catch (_) {
    return [];
  }
});

final _auditSearchProvider = StateProvider.autoDispose<String>((ref) => '');

class AuditScreen extends ConsumerWidget {
  const AuditScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logs = ref.watch(auditProvider);
    final search = ref.watch(_auditSearchProvider).toLowerCase();
    return Scaffold(
      appBar: NuzlAppBar(title: context.tr('Audit Logs')),
      drawer: const NuzlDrawer(),
      body: ResponsiveCenter(
        child: logs.when(
          loading: () => const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator())),
          error: (e, _) => Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(friendlyError(e)))),
          data: (list) {
            final filtered = list.where((e) {
              if (search.isEmpty) return true;
              final m = Map<String, dynamic>.from(e);
              return '${m['action']} ${m['entity_table']} ${m['actor_name']}'.toLowerCase().contains(search);
            }).toList();
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.x16),
                  child: TextField(
                    decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.search),
                        hintText: context.tr('Filter by action, entity or user')),
                    onChanged: (v) => ref.read(_auditSearchProvider.notifier).state = v,
                  ),
                ),
                Expanded(
                  child: filtered.isEmpty
                      ? Center(child: Text(context.tr('No audit entries.')))
                      : ListView.separated(
                          padding: const EdgeInsets.all(AppSpacing.x16),
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.x8),
                          itemBuilder: (_, i) {
                            final m = Map<String, dynamic>.from(filtered[i]);
                            final created = DateTime.tryParse('${m['created_at']}');
                            final when = created != null
                                ? DateFormat('d MMM y · HH:mm').format(created)
                                : '';
                            return Card(
                              child: ListTile(
                                leading: const Icon(Icons.receipt_long_outlined),
                                title: Text('${m['action'] ?? context.tr('action')} · ${m['entity_table'] ?? ''}'),
                                subtitle: Text([m['actor_name'], when]
                                    .where((x) => x != null && '$x'.isNotEmpty)
                                    .join('  ·  ')),
                                trailing: m['is_test'] == true
                                    ? StatusBadge(context.tr('test'), tone: BadgeTone.warning)
                                    : null,
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
