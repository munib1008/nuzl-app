import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/i18n/app_localizations.dart';
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

/// Property-RECORD ownership submissions (owner deed-verification flow) — these
/// may have no listing, so they get their own queue (owner deed spec §19).
final ownershipRecordsProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  final d = await ref.read(apiClientProvider).get('/admin/ownership-records', query: {'status': 'pending'});
  return d is List ? d : [];
});

class VerificationQueueScreen extends StatelessWidget {
  const VerificationQueueScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: NuzlAppBar(title: context.tr('Verification queue')),
        drawer: const NuzlDrawer(),
        body: ResponsiveCenter(
          child: Column(children: [
            TabBar(tabs: [Tab(text: context.tr('Listings')), Tab(text: context.tr('Owner records'))]),
            const Expanded(child: TabBarView(children: [_ListingQueue(), _OwnerRecordQueue()])),
          ]),
        ),
      ),
    );
  }
}

class _ListingQueue extends ConsumerWidget {
  const _ListingQueue();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queue = ref.watch(verificationQueueProvider);
    return RefreshIndicator(
      onRefresh: () async => ref.refresh(verificationQueueProvider.future),
      child: queue.when(
        loading: () => const Center(
            child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator())),
        error: (e, _) => ListView(children: [
          Padding(padding: const EdgeInsets.all(24), child: Text(friendlyError(e))),
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
    );
  }
}

class _OwnerRecordQueue extends ConsumerWidget {
  const _OwnerRecordQueue();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queue = ref.watch(ownershipRecordsProvider);
    return RefreshIndicator(
      onRefresh: () async => ref.refresh(ownershipRecordsProvider.future),
      child: queue.when(
        loading: () => const Center(
            child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator())),
        error: (e, _) => ListView(children: [
          Padding(padding: const EdgeInsets.all(24), child: Text(friendlyError(e))),
        ]),
        data: (list) => list.isEmpty
            ? ListView(children: const [SizedBox(height: 80), _Empty()])
            : ListView.separated(
                padding: const EdgeInsets.all(AppSpacing.x16),
                itemCount: list.length,
                separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.x12),
                itemBuilder: (_, i) => _OwnerRecordCard(item: Map<String, dynamic>.from(list[i])),
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.tr('Listing verified ✓'))));
      }
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.tr('Submission rejected'))));
      }
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
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
              title: Text(context.tr('Title deed')),
              automaticallyImplyLeading: false,
              actions: [IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context))],
            ),
            Flexible(
              child: InteractiveViewer(
                child: Image.network(url,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => Padding(
                        padding: const EdgeInsets.all(40), child: Text(context.tr('Could not load the document.')))),
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
      if ('${item['unit_no'] ?? ''}'.isNotEmpty) '${context.tr('Unit')} ${item['unit_no']}',
    ].join(' · ');
    final broker = '${item['broker_name'] ?? context.tr('Unknown')}';
    final submitted = DateTime.tryParse('${item['ownership_submitted_at'] ?? ''}');
    final hasDeed = '${item['ownership_doc_url'] ?? ''}'.trim().isNotEmpty;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.x16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title.isEmpty ? context.tr('Listing') : title,
                style: t.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text('${context.tr('Submitted by')} $broker${submitted != null ? ' · ${DateFormat('d MMM, HH:mm').format(submitted.toLocal())}' : ''}',
                style: t.bodySmall?.copyWith(color: AppColors.textMuted)),
            const SizedBox(height: AppSpacing.x12),
            Wrap(
              spacing: AppSpacing.x8,
              runSpacing: AppSpacing.x8,
              children: [
                OutlinedButton.icon(
                  onPressed: hasDeed ? () => _viewDeed(context) : null,
                  icon: const Icon(Icons.description_outlined, size: 18),
                  label: Text(context.tr('View deed')),
                ),
                OutlinedButton.icon(
                  onPressed: () => _reject(context, ref),
                  style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger),
                  icon: const Icon(Icons.close, size: 18),
                  label: Text(context.tr('Reject')),
                ),
                FilledButton.icon(
                  onPressed: () => _approve(context, ref),
                  icon: const Icon(Icons.verified, size: 18),
                  label: Text(context.tr('Approve')),
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

/// Directory search to pick the new owner for an ownership transfer (§19).
Future<Map<String, dynamic>?> _pickUser(BuildContext context, WidgetRef ref) {
  final search = TextEditingController();
  var results = <Map<String, dynamic>>[];
  return showDialog<Map<String, dynamic>>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setS) {
        Future<void> run(String q) async {
          if (q.trim().length < 2) {
            setS(() => results = []);
            return;
          }
          try {
            final r = await ref.read(apiClientProvider).get('/users/search', query: {'q': q.trim()});
            setS(() => results = (r as List).map((e) => Map<String, dynamic>.from(e as Map)).toList());
          } catch (_) {
            setS(() => results = []);
          }
        }

        return AlertDialog(
          title: Text(context.tr('Transfer to')),
          content: SizedBox(
            width: 380,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(
                controller: search,
                autofocus: true,
                decoration: InputDecoration(hintText: context.tr('Search a user by name…'), prefixIcon: const Icon(Icons.search)),
                onChanged: run,
              ),
              const SizedBox(height: AppSpacing.x8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 280),
                child: results.isEmpty
                    ? Padding(padding: const EdgeInsets.all(16), child: Text(context.tr('Type at least 2 letters to search')))
                    : ListView(
                        shrinkWrap: true,
                        children: [
                          for (final u in results)
                            ListTile(
                              dense: true,
                              title: Text('${u['full_name'] ?? context.tr('User')}'),
                              subtitle: u['email'] != null ? Text('${u['email']}') : null,
                              onTap: () => Navigator.pop(ctx, Map<String, dynamic>.from(u)),
                            ),
                        ],
                      ),
              ),
            ]),
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text(context.tr('Close')))],
        );
      },
    ),
  );
}

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
      title: Text(context.tr('Reject submission')),
      content: TextField(
        controller: _ctrl,
        autofocus: true,
        minLines: 2,
        maxLines: 4,
        decoration: InputDecoration(
          hintText: context.tr('Reason (shown to the lister), e.g. document unclear'),
          border: const OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(context.tr('Cancel'))),
        FilledButton(
          onPressed: () => Navigator.pop(context, _ctrl.text.trim()),
          child: Text(context.tr('Reject')),
        ),
      ],
    );
  }
}

