import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'student_profile_screen.dart';
import 'edit_batch_screen.dart';
import 'app_colors.dart';
import 'soft_delete.dart';
import 'responsive.dart';

class BatchDetailScreen extends StatelessWidget {
  final String batchId;
  const BatchDetailScreen({super.key, required this.batchId});

  Widget _infoChip(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: Colors.white70),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 13)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.appBackground,
      appBar: AppBar(
        backgroundColor: AppColors.appPrimary,
        elevation: 0,
        title: const Text('Batch Details'),
        actions: [
          FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance
                .collection('users')
                .doc(FirebaseAuth.instance.currentUser?.uid)
                .get(),
            builder: (context, userSnap) {
              if (!userSnap.hasData || !userSnap.data!.exists) return const SizedBox();
              final role = (userSnap.data!.data() as Map<String, dynamic>)['role'] ?? '';
              if (role != 'admin') return const SizedBox();
              return IconButton(
                icon: const Icon(Icons.edit_outlined),
                tooltip: 'Edit Batch',
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => EditBatchScreen(batchId: batchId),
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
      body: ContentWidth(maxWidth: 1100, child: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('batches').doc(batchId).snapshots(),
        builder: (context, batchSnap) {
          if (!batchSnap.hasData) {
            return const Center(child: CircularProgressIndicator(color: AppColors.appPrimary));
          }
          if (!batchSnap.data!.exists) {
            return const Center(child: Text('This batch no longer exists.'));
          }

          final batchData = batchSnap.data!.data() as Map<String, dynamic>;
          final batchName = (batchData['batchName'] ?? '').toString();
          final startDate = batchData['startDate'] != null
              ? DateFormat('dd MMM yyyy').format((batchData['startDate'] as Timestamp).toDate())
              : '-';
          final endDate = batchData['endDate'] != null
              ? DateFormat('dd MMM yyyy').format((batchData['endDate'] as Timestamp).toDate())
              : '-';

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.appPrimary,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      batchName.isNotEmpty ? batchName : 'Unnamed Batch',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        (batchData['status'] ?? 'active').toString().toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _infoChip(Icons.school_outlined, batchData['course'] ?? '-'),
                    const SizedBox(height: 6),
                    _infoChip(Icons.person_outline, batchData['trainerName'] ?? '-'),
                    const SizedBox(height: 6),
                    _infoChip(Icons.calendar_today_outlined, '$startDate - $endDate'),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'TRAINEES IN THIS BATCH',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.appPrimary,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 12),
              if (batchName.isEmpty)
                Text(
                  'This batch has no batchName set, so trainees cannot be matched to it.',
                  style: TextStyle(color: Colors.grey[600]),
                )
              else
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('students')
                      .where('batch', isEqualTo: batchName)
                      .snapshots(),
                  builder: (context, studentSnap) {
                    if (!studentSnap.hasData) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(20),
                          child: CircularProgressIndicator(color: AppColors.appPrimary),
                        ),
                      );
                    }
                    final students = liveDocsOf(studentSnap.data!);
                    if (students.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(Icons.groups_outlined, size: 48, color: Colors.grey[350]),
                              const SizedBox(height: 10),
                              Text(
                                'No trainees assigned to this batch yet.',
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                            ],
                          ),
                        ),
                      );
                    }
                    return Column(
                      children: students.map((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        final rawName = (data['name'] ?? '').toString().trim();
                        final traineeId = (data['traineeId'] ?? '').toString();
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.04),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: AppColors.appPrimary.withValues(alpha: 0.12),
                              child: Text(
                                rawName.isNotEmpty ? rawName[0].toUpperCase() : '?',
                                style: const TextStyle(color: AppColors.appPrimary, fontWeight: FontWeight.bold),
                              ),
                            ),
                            title: Text(rawName.isNotEmpty ? rawName : 'Unnamed'),
                            subtitle: Text(
                              traineeId.isNotEmpty ? traineeId : (data['phone'] ?? '-'),
                              style: TextStyle(color: Colors.grey[600], fontSize: 12),
                            ),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.teal.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                (data['status'] ?? 'Registered').toString().toUpperCase(),
                                style: const TextStyle(
                                  color: AppColors.teal,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
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
                      }).toList(),
                    );
                  },
                ),
            ],
          );
        },
      )),
    );
  }
}