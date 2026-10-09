import 'package:flutter/material.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  static const Color primaryGreen = Color(0xFF1B6B4A);
  static const Color accentGold = Color(0xFFD4AF37);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F5),
      appBar: AppBar(
        backgroundColor: primaryGreen,
        elevation: 0,
        title: const Text('Help & User Guide'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: primaryGreen,
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
                  'A complete guide for every role',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          _section('🔑 Getting Started', [
            _step('Who can log in',
                'Only staff accounts created by the Admin can log in — there is no public sign-up. Each account belongs to one role: Admin, Trainer, Placement Officer, or Mobilizer.'),
            _step('Login with Mobile OTP or Google',
                'First log in with your email once. Then open My Profile → Login Options and link your mobile number (verified by OTP) and/or your Google account. After that, you can use "Login with Mobile OTP" or "Continue with Google" on the Login screen.'),
            _step('Fingerprint / Face lock',
                'My Profile → Login Options → turn on Fingerprint / Face Lock. The app will then ask for your fingerprint (or phone PIN) when it opens, and again if it was in the background for more than 30 seconds.'),
            _step('Forgot your password?',
                'On the Login screen, tap "Forgot Password?" → enter your email → check your inbox (and Spam folder) for the reset link.'),
            _step('Deactivated account',
                'If your account shows as deactivated when logging in, contact your Admin to reactivate it.'),
          ]),

          _section('👤 My Profile', [
            _step('View your profile',
                'Open the side menu (☰ icon top-left) → "My Profile" to see your name, role, email, phone, education, address, and (for Trainers) your assigned batch.'),
            _step('Update your own details',
                'On your Profile screen, tap "Edit Profile" to update your name, phone, address, and education yourself at any time.'),
            _step('Changing your role or account status',
                'Your role and account status (active/inactive) can only be changed by the Admin, for security reasons.'),
          ]),

          _section('👥 Managing Staff Accounts (Admin only)', [
            _step('Add a new staff member',
                'Dashboard → "Add Staff" → fill Name, Email, Phone, Education, Address, set a temporary Password (at least 8 characters, with letters and numbers), choose their Role (Trainer / Placement Officer / Mobilizer / Admin) → Create Account.'),
            _step('View or edit staff details',
                'Dashboard → "Staff List" → tap any staff member to view their details, edit their information, or change their role.'),
            _step('Deactivate or reactivate an account',
                'Open Staff List → tap the staff member → "Deactivate Account" (or "Activate Account"). A deactivated account cannot log in until reactivated. You cannot deactivate your own account.'),
            _step('Reset a staff member\'s password',
                'Open Staff List → tap their name → "Send Password Reset Email". They will receive a link on their registered email to set a new password.'),
            _step('Remove a staff account',
                'Open Staff List → tap the staff member → "Delete Account". This permanently removes their access. You cannot delete your own account this way.'),
          ]),

          _section('🎓 Managing Trainees', [
            _step('Add a new trainee',
                'Dashboard → "Add Trainee" → fill in personal and guardian details, select the Course and Batch from the dropdown lists, and optionally enter fee details → Save. A Trainee ID (e.g. VIS-2026-0001) is generated automatically.'),
            _step('View all trainees',
                'Dashboard → "View Trainees" → search by name, phone, Trainee ID, village, or batch, and tap any trainee to open their full profile.'),
            _step('Edit a trainee or update their status',
                'Open a trainee\'s profile → Edit → update details, change their status (Registered / Joined / Ongoing / Completed / Dropped), or update their fee record.'),
            _step('Removing a trainee record',
                'Only the Admin can edit or delete a trainee record.'),
          ]),

          _section('📚 Managing Batches', [
            _step('Create a batch',
                'Dashboard → "Add Batch" → enter a batch name, select the Course from the dropdown, assign a Trainer, set the timing and start/end dates → Save.'),
            _step('View batches',
                'Dashboard → "View Batches" → see all batches along with their trainer, dates, and trainee count. Tap a batch to see the full list of trainees assigned to it.'),
          ]),

          _section('✅ Attendance', [
            _step('Mark attendance',
                'Dashboard → "Mark Attendance" → select a Batch and Date → mark each trainee Present / Absent / Leave → Save Attendance.'),
            _step('View attendance history',
                'Dashboard → "Attendance History" → select a batch to see past attendance records.'),
            _step('Correcting attendance',
                'From Attendance History, use the Edit option to reopen a past date for corrections, pre-filled with the existing marks.'),
            _step('Deleting an attendance record',
                'A delete option for attendance records is available to the Admin only.'),
            _step('For Trainers',
                'Trainers only see and mark attendance for the batch(es) assigned to them.'),
          ]),

          _section('📞 Enquiries (Mobilizer)', [
            _step('Add a new enquiry',
                'Dashboard → "Add Enquiry" → fill in the enquirer\'s details and select the Course Interested from the dropdown list → Save.'),
            _step('Track and update enquiries',
                'Dashboard → "View Enquiries" → filter by status (New / Follow-up / Registered / Not Interested), tap any enquiry to update its follow-up notes and status.'),
            _step('Converting an enquiry into a trainee',
                'Open an enquiry and tap "Convert to Registration" to automatically create a new trainee record with an auto-generated Trainee ID.'),
            _step('What Mobilizers can see',
                'The enquiry list and dashboard counts show all enquiries, whoever added them.'),
          ]),

          _section('💼 Placement (Placement Officer)', [
            _step('Add a company',
                'Dashboard → "Add Company" → enter company name, contact person, phone, and location → Save.'),
            _step('Record a placement',
                'Dashboard → "Add Placement" → select the trainee and company, choose the Course from the dropdown, fill in job details, salary, joining date, and set a status (Not Placed / Interview Scheduled / Selected / Joined / Rejected / Self-Employed / Not Joined) → Save.'),
            _step('View, edit, or remove placement records',
                'Dashboard → "View Placements" → tap any record to view full details, edit the information, or delete the record.'),
          ]),

          _section('💰 Fees', [
            _step('Recording fee payments',
                'When adding or editing a trainee, enter the Total Course Fee and the Fee Paid So Far. The pending amount is calculated automatically.'),
            _step('Fees Report (Admin only)',
                'Dashboard → "Fees Report" shows a summary of total fees collected and pending across all trainees, with search and filters to quickly find trainees with pending payments.'),
            _step('Note',
                'This is for record-keeping only — the app does not process online payments. Payments should be collected separately and simply recorded here.'),
          ]),

          _section('📥 Bulk Import (Admin only)', [
            _step('Importing trainee records',
                'Dashboard → "Bulk Import" → select an Excel file to import multiple trainee records at once, along with their batch assignments.'),
            _step('Importing placement records',
                'The same screen also supports importing placement records from an Excel file, including automatically creating any new companies found in the file.'),
            _step('Undoing an import',
                'If an import needs to be reversed, use the "Undo Last Import" option to remove all records added in that specific import session.'),
          ]),

          const SizedBox(height: 10),
          Center(
            child: Text(
              'Need more help? Contact your system administrator.',
              style: TextStyle(color: Colors.grey[500], fontSize: 12),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _section(String title, List<Widget> steps) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
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
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: primaryGreen),
          ),
          const SizedBox(height: 12),
          ...steps,
        ],
      ),
    );
  }

  Widget _step(String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 4),
            width: 6,
            height: 6,
            decoration: const BoxDecoration(color: accentGold, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(description, style: TextStyle(fontSize: 12.5, color: Colors.grey[600], height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}