import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'add_student_screen.dart';
import 'student_list_screen.dart';
import 'add_batch_screen.dart';
import 'batch_list_screen.dart';
import 'add_trainer_screen.dart';
import 'staff_list_screen.dart';
import 'mark_attendance_screen.dart';
import 'attendance_history_screen.dart';
import 'app_drawer.dart';
import 'add_company_screen.dart';
import 'company_list_screen.dart';
import 'add_placement_screen.dart';
import 'placement_list_screen.dart';
import 'add_enquiry_screen.dart';
import 'enquiry_list_screen.dart';
import 'profile_screen.dart';
import 'bulk_import_screen.dart';
import 'fees_report_screen.dart';
import 'analytics_screen.dart';
import 'at_risk_screen.dart';
import 'ask_data_screen.dart';
import 'notifications_screen.dart';
import 'app_colors.dart';
import 'brand.dart';
import 'app_shell.dart';
import 'nav_items.dart';
import 'responsive.dart';

class DashboardScreen extends StatelessWidget {
  final String role;
  final String name;
  const DashboardScreen({super.key, required this.role, required this.name});

  String get _roleLabel => roleLabelFor(role);

  // Sidebar ko naam aur role yahin se milta hai
  @override
  Widget build(BuildContext context) => ShellUser(name: name, role: role, child: Builder(builder: _buildPage));

