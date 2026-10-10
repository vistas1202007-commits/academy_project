import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'login_screen.dart';
import 'help_screen.dart';
import 'about_screen.dart';
import 'report_list_screen.dart';
import 'analytics_screen.dart';

/// Menu items ke ids. Menu se khule route ka RouteSettings.name yahi hota
/// hai, taaki sidebar kholi hui screen highlight kar sake.
class NavIds {
  NavIds._();

  static const String dashboard = 'dashboard';
  static const String reports = 'reports';
  static const String analytics = 'analytics';
  static const String help = 'help';
  static const String about = 'about';

  static const Set<String> all = {dashboard, reports, analytics, help, about};
}

class NavItem {
  final String id;
  final String label;
  final IconData icon;

  /// null = Dashboard (wahan tak wapas jaana hi kaafi hai)
  final WidgetBuilder? builder;

  const NavItem({required this.id, required this.label, required this.icon, this.builder});

  Route<void> route() => MaterialPageRoute(
    settings: RouteSettings(name: id),
    builder: builder!,
  );
}

/// Phone ka drawer aur desktop ka sidebar dono yahi list dikhate hain
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

/// "Logout?" poochta hai; haan par sign out karke Login par le jata hai
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
