import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/responsive.dart';
import '../shell/app_shell.dart';

/// The user's saved searches (criteria). Graceful: [] on any error / pre-migration.
final savedSearchesProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  try {
    final d = await ref.read(apiClientProvider).get(Api.savedSearches);
    return d is List ? d : [];
  } catch (_) {
    return [];
  }
});

/// New-listing matches for the user's saved searches: { unread, items }.
final savedSearchAlertsProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  try {
    final d = await ref.read(apiClientProvider).get(Api.savedSearchAlerts);
    return d is Map ? Map<String, dynamic>.from(d) : <String, dynamic>{'unread': 0, 'items': []};
  } catch (_) {
    return <String, dynamic>{'unread': 0, 'items': []};
  }
});

int _asInt(dynamic v) => v is int ? v : int.tryParse('$v') ?? 0;

Future<void> _createSavedSearch(WidgetRef ref, Map<String, dynamic> body) async {
  await ref.read(apiClientProvider).post(Api.savedSearches, body: body);
  ref.invalidate(savedSearchesProvider);
}

Future<void> _deleteSavedSearch(WidgetRef ref, String id) async {
  await ref.read(apiClientProvider).delete(Api.savedSearch(id));
  ref.invalidate(savedSearchesProvider);
}

/// App-bar action on the Properties screen — saves the current filter set as a
/// saved search (with optional name) so the user gets alerts on new matches.
class SaveSearchAction extends ConsumerWidget {
  const SaveSearchAction({super.key, required this.filters});

  /// Already mapped to the API's saved_searches fields (purpose, property_type,
  /// max_price, min_bedrooms, …) — null/absent values are simply omitted.
  final Map<String, dynamic> filters;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IconButton(
      tooltip: 'Save this search',
      icon: const Icon(Icons.bookmark_add_outlined),
      onPressed: () => _save(context, ref),
    );
  }

  Future<void> _save(BuildContext context, WidgetRef ref) async {
    final nameCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Save search'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: nameCtrl,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Name (optional)',
                hintText: 'e.g. 2BR in JVC under 1.5M',
              ),
            ),
            const SizedBox(height: AppSpacing.x12),
            const Text('We’ll alert you when a new listing matches these filters.',
                style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final body = <String, dynamic>{
        ...filters,
        if (nameCtrl.text.trim().isNotEmpty) 'name': nameCtrl.text.trim(),
        'notify': true,
      };
      await _createSavedSearch(ref, body);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Search saved — we’ll alert you on new matches.')));
      }
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }
}

/// Bell with an unread-match badge → opens the Saved searches screen.
class SavedSearchAlertsBell extends ConsumerWidget {
  const SavedSearchAlertsBell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(savedSearchAlertsProvider)
        .maybeWhen(data: (m) => _asInt(m['unread']), orElse: () => 0);
    return Stack(alignment: Alignment.center, children: [
      IconButton(
        tooltip: 'Saved-search alerts',
        icon: const Icon(Icons.saved_search),
        onPressed: () => context.push('/saved-searches'),
      ),
      if (unread > 0)
        Positioned(
          right: 8, top: 8,
          child: Container(
            padding: const EdgeInsets.all(3),
            decoration: const BoxDecoration(color: AppColors.danger, shape: BoxShape.circle),
            constraints: const BoxConstraints(minWidth: 15, minHeight: 15),
            child: Text(unread > 9 ? '9+' : '$unread',
                style: const TextStyle(color: Colors.white, fontSize: 9, height: 1),
                textAlign: TextAlign.center),
          ),
        ),
    ]);
  }
}

class SavedSearchesScreen extends ConsumerStatefulWidget {
  const SavedSearchesScreen({super.key});
  @override
  ConsumerState<SavedSearchesScreen> createState() => _SavedSearchesScreenState();
}