  Widget _buildPage(BuildContext context) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    // Desktop par menu sidebar me hai: na drawer, na hamburger
    final desktop = isDesktop(context);
    return Scaffold(
      backgroundColor: AppColors.appBackground,
      drawer: desktop ? null : AppDrawer(name: name, roleLabel: _roleLabel),
      appBar: AppBar(
        backgroundColor: AppColors.appPrimary,
        elevation: 0,
        title: desktop ? const Text('Dashboard') : const VistasAppBarTitle(),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.appPrimary,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.appPrimary.withValues(alpha: 0.25),
                    blurRadius: 15,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Welcome back',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.aurora.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _roleLabel,
                      style: const TextStyle(
                        color: AppColors.aurora,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Overview',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            // ---------------- OVERVIEW SECTIONS PER ROLE ----------------
            if (role == 'admin')
              _AdminOverview(
                  onViewStudents: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (context) => const StudentListScreen()),
                  ))
            else if (role == 'trainer')
              _TrainerOverview(trainerUid: currentUid)
            else if (role == 'placementOfficer')
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collection('placements').snapshots(),
                  builder: (context, placementSnap) {
                    final placedCount = placementSnap.hasData
                        ? placementSnap.data!.docs
                        .where((d) {
                      final s = (d.data() as Map<String, dynamic>)['status'];
                      return s == 'Joined' || s == 'Selected' || s == 'Self-Employed';
                    })
                        .length
                        .toString()
                        : '--';
                    return StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance.collection('companies').snapshots(),
                      builder: (context, companySnap) {
                        final companyCount =
                        companySnap.hasData ? companySnap.data!.docs.length.toString() : '--';
                        return GridView(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          // Max ~220 chaude cards: phone par 2, desktop par 5-6 ek line me
                          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 220,
                            crossAxisSpacing: 14,
                            mainAxisSpacing: 14,
                            childAspectRatio: 1.25,
                          ),
                          children: [
                            _DashboardCard(
                              icon: Icons.work_outline,
                              label: 'Trainees Placed',
                              value: placedCount,
                              color: AppColors.appPrimary,
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(builder: (context) => const PlacementListScreen()),
                                );
                              },
                            ),
                            _DashboardCard(
                              icon: Icons.business_outlined,
                              label: 'Active Companies',
                              value: companyCount,
                              color: AppColors.teal,
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(builder: (context) => const CompanyListScreen()),
                                );
                              },
                            ),
                          ],
                        );
                      },
                    );
                  },
                )
              else if (role == 'mobilizer')
                  const _MobilizerOverview(),
            const SizedBox(height: 24),
            if (_actionsForRole(context).isNotEmpty) ...[
              const Text(
                'Quick Actions',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 12),
              // Parent ki width se: phone par 2, desktop par ~180 ke jitne aa jayein
              LayoutBuilder(
                builder: (context, constraints) {
                  final columns = ((constraints.maxWidth + 12) / (180 + 12)).floor().clamp(2, 8);
                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      for (final action in _actionsForRole(context))
                        SizedBox(
                          width: (constraints.maxWidth - 12 * (columns - 1)) / columns,
                          child: action,
                        ),
                    ],
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  List<_QuickActionButton> _actionsForRole(BuildContext context) {
    switch (role) {
      case 'admin':
        return [
          _QuickActionButton(
            icon: Icons.person_add_alt_outlined,
            label: 'Add Trainee',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const AddStudentScreen()),
              );
            },
          ),
          _QuickActionButton(
            icon: Icons.fact_check_outlined,
            label: 'Mark Attendance',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const MarkAttendanceScreen()),
              );
            },
          ),
          _QuickActionButton(
            icon: Icons.list_alt_outlined,
            label: 'View Trainees',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const StudentListScreen()),
              );
            },
          ),
          _QuickActionButton(
            icon: Icons.add_business_outlined,
            label: 'Add Batch',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const AddBatchScreen()),
              );
            },
          ),
          _QuickActionButton(
            icon: Icons.view_list_outlined,
            label: 'View Batches',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const BatchListScreen()),
              );
            },
          ),
          _QuickActionButton(
            icon: Icons.person_add_outlined,
            label: 'Add Staff',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const AddTrainerScreen()),
              );
            },
          ),
          _QuickActionButton(
            icon: Icons.badge_outlined,
            label: 'Staff List',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const StaffListScreen()),
              );
            },
          ),
          _QuickActionButton(
            icon: Icons.history_outlined,
            label: 'Attendance History',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const AttendanceHistoryScreen()),
              );
            },
          ),
          _QuickActionButton(
            icon: Icons.business_outlined,
            label: 'View Companies',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const CompanyListScreen()),
              );
            },
          ),
          _QuickActionButton(
            icon: Icons.work_history_outlined,
            label: 'View Placements',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const PlacementListScreen()),
              );
            },
          ),
          _QuickActionButton(
            icon: Icons.contact_mail_outlined,
            label: 'View Enquiries',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const EnquiryListScreen()),
              );
            },
          ),
          _QuickActionButton(
            icon: Icons.upload_file_outlined,
            label: 'Bulk Import',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const BulkImportScreen()),
              );
            },
          ),
          _QuickActionButton(
            icon: Icons.receipt_long_outlined,
            label: 'Fees Report',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const FeesReportScreen()),
              );
            },
          ),
          _QuickActionButton(
            icon: Icons.insights_outlined,
            label: 'Analytics',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  settings: const RouteSettings(name: NavIds.analytics),
                  builder: (context) => const AnalyticsScreen(),
                ),
              );
            },
          ),
          _QuickActionButton(
            icon: Icons.warning_amber_outlined,
            label: 'At-Risk Trainees',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  settings: const RouteSettings(name: NavIds.atRisk),
                  builder: (context) => const AtRiskScreen(),
                ),
              );
            },
          ),
          _QuickActionButton(
            icon: Icons.question_answer_outlined,
            label: 'Ask Your Data',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  settings: const RouteSettings(name: NavIds.askData),
                  builder: (context) => const AskDataScreen(),
                ),
              );
            },
          ),
          _QuickActionButton(
            icon: Icons.notifications_outlined,
            label: 'Notifications',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  settings: const RouteSettings(name: NavIds.notifications),
                  builder: (context) => const NotificationsScreen(),
                ),
              );
            },
          ),
          _QuickActionButton(
            icon: Icons.account_circle_outlined,
            label: 'My Profile',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const ProfileScreen()),
              );
            },
          ),
        ];
      case 'trainer':
        return [
          _QuickActionButton(
            icon: Icons.fact_check_outlined,
            label: 'Mark Attendance',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const MarkAttendanceScreen(trainerOnly: true)),
              );
            },
          ),
          _QuickActionButton(
            icon: Icons.list_alt_outlined,
            label: 'View Trainees',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const StudentListScreen(trainerOnly: true)),
              );
            },
          ),
          _QuickActionButton(
            icon: Icons.history_outlined,
            label: 'Attendance History',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const AttendanceHistoryScreen(trainerOnly: true)),
              );
            },
          ),
          _QuickActionButton(
            icon: Icons.account_circle_outlined,
            label: 'My Profile',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const ProfileScreen()),
              );
            },
          ),
        ];
      case 'placementOfficer':
        return [
          _QuickActionButton(
            icon: Icons.add_business_outlined,
            label: 'Add Company',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const AddCompanyScreen()),
              );
            },
          ),
          _QuickActionButton(
            icon: Icons.list_alt_outlined,
            label: 'View Companies',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const CompanyListScreen()),
              );
            },
          ),
          _QuickActionButton(
            icon: Icons.person_add_alt_outlined,
            label: 'Add Placement',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const AddPlacementScreen()),
              );
            },
          ),
          _QuickActionButton(
            icon: Icons.work_history_outlined,
            label: 'View Placements',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const PlacementListScreen()),
              );
            },
          ),
          _QuickActionButton(
            icon: Icons.account_circle_outlined,
            label: 'My Profile',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const ProfileScreen()),
              );
            },
          ),
        ];
      case 'mobilizer':
        return [
          _QuickActionButton(
            icon: Icons.person_add_alt_outlined,
            label: 'Add Enquiry',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => AddEnquiryScreen(currentUserRole: role)),
              );
            },
          ),
          _QuickActionButton(
            icon: Icons.contact_mail_outlined,
            label: 'View Enquiries',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const EnquiryListScreen()),
              );
            },
          ),
          _QuickActionButton(
            icon: Icons.list_alt_outlined,
            label: 'View Registered Trainees',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const StudentListScreen()),
              );
            },
          ),
          _QuickActionButton(
            icon: Icons.account_circle_outlined,
            label: 'My Profile',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const ProfileScreen()),
              );
            },
          ),
        ];
      default:
        return [];
    }
  }
}

