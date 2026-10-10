import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'mark_attendance_screen.dart';
import 'app_colors.dart';

class AttendanceHistoryScreen extends StatefulWidget {
  // true when opened from the Trainer's Quick Actions — restricts the batch
  // dropdown to their own batches and hides the Delete option (Trainer only
  // has edit/update permission on attendance per the Firestore rules; only
  // Admin can delete an attendance record outright).
  final bool trainerOnly;

  const AttendanceHistoryScreen({super.key, this.trainerOnly = false});

  @override
  State<AttendanceHistoryScreen> createState() => _AttendanceHistoryScreenState();
}

class _AttendanceHistoryScreenState extends State<AttendanceHistoryScreen> {
  String? _selectedBatchId;
  String? _selectedBatchName;

  Future<void> _confirmDelete(BuildContext context, String docId, DateTime date, String batchName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Delete Attendance Record?'),
        content: Text(
          "This will permanently delete the attendance marked for $batchName on "
              "${DateFormat('dd MMM yyyy').format(date)}. This action cannot be undone. Continue?",
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
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await FirebaseFirestore.instance.collection('attendance').doc(docId).delete();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Attendance record deleted.'), backgroundColor: AppColors.appPrimary),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to delete. Please try again.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final batchesQuery = widget.trainerOnly
        ? FirebaseFirestore.instance
        .collection('batches')
        .where('trainerId', isEqualTo: FirebaseAuth.instance.currentUser?.uid)
        : FirebaseFirestore.instance.collection('batches');

    return Scaffold(
      backgroundColor: AppColors.appBackground,
      appBar: AppBar(
        backgroundColor: AppColors.appPrimary,
        elevation: 0,
        title: const Text('Attendance History'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: StreamBuilder<QuerySnapshot>(
              stream: batchesQuery.snapshots(),
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
                          : 'No batches found.',
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
                  },
                );
              },
            ),
          ),
          if (_selectedBatchId == null)
            Expanded(
              child: Center(
                child: Text('Select a batch to view attendance history', style: TextStyle(color: Colors.grey[600])),
              ),
            )
          else
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('attendance')
                    .orderBy('date', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return const Center(child: Text('Something went wrong.'));
                  }
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator(color: AppColors.appPrimary));
                  }

                  final records = snapshot.data!.docs.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    return data['batchId'] == _selectedBatchId;
                  }).toList();

                  if (records.isEmpty) {
                    return Center(
                      child: Text('No attendance marked yet for this batch.', style: TextStyle(color: Colors.grey[600])),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: records.length,
                    itemBuilder: (context, index) {
                      final doc = records[index];
                      final data = doc.data() as Map<String, dynamic>;
                      final date = (data['date'] as Timestamp).toDate();
                      final statusMap = Map<String, dynamic>.from(data['statusMap'] ?? {});
                      final batchName = (data['batchName'] ?? _selectedBatchName ?? '').toString();

                      final presentCount = statusMap.values.where((v) => v == 'present').length;
                      final absentCount = statusMap.values.where((v) => v == 'absent').length;
                      final leaveCount = statusMap.values.where((v) => v == 'leave').length;
                      final total = statusMap.length;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  DateFormat('dd MMM yyyy').format(date),
                                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                                ),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      '$total trainees',
                                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                    ),
                                    const SizedBox(width: 4),
                                    IconButton(
                                      icon: Icon(Icons.edit_outlined, color: AppColors.appPrimary, size: 18),
                                      tooltip: 'Edit',
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      onPressed: () {
                                        Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (context) => MarkAttendanceScreen(
                                              trainerOnly: widget.trainerOnly,
                                              initialBatchId: _selectedBatchId,
                                              initialBatchName: _selectedBatchName,
                                              initialDate: date,
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                    if (!widget.trainerOnly) ...[
                                      const SizedBox(width: 4),
                                      IconButton(
                                        icon: Icon(Icons.delete_outline, color: Colors.red[400], size: 18),
                                        tooltip: 'Delete',
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        onPressed: () => _confirmDelete(context, doc.id, date, batchName),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                _countChip('Present', presentCount, AppColors.appPrimary),
                                const SizedBox(width: 8),
                                _countChip('Absent', absentCount, AppColors.danger),
                                const SizedBox(width: 8),
                                _countChip('Leave', leaveCount, AppColors.teal),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _countChip(String label, int count, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Text(
              count.toString(),
              style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16),
            ),
            Text(
              label,
              style: TextStyle(color: color, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }
}