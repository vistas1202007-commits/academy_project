import 'dart:async';

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
import 'soft_delete.dart';
import 'brand.dart';
import 'app_shell.dart';
import 'nav_items.dart';
import 'responsive.dart';
import 'ui_kit.dart';

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
        flexibleSpace: const AppBarRibbon(),
      ),
      body: PageWash(child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Entrance(child: _WelcomeCard(name: name, roleLabel: _roleLabel)),
            const SizedBox(height: 24),
            const SectionHeading('Overview'),
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
                        ? liveDocsOf(placementSnap.data!)
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
                        companySnap.hasData ? liveDocsOf(companySnap.data!).length.toString() : '--';
                        return _StatGrid(
                          children: _staggered([
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
                              color: AppColors.appAccent,
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(builder: (context) => const CompanyListScreen()),
                                );
                              },
                            ),
                          ]),
                        );
                      },
                    );
                  },
                )
              else if (role == 'mobilizer')
                  const _MobilizerOverview(),
            const SizedBox(height: 24),
            if (_actionsForRole(context).isNotEmpty) ...[
              const SectionHeading('Quick Actions'),
              const SizedBox(height: 12),
              // Parent ki width se: phone par 2, desktop par ~180 ke jitne aa jayein
              LayoutBuilder(
                builder: (context, constraints) {
                  final columns = ((constraints.maxWidth + 12) / (180 + 12)).floor().clamp(2, 8);
                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      // Entrance stat cards ke baad se aage chalta hai
                      for (final (i, action) in _actionsForRole(context).indexed)
                        SizedBox(
                          width: (constraints.maxWidth - 12 * (columns - 1)) / columns,
                          child: Entrance(index: _statCardCount + i, child: action),
                        ),
                    ],
                  );
                },
              ),
            ],
          ],
        ),
      )),
    );
  }

  /// Har role ke Overview me kitne stat cards hain (entrance ka stagger)
  int get _statCardCount => switch (role) {
        'admin' => 6,
        'mobilizer' => 3,
        _ => 2,
      };

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
        final allStudentDocs = studentSnap.data?.docs ?? [];
        final studentDocs = allStudentDocs.where((d) => isLive(d.data() as Map<String, dynamic>?)).toList();
        // Bin wale trainees ki placements "Placed" me nahi ginti
        final binnedTraineeIds = deletedTraineeIds(allStudentDocs.map((d) => d.data() as Map<String, dynamic>));
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
            final totalEnquiries = enquirySnap.hasData ? liveDocsOf(enquirySnap.data!).length.toString() : '--';
            return StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('placements').snapshots(),
              builder: (context, placementSnap) {
                int placedCount = 0;
                if (placementSnap.hasData) {
                  for (final doc in placementSnap.data!.docs) {
                    final p = doc.data() as Map<String, dynamic>;
                    if (!isCountablePlacement(p, binnedTraineeIds)) continue;
                    final status = p['status'];
                    if (status == 'Joined' || status == 'Selected' || status == 'Self-Employed') {
                      placedCount++;
                    }
                  }
                }
                return _StatGrid(
                  children: _staggered([
                    _DashboardCard(
                      icon: Icons.contact_mail_outlined,
                      label: 'Total Enquiries',
                      value: totalEnquiries,
                      color: AppColors.appAccent,
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
                      label: 'Enrolled',
                      value: joined.toString(),
                      color: AppColors.appAccent,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const StudentListScreen(
                              filterStatuses: ['Joined', 'Ongoing', 'Completed'],
                              screenTitle: 'Enrolled Trainees',
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
                      color: AppColors.appAccent,
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
                  ]),
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
        return _StatGrid(
          children: _staggered([
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
            _TodayAttendanceCard(
              batchIds: snapshot.hasData ? snapshot.data!.docs.map((d) => d.id).toList() : null,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => const AttendanceHistoryScreen(trainerOnly: true)),
                );
              },
            ),
          ]),
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
        final allDocs = snapshot.hasData ? liveDocsOf(snapshot.data!) : <QueryDocumentSnapshot>[];
        final totalEnquiries = snapshot.hasData ? allDocs.length.toString() : '--';
        int pendingFollowUp = 0;
        int registered = 0;
        for (final doc in allDocs) {
          final status = (doc.data() as Map<String, dynamic>)['followUpStatus'];
          if (status == 'Follow-up' || status == 'New') pendingFollowUp++;
          if (status == 'Registered') registered++;
        }
        return _StatGrid(
          children: _staggered([
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
              color: AppColors.appAccent,
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
          ]),
        );
      },
    );
  }
}

