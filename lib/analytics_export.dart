import 'dart:typed_data';

import 'package:excel/excel.dart' as xl;
import 'package:file_saver/file_saver.dart';

/// Excel ki ek sheet: pehli row header, baaki data. Values int, double ya
/// String ho sakti hain (null = khaali cell).
class ExportSheet {
  final String name;
  final List<List<Object?>> rows;
  const ExportSheet(this.name, this.rows);
}

/// Sheets se .xlsx banake Downloads me save karta hai. Web pe browser download
/// hota hai, Android pe public Downloads folder. dart:io use nahi hota.
Future<void> saveSheetsAsXlsx(String fileName, List<ExportSheet> sheets) async {
  if (sheets.isEmpty) throw ArgumentError('Koi sheet nahi hai');

  final book = xl.Excel.createExcel();
  // Default "Sheet1" ko pehli sheet ka naam de do, taaki khaali sheet na bache
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
  if (bytes == null) throw StateError('Excel file ban nahi payi');

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
