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

final _orgProvider = FutureProvider.autoDispose.family<Map<String, dynamic>, String>((ref, slug) async {
  final d = await ref.read(apiClientProvider).get('/public/orgs/$slug');
  return d is Map ? Map<String, dynamic>.from(d) : <String, dynamic>{};
});

/// Read-only, shareable agency landing page (cover + logo + about + team + listings).
class PublicOrgScreen extends ConsumerWidget {
  const PublicOrgScreen({super.key, required this.slug});
  final String slug;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final org = ref.watch(_orgProvider(slug));
    return Scaffold(
      appBar: AppBar(
        title: const NuzlLogo(size: 26),
        leading: Navigator.of(context).canPop()
            ? IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.pop())
            : null,
      ),
      body: org.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.x24),
            child: Text('This organization is not available.', style: Theme.of(context).textTheme.bodyMedium),
          ),
        ),
        data: (m) => m.isEmpty
            ? const Center(child: Text('Not found'))
            : _Body(org: m),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.org});
  final Map<String, dynamic> org;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final name = '${org['name'] ?? 'Agency'}';
    final tagline = '${org['tagline'] ?? ''}'.trim();
    final about = '${org['about'] ?? ''}'.trim();
    final cover = '${org['cover_image_url'] ?? ''}'.trim();
    final logo = '${org['logo_url'] ?? ''}'.trim();
    final website = '${org['website'] ?? ''}'.trim();
    final phone = '${org['phone'] ?? ''}'.trim();
    final email = '${org['email'] ?? ''}'.trim();
    final verified = org['is_verified'] == true;
    final agents = (org['agents'] is List) ? org['agents'] as List : const [];
    final listings = (org['listings'] is List) ? org['listings'] as List : const [];
    final services = (org['services'] is List) ? org['services'] as List : const [];
    final products = (org['products'] is List) ? org['products'] as List : const [];
    final projects = (org['projects'] is List) ? org['projects'] as List : const [];
    final reviews = (org['reviews'] is List) ? org['reviews'] as List : const [];
    final rating = num.tryParse('${org['rating'] ?? ''}');
    final reviewCount = int.tryParse('${org['review_count'] ?? 0}') ?? 0;
    final location = [
      '${org['city'] ?? ''}'.trim(),
      '${org['country'] ?? ''}'.trim(),
    ].where((s) => s.isNotEmpty).join(', ');

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        // cover banner
        AspectRatio(
          aspectRatio: 3.4,
          child: cover.isNotEmpty
              ? Image.network(cover, fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const _CoverFallback())
              : const _CoverFallback(),
        ),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 880),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.x16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // header: logo + name/tagline/verified
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Container(
                      width: 64, height: 64,
                      decoration: BoxDecoration(
                        color: AppColors.surface2,
                        borderRadius: BorderRadius.circular(AppSpacing.rCard),
                        image: logo.isNotEmpty ? DecorationImage(image: NetworkImage(logo), fit: BoxFit.cover) : null,
                      ),
                      child: logo.isEmpty
                          ? Center(child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                              style: t.headlineSmall?.copyWith(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w700)))
                          : null,
                    ),
                    const SizedBox(width: AppSpacing.x12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Flexible(child: Text(name, style: t.headlineSmall)),
                          if (verified) ...[
                            const SizedBox(width: AppSpacing.x8),
                            const Icon(Icons.verified, size: 18, color: AppColors.accentGold),
                          ],
                        ]),
                        if (tagline.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(tagline, style: t.bodyMedium?.copyWith(color: dark ? AppColors.dTextMuted : AppColors.textMuted)),
                        ],
                        if (rating != null && reviewCount > 0) ...[
                          const SizedBox(height: 4),
                          Row(children: [
                            for (var i = 1; i <= 5; i++)
                              Icon(i <= rating.round() ? Icons.star : Icons.star_border, size: 14, color: AppColors.accentGold),
                            const SizedBox(width: 6),
                            Text('${rating.toStringAsFixed(1)} ($reviewCount ${reviewCount == 1 ? 'review' : 'reviews'})',
                                style: t.bodySmall?.copyWith(color: dark ? AppColors.dTextMuted : AppColors.textMuted)),
                          ]),
                        ],
                      ]),
                    ),
                  ]),
                  const SizedBox(height: AppSpacing.x16),
                  if (org['id'] != null) ...[
                    FollowButton(targetId: '${org['id']}', isOrg: true),
                    const SizedBox(height: AppSpacing.x16),
                  ],

                  // contact / links
                  if (website.isNotEmpty || phone.isNotEmpty || email.isNotEmpty || location.isNotEmpty)
                    Wrap(spacing: AppSpacing.x8, runSpacing: AppSpacing.x8, children: [
                      if (location.isNotEmpty) _LinkChip(icon: Icons.place_outlined, label: location, value: location),
                      if (website.isNotEmpty) _LinkChip(icon: Icons.language, label: 'Website', value: website),
                      if (phone.isNotEmpty) _LinkChip(icon: Icons.call_outlined, label: 'Call', value: phone),
                      if (email.isNotEmpty) _LinkChip(icon: Icons.mail_outline, label: 'Email', value: email),
                    ]),

                  // about
                  if (about.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.x24),
                    Text('About the company', style: t.titleMedium),
                    const SizedBox(height: AppSpacing.x8),
                    Text(about, style: t.bodyMedium),
                  ],

                  // listings
                  if (listings.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.x24),
                    Text('Listings', style: t.titleMedium),
                    const SizedBox(height: AppSpacing.x8),
                    LayoutBuilder(builder: (ctx, c) {
                      final cols = c.maxWidth >= 720 ? 3 : (c.maxWidth >= 480 ? 2 : 1);
                      final cardW = cols == 1 ? c.maxWidth : (c.maxWidth - (cols - 1) * AppSpacing.x12) / cols;
                      return Wrap(
                        spacing: AppSpacing.x12,
                        runSpacing: AppSpacing.x12,
                        children: listings
                            .map((e) => SizedBox(width: cardW, child: _OrgListingCard(Map<String, dynamic>.from(e))))
                            .toList(),
                      );
                    }),
                  ],

                  // services
                  if (services.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.x24),
                    Text('Services', style: t.titleMedium),
                    const SizedBox(height: AppSpacing.x8),
                    _offeringsGrid(services),
                  ],

                  // products
                  if (products.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.x24),
                    Text('Products', style: t.titleMedium),
                    const SizedBox(height: AppSpacing.x8),
                    _offeringsGrid(products),
                  ],

                  // projects (developers)
                  if (projects.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.x24),
                    Row(children: [
                      Expanded(child: Text('Projects', style: t.titleMedium)),
                      if ('${org['org_type'] ?? ''}' == 'developer')
                        _PartnerRequestButton(developerOrg: '${org['id'] ?? ''}', developerName: name),
                    ]),
                    const SizedBox(height: AppSpacing.x8),
                    Column(children: projects.map((e) => _ProjectTile(Map<String, dynamic>.from(e))).toList()),
                  ],

                  // team
                  if (agents.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.x24),
                    Text('Our team', style: t.titleMedium),
                    const SizedBox(height: AppSpacing.x8),
                    Wrap(
                      spacing: AppSpacing.x12,
                      runSpacing: AppSpacing.x12,
                      children: agents.map((e) => _AgentChip(Map<String, dynamic>.from(e))).toList(),
                    ),
                  ],

                  // reviews
                  if (reviews.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.x24),
                    Text('Reviews', style: t.titleMedium),
                    const SizedBox(height: AppSpacing.x8),
                    Column(children: reviews.map((e) => _ReviewTile(Map<String, dynamic>.from(e))).toList()),
                  ],
                  const SizedBox(height: AppSpacing.x32),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _CoverFallback extends StatelessWidget {
  const _CoverFallback();
  @override
  Widget build(BuildContext context) => const DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [AppColors.primary, AppColors.secondary]),
        ),
      );
}