/// Overview ke stat cards. Phone par pehle jaisa (max 220 chaude); desktop par
/// columns aise ki aakhri line me ek card akela na bache (6 = 6, 3+3, 2+2+2).
class _StatGrid extends StatelessWidget {
  final List<Widget> children;
  const _StatGrid({required this.children});

  static const double _gap = 14;
  static const double _minCard = 150;
  static const double _maxCard = 240;
  static const double _aspect = 1.25;

  /// Jitne fit hon unme se: sab ek line me, warna sabse bada barabar bantwara,
  /// warna aisa jisme aakhri line me akela card na ho
  static int _columns(int count, int fit) {
    if (count <= fit) return count;
    for (var c = fit; c >= 2; c--) {
      if (count % c == 0) return c;
    }
    for (var c = fit; c >= 2; c--) {
      if (count % c != 1) return c;
    }
    return fit;
  }

  @override
  Widget build(BuildContext context) {
    if (!isDesktop(context)) {
      return GridView(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 220,
          crossAxisSpacing: _gap,
          mainAxisSpacing: _gap,
          childAspectRatio: _aspect,
        ),
        children: children,
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final fit = ((width + _gap) / (_minCard + _gap)).floor().clamp(1, 99);
        final columns = _columns(children.length, fit).clamp(1, 99);
        final card = ((width - _gap * (columns - 1)) / columns).clamp(0.0, _maxCard);
        return Align(
          alignment: Alignment.centerLeft,
          child: SizedBox(
            width: card * columns + _gap * (columns - 1),
            child: GridView(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                crossAxisSpacing: _gap,
                mainAxisSpacing: _gap,
                childAspectRatio: _aspect,
              ),
              children: children,
            ),
          ),
        );
      },
    );
  }
}

/// Grid ke cards ek ke baad ek (50ms gap) aate hain
List<Widget> _staggered(List<Widget> cards) => [
      for (final (i, card) in cards.indexed) Entrance(index: i, child: card),
    ];

