import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'student_profile_screen.dart';
import 'current_user.dart';
import 'app_colors.dart';
import 'recycle_bin_screen.dart';
import 'soft_delete.dart';
import 'responsive.dart';
import 'ui_kit.dart';

class StudentListScreen extends StatefulWidget {
  final bool trainerOnly;
  final List<String>? filterStatuses;
  final String? screenTitle;

  const StudentListScreen({
    super.key,
    this.trainerOnly = false,
    this.filterStatuses,
    this.screenTitle,
  });

  @override
  State<StudentListScreen> createState() => _StudentListScreenState();
}

class _StudentListScreenState extends State<StudentListScreen> {
  String _searchQuery = '';
  // Delete is visible to Admin only
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    currentUserRole().then((role) {
      if (mounted) setState(() => _isAdmin = role == 'admin');
    });
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'Completed':
        return AppColors.appPrimary;
      case 'Joined':
      case 'Ongoing':
        return AppColors.teal;
      case 'Dropped':
        return AppColors.danger;
      default:
        return AppColors.teal;
    }
  }

  Future<void> _confirmDelete(BuildContext context, String docId, String name) async {
    if (!await confirmMoveToBin(context, name)) return;

    try {
      await softDelete(FirebaseFirestore.instance.collection('students').doc(docId));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$name moved to Recycle Bin.'), backgroundColor: AppColors.appPrimary),
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

  Widget _buildStudentList(List<QueryDocumentSnapshot> snapDocs) {
    // Trainees in the Recycle Bin are left out of the list, counts and search
    final allDocs = snapDocs.where((d) => isLive(d.data() as Map<String, dynamic>?)).toList();
    final filteredDocs = allDocs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final name = (data['name'] ?? '').toString().toLowerCase();
      final phone = (data['phone'] ?? '').toString().toLowerCase();
      final traineeId = (data['traineeId'] ?? '').toString().toLowerCase();
      final village = (data['village'] ?? '').toString().toLowerCase();
      final batch = (data['batch'] ?? '').toString().toLowerCase();
      final status = (data['status'] ?? 'Registered').toString();
      final matchesSearch = name.contains(_searchQuery) ||
          phone.contains(_searchQuery) ||
          traineeId.contains(_searchQuery) ||
          village.contains(_searchQuery) ||
          batch.contains(_searchQuery);
      final matchesStatus =
          widget.filterStatuses == null || widget.filterStatuses!.contains(status);
      return matchesSearch && matchesStatus;
    }).toList();

    if (filteredDocs.isEmpty) {
      return EmptyState(icon: Icons.groups_outlined, message: allDocs.isEmpty ? 'No trainees found.' : 'No matching trainees found.');
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: filteredDocs.length,
      itemBuilder: (context, index) {
        final doc = filteredDocs[index];
        final data = doc.data() as Map<String, dynamic>;
        final traineeId = (data['traineeId'] ?? '').toString();
        final status = (data['status'] ?? 'Registered').toString();
        final rawName = (data['name'] ?? '').toString().trim();
        final name = rawName.isNotEmpty ? rawName : 'This trainee';
        final village = (data['village'] ?? '').toString().trim();
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: AppCard.decoration,
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: CircleAvatar(
              backgroundColor: AppColors.appPrimary.withValues(alpha: 0.12),
              child: Text(
                rawName.isNotEmpty ? rawName[0].toUpperCase() : '?',
                style: const TextStyle(color: AppColors.appPrimary, fontWeight: FontWeight.bold),
              ),
            ),
            title: Text(
              data['name'] ?? 'Unnamed',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              (traineeId.isNotEmpty
                  ? '$traineeId - ${data['course'] ?? '-'}'
                  : '${data['course'] ?? '-'} - ${data['phone'] ?? '-'}') +
                  (village.isNotEmpty ? '\n$village' : ''),
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _statusColor(status).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    status.toUpperCase(),
                    style: TextStyle(
                      color: _statusColor(status),
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (_isAdmin && !widget.trainerOnly)
                  IconButton(
                    icon: Icon(Icons.delete_outline, color: Colors.red[400], size: 20),
                    tooltip: 'Delete',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => _confirmDelete(context, doc.id, name),
                  ),
              ],
            ),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => StudentProfileScreen(studentId: doc.id),
                ),
              );
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.screenTitle ??
        (widget.trainerOnly ? 'My Batch Trainees' : 'Trainees');
    return Scaffold(
      backgroundColor: AppColors.appBackground,
      appBar: AppBar(
        flexibleSpace: const AppBarRibbon(),
        backgroundColor: AppColors.appPrimary,
        elevation: 0,
        title: Text(title),
      ),
      body: PageWash(child: ContentWidth(maxWidth: 900, child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.toLowerCase();
                });
              },
              decoration: InputDecoration(
                hintText: 'Search by name, phone, ID, village, or batch',
                prefixIcon: Icon(Icons.search, color: AppColors.appPrimary),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Expanded(
            child: widget.trainerOnly
                ? StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('batches')
                  .where('trainerId', isEqualTo: FirebaseAuth.instance.currentUser?.uid)
                  .snapshots(),
              builder: (context, batchSnap) {
                if (!batchSnap.hasData) {
                  return const AppLoader();
                }
                final batchNames = batchSnap.data!.docs
                    .map((d) => (d.data() as Map<String, dynamic>)['batchName'] as String?)
                    .whereType<String>()
                    .toList();
                if (batchNames.isEmpty) {
                  return EmptyState(icon: Icons.class_outlined, message: 'No batch assigned to you yet.');
                }
                return StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('students')
                      .where('batch', whereIn: batchNames)
                      .snapshots(),
                  builder: (context, studentSnap) {
                    if (!studentSnap.hasData) {
                      return const AppLoader();
                    }
                    return _buildStudentList(studentSnap.data!.docs);
                  },
                );
              },
            )
                : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('students')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(child: Text('Something went wrong.'));
                }
                if (!snapshot.hasData) {
                  return const AppLoader();
                }
                return _buildStudentList(snapshot.data!.docs);
              },
            ),
          ),
        ],
      ))),
    );
  }
}