import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/responsive.dart';
import '../shell/app_shell.dart';

/// GET /admin/settings → { settings: {...}, defs: { key: {default,label,group,public} } }.
final _adminSettingsProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final d = await ref.read(apiClientProvider).get('/admin/settings');
  return d is Map ? Map<String, dynamic>.from(d) : <String, dynamic>{};
});

/// Admin platform-settings console (audit #1) — edit pricing, VAT, commission,
/// referral, plan enforcement, etc. instead of code constants. Grouped editor;
/// number/boolean/text fields inferred from each setting's default.
class AdminSettingsScreen extends ConsumerStatefulWidget {
  const AdminSettingsScreen({super.key});
  @override
  ConsumerState<AdminSettingsScreen> createState() => _AdminSettingsScreenState();
}

class _AdminSettingsScreenState extends ConsumerState<AdminSettingsScreen> {
  final _controllers = <String, TextEditingController>{};
  final _bools = <String, bool>{};
  bool _loaded = false;
  bool _saving = false;
  bool _purging = false;

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _hydrate(Map<String, dynamic> settings, Map<String, dynamic> defs) {
    if (_loaded) return;
    _loaded = true;
    defs.forEach((k, raw) {
      final def = Map<String, dynamic>.from(raw as Map);
      final v = settings[k];
      if (def['default'] is bool || v is bool) {
        _bools[k] = v == true;
      } else {
        _controllers[k] = TextEditingController(text: v == null ? '' : '$v');
      }
    });
  }

  Future<void> _save(Map<String, dynamic> defs) async {
    setState(() => _saving = true);
    final body = <String, dynamic>{};
    defs.forEach((k, raw) {
      final def = Map<String, dynamic>.from(raw as Map);
      if (_bools.containsKey(k)) {
        body[k] = _bools[k];
      } else {
        final txt = _controllers[k]?.text.trim() ?? '';
        body[k] = def['default'] is num ? (num.tryParse(txt) ?? def['default']) : txt;
      }
    });
    try {
      await ref.read(apiClientProvider).patch('/admin/settings', body: body);
      ref.invalidate(_adminSettingsProvider);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Settings saved')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(_adminSettingsProvider);
    return Scaffold(
      appBar: const NuzlAppBar(title: 'Settings'),
      drawer: const NuzlDrawer(),
      floatingActionButton: async.hasValue
          ? FloatingActionButton.extended(
              onPressed: _saving ? null : () => _save(Map<String, dynamic>.from(async.value!['defs'] as Map? ?? const {})),
              icon: _saving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.save_outlined),
              label: const Text('Save'),
            )
          : null,
      body: ResponsiveCenter(
        child: async.when(
          loading: () => const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator())),
          error: (e, _) => Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(friendlyError(e)))),
          data: (d) {
            final settings = Map<String, dynamic>.from(d['settings'] as Map? ?? const {});
            final defs = Map<String, dynamic>.from(d['defs'] as Map? ?? const {});
            if (defs.isEmpty) {
              return const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('No settings available.')));
            }
            _hydrate(settings, defs);
            final groups = <String, List<String>>{};
            defs.forEach((k, raw) {
              final g = '${(raw as Map)['group'] ?? 'Other'}';
              (groups[g] ??= []).add(k);
            });
            return ListView(
              padding: const EdgeInsets.all(AppSpacing.x16),
              children: [
                for (final entry in groups.entries) ...[
                  _group(context, entry.key, entry.value, defs),
                  const SizedBox(height: AppSpacing.x12),
                ],
                _dangerZone(context),
                const SizedBox(height: 72),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _dangerZone(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final muted = Theme.of(context).hintColor;
    return Card(
      color: Colors.red.withValues(alpha: 0.06),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.x16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.warning_amber_rounded, size: 18, color: Colors.red),
            const SizedBox(width: AppSpacing.x8),
            Text('Danger zone', style: t.titleSmall?.copyWith(fontWeight: FontWeight.w700, color: Colors.red)),
          ]),
          const SizedBox(height: AppSpacing.x8),
          Text(
            'Permanently delete all seed/demo data: test accounts (@nuzl.test, @demo.nuzl.ae), demo '
            'listings, properties, marketplace items and posts. Real accounts and admin@nuzl.ae are kept. '
            'Reversible only by re-seeding. Also set SEED_TEST_ACCOUNTS=false in the API env so it does not '
            'recreate test accounts on the next deploy.',
            style: t.bodySmall?.copyWith(color: muted),
          ),
          const SizedBox(height: AppSpacing.x12),
          OutlinedButton.icon(
            onPressed: _purging ? null : _purgeDemo,
            style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red)),
            icon: _purging
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.red))
                : const Icon(Icons.delete_sweep_outlined, size: 18),
            label: const Text('Purge demo / test data'),
          ),
        ]),
      ),
    );
  }

  Future<void> _purgeDemo() async {
    final confirm = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Purge demo / test data'),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('This permanently deletes all seed/demo records. Real users and admin@nuzl.ae are kept. '
              'Type PURGE to confirm.'),
          const SizedBox(height: AppSpacing.x12),
          TextField(controller: confirm, autofocus: true, decoration: const InputDecoration(hintText: 'PURGE')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, confirm.text.trim().toUpperCase() == 'PURGE'),
            child: const Text('Purge'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _purging = true);
    try {
      final res = await ref.read(apiClientProvider).post('/admin/purge-demo-data');
      final del = (res is Map && res['deleted'] is Map) ? Map<String, dynamic>.from(res['deleted'] as Map) : {};
      final total = del.values.fold<int>(0, (s, v) => s + (int.tryParse('$v') ?? 0));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Demo data purged — $total records removed. Hard-refresh to see the clean state.')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
    } finally {
      if (mounted) setState(() => _purging = false);
    }
  }

  Widget _group(BuildContext context, String group, List<String> keys, Map<String, dynamic> defs) {
    final t = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.x16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(group, style: t.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: AppSpacing.x4),
          for (final k in keys) _field(k, Map<String, dynamic>.from(defs[k] as Map)),
        ]),
      ),
    );
  }

  Widget _field(String k, Map<String, dynamic> def) {
    final label = '${def['label'] ?? k}';
    if (_bools.containsKey(k)) {
      return SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(label),
        value: _bools[k] ?? false,
        onChanged: (v) => setState(() => _bools[k] = v),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.x8),
      child: TextField(
        controller: _controllers[k],
        keyboardType: def['default'] is num ? TextInputType.number : TextInputType.text,
        decoration: InputDecoration(labelText: label),
      ),
    );
  }
}
