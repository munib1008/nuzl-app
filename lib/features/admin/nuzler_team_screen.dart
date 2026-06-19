import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/responsive.dart';
import '../shell/app_shell.dart';

/// The 7 Nuzler (platform-staff) designations — slug → label.
const nuzlerDesignations = <String, String>{
  'admin': 'Admin',
  'operations': 'Operations',
  'verification': 'Verification',
  'property_mgmt': 'Property Management',
  'finance': 'Finance',
  'customer_success': 'Customer Success',
  'legal': 'Legal',
};

String designationLabel(String? slug) =>
    slug == null ? '' : (nuzlerDesignations[slug] ?? slug.replaceAll('_', ' '));

final nuzlerTeamProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  final d = await ref.read(apiClientProvider).get('/admin/team');
  return d is List ? d : [];
});

/// Admin-only view of the Nuzler team with editable designations (UAT #4b).
class NuzlerTeamScreen extends ConsumerWidget {
  const NuzlerTeamScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final team = ref.watch(nuzlerTeamProvider);
    return Scaffold(
      appBar: const NuzlAppBar(title: 'Nuzler team'),
      drawer: const NuzlDrawer(),
      body: ResponsiveCenter(
        child: RefreshIndicator(
          onRefresh: () async => ref.refresh(nuzlerTeamProvider.future),
          child: team.when(
            loading: () => const Center(
                child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator())),
            error: (e, _) => ListView(children: [Padding(padding: const EdgeInsets.all(24), child: Text(friendlyError(e)))]),
            data: (list) => list.isEmpty
                ? ListView(children: const [SizedBox(height: 80), _Empty()])
                : ListView.separated(
                    padding: const EdgeInsets.all(AppSpacing.x16),
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.x8),
                    itemBuilder: (_, i) => _MemberTile(m: Map<String, dynamic>.from(list[i])),
                  ),
          ),
        ),
      ),
    );
  }
}

class _MemberTile extends ConsumerWidget {
  const _MemberTile({required this.m});
  final Map<String, dynamic> m;

  Future<void> _set(BuildContext context, WidgetRef ref, String? slug) async {
    try {
      await ref.read(apiClientProvider)
          .patch('/admin/users/${m['id']}/designation', body: {'designation': slug});
      ref.invalidate(nuzlerTeamProvider);
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final name = '${m['full_name'] ?? m['email'] ?? 'Member'}';
    final email = '${m['email'] ?? ''}';
    final role = '${m['role'] ?? ''}';
    final raw = '${m['designation'] ?? ''}';
    final current = nuzlerDesignations.containsKey(raw) ? raw : null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.x12),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: AppColors.primaryTint,
              child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700)),
            ),
            const SizedBox(width: AppSpacing.x12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: t.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text('$email${role.isNotEmpty ? ' · $role' : ''}',
                      style: t.bodySmall?.copyWith(color: dark ? AppColors.dTextMuted : AppColors.textMuted),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.x8),
            SizedBox(
              width: 156,
              child: DropdownButtonFormField<String?>(
                initialValue: current,
                isExpanded: true,
                decoration: const InputDecoration(
                  isDense: true,
                  labelText: 'Designation',
                  contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                ),
                items: [
                  const DropdownMenuItem<String?>(value: null, child: Text('—')),
                  ...nuzlerDesignations.entries.map((e) =>
                      DropdownMenuItem<String?>(value: e.key, child: Text(e.value, overflow: TextOverflow.ellipsis))),
                ],
                onChanged: (v) => _set(context, ref, v),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.x32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.badge_outlined, size: 56, color: dark ? AppColors.dTextSubtle : AppColors.textSubtle),
            const SizedBox(height: AppSpacing.x16),
            Text('No Nuzlers yet', style: t.titleMedium),
            const SizedBox(height: AppSpacing.x8),
            Text('Platform staff (@nuzl.ae) appear here for designation assignment.',
                textAlign: TextAlign.center, style: t.bodyMedium?.copyWith(color: dark ? AppColors.dTextMuted : AppColors.textMuted)),
          ],
        ),
      ),
    );
  }
}
