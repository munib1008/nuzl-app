import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/network/api_client.dart';
import '../../core/rbac/persona.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/responsive.dart';
import '../../core/widgets/status_badge.dart';
import '../shell/app_shell.dart';

/// Nuzler queue of pending role requests (agent → RERA, developer/provider/
/// supplier → trade license).
final roleRequestsProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  final d = await ref.read(apiClientProvider).get('/admin/role-requests', query: {'status': 'pending'});
  return d is List ? d : [];
});

class RoleRequestsScreen extends ConsumerWidget {
  const RoleRequestsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final reqs = ref.watch(roleRequestsProvider);
    return Scaffold(
      appBar: const NuzlAppBar(title: 'Role requests'),
      drawer: const NuzlDrawer(),
      body: ResponsiveCenter(
        child: RefreshIndicator(
          onRefresh: () async => ref.refresh(roleRequestsProvider.future),
          child: reqs.when(
            loading: () => const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator())),
            error: (e, _) => ListView(children: [Padding(padding: const EdgeInsets.all(24), child: Text(friendlyError(e)))]),
            data: (list) => list.isEmpty
                ? ListView(children: [
                    const SizedBox(height: 80),
                    Icon(Icons.verified_user_outlined, size: 48, color: dark ? AppColors.dTextSubtle : AppColors.textSubtle),
                    const SizedBox(height: 12),
                    const Center(child: Text('No pending role requests', style: TextStyle(fontWeight: FontWeight.w700))),
                    const SizedBox(height: 4),
                    Center(child: Text('Agent / developer / supplier requests appear here for review.',
                        style: TextStyle(color: dark ? AppColors.dTextMuted : AppColors.textMuted))),
                  ])
                : ListView.separated(
                    padding: const EdgeInsets.all(AppSpacing.x16),
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.x12),
                    itemBuilder: (_, i) => _RoleCard(Map<String, dynamic>.from(list[i])),
                  ),
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends ConsumerWidget {
  const _RoleCard(this.r);
  final Map<String, dynamic> r;

  Future<void> _decide(BuildContext context, WidgetRef ref, bool approve) async {
    try {
      await ref.read(apiClientProvider).post('/admin/role-requests/decide',
          body: {'user_id': r['user_id'], 'role': r['role'], 'approve': approve});
      ref.invalidate(roleRequestsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(approve ? 'Role approved ✓' : 'Role request declined')));
      }
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final role = '${r['role'] ?? ''}';
    final when = DateTime.tryParse('${r['created_at'] ?? ''}');
    final rera = '${r['rera_brn'] ?? ''}'.trim();
    final license = '${r['trade_license'] ?? ''}'.trim();
    final verifStatus = '${r['verification_status'] ?? ''}'.trim();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.x16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text('${r['full_name'] ?? 'User'}',
                style: t.titleSmall?.copyWith(fontWeight: FontWeight.w700))),
            StatusBadge(personaFromRole(role).label, tone: BadgeTone.gold),
          ]),
          if ('${r['email'] ?? ''}'.isNotEmpty)
            Text('${r['email']}', style: t.bodySmall?.copyWith(color: dark ? AppColors.dTextMuted : AppColors.textMuted)),
          const SizedBox(height: AppSpacing.x8),
          // Supporting verification evidence for the reviewer.
          Wrap(spacing: AppSpacing.x8, runSpacing: 6, children: [
            if (rera.isNotEmpty) _evi(Icons.badge_outlined, 'RERA $rera'),
            if ('${r['org_name'] ?? ''}'.isNotEmpty) _evi(Icons.business_outlined, '${r['org_name']}'),
            if (license.isNotEmpty) _evi(Icons.description_outlined, 'License $license'),
            if (verifStatus.isNotEmpty) _evi(Icons.verified_outlined, 'Company $verifStatus'),
            if (when != null) _evi(Icons.schedule, DateFormat('d MMM').format(when.toLocal())),
          ]),
          if (rera.isEmpty && license.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.x8),
              child: Text('No RERA / trade-license on file — verify externally before approving.',
                  style: t.bodySmall?.copyWith(color: AppColors.warning)),
            ),
          const SizedBox(height: AppSpacing.x12),
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            OutlinedButton.icon(
              onPressed: () => _decide(context, ref, false),
              style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger),
              icon: const Icon(Icons.close, size: 18),
              label: const Text('Reject'),
            ),
            const SizedBox(width: AppSpacing.x8),
            FilledButton.icon(
              onPressed: () => _decide(context, ref, true),
              icon: const Icon(Icons.verified, size: 18),
              label: const Text('Approve'),
            ),
          ]),
        ]),
      ),
    );
  }

  Widget _evi(IconData icon, String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(AppSpacing.rFull)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 13, color: AppColors.textMuted),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textMuted, fontWeight: FontWeight.w500)),
        ]),
      );
}
