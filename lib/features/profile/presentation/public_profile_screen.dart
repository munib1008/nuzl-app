import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/network/api_client.dart';
import '../../../core/rbac/persona.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/nuzl_logo.dart';

final _publicUserProvider = FutureProvider.autoDispose.family<Map<String, dynamic>, String>((ref, id) async {
  final d = await ref.read(apiClientProvider).get('/public/users/$id');
  return d is Map ? Map<String, dynamic>.from(d) : <String, dynamic>{};
});

final _publicListingsProvider = FutureProvider.autoDispose.family<List<dynamic>, String>((ref, id) async {
  try {
    final d = await ref.read(apiClientProvider).get('/public/users/$id/listings');
    return d is List ? d : [];
  } catch (_) {
    return [];
  }
});

final _reviewsProvider = FutureProvider.autoDispose.family<List<dynamic>, String>((ref, id) async {
  try {
    final d = await ref.read(apiClientProvider).get('/reviews', query: {'subject_type': 'agent', 'subject_id': id});
    return d is List ? d : [];
  } catch (_) {
    return [];
  }
});

/// Read-only, shareable public profile for agencies / agents / owner-sellers.
class PublicProfileScreen extends ConsumerWidget {
  const PublicProfileScreen({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(_publicUserProvider(id));
    return Scaffold(
      appBar: AppBar(
        title: const NuzlLogo(size: 26),
        leading: Navigator.of(context).canPop()
            ? IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.pop())
            : null,
      ),
      body: user.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.x24),
            child: Text('This profile is not available.', style: Theme.of(context).textTheme.bodyMedium),
          ),
        ),
        data: (m) => _Body(id: id, user: m),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.id, required this.user});
  final String id;
  final Map<String, dynamic> user;

  List<String> _list(dynamic v) => v is List ? v.map((e) => '$e').toList() : const [];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final name = '${user['full_name'] ?? 'Member'}';
    final role = personaFromRole('${user['role'] ?? ''}').label;
    final reraVerified = '${user['rera_brn'] ?? ''}'.trim().isNotEmpty;
    final areas = _list(user['areas']);
    final languages = _list(user['languages']);
    final specialties = _list(user['specialties']);
    final listings = ref.watch(_publicListingsProvider(id));
    final reviews = ref.watch(_reviewsProvider(id));

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.x16),
      children: [
        Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // header
                Center(
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 40,
                        backgroundColor: AppColors.primary,
                        child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                            style: t.headlineMedium?.copyWith(color: Colors.white)),
                      ),
                      const SizedBox(height: AppSpacing.x12),
                      Text(name, style: t.headlineSmall),
                      const SizedBox(height: AppSpacing.x4),
                      Wrap(
                        spacing: AppSpacing.x8,
                        alignment: WrapAlignment.center,
                        children: [
                          _Pill(text: role, color: AppColors.primaryTint, textColor: AppColors.primaryDark),
                          if (reraVerified)
                            const _Pill(text: 'RERA verified', color: AppColors.accentGoldTint, textColor: AppColors.secondary, icon: Icons.verified_outlined),
                        ],
                      ),
                      if ('${user['company'] ?? ''}'.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.x8),
                        Text('${user['company']}', style: t.bodyMedium?.copyWith(color: AppColors.textMuted)),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.x24),
                if (areas.isNotEmpty) _ChipBlock(label: 'Areas covered', values: areas),
                if (languages.isNotEmpty) _ChipBlock(label: 'Languages', values: languages),
                if (specialties.isNotEmpty) _ChipBlock(label: 'Specialties', values: specialties),

                // reviews summary
                reviews.maybeWhen(
                  data: (list) => list.isEmpty ? const SizedBox.shrink() : _ReviewsSection(reviews: list),
                  orElse: () => const SizedBox.shrink(),
                ),

                const SizedBox(height: AppSpacing.x16),
                Text('Active listings', style: t.titleMedium),
                const SizedBox(height: AppSpacing.x8),
                listings.when(
                  loading: () => const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator())),
                  error: (e, _) => const Text('No listings.'),
                  data: (list) => list.isEmpty
                      ? Text('No active listings.', style: t.bodySmall?.copyWith(color: AppColors.textMuted))
                      : Column(children: list.map((e) => _PublicListingCard(Map<String, dynamic>.from(e))).toList()),
                ),
                const SizedBox(height: AppSpacing.x32),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.text, required this.color, required this.textColor, this.icon});
  final String text;
  final Color color;
  final Color textColor;
  final IconData? icon;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(AppSpacing.rFull)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[Icon(icon, size: 14, color: textColor), const SizedBox(width: 4)],
        Text(text, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: textColor, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

class _ChipBlock extends StatelessWidget {
  const _ChipBlock({required this.label, required this.values});
  final String label;
  final List<String> values;
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.x12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: t.titleSmall),
          const SizedBox(height: AppSpacing.x8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: values
                .map((v) => Chip(label: Text(v), materialTapTargetSize: MaterialTapTargetSize.shrinkWrap))
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _ReviewsSection extends StatelessWidget {
  const _ReviewsSection({required this.reviews});
  final List<dynamic> reviews;
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final ratings = reviews
        .map((e) => num.tryParse('${(e as Map)['rating']}') ?? 0)
        .where((r) => r > 0)
        .toList();
    final avg = ratings.isEmpty ? 0 : ratings.reduce((a, b) => a + b) / ratings.length;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.x8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.star, color: AppColors.accentGold, size: 20),
            const SizedBox(width: 4),
            Text(avg.toStringAsFixed(1), style: t.titleMedium),
            const SizedBox(width: 6),
            Text('(${reviews.length} reviews)', style: t.bodySmall?.copyWith(color: AppColors.textMuted)),
          ]),
          const SizedBox(height: AppSpacing.x8),
          ...reviews.take(5).map((e) {
            final m = Map<String, dynamic>.from(e);
            return ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.format_quote, color: AppColors.textMuted),
              title: Text('${m['comment'] ?? ''}'),
              subtitle: Text('${m['rater'] ?? 'Anonymous'} · ${m['rating'] ?? '-'}★'),
            );
          }),
        ],
      ),
    );
  }
}

class _PublicListingCard extends StatelessWidget {
  const _PublicListingCard(this.l);
  final Map<String, dynamic> l;
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final price = num.tryParse('${l['price']}') ?? 0;
    final money = NumberFormat.currency(symbol: 'AED ', decimalDigits: 0).format(price);
    final cover = '${l['cover_image'] ?? ''}';
    final facts = [
      if (l['community'] != null) '${l['community']}',
      if (l['bedrooms'] != null) '${l['bedrooms']} BR',
      if (l['size_sqft'] != null) '${(num.tryParse('${l['size_sqft']}') ?? 0).toStringAsFixed(0)} sqft',
    ].join('  ·  ');
    return Card(
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.only(bottom: AppSpacing.x12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: cover.isEmpty
                ? Container(
                    color: AppColors.surface2,
                    child: const Center(child: Icon(Icons.apartment_outlined, size: 40, color: AppColors.textSubtle)),
                  )
                : Image.network(cover, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                        color: AppColors.surface2,
                        child: const Center(child: Icon(Icons.apartment_outlined, size: 40, color: AppColors.textSubtle)))),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.x12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(money, style: t.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(facts, style: t.bodySmall?.copyWith(color: AppColors.textMuted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
