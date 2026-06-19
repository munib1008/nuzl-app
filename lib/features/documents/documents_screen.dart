import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/responsive.dart';
import '../auth/application/auth_controller.dart';
import '../shell/app_shell.dart';

/// Personal document vault: GET /documents for the signed-in user.
final documentsProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  final me = ref.watch(authControllerProvider).user;
  if (me == null) return [];
  try {
    final d = await ref.read(apiClientProvider).get('/documents', query: {
      'owner_table': 'users',
      'owner_id': me.id,
    });
    return d is List ? d : [];
  } catch (_) {
    return [];
  }
});

const _docTypes = [
  'title_deed', 'spa', 'mou', 'form_a', 'form_b', 'form_f',
  'noc', 'mortgage_approval', 'tenancy_contract', 'ejari', 'other',
];

class DocumentsScreen extends ConsumerWidget {
  const DocumentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final docs = ref.watch(documentsProvider);
    return Scaffold(
      appBar: const NuzlAppBar(title: 'Documents'),
      drawer: const NuzlDrawer(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _upload(context, ref),
        icon: const Icon(Icons.upload_file),
        label: const Text('Upload'),
      ),
      body: ResponsiveCenter(
        child: docs.when(
          loading: () => const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator())),
          error: (e, _) => Center(child: Padding(padding: const EdgeInsets.all(24), child: Text('$e'))),
          data: (list) => list.isEmpty
              ? const EmptyState(
                  icon: Icons.folder_open_outlined,
                  title: 'No documents yet',
                  message: 'Upload a document to keep everything for this property in one place.',
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(AppSpacing.x16),
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.x8),
                  itemBuilder: (_, i) {
                    final m = Map<String, dynamic>.from(list[i]);
                    final created = DateTime.tryParse('${m['created_at']}');
                    final when = created != null ? DateFormat('d MMM y').format(created) : '';
                    return Card(
                      child: ListTile(
                        leading: const Icon(Icons.description_outlined),
                        title: Text(_humanize('${m['doc_type'] ?? 'document'}')),
                        subtitle: Text([m['uploaded_by_name'], when]
                            .where((x) => x != null && '$x'.isNotEmpty)
                            .join('  ·  ')),
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }

  Future<void> _upload(BuildContext context, WidgetRef ref) async {
    final me = ref.read(authControllerProvider).user;
    if (me == null) return;
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 2200, imageQuality: 85);
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    if (!context.mounted) return;
    var type = 'other';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Document type'),
        content: StatefulBuilder(
          builder: (ctx, setS) => DropdownButtonFormField<String>(
            initialValue: type,
            decoration: const InputDecoration(labelText: 'Type'),
            items: _docTypes.map((d) => DropdownMenuItem(value: d, child: Text(_humanize(d)))).toList(),
            onChanged: (v) => setS(() => type = v ?? 'other'),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Upload')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final up = await ref.read(apiClientProvider).post('/uploads', body: {
        'filename': picked.name,
        'contentType': 'image/jpeg',
        'dataBase64': base64Encode(bytes),
      });
      final key = (up is Map) ? (up['path'] ?? up['url']) : null;
      if (key == null) throw Exception('Upload failed — storage not configured');
      await ref.read(apiClientProvider).post('/documents', body: {
        'owner_table': 'users',
        'owner_id': me.id,
        'doc_type': type,
        'storage_key': key,
      });
      ref.invalidate(documentsProvider);
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }
}

String _humanize(String k) => k
    .replaceAll('_', ' ')
    .split(' ')
    .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
    .join(' ');
