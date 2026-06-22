import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/responsive.dart';
import '../../core/widgets/verification_badge.dart';
import '../shell/app_shell.dart';

/// Nuzler-only queue of companies awaiting business (trade-license) verification.
final companyVerifProvider =
    FutureProvider.autoDispose.family<List<dynamic>, String>((ref, status) async {
  final d = await ref.read(apiClientProvider).get('/organizations/verifications', query: {'status': status});
  return d is List ? d : [];
});

class CompanyVerificationsScreen extends ConsumerStatefulWidget {
  const CompanyVerificationsScreen({super.key});
  @override
  ConsumerState<CompanyVerificationsScreen> createState() => _CompanyVerificationsScreenState();
}

class _CompanyVerificationsScreenState extends ConsumerState<CompanyVerificationsScreen> {
  String _status = 'pending';

  @override
  Widget build(BuildContext context) {
    final queue = ref.watch(companyVerifProvider(_status));
    return Scaffold(
      appBar: NuzlAppBar(title: context.tr('Company verifications')),
      drawer: const NuzlDrawer(),
      body: ResponsiveCenter(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.x16, AppSpacing.x12, AppSpacing.x16, 0),
            child: Wrap(spacing: AppSpacing.x8, children: [
              for (final s in const ['pending', 'verified', 'rejected'])
                ChoiceChip(
                  label: Text(context.tr(s[0].toUpperCase() + s.substring(1))),
                  selected: _status == s,
                  onSelected: (_) => setState(() => _status = s),
                ),
            ]),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async => ref.refresh(companyVerifProvider(_status).future),
              child: queue.when(
                loading: () => const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator())),
                error: (e, _) => ListView(children: [Padding(padding: const EdgeInsets.all(24), child: Text(friendlyError(e)))]),
                data: (list) => list.isEmpty
                    ? ListView(children: [
                        const SizedBox(height: 80),
                        Center(child: Text('${context.tr('Nothing')} $_status.', style: const TextStyle(color: AppColors.textMuted))),
                      ])
                    : ListView.separated(
                        padding: const EdgeInsets.all(AppSpacing.x16),
                        itemCount: list.length,
                        separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.x12),
                        itemBuilder: (_, i) => _CompanyCard(org: Map<String, dynamic>.from(list[i]), status: _status),
                      ),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

class _CompanyCard extends ConsumerWidget {
  const _CompanyCard({required this.org, required this.status});
  final Map<String, dynamic> org;
  final String status;

  Future<void> _decide(BuildContext context, WidgetRef ref, bool approve, {String? note}) async {
    try {
      await ref.read(apiClientProvider)
          .post('/organizations/${org['id']}/verify', body: {'approve': approve, 'note': note});
      ref.invalidate(companyVerifProvider(status));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.tr(approve ? 'Company verified ✓' : 'Company rejected'))));
      }
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
    }
  }

  void _viewDoc(BuildContext context) {
    final url = '${org['trade_license_doc'] ?? ''}'.trim();
    if (url.isEmpty) return;
    showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          AppBar(
            title: Text(context.tr('Trade license')),
            automaticallyImplyLeading: false,
            actions: [IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context))],
          ),
          Flexible(
            child: InteractiveViewer(
              child: Image.network(url, fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => Padding(
                      padding: const EdgeInsets.all(40), child: Text(context.tr('Could not load the document.')))),
            ),
          ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final submitted = DateTime.tryParse('${org['submitted_at'] ?? ''}');
    final hasDoc = '${org['trade_license_doc'] ?? ''}'.trim().isNotEmpty;
    final license = '${org['trade_license'] ?? ''}'.trim();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.x16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text('${org['name'] ?? context.tr('Company')}',
                style: t.titleSmall?.copyWith(fontWeight: FontWeight.w700))),
            VerificationBadge('${org['verification_status'] ?? status}'),
          ]),
          const SizedBox(height: 2),
          Text([
            if ('${org['owner_name'] ?? ''}'.isNotEmpty) '${context.tr('Owner')}: ${org['owner_name']}',
            if ('${org['owner_email'] ?? ''}'.isNotEmpty) '${org['owner_email']}',
          ].join(' · '), style: t.bodySmall?.copyWith(color: AppColors.textMuted)),
          const SizedBox(height: AppSpacing.x4),
          Text([
            if (license.isNotEmpty) '${context.tr('License')}: $license',
            if (submitted != null) '${context.tr('Submitted')} ${DateFormat('d MMM, HH:mm').format(submitted.toLocal())}',
          ].join(' · '), style: t.bodySmall?.copyWith(color: AppColors.textMuted)),
          if ('${org['verification_note'] ?? ''}'.trim().isNotEmpty) ...[
            const SizedBox(height: AppSpacing.x4),
            Text('${context.tr('Note')}: ${org['verification_note']}', style: t.bodySmall?.copyWith(color: AppColors.danger)),
          ],
          const SizedBox(height: AppSpacing.x12),
          Wrap(spacing: AppSpacing.x8, runSpacing: AppSpacing.x8, children: [
            OutlinedButton.icon(
              onPressed: hasDoc ? () => _viewDoc(context) : null,
              icon: const Icon(Icons.description_outlined, size: 18),
              label: Text(context.tr('View license')),
            ),
            if (status != 'rejected')
              OutlinedButton.icon(
                onPressed: () async {
                  final reason = await _askReason(context);
                  if (reason == null) return;
                  if (context.mounted) await _decide(context, ref, false, note: reason);
                },
                style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger),
                icon: const Icon(Icons.close, size: 18),
                label: Text(context.tr('Reject')),
              ),
            if (status != 'verified')
              FilledButton.icon(
                onPressed: () => _decide(context, ref, true),
                icon: const Icon(Icons.verified, size: 18),
                label: Text(context.tr('Approve')),
              ),
          ]),
        ]),
      ),
    );
  }
}

Future<String?> _askReason(BuildContext context) =>
    showDialog<String>(context: context, builder: (_) => const _RejectReasonDialog());

class _RejectReasonDialog extends StatefulWidget {
  const _RejectReasonDialog();
  @override
  State<_RejectReasonDialog> createState() => _RejectReasonDialogState();
}

class _RejectReasonDialogState extends State<_RejectReasonDialog> {
  final _ctrl = TextEditingController();
  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(context.tr('Reject company')),
      content: TextField(
        controller: _ctrl,
        autofocus: true,
        minLines: 2,
        maxLines: 4,
        decoration: InputDecoration(
          hintText: context.tr('Reason (shown to the company), e.g. license expired'),
          border: const OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(context.tr('Cancel'))),
        FilledButton(onPressed: () => Navigator.pop(context, _ctrl.text.trim()), child: Text(context.tr('Reject'))),
      ],
    );
  }
}
