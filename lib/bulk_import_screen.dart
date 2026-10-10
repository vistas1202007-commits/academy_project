import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart' as xls;
import 'course_data.dart';
import 'current_user.dart';
import 'app_colors.dart';
import 'responsive.dart';

class BulkImportScreen extends StatefulWidget {
  const BulkImportScreen({super.key});

  @override
  State<BulkImportScreen> createState() => _BulkImportScreenState();
}

class _BulkImportScreenState extends State<BulkImportScreen> {
  // ===================== TRAINEE IMPORT STATE =====================
  String? _traineeFileName;
  bool _isParsingTrainees = false;
  bool _isImportingTrainees = false;
  List<_SheetPreview> _sheetPreviews = [];
  final Map<String, bool> _sheetSelected = {};
  String _defaultTraineeStatus = 'Joined';
  final List<String> _statusOptions = [
    'Registered',
    'Joined',
    'Ongoing',
    'Completed',
    'Dropped',
  ];

  int _traineeProgressDone = 0;
  int _traineeProgressTotal = 0;
  int _traineeImportedCount = 0;
  final List<String> _traineeSkippedLog = [];
  final List<String> _traineeFailedLog = [];
  final List<String> _traineeWarningLog = [];
  bool _traineeImportFinished = false;
  String? _lastTraineeImportSessionId;
  bool _isUndoingTrainees = false;

  // ===================== PLACEMENT IMPORT STATE ====================
  String? _placementFileName;
  bool _isParsingPlacements = false;
  bool _isImportingPlacements = false;
  List<_PlacementRowData> _placementRows = [];
  int _placementProgressDone = 0;
  int _placementProgressTotal = 0;
  int _placementImportedCount = 0;
  int _companiesCreatedCount = 0;
  final List<String> _placementFailedLog = [];
  final List<String> _placementWarningLog = [];
  bool _placementImportFinished = false;
  String? _lastPlacementImportSessionId;
  bool _isUndoingPlacements = false;

  // =================================================================
  //  SHARED HELPERS
  // =================================================================

  String _cellToString(xls.Data? cell) {
    if (cell == null || cell.value == null) return '';
    final v = cell.value;
    // Excel package wraps values in typed classes (TextCellValue,
    // IntCellValue, DoubleCellValue, DateCellValue, etc.) — this
    // mirrors the official package's documented switch pattern.
    if (v is xls.TextCellValue) return v.value.toString().trim();
    if (v is xls.IntCellValue) return v.value.toString();
    if (v is xls.DoubleCellValue) {
      // Avoid "9662789415.0" showing up for phone numbers etc.
      final d = v.value;
      if (d == d.roundToDouble()) return d.toInt().toString();
      return d.toString();
    }
    if (v is xls.DateCellValue) {
      final dt = v.asDateTimeLocal();
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    }
    if (v is xls.DateTimeCellValue) {
      final dt = v.asDateTimeLocal();
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    }
    return v.toString().trim();
  }

  bool _looksNumeric(xls.Data? cell) {
    if (cell == null || cell.value == null) return false;
    final v = cell.value;
    return v is xls.IntCellValue || v is xls.DoubleCellValue;
  }

  /// "BPO-01" -> "BPO", "A.E.-03" -> "A.E.", "GDA-01" -> "GDA"
  String _courseFromBatchLabel(String label) {
    final stripped = label.replaceAll(RegExp(r'-?\s*\d+\s*$'), '').trim();
    // remove a trailing lone dash if the regex above left one
    return stripped.replaceAll(RegExp(r'-\s*$'), '').trim();
  }

  /// Batch label se course: pehle prefix map (ELC-01 -> Electrical), warna label ka prefix hi
  String _courseForBatch(String label) {
    final prefix = label.split('-').first.trim().toUpperCase();
    return kBatchPrefixToCourse[prefix] ?? _courseFromBatchLabel(label);
  }

  /// "M"/"Male" -> Male, "F"/"Female" -> Female, kuch aur ho to jaisa hai waisa
  String _normalizeGender(String raw) {
    final g = raw.trim().toLowerCase();
    if (g == 'm' || g == 'male') return 'Male';
    if (g == 'f' || g == 'female') return 'Female';
    return raw.trim();
  }

  /// Header text ko compare karne layak banata hai: "Fees Received  Amount" -> "feesreceivedamount"
  String _headerKey(String raw) => raw.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

