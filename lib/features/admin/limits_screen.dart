import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/api_client.dart';
import '../../core/i18n/app_localizations.dart';
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
      appBar: NuzlAppBar(title: context.tr('Usage Limits')),
      drawer: const NuzlDrawer(),
      body: ResponsiveCenter(
        child: limits.when(
          loading: () => const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator())),
          error: (e, _) => Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(friendlyError(e)))),
          data: (list) => list.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(40),
                    child: Text(context.tr('No limits configured yet.\nRun db/migrate_usage_limits.sql on Supabase.'),
                        textAlign: TextAlign.center),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(AppSpacing.x16),
                  children: [
                    Text(context.tr('Free usage allowances. Changes apply immediately — no deployment.'),
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
          value == 0 ? context.tr('Unlimited') : '$value ${context.tr('per')} $period${soft ? '  ·  ' + context.tr('soft') : ''}',
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
              decoration: InputDecoration(labelText: context.tr('Free amount (0 = unlimited)')),
            ),
            const SizedBox(height: AppSpacing.x8),
            DropdownButtonFormField<String>(
              initialValue: period,
              decoration: InputDecoration(labelText: context.tr('Period')),
              items: [
                DropdownMenuItem(value: 'day', child: Text(context.tr('Per day'))),
                DropdownMenuItem(value: 'week', child: Text(context.tr('Per week'))),
                DropdownMenuItem(value: 'month', child: Text(context.tr('Per month'))),
                DropdownMenuItem(value: 'year', child: Text(context.tr('Per year'))),
              ],
              onChanged: (v) => setS(() => period = v ?? 'day'),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(context.tr('Soft limit (allow + flag, don’t block)')),
              value: soft,
              activeThumbColor: AppColors.primary,
              onChanged: (v) => setS(() => soft = v),
            ),
          ]),
        ),
      ],
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: Text(context.tr('Cancel'))),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(context.tr('Save'))),
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.tr('Limit updated'))));
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
