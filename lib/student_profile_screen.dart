import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'edit_student_screen.dart';

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
              Positioned(
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
              ),
            ],
          );
        },
      ),
    );
  }
}