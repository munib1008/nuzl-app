import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/auth_prompt.dart';
import '../../../core/widgets/nuzl_logo.dart';
import '../../auth/application/auth_controller.dart';

/// Public (unauthenticated) property detail. Visitors can explore freely;
/// in-platform actions (save / request a viewing) prompt sign-up. The agent's
/// phone + WhatsApp are shown openly (product decision) so a visitor can reach
/// out without an account.
final _publicListingProvider =
    FutureProvider.autoDispose.family<Map<String, dynamic>?, String>((ref, id) async {
  try {
    final d = await ref.read(apiClientProvider).get('/public/listings/$id');
    return d is Map ? Map<String, dynamic>.from(d) : null;
  } catch (_) {
    return null;
  }
});

double _estMonthly(num price) {
  final loan = price * 0.75;
  const r = 0.045 / 12;
  const n = 300;
  if (loan <= 0) return 0;
  final f = math.pow(1 + r, n).toDouble();
  return loan * r * f / (f - 1);
}

String _cap(String s) => s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

class PublicListingScreen extends ConsumerWidget {
  const PublicListingScreen({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_publicListingProvider(id));
    return Scaffold(
      appBar: AppBar(
        titleSpacing: AppSpacing.x16,
        title: InkWell(onTap: () => context.go('/'), child: const NuzlLogo(size: 26)),
        actions: [
          TextButton(onPressed: () => context.go('/login'), child: const Text('Sign in')),
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.x12, left: AppSpacing.x8),
            child: FilledButton(onPressed: () => context.go('/register'), child: const Text('Sign up')),
          ),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => _notFound(context),
        data: (m) => (m == null) ? _notFound(context) : _Body(m: m, id: id),
      ),
    );
  }

  Widget _notFound(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.x24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.search_off, size: 44, color: AppColors.textMuted),
            const SizedBox(height: AppSpacing.x12),
            const Text('This listing is no longer available.'),
            const SizedBox(height: AppSpacing.x16),
            FilledButton(onPressed: () => context.go('/'), child: const Text('Back to NUZL')),
          ]),
        ),
      );
}

class _Body extends ConsumerWidget {
  const _Body({required this.m, required this.id});
  final Map<String, dynamic> m;
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final aed = NumberFormat.currency(symbol: 'AED ', decimalDigits: 0);
    final wide = MediaQuery.of(context).size.width >= 900;
    final price = num.tryParse('${m['price']}') ?? 0;
    final isRent = '${m['purpose']}' == 'rent';

    final images = <String>[];
    final raw = m['images'];
    if (raw is List) {
      for (final e in raw) {
        final s = '$e'.trim();
        if (s.isNotEmpty) images.add(s);
      }
    }
    final cover = '${m['cover_image'] ?? ''}'.trim();
    if (cover.isNotEmpty && !images.contains(cover)) images.insert(0, cover);

    final building = '${m['building_name'] ?? ''}'.trim();
    final unit = '${m['unit_no'] ?? ''}'.trim();
    final community = '${m['community'] ?? ''}'.trim();
    final ptype = '${m['property_type'] ?? ''}'.trim();
    final title = building.isNotEmpty
        ? (unit.isNotEmpty ? '$building · Unit $unit' : building)
        : (ptype.isNotEmpty ? _cap(ptype) : 'Property');
    final desc = '${m['description'] ?? ''}'.trim();
    final verified = '${m['ownership_status']}' == 'verified';
    final refCode = '${m['ref_code'] ?? ''}'.trim();
    final est = _estMonthly(price);

    final highlights = <String>[
      if ('${m['status'] ?? ''}'.trim().isNotEmpty) _cap('${m['status']}'),
      if ('${m['furnishing'] ?? ''}'.trim().isNotEmpty) _cap('${m['furnishing']}'.replaceAll('_', ' ')),
      if ('${m['view'] ?? ''}'.trim().isNotEmpty) '${m['view']}',
    ];

    final details = <(String, String)>[
      if ('${m['developer'] ?? ''}'.trim().isNotEmpty) ('Developer', '${m['developer']}'),
      if ('${m['handover_date'] ?? ''}'.trim().isNotEmpty) ('Handover', '${m['handover_date']}'.split('T').first),
      if (m['parking'] != null && '${m['parking']}'.trim().isNotEmpty) ('Parking', '${m['parking']}'),
      if (m['service_charge'] != null && (num.tryParse('${m['service_charge']}') ?? 0) > 0)
        ('Service charge', aed.format(num.tryParse('${m['service_charge']}') ?? 0)),
    ];

