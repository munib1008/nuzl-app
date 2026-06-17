import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/app_dialog.dart';
import '../../core/widgets/async_view.dart';
import '../../core/widgets/responsive.dart';
import '../shell/app_shell.dart';

/// Pending ownership claims the user can act on (orgs they own) + their own submitted claims.
final orgClaimsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  try {
    final d = await ref.read(apiClientProvider).get('/organizations/mine/claims');
    return d is List ? d.map((e) => Map<String, dynamic>.from(e as Map)).toList() : <Map<String, dynamic>>[];
  } catch (_) {
    return <Map<String, dynamic>>[];
  }
});

class OrgOwnershipScreen extends ConsumerWidget {
  const OrgOwnershipScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final claims = ref.watch(orgClaimsProvider);
    return Scaffold(
      appBar: const NuzlAppBar(title: 'Organization ownership'),
      drawer: const NuzlDrawer(),
      body: ResponsiveCenter(
        child: RefreshIndicator(
          onRefresh: () async => ref.invalidate(orgClaimsProvider),
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.x16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.x16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Claim ownership', style: t.titleMedium),
                    const SizedBox(height: AppSpacing.x4),
                    Text('Request to become the owner of your organization. The current owner approves or declines.',
                        style: t.bodySmall?.copyWith(color: AppColors.textMuted)),
                    const SizedBox(height: AppSpacing.x12),
                    FilledButton.icon(
                      onPressed: () => _claim(context, ref),
                      icon: const Icon(Icons.workspace_premium_outlined, size: 18),
                      label: const Text('Claim ownership'),
                    ),
                  ]),
                ),
              ),
              const SizedBox(height: AppSpacing.x16),
              Text('Pending claims', style: t.titleMedium),
              const SizedBox(height: AppSpacing.x8),
              AsyncView<List<Map<String, dynamic>>>(
                value: claims,
                onRetry: () => ref.invalidate(orgClaimsProvider),
                data: (list) => list.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.symmetric(vertical: AppSpacing.x16),
                        child: Text('No pending claims.', style: t.bodyMedium?.copyWith(color: AppColors.textMuted)),
                      )
                    : Column(children: [for (final c in list) _ClaimTile(c)]),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _claim(BuildContext context, WidgetRef ref) async {
    final reason = TextEditingController();
    final ok = await AppDialog.show<bool>(
      context,
      title: 'Claim ownership',
      children: [
        TextField(
          controller: reason,
          maxLines: 3,
          decoration: const InputDecoration(labelText: 'Reason (optional)', hintText: 'Why should you own this org?'),
        ),
      ],
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Submit claim')),
      ],
    );
    if (ok != true) return;
    try {
      await ref.read(apiClientProvider).post('/organizations/mine/claim', body: {'reason': reason.text.trim()});
      ref.invalidate(orgClaimsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Claim submitted')));
      }
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }
}

class _ClaimTile extends ConsumerWidget {
  const _ClaimTile(this.c);
  final Map<String, dynamic> c;

  Future<void> _decide(BuildContext context, WidgetRef ref, bool approve) async {
    try {
      await ref.read(apiClientProvider).post('/organizations/claims/${c['id']}/decide', body: {'approve': approve});
      ref.invalidate(orgClaimsProvider);
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final iAmOwner = c['i_am_owner'] == true;
    final orgName = '${c['org_name'] ?? 'Organization'}';
    final claimant = '${c['claimant_name'] ?? 'A member'}';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.x12),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(iAmOwner ? '$claimant wants to own $orgName' : 'Your claim on $orgName',
                  style: t.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
              if ('${c['reason'] ?? ''}'.trim().isNotEmpty)
                Text('${c['reason']}', style: t.bodySmall?.copyWith(color: AppColors.textMuted)),
              if (!iAmOwner)
                Text('Awaiting the current owner’s decision.',
                    style: t.bodySmall?.copyWith(color: AppColors.textMuted)),
            ]),
          ),
          if (iAmOwner) ...[
            const SizedBox(width: AppSpacing.x8),
            TextButton(onPressed: () => _decide(context, ref, false), child: const Text('Decline')),
            FilledButton(onPressed: () => _decide(context, ref, true), child: const Text('Approve')),
          ],
        ]),
      ),
    );
  }
}
