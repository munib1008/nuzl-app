import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/responsive.dart';
import '../shell/app_shell.dart';

final jobsProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  try { final d = await ref.read(apiClientProvider).get('/maintenance/jobs'); return d is List ? d : []; } catch (_) { return []; }
});
final providersProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  try { final d = await ref.read(apiClientProvider).get('/service-providers'); return d is List ? d : []; } catch (_) { return []; }
});

class MaintenanceScreen extends ConsumerWidget {
  const MaintenanceScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jobs = ref.watch(jobsProvider);
    final providers = ref.watch(providersProvider);
    return Scaffold(
      appBar: const NuzlAppBar(title: 'Maintenance'),
      drawer: const NuzlDrawer(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _request(context, ref), icon: const Icon(Icons.build_outlined), label: const Text('Request job')),
      body: ResponsiveCenter(
        child: RefreshIndicator(
          onRefresh: () async { ref.invalidate(jobsProvider); ref.invalidate(providersProvider); },
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.x16),
            children: [
              Text('Jobs', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: AppSpacing.x8),
              jobs.when(
                loading: () => const LinearProgressIndicator(),
                error: (e, _) => Text('$e'),
                data: (list) => list.isEmpty
                    ? const Text('No jobs yet — request one below.')
                    : Column(children: list.map((m) {
                        final j = Map<String, dynamic>.from(m);
                        return Card(child: ListTile(
                          title: Text('${j['category']} · ${j['provider_name'] ?? 'Unassigned'}'),
                          subtitle: Text(j['description'] ?? ''),
                          trailing: _StatusChip(status: '${j['status']}'),
                          onTap: () => _advance(context, ref, j['id'].toString(), '${j['status']}'),
                        ));
                      }).toList()),
              ),
              const SizedBox(height: AppSpacing.x24),
              Text('Service providers', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: AppSpacing.x8),
              providers.when(
                loading: () => const LinearProgressIndicator(),
                error: (e, _) => Text('$e'),
                data: (list) => list.isEmpty
                    ? const Text('No providers listed yet.')
                    : Column(children: list.map((m) {
                        final p = Map<String, dynamic>.from(m);
                        final cats = (p['categories'] is List) ? (p['categories'] as List).join(', ') : '';
                        return Card(child: ListTile(
                          leading: const CircleAvatar(child: Icon(Icons.handyman_outlined)),
                          title: Text(p['name'] ?? 'Provider'),
                          subtitle: Text(cats),
                          trailing: Text('★ ${p['rating'] ?? 0}'),
                        ));
                      }).toList()),
              ),
              const SizedBox(height: AppSpacing.x24),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _request(BuildContext context, WidgetRef ref) async {
    final cat = TextEditingController(text: 'ac'); final desc = TextEditingController();
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Request maintenance'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: cat, decoration: const InputDecoration(labelText: 'Category', hintText: 'ac, plumbing, electrical…')),
        TextField(controller: desc, maxLines: 2, decoration: const InputDecoration(labelText: 'Describe the issue')),
      ]),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Request'))],
    ));
    if (ok != true) return;
    try {
      await ref.read(apiClientProvider).post('/maintenance/jobs', body: {'category': cat.text.trim(), 'description': desc.text.trim()});
      ref.invalidate(jobsProvider);
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _advance(BuildContext context, WidgetRef ref, String id, String current) async {
    const flow = ['requested','matched','accepted','in_progress','completed','cancelled'];
    final picked = await showModalBottomSheet<String>(context: context, builder: (ctx) => SafeArea(
      child: ListView(shrinkWrap: true, children: flow.map((s) => ListTile(
        title: Text(s), trailing: s == current ? const Icon(Icons.check, color: AppColors.primary) : null,
        onTap: () => Navigator.pop(ctx, s))).toList())));
    if (picked == null || picked == current) return;
    await ref.read(apiClientProvider).patch('/maintenance/jobs/$id/status', body: {'status': picked});
    ref.invalidate(jobsProvider);
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final String status;
  @override
  Widget build(BuildContext context) {
    final done = status == 'completed';
    final cancelled = status == 'cancelled';
    final color = cancelled ? Colors.redAccent : done ? AppColors.primary : AppColors.accentGold;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(AppSpacing.rFull)),
      child: Text(status, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12)));
  }
}