  /// Date cell -> DateTime. Excel date cell, numeric serial (45231) aur
  /// dd/mm/yyyy, dd-mm-yyyy, dd.mm.yyyy text teeno sambhalta hai.
  DateTime? _parseDateCell(xls.Data? cell) {
    if (cell == null || cell.value == null) return null;
    final v = cell.value;
    if (v is xls.DateCellValue) return v.asDateTimeLocal();
    if (v is xls.DateTimeCellValue) return v.asDateTimeLocal();
    if (v is xls.IntCellValue || v is xls.DoubleCellValue) {
      final serial = v is xls.IntCellValue ? v.value.toDouble() : (v as xls.DoubleCellValue).value;
      if (serial < 1 || serial > 100000) return null;
      return DateTime(1899, 12, 30).add(Duration(days: serial.floor()));
    }
    final parts = _cellToString(cell).split(RegExp(r'[/.\-]'));
    if (parts.length != 3) return null;
    final d = int.tryParse(parts[0].trim());
    final m = int.tryParse(parts[1].trim());
    var y = int.tryParse(parts[2].trim());
    if (d == null || m == null || y == null) return null;
    if (y < 100) y += (y <= DateTime.now().year % 100) ? 2000 : 1900;
    if (m < 1 || m > 12 || d < 1 || d > 31) return null;
    return DateTime(y, m, d);
  }

  /// "₹ 1,500" -> 1500
  double? _parseAmount(String raw) {
    final cleaned = raw.replaceAll(RegExp(r'[^0-9.]'), '');
    return cleaned.isEmpty ? null : double.tryParse(cleaned);
  }

  /// Normalizes messy spacing around dashes: "BPO - 03" / "BPO -01" -> "BPO-03"/"BPO-01"
  String _normalizeBatchLabel(String raw) {
    String label = raw.trim();
    label = label.replaceAll(RegExp(r'\s*-\s*'), '-');
    label = label.replaceAll(RegExp(r'\s+'), ' ').trim();
    return label;
  }

  /// Turns a raw exception (often a low-level Firestore/plugin error) into a
  /// short, client-friendly message instead of showing the raw stack text.
  String _friendlyError(Object e) {
    final msg = e.toString().toLowerCase();
    if (msg.contains('unavailable') || msg.contains('network')) {
      return 'Network/server issue — please retry the import.';
    }
    if (msg.contains('permission-denied')) {
      return 'Permission denied — please check your account access.';
    }
    if (msg.contains('deadline-exceeded') || msg.contains('timeout')) {
      return 'Request timed out — please retry the import.';
    }
    return 'Could not save this record — please retry the import.';
  }

  /// Generates a unique tag for one import run, so it can be found and
  /// undone later without touching any other data.
  String _newImportSessionId() => DateTime.now().millisecondsSinceEpoch.toString();

  Future<Map<String, Timestamp?>> _fetchBatchStartDates() async {
    final snap = await FirebaseFirestore.instance.collection('batches').get();
    final map = <String, Timestamp?>{};
    for (final doc in snap.docs) {
      final data = doc.data();
      final name = (data['batchName'] ?? '').toString().trim();
      if (name.isEmpty) continue;
      map[name] = data['startDate'] is Timestamp ? data['startDate'] as Timestamp : null;
    }
    return map;
  }

  Future<Set<String>> _fetchExistingStudentPhones() async {
    final snap = await FirebaseFirestore.instance.collection('students').get();
    return snap.docs
        .map((d) => (d.data()['phone'] ?? '').toString().trim())
        .where((p) => p.isNotEmpty)
        .toSet();
  }

  /// phone -> traineeId, used to link placement records back to trainees
  Future<Map<String, String>> _fetchPhoneToTraineeId() async {
    final snap = await FirebaseFirestore.instance.collection('students').get();
    final map = <String, String>{};
    for (final doc in snap.docs) {
      final data = doc.data();
      final phone = (data['phone'] ?? '').toString().trim();
      final traineeId = (data['traineeId'] ?? '').toString().trim();
      if (phone.isNotEmpty && traineeId.isNotEmpty) {
        map[phone] = traineeId;
      }
    }
    return map;
  }

  Future<Map<String, String>> _fetchCompanyNameToId() async {
    final snap = await FirebaseFirestore.instance.collection('companies').get();
    final map = <String, String>{};
    for (final doc in snap.docs) {
      final name = (doc.data()['companyName'] ?? '').toString().trim().toLowerCase();
      if (name.isNotEmpty) map[name] = doc.id;
    }
    return map;
  }

