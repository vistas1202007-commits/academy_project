import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'responsive.dart';
import 'ui_kit.dart';

/// Labels for the role chips
const String _all = 'All roles';
const String _admin = 'Admin';
const String _trainer = 'Trainer';
const String _po = 'Placement Officer';
const String _mob = 'Mobilizer';

class _HelpItem {
  final String title;
  final String body;
  const _HelpItem(this.title, this.body);

  bool matches(String q) => title.toLowerCase().contains(q) || body.toLowerCase().contains(q);
}

class _HelpSection {
  final String title;
  final IconData icon;
  final List<String> roles;
  final List<_HelpItem> items;

  /// The role matrix table appears only in the Roles section
  final bool showRoleMatrix;

  const _HelpSection(this.title, this.icon, this.roles, this.items, {this.showRoleMatrix = false});
}

/// Role matrix: feature, then Admin / Trainer / Placement Officer / Mobilizer
const List<List<String>> _roleMatrix = [
  ['Dashboard, My Profile, Help', '✓', '✓', '✓', '✓'],
  ['Add / edit / delete trainees', '✓', '—', '—', '—'],
  ['View trainees', 'All', 'Own batches', '—', 'View only'],
  ['Create batches', '✓', '—', '—', '—'],
  ['Mark / edit attendance', '✓', 'Own batches', '—', '—'],
  ['Delete attendance', '✓', '—', '—', '—'],
  ['Enquiries (add, follow-up, convert)', '✓', '—', '—', '✓'],
  ['Add / edit companies and placements', '✓', '—', '✓', '—'],
  ['Delete enquiries, placements, companies', '✓', '—', '—', '—'],
  ['Fees Report, Download Receipt', '✓', '—', '—', '—'],
  ['Reports (view / add)', '✓', '—', '—', '✓'],
  ['Edit / delete reports', '✓', '—', '—', '—'],
  ['Analytics, At-Risk, Ask Your Data', '✓', '—', '—', '—'],
  ['Staff, Bulk Import, Notifications', '✓', '—', '—', '—'],
  ['Recycle Bin (restore, delete forever)', '✓', '—', '—', '—'],
];

