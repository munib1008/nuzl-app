import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/responsive.dart';
import '../shell/app_shell.dart';

final savedListingsProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  try {
    final d = await ref.read(apiClientProvider).get('/listings/saved/mine');
    return d is List ? d : [];
  } catch (_) {
    return [];
  }
});

final savedIdsProvider = FutureProvider.autoDispose<Set<String>>((ref) async {
  final list = await ref.watch(savedListingsProvider.future);
  return list.map((e) => '${(e as Map)['id']}').toSet();
});

Future<void> _toggleSaved(WidgetRef ref, String listingId) async {
  await ref.read(apiClientProvider).post('/listings/$listingId/save');
  ref.invalidate(savedListingsProvider);
}

/// Reusable bookmark toggle for a listing (used on the detail + saved cards).
class SaveListingButton extends ConsumerWidget {
  const SaveListingButton({super.key, required this.listingId});
  final String listingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final saved = ref.watch(savedIdsProvider).maybeWhen(data: (s) => s.contains(listingId), orElse: () => false);
    return IconButton(
      tooltip: saved ? 'Saved' : 'Save',
      icon: Icon(saved ? Icons.bookmark : Icons.bookmark_border, color: saved ? AppColors.primary : null),
      onPressed: () async {
        try {
          await _toggleSaved(ref, listingId);
        } catch (e) {
          if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
        }
      },
    );
  }
}

class SavedScreen extends ConsumerWidget {
  const SavedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final saved = ref.watch(savedListingsProvider);
    return Scaffold(
      appBar: NuzlAppBar(title: 'Saved', actions: [
        IconButton(
          tooltip: 'Saved searches',
          icon: const Icon(Icons.saved_search),
          onPressed: () => context.push('/saved-searches'),
        ),
      ]),
      drawer: const NuzlDrawer(),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(savedListingsProvider);
          await ref.read(savedListingsProvider.future);
        },
        child: ResponsiveCenter(
          child: saved.when(
            loading: () => const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator())),
            error: (e, _) => ListView(children: [Padding(padding: const EdgeInsets.all(24), child: Center(child: Text('$e')))]),
            data: (list) => list.isEmpty
                ? ListView(children: const [
                    Padding(
                      padding: EdgeInsets.all(48),
                      child: Center(child: Text('No saved properties yet.\nTap the bookmark on a listing to save it.', textAlign: TextAlign.center)),
                    ),
                  ])
                : ListView.separated(
                    padding: const EdgeInsets.all(AppSpacing.x16),
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.x12),
                    itemBuilder: (_, i) => _SavedCard(Map<String, dynamic>.from(list[i])),
                  ),
          ),
        ),
      ),
    );
  }
}

class _SavedCard extends StatelessWidget {
  const _SavedCard(this.m);
  final Map<String, dynamic> m;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final id = '${m['id']}';
    final price = num.tryParse('${m['price']}') ?? 0;
    final money = price > 0 ? NumberFormat.currency(symbol: 'AED ', decimalDigits: 0).format(price) : '';
    final beds = m['bedrooms'] == null ? '' : '${m['bedrooms']}BR ';
    final type = '${m['property_type'] ?? ''}'.replaceAll('_', ' ');
    final community = '${m['community'] ?? ''}';
    final cover = '${m['cover_image'] ?? ''}';
    final title = '$beds$type'.trim().isEmpty ? 'Property' : '$beds$type';
    return Card(
      child: InkWell(
        onTap: () => context.go('/listings/$id'),
        borderRadius: BorderRadius.circular(AppSpacing.rCard),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.x12),
          child: Row(children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(AppSpacing.rSm),
              child: cover.isNotEmpty
                  ? Image.network(cover, width: 72, height: 72, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(width: 72, height: 72, color: AppColors.surface2,
                          child: const Icon(Icons.image_outlined, color: AppColors.textMuted)))
                  : Container(width: 72, height: 72, color: AppColors.surface2,
                      child: const Icon(Icons.apartment_outlined, color: AppColors.textMuted)),
            ),
            const SizedBox(width: AppSpacing.x12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: t.titleSmall),
                if (community.isNotEmpty)
                  Text(community, style: t.bodySmall?.copyWith(color: AppColors.textMuted)),
                if (money.isNotEmpty)
                  Text(money, style: t.titleMedium?.copyWith(color: AppColors.primary, fontWeight: FontWeight.w700)),
              ]),
            ),
            SaveListingButton(listingId: id),
          ]),
        ),
      ),
    );
  }
}
