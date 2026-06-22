import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/responsive.dart';
import '../shell/app_shell.dart';

final _partnersProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  try {
    final d = await ref.read(apiClientProvider).get('/developer/partners');
    return d is List ? d : [];
  } catch (_) {
    return [];
  }
});

Color _statusColor(String s) => switch (s) {
      'approved' => AppColors.success,
      'rejected' => AppColors.danger,
      _ => AppColors.warning,
    };

/// Developer ↔ external agency/agent sales partners: approve who may sell your
/// projects, then assign them from a project.
class PartnersScreen extends ConsumerWidget {
  const PartnersScreen({super.key});

  Future<void> _decide(BuildContext context, WidgetRef ref, String id, bool approve) async {
    try {
      await ref.read(apiClientProvider).post('/developer/partners/$id/decide', body: {'approve': approve});
      ref.invalidate(_partnersProvider);
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final partners = ref.watch(_partnersProvider);
    final df = DateFormat('d MMM yyyy');
    return Scaffold(
      appBar: NuzlAppBar(title: context.tr('Sales partners')),
      drawer: const NuzlDrawer(),
      body: ResponsiveCenter(
        child: RefreshIndicator(
          onRefresh: () async => ref.invalidate(_partnersProvider),
          child: partners.when(
            loading: () => const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator())),
            error: (e, _) => Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(friendlyError(e)))),
            data: (list) {
              if (list.isEmpty) {
                return ListView(children: [
                  Padding(
                    padding: const EdgeInsets.all(40),
                    child: Column(children: [
                      Icon(Icons.handshake_outlined, size: 44, color: Theme.of(context).hintColor),
                      const SizedBox(height: 12),
                      Text(context.tr('No partner requests yet')),
                      const SizedBox(height: 4),
                      Text(context.tr('Agencies and agents can request to sell your projects from your public company page.'),
                          textAlign: TextAlign.center, style: TextStyle(color: Theme.of(context).hintColor)),
                    ]),
                  ),
                ]);
              }
              return ListView(
                padding: const EdgeInsets.all(AppSpacing.x16),
                children: [
                  for (final e in list)
                    Builder(builder: (_) {
                      final p = Map<String, dynamic>.from(e);
                      final status = '${p['status'] ?? 'pending'}';
                      final when = DateTime.tryParse('${p['created_at']}');
                      return Card(
                        margin: const EdgeInsets.only(bottom: AppSpacing.x12),
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.x16),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Row(children: [
                              Expanded(
                                child: Text('${p['partner_company'] ?? p['partner_name'] ?? context.tr('Agency')}',
                                    style: t.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(color: _statusColor(status).withValues(alpha: 0.14), borderRadius: BorderRadius.circular(AppSpacing.rFull)),
                                child: Text(context.tr(status[0].toUpperCase() + status.substring(1)),
                                    style: t.labelSmall?.copyWith(color: _statusColor(status), fontWeight: FontWeight.w700)),
                              ),
                            ]),
                            Text([
                              if (p['partner_name'] != null) '${p['partner_name']}',
                              if (p['partner_email'] != null) '${p['partner_email']}',
                              if (when != null) df.format(when),
                            ].where((s) => s.trim().isNotEmpty).join('  ·  '),
                                style: t.bodySmall?.copyWith(color: Theme.of(context).hintColor)),
                            if ('${p['message'] ?? ''}'.isNotEmpty)
                              Padding(padding: const EdgeInsets.only(top: 6), child: Text('${p['message']}', style: t.bodySmall)),
                            if (status == 'pending') ...[
                              const SizedBox(height: AppSpacing.x8),
                              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                                TextButton(
                                  style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
                                  onPressed: () => _decide(context, ref, '${p['id']}', false),
                                  child: Text(context.tr('Decline')),
                                ),
                                const SizedBox(width: AppSpacing.x8),
                                FilledButton(onPressed: () => _decide(context, ref, '${p['id']}', true), child: Text(context.tr('Approve'))),
                              ]),
                            ],
                          ]),
                        ),
                      );
                    }),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
