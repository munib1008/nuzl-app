import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/network/api_client.dart';
import '../../../core/rbac/persona.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/nuzl_logo.dart';
import '../../../core/widgets/follow_button.dart';
import '../../auth/application/auth_controller.dart';
import '../../messages/data/messaging_repository.dart';

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
    final avatarUrl = '${user['avatar_url'] ?? ''}'.trim();
    final bio = '${user['bio'] ?? ''}'.trim();
    final company = '${user['company'] ?? ''}'.trim();
    final orgName = '${user['org_name'] ?? ''}'.trim();
    final orgSlug = '${user['org_slug'] ?? ''}'.trim();
    final phone = '${user['phone'] ?? ''}'.trim();
    final whatsapp = '${user['whatsapp'] ?? ''}'.trim();
    final areas = _list(user['areas']);
    final languages = _list(user['languages']);
    final specialties = _list(user['specialties']);
    final listings = ref.watch(_publicListingsProvider(id));
    final reviews = ref.watch(_reviewsProvider(id));

    final listingCount = listings.asData?.value.length ?? 0;
    final ratings = (reviews.asData?.value ?? const [])
        .map((e) => num.tryParse('${(e as Map)['rating']}') ?? 0)
        .where((r) => r > 0)
        .toList();
    final avg = ratings.isEmpty ? null : ratings.reduce((a, b) => a + b) / ratings.length;

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.x16),
      children: [
        Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // header
                Center(
                  child: Column(
                    children: [
                      if (avatarUrl.isNotEmpty)
                        CircleAvatar(radius: 44, backgroundColor: AppColors.surface2, backgroundImage: NetworkImage(avatarUrl))
                      else
                        CircleAvatar(
                          radius: 44,
                          backgroundColor: AppColors.primary,
                          child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                              style: t.headlineMedium?.copyWith(color: Colors.white)),
                        ),
                      const SizedBox(height: AppSpacing.x12),
                      Text(name, style: t.headlineSmall, textAlign: TextAlign.center),
                      const SizedBox(height: AppSpacing.x8),
                      Center(child: FollowButton(targetId: id)),
                      const SizedBox(height: AppSpacing.x8),
                      Wrap(
                        spacing: AppSpacing.x8,
                        runSpacing: AppSpacing.x8,
                        alignment: WrapAlignment.center,
                        children: [
                          _Pill(text: role, color: AppColors.primaryTint, textColor: AppColors.primaryDark),
                          if (reraVerified)
                            const _Pill(text: 'RERA verified', color: AppColors.accentGoldTint, textColor: AppColors.accentGold, icon: Icons.verified),
                          if (orgName.isNotEmpty)
                            GestureDetector(
                              onTap: orgSlug.isNotEmpty ? () => context.push('/org/$orgSlug') : null,
                              child: _Pill(text: orgName, color: AppColors.surface2, textColor: AppColors.textMuted, icon: Icons.business_outlined),
                            ),
                        ],
                      ),
                      if (company.isNotEmpty && company != orgName) ...[
                        const SizedBox(height: AppSpacing.x8),
                        Text(company, style: t.bodyMedium?.copyWith(color: AppColors.textMuted)),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.x20),
                _MessageCta(profileId: id),

                // stats strip
                _StatsStrip(items: [
                  ('Listings', '$listingCount'),
                  ('Areas', '${areas.length}'),
                  ('Languages', '${languages.length}'),
                  if (avg != null) ('Rating', avg.toStringAsFixed(1)),
                ]),
                const SizedBox(height: AppSpacing.x20),

                // contact
                if (phone.isNotEmpty || whatsapp.isNotEmpty) ...[
                  Row(children: [
                    if (phone.isNotEmpty)
                      Expanded(child: _ContactButton(icon: Icons.call_outlined, label: 'Call', value: phone)),
                    if (phone.isNotEmpty && whatsapp.isNotEmpty) const SizedBox(width: AppSpacing.x12),
                    if (whatsapp.isNotEmpty)
                      Expanded(child: _ContactButton(icon: Icons.chat_outlined, label: 'WhatsApp', value: whatsapp)),
                  ]),
                  const SizedBox(height: AppSpacing.x20),
                ],

                // about / bio
                if (bio.isNotEmpty) ...[
                  Text('About', style: t.titleMedium),
                  const SizedBox(height: AppSpacing.x8),
                  Text(bio, style: t.bodyMedium),
                  const SizedBox(height: AppSpacing.x20),
                ],

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
                      : LayoutBuilder(builder: (ctx, c) {
                          final cols = c.maxWidth >= 560 ? 2 : 1;
                          final cardW = cols == 1 ? c.maxWidth : (c.maxWidth - AppSpacing.x12) / 2;
                          return Wrap(
                            spacing: AppSpacing.x12,
                            runSpacing: AppSpacing.x12,
                            children: list
                                .map((e) => SizedBox(width: cardW, child: _PublicListingCard(Map<String, dynamic>.from(e))))
                                .toList(),
                          );
                        }),
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

/// "Message" call-to-action. Hidden when signed-out or viewing your own profile.
class _MessageCta extends ConsumerWidget {
  const _MessageCta({required this.profileId});
  final String profileId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final myId = ref.watch(authControllerProvider).user?.id;
    if (myId == null || myId == profileId) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.x20),
      child: SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: () async {
            try {
              final convId = await ref.read(messagingRepositoryProvider).startDirect(profileId);
              if (convId.isNotEmpty && context.mounted) context.push('/messages/$convId');
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
              }
            }
          },
          icon: const Icon(Icons.chat_bubble_outline),
          label: const Text('Message'),
        ),
      ),
    );
  }
}

class _StatsStrip extends StatelessWidget {
  const _StatsStrip({required this.items});
  final List<(String, String)> items;
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.x16),
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(AppSpacing.rCard),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: items
            .map((it) => Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(it.$2, style: t.titleLarge?.copyWith(fontWeight: FontWeight.w700, color: AppColors.primary)),
                  const SizedBox(height: 2),
                  Text(it.$1, style: t.bodySmall?.copyWith(color: AppColors.textMuted)),
                ]))
            .toList(),
      ),
    );
  }
}

class _ContactButton extends StatelessWidget {
  const _ContactButton({required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: () {
        Clipboard.setData(ClipboardData(text: value));
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$label copied — $value')));
      },
      icon: Icon(icon, size: 18),
      label: Text(label),
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
                Row(children: [
                  Expanded(
                    child: Text(money,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: t.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                  ),
                  if ('${l['ownership_status']}' == 'verified')
                    const Tooltip(
                      message: 'Ownership verified',
                      child: Icon(Icons.verified_user, size: 16, color: AppColors.accentGold),
                    ),
                ]),
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
