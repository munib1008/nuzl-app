import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/network/api_client.dart';
import '../../core/network/upload_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/status_badge.dart';
import 'property_docs_repository.dart';

const _docTypes = {
  'title_deed': 'Title deed',
  'ejari': 'Ejari',
  'cheque': 'Cheque copy',
  'agency_fee_receipt': 'Agency fee receipt',
  'passport': 'Passport',
  'emirates_id': 'Emirates ID',
  'noc': 'NOC',
  'other': 'Other',
};

String _docLabel(dynamic t) => _docTypes['$t'] ?? '$t'.replaceAll('_', ' ');

/// Owner <-> agent document collaboration for a property (owner/agent #9/#10/#11):
/// agents request documents, the owner uploads them (Ejari, cheques, agency-fee
/// receipts, title deed — PDF or image), shareable links, and a full activity log.
class PropertyDocsScreen extends ConsumerWidget {
  const PropertyDocsScreen({super.key, required this.propertyId});
  final String propertyId;

  void _refresh(WidgetRef ref) {
    ref.invalidate(propertyDocRequestsProvider(propertyId));
    ref.invalidate(propertyDocumentsProvider(propertyId));
    ref.invalidate(propertyDocActivityProvider(propertyId));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final requests = ref.watch(propertyDocRequestsProvider(propertyId));
    final documents = ref.watch(propertyDocumentsProvider(propertyId));
    final activity = ref.watch(propertyDocActivityProvider(propertyId));
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('Documents'))),
      body: RefreshIndicator(
        onRefresh: () async => _refresh(ref),
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.x16),
          children: [
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _requestDialog(context, ref),
                  icon: const Icon(Icons.request_page_outlined, size: 18),
                  label: Text(context.tr('Request')),
                ),
              ),
              const SizedBox(width: AppSpacing.x12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => _uploadDocument(context, ref),
                  icon: const Icon(Icons.upload_file, size: 18),
                  label: Text(context.tr('Upload')),
                ),
              ),
            ]),
            const SizedBox(height: AppSpacing.x20),

            Text(context.tr('Requests'), style: t.titleSmall),
            const SizedBox(height: AppSpacing.x8),
            requests.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('$e', style: t.bodySmall),
              data: (list) => list.isEmpty
                  ? Text(context.tr('No document requests yet.'), style: t.bodySmall?.copyWith(color: dark ? AppColors.dTextMuted : AppColors.textMuted))
                  : Column(children: [for (final r in list) _requestTile(context, ref, r, t)]),
            ),
            const SizedBox(height: AppSpacing.x16),
            const Divider(),
            const SizedBox(height: AppSpacing.x8),

            Text(context.tr('Documents'), style: t.titleSmall),
            const SizedBox(height: AppSpacing.x8),
            documents.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('$e', style: t.bodySmall),
              data: (list) => list.isEmpty
                  ? Text(context.tr('No documents uploaded yet.'), style: t.bodySmall?.copyWith(color: dark ? AppColors.dTextMuted : AppColors.textMuted))
                  : Column(children: [for (final d in list) _docTile(context, ref, d, t)]),
            ),
            const SizedBox(height: AppSpacing.x16),
            const Divider(),
            const SizedBox(height: AppSpacing.x8),

            Text(context.tr('Activity log'), style: t.titleSmall),
            const SizedBox(height: AppSpacing.x8),
            activity.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('$e', style: t.bodySmall),
              data: (list) => list.isEmpty
                  ? Text(context.tr('Nothing logged yet.'), style: t.bodySmall?.copyWith(color: dark ? AppColors.dTextMuted : AppColors.textMuted))
                  : Column(children: [for (final a in list) _activityTile(context, a, t, dark)]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _requestTile(BuildContext context, WidgetRef ref, Map<String, dynamic> r, TextTheme t) {
    final pending = r['status'] == 'pending';
    return Card(
      child: ListTile(
        title: Text(r['label']?.toString().isNotEmpty == true ? '${r['label']}' : context.tr(_docLabel(r['doc_type']))),
        subtitle: Text([
          context.tr(_docLabel(r['doc_type'])),
          if (r['requested_by_name'] != null) '${context.tr('by')} ${r['requested_by_name']}',
          if (r['note'] != null && '${r['note']}'.isNotEmpty) '${r['note']}',
        ].join('  ·  '), style: t.bodySmall),
        trailing: pending
            ? TextButton(
                onPressed: () => _fulfilRequest(context, ref, r),
                child: Text(context.tr('Upload')),
              )
            : StatusBadge(context.tr('Fulfilled'), tone: BadgeTone.success),
      ),
    );
  }

  Widget _docTile(BuildContext context, WidgetRef ref, Map<String, dynamic> d, TextTheme t) {
    final when = DateTime.tryParse('${d['created_at'] ?? ''}');
    return Card(
      child: ListTile(
        leading: const Icon(Icons.description_outlined),
        title: Text(d['label']?.toString().isNotEmpty == true ? '${d['label']}' : context.tr(_docLabel(d['doc_type']))),
        subtitle: Text([
          context.tr(_docLabel(d['doc_type'])),
          if (d['uploaded_by_name'] != null) '${d['uploaded_by_name']}',
          if (when != null) DateFormat.yMMMd().format(when),
        ].join('  ·  '), style: t.bodySmall),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          IconButton(
            tooltip: context.tr('Copy share link'),
            icon: const Icon(Icons.link, size: 20),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: '${d['file_url']}'));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.tr('Download link copied'))));
              }
            },
          ),
          IconButton(
            tooltip: context.tr('Delete'),
            icon: const Icon(Icons.delete_outline, size: 20),
            onPressed: () => _delete(context, ref, '${d['id']}'),
          ),
        ]),
      ),
    );
  }

  Widget _activityTile(BuildContext context, Map<String, dynamic> a, TextTheme t, bool dark) {
    final when = DateTime.tryParse('${a['created_at'] ?? ''}');
    final isReq = a['kind'] == 'request';
    final verb = context.tr(isReq ? 'requested' : 'uploaded');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.x8),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(isReq ? Icons.request_page_outlined : Icons.upload_file,
              size: 16, color: dark ? AppColors.dPrimary : AppColors.primary),
        ),
        const SizedBox(width: AppSpacing.x12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${a['actor_name'] ?? context.tr('Someone')} $verb ${a['label']?.toString().isNotEmpty == true ? a['label'] : context.tr(_docLabel(a['doc_type']))}',
                style: t.bodyMedium),
            if (when != null)
              Text(DateFormat.yMMMd().add_jm().format(when),
                  style: t.bodySmall?.copyWith(color: dark ? AppColors.dTextMuted : AppColors.textMuted)),
          ]),
        ),
      ]),
    );
  }

  // ── Actions ────────────────────────────────────────────────────────────

  Future<void> _requestDialog(BuildContext context, WidgetRef ref) async {
    String type = 'ejari';
    final label = TextEditingController();
    final note = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text(context.tr('Request a document')),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            DropdownButtonFormField<String>(
              initialValue: type,
              decoration: InputDecoration(labelText: context.tr('Document type')),
              items: [for (final e in _docTypes.entries) DropdownMenuItem(value: e.key, child: Text(context.tr(e.value)))],
              onChanged: (v) => setLocal(() => type = v ?? 'other'),
            ),
            const SizedBox(height: AppSpacing.x12),
            TextField(controller: label, decoration: InputDecoration(
                labelText: context.tr('What exactly do you need?'), hintText: context.tr('e.g. Q2 rent cheque copy'))),
            const SizedBox(height: AppSpacing.x12),
            TextField(controller: note, maxLines: 2, decoration: InputDecoration(labelText: context.tr('Note (optional)'))),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(context.tr('Cancel'))),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(context.tr('Send request'))),
          ],
        ),
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(propertyDocsRepoProvider).requestDoc(propertyId, type, label.text.trim(), note.text.trim());
      _refresh(ref);
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.tr('Request sent'))));
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
    }
  }

  Future<void> _uploadDocument(BuildContext context, WidgetRef ref) async {
    String type = 'other';
    final label = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text(context.tr('Upload a document')),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            DropdownButtonFormField<String>(
              initialValue: type,
              decoration: InputDecoration(labelText: context.tr('Document type')),
              items: [for (final e in _docTypes.entries) DropdownMenuItem(value: e.key, child: Text(context.tr(e.value)))],
              onChanged: (v) => setLocal(() => type = v ?? 'other'),
            ),
            const SizedBox(height: AppSpacing.x12),
            TextField(controller: label, decoration: InputDecoration(labelText: context.tr('Label (optional)'))),
            const SizedBox(height: AppSpacing.x8),
            Text(context.tr('You can attach a PDF or an image.'), style: const TextStyle(fontSize: 12)),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(context.tr('Cancel'))),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(context.tr('Choose file'))),
          ],
        ),
      ),
    );
    if (ok != true || !context.mounted) return;
    final url = await _pickAndUpload(context, ref);
    if (url == null) return;
    try {
      await ref.read(propertyDocsRepoProvider).addDoc(propertyId,
          docType: type, label: label.text.trim(), fileUrl: url);
      _refresh(ref);
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.tr('Document uploaded'))));
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
    }
  }

  Future<void> _fulfilRequest(BuildContext context, WidgetRef ref, Map<String, dynamic> r) async {
    final url = await _pickAndUpload(context, ref);
    if (url == null) return;
    try {
      await ref.read(propertyDocsRepoProvider).addDoc(propertyId,
          docType: '${r['doc_type']}', label: r['label']?.toString(), fileUrl: url, requestId: '${r['id']}');
      _refresh(ref);
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.tr('Request fulfilled'))));
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, String docId) async {
    try {
      await ref.read(propertyDocsRepoProvider).deleteDoc(propertyId, docId);
      _refresh(ref);
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
    }
  }

  /// Pick a PDF/image and upload it → returns the public URL (or null).
  Future<String?> _pickAndUpload(BuildContext context, WidgetRef ref) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png', 'webp'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return null;
    final f = result.files.first;
    final bytes = f.bytes;
    if (bytes == null) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.tr('Could not read the file'))));
      return null;
    }
    final ext = (f.extension ?? '').toLowerCase();
    final ct = ext == 'pdf'
        ? 'application/pdf'
        : ext == 'png'
            ? 'image/png'
            : ext == 'webp'
                ? 'image/webp'
                : 'image/jpeg';
    try {
      final url = await ref.read(uploadServiceProvider).upload(bytes, f.name, ct);
      if (url == null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.tr('Upload returned no URL'))));
      }
      return url;
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${context.tr('Upload failed')}: $e')));
      return null;
    }
  }
}
