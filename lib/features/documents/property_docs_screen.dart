import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
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
    final requests = ref.watch(propertyDocRequestsProvider(propertyId));
    final documents = ref.watch(propertyDocumentsProvider(propertyId));
    final activity = ref.watch(propertyDocActivityProvider(propertyId));
    return Scaffold(
      appBar: AppBar(title: const Text('Documents')),
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
                  label: const Text('Request'),
                ),
              ),
              const SizedBox(width: AppSpacing.x12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => _uploadDocument(context, ref),
                  icon: const Icon(Icons.upload_file, size: 18),
                  label: const Text('Upload'),
                ),
              ),
            ]),
            const SizedBox(height: AppSpacing.x20),

            Text('Requests', style: t.titleSmall),
            const SizedBox(height: AppSpacing.x8),
            requests.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('$e', style: t.bodySmall),
              data: (list) => list.isEmpty
                  ? Text('No document requests yet.', style: t.bodySmall?.copyWith(color: AppColors.textMuted))
                  : Column(children: [for (final r in list) _requestTile(context, ref, r, t)]),
            ),
            const SizedBox(height: AppSpacing.x16),
            const Divider(),
            const SizedBox(height: AppSpacing.x8),

            Text('Documents', style: t.titleSmall),
            const SizedBox(height: AppSpacing.x8),
            documents.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('$e', style: t.bodySmall),
              data: (list) => list.isEmpty
                  ? Text('No documents uploaded yet.', style: t.bodySmall?.copyWith(color: AppColors.textMuted))
                  : Column(children: [for (final d in list) _docTile(context, ref, d, t)]),
            ),
            const SizedBox(height: AppSpacing.x16),
            const Divider(),
            const SizedBox(height: AppSpacing.x8),

            Text('Activity log', style: t.titleSmall),
            const SizedBox(height: AppSpacing.x8),
            activity.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('$e', style: t.bodySmall),
              data: (list) => list.isEmpty
                  ? Text('Nothing logged yet.', style: t.bodySmall?.copyWith(color: AppColors.textMuted))
                  : Column(children: [for (final a in list) _activityTile(a, t)]),
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
        title: Text(r['label']?.toString().isNotEmpty == true ? '${r['label']}' : _docLabel(r['doc_type'])),
        subtitle: Text([
          _docLabel(r['doc_type']),
          if (r['requested_by_name'] != null) 'by ${r['requested_by_name']}',
          if (r['note'] != null && '${r['note']}'.isNotEmpty) '${r['note']}',
        ].join('  ·  '), style: t.bodySmall),
        trailing: pending
            ? TextButton(
                onPressed: () => _fulfilRequest(context, ref, r),
                child: const Text('Upload'),
              )
            : const StatusBadge('Fulfilled', tone: BadgeTone.success),
      ),
    );
  }

  Widget _docTile(BuildContext context, WidgetRef ref, Map<String, dynamic> d, TextTheme t) {
    final when = DateTime.tryParse('${d['created_at'] ?? ''}');
    return Card(
      child: ListTile(
        leading: const Icon(Icons.description_outlined),
        title: Text(d['label']?.toString().isNotEmpty == true ? '${d['label']}' : _docLabel(d['doc_type'])),
        subtitle: Text([
          _docLabel(d['doc_type']),
          if (d['uploaded_by_name'] != null) '${d['uploaded_by_name']}',
          if (when != null) DateFormat.yMMMd().format(when),
        ].join('  ·  '), style: t.bodySmall),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          IconButton(
            tooltip: 'Copy share link',
            icon: const Icon(Icons.link, size: 20),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: '${d['file_url']}'));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Download link copied')));
              }
            },
          ),
          IconButton(
            tooltip: 'Delete',
            icon: const Icon(Icons.delete_outline, size: 20),
            onPressed: () => _delete(context, ref, '${d['id']}'),
          ),
        ]),
      ),
    );
  }

  Widget _activityTile(Map<String, dynamic> a, TextTheme t) {
    final when = DateTime.tryParse('${a['created_at'] ?? ''}');
    final isReq = a['kind'] == 'request';
    final verb = isReq ? 'requested' : 'uploaded';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.x8),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(isReq ? Icons.request_page_outlined : Icons.upload_file,
              size: 16, color: AppColors.primary),
        ),
        const SizedBox(width: AppSpacing.x12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${a['actor_name'] ?? 'Someone'} $verb ${a['label']?.toString().isNotEmpty == true ? a['label'] : _docLabel(a['doc_type'])}',
                style: t.bodyMedium),
            if (when != null)
              Text(DateFormat.yMMMd().add_jm().format(when),
                  style: t.bodySmall?.copyWith(color: AppColors.textMuted)),
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
          title: const Text('Request a document'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            DropdownButtonFormField<String>(
              initialValue: type,
              decoration: const InputDecoration(labelText: 'Document type'),
              items: [for (final e in _docTypes.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
              onChanged: (v) => setLocal(() => type = v ?? 'other'),
            ),
            const SizedBox(height: AppSpacing.x12),
            TextField(controller: label, decoration: const InputDecoration(
                labelText: 'What exactly do you need?', hintText: 'e.g. Q2 rent cheque copy')),
            const SizedBox(height: AppSpacing.x12),
            TextField(controller: note, maxLines: 2, decoration: const InputDecoration(labelText: 'Note (optional)')),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Send request')),
          ],
        ),
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(propertyDocsRepoProvider).requestDoc(propertyId, type, label.text.trim(), note.text.trim());
      _refresh(ref);
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Request sent')));
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
          title: const Text('Upload a document'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            DropdownButtonFormField<String>(
              initialValue: type,
              decoration: const InputDecoration(labelText: 'Document type'),
              items: [for (final e in _docTypes.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
              onChanged: (v) => setLocal(() => type = v ?? 'other'),
            ),
            const SizedBox(height: AppSpacing.x12),
            TextField(controller: label, decoration: const InputDecoration(labelText: 'Label (optional)')),
            const SizedBox(height: AppSpacing.x8),
            const Text('You can attach a PDF or an image.', style: TextStyle(fontSize: 12)),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Choose file')),
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
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Document uploaded')));
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
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Request fulfilled')));
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
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not read the file')));
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
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Upload returned no URL')));
      }
      return url;
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload failed: $e')));
      return null;
    }
  }
}
