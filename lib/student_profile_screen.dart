import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'edit_student_screen.dart';
import 'current_user.dart';
import 'fee_receipt_pdf.dart';
import 'app_colors.dart';
import 'soft_delete.dart';
import 'responsive.dart';
import 'ui_kit.dart';

class StudentProfileScreen extends StatelessWidget {
  final String studentId;

  const StudentProfileScreen({super.key, required this.studentId});

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
          Icon(icon, color: AppColors.appPrimary, size: 20),
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
            color: Colors.black.withValues(alpha: 0.04),
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
              color: AppColors.appPrimary,
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
              child: Center(child: CircularProgressIndicator(color: AppColors.appPrimary)),
            ),
          ]);
        }
        final docs = liveDocs(snap.data!);
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
      backgroundColor: AppColors.appBackground,
      appBar: AppBar(
        flexibleSpace: const AppBarRibbon(),
        backgroundColor: AppColors.appPrimary,
        elevation: 0,
        title: const Text('Trainee Profile'),
      ),
      body: PageWash(child: ContentWidth(maxWidth: 1100, child: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('students').doc(studentId).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator(color: AppColors.appPrimary));
          }
          if (!snapshot.data!.exists) {
            return const Center(child: Text('This trainee no longer exists.'));
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;
          if (!isLive(data)) {
            return const Center(child: Text('This trainee is in the Recycle Bin.'));
          }
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
                      color: AppColors.appPrimary,
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
                                color: _statusColor(status).withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                status.toUpperCase(),
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            if (hasFeeData)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.2),
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
                          color: Colors.black.withValues(alpha: 0.04),
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
                            color: AppColors.appPrimary,
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
                                color: isFullyPaid ? AppColors.success : AppColors.warning,
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
                                        color: isFullyPaid ? AppColors.success : AppColors.warning.withAlpha(230),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (feePaid > 0) _ReceiptButton(data: data),
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
                      backgroundColor: AppColors.appAccent,
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
      ))),
    );
  }
}

/// FEES card ka "Download Receipt"; sirf Admin ko dikhta hai
class _ReceiptButton extends StatefulWidget {
  final Map<String, dynamic> data;
  const _ReceiptButton({required this.data});

  @override
  State<_ReceiptButton> createState() => _ReceiptButtonState();
}

class _ReceiptButtonState extends State<_ReceiptButton> {
  late final Future<String> _role = currentUserRole();
  bool _busy = false;

  Future<void> _download() async {
    setState(() => _busy = true);
    final result = await shareFeeReceipt(widget.data);
    if (!mounted) return;
    setState(() => _busy = false);
    final message = switch (result) {
      ReceiptResult.denied => 'Access denied: only Admin can generate receipts.',
      ReceiptResult.failed => 'Could not create the receipt. Please try again.',
      ReceiptResult.shared => null,
    };
    if (message == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.danger),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _role,
      builder: (context, snap) {
        if (snap.data != 'admin') return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(top: 8),
          child: SizedBox(
            width: double.infinity,
            height: 44,
            child: OutlinedButton.icon(
              onPressed: _busy ? null : _download,
              icon: _busy
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.appPrimary),
                    )
                  : const Icon(Icons.download_outlined, size: 20),
              label: const Text('Download Receipt', style: TextStyle(fontWeight: FontWeight.w600)),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.appPrimary,
                side: const BorderSide(color: AppColors.border),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        );
      },
    );
  }
}