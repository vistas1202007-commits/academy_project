import 'dart:typed_data';

import 'package:excel/excel.dart' as xl;
import 'package:file_saver/file_saver.dart';

/// One Excel sheet: first row is the header, the rest is data. Values can be
/// int, double or String (null = empty cell).
class ExportSheet {
  final String name;
  final List<List<Object?>> rows;
  const ExportSheet(this.name, this.rows);
}

/// Builds an .xlsx from the sheets and saves it to Downloads. On web it's a browser
/// download, on Android the public Downloads folder. dart:io is not used.
Future<void> saveSheetsAsXlsx(String fileName, List<ExportSheet> sheets) async {
  if (sheets.isEmpty) throw ArgumentError('No sheets to export.');

  final book = xl.Excel.createExcel();
  // Rename the default "Sheet1" to the first sheet's name so no empty sheet is left
  final defaultSheet = book.getDefaultSheet();
  if (defaultSheet != null && defaultSheet != sheets.first.name) {
    book.rename(defaultSheet, sheets.first.name);
  }

  final bold = xl.CellStyle(bold: true);
  for (final s in sheets) {
    final sheet = book[s.name];
    for (final row in s.rows) {
      sheet.appendRow(row.map(_cell).toList());
    }
    if (s.rows.isNotEmpty) {
      for (var c = 0; c < s.rows.first.length; c++) {
        sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 0)).cellStyle = bold;
      }
    }
  }
  book.setDefaultSheet(sheets.first.name);

  final bytes = book.encode();
  if (bytes == null) throw StateError('Could not create the Excel file.');

  await FileSaver.instance.saveToDownloads(
    name: fileName,
    bytes: Uint8List.fromList(bytes),
    fileExtension: 'xlsx',
    mimeType: MimeType.microsoftExcel,
  );
}

xl.CellValue? _cell(Object? v) {
  if (v == null) return null;
  if (v is int) return xl.IntCellValue(v);
  if (v is double) return xl.DoubleCellValue(v);
  return xl.TextCellValue(v.toString());
}
