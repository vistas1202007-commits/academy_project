import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'live_query.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'app_colors.dart';
import 'soft_delete.dart';
import 'responsive.dart';
import 'ui_kit.dart';

class MarkAttendanceScreen extends StatefulWidget {
  final bool trainerOnly;
  // When these are provided (e.g. navigating in from "Edit" on Attendance
  // History), the screen opens straight into that batch/date with the
  // existing attendance pre-loaded, ready to correct and re-save.
  final String? initialBatchId;
  final String? initialBatchName;
  final DateTime? initialDate;

  const MarkAttendanceScreen({
    super.key,
    this.trainerOnly = false,
    this.initialBatchId,
    this.initialBatchName,
    this.initialDate,
  });

  @override
  State<MarkAttendanceScreen> createState() => _MarkAttendanceScreenState();
}

class _MarkAttendanceScreenState extends State<MarkAttendanceScreen> {
  String? _selectedBatchId;
  String? _selectedBatchName;
  DateTime _selectedDate = DateTime.now();
  Map<String, String> _attendanceStatus = {};
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialBatchId != null) {
      _selectedBatchId = widget.initialBatchId;
      _selectedBatchName = widget.initialBatchName;
    }
    if (widget.initialDate != null) {
      _selectedDate = widget.initialDate!;
    }
    if (_selectedBatchId != null) {
      // Load once the first frame is up so `context`/`mounted` are ready.
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadExistingAttendance());
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(primary: AppColors.appPrimary),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _attendanceStatus = {};
      });
      _loadExistingAttendance();
    }
  }

  String get _docId {
    final dateStr = '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}';
    return '${_selectedBatchId}_$dateStr';
  }

  Future<void> _loadExistingAttendance() async {
    if (_selectedBatchId == null) return;
    final doc = await FirebaseFirestore.instance.collection('attendance').doc(_docId).get();
    if (doc.exists) {
      final data = doc.data() as Map<String, dynamic>;
      final statusMap = data['statusMap'] as Map<String, dynamic>? ?? {};
      setState(() {
        _attendanceStatus = statusMap.map((k, v) => MapEntry(k, v.toString()));
      });
    } else {
      setState(() {
        _attendanceStatus = {};
      });
    }
  }

  Future<void> _saveAttendance(List<QueryDocumentSnapshot> students) async {
    if (_selectedBatchId == null) return;

    setState(() {
      _isSaving = true;
    });

    try {
      await FirebaseFirestore.instance.collection('attendance').doc(_docId).set({
        'batchId': _selectedBatchId,
        'batchName': _selectedBatchName,
        'date': Timestamp.fromDate(_selectedDate),
        'statusMap': _attendanceStatus,
        'markedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Attendance saved successfully!'),
            backgroundColor: AppColors.appPrimary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to save attendance. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'present':
        return AppColors.appPrimary;
      case 'absent':
        return AppColors.danger;
      case 'leave':
        return AppColors.teal;
      default:
        return Colors.grey.shade300;
    }
  }

  @override
  Widget build(BuildContext context) {
    final batchesQuery = widget.trainerOnly
        ? FirebaseFirestore.instance
        .collection('batches')
        .where('trainerId', isEqualTo: FirebaseAuth.instance.currentUser?.uid)
        : FirebaseFirestore.instance.collection('batches');

    final isEditingExisting = widget.initialBatchId != null;

    return Scaffold(
      backgroundColor: AppColors.appBackground,
      appBar: AppBar(
        flexibleSpace: const AppBarRibbon(),
        backgroundColor: AppColors.appPrimary,
        elevation: 0,
        title: Text(isEditingExisting ? 'Edit Attendance' : 'Mark Attendance'),
      ),
      body: PageWash(child: ContentWidth(maxWidth: 1100, child: Column(
        children: [
          if (isEditingExisting)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.teal.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: AppColors.teal, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Editing ${_selectedBatchName ?? ''} — ${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}. Update the statuses below and save.',
                      style: const TextStyle(fontSize: 12, color: Colors.black87),
                    ),
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                StreamBuilder<QuerySnapshot>(
                  stream: batchesQuery.liveSnapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const SizedBox();
                    final batches = snapshot.data!.docs;

                    if (batches.isEmpty) {
                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orange[50],
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          widget.trainerOnly
                              ? 'No batch assigned to you yet.'
                              : 'No batches found. Create a batch first.',
                          style: const TextStyle(fontSize: 12, color: Colors.orange),
                        ),
                      );
                    }

                    return DropdownButtonFormField<String>(
                      initialValue: _selectedBatchId,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: 'Select Batch',
                        prefixIcon: Icon(Icons.class_outlined, color: AppColors.appPrimary),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      items: batches.map((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        return DropdownMenuItem(
                          value: doc.id,
                          child: Text(
                            data['batchName'] ?? 'Unnamed',
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        final selectedDoc = batches.firstWhere((doc) => doc.id == value);
                        final data = selectedDoc.data() as Map<String, dynamic>;
                        setState(() {
                          _selectedBatchId = value;
                          _selectedBatchName = data['batchName'];
                        });
                        _loadExistingAttendance();
                      },
                    );
                  },
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: _pickDate,
                  borderRadius: BorderRadius.circular(10),
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'Date',
                      prefixIcon: Icon(Icons.calendar_today_outlined, color: AppColors.appPrimary),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    child: Text('${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}'),
                  ),
                ),
              ],
            ),
          ),
          if (_selectedBatchId == null)
            Expanded(
              child: EmptyState(icon: Icons.fact_check_outlined, message: 'Select a batch to mark attendance'),
            )
          else
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('students')
                    .where('batch', isEqualTo: _selectedBatchName)
                    .liveSnapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const AppLoader();
                  }
                  final students = liveDocsOf(snapshot.data!);

                  if (students.isEmpty) {
                    return const EmptyState(
                      icon: Icons.groups_outlined,
                      message:
                          'No trainees found in this batch.\n(Make sure the trainee\'s "Batch" field matches the batch name exactly.)',
                    );
                  }

                  return Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton.icon(
                              onPressed: () {
                                setState(() {
                                  for (var doc in students) {
                                    _attendanceStatus[doc.id] = 'present';
                                  }
                                });
                              },
                              icon: const Icon(Icons.done_all, size: 18, color: AppColors.appPrimary),
                              label: const Text('Mark all present', style: TextStyle(color: AppColors.appPrimary)),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: students.length,
                          itemBuilder: (context, index) {
                            final doc = students[index];
                            final data = doc.data() as Map<String, dynamic>;
                            final currentStatus = _attendanceStatus[doc.id] ?? '';

                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: AppCard.decoration,
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      data['name'] ?? 'Unnamed',
                                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                                    ),
                                  ),
                                  _statusChip('P', 'present', doc.id, currentStatus),
                                  const SizedBox(width: 6),
                                  _statusChip('A', 'absent', doc.id, currentStatus),
                                  const SizedBox(width: 6),
                                  _statusChip('L', 'leave', doc.id, currentStatus),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            onPressed: _isSaving ? null : () => _saveAttendance(students),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.appPrimary,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: _isSaving
                                ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                            )
                                : Text(
                              isEditingExisting ? 'Save Changes' : 'Save Attendance',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
        ],
      ))),
    );
  }

  Widget _statusChip(String label, String status, String studentId, String currentStatus) {
    final isSelected = currentStatus == status;
    return InkWell(
      onTap: () {
        setState(() {
          _attendanceStatus[studentId] = status;
        });
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 32,
        height: 32,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? _statusColor(status) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey[600],
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}