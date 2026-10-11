import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'at_risk_logic.dart';
import 'brand.dart';
import 'current_user.dart';

enum ReceiptResult { shared, denied, failed }

// Sirf #0B4F55 aur #3EE0A0 ke shades
const PdfColor _primary = PdfColor.fromInt(0xFF0B4F55);
const PdfColor _aurora = PdfColor.fromInt(0xFF3EE0A0);
const PdfColor _primaryTint = PdfColor.fromInt(0xFFEBF1F1); // primary 8%
const PdfColor _primaryLine = PdfColor.fromInt(0xFFCEDCDD); // primary 20%
const PdfColor _muted = PdfColor.fromInt(0xFF5A8589); // primary + safed

final NumberFormat _inr = NumberFormat('#,##,##0', 'en_IN');

/// Default PDF font me ₹ nahi hota, isliye "Rs. 12,000"
String _rs(double v) => 'Rs. ${_inr.format(v.round())}';

String _text(dynamic v) {
  final s = (v ?? '').toString().trim();
  return s.isEmpty ? '-' : s;
}

String receiptNoFor(Map<String, dynamic> data) {
  final no = (data['receiptNo'] ?? '').toString().trim();
  return no.isNotEmpty ? no : 'VIS-R-${(data['traineeId'] ?? '').toString().trim()}';
}

/// A5 fee receipt ke bytes
Future<Uint8List> buildFeeReceiptPdf(Map<String, dynamic> data) async {
  final glyph = pw.MemoryImage((await rootBundle.load(BrandAssets.mountainGlyph)).buffer.asUint8List());
  final wordmark = pw.MemoryImage((await rootBundle.load(BrandAssets.wordmarkDark)).buffer.asUint8List());

  final received = data['feeReceivedDate'];
  final date = received is Timestamp ? received.toDate() : DateTime.now();

  final total = toAmount(data['totalFee']);
  final paid = toAmount(data['feePaid']);
  var pending = data['feePending'] == null ? total - paid : toAmount(data['feePending']);
  if (pending < 0) pending = 0;

  pw.Widget infoRow(String label, String value) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 3),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.SizedBox(width: 90, child: pw.Text(label, style: const pw.TextStyle(fontSize: 9.5, color: _muted))),
            pw.Expanded(child: pw.Text(value, style: const pw.TextStyle(fontSize: 10.5))),
          ],
        ),
      );

  pw.Widget amountRow(String label, String value, {bool bold = false}) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 4),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(label, style: const pw.TextStyle(fontSize: 10.5, color: _primary)),
            pw.Text(
              value,
              style: pw.TextStyle(
                fontSize: 11,
                color: _primary,
                fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
              ),
            ),
          ],
        ),
      );

  final doc = pw.Document(title: 'Fee Receipt ${receiptNoFor(data)}', author: BrandAssets.appName);
  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a5,
      margin: const pw.EdgeInsets.all(28),
      build: (context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Image(glyph, height: 32),
              pw.SizedBox(width: 10),
              pw.Image(wordmark, height: 20),
            ],
          ),
          pw.SizedBox(height: 18),
          pw.Text(
            'Fee Receipt',
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: _primary),
          ),
          pw.SizedBox(height: 6),
          pw.Container(width: 48, height: 3, color: _aurora),
          pw.SizedBox(height: 14),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Receipt No: ${receiptNoFor(data)}', style: const pw.TextStyle(fontSize: 10, color: _muted)),
              pw.Text(
                'Date: ${DateFormat('dd MMM yyyy').format(date)}',
                style: const pw.TextStyle(fontSize: 10, color: _muted),
              ),
            ],
          ),
          pw.SizedBox(height: 10),
          pw.Divider(color: _primaryLine, thickness: 0.8),
          pw.SizedBox(height: 6),
          infoRow('Trainee Name', _text(data['name'])),
          infoRow('Trainee ID', _text(data['traineeId'])),
          infoRow('Course', _text(data['course'])),
          infoRow('Batch', _text(data['batch'])),
          pw.SizedBox(height: 16),
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: pw.BoxDecoration(
              color: _primaryTint,
              border: pw.Border.all(color: _primaryLine, width: 0.8),
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: pw.Column(
              children: [
                amountRow('Total Fee', _rs(total)),
                amountRow('Paid', _rs(paid)),
                pw.Divider(color: _primaryLine, thickness: 0.8, height: 8),
                amountRow('Pending', _rs(pending), bold: pending > 0),
              ],
            ),
          ),
          pw.Spacer(),
          pw.Divider(color: _primaryLine, thickness: 0.8),
          pw.SizedBox(height: 4),
          pw.Center(
            child: pw.Text(
              'Computer generated receipt. Demo data.',
              style: const pw.TextStyle(fontSize: 8.5, color: _muted),
            ),
          ),
        ],
      ),
    ),
  );
  return doc.save();
}

/// Admin check, phir PDF bana ke share (Android) / download (web)
Future<ReceiptResult> shareFeeReceipt(Map<String, dynamic> data) async {
  if (await currentUserRole() != 'admin') return ReceiptResult.denied;
  try {
    final bytes = await buildFeeReceiptPdf(data);
    final id = (data['traineeId'] ?? '').toString().trim();
    await Printing.sharePdf(bytes: bytes, filename: 'Receipt_${id.isEmpty ? 'trainee' : id}.pdf');
    return ReceiptResult.shared;
  } catch (_) {
    return ReceiptResult.failed;
  }
}
