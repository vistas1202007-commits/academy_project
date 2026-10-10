import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'student_profile_screen.dart';
import 'current_user.dart';
import 'app_colors.dart';
import 'responsive.dart';

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
  // Delete sirf Admin ko dikhe
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
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Delete Trainee?'),
        content: Text(
          "This will permanently delete $name's record. This action cannot be undone. Continue?",
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
      await FirebaseFirestore.instance.collection('students').doc(docId).delete();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$name deleted.'), backgroundColor: AppColors.appPrimary),
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

  Widget _buildStudentList(List<QueryDocumentSnapshot> allDocs) {
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
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.groups_outlined, size: 56, color: Colors.grey[350]),
            const SizedBox(height: 12),
            Text(
              allDocs.isEmpty
                  ? 'No trainees found.'
                  : 'No matching trainees found.',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      );
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
        backgroundColor: AppColors.appPrimary,
        elevation: 0,
        title: Text(title),
      ),
      body: ContentWidth(maxWidth: 900, child: Column(
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
                  return const Center(child: CircularProgressIndicator(color: AppColors.appPrimary));
                }
                final batchNames = batchSnap.data!.docs
                    .map((d) => (d.data() as Map<String, dynamic>)['batchName'] as String?)
                    .whereType<String>()
                    .toList();
                if (batchNames.isEmpty) {
                  return Center(
                    child: Text(
                      'No batch assigned to you yet.',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  );
                }
                return StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('students')
                      .where('batch', whereIn: batchNames)
                      .snapshots(),
                  builder: (context, studentSnap) {
                    if (!studentSnap.hasData) {
                      return const Center(child: CircularProgressIndicator(color: AppColors.appPrimary));
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
                  return const Center(child: CircularProgressIndicator(color: AppColors.appPrimary));
                }
                return _buildStudentList(snapshot.data!.docs);
              },
            ),
          ),
        ],
      )),
    );
  }
}