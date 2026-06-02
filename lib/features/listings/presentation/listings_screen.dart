import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/async_view.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/status_badge.dart';
import '../data/listings_repository.dart';
import '../domain/listing.dart';
import '../../shell/app_shell.dart';

class ListingsScreen extends ConsumerWidget {
  const ListingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listings = ref.watch(listingsProvider);
    return Scaffold(
      appBar: const NuzlAppBar(title: 'Properties'),
      drawer: const NuzlDrawer(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/properties/new'),
        icon: const Icon(Icons.add),
        label: const Text('New listing'),
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.refresh(listingsProvider.future),
        child: AsyncView<List<Listing>>(
          value: listings,
          onRetry: () => ref.refresh(listingsProvider),
          data: (items) {
            if (items.isEmpty) {
              return const EmptyState(
                icon: Icons.apartment_outlined,
                title: 'No properties yet',
                message: 'Add your first listing to start matching it to buyers.',
                actionLabel: 'Add listing',
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.x16),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.x12),
              itemBuilder: (_, i) => _ListingCard(items[i]),
            );
          },
        ),
      ),
    );
  }
}

class _ListingCard extends StatelessWidget {
  const _ListingCard(this.l);
  final Listing l;

  BadgeTone get _availTone => switch (l.availability) {
        'verified' => BadgeTone.success,
        'expired' => BadgeTone.danger,
        _ => BadgeTone.warning,
      };

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final price = NumberFormat.currency(symbol: 'AED ', decimalDigits: 0).format(l.price);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.x16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(child: Text(price, style: t.titleLarge)),
              StatusBadge(l.availability ?? 'unverified', tone: _availTone),
            ]),
            const SizedBox(height: AppSpacing.x4),
            Text([
              if (l.community != null) l.community,
              if (l.bedrooms != null) '${l.bedrooms} BR',
              if (l.sizeSqft != null) '${l.sizeSqft!.toStringAsFixed(0)} sqft',
              if (l.purpose != null) 'for ${l.purpose}',
            ].whereType<String>().join('  ·  '), style: t.bodyMedium),
            const SizedBox(height: AppSpacing.x8),
            Align(
              alignment: Alignment.centerLeft,
              child: StatusBadge(l.status ?? 'available',
                  tone: l.status == 'held' ? BadgeTone.warning : BadgeTone.neutral),
            ),
          ],
        ),
      ),
    );
  }
}
