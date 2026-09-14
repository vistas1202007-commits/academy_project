import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'student_profile_screen.dart';

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
  static const Color primaryGreen = Color(0xFF1B6B4A);
  static const Color accentGold = Color(0xFFD4AF37);
  static const Color lightGreen = Color(0xFF6FA98C);

  Color _statusColor(String status) {
    switch (status) {
      case 'Completed':
        return primaryGreen;
      case 'Joined':
      case 'Ongoing':
        return accentGold;
      case 'Dropped':
        return lightGreen;
      default:
        return accentGold;
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
          SnackBar(content: Text('$name deleted.'), backgroundColor: primaryGreen),
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
      final status = (data['status'] ?? 'Registered').toString();
      final matchesSearch = name.contains(_searchQuery) ||
          phone.contains(_searchQuery) ||
          traineeId.contains(_searchQuery);
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
                  ? 'No students found.'
                  : 'No matching students found.',
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
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: CircleAvatar(
              backgroundColor: primaryGreen.withOpacity(0.12),
              child: Text(
                rawName.isNotEmpty ? rawName[0].toUpperCase() : '?',
                style: const TextStyle(color: primaryGreen, fontWeight: FontWeight.bold),
              ),
            ),
            title: Text(
              data['name'] ?? 'Unnamed',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              traineeId.isNotEmpty
                  ? '$traineeId - ${data['course'] ?? '-'}'
                  : '${data['course'] ?? '-'} - ${data['phone'] ?? '-'}',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _statusColor(status).withOpacity(0.15),
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
                if (!widget.trainerOnly)
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
        (widget.trainerOnly ? 'My Batch Students' : 'Students');
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F5),
      appBar: AppBar(
        backgroundColor: primaryGreen,
        elevation: 0,
        title: Text(title),
      ),
      body: Column(
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
                hintText: 'Search by name, phone, or Trainee ID',
                prefixIcon: Icon(Icons.search, color: primaryGreen),
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
                  return const Center(child: CircularProgressIndicator(color: primaryGreen));
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
                      return const Center(child: CircularProgressIndicator(color: primaryGreen));
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
                  return const Center(child: CircularProgressIndicator(color: primaryGreen));
                }
                return _buildStudentList(snapshot.data!.docs);
              },
            ),
          ),
        ],
      ),
    );
  }
}