// ---------------- ADMIN OVERVIEW (real auto-calculated stats) ----------------
class _AdminOverview extends StatelessWidget {
  final VoidCallback onViewStudents;
  const _AdminOverview({required this.onViewStudents});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('students').snapshots(),
      builder: (context, studentSnap) {
        final studentDocs = studentSnap.data?.docs ?? [];
        final totalStudents = studentSnap.hasData ? studentDocs.length.toString() : '--';
        int joined = 0, completed = 0, dropped = 0;
        for (final doc in studentDocs) {
          final status = (doc.data() as Map<String, dynamic>)['status'] ?? '';
          if (status == 'Joined' || status == 'Ongoing' || status == 'Completed') joined++;
          if (status == 'Completed') completed++;
          if (status == 'Dropped') dropped++;
        }
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('enquiries').snapshots(),
          builder: (context, enquirySnap) {
            final totalEnquiries = enquirySnap.hasData ? enquirySnap.data!.docs.length.toString() : '--';
            return StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('placements').snapshots(),
              builder: (context, placementSnap) {
                int placedCount = 0;
                if (placementSnap.hasData) {
                  for (final doc in placementSnap.data!.docs) {
                    final status = (doc.data() as Map<String, dynamic>)['status'];
                    if (status == 'Joined' || status == 'Selected' || status == 'Self-Employed') {
                      placedCount++;
                    }
                  }
                }
                return GridView(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  // Max ~220 chaude cards: phone par 2, desktop par 5-6 ek line me
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 220,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                    childAspectRatio: 1.25,
                  ),
                  children: [
                    _DashboardCard(
                      icon: Icons.contact_mail_outlined,
                      label: 'Total Enquiries',
                      value: totalEnquiries,
                      color: AppColors.teal,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (context) => const EnquiryListScreen()),
                        );
                      },
                    ),
                    _DashboardCard(
                      icon: Icons.groups_outlined,
                      label: 'Total Trainees',
                      value: totalStudents,
                      color: AppColors.appPrimary,
                      onTap: onViewStudents,
                    ),
                    _DashboardCard(
                      icon: Icons.how_to_reg_outlined,
                      label: 'Joined',
                      value: joined.toString(),
                      color: AppColors.teal,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const StudentListScreen(
                              filterStatuses: ['Joined', 'Ongoing', 'Completed'],
                              screenTitle: 'Joined Trainees',
                            ),
                          ),
                        );
                      },
                    ),
                    _DashboardCard(
                      icon: Icons.verified_outlined,
                      label: 'Completed',
                      value: completed.toString(),
                      color: AppColors.appPrimary,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const StudentListScreen(
                              filterStatuses: ['Completed'],
                              screenTitle: 'Completed Trainees',
                            ),
                          ),
                        );
                      },
                    ),
                    _DashboardCard(
                      icon: Icons.person_off_outlined,
                      label: 'Dropped',
                      value: dropped.toString(),
                      color: AppColors.teal,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const StudentListScreen(
                              filterStatuses: ['Dropped'],
                              screenTitle: 'Dropped Trainees',
                            ),
                          ),
                        );
                      },
                    ),
                    _DashboardCard(
                      icon: Icons.work_outline,
                      label: 'Placed',
                      value: placedCount.toString(),
                      color: AppColors.appPrimary,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (context) => const PlacementListScreen()),
                        );
                      },
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }
}

