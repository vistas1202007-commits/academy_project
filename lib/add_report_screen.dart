import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:pdfx/pdfx.dart';

class AddReportScreen extends StatefulWidget {
  final String currentUserRole;
  final String? reportId; // null = creating a new report
  final Map<String, dynamic>? currentData; // provided only when editing

  const AddReportScreen({
    super.key,
    required this.currentUserRole,
    this.reportId,
    this.currentData,
  });

  @override
  State<AddReportScreen> createState() => _AddReportScreenState();
}

// A file the user picked but which is not uploaded yet
class _PendingAttachment {
  final File file;
  final String name;
  final String type; // 'pdf' or 'image'
  final int pageCount; // 0 for images

  _PendingAttachment({
    required this.file,
    required this.name,
    required this.type,
    required this.pageCount,
  });
}

class _AddReportScreenState extends State<AddReportScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  DateTime _reportDate = DateTime.now();
  bool _isSaving = false;
  bool _isPicking = false;
  String _errorMessage = '';

  static const Color primaryGreen = Color(0xFF1B6B4A);
  static const int _maxTotalPdfPages = 10;

  // Already-saved attachments (only filled when editing)
  List<Map<String, dynamic>> _existingAttachments = [];

  // Attachments removed by the admin during this edit (deleted from Storage after save)
  final List<Map<String, dynamic>> _removedExistingAttachments = [];

  // Newly picked files, not uploaded yet
  final List<_PendingAttachment> _pendingAttachments = [];

  bool get _isEditing => widget.reportId != null;

  // Total pages of all PDFs (saved + newly picked). Images are not counted.
  int get _totalPdfPagesUsed {
    final existingPages = _existingAttachments
        .where((a) => a['type'] == 'pdf')
        .fold<int>(0, (sum, a) => sum + ((a['pageCount'] ?? 0) as int));
    final pendingPages = _pendingAttachments
        .where((a) => a.type == 'pdf')
        .fold<int>(0, (sum, a) => sum + a.pageCount);
    return existingPages + pendingPages;
  }

  @override
  void initState() {
    super.initState();
    final data = widget.currentData;
    _titleController = TextEditingController(text: data?['title'] ?? '');
    _descriptionController = TextEditingController(text: data?['description'] ?? '');
    if (data?['reportDate'] != null) {
      _reportDate = (data!['reportDate'] as Timestamp).toDate();
    }
    final rawAttachments = data?['attachments'];
    if (rawAttachments is List) {
      _existingAttachments =
          rawAttachments.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
  }

  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red[700] : primaryGreen,
      ),
    );
  }

  Future<void> _pickReportDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _reportDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(primary: primaryGreen),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _reportDate = picked);
    }
  }

  Future<void> _pickAttachments() async {
    setState(() => _isPicking = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
        allowMultiple: true,
      );
      if (result == null) return;

      for (final picked in result.files) {
        if (picked.path == null) continue;
        final file = File(picked.path!);
        final ext = (picked.extension ?? '').toLowerCase();
        final isPdf = ext == 'pdf';

        int pageCount = 0;
        if (isPdf) {
          PdfDocument? document;
          try {
            document = await PdfDocument.openFile(file.path);
            pageCount = document.pagesCount;
          } catch (e) {
            _showSnack('Could not read "${picked.name}" - skipped.', isError: true);
            continue;
          } finally {
            await document?.close();
          }

          if (_totalPdfPagesUsed + pageCount > _maxTotalPdfPages) {
            _showSnack(
              '"${picked.name}" skipped - total PDF pages would exceed the $_maxTotalPdfPages-page limit.',
              isError: true,
            );
            continue;
          }
        }

        if (!mounted) return;
        setState(() {
          _pendingAttachments.add(_PendingAttachment(
            file: file,
            name: picked.name,
            type: isPdf ? 'pdf' : 'image',
            pageCount: pageCount,
          ));
        });
      }
    } finally {
      if (mounted) setState(() => _isPicking = false);
    }
  }

  void _removePendingAttachment(int index) {
    setState(() => _pendingAttachments.removeAt(index));
  }

  void _removeExistingAttachment(int index) {
    setState(() {
      _removedExistingAttachments.add(_existingAttachments[index]);
      _existingAttachments.removeAt(index);
    });
  }

  Future<void> _saveReport() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
      _errorMessage = '';
    });

    try {
      final reportsRef = FirebaseFirestore.instance.collection('reports');
      final docRef = _isEditing ? reportsRef.doc(widget.reportId) : reportsRef.doc();
      final reportId = docRef.id;

      // 1. Upload newly picked attachments
      final uploadedAttachments = <Map<String, dynamic>>[];
      for (final pending in _pendingAttachments) {
        final storagePath =
            'reports/$reportId/${DateTime.now().millisecondsSinceEpoch}_${pending.name}';
        final ref = FirebaseStorage.instance.ref(storagePath);
        await ref.putFile(pending.file);
        final url = await ref.getDownloadURL();
        uploadedAttachments.add({
          'name': pending.name,
          'url': url,
          'type': pending.type,
          'storagePath': storagePath,
          'pageCount': pending.pageCount,
        });
      }

      final finalAttachments = [..._existingAttachments, ...uploadedAttachments];

      // 2. Save the report in ONE write (so Mobilizer create also works)
      if (_isEditing) {
        await docRef.update({
          'title': _titleController.text.trim(),
          'description': _descriptionController.text.trim(),
          'reportDate': Timestamp.fromDate(_reportDate),
          'updatedAt': FieldValue.serverTimestamp(),
          'attachments': finalAttachments,
        });
      } else {
        await docRef.set({
          'title': _titleController.text.trim(),
          'description': _descriptionController.text.trim(),
          'reportDate': Timestamp.fromDate(_reportDate),
          'createdBy': FirebaseAuth.instance.currentUser?.uid,
          'createdByEmail': FirebaseAuth.instance.currentUser?.email,
          'createdByRole': widget.currentUserRole,
          'createdAt': FieldValue.serverTimestamp(),
          'attachments': finalAttachments,
        });
      }

      // 3. Only after the save succeeded, delete files the admin removed
      for (final removed in _removedExistingAttachments) {
        final storagePath = removed['storagePath'];
        if (storagePath != null) {
          try {
            await FirebaseStorage.instance.ref(storagePath).delete();
          } catch (_) {
            // Ignore - file may already be gone
          }
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEditing ? 'Report updated successfully!' : 'Report saved successfully!'),
            backgroundColor: primaryGreen,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to save report. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  InputDecoration _inputStyle(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: Colors.grey[600]),
      prefixIcon: Icon(icon, color: primaryGreen),
      filled: true,
      fillColor: const Color(0xFFF5F7F5),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: primaryGreen, width: 1.5),
      ),
    );
  }

  Widget _attachmentTile({
    required String name,
    required String type,
    required VoidCallback onRemove,
  }) {
    final isPdf = type == 'pdf';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Row(
        children: [
          Icon(
            isPdf ? Icons.picture_as_pdf_outlined : Icons.image_outlined,
            color: isPdf ? Colors.red[400] : Colors.blue[400],
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              name,
              style: const TextStyle(fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            color: Colors.grey[600],
            onPressed: _isSaving ? null : onRemove,
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F5),
      appBar: AppBar(
        backgroundColor: primaryGreen,
        elevation: 0,
        title: Text(_isEditing ? 'Edit Report' : 'New Report'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            TextFormField(
              controller: _titleController,
              decoration: _inputStyle('Report Title', Icons.title_outlined),
              validator: (v) =>
              (v == null || v.trim().isEmpty) ? 'Please enter a title' : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _descriptionController,
              maxLines: 6,
              decoration: _inputStyle('Details / Data', Icons.notes_outlined),
              validator: (v) =>
              (v == null || v.trim().isEmpty) ? 'Please enter report details' : null,
            ),
            const SizedBox(height: 14),
            InkWell(
              onTap: _pickReportDate,
              borderRadius: BorderRadius.circular(10),
              child: InputDecorator(
                decoration: _inputStyle('Report Date', Icons.calendar_today_outlined),
                child: Text(
                  '${_reportDate.day}/${_reportDate.month}/${_reportDate.year}',
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'ATTACHMENTS',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey[600],
                    letterSpacing: 0.5,
                  ),
                ),
                Text(
                  'PDF pages: $_totalPdfPagesUsed/$_maxTotalPdfPages',
                  style: TextStyle(
                    fontSize: 11,
                    color: _totalPdfPagesUsed >= _maxTotalPdfPages
                        ? Colors.red[700]
                        : Colors.grey[600],
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: (_isPicking || _isSaving) ? null : _pickAttachments,
              icon: _isPicking
                  ? const SizedBox(
                height: 16,
                width: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: primaryGreen),
              )
                  : const Icon(Icons.attach_file, color: primaryGreen),
              label: const Text('Add Attachments', style: TextStyle(color: primaryGreen)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: primaryGreen),
                minimumSize: const Size(double.infinity, 46),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 12),
            ..._existingAttachments.asMap().entries.map(
                  (entry) => _attachmentTile(
                name: entry.value['name'] ?? 'Document',
                type: entry.value['type'] ?? 'pdf',
                onRemove: () => _removeExistingAttachment(entry.key),
              ),
            ),
            ..._pendingAttachments.asMap().entries.map(
                  (entry) => _attachmentTile(
                name: entry.value.name,
                type: entry.value.type,
                onRemove: () => _removePendingAttachment(entry.key),
              ),
            ),
            if (_errorMessage.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _errorMessage,
                  style: TextStyle(color: Colors.red[700], fontSize: 13),
                ),
              ),
            ],
            const SizedBox(height: 28),
            SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveReport,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryGreen,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: _isSaving
                    ? const SizedBox(
                  height: 22,
                  width: 22,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2.5,
                  ),
                )
                    : Text(
                  _isEditing ? 'Update Report' : 'Save Report',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}