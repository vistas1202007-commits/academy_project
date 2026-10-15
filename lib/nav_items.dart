import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'login_screen.dart';
import 'help_screen.dart';
import 'about_screen.dart';
import 'report_list_screen.dart';
import 'analytics_screen.dart';
import 'at_risk_screen.dart';
import 'ask_data_screen.dart';
import 'notifications_screen.dart';
import 'recycle_bin_screen.dart';

/// Menu item ids. A route opened from the menu uses this as its
/// RouteSettings.name, so the sidebar can highlight the open screen.
class NavIds {
  NavIds._();

  static const String dashboard = 'dashboard';
  static const String reports = 'reports';
  static const String analytics = 'analytics';
  static const String atRisk = 'atRisk';
  static const String askData = 'askData';
  static const String notifications = 'notifications';
  static const String recycleBin = 'recycleBin';
  static const String help = 'help';
  static const String about = 'about';

  static const Set<String> all = {dashboard, reports, analytics, atRisk, askData, notifications, recycleBin, help, about};
}

class NavItem {
  final String id;
  final String label;
  final IconData icon;

  /// null = Dashboard (popping back to it is enough)
  final WidgetBuilder? builder;

  const NavItem({required this.id, required this.label, required this.icon, this.builder});

  Route<void> route() => MaterialPageRoute(
    settings: RouteSettings(name: id),
    builder: builder!,
  );
}

/// Both the phone drawer and the desktop sidebar show this list
List<NavItem> navItemsFor(String role) => [
  const NavItem(id: NavIds.dashboard, label: 'Dashboard', icon: Icons.dashboard_outlined),
  if (role == 'admin' || role == 'mobilizer')
    NavItem(
      id: NavIds.reports,
      label: 'Reports',
      icon: Icons.description_outlined,
      builder: (context) => const ReportListScreen(),
    ),
  if (role == 'admin')
    NavItem(
      id: NavIds.analytics,
      label: 'Analytics',
      icon: Icons.insights_outlined,
      builder: (context) => const AnalyticsScreen(),
    ),
  if (role == 'admin')
    NavItem(
      id: NavIds.atRisk,
      label: 'At-Risk Trainees',
      icon: Icons.warning_amber_outlined,
      builder: (context) => const AtRiskScreen(),
    ),
  if (role == 'admin')
    NavItem(
      id: NavIds.askData,
      label: 'Ask Your Data',
      icon: Icons.question_answer_outlined,
      builder: (context) => const AskDataScreen(),
    ),
  if (role == 'admin')
    NavItem(
      id: NavIds.notifications,
      label: 'Notifications',
      icon: Icons.notifications_outlined,
      builder: (context) => const NotificationsScreen(),
    ),
  if (role == 'admin')
    NavItem(
      id: NavIds.recycleBin,
      label: 'Recycle Bin',
      icon: Icons.delete_sweep_outlined,
      builder: (context) => const RecycleBinScreen(),
    ),
  NavItem(
    id: NavIds.help,
    label: 'Help & User Guide',
    icon: Icons.help_outline,
    builder: (context) => const HelpScreen(),
  ),
  NavItem(id: NavIds.about, label: 'About', icon: Icons.info_outline, builder: (context) => const AboutScreen()),
];

String roleLabelFor(String role) {
  switch (role) {
    case 'admin':
      return 'Admin';
    case 'trainer':
      return 'Trainer';
    case 'placementOfficer':
      return 'Placement Officer';
    case 'mobilizer':
      return 'Mobilizer';
    default:
      return 'Staff';
  }
}

/// Asks "Logout?"; on yes, signs out and goes to Login
Future<void> confirmLogout(BuildContext context) async {
  final confirm = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      title: const Text('Logout?'),
      content: const Text('Are you sure you want to logout?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text('Cancel', style: TextStyle(color: Colors.grey[700])),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: const Text('Logout', style: TextStyle(color: Colors.white)),
        ),
      ],
    ),
  );
  if (confirm != true) return;
  await FirebaseAuth.instance.signOut();
  if (context.mounted) {
    Navigator.of(
      context,
    ).pushAndRemoveUntil(MaterialPageRoute(builder: (context) => const LoginScreen()), (route) => false);
  }
}