// ---------------- TRAINER OVERVIEW ----------------
class _TrainerOverview extends StatelessWidget {
  final String? trainerUid;
  const _TrainerOverview({required this.trainerUid});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('batches')
          .where('trainerId', isEqualTo: trainerUid)
          .snapshots(),
      builder: (context, snapshot) {
        final myBatches = snapshot.hasData ? snapshot.data!.docs.length.toString() : '--';
        return GridView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          // Max ~220 chaude cards: phone par 2, desktop par 5-6 ek line me
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 220,
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
            childAspectRatio: 1.25,
          ),
          children: [
            _DashboardCard(
              icon: Icons.class_outlined,
              label: 'My Batches',
              value: myBatches,
              color: AppColors.appPrimary,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => const BatchListScreen(trainerOnly: true)),
                );
              },
            ),
            _DashboardCard(
              icon: Icons.event_available_outlined,
              label: "Today's Attendance",
              value: '--',
              color: AppColors.teal,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => const AttendanceHistoryScreen(trainerOnly: true)),
                );
              },
            ),
          ],
        );
      },
    );
  }
}

// ---------------- MOBILIZER OVERVIEW ----------------
class _MobilizerOverview extends StatelessWidget {
  const _MobilizerOverview();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('enquiries')
          .snapshots(),
      builder: (context, snapshot) {
        // Mobilizer saari enquiries dekhta hai (koi createdBy filter nahi)
        final allDocs = snapshot.data?.docs ?? [];
        final totalEnquiries = snapshot.hasData ? allDocs.length.toString() : '--';
        int pendingFollowUp = 0;
        int registered = 0;
        for (final doc in allDocs) {
          final status = (doc.data() as Map<String, dynamic>)['followUpStatus'];
          if (status == 'Follow-up' || status == 'New') pendingFollowUp++;
          if (status == 'Registered') registered++;
        }
        return GridView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          // Max ~220 chaude cards: phone par 2, desktop par 5-6 ek line me
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 220,
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
            childAspectRatio: 1.25,
          ),
          children: [
            _DashboardCard(
              icon: Icons.contact_mail_outlined,
              label: 'Enquiries',
              value: totalEnquiries,
              color: AppColors.appPrimary,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => const EnquiryListScreen()),
                );
              },
            ),
            _DashboardCard(
              icon: Icons.pending_actions_outlined,
              label: 'Pending Follow-up',
              value: pendingFollowUp.toString(),
              color: AppColors.teal,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const EnquiryListScreen(
                      filterStatuses: ['New', 'Follow-up'],
                    ),
                  ),
                );
              },
            ),
            _DashboardCard(
              icon: Icons.how_to_reg_outlined,
              label: 'Registered',
              value: registered.toString(),
              color: AppColors.appPrimary,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const EnquiryListScreen(
                      filterStatuses: ['Registered'],
                    ),
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }
}

class _DashboardCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final VoidCallback? onTap;
  const _DashboardCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        clipBehavior: Clip.hardEdge,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const Spacer(),
            Text(
              value,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          children: [
            Icon(icon, color: AppColors.appPrimary, size: 24),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}