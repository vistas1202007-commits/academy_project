import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'batch_detail_screen.dart';

class BatchListScreen extends StatefulWidget {
  final bool trainerOnly;

  const BatchListScreen({super.key, this.trainerOnly = false});

  @override
  State<BatchListScreen> createState() => _BatchListScreenState();
}

class _BatchListScreenState extends State<BatchListScreen> {
  String _searchQuery = '';
  static const Color primaryGreen = Color(0xFF1B6B4A);
  static const Color accentGold = Color(0xFFD4AF37);

  @override
  Widget build(BuildContext context) {
    Query<Map<String, dynamic>> query = FirebaseFirestore.instance.collection('batches');

    if (widget.trainerOnly) {
      final currentUid = FirebaseAuth.instance.currentUser?.uid;
      query = query.where('trainerId', isEqualTo: currentUid);
    } else {
      query = query.orderBy('createdAt', descending: true);
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F5),
      appBar: AppBar(
        backgroundColor: primaryGreen,
        elevation: 0,
        title: Text(widget.trainerOnly ? 'My Batches' : 'Batches'),
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
                hintText: 'Search by batch name, course, or trainer',
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
            child: StreamBuilder<QuerySnapshot>(
              stream: query.snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(child: Text('Something went wrong.'));
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator(color: primaryGreen));
                }
                final allDocs = snapshot.data!.docs.toList();
                if (widget.trainerOnly) {
                  allDocs.sort((a, b) {
                    final aTime = (a.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
                    final bTime = (b.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
                    if (aTime == null || bTime == null) return 0;
                    return bTime.compareTo(aTime);
                  });
                }
                final docs = allDocs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final batchName = (data['batchName'] ?? '').toString().toLowerCase();
                  final course = (data['course'] ?? '').toString().toLowerCase();
                  final trainerName = (data['trainerName'] ?? '').toString().toLowerCase();
                  return batchName.contains(_searchQuery) ||
                      course.contains(_searchQuery) ||
                      trainerName.contains(_searchQuery);
                }).toList();
                if (docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          allDocs.isEmpty ? Icons.class_outlined : Icons.search_off_outlined,
                          size: 56,
                          color: Colors.grey[350],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          allDocs.isEmpty
                              ? (widget.trainerOnly
                              ? 'No batches assigned to you yet.'
                              : 'No batches created yet.')
                              : 'No matching batches found.',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final batchName = (data['batchName'] ?? '').toString();
                    final startDate = data['startDate'] != null
                        ? DateFormat('dd MMM yyyy').format((data['startDate'] as Timestamp).toDate())
                        : '-';
                    final endDate = data['endDate'] != null
                        ? DateFormat('dd MMM yyyy').format((data['endDate'] as Timestamp).toDate())
                        : '-';
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
                      child: Material(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(14),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => BatchDetailScreen(batchId: doc.id),
                              ),
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        batchName.isNotEmpty ? batchName : 'Unnamed Batch',
                                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: accentGold.withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        (data['status'] ?? 'active').toString().toUpperCase(),
                                        style: const TextStyle(
                                          color: accentGold,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Icon(Icons.school_outlined, size: 16, color: Colors.grey[600]),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        data['course'] ?? '-',
                                        style: TextStyle(color: Colors.grey[700]),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(Icons.person_outline, size: 16, color: Colors.grey[600]),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        data['trainerName'] ?? '-',
                                        style: TextStyle(color: Colors.grey[700]),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(Icons.calendar_today_outlined, size: 16, color: Colors.grey[600]),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        '$startDate - $endDate',
                                        style: TextStyle(color: Colors.grey[700], fontSize: 12),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(Icons.groups_outlined, size: 16, color: Colors.grey[600]),
                                    const SizedBox(width: 6),
                                    if (batchName.isEmpty)
                                      Text('0 students', style: TextStyle(color: Colors.grey[700], fontSize: 12))
                                    else
                                      StreamBuilder<QuerySnapshot>(
                                        stream: FirebaseFirestore.instance
                                            .collection('students')
                                            .where('batch', isEqualTo: batchName)
                                            .snapshots(),
                                        builder: (context, studentSnap) {
                                          final count = studentSnap.hasData
                                              ? studentSnap.data!.docs.length
                                              : (data['studentCount'] ?? 0);
                                          return Text(
                                            '$count students',
                                            style: TextStyle(color: Colors.grey[700], fontSize: 12),
                                          );
                                        },
                                      ),
                                    const Spacer(),
                                    Icon(Icons.chevron_right, size: 20, color: Colors.grey[400]),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
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
}