class _SavedSearchesScreenState extends ConsumerState<SavedSearchesScreen> {
  @override
  void initState() {
    super.initState();
    // Clear the unread badge on open.
    Future.microtask(() async {
      try {
        await ref.read(apiClientProvider).post(Api.savedSearchAlertsSeen);
        ref.invalidate(savedSearchAlertsProvider);
      } catch (_) {/* best-effort */}
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final searches = ref.watch(savedSearchesProvider);
    final alerts = ref.watch(savedSearchAlertsProvider);

    return Scaffold(
      appBar: const NuzlAppBar(title: 'Saved searches'),
      drawer: const NuzlDrawer(),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(savedSearchesProvider);
          ref.invalidate(savedSearchAlertsProvider);
          await ref.read(savedSearchesProvider.future);
        },
        child: ResponsiveCenter(
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.x16),
            children: [
              // ── New matches ──────────────────────────────────────
              alerts.maybeWhen(
                data: (m) {
                  final items = (m['items'] as List?) ?? const [];
                  if (items.isEmpty) return const SizedBox.shrink();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('New matches', style: t.titleMedium),
                      const SizedBox(height: AppSpacing.x8),
                      ...items.map((e) => _AlertCard(Map<String, dynamic>.from(e))),
                      const SizedBox(height: AppSpacing.x20),
                    ],
                  );
                },
                orElse: () => const SizedBox.shrink(),
              ),
              // ── Saved searches ───────────────────────────────────
              Text('Your saved searches', style: t.titleMedium),
              const SizedBox(height: AppSpacing.x8),
              searches.when(
                loading: () => const Padding(
                    padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator())),
                error: (e, _) => Padding(padding: const EdgeInsets.all(24), child: Text('$e')),
                data: (list) => list.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 32),
                        child: Center(
                          child: Text(
                            'No saved searches yet.\nUse “Save search” on the Properties screen to get alerts on new matches.',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                    : Column(
                        children: list
                            .map((e) => _SearchTile(
                                  Map<String, dynamic>.from(e),
                                  onDelete: () => _confirmDelete(context, '${(e as Map)['id']}'),
                                ))
                            .toList(),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete saved search?'),
        content: const Text('You will stop receiving alerts for it.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _deleteSavedSearch(ref, id);
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }
}

class _SearchTile extends StatelessWidget {
  const _SearchTile(this.m, {required this.onDelete});
  final Map<String, dynamic> m;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final name = '${m['name'] ?? ''}'.trim();
    return Card(
      child: ListTile(
        leading: const Icon(Icons.search, color: AppColors.primary),
        title: Text(name.isEmpty ? _summary(m) : name, style: t.titleSmall),
        subtitle: name.isEmpty ? null : Text(_summary(m), style: t.bodySmall?.copyWith(color: AppColors.textMuted)),
        trailing: IconButton(
          tooltip: 'Delete',
          icon: const Icon(Icons.delete_outline, color: AppColors.danger),
          onPressed: onDelete,
        ),
      ),
    );
  }

  static String _summary(Map<String, dynamic> m) {
    final money = NumberFormat.compact();
    final parts = <String>[];
    if (m['purpose'] != null) parts.add('${m['purpose']}' == 'rent' ? 'For rent' : 'For sale');
    if (m['property_type'] != null) parts.add(_cap('${m['property_type']}'));
    if (m['min_bedrooms'] != null) parts.add('${m['min_bedrooms']}+ BR');
    if (m['min_price'] != null) parts.add('≥ AED ${money.format(num.tryParse('${m['min_price']}') ?? 0)}');
    if (m['max_price'] != null) parts.add('≤ AED ${money.format(num.tryParse('${m['max_price']}') ?? 0)}');
    return parts.isEmpty ? 'Any property' : parts.join(' · ');
  }
}

class _AlertCard extends StatelessWidget {
  const _AlertCard(this.m);
  final Map<String, dynamic> m;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final id = '${m['listing_id']}';
    final price = num.tryParse('${m['price']}') ?? 0;
    final money = price > 0 ? NumberFormat.currency(symbol: 'AED ', decimalDigits: 0).format(price) : '';
    final beds = m['bedrooms'] == null ? '' : '${m['bedrooms']}BR ';
    final type = '${m['property_type'] ?? ''}'.replaceAll('_', ' ');
    final community = '${m['community'] ?? ''}';
    final cover = '${m['cover_image'] ?? ''}';
    final title = '$beds$type'.trim().isEmpty ? 'Property' : '$beds$type';
    return Card(
      child: InkWell(
        onTap: () => context.push('/listings/$id'),
        borderRadius: BorderRadius.circular(AppSpacing.rCard),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.x12),
          child: Row(children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(AppSpacing.rSm),
              child: cover.isNotEmpty
                  ? Image.network(cover, width: 64, height: 64, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(width: 64, height: 64, color: AppColors.surface2,
                          child: const Icon(Icons.image_outlined, color: AppColors.textMuted)))
                  : Container(width: 64, height: 64, color: AppColors.surface2,
                      child: const Icon(Icons.apartment_outlined, color: AppColors.textMuted)),
            ),
            const SizedBox(width: AppSpacing.x12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: t.titleSmall),
                if (community.isNotEmpty) Text(community, style: t.bodySmall?.copyWith(color: AppColors.textMuted)),
                if (money.isNotEmpty)
                  Text(money, style: t.titleSmall?.copyWith(color: AppColors.primary, fontWeight: FontWeight.w700)),
              ]),
            ),
            const Icon(Icons.chevron_right, color: AppColors.textSubtle),
          ]),
        ),
      ),
    );
  }
}

String _cap(String s) {
  final x = s.replaceAll('_', ' ').trim();
  return x.isEmpty ? x : '${x[0].toUpperCase()}${x.substring(1)}';
}
