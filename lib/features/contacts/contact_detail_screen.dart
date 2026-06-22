import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/async_view.dart';
import '../../core/widgets/status_badge.dart';
import '../../core/widgets/user_avatar.dart';
import '../shell/app_shell.dart';
import 'contacts_repository.dart';

final contactDetailProvider =
    FutureProvider.autoDispose.family<Map<String, dynamic>, String>((ref, id) async {
  final d = await ref.read(apiClientProvider).get('/contacts/$id');
  return d is Map ? Map<String, dynamic>.from(d) : <String, dynamic>{};
});

BadgeTone _lifeTone(String l) => switch (l) {
      'customer' || 'owner' || 'tenant' => BadgeTone.success,
      'qualified' => BadgeTone.gold,
      'lost' => BadgeTone.danger,
      _ => BadgeTone.neutral,
    };

/// Full contact profile (post-submit lands here for a consistent create → detail
/// workflow). Shows all info, the lifecycle stage, and quick links.
class ContactDetailScreen extends ConsumerWidget {
  const ContactDetailScreen({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(contactDetailProvider(id));
    return Scaffold(
      appBar: NuzlAppBar(title: context.tr('Contact')),
      drawer: const NuzlDrawer(),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(contactDetailProvider(id)),
        child: AsyncView<Map<String, dynamic>>(
          value: detail,
          onRetry: () => ref.invalidate(contactDetailProvider(id)),
          data: (c) => _body(context, ref, c),
        ),
      ),
    );
  }

  Widget _body(BuildContext context, WidgetRef ref, Map<String, dynamic> c) {
    final t = Theme.of(context).textTheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final muted = dark ? AppColors.dTextMuted : AppColors.textMuted;
    final name = '${c['full_name'] ?? 'Contact'}';
    final lifecycle = '${c['lifecycle'] ?? 'lead'}';
    final phone = '${c['phone'] ?? ''}'.trim();
    final email = '${c['email'] ?? ''}'.trim();
    final owner = '${c['owner_name'] ?? ''}'.trim();
    final notes = '${c['notes'] ?? ''}'.trim();
    final hasLead = c['lead_id'] != null;
    final props = int.tryParse('${c['properties'] ?? 0}') ?? 0;
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.x16),
      children: [
        Row(children: [
          UserAvatar(name: name, url: '${c['avatar'] ?? ''}', radius: 28),
          const SizedBox(width: AppSpacing.x12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name, style: t.titleLarge, maxLines: 2, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 4),
              StatusBadge(contactLifecycleLabels[lifecycle] ?? lifecycle, tone: _lifeTone(lifecycle)),
            ]),
          ),
        ]),
        const SizedBox(height: AppSpacing.x16),
        if (phone.isNotEmpty) _row(Icons.phone_outlined, phone, t, muted),
        if (email.isNotEmpty) _row(Icons.email_outlined, email, t, muted),
        if (owner.isNotEmpty) _row(Icons.person_outline, '${context.tr('Owner')}: $owner', t, muted),
        if (props > 0) _row(Icons.home_work_outlined, '$props ${context.tr(props == 1 ? 'property' : 'properties')}', t, muted),
        if (notes.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.x12),
          Text(context.tr('Notes'), style: t.labelLarge),
          Text(notes, style: t.bodyMedium),
        ],
        const SizedBox(height: AppSpacing.x20),
        Text(context.tr('Lifecycle stage'), style: t.labelLarge),
        const SizedBox(height: AppSpacing.x8),
        DropdownButtonFormField<String>(
          initialValue: contactLifecycleOrder.contains(lifecycle) ? lifecycle : null,
          decoration: InputDecoration(labelText: context.tr('Stage')),
          items: [for (final l in contactLifecycleOrder) DropdownMenuItem(value: l, child: Text(contactLifecycleLabels[l] ?? l))],
          onChanged: (v) async {
            if (v == null || v == lifecycle) return;
            try {
              await ref.read(apiClientProvider).patch('/contacts/$id', body: {'lifecycle': v});
              ref.invalidate(contactDetailProvider(id));
            } catch (e) {
              if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
            }
          },
        ),
        if (hasLead) ...[
          const SizedBox(height: AppSpacing.x16),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: () => context.push('/leads/${c['lead_id']}'),
              icon: const Icon(Icons.open_in_new, size: 18),
              label: Text(context.tr('Open lead')),
            ),
          ),
        ],
      ],
    );
  }

  Widget _row(IconData icon, String text, TextTheme t, Color muted) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.x8),
        child: Row(children: [
          Icon(icon, size: 18, color: muted),
          const SizedBox(width: AppSpacing.x8),
          Expanded(child: Text(text, style: t.bodyMedium)),
        ]),
      );
}
