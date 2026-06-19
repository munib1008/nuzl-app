import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/app_dialog.dart';
import '../../core/widgets/responsive.dart';
import '../shell/app_shell.dart';

/// Super-admin: the admin-configurable free usage allowances.
/// Changes apply immediately (no deploy) — the "nothing hardcoded" rule.
final limitsProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  try {
    final d = await ref.read(apiClientProvider).get('/admin/limits');
    return d is List ? d : [];
  } catch (_) {
    return [];
  }
});

class LimitsScreen extends ConsumerWidget {
  const LimitsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final limits = ref.watch(limitsProvider);
    return Scaffold(
      appBar: const NuzlAppBar(title: 'Usage Limits'),
      drawer: const NuzlDrawer(),
      body: ResponsiveCenter(
        child: limits.when(
          loading: () => const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator())),
          error: (e, _) => Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(friendlyError(e)))),
          data: (list) => list.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(40),
                    child: Text('No limits configured yet.\nRun db/migrate_usage_limits.sql on Supabase.',
                        textAlign: TextAlign.center),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(AppSpacing.x16),
                  children: [
                    Text('Free usage allowances. Changes apply immediately — no deployment.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textMuted)),
                    const SizedBox(height: AppSpacing.x12),
                    ...list.map((e) => _LimitTile(Map<String, dynamic>.from(e))),
                  ],
                ),
        ),
      ),
    );
  }
}

class _LimitTile extends ConsumerWidget {
  const _LimitTile(this.m);
  final Map<String, dynamic> m;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = num.tryParse('${m['value']}')?.toInt() ?? 0;
    final period = '${m['period'] ?? 'day'}';
    final soft = m['soft'] == true;
    return Card(
      child: ListTile(
        leading: const Icon(Icons.speed_outlined),
        title: Text(_humanize('${m['key']}')),
        subtitle: Text([
          if ('${m['description'] ?? ''}'.isNotEmpty) '${m['description']}',
          value == 0 ? 'Unlimited' : '$value per $period${soft ? '  ·  soft' : ''}',
        ].join('\n')),
        isThreeLine: true,
        trailing: const Icon(Icons.edit_outlined),
        onTap: () => _edit(context, ref),
      ),
    );
  }

  Future<void> _edit(BuildContext context, WidgetRef ref) async {
    final valueCtl = TextEditingController(text: '${m['value'] ?? 0}');
    var period = const ['day', 'week', 'month', 'year'].contains('${m['period']}') ? '${m['period']}' : 'day';
    var soft = m['soft'] == true;
    final ok = await AppDialog.show<bool>(
      context,
      title: _humanize('${m['key']}'),
      maxWidth: 460,
      children: [
        StatefulBuilder(
          builder: (ctx, setS) => Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
              controller: valueCtl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Free amount (0 = unlimited)'),
            ),
            const SizedBox(height: AppSpacing.x8),
            DropdownButtonFormField<String>(
              initialValue: period,
              decoration: const InputDecoration(labelText: 'Period'),
              items: const [
                DropdownMenuItem(value: 'day', child: Text('Per day')),
                DropdownMenuItem(value: 'week', child: Text('Per week')),
                DropdownMenuItem(value: 'month', child: Text('Per month')),
                DropdownMenuItem(value: 'year', child: Text('Per year')),
              ],
              onChanged: (v) => setS(() => period = v ?? 'day'),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Soft limit (allow + flag, don’t block)'),
              value: soft,
              activeThumbColor: AppColors.primary,
              onChanged: (v) => setS(() => soft = v),
            ),
          ]),
        ),
      ],
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save')),
      ],
    );
    if (ok != true) return;
    try {
      await ref.read(apiClientProvider).patch('/admin/limits/${m['key']}', body: {
        'value': int.tryParse(valueCtl.text.trim()) ?? 0,
        'period': period,
        'soft': soft,
      });
      ref.invalidate(limitsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Limit updated')));
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
