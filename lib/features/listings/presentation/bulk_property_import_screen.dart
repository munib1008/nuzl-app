import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../core/utils/spreadsheet.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/responsive.dart';
import '../../shell/app_shell.dart';
import 'listings_screen.dart' show listingsRawProvider;

/// Bulk property/listing upload — paste CSV or pick a .csv file, preview, import.
class BulkPropertyImportScreen extends ConsumerStatefulWidget {
  const BulkPropertyImportScreen({super.key});
  @override
  ConsumerState<BulkPropertyImportScreen> createState() => _BulkPropertyImportScreenState();
}

class _BulkPropertyImportScreenState extends ConsumerState<BulkPropertyImportScreen> {
  final _csv = TextEditingController();
  bool _importing = false;
  String? _result;
  bool _resultOk = false;

  static const _known = {
    'community', 'community_id', 'building', 'building_name', 'unit', 'unit_no', 'type', 'property_type',
    'purpose', 'price', 'bedrooms', 'bathrooms', 'size_sqft', 'description',
  };
  static const _defaultHeaders = ['community', 'building', 'unit', 'type', 'purpose', 'price', 'bedrooms', 'bathrooms', 'size_sqft', 'description'];

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
    final res = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['csv', 'txt', 'xlsx'], withData: true);
    final file = res?.files.single;
    final bytes = file?.bytes;
    if (bytes == null) return;
    final ext = (file?.extension ?? '').toLowerCase();
    if (ext == 'xlsx') {
      final csv = xlsxBytesToCsv(bytes);
      if (csv.isEmpty) return;
      setState(() => _csv.text = csv);
    } else {
      setState(() => _csv.text = utf8.decode(bytes, allowMalformed: true));
    }
  }

  Future<void> _import() async {
    final rows = _parse(_csv.text);
    if (rows.isEmpty) {
      setState(() { _result = context.tr('No valid rows found. Check the format below.'); _resultOk = false; });
      return;
    }
    setState(() { _importing = true; _result = null; });
    try {
      final res = await ref.read(apiClientProvider).post('/listings/bulk', body: {'properties': rows});
      final m = res is Map ? res : {};
      final created = m['created'] ?? 0;
      final skipped = m['skipped'] ?? 0;
      ref.invalidate(listingsRawProvider);
      setState(() {
        _resultOk = true;
        _result = '${context.tr('Imported')} $created ${context.tr(created == 1 ? 'property' : 'properties')}'
            '${(skipped is int && skipped > 0) ? ' · $skipped ${context.tr('skipped (missing/invalid price or community)')}' : ''}.';
      });
    } catch (e) {
      setState(() { _result = '${context.tr('Import failed')}: $e'; _resultOk = false; });
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final count = _parse(_csv.text).length;
    return Scaffold(
      appBar: NuzlAppBar(title: context.tr('Import properties')),
      drawer: const NuzlDrawer(),
      body: ResponsiveCenter(
        child: ListView(padding: const EdgeInsets.all(AppSpacing.x16), children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.x16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(context.tr('Bulk upload properties'), style: t.titleMedium),
                const SizedBox(height: 4),
                Text(context.tr('Paste rows from a spreadsheet or upload a .csv file. Up to 200 listings at a time. '
                    'Price is required; community is matched by name.'),
                    style: t.bodySmall?.copyWith(color: AppColors.textMuted)),
                const SizedBox(height: AppSpacing.x12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.x12),
                  decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(AppSpacing.rMd)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(context.tr('Columns (header row optional)'), style: t.labelMedium?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text('community, building, unit, type, purpose, price, bedrooms, bathrooms, size_sqft, description',
                        style: t.bodySmall?.copyWith(color: AppColors.textMuted, fontFamily: 'monospace')),
                    const SizedBox(height: 6),
                    Text('${context.tr('Example')}:  Dubai Marina, Marina Heights, 1203, apartment, sale, 1850000, 2, 2, 1100, Sea view',
                        style: t.bodySmall?.copyWith(color: AppColors.textSubtle)),
                  ]),
                ),
              ]),
            ),
          ),
          const SizedBox(height: AppSpacing.x12),
          Row(children: [
            OutlinedButton.icon(onPressed: _pickFile, icon: const Icon(Icons.upload_file, size: 18), label: Text(context.tr('Upload .csv / .xlsx'))),
            const Spacer(),
            if (count > 0) Text('$count ${context.tr(count == 1 ? 'row detected' : 'rows detected')}',
                style: t.bodySmall?.copyWith(color: AppColors.success, fontWeight: FontWeight.w600)),
          ]),
          const SizedBox(height: AppSpacing.x8),
          TextField(
            controller: _csv,
            maxLines: 12,
            onChanged: (_) => setState(() {}),
            style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
            decoration: InputDecoration(hintText: context.tr('Paste CSV rows here…'), border: const OutlineInputBorder(), alignLabelWithHint: true),
          ),
          if (_result != null) ...[
            const SizedBox(height: AppSpacing.x12),
            Container(
              padding: const EdgeInsets.all(AppSpacing.x12),
              decoration: BoxDecoration(
                color: _resultOk ? AppColors.success.withValues(alpha: 0.10) : AppColors.danger.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppSpacing.rMd),
              ),
              child: Text(_result!,
                  style: t.bodyMedium?.copyWith(
                      color: _resultOk ? AppColors.success : AppColors.danger, fontWeight: FontWeight.w600)),
            ),
          ],
          const SizedBox(height: AppSpacing.x16),
          FilledButton.icon(
            onPressed: _importing || count == 0 ? null : _import,
            icon: _importing
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.cloud_upload_outlined, size: 18),
            label: Text(_importing ? context.tr('Importing…') : '${context.tr('Import')} ${count > 0 ? '$count ' : ''}${context.tr('properties')}'),
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          ),
        ]),
      ),
    );
  }
}