    final info = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Wrap(spacing: 8, runSpacing: 8, children: [
        _pill(context, isRent ? 'For rent' : 'For sale', AppColors.primary),
        if (verified) _pill(context, 'Verified', AppColors.success, icon: Icons.verified),
      ]),
      const SizedBox(height: AppSpacing.x12),
      Text(title, style: t.headlineSmall),
      if (community.isNotEmpty) ...[
        const SizedBox(height: 2),
        Row(children: [
          const Icon(Icons.place_outlined, size: 16, color: AppColors.textMuted),
          const SizedBox(width: 4),
          Text(community, style: t.bodyMedium?.copyWith(color: AppColors.textMuted)),
        ]),
      ],
      if (refCode.isNotEmpty) ...[
        const SizedBox(height: 4),
        Text('Ref $refCode', style: t.bodySmall?.copyWith(color: AppColors.textSubtle, fontWeight: FontWeight.w600)),
      ],
      const SizedBox(height: AppSpacing.x12),
      Text('${aed.format(price)}${isRent ? ' / yr' : ''}',
          style: t.displaySmall?.copyWith(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w800)),
      if (!isRent && est > 0)
        Text('~${aed.format(est)}/mo estimated mortgage',
            style: t.bodySmall?.copyWith(color: AppColors.textMuted)),
      const SizedBox(height: AppSpacing.x16),
      Wrap(spacing: AppSpacing.x24, runSpacing: AppSpacing.x12, children: [
        _fact(context, Icons.bed_outlined, '${m['bedrooms'] ?? '-'}', 'Bedrooms'),
        _fact(context, Icons.bathtub_outlined, '${m['bathrooms'] ?? '-'}', 'Bathrooms'),
        _fact(context, Icons.straighten, '${m['size_sqft'] ?? '-'}', 'Sq ft'),
        if (ptype.isNotEmpty) _fact(context, Icons.home_work_outlined, _cap(ptype), 'Type'),
      ]),
      if (highlights.isNotEmpty) ...[
        const SizedBox(height: AppSpacing.x16),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final h in highlights)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(AppSpacing.rFull)),
              child: Text(h, style: t.labelMedium?.copyWith(color: AppColors.success, fontWeight: FontWeight.w600)),
            ),
        ]),
      ],
      if (desc.isNotEmpty) ...[
        const SizedBox(height: AppSpacing.x24),
        Text('About this property', style: t.titleMedium),
        const SizedBox(height: AppSpacing.x8),
        Text(desc, style: t.bodyMedium?.copyWith(height: 1.5)),
      ],
      ...(() {
        final raw = m['amenities'];
        final items = raw is List
            ? raw
                .map((e) => '${(e is Map ? e : const {})['label'] ?? (e is Map ? e : const {})['code'] ?? ''}')
                .where((s) => s.isNotEmpty)
                .toList()
            : <String>[];
        if (items.isEmpty) return <Widget>[];
        return [
          const SizedBox(height: AppSpacing.x24),
          Text('Amenities', style: t.titleMedium),
          const SizedBox(height: AppSpacing.x8),
          Wrap(spacing: AppSpacing.x8, runSpacing: AppSpacing.x8, children: [
            for (final a in items) Chip(label: Text(a), visualDensity: VisualDensity.compact),
          ]),
        ];
      })(),
      if (details.isNotEmpty) ...[
        const SizedBox(height: AppSpacing.x24),
        Text('Details', style: t.titleMedium),
        const SizedBox(height: AppSpacing.x8),
        for (final d in details)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(children: [
              Expanded(child: Text(d.$1, style: t.bodyMedium?.copyWith(color: AppColors.textMuted))),
              Text(d.$2, style: t.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
            ]),
          ),
      ],
    ]);

    final agent = _AgentCard(m: m, id: id);

    return ListView(
      children: [
        _Gallery(images: images, height: wide ? 420 : 240),
        const SizedBox(height: AppSpacing.x20),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1040),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.x20, 0, AppSpacing.x20, AppSpacing.x32),
              child: wide
                  ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Expanded(flex: 2, child: info),
                      const SizedBox(width: AppSpacing.x24),
                      SizedBox(width: 320, child: agent),
                    ])
                  : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      info,
                      const SizedBox(height: AppSpacing.x24),
                      agent,
                    ]),
            ),
          ),
        ),
      ],
    );
  }

  Widget _pill(BuildContext context, String text, Color c, {IconData? icon}) {
    final t = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: c.withValues(alpha: 0.92), borderRadius: BorderRadius.circular(AppSpacing.rFull)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[Icon(icon, size: 13, color: Colors.white), const SizedBox(width: 3)],
        Text(text, style: t.labelMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
      ]),
    );
  }

  Widget _fact(BuildContext context, IconData icon, String value, String label) {
    final t = Theme.of(context).textTheme;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 20, color: AppColors.primary),
      const SizedBox(width: 8),
      Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Text(value, style: t.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
        Text(label, style: t.bodySmall?.copyWith(color: AppColors.textMuted)),
      ]),
    ]);
  }
}

