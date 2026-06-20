import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/network/api_client.dart';
import '../../core/network/upload_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/responsive.dart';
import '../../core/widgets/verification_badge.dart';
import '../shell/app_shell.dart';
import 'org_ownership_screen.dart';

/// Company owner's hub — verification status, public page, and shortcuts to the
/// company's listings, orders, requests and members. (epic D)
class CompanyDashboardScreen extends ConsumerWidget {
  const CompanyDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final company = ref.watch(myCompanyProvider);
    final joinReqs = ref.watch(joinRequestsProvider);
    final pendingJoins = joinReqs.maybeWhen(
      data: (l) => l.where((j) => j['i_am_owner'] == true).length,
      orElse: () => 0,
    );
    return Scaffold(
      appBar: const NuzlAppBar(title: 'My Company'),
      drawer: const NuzlDrawer(),
      body: ResponsiveCenter(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(myCompanyProvider);
            ref.invalidate(joinRequestsProvider);
          },
          child: company.when(
            loading: () => const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator())),
            error: (e, _) => ListView(children: [Padding(padding: const EdgeInsets.all(24), child: Text(friendlyError(e)))]),
            data: (c) => c == null ? _noCompany(context, t) : _dashboard(context, ref, t, c, pendingJoins),
          ),
        ),
      ),
    );
  }

  Widget _noCompany(BuildContext context, TextTheme t) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return ListView(
        padding: const EdgeInsets.all(AppSpacing.x24),
        children: [
          const SizedBox(height: 60),
          Icon(Icons.business_outlined, size: 48, color: dark ? AppColors.dTextSubtle : AppColors.textSubtle),
          const SizedBox(height: 12),
          Center(child: Text('No company yet', style: t.titleMedium)),
          const SizedBox(height: 4),
          Center(child: Text('Create or join a company to manage listings and get verified.',
              textAlign: TextAlign.center, style: t.bodyMedium?.copyWith(color: dark ? AppColors.dTextMuted : AppColors.textMuted))),
          const SizedBox(height: AppSpacing.x16),
          Center(
            child: FilledButton.icon(
              onPressed: () => context.push('/org-ownership'),
              icon: const Icon(Icons.add_business_outlined, size: 18),
              label: const Text('Set up company'),
            ),
          ),
        ],
      );
  }

  /// Owner uploads/changes the company logo (drives invoice header, public page,
  /// marketplace cards). The backend enforces owner-only.
  Future<void> _uploadLogo(BuildContext context, WidgetRef ref) async {
    try {
      final picked = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 512, imageQuality: 85);
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      final url = await ref.read(uploadServiceProvider).upload(bytes, picked.name, 'image/jpeg');
      if (url == null || url.isEmpty) {
        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Logo upload failed — try again.')));
        return;
      }
      await ref.read(apiClientProvider).patch('/organizations/mine/logo', body: {'logo_url': url});
      ref.invalidate(myCompanyProvider);
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Company logo updated.')));
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
    }
  }

  Widget _dashboard(BuildContext context, WidgetRef ref, TextTheme t, Map<String, dynamic> c, int pendingJoins) {
    final name = '${c['name'] ?? 'Your company'}';
    final logo = '${c['logo_url'] ?? ''}'.trim();
    final slug = '${c['slug'] ?? ''}'.trim();
    final status = '${c['verification_status'] ?? 'pending'}';
    final verified = status == 'verified';
    final dark = Theme.of(context).brightness == Brightness.dark;
    return ListView(padding: const EdgeInsets.all(AppSpacing.x16), children: [
      Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.x16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              GestureDetector(
                onTap: () => _uploadLogo(context, ref),
                child: Stack(children: [
                  Container(
                    width: 56, height: 56,
                    decoration: BoxDecoration(
                      color: AppColors.surface2,
                      borderRadius: BorderRadius.circular(AppSpacing.rMd),
                      image: logo.isNotEmpty ? DecorationImage(image: NetworkImage(logo), fit: BoxFit.cover) : null,
                    ),
                    child: logo.isEmpty
                        ? Center(child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                            style: t.titleLarge?.copyWith(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w700)))
                        : null,
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                        border: Border.all(color: Theme.of(context).colorScheme.surface, width: 1.5),
                      ),
                      child: const Icon(Icons.photo_camera, size: 11, color: Colors.white),
                    ),
                  ),
                ]),
              ),
              const SizedBox(width: AppSpacing.x12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(name, style: t.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  VerificationBadge(status),
                ]),
              ),
            ]),
            if (c['i_am_owner'] == true) ...[
              const SizedBox(height: AppSpacing.x12),
              OutlinedButton.icon(
                onPressed: () => context.push('/company/edit'),
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('Edit public page'),
              ),
            ],
            if (!verified) ...[
              const SizedBox(height: AppSpacing.x12),
              Text('Get verified to publish listings publicly and appear in the marketplace.',
                  style: t.bodySmall?.copyWith(color: dark ? AppColors.dTextMuted : AppColors.textMuted)),
              const SizedBox(height: AppSpacing.x8),
              FilledButton.icon(
                onPressed: () => context.push('/org-ownership'),
                icon: const Icon(Icons.verified_user_outlined, size: 18),
                label: const Text('Manage verification'),
              ),
            ] else if (slug.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.x12),
              Wrap(spacing: AppSpacing.x8, runSpacing: AppSpacing.x8, children: [
                OutlinedButton.icon(
                  onPressed: () => context.push('/org/$slug'),
                  icon: const Icon(Icons.open_in_new, size: 18),
                  label: const Text('View public page'),
                ),
                OutlinedButton.icon(
                  onPressed: () => context.push('/sales-performance'),
                  icon: const Icon(Icons.leaderboard_outlined, size: 18),
                  label: const Text('Sales performance'),
                ),
              ]),
            ],
          ]),
        ),
      ),
      const SizedBox(height: AppSpacing.x16),
      Text('Manage', style: t.titleMedium),
      const SizedBox(height: AppSpacing.x8),
      LayoutBuilder(builder: (ctx, cons) {
        final cols = cons.maxWidth >= 720 ? 3 : (cons.maxWidth >= 460 ? 2 : 1);
        final w = cols == 1 ? cons.maxWidth : (cons.maxWidth - (cols - 1) * AppSpacing.x12) / cols;
        final tiles = <Widget>[
          _tile(context, w, Icons.storefront_outlined, 'Listings', 'Your services & products', AppColors.primaryBright, '/marketplace'),
          _tile(context, w, Icons.receipt_long_outlined, 'Orders', 'Bookings & sales', AppColors.success, '/orders'),
          _tile(context, w, Icons.assignment_outlined, 'Requests', 'Bid on open requests', AppColors.warning, '/tenders'),
          _tile(context, w, Icons.groups_outlined, 'Members', pendingJoins > 0 ? '$pendingJoins join request${pendingJoins == 1 ? '' : 's'}' : 'Team & join requests', AppColors.secondary, '/org-ownership'),
          _tile(context, w, Icons.handshake_outlined, 'Sales partners', 'Agencies selling your projects', AppColors.primary, '/partners'),
          _tile(context, w, Icons.verified_user_outlined, 'Verification', status[0].toUpperCase() + status.substring(1), AppColors.info, '/org-ownership'),
        ];
        return Wrap(spacing: AppSpacing.x12, runSpacing: AppSpacing.x12, children: tiles);
      }),
    ]);
  }

  Widget _tile(BuildContext context, double w, IconData icon, String title, String sub, Color color, String route) {
    final t = Theme.of(context).textTheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      width: w,
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(AppSpacing.rCard),
          onTap: () => context.push(route),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.x16),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(AppSpacing.rMd)),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: AppSpacing.x12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, style: t.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                  Text(sub, style: t.bodySmall?.copyWith(color: dark ? AppColors.dTextMuted : AppColors.textMuted), maxLines: 1, overflow: TextOverflow.ellipsis),
                ]),
              ),
              Icon(Icons.chevron_right, color: dark ? AppColors.dTextSubtle : AppColors.textSubtle),
            ]),
          ),
        ),
      ),
    );
  }
}
