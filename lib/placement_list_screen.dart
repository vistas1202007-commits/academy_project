import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'add_placement_screen.dart';
import 'placement_detail_screen.dart';

class PlacementListScreen extends StatefulWidget {
  const PlacementListScreen({super.key});

  @override
  State<PlacementListScreen> createState() => _PlacementListScreenState();
}

class _PlacementListScreenState extends State<PlacementListScreen> {
  String _searchQuery = '';

  static const Color primaryGreen = Color(0xFF1B6B4A);
  static const Color accentGold = Color(0xFFD4AF37);

  Color _statusColor(String status) {
    switch (status) {
      case 'Selected':
      case 'Joined':
      case 'Self-Employed':
        return primaryGreen;
      case 'Rejected':
      case 'Not Joined':
        return Colors.red;
      case 'Interview Scheduled':
        return accentGold;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F5),
      appBar: AppBar(
        backgroundColor: primaryGreen,
        title: const Text('Placements'),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: accentGold,
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (context) => const AddPlacementScreen()),
          );
        },
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              onChanged: (value) => setState(() => _searchQuery = value.toLowerCase()),
              decoration: InputDecoration(
                hintText: 'Search by name, company, or trainee ID',
                prefixIcon: Icon(Icons.search, color: primaryGreen),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('placements')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: primaryGreen));
                }
                final allDocs = snapshot.data?.docs ?? [];
                final docs = allDocs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final name = (data['studentName'] ?? '').toString().toLowerCase();
                  final company = (data['companyName'] ?? '').toString().toLowerCase();
                  final traineeId = (data['traineeId'] ?? '').toString().toLowerCase();
                  return name.contains(_searchQuery) || company.contains(_searchQuery) || traineeId.contains(_searchQuery);
                }).toList();
                if (docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.work_history_outlined, size: 56, color: Colors.grey[350]),
                        const SizedBox(height: 12),
                        Text('No placement records yet.', style: TextStyle(color: Colors.grey[600])),
                      ],
                    ),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    final status = data['status'] ?? 'Not Placed';
                    final traineeId = (data['traineeId'] ?? '').toString();
                    final course = (data['course'] ?? '').toString();
                    final jobPost = (data['jobPost'] ?? '').toString();
                    return Material(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => PlacementDetailScreen(
                                placementId: docs[index].id,
                                data: data,
                              ),
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 3)),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      data['studentName'] ?? '',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: _statusColor(status).withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      status,
                                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _statusColor(status)),
                                    ),
                                  ),
                                ],
                              ),
                              if (traineeId.isNotEmpty || course.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 3),
                                  child: Text(
                                    [
                                      if (traineeId.isNotEmpty) traineeId,
                                      if (course.isNotEmpty) course,
                                    ].join(' - '),
                                    style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                                  ),
                                ),
                              const SizedBox(height: 6),
                              Text(
                                '${data['companyName'] ?? ''} - ${data['jobLocation'] ?? ''}',
                                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                              ),
                              if (jobPost.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 3),
                                  child: Text(
                                    jobPost,
                                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                  ),
                                ),
                              if ((data['salary'] ?? '').toString().isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 3),
                                  child: Text(
                                    'Salary: Rs.${data['salary']} - ${data['employmentType'] ?? ''}',
                                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                  ),
                                ),
                            ],
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