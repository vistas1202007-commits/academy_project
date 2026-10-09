import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'edit_student_screen.dart';
import 'current_user.dart';

class StudentProfileScreen extends StatelessWidget {
  final String studentId;

  const StudentProfileScreen({super.key, required this.studentId});

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

  /// DOB se aaj tak ki poori umar (saal me)
  int _ageFromDob(DateTime dob) {
    final now = DateTime.now();
    int age = now.year - dob.year;
    if (now.month < dob.month || (now.month == dob.month && now.day < dob.day)) age--;
    return age;
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: primaryGreen, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                const SizedBox(height: 2),
                Text(
                  value.isEmpty ? '-' : value,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionCard(String title, List<Widget> children) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: primaryGreen,
              letterSpacing: 0.3,
            ),
          ),
          const Divider(height: 20),
          ...children,
        ],
      ),
    );
  }

  /// placements collection se is trainee ka latest record (orderBy nahi, taaki index na lage)
  Widget _placementSection(String traineeId) {
    if (traineeId.isEmpty) {
      return _sectionCard('PLACEMENT', [
        _infoRow(Icons.work_off_outlined, 'Status', 'Not placed yet'),
      ]);
    }
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('placements')
          .where('traineeId', isEqualTo: traineeId)
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return _sectionCard('PLACEMENT', [
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Center(child: CircularProgressIndicator(color: primaryGreen)),
            ),
          ]);
        }
        final docs = snap.data!.docs;
        if (docs.isEmpty) {
          return _sectionCard('PLACEMENT', [
            _infoRow(Icons.work_off_outlined, 'Status', 'Not placed yet'),
          ]);
        }
        // Ek se zyada record ho to sabse naya (createdAt) dikhao
        final latest = docs.reduce((a, b) {
          final ta = a.data()['createdAt'];
          final tb = b.data()['createdAt'];
          if (ta is! Timestamp) return b;
          if (tb is! Timestamp) return a;
          return tb.compareTo(ta) > 0 ? b : a;
        }).data();
        return _sectionCard('PLACEMENT', [
          _infoRow(Icons.work_outline, 'Status', (latest['status'] ?? '').toString()),
          _infoRow(Icons.business_outlined, 'Company', (latest['companyName'] ?? '').toString()),
          _infoRow(Icons.location_on_outlined, 'Job Location',
              (latest['jobLocation'] ?? '').toString()),
        ]);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F5),
      appBar: AppBar(
        backgroundColor: primaryGreen,
        elevation: 0,
        title: const Text('Trainee Profile'),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('students').doc(studentId).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator(color: primaryGreen));
          }
          if (!snapshot.data!.exists) {
            return const Center(child: Text('This trainee no longer exists.'));
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;
          final admissionDate = data['admissionDate'] != null
              ? DateFormat('dd MMM yyyy').format((data['admissionDate'] as Timestamp).toDate())
              : '-';
          final dobText = data['dob'] is Timestamp
              ? () {
                  final dob = (data['dob'] as Timestamp).toDate();
                  return '${DateFormat('dd MMM yyyy').format(dob)} (${_ageFromDob(dob)} yrs)';
                }()
              : '';
          final traineeId = (data['traineeId'] ?? '').toString();
          final status = (data['status'] ?? 'Registered').toString();

          final totalFee = (data['totalFee'] ?? 0).toDouble();
          final feePaid = (data['feePaid'] ?? 0).toDouble();
          final feePending = (data['feePending'] ?? (totalFee - feePaid)).toDouble();
          final isFullyPaid = totalFee > 0 && feePending <= 0;
          final hasFeeData = totalFee > 0 || feePaid > 0;

          return Stack(
            children: [
              ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: primaryGreen,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          data['name'] ?? 'Unnamed',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (traineeId.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            traineeId,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: _statusColor(status).withOpacity(0.2),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                status.toUpperCase(),
                                style: TextStyle(
                                  color: _statusColor(status) == primaryGreen
                                      ? Colors.white
                                      : accentGold,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            if (hasFeeData)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  isFullyPaid ? 'FEES PAID' : 'FEES PENDING',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  _sectionCard('PERSONAL INFORMATION', [
                    _infoRow(Icons.phone_outlined, 'Phone', data['phone'] ?? ''),
                    _infoRow(Icons.email_outlined, 'Email', data['email'] ?? ''),
                    _infoRow(Icons.wc_outlined, 'Gender', data['gender'] ?? ''),
                    _infoRow(Icons.cake_outlined, 'Date of Birth (Age)', dobText),
                    _infoRow(Icons.home_outlined, 'Village', (data['village'] ?? '').toString()),
                    _infoRow(Icons.location_city_outlined, 'Tehsil', (data['tehsil'] ?? '').toString()),
                  ]),
                  _sectionCard('GUARDIAN INFORMATION', [
                    _infoRow(Icons.family_restroom_outlined, 'Guardian Name',
                        data['guardianName'] ?? ''),
                    _infoRow(Icons.phone_outlined, 'Guardian Phone', data['guardianPhone'] ?? ''),
                  ]),
                  _sectionCard('TRAINING INFORMATION', [
                    _infoRow(Icons.badge_outlined, 'Trainee ID', traineeId),
                    _infoRow(Icons.school_outlined, 'Course', data['course'] ?? ''),
                    _infoRow(Icons.class_outlined, 'Batch', data['batch'] ?? ''),
                    _infoRow(Icons.calendar_today_outlined, 'Admission Date', admissionDate),
                  ]),
                  _placementSection(traineeId),
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(16),
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'FEES',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: primaryGreen,
                            letterSpacing: 0.3,
                          ),
                        ),
                        const Divider(height: 20),
                        _infoRow(Icons.receipt_long_outlined, 'Total Fee',
                            '₹${totalFee.toStringAsFixed(0)}'),
                        _infoRow(Icons.currency_rupee_outlined, 'Paid',
                            '₹${feePaid.toStringAsFixed(0)}'),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                isFullyPaid ? Icons.check_circle_outline : Icons.pending_outlined,
                                color: isFullyPaid ? primaryGreen : accentGold,
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Pending',
                                        style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                                    const SizedBox(height: 2),
                                    Text(
                                      isFullyPaid
                                          ? 'Fully Paid ✓'
                                          : '₹${feePending.clamp(0, double.infinity).toStringAsFixed(0)}',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: isFullyPaid ? primaryGreen : accentGold.withAlpha(230),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 70),
                ],
              ),
              // Edit sirf Admin ko dikhe
              FutureBuilder<String>(
                future: currentUserRole(),
                builder: (context, roleSnap) {
                  if (roleSnap.data != 'admin') return const SizedBox.shrink();
                  return Positioned(
                bottom: 20,
                left: 20,
                right: 20,
                child: SizedBox(
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => EditStudentScreen(
                            studentId: studentId,
                            currentData: data,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.edit_outlined, color: Colors.white),
                    label: const Text('Edit Trainee',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accentGold,
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}