  Future<String> _generateTraineeId() async {
    // Reused as-is from add_student_screen.dart — do not change this logic,
    // it guarantees unique sequential IDs via a Firestore transaction.
    final year = DateTime.now().year;
    final counterRef =
    FirebaseFirestore.instance.collection('counters').doc('traineeId_$year');

    final newNumber = await FirebaseFirestore.instance.runTransaction<int>((transaction) async {
      final snapshot = await transaction.get(counterRef);
      int currentCount = 0;
      if (snapshot.exists) {
        final data = snapshot.data() as Map<String, dynamic>;
        currentCount = (data['count'] ?? 0) as int;
      }
      final nextCount = currentCount + 1;
      transaction.set(counterRef, {
        'count': nextCount,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return nextCount;
    });

    final paddedNumber = newNumber.toString().padLeft(4, '0');
    return 'VIS-$year-$paddedNumber';
  }

  // =================================================================
  //  TRAINEE IMPORT — pick + parse
  // =================================================================

  Future<void> _pickTraineeFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
      withData: true,
    );
    if (result == null || result.files.single.bytes == null) return;

    setState(() {
      _isParsingTrainees = true;
      _traineeFileName = result.files.single.name;
      _sheetPreviews = [];
      _sheetSelected.clear();
      _traineeImportFinished = false;
      _traineeSkippedLog.clear();
      _traineeFailedLog.clear();
      _traineeWarningLog.clear();
      _traineeImportedCount = 0;
      _lastTraineeImportSessionId = null;
    });

    try {
      final bytes = result.files.single.bytes!;
      final previews = _parseTraineeWorkbook(bytes);
      setState(() {
        _sheetPreviews = previews;
        for (final p in previews) {
          _sheetSelected[p.sheetName] = true;
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not read the file. Please make sure it is a valid .xlsx file.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isParsingTrainees = false);
    }
  }

  List<_SheetPreview> _parseTraineeWorkbook(Uint8List bytes) {
    final workbook = xls.Excel.decodeBytes(bytes);
    final previews = <_SheetPreview>[];

    for (final sheetName in workbook.tables.keys) {
      final sheet = workbook.tables[sheetName]!;
      final rows = sheet.rows;
      if (rows.length < 3) continue; // no data rows at all

      // Row index 0 = title, index 1 = header, index 2+ = data.
      // Columns A-I fixed: Sr No, Gender, Name, Batch, DOB, Village, Tehsil,
      // Contact, Emergency. Fees wale columns header ke naam se dhoondhe jaate hain.
      final headerCols = <String, int>{};
      final headerRow = rows[1];
      for (int c = 0; c < headerRow.length; c++) {
        final key = _headerKey(_cellToString(headerRow[c]));
        if (key.isNotEmpty) headerCols.putIfAbsent(key, () => c);
      }
      final feesAmountCol = headerCols['feesreceivedamount'];
      final receiptNoCol = headerCols['receiptno'];
      final feesDateCol = headerCols['feesreceiveddate'];
      final totalFeeCol = headerCols['totalfee'];
      final statusCol = headerCols['status'];

      final dataRows = <_TraineeRowData>[];
      for (int r = 2; r < rows.length; r++) {
        final row = rows[r];
        if (row.isEmpty) continue;

        xls.Data? cellAt(int? i) => (i != null && i < row.length) ? row[i] : null;
        String text(int? i) => _cellToString(cellAt(i));

        final name = text(2);
        if (name.isEmpty) continue; // trailing empty row — skip

        final batchFromCell = _normalizeBatchLabel(text(3));
        final batch = batchFromCell.isNotEmpty ? batchFromCell : sheetName.trim();

        dataRows.add(_TraineeRowData(
          name: name,
          gender: _normalizeGender(text(1)),
          batch: batch,
          course: _courseForBatch(batch),
          dob: _parseDateCell(cellAt(4)),
          village: text(5),
          tehsil: text(6),
          phone: text(7),
          guardianPhone: text(8),
          feePaid: _parseAmount(text(feesAmountCol)),
          receiptNo: text(receiptNoCol),
          feeReceivedDate: _parseDateCell(cellAt(feesDateCol)),
          totalFee: _parseAmount(text(totalFeeCol)),
          status: text(statusCol),
        ));
      }

      if (dataRows.isNotEmpty) {
        previews.add(_SheetPreview(sheetName: sheetName.trim(), rows: dataRows));
      }
    }
    return previews;
  }

  // =================================================================
  //  TRAINEE IMPORT — actually write to Firestore
  // =================================================================

  Future<void> _importSelectedTrainees() async {
    final selectedSheets =
    _sheetPreviews.where((p) => _sheetSelected[p.sheetName] == true).toList();
    if (selectedSheets.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one sheet.')),
      );
      return;
    }

    final sessionId = _newImportSessionId();

    setState(() {
      _isImportingTrainees = true;
      _traineeImportFinished = false;
      _traineeImportedCount = 0;
      _traineeProgressDone = 0;
      _traineeSkippedLog.clear();
      _traineeFailedLog.clear();
      _traineeWarningLog.clear();
      _lastTraineeImportSessionId = null;
    });

    final batchStartDates = await _fetchBatchStartDates();
    final existingPhones = await _fetchExistingStudentPhones();
    final stamp = await creatorStamp();
    final seenPhonesThisRun = <String>{};
    final warnedBatches = <String>{};

    final allRows = <_TraineeRowData>[];
    for (final s in selectedSheets) {
      allRows.addAll(s.rows);
    }

    setState(() => _traineeProgressTotal = allRows.length);

    WriteBatch batch = FirebaseFirestore.instance.batch();
    int opsInBatch = 0;
    const maxOpsPerBatch = 450;

    Future<void> commitIfNeeded({bool force = false}) async {
      if (opsInBatch >= maxOpsPerBatch || (force && opsInBatch > 0)) {
        await batch.commit();
        batch = FirebaseFirestore.instance.batch();
        opsInBatch = 0;
      }
    }

    for (final row in allRows) {
      // ---- duplicate check (by phone) ----
      final phoneKey = row.phone.trim();
      if (phoneKey.isNotEmpty &&
          (existingPhones.contains(phoneKey) || seenPhonesThisRun.contains(phoneKey))) {
        _traineeSkippedLog.add('${row.name} (${row.batch}) — duplicate phone number $phoneKey');
        setState(() => _traineeProgressDone++);
        continue;
      }

      // ---- batch existence check (warning only, still imports) — har batch ka ek hi warning ----
      if (!batchStartDates.containsKey(row.batch) && warnedBatches.add(row.batch)) {
        _traineeWarningLog.add(
            "Batch '${row.batch}' was not found in the system — the trainee was still imported and the batch name was saved as text, but trainer filtering by batch will not work for this record until the batch is created.");
      }

      final admissionTimestamp = batchStartDates[row.batch] ?? Timestamp.fromDate(DateTime.now());

      // Sheet ka Status valid ho to wahi, warna dropdown wala default
      final rowStatus = _statusOptions.firstWhere(
        (s) => s.toLowerCase() == row.status.trim().toLowerCase(),
        orElse: () => _defaultTraineeStatus,
      );
      final totalFee = row.totalFee ?? 0;
      final feePaid = row.feePaid ?? 0;
      final feePending = totalFee - feePaid;

      try {
        final traineeId = await _generateTraineeId();
        final docRef = FirebaseFirestore.instance.collection('students').doc();
        batch.set(docRef, {
          'traineeId': traineeId,
          'name': row.name,
          'phone': row.phone,
          'email': '',
          'gender': row.gender,
          'dob': row.dob != null ? Timestamp.fromDate(row.dob!) : null,
          'village': row.village,
          'tehsil': row.tehsil,
          'guardianName': '',
          'guardianPhone': row.guardianPhone,
          'course': row.course,
          'batch': row.batch,
          'admissionDate': admissionTimestamp,
          'status': rowStatus,
          'totalFee': totalFee,
          'feePaid': feePaid,
          'feePending': feePending < 0 ? 0 : feePending,
          'receiptNo': row.receiptNo,
          'feeReceivedDate':
              row.feeReceivedDate != null ? Timestamp.fromDate(row.feeReceivedDate!) : null,
          'importSessionId': sessionId,
          ...stamp,
          'createdAt': FieldValue.serverTimestamp(),
        });
        opsInBatch++;
        _traineeImportedCount++;
        if (phoneKey.isNotEmpty) seenPhonesThisRun.add(phoneKey);
        await commitIfNeeded();
      } catch (e) {
        _traineeFailedLog.add('${row.name} (${row.batch}) — ${_friendlyError(e)}');
      }

      setState(() => _traineeProgressDone++);
    }

    await commitIfNeeded(force: true);

    setState(() {
      _isImportingTrainees = false;
      _traineeImportFinished = true;
      _lastTraineeImportSessionId = _traineeImportedCount > 0 ? sessionId : null;
    });
  }

  // =================================================================
  //  TRAINEE IMPORT — undo
  // =================================================================

  Future<void> _undoTraineeImport() async {
    final sessionId = _lastTraineeImportSessionId;
    if (sessionId == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Undo This Import?'),
        content: Text(
          'This will permanently delete all $_traineeImportedCount trainee record(s) added in this import. '
              'This action cannot be undone. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancel', style: TextStyle(color: Colors.grey[700])),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[700],
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Undo Import', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _isUndoingTrainees = true);

    try {
      final snap = await FirebaseFirestore.instance
          .collection('students')
          .where('importSessionId', isEqualTo: sessionId)
          .get();

      WriteBatch batch = FirebaseFirestore.instance.batch();
      int opsInBatch = 0;
      const maxOpsPerBatch = 450;

      for (final doc in snap.docs) {
        batch.delete(doc.reference);
        opsInBatch++;
        if (opsInBatch >= maxOpsPerBatch) {
          await batch.commit();
          batch = FirebaseFirestore.instance.batch();
          opsInBatch = 0;
        }
      }
      if (opsInBatch > 0) await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${snap.docs.length} trainee record(s) removed.'),
            backgroundColor: AppColors.appPrimary,
          ),
        );
        setState(() {
          _lastTraineeImportSessionId = null;
          _traineeImportFinished = false;
          _sheetPreviews = [];
          _traineeFileName = null;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_friendlyError(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _isUndoingTrainees = false);
    }
  }

  // =================================================================
  //  PLACEMENT IMPORT — pick + parse
  // =================================================================

  Future<void> _pickPlacementFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
      withData: true,
    );
    if (result == null || result.files.single.bytes == null) return;

    setState(() {
      _isParsingPlacements = true;
      _placementFileName = result.files.single.name;
      _placementRows = [];
      _placementImportFinished = false;
      _placementFailedLog.clear();
      _placementWarningLog.clear();
      _placementImportedCount = 0;
      _companiesCreatedCount = 0;
      _lastPlacementImportSessionId = null;
    });

    try {
      final bytes = result.files.single.bytes!;
      final rows = _parsePlacementWorkbook(bytes);
      setState(() => _placementRows = rows);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not read the file. Please make sure it is a valid .xlsx file.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isParsingPlacements = false);
    }
  }

  List<_PlacementRowData> _parsePlacementWorkbook(Uint8List bytes) {
    final workbook = xls.Excel.decodeBytes(bytes);

    xls.Sheet? sheet;
    for (final name in workbook.tables.keys) {
      if (name.toLowerCase().contains('trainees details')) {
        sheet = workbook.tables[name];
        break;
      }
    }
    sheet ??= workbook.tables.values.first;

    final rows = sheet.rows;
    final result = <_PlacementRowData>[];
    String? currentBatch;
    String? currentCourse;

    // Row 0 = header row. Data / group-title rows start at index 1.
    for (int r = 1; r < rows.length; r++) {
      final row = rows[r];
      if (row.isEmpty) continue;

      final col0 = row.isNotEmpty ? row[0] : null;
      final col1 = row.length > 1 ? row[1] : null;
      final srNoIsNumeric = _looksNumeric(col0);
      final col0Text = _cellToString(col0);

      if (!srNoIsNumeric && col0Text.isNotEmpty && (col1 == null || _cellToString(col1).isEmpty)) {
        // This is a "BPO -01 Placement Details (...)" group-title row.
        final idx = col0Text.toLowerCase().indexOf('placement details');
        final label = idx >= 0 ? col0Text.substring(0, idx).trim() : col0Text.trim();
        currentBatch = _normalizeBatchLabel(label);
        currentCourse = _courseFromBatchLabel(currentBatch);
        continue;
      }

      if (!srNoIsNumeric) continue; // blank / junk row
      final name = _cellToString(col1);
      if (name.isEmpty) continue; // trailing empty row

      String cell(int i) => row.length > i ? _cellToString(row[i]) : '';

      result.add(_PlacementRowData(
        name: name,
        phone: cell(3),
        placementStatusRaw: cell(6),
        salariedOrSelfEmployed: cell(7),
        doj: cell(8),
        companyName: cell(9),
        contactPersonName: cell(10),
        contactPersonPhone: cell(12),
        jobLocation: cell(13),
        salary: cell(15),
        foodProvided: cell(16),
        batch: currentBatch ?? 'UNKNOWN',
        course: currentCourse ?? '',
      ));
    }

    return result;
  }

  String _mapPlacementStatus(_PlacementRowData row) {
    final isSelfEmployed = row.salariedOrSelfEmployed.toLowerCase().contains('self');
    if (isSelfEmployed) return 'Self-Employed';
    if (row.placementStatusRaw.trim().toLowerCase() == 'no') return 'Not Placed';
    if (row.placementStatusRaw.trim().toLowerCase() == 'yes') {
      return row.doj.trim().isNotEmpty ? 'Joined' : 'Selected';
    }
    return 'Not Placed';
  }

  String _mapEmploymentType(_PlacementRowData row) {
    if (row.salariedOrSelfEmployed.toLowerCase().contains('self')) return 'Self-employed';
    return 'Salaried'; // combined "Salaried or Waged" defaults to Salaried
  }

  Timestamp? _tryParseDojTimestamp(String doj) {
    if (doj.trim().isEmpty) return null;
    // Handles "26/11/2025" (dd/mm/yyyy) format seen in the source file.
    final parts = doj.trim().split('/');
    if (parts.length == 3) {
      final d = int.tryParse(parts[0]);
      final m = int.tryParse(parts[1]);
      final y = int.tryParse(parts[2]);
      if (d != null && m != null && y != null) {
        try {
          return Timestamp.fromDate(DateTime(y, m, d));
        } catch (_) {
          return null;
        }
      }
    }
    return null;
  }

  // =================================================================
  //  PLACEMENT IMPORT — actually write to Firestore
  // =================================================================

  Future<void> _importPlacements() async {
    if (_placementRows.isEmpty) return;

    final sessionId = _newImportSessionId();

    setState(() {
      _isImportingPlacements = true;
      _placementImportFinished = false;
      _placementImportedCount = 0;
      _companiesCreatedCount = 0;
      _placementProgressDone = 0;
      _placementProgressTotal = _placementRows.length;
      _placementFailedLog.clear();
      _placementWarningLog.clear();
      _lastPlacementImportSessionId = null;
    });

    final phoneToTraineeId = await _fetchPhoneToTraineeId();
    final companyNameToId = await _fetchCompanyNameToId();
    final stamp = await creatorStamp();

    WriteBatch batch = FirebaseFirestore.instance.batch();
    int opsInBatch = 0;
    const maxOpsPerBatch = 450;

    Future<void> commitIfNeeded({bool force = false}) async {
      if (opsInBatch >= maxOpsPerBatch || (force && opsInBatch > 0)) {
        await batch.commit();
        batch = FirebaseFirestore.instance.batch();
        opsInBatch = 0;
      }
    }

    for (final row in _placementRows) {
      try {
        // ---- auto-create company if it doesn't exist yet ----
        // Only newly created companies are tagged with this session's ID —
        // an existing company that already had records is left untouched,
        // so undoing this import will never delete a pre-existing company.
        final key = row.companyName.trim().toLowerCase();
        if (key.isNotEmpty && !companyNameToId.containsKey(key)) {
          final companyRef = FirebaseFirestore.instance.collection('companies').doc();
          batch.set(companyRef, {
            'companyName': row.companyName.trim(),
            'contactPerson': row.contactPersonName,
            'contactNumber': row.contactPersonPhone,
            'location': row.jobLocation,
            'importSessionId': sessionId,
            ...stamp,
            'createdAt': FieldValue.serverTimestamp(),
          });
          companyNameToId[key] = companyRef.id; // avoid creating it twice
          opsInBatch++;
          _companiesCreatedCount++;
        }

        // ---- link to trainee by phone (best effort) ----
        final traineeId = phoneToTraineeId[row.phone.trim()] ?? '';
        if (traineeId.isEmpty) {
          _placementWarningLog.add(
              '${row.name} (${row.phone}) — no matching trainee record found; placement was saved without a linked trainee ID.');
        }

        final placementRef = FirebaseFirestore.instance.collection('placements').doc();
        batch.set(placementRef, {
          'studentName': row.name,
          'traineeId': traineeId,
          'course': row.course,
          'contactPersonName': row.contactPersonName,
          'jobLocation': row.jobLocation,
          'jobPost': '',
          'salary': row.salary,
          'foodProvided': row.foodProvided.isNotEmpty ? row.foodProvided : 'No',
          'companyName': row.companyName,
          'joiningDate': _tryParseDojTimestamp(row.doj),
          'employmentType': _mapEmploymentType(row),
          'status': _mapPlacementStatus(row),
          'importSessionId': sessionId,
          ...stamp,
          'createdAt': FieldValue.serverTimestamp(),
        });
        opsInBatch++;
        _placementImportedCount++;
        await commitIfNeeded();
      } catch (e) {
        _placementFailedLog.add('${row.name} — ${_friendlyError(e)}');
      }

      setState(() => _placementProgressDone++);
    }

    await commitIfNeeded(force: true);

    setState(() {
      _isImportingPlacements = false;
      _placementImportFinished = true;
      _lastPlacementImportSessionId = _placementImportedCount > 0 ? sessionId : null;
    });
  }

  // =================================================================
  //  PLACEMENT IMPORT — undo
  // =================================================================

  Future<void> _undoPlacementImport() async {
    final sessionId = _lastPlacementImportSessionId;
    if (sessionId == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Undo This Import?'),
        content: Text(
          'This will permanently delete all $_placementImportedCount placement record(s) and '
              '$_companiesCreatedCount newly created compan${_companiesCreatedCount == 1 ? 'y' : 'ies'} added in this import. '
              'This action cannot be undone. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancel', style: TextStyle(color: Colors.grey[700])),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[700],
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Undo Import', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _isUndoingPlacements = true);

    try {
      final placementSnap = await FirebaseFirestore.instance
          .collection('placements')
          .where('importSessionId', isEqualTo: sessionId)
          .get();
      final companySnap = await FirebaseFirestore.instance
          .collection('companies')
          .where('importSessionId', isEqualTo: sessionId)
          .get();

      WriteBatch batch = FirebaseFirestore.instance.batch();
      int opsInBatch = 0;
      const maxOpsPerBatch = 450;

      Future<void> addDelete(DocumentReference ref) async {
        batch.delete(ref);
        opsInBatch++;
        if (opsInBatch >= maxOpsPerBatch) {
          await batch.commit();
          batch = FirebaseFirestore.instance.batch();
          opsInBatch = 0;
        }
      }

      for (final doc in placementSnap.docs) {
        await addDelete(doc.reference);
      }
      for (final doc in companySnap.docs) {
        await addDelete(doc.reference);
      }
      if (opsInBatch > 0) await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${placementSnap.docs.length} placement record(s) and ${companySnap.docs.length} '
                  'compan${companySnap.docs.length == 1 ? 'y' : 'ies'} removed.',
            ),
            backgroundColor: AppColors.appPrimary,
          ),
        );
        setState(() {
          _lastPlacementImportSessionId = null;
          _placementImportFinished = false;
          _placementRows = [];
          _placementFileName = null;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_friendlyError(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _isUndoingPlacements = false);
    }
  }

  // =================================================================
  //  UI
  // =================================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.appBackground,
      appBar: AppBar(
        backgroundColor: AppColors.appPrimary,
        elevation: 0,
        title: const Text('Bulk Import'),
      ),
      body: ContentWidth(maxWidth: 1100, child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _sectionCard(
            title: 'Import Trainees',
            subtitle: 'Enrollment & Fees Excel — row 1 title, row 2 header, data from row 3. Batch from column D (sheet name if empty).',
            child: _buildTraineeSection(),
          ),
          const SizedBox(height: 20),
          _sectionCard(
            title: 'Import Placement Records',
            subtitle: 'From the Placement Excel — "Trainees Details" sheet.',
            child: _buildPlacementSection(),
          ),
        ],
      )),
    );
  }

  Widget _sectionCard({required String title, required String subtitle, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.appPrimary)),
          const SizedBox(height: 4),
          Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  // ---------------- Trainee section UI ----------------

  Widget _buildTraineeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ElevatedButton.icon(
          onPressed: _isParsingTrainees || _isImportingTrainees ? null : _pickTraineeFile,
          icon: const Icon(Icons.upload_file, color: Colors.white),
          label: Text(_traineeFileName == null ? 'Select Enrollment File (.xlsx)' : 'Change File',
              style: const TextStyle(color: Colors.white)),
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.appPrimary),
        ),
        if (_traineeFileName != null) ...[
          const SizedBox(height: 8),
          Text('File: $_traineeFileName', style: const TextStyle(fontSize: 12)),
        ],
        if (_isParsingTrainees) ...[
          const SizedBox(height: 12),
          const LinearProgressIndicator(color: AppColors.appPrimary),
        ],
        if (_sheetPreviews.isNotEmpty && !_isImportingTrainees && !_traineeImportFinished) ...[
          const SizedBox(height: 16),
          Text('${_sheetPreviews.length} sheets found:',
              style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          ..._sheetPreviews.map((p) => CheckboxListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            activeColor: AppColors.appPrimary,
            value: _sheetSelected[p.sheetName] ?? true,
            onChanged: (v) => setState(() => _sheetSelected[p.sheetName] = v ?? true),
            title: Text('${p.sheetName}  (${p.rows.length} rows)',
                style: const TextStyle(fontSize: 13)),
          )),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _defaultTraineeStatus,
            decoration: const InputDecoration(
              labelText: 'Default status (if sheet has no valid Status)',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            items: _statusOptions.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
            onChanged: (v) => setState(() => _defaultTraineeStatus = v ?? 'Joined'),
          ),
          const SizedBox(height: 14),
          ElevatedButton(
            onPressed: _importSelectedTrainees,
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.appAccent),
            child: const Text('Import Selected', style: TextStyle(color: Colors.black87)),
          ),
        ],
        if (_isImportingTrainees) ...[
          const SizedBox(height: 16),
          LinearProgressIndicator(
            color: AppColors.appPrimary,
            value: _traineeProgressTotal == 0 ? null : _traineeProgressDone / _traineeProgressTotal,
          ),
          const SizedBox(height: 6),
          Text('Importing $_traineeProgressDone/$_traineeProgressTotal...',
              style: const TextStyle(fontSize: 12)),
        ],
        if (_traineeImportFinished) _buildTraineeSummary(),
      ],
    );
  }

  Widget _buildTraineeSummary() {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppColors.appPrimary.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(10)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$_traineeImportedCount imported successfully, '
                '${_traineeSkippedLog.length} skipped (duplicates), '
                '${_traineeFailedLog.length} failed.',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          if (_traineeWarningLog.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('${_traineeWarningLog.length} warning(s):',
                style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.orange)),
            ..._traineeWarningLog.take(20).map((w) => Text('• $w', style: const TextStyle(fontSize: 11))),
          ],
          if (_traineeSkippedLog.isNotEmpty) ...[
            const SizedBox(height: 8),
            const Text('Skipped:', style: TextStyle(fontWeight: FontWeight.w600)),
            ..._traineeSkippedLog.take(20).map((s) => Text('• $s', style: const TextStyle(fontSize: 11))),
          ],
          if (_traineeFailedLog.isNotEmpty) ...[
            const SizedBox(height: 8),
            const Text('Failed:', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.red)),
            ..._traineeFailedLog.take(20).map((s) => Text('• $s', style: const TextStyle(fontSize: 11))),
          ],
          if (_lastTraineeImportSessionId != null) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: OutlinedButton.icon(
                onPressed: _isUndoingTrainees ? null : _undoTraineeImport,
                icon: _isUndoingTrainees
                    ? SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.red[700]),
                )
                    : Icon(Icons.undo, color: Colors.red[700]),
                label: Text(
                  _isUndoingTrainees ? 'Undoing...' : 'Undo This Import',
                  style: TextStyle(color: Colors.red[700]),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Colors.red[700]!),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ---------------- Placement section UI ----------------

  Widget _buildPlacementSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ElevatedButton.icon(
          onPressed: _isParsingPlacements || _isImportingPlacements ? null : _pickPlacementFile,
          icon: const Icon(Icons.upload_file, color: Colors.white),
          label: Text(_placementFileName == null ? 'Select Placement File (.xlsx)' : 'Change File',
              style: const TextStyle(color: Colors.white)),
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.appPrimary),
        ),
        if (_placementFileName != null) ...[
          const SizedBox(height: 8),
          Text('File: $_placementFileName', style: const TextStyle(fontSize: 12)),
        ],
        if (_isParsingPlacements) ...[
          const SizedBox(height: 12),
          const LinearProgressIndicator(color: AppColors.appPrimary),
        ],
        if (_placementRows.isNotEmpty && !_isImportingPlacements && !_placementImportFinished) ...[
          const SizedBox(height: 16),
          Text('${_placementRows.length} placement records found.',
              style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 14),
          ElevatedButton(
            onPressed: _importPlacements,
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.appAccent),
            child: const Text('Import Placement Records', style: TextStyle(color: Colors.black87)),
          ),
        ],
        if (_isImportingPlacements) ...[
          const SizedBox(height: 16),
          LinearProgressIndicator(
            color: AppColors.appPrimary,
            value: _placementProgressTotal == 0 ? null : _placementProgressDone / _placementProgressTotal,
          ),
          const SizedBox(height: 6),
          Text('Importing $_placementProgressDone/$_placementProgressTotal...',
              style: const TextStyle(fontSize: 12)),
        ],
        if (_placementImportFinished) _buildPlacementSummary(),
      ],
    );
  }

  Widget _buildPlacementSummary() {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppColors.appPrimary.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(10)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$_placementImportedCount placement records imported, '
                '$_companiesCreatedCount new companies created, '
                '${_placementFailedLog.length} failed.',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          if (_placementWarningLog.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('${_placementWarningLog.length} warning(s):',
                style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.orange)),
            ..._placementWarningLog.take(20).map((w) => Text('• $w', style: const TextStyle(fontSize: 11))),
          ],
          if (_placementFailedLog.isNotEmpty) ...[
            const SizedBox(height: 8),
            const Text('Failed:', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.red)),
            ..._placementFailedLog.take(20).map((s) => Text('• $s', style: const TextStyle(fontSize: 11))),
          ],
          if (_lastPlacementImportSessionId != null) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: OutlinedButton.icon(
                onPressed: _isUndoingPlacements ? null : _undoPlacementImport,
                icon: _isUndoingPlacements
                    ? SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.red[700]),
                )
                    : Icon(Icons.undo, color: Colors.red[700]),
                label: Text(
                  _isUndoingPlacements ? 'Undoing...' : 'Undo This Import',
                  style: TextStyle(color: Colors.red[700]),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Colors.red[700]!),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// =====================================================================
//  Small data holder classes
// =====================================================================

class _SheetPreview {
  final String sheetName;
  final List<_TraineeRowData> rows;
  _SheetPreview({required this.sheetName, required this.rows});
}

class _TraineeRowData {
  final String name;
  final String gender;
  final String phone;
  final String guardianPhone;
  final String batch;
  final String course;
  final DateTime? dob;
  final String village;
  final String tehsil;
  final double? feePaid;
  final String receiptNo;
  final DateTime? feeReceivedDate;
  final double? totalFee;
  final String status;
  _TraineeRowData({
    required this.name,
    required this.gender,
    required this.phone,
    required this.guardianPhone,
    required this.batch,
    required this.course,
    required this.dob,
    required this.village,
    required this.tehsil,
    required this.feePaid,
    required this.receiptNo,
    required this.feeReceivedDate,
    required this.totalFee,
    required this.status,
  });
}

class _PlacementRowData {
  final String name;
  final String phone;
  final String placementStatusRaw;
  final String salariedOrSelfEmployed;
  final String doj;
  final String companyName;
  final String contactPersonName;
  final String contactPersonPhone;
  final String jobLocation;
  final String salary;
  final String foodProvided;
  final String batch;
  final String course;

  _PlacementRowData({
    required this.name,
    required this.phone,
    required this.placementStatusRaw,
    required this.salariedOrSelfEmployed,
    required this.doj,
    required this.companyName,
    required this.contactPersonName,
    required this.contactPersonPhone,
    required this.jobLocation,
    required this.salary,
    required this.foodProvided,
    required this.batch,
    required this.course,
  });
}