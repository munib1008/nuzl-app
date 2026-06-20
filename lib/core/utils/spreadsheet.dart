import 'dart:typed_data';
import 'package:excel/excel.dart' as xlsx;

/// Converts the first worksheet of an .xlsx file into plain CSV text so it can
/// flow through the same paste/preview/import path as a pasted CSV. Commas
/// inside cells are flattened to spaces (the downstream parser splits on ',').
/// Returns '' if the workbook can't be read or has no rows.
String xlsxBytesToCsv(Uint8List bytes) {
  try {
    final book = xlsx.Excel.decodeBytes(bytes);
    if (book.tables.isEmpty) return '';
    final sheet = book.tables[book.tables.keys.first];
    if (sheet == null) return '';
    final lines = <String>[];
    for (final row in sheet.rows) {
      final cells = row.map((c) => _cell(c?.value).replaceAll(',', ' ').trim()).toList();
      if (cells.any((c) => c.isNotEmpty)) lines.add(cells.join(','));
    }
    return lines.join('\n');
  } catch (_) {
    return '';
  }
}

/// Extract a clean string from a typed spreadsheet cell value.
String _cell(xlsx.CellValue? v) => switch (v) {
      null => '',
      xlsx.TextCellValue() => v.value.text ?? '',
      xlsx.IntCellValue() => v.value.toString(),
      xlsx.DoubleCellValue() => v.value.toString(),
      xlsx.BoolCellValue() => v.value.toString(),
      _ => v.toString(),
    };