/// Agent card with openly-shown contact (copy-to-clipboard, matching the public
/// profile page) + the sign-up-gated in-platform actions.
class _AgentCard extends ConsumerWidget {
  const _AgentCard({required this.m, required this.id});
  final Map<String, dynamic> m;
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final name = '${m['agent_name'] ?? ''}'.trim();
    final phone = '${m['agent_phone'] ?? ''}'.trim();
    final whatsapp = '${m['agent_whatsapp'] ?? ''}'.trim();
    final score = num.tryParse('${m['agent_score'] ?? ''}');
    final authed = ref.watch(authControllerProvider).isAuthenticated;

    void gated(String action) {
      if (authed) {
        context.go('/listings/$id'); // full in-platform flow
      } else {
        showAuthPrompt(context, action: action);
      }
    }

    return Container(
      padding: const EdgeInsets.all(AppSpacing.x16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(AppSpacing.rCard),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (name.isNotEmpty) ...[
          Row(children: [
            CircleAvatar(
              radius: 20, backgroundColor: AppColors.primaryTint,
              child: Text(name[0].toUpperCase(),
                  style: t.titleMedium?.copyWith(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w700)),
            ),
            const SizedBox(width: AppSpacing.x12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(name, style: t.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                if (score != null && score > 0 && score <= 5)
                  Row(children: [
                    const Icon(Icons.star, size: 14, color: AppColors.accentGold),
                    const SizedBox(width: 2),
                    Text('${score.toStringAsFixed(1)} rating', style: t.bodySmall?.copyWith(color: AppColors.textMuted)),
                  ]),
              ]),
            ),
          ]),
          const SizedBox(height: AppSpacing.x12),
        ],
        if (phone.isNotEmpty || whatsapp.isNotEmpty) ...[
          Row(children: [
            if (phone.isNotEmpty) Expanded(child: _ContactButton(icon: Icons.call_outlined, label: 'Call', value: phone)),
            if (phone.isNotEmpty && whatsapp.isNotEmpty) const SizedBox(width: AppSpacing.x8),
            if (whatsapp.isNotEmpty)
              Expanded(child: _ContactButton(icon: Icons.chat_outlined, label: 'WhatsApp', value: whatsapp)),
          ]),
          const SizedBox(height: AppSpacing.x12),
        ],
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () => gated('request a viewing'),
            icon: const Icon(Icons.event_available_outlined, size: 18),
            label: const Text('Request a viewing'),
          ),
        ),
        const SizedBox(height: AppSpacing.x8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => gated('save this property'),
            icon: const Icon(Icons.bookmark_outline, size: 18),
            label: const Text('Save property'),
          ),
        ),
        if (!authed) ...[
          const SizedBox(height: AppSpacing.x8),
          Text('Free account — save searches, track mortgages and manage your property.',
              style: t.bodySmall?.copyWith(color: AppColors.textMuted)),
        ],
      ]),
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

class _Gallery extends StatefulWidget {
  const _Gallery({required this.images, required this.height});
  final List<String> images;
  final double height;
  @override
  State<_Gallery> createState() => _GalleryState();
}

class _GalleryState extends State<_Gallery> {
  final _pc = PageController();
  int _i = 0;
  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget ph() => Container(
        color: AppColors.surface2,
        child: const Center(child: Icon(Icons.apartment_outlined, size: 48, color: AppColors.textMuted)));
    if (widget.images.isEmpty) return SizedBox(height: widget.height, child: ph());
    return SizedBox(
      height: widget.height,
      child: Stack(children: [
        PageView.builder(
          controller: _pc,
          itemCount: widget.images.length,
          onPageChanged: (i) => setState(() => _i = i),
          itemBuilder: (_, i) => Image.network(widget.images[i],
              fit: BoxFit.cover, width: double.infinity,
              errorBuilder: (_, __, ___) => ph()),
        ),
        if (widget.images.length > 1)
          Positioned(
            right: 12, bottom: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55), borderRadius: BorderRadius.circular(AppSpacing.rFull)),
              child: Text('${_i + 1} / ${widget.images.length}',
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
            ),
          ),
      ]),
    );
  }
}