class _LinkChip extends StatelessWidget {
  const _LinkChip({required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: Icon(icon, size: 16, color: Theme.of(context).colorScheme.primary),
      label: Text(label),
      onPressed: () {
        Clipboard.setData(ClipboardData(text: value));
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$label copied — $value')));
      },
    );
  }
}

class _AgentChip extends StatelessWidget {
  const _AgentChip(this.a);
  final Map<String, dynamic> a;
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final id = '${a['id']}';
    final name = '${a['full_name'] ?? 'Agent'}';
    final role = personaFromRole('${a['role'] ?? ''}').label;
    final avatar = '${a['avatar_url'] ?? ''}'.trim();
    return InkWell(
      borderRadius: BorderRadius.circular(AppSpacing.rCard),
      onTap: () => context.push('/u/$id'),
      child: Container(
        width: 220,
        padding: const EdgeInsets.all(AppSpacing.x12),
        decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).dividerColor),
          borderRadius: BorderRadius.circular(AppSpacing.rCard),
        ),
        child: Row(children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: AppColors.primaryTint,
            backgroundImage: avatar.isNotEmpty ? NetworkImage(avatar) : null,
            child: avatar.isEmpty
                ? Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: t.titleSmall?.copyWith(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w700))
                : null,
          ),
          const SizedBox(width: AppSpacing.x8),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name, style: t.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
              Text(role, style: t.bodySmall?.copyWith(color: dark ? AppColors.dTextMuted : AppColors.textMuted)),
            ]),
          ),
        ]),
      ),
    );
  }
}

