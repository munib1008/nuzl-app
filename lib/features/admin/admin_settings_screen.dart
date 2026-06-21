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
                const SizedBox(height: 72),
              ],
            );
          },
        ),
      ),
    );
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