const List<_HelpSection> _sections = [
  _HelpSection('Getting started', Icons.rocket_launch_outlined, [_all], [
    _HelpItem('Who can log in',
        'Only staff accounts created by the Admin can log in. There is no public sign-up. Each account has one role: Admin, Trainer, Placement Officer or Mobilizer.'),
    _HelpItem('Sign in with Email and Password',
        'Email and Password is the main way to sign in. Enter the email and password given to you by your Admin on the Login screen.'),
    _HelpItem('Mobile OTP and Google sign-in',
        'These only work for accounts that have linked them in My Profile → Login Options, and only where these providers are enabled. They are not available in the public demo; use Email and Password there.'),
    _HelpItem('Forgot password',
        'On the Login screen tap "Forgot password?", enter your email and tap Send Link. If an account exists for that email, a reset link is sent. Check your Spam folder too.'),
    _HelpItem('Fingerprint / Face Lock',
        'My Profile → Login Options → turn on Fingerprint / Face Lock (on supported phones). The app then asks to unlock when it opens, and again after it has been in the background for more than 30 seconds.'),
    _HelpItem('Navigation',
        'Use the Quick Actions on the Dashboard, or the side menu (☰ on phone, sidebar on desktop) for Reports, Analytics, Help and other screens. Menu items depend on your role.'),
    _HelpItem('My Profile',
        'Dashboard → My Profile shows your details. Tap the edit icon to update your own name, phone, address and education. Only the Admin can change your role or account status.'),
    _HelpItem('Deactivated account',
        'If login says your account is deactivated, contact your Admin to reactivate it.'),
  ]),
  _HelpSection('Roles', Icons.badge_outlined, [_all], [
    _HelpItem('Admin', 'Full access: trainees, batches, attendance, fees, staff, imports, analytics, insights and the Recycle Bin.'),
    _HelpItem('Trainer', 'Marks and edits attendance and views trainees for the batches assigned to them ("My Batches").'),
    _HelpItem('Placement Officer', 'Adds and edits companies and placements. Deleting is done by the Admin.'),
    _HelpItem('Mobilizer', 'Adds and follows up enquiries, converts them into trainees, views registered trainees and adds reports.'),
  ], showRoleMatrix: true),
  _HelpSection('Trainees', Icons.school_outlined, [_admin, _trainer, _mob], [
    _HelpItem('Add a trainee',
        'Dashboard → Add Trainee → fill personal and guardian details, choose Course and Batch, status and fees → Save. A Trainee ID like VIS-2026-0001 is created automatically.'),
    _HelpItem('Find a trainee',
        'View Trainees → search by name, phone, Trainee ID, village or batch. Tap a trainee to open the full profile. Trainers see only their own batches; Mobilizers see the list as View Registered Trainees (view only).'),
    _HelpItem('Edit or delete',
        'Only the Admin can edit a trainee (Trainee Profile → Edit Trainee) or delete one (delete icon in the list). A deleted trainee moves to the Recycle Bin; their attendance and placements are kept. Statuses: Registered, Joined, Ongoing, Completed, Dropped.'),
    _HelpItem('Bulk import',
        'Admin: Dashboard → Bulk Import → Import Trainees → select the Enrollment & Fees Excel (.xlsx). Row 1 is the title, row 2 the header, data starts at row 3. Batch is read from column D (sheet name if empty). Warnings, skipped and failed rows are listed after the import. A row whose phone number belongs to a trainee in the Recycle Bin is skipped; restore that trainee or delete it forever first.'),
    _HelpItem('Undo an import',
        'Right after an import, tap "Undo This Import" on the Bulk Import screen. It permanently removes only the records added in that run (they do not go to the Recycle Bin). The button is available until you leave the screen or start a new import.'),
  ]),
  _HelpSection('Batches and attendance', Icons.event_available_outlined, [_admin, _trainer], [
    _HelpItem('Create a batch',
        'Admin: Dashboard → Add Batch → batch name, Course, Trainer, timing, start and end dates → Save. View Batches lists all batches; tap one to see its trainees.'),
    _HelpItem('Mark attendance',
        'Dashboard → Mark Attendance → choose Batch and Date → mark each trainee P (Present), A (Absent) or L (Leave), or use Mark all present → Save. Trainers only see their own batches.'),
    _HelpItem('Attendance history and corrections',
        'Attendance History → choose a batch → tap the edit icon on a date to reopen it with the existing marks.'),
    _HelpItem('Delete an attendance record',
        'Only the Admin sees the delete icon in Attendance History. Attendance deletes are permanent; they do not go to the Recycle Bin.'),
  ]),
  _HelpSection('Enquiries', Icons.support_agent_outlined, [_mob, _admin], [
    _HelpItem('Add an enquiry', 'Mobilizer: Dashboard → Add Enquiry → enquirer details and Course Interested → Save.'),
    _HelpItem('Follow up',
        'View Enquiries → filter by status (New / Follow-up / Registered / Not Interested) → tap an enquiry → update notes and status → Save Update. Everyone with access sees all enquiries.'),
    _HelpItem('Convert to a trainee',
        'Open an enquiry → Convert to Registration. A trainee record with a new Trainee ID is created and the enquiry is marked Registered.'),
    _HelpItem('Delete an enquiry', 'Admin: open an enquiry → Delete Enquiry. It moves to the Recycle Bin.'),
  ]),
  _HelpSection('Placements and companies', Icons.work_outline, [_po, _admin], [
    _HelpItem('Add a company', 'Dashboard → Add Company (or + on View Companies) → name, contact person, phone, location → Save.'),
    _HelpItem('Record a placement',
        'Dashboard → Add Placement → trainee, company, course, job details, salary, joining date and status (Not Placed / Interview Scheduled / Selected / Joined / Rejected / Self-Employed / Not Joined) → Save.'),
    _HelpItem('Edit or delete',
        'View Placements → tap a record → Edit Placement. Only the Admin sees Delete Placement at the bottom of the edit screen; it moves the record to the Recycle Bin.'),
    _HelpItem('Delete a company', 'Admin: View Companies → edit a company → Delete Company. It moves to the Recycle Bin.'),
    _HelpItem('Import placements',
        'Admin: Bulk Import → Import Placement Records → select the Placement Excel ("Trainees Details" sheet). New companies in the file are created automatically, and "Undo This Import" works the same way as for trainees. If a company in the file is in the Recycle Bin, no new company is created; the placement is still imported with a warning.'),
  ]),
  _HelpSection('Fees and receipts', Icons.currency_rupee, [_admin], [
    _HelpItem('Record fees',
        'When adding or editing a trainee, enter Total Course Fee and Fee Paid So Far. The pending amount is calculated automatically.'),
    _HelpItem('Fees Report', 'Dashboard → Fees Report shows total collected and pending, with search to find trainees with dues.'),
    _HelpItem('Download Receipt',
        'Trainee Profile → Fees card → Download Receipt creates a PDF fee receipt you can save or share. Only the Admin sees this button.'),
    _HelpItem('No online payments', 'The app only records fees. Payments are collected outside the app.'),
  ]),
  _HelpSection('Analytics and reports', Icons.insights_outlined, [_admin, _mob], [
    _HelpItem('Analytics (Admin)',
        'Menu → Analytics: enrollment trend, course-wise trainees, gender, villages, enquiry → placement funnel, fees by batch, attendance, salaries and top companies. Pick a Date Range at the top.'),
    _HelpItem('Export Excel', 'On Analytics tap Export Excel to save the summary sheets as an Excel file.'),
    _HelpItem('Reports (Admin and Mobilizer)',
        'Menu → Reports lists saved reports. Tap + to add one with attachments. Only the Admin can edit or delete reports and attachments.'),
  ]),
  _HelpSection('Insights', Icons.lightbulb_outline, [_admin], [
    _HelpItem('At-Risk Trainees',
        'Menu → At-Risk Trainees scores Joined and Ongoing trainees using the last 28 days of attendance. Each trainee shows the reasons behind the score.'),
    _HelpItem('At-Risk rules',
        'Attendance below 60%: +60, or below 75%: +40. Fees more than 50% pending: +25. Fewer than 5 attendance records in 28 days: +10. Status Joined: +5. Score 60+ = High, 30–59 = Medium, below 30 = Low.'),
    _HelpItem('Notify guardian (simulated)',
        'For High-risk trainees, "Notify guardian (simulated)" logs an alert in Notifications. No real message is sent.'),
    _HelpItem('Ask Your Data',
        'Menu → Ask Your Data → tap a ready-made question to see the answer with a table: trainees at risk, batch with highest dropout %, batch with lowest attendance, fees collected vs pending, course-wise placement %, course-wise average salary, village with most dropouts, enquiry to registration conversion %, top 5 hiring companies, trainees with no attendance record. You cannot type free-form questions.'),
  ]),
  _HelpSection('Admin tools', Icons.admin_panel_settings_outlined, [_admin], [
    _HelpItem('Add staff',
        'Dashboard → Add Staff → name, email, phone, education, address, a temporary password and role → Create Account.'),
    _HelpItem('Manage staff',
        'Dashboard → Staff List → tap a person → Edit Details, Send Password Reset Email, Deactivate / Activate Account, or Delete Account. You cannot deactivate or delete your own account.'),
    _HelpItem('Recycle Bin',
        'Menu → Recycle Bin has four tabs: Trainees, Enquiries, Placements and Companies. Deleted records are hidden from lists, counts, search, charts and alerts, but stay here until you act. Each row shows when it was deleted.'),
    _HelpItem('Restore or delete forever',
        'Restore brings the record back exactly as it was. Delete forever removes it permanently after a confirmation. Nothing is purged automatically.'),
    _HelpItem('What does not go to the Recycle Bin',
        'Deleting attendance records, reports or staff accounts is permanent, and so is "Undo This Import".'),
    _HelpItem('Notifications (simulated)',
        'Menu → Notifications: Generate fee reminders, Generate absent alerts, Batch alert and Daily summary. These only create log records marked "Simulated (not sent)". No SMS or WhatsApp is sent. Trainees without a guardian phone are skipped, and the same alert is not logged twice in a day.'),
    _HelpItem('Bulk Import', 'Dashboard → Bulk Import for trainees and placements from Excel. See Trainees and Placements for file format and undo.'),
  ]),
  _HelpSection('FAQ', Icons.quiz_outlined, [_all], [
    _HelpItem('Why can\'t I see a screen or button?',
        'Screens and buttons depend on your role. Check the role matrix in the Roles section. Admin-only screens show "Access denied" for other roles.'),
    _HelpItem('Mobile OTP or Google login does not work',
        'Sign in with Email and Password first, then link them in My Profile → Login Options. They also need the provider to be enabled, so they do not work in the public demo.'),
    _HelpItem('I did not get the password reset email', 'Check Spam, make sure the email is correct, or ask your Admin to send a reset link from Staff List.'),
    _HelpItem('A trainee is missing from attendance', 'Check that the trainee is assigned to that batch. Only the Admin can change a trainee\'s batch.'),
    _HelpItem('Are notifications sent to guardians?', 'No. Notifications are simulated logs only.'),
    _HelpItem('Can I recover something I deleted?',
        'Deleted trainees, enquiries, placements and companies can be restored by the Admin from Menu → Recycle Bin. Other deletes (attendance, reports, staff) and "Undo This Import" are permanent.'),
    _HelpItem('Why is a trainee missing from lists and charts?',
        'They may be in the Recycle Bin. Ask your Admin to check and restore them.'),
  ]),
];