/// One owner property-record awaiting ownership verification (name-match score,
/// deed link, account vs deed name) with Verify / Reject overrides.
class _OwnerRecordCard extends ConsumerWidget {
  const _OwnerRecordCard({required this.item});
  final Map<String, dynamic> item;

  Future<void> _approve(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(apiClientProvider).post('/admin/ownership-records/${item['id']}/approve');
      ref.invalidate(ownershipRecordsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.tr('Ownership verified ✓'))));
      }
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
    }
  }

  Future<void> _reject(BuildContext context, WidgetRef ref) async {
    final reason = await _askReason(context);
    if (reason == null) return;
    try {
      await ref.read(apiClientProvider)
          .post('/admin/ownership-records/${item['id']}/reject', body: {'reason': reason});
      ref.invalidate(ownershipRecordsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.tr('Ownership rejected'))));
      }
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
    }
  }

  Future<void> _lock(BuildContext context, WidgetRef ref, bool locked) async {
    try {
      await ref.read(apiClientProvider).post('/admin/ownership-records/${item['id']}/lock', body: {'locked': locked});
      ref.invalidate(ownershipRecordsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(context.tr(locked ? 'Property locked' : 'Property unlocked'))));
      }
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
    }
  }

  Future<void> _transfer(BuildContext context, WidgetRef ref) async {
    final picked = await _pickUser(context, ref);
    if (picked == null || !context.mounted) return;
    final name = '${picked['full_name'] ?? context.tr('this user')}';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.tr('Transfer ownership')),
        content: Text('${context.tr('Transfer this property to')} $name? ${context.tr('Ownership resets to pending and the property moves to their portfolio.')}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(context.tr('Cancel'))),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(context.tr('Transfer'))),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(apiClientProvider)
          .post('/admin/ownership-records/${item['id']}/transfer', body: {'owner_id': picked['id']});
      ref.invalidate(ownershipRecordsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${context.tr('Ownership transferred to')} $name')));
      }
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final title = [
      if ('${item['building_name'] ?? item['community'] ?? ''}'.isNotEmpty) '${item['building_name'] ?? item['community']}',
      if ('${item['property_type'] ?? ''}'.isNotEmpty) _cap('${item['property_type']}'),
      if ('${item['unit_no'] ?? ''}'.isNotEmpty) '${context.tr('Unit')} ${item['unit_no']}',
    ].join(' · ');
    final owner = '${item['owner_name'] ?? context.tr('Unknown')}';
    final deedName = '${item['owner_name_on_deed'] ?? ''}'.trim();
    final deedNo = '${item['title_deed_number'] ?? ''}'.trim();
    final refCode = '${item['ref_code'] ?? ''}'.trim();
    final score = num.tryParse('${item['ownership_match_score'] ?? ''}');
    final deedUrl = '${item['deed_url'] ?? ''}'.trim();
    final locked = item['locked'] == true;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.x16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(
                child: Text(title.isEmpty ? context.tr('Property') : title,
                    style: t.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
              ),
              if (locked)
                const Padding(
                    padding: EdgeInsets.only(right: 6),
                    child: Icon(Icons.lock, size: 14, color: AppColors.danger)),
              if (refCode.isNotEmpty) Text(refCode, style: t.bodySmall?.copyWith(color: AppColors.textMuted)),
            ]),
            const SizedBox(height: 2),
            Text('${context.tr('Account')}: $owner', style: t.bodySmall?.copyWith(color: AppColors.textMuted)),
            if (deedName.isNotEmpty) Text('${context.tr('On deed')}: $deedName', style: t.bodySmall?.copyWith(color: AppColors.textMuted)),
            if (deedNo.isNotEmpty) Text('${context.tr('Deed no.')}: $deedNo', style: t.bodySmall?.copyWith(color: AppColors.textMuted)),
            if (score != null) Padding(
              padding: const EdgeInsets.only(top: 6),
              child: _MatchChip(score: score.toDouble()),
            ),
            const SizedBox(height: AppSpacing.x12),
            Wrap(
              spacing: AppSpacing.x8,
              runSpacing: AppSpacing.x8,
              children: [
                OutlinedButton.icon(
                  onPressed: deedUrl.isEmpty
                      ? null
                      : () async {
                          final uri = Uri.tryParse(deedUrl);
                          if (uri != null) await launchUrl(uri, mode: LaunchMode.externalApplication);
                        },
                  icon: const Icon(Icons.description_outlined, size: 18),
                  label: Text(context.tr('View deed')),
                ),
                OutlinedButton.icon(
                  onPressed: () => _reject(context, ref),
                  style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger),
                  icon: const Icon(Icons.close, size: 18),
                  label: Text(context.tr('Reject')),
                ),
                FilledButton.icon(
                  onPressed: () => _approve(context, ref),
                  icon: const Icon(Icons.verified, size: 18),
                  label: Text(context.tr('Verify')),
                ),
                OutlinedButton.icon(
                  onPressed: () => _lock(context, ref, !locked),
                  icon: Icon(locked ? Icons.lock_open_outlined : Icons.lock_outline, size: 18),
                  label: Text(context.tr(locked ? 'Unlock' : 'Lock')),
                ),
                OutlinedButton.icon(
                  onPressed: () => _transfer(context, ref),
                  icon: const Icon(Icons.swap_horiz, size: 18),
                  label: Text(context.tr('Transfer')),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Name-match confidence chip (green >=60%, amber >0, red 0).
class _MatchChip extends StatelessWidget {
  const _MatchChip({required this.score});
  final double score;
  @override
  Widget build(BuildContext context) {
    final pct = (score * 100).round();
    final color = score >= 0.6 ? AppColors.success : (score > 0 ? AppColors.warning : AppColors.danger);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSpacing.rFull),
      ),
      child: Text('${context.tr('Name match')} $pct%',
          style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12)),
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
            Text(context.tr('Nothing to review'), style: t.titleMedium),
            const SizedBox(height: AppSpacing.x8),
            Text(context.tr('Title-deed submissions appear here for approval.'),
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