/// Responsive grid of service/product offering cards.
Widget _offeringsGrid(List items) => LayoutBuilder(builder: (ctx, c) {
      final cols = c.maxWidth >= 720 ? 3 : (c.maxWidth >= 480 ? 2 : 1);
      final w = cols == 1 ? c.maxWidth : (c.maxWidth - (cols - 1) * AppSpacing.x12) / cols;
      return Wrap(
        spacing: AppSpacing.x12,
        runSpacing: AppSpacing.x12,
        children: items.map((e) => SizedBox(width: w, child: _OfferingCard(Map<String, dynamic>.from(e)))).toList(),
      );
    });

class _OfferingCard extends StatelessWidget {
  const _OfferingCard(this.m);
  final Map<String, dynamic> m;
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final price = num.tryParse('${m['price']}');
    final money = price != null && price > 0 ? NumberFormat.currency(symbol: 'AED ', decimalDigits: 0).format(price) : '';
    final unit = '${m['price_unit'] ?? ''}'.trim();
    final img = '${m['image_url'] ?? ''}'.trim();
    final isProduct = '${m['kind']}' == 'product';
    final fallback = Container(
      color: AppColors.surface2,
      child: Center(child: Icon(isProduct ? Icons.inventory_2_outlined : Icons.handyman_outlined, size: 32, color: AppColors.textSubtle)),
    );
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        AspectRatio(
          aspectRatio: 16 / 10,
          child: img.isEmpty ? fallback : Image.network(img, fit: BoxFit.cover, errorBuilder: (_, __, ___) => fallback),
        ),
        Padding(
          padding: const EdgeInsets.all(AppSpacing.x12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${m['title'] ?? ''}', style: t.titleSmall?.copyWith(fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
            if ('${m['category'] ?? ''}'.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text('${m['category']}${'${m['subcategory'] ?? ''}'.isNotEmpty ? ' · ${m['subcategory']}' : ''}',
                  style: t.bodySmall?.copyWith(color: dark ? AppColors.dTextMuted : AppColors.textMuted), maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
            if (money.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text('$money${unit.isNotEmpty ? ' · $unit' : ''}', style: t.titleSmall?.copyWith(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w700)),
            ],
          ]),
        ),
      ]),
    );
  }
}

/// Shown to agent/brokerage personas on a developer's page — request to sell
/// the developer's projects. The developer approves from their Partners screen.
class _PartnerRequestButton extends ConsumerWidget {
  const _PartnerRequestButton({required this.developerOrg, required this.developerName});
  final String developerOrg;
  final String developerName;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final persona = ref.watch(personaProvider);
    final canPartner = persona == Persona.broker || persona == Persona.agent || persona == Persona.salesperson;
    if (!canPartner || developerOrg.isEmpty) return const SizedBox.shrink();
    return OutlinedButton.icon(
      onPressed: () async {
        try {
          await ref.read(apiClientProvider).post('/developer/partners/request', body: {'developer_org': developerOrg});
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Request sent to $developerName — they\'ll review your partnership.')));
          }
        } catch (e) {
          if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
        }
      },
      icon: const Icon(Icons.handshake_outlined, size: 16),
      label: const Text('Request to partner'),
      style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
    );
  }
}

class _ProjectTile extends StatelessWidget {
  const _ProjectTile(this.p);
  final Map<String, dynamic> p;
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final units = int.tryParse('${p['unit_count'] ?? 0}') ?? 0;
    final handover = '${p['handover_date'] ?? ''}'.split('T').first;
    final meta = [
      if ('${p['community'] ?? ''}'.isNotEmpty) '${p['community']}',
      '${p['status'] ?? ''}'.replaceAll('_', ' '),
      if (units > 0) '$units ${units == 1 ? 'unit' : 'units'}',
      if (handover.isNotEmpty) 'Handover $handover',
    ].where((s) => s.trim().isNotEmpty).join(' · ');
    final id = '${p['id'] ?? ''}'.trim();
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: id.isEmpty ? null : () => context.push('/projects/$id'),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.x12),
          child: Row(children: [
            Icon(Icons.domain_outlined, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: AppSpacing.x12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${p['name'] ?? 'Project'}', style: t.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                if (meta.isNotEmpty) Text(meta, style: t.bodySmall?.copyWith(color: dark ? AppColors.dTextMuted : AppColors.textMuted)),
              ]),
            ),
            if (id.isNotEmpty) Icon(Icons.chevron_right, color: Theme.of(context).hintColor),
          ]),
        ),
      ),
    );
  }
}

class _ReviewTile extends StatelessWidget {
  const _ReviewTile(this.r);
  final Map<String, dynamic> r;
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final rating = int.tryParse('${r['rating'] ?? 0}') ?? 0;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.x12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            for (var i = 1; i <= 5; i++)
              Icon(i <= rating ? Icons.star : Icons.star_border, size: 14, color: AppColors.accentGold),
            const SizedBox(width: 6),
            Expanded(child: Text('${r['customer_name'] ?? 'Customer'}',
                style: t.bodySmall?.copyWith(fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis)),
          ]),
          if ('${r['review'] ?? ''}'.trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text('${r['review']}', style: t.bodySmall),
          ],
          if ('${r['item_title'] ?? ''}'.trim().isNotEmpty) ...[
            const SizedBox(height: 2),
            Text('${r['item_title']}', style: t.labelSmall?.copyWith(color: dark ? AppColors.dTextMuted : AppColors.textMuted)),
          ],
        ]),
      ),
    );
  }
}

class _OrgListingCard extends StatelessWidget {
  const _OrgListingCard(this.l);
  final Map<String, dynamic> l;
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: cover.isEmpty
                ? Container(color: AppColors.surface2,
                    child: const Center(child: Icon(Icons.apartment_outlined, size: 36, color: AppColors.textSubtle)))
                : Image.network(cover, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(color: AppColors.surface2,
                        child: const Center(child: Icon(Icons.apartment_outlined, size: 36, color: AppColors.textSubtle)))),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.x12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(money, style: t.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(facts, style: t.bodySmall?.copyWith(color: dark ? AppColors.dTextMuted : AppColors.textMuted), maxLines: 1, overflow: TextOverflow.ellipsis),
            ]),
          ),
        ],
      ),
    );
  }
}