class HelpScreen extends StatefulWidget {
  const HelpScreen({super.key});

  @override
  State<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends State<HelpScreen> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final q = _query.trim().toLowerCase();
    final visible = <Widget>[];
    for (final section in _sections) {
      final titleHit = q.isNotEmpty && section.title.toLowerCase().contains(q);
      final items = q.isEmpty || titleHit ? section.items : section.items.where((i) => i.matches(q)).toList();
      final matrixHit = section.showRoleMatrix &&
          (q.isEmpty || titleHit || _roleMatrix.any((row) => row.first.toLowerCase().contains(q)));
      if (items.isEmpty && !matrixHit) continue;
      visible.add(_buildSection(section, items, showMatrix: matrixHit, expanded: q.isNotEmpty));
    }

    return Scaffold(
      backgroundColor: AppColors.appBackground,
      appBar: AppBar(
        flexibleSpace: const AppBarRibbon(),
        backgroundColor: AppColors.appPrimary,
        elevation: 0,
        title: const Text('Help & User Guide'),
      ),
      body: PageWash(child: ContentWidth(maxWidth: 1100, child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.appPrimary,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.menu_book_outlined, color: Colors.white, size: 32),
                SizedBox(height: 10),
                Text(
                  'How to use this app',
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 4),
                Text(
                  'Guide by role. Tap a section to open it.',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _searchController,
            onChanged: (v) => setState(() => _query = v),
            decoration: InputDecoration(
              hintText: 'Search help',
              prefixIcon: const Icon(Icons.search, color: AppColors.textMuted),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close, color: AppColors.textMuted),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _query = '');
                      },
                    ),
              filled: true,
              fillColor: AppColors.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.appAccent),
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (visible.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 30),
              child: Center(
                child: Text('No help topics match your search.', style: TextStyle(color: AppColors.textMuted)),
              ),
            )
          else
            ...visible,
          const SizedBox(height: 10),
          const Center(
            child: Text(
              'Need more help? Contact your Admin.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ))),
    );
  }

  Widget _buildSection(_HelpSection section, List<_HelpItem> items, {required bool showMatrix, required bool expanded}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          // The key changes with the search so initiallyExpanded applies again
          key: ValueKey('${section.title}-$expanded'),
          initiallyExpanded: expanded,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          collapsedShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          iconColor: AppColors.appPrimary,
          collapsedIconColor: AppColors.textMuted,
          leading: Icon(section.icon, color: AppColors.appPrimary),
          title: Text(
            section.title,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.appPrimary),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Wrap(spacing: 6, runSpacing: 6, children: section.roles.map(_roleChip).toList()),
          ),
          childrenPadding: const EdgeInsets.fromLTRB(18, 0, 18, 8),
          children: [
            ...items.map(_step),
            if (showMatrix) _matrixTable(),
          ],
        ),
      ),
    );
  }

  Widget _roleChip(String role) {
    final color = role == _admin ? AppColors.appPrimary : AppColors.appAccent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(role, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
    );
  }

  Widget _matrixTable() {
    const header = ['Feature', 'Admin', 'Trainer', 'Placement Officer', 'Mobilizer'];
    Widget cell(String text, {bool bold = false, bool first = false}) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Text(
            text,
            textAlign: first ? TextAlign.left : TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: bold ? FontWeight.w600 : FontWeight.normal,
              color: text == '—' ? AppColors.textMuted : AppColors.textDark,
            ),
          ),
        );
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 640),
          child: Table(
            columnWidths: const {0: FlexColumnWidth(2.4)},
            defaultColumnWidth: const FlexColumnWidth(1),
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
            border: TableBorder.all(color: AppColors.border, borderRadius: BorderRadius.circular(8)),
            children: [
              TableRow(
                decoration: BoxDecoration(color: AppColors.appBackground),
                children: [for (var i = 0; i < header.length; i++) cell(header[i], bold: true, first: i == 0)],
              ),
              for (final row in _roleMatrix)
                TableRow(children: [for (var i = 0; i < row.length; i++) cell(row[i], first: i == 0)]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _step(_HelpItem item) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 6),
            width: 6,
            height: 6,
            decoration: const BoxDecoration(color: AppColors.appAccent, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.title,
                    style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppColors.textDark)),
                const SizedBox(height: 2),
                Text(item.body, style: const TextStyle(fontSize: 12.5, color: AppColors.textMuted, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
