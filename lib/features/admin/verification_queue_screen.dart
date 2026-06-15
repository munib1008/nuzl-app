import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/responsive.dart';
import '../shell/app_shell.dart';

/// Nuzler-only queue of listings awaiting ownership (title-deed) verification.
final verificationQueueProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  final d = await ref.read(apiClientProvider).get('/admin/verification-queue', query: {'status': 'pending'});
  return d is List ? d : [];
});

class VerificationQueueScreen extends ConsumerWidget {
  const VerificationQueueScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queue = ref.watch(verificationQueueProvider);
    return Scaffold(
      appBar: const NuzlAppBar(title: 'Verification queue'),
      drawer: const NuzlDrawer(),
      body: ResponsiveCenter(
        child: RefreshIndicator(
          onRefresh: () async => ref.refresh(verificationQueueProvider.future),
          child: queue.when(
            loading: () => const Center(
                child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator())),
            error: (e, _) => ListView(children: [
              Padding(padding: const EdgeInsets.all(24), child: Text('$e')),
            ]),
            data: (list) => list.isEmpty
                ? ListView(children: const [SizedBox(height: 80), _Empty()])
                : ListView.separated(
                    padding: const EdgeInsets.all(AppSpacing.x16),
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.x12),
                    itemBuilder: (_, i) => _QueueCard(item: Map<String, dynamic>.from(list[i])),
                  ),
          ),
        ),
      ),
    );
  }
}

class _QueueCard extends ConsumerWidget {
  const _QueueCard({required this.item});
  final Map<String, dynamic> item;

  Future<void> _approve(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(apiClientProvider).post('/admin/verification-queue/${item['id']}/approve');
      ref.invalidate(verificationQueueProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Listing verified ✓')));
      }
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _reject(BuildContext context, WidgetRef ref) async {
    final reason = await _askReason(context);
    if (reason == null) return; // cancelled
    try {
      await ref.read(apiClientProvider)
          .post('/admin/verification-queue/${item['id']}/reject', body: {'reason': reason});
      ref.invalidate(verificationQueueProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Submission rejected')));
      }
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  void _viewDeed(BuildContext context) {
    final url = '${item['ownership_doc_url'] ?? ''}'.trim();
    if (url.isEmpty) return;
    showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppBar(
              title: const Text('Title deed'),
              automaticallyImplyLeading: false,
              actions: [IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context))],
            ),
            Flexible(
              child: InteractiveViewer(
                child: Image.network(url,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Padding(
                        padding: EdgeInsets.all(40), child: Text('Could not load the document.'))),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final title = [
      if ('${item['community'] ?? ''}'.isNotEmpty) '${item['community']}',
      if ('${item['property_type'] ?? ''}'.isNotEmpty) _cap('${item['property_type']}'),
      if ('${item['unit_no'] ?? ''}'.isNotEmpty) 'Unit ${item['unit_no']}',
    ].join(' · ');
    final broker = '${item['broker_name'] ?? 'Unknown'}';
    final submitted = DateTime.tryParse('${item['ownership_submitted_at'] ?? ''}');
    final hasDeed = '${item['ownership_doc_url'] ?? ''}'.trim().isNotEmpty;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.x16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title.isEmpty ? 'Listing' : title,
                style: t.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text('Submitted by $broker${submitted != null ? ' · ${DateFormat('d MMM, HH:mm').format(submitted.toLocal())}' : ''}',
                style: t.bodySmall?.copyWith(color: AppColors.textMuted)),
            const SizedBox(height: AppSpacing.x12),
            Wrap(
              spacing: AppSpacing.x8,
              runSpacing: AppSpacing.x8,
              children: [
                OutlinedButton.icon(
                  onPressed: hasDeed ? () => _viewDeed(context) : null,
                  icon: const Icon(Icons.description_outlined, size: 18),
                  label: const Text('View deed'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _reject(context, ref),
                  style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger),
                  icon: const Icon(Icons.close, size: 18),
                  label: const Text('Reject'),
                ),
                FilledButton.icon(
                  onPressed: () => _approve(context, ref),
                  icon: const Icon(Icons.verified, size: 18),
                  label: const Text('Approve'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Returns the trimmed reason on Reject, or null on Cancel. Backed by a
/// StatefulWidget so the TextEditingController is disposed (no leak).
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
      title: const Text('Reject submission'),
      content: TextField(
        controller: _ctrl,
        autofocus: true,
        minLines: 2,
        maxLines: 4,
        decoration: const InputDecoration(
          hintText: 'Reason (shown to the lister), e.g. document unclear',
          border: OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: () => Navigator.pop(context, _ctrl.text.trim()),
          child: const Text('Reject'),
        ),
      ],
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.x32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.verified_user_outlined, size: 56, color: AppColors.textSubtle),
            const SizedBox(height: AppSpacing.x16),
            Text('Nothing to review', style: t.titleMedium),
            const SizedBox(height: AppSpacing.x8),
            Text('Title-deed submissions appear here for approval.',
                textAlign: TextAlign.center, style: t.bodyMedium?.copyWith(color: AppColors.textMuted)),
          ],
        ),
      ),
    );
  }
}

String _cap(String s) {
  final x = s.replaceAll('_', ' ').trim();
  return x.isEmpty ? x : '${x[0].toUpperCase()}${x.substring(1)}';
}