class _WelcomeCard extends StatelessWidget {
  final String name;
  final String roleLabel;
  const _WelcomeCard({required this.name, required this.roleLabel});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.night, AppColors.appPrimary],
        ),
        boxShadow: [
          BoxShadow(color: AppColors.night.withValues(alpha: 0.18), blurRadius: 16, offset: const Offset(0, 6)),
        ],
      ),
      child: Stack(
        children: [
          const Positioned.fill(child: IgnorePointer(child: CustomPaint(painter: AuroraRibbonPainter(opacity: 0.6)))),
          // Kone me chhota pahaad, bahut halka
          Positioned(
            right: 12,
            bottom: 0,
            child: IgnorePointer(
              child: Opacity(
                opacity: 0.10,
                child: Image.asset(
                  BrandAssets.mountainGlyph,
                  height: 90,
                  color: Colors.white,
                  colorBlendMode: BlendMode.srcIn,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Welcome back', style: TextStyle(color: Colors.white70, fontSize: 14)),
                const SizedBox(height: 4),
                Text(
                  name,
                  style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.aurora.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.aurora.withValues(alpha: 0.35), width: 0.5),
                  ),
                  child: Text(
                    roleLabel,
                    style: const TextStyle(color: AppColors.aurora, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Trainer ke batches ki aaj ki attendance: present (Present/Late) / marked
/// (Present/Late/Absent). Leave jaise baaki status dono me nahi gine jaate.
class _TodayAttendanceCard extends StatefulWidget {
  /// null = batches abhi load ho rahe hain
  final List<String>? batchIds;
  final VoidCallback onTap;
  const _TodayAttendanceCard({required this.batchIds, required this.onTap});

  @override
  State<_TodayAttendanceCard> createState() => _TodayAttendanceCardState();
}

class _TodayAttendanceCardState extends State<_TodayAttendanceCard> {
  /// whereIn me ek baar me 30 se zyada id nahi ja sakti
  static const _chunk = 30;

  final _subs = <StreamSubscription<QuerySnapshot>>[];
  final _chunkDocs = <int, List<QueryDocumentSnapshot>>{};
  String? _key;

  @override
  void initState() {
    super.initState();
    _subscribe();
  }

  @override
  void didUpdateWidget(_TodayAttendanceCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    _subscribe();
  }

  /// Batch ids badle tabhi dobara subscribe
  void _subscribe() {
    final ids = widget.batchIds;
    if (ids == null) return;
    final key = ([...ids]..sort()).join(',');
    if (key == _key) return;
    _key = key;
    _cancel();
    _chunkDocs.clear();
    for (var start = 0, n = 0; start < ids.length; start += _chunk, n++) {
      final part = ids.sublist(start, (start + _chunk).clamp(0, ids.length));
      final index = n;
      _subs.add(FirebaseFirestore.instance
          .collection('attendance')
          .where('batchId', whereIn: part)
          .snapshots()
          .listen((snap) {
        if (mounted) setState(() => _chunkDocs[index] = snap.docs);
      }, onError: (Object _) {}));
    }
  }

  void _cancel() {
    for (final s in _subs) {
      s.cancel();
    }
    _subs.clear();
  }

  @override
  void dispose() {
    _cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ids = widget.batchIds;
    final chunks = ids == null ? 0 : (ids.length + _chunk - 1) ~/ _chunk;
    final loading = ids == null || _chunkDocs.length < chunks;

    var value = '--';
    String? subtitle;
    if (!loading) {
      final now = DateTime.now();
      var records = 0, present = 0, marked = 0;
      for (final docs in _chunkDocs.values) {
        for (final doc in docs) {
          final d = doc.data() as Map<String, dynamic>;
          final date = d['date'];
          if (date is! Timestamp) continue;
          final t = date.toDate();
          if (t.year != now.year || t.month != now.month || t.day != now.day) continue;
          records++;
          final map = d['statusMap'];
          if (map is! Map) continue;
          for (final v in map.values) {
            final status = (v ?? '').toString().trim().toLowerCase();
            if (status == 'present' || status == 'late') {
              present++;
              marked++;
            } else if (status == 'absent') {
              marked++;
            }
          }
        }
      }
      if (records == 0) {
        value = 'Not marked yet';
      } else {
        value = marked == 0 ? '--' : '${(present * 100 / marked).round()}%';
        subtitle = '$present of $marked present';
      }
    }

    return _DashboardCard(
      icon: Icons.event_available_outlined,
      label: "Today's Attendance",
      value: value,
      subtitle: subtitle,
      color: AppColors.appAccent,
      onTap: widget.onTap,
    );
  }
}

class _DashboardCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String? subtitle;
  final Color color;
  final VoidCallback? onTap;
  const _DashboardCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // "Not marked yet" jaisi text value chhoti dikhti hai
    final isText = !RegExp(r'^[\d-]').hasMatch(value);
    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.mintChipStart, AppColors.mintChipEnd],
              ),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const Spacer(),
          CountUpText(
            value,
            style: TextStyle(fontSize: isText ? 15 : 24, fontWeight: FontWeight.bold, color: color, height: 1.15),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle == null ? label : '$label · $subtitle',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
        ],
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
    return Material(
      color: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: AppCard.radius,
        side: BorderSide(color: AppColors.border, width: 0.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
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
      ),
    );
  }
}
