import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/responsive.dart';
import '../../shell/app_shell.dart';
import '../data/leads_repository.dart' show leadsProvider;

/// Mass lead upload — paste CSV or pick a .csv file, preview, then import.
class BulkLeadImportScreen extends ConsumerStatefulWidget {
  const BulkLeadImportScreen({super.key});
  @override
  ConsumerState<BulkLeadImportScreen> createState() => _BulkLeadImportScreenState();
}

class _BulkLeadImportScreenState extends ConsumerState<BulkLeadImportScreen> {
  final _csv = TextEditingController();
  bool _importing = false;
  String? _result;

  static const _known = {
    'name', 'buyer_name', 'phone', 'buyer_phone', 'type', 'buyer_type',
    'purpose', 'min_budget', 'max_budget', 'bedrooms', 'property_type', 'status', 'lead_category',
  };
  static const _defaultHeaders = ['name', 'phone', 'type', 'purpose', 'min_budget', 'max_budget', 'property_type', 'status'];

  @override
  void dispose() {
    _csv.dispose();
    super.dispose();
  }

  List<Map<String, String>> _parse(String text) {
    final lines = text.trim().split(RegExp(r'\r?\n')).where((l) => l.trim().isNotEmpty).toList();
    if (lines.isEmpty) return [];
    final firstCells = lines.first.split(',').map((c) => c.trim().toLowerCase()).toList();
    final hasHeader = firstCells.any(_known.contains);
    final headers = hasHeader ? firstCells : _defaultHeaders;
    final dataLines = hasHeader ? lines.skip(1) : lines;
    final out = <Map<String, String>>[];
    for (final line in dataLines) {
      final cells = line.split(',');
      final m = <String, String>{};
      for (var i = 0; i < headers.length && i < cells.length; i++) {
        m[headers[i]] = cells[i].trim();
      }
      if (m.values.any((v) => v.isNotEmpty)) out.add(m);
    }
    return out;
  }

  Future<void> _pickFile() async {
    final res = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['csv', 'txt'], withData: true);
    final bytes = res?.files.single.bytes;
    if (bytes == null) return;
    setState(() => _csv.text = utf8.decode(bytes, allowMalformed: true));
  }

  Future<void> _import() async {
    final rows = _parse(_csv.text);
    if (rows.isEmpty) {
      setState(() => _result = 'No valid rows found. Check the format below.');
      return;
    }
    setState(() { _importing = true; _result = null; });
    try {
      final res = await ref.read(apiClientProvider).post('/buyer-requirements/bulk', body: {'leads': rows});
      final m = res is Map ? res : {};
      final created = m['created'] ?? 0;
      final skipped = m['skipped'] ?? 0;
      ref.invalidate(leadsProvider);
      setState(() => _result = 'Imported $created lead${created == 1 ? '' : 's'}'
          '${(skipped is int && skipped > 0) ? ' · $skipped skipped' : ''}.');
    } catch (e) {
      setState(() => _result = 'Import failed: $e');
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final count = _parse(_csv.text).length;
    return Scaffold(
      appBar: const NuzlAppBar(title: 'Import leads'),
      drawer: const NuzlDrawer(),
      body: ResponsiveCenter(
        child: ListView(padding: const EdgeInsets.all(AppSpacing.x16), children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.x16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Bulk upload leads', style: t.titleMedium),
                const SizedBox(height: 4),
                Text('Paste rows from a spreadsheet or upload a .csv file. Up to 500 leads at a time.',
                    style: t.bodySmall?.copyWith(color: AppColors.textMuted)),
                const SizedBox(height: AppSpacing.x12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.x12),
                  decoration: BoxDecoration(
                    color: AppColors.surface2,
                    borderRadius: BorderRadius.circular(AppSpacing.rMd),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Columns (header row optional)', style: t.labelMedium?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text('name, phone, type, purpose, min_budget, max_budget, property_type, status',
                        style: t.bodySmall?.copyWith(color: AppColors.textMuted, fontFamily: 'monospace')),
                    const SizedBox(height: 6),
                    Text('Example:  Ahmed Ali, +97150…, end_user, sale, 1000000, 1500000, Apartment, potential',
                        style: t.bodySmall?.copyWith(color: AppColors.textSubtle)),
                  ]),
                ),
              ]),
            ),
          ),
          const SizedBox(height: AppSpacing.x12),
          Row(children: [
            OutlinedButton.icon(
              onPressed: _pickFile,
              icon: const Icon(Icons.upload_file, size: 18),
              label: const Text('Upload .csv'),
            ),
            const Spacer(),
            if (count > 0) Text('$count row${count == 1 ? '' : 's'} detected',
                style: t.bodySmall?.copyWith(color: AppColors.success, fontWeight: FontWeight.w600)),
          ]),
          const SizedBox(height: AppSpacing.x8),
          TextField(
            controller: _csv,
            maxLines: 12,
            onChanged: (_) => setState(() {}),
            style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
            decoration: const InputDecoration(
              hintText: 'Paste CSV rows here…',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
          ),
          if (_result != null) ...[
            const SizedBox(height: AppSpacing.x12),
            Container(
              padding: const EdgeInsets.all(AppSpacing.x12),
              decoration: BoxDecoration(
                color: _result!.startsWith('Imported') ? AppColors.success.withValues(alpha: 0.10) : AppColors.danger.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppSpacing.rMd),
              ),
              child: Text(_result!,
                  style: t.bodyMedium?.copyWith(
                      color: _result!.startsWith('Imported') ? AppColors.success : AppColors.danger,
                      fontWeight: FontWeight.w600)),
            ),
          ],
          const SizedBox(height: AppSpacing.x16),
          FilledButton.icon(
            onPressed: _importing || count == 0 ? null : _import,
            icon: _importing
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.cloud_upload_outlined, size: 18),
            label: Text(_importing ? 'Importing…' : 'Import ${count > 0 ? '$count ' : ''}leads'),
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          ),
        ]),
      ),
    );
  }
}
