import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'edit_profile_screen.dart';
import 'login_options_card.dart';
import 'app_colors.dart';
import 'responsive.dart';
import 'ui_kit.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  String _roleLabel(String role) {
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
        return role;
    }
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

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: AppColors.appBackground,
      appBar: AppBar(
        flexibleSpace: const AppBarRibbon(),
        backgroundColor: AppColors.appPrimary,
        elevation: 0,
        title: const Text('My Profile'),
      ),
      body: PageWash(child: ContentWidth(maxWidth: 1100, child: uid == null
          ? const Center(child: Text('Not logged in.'))
          : StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator(color: AppColors.appPrimary));
          }
          if (!snapshot.data!.exists) {
            return const Center(child: Text('Profile not found.'));
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;
          final role = (data['role'] ?? '').toString();
          final createdAt = data['createdAt'] != null
              ? DateFormat('dd MMM yyyy').format((data['createdAt'] as Timestamp).toDate())
              : '-';

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.appPrimary,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Stack(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(right: 36),
                          child: Text(
                            data['name'] ?? 'Unnamed',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
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
                            _roleLabel(role),
                            style: const TextStyle(
                              color: AppColors.aurora,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Positioned(
                      top: -8,
                      right: -8,
                      child: IconButton(
                        icon: const Icon(Icons.edit_outlined, color: Colors.white),
                        tooltip: 'Edit Profile',
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => EditProfileScreen(
                                uid: uid,
                                currentData: data,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              _sectionCard('CONTACT INFORMATION', [
                _infoRow(Icons.email_outlined, 'Email', data['email'] ?? ''),
                _infoRow(Icons.phone_outlined, 'Phone', data['phone'] ?? ''),
                _infoRow(Icons.location_on_outlined, 'Address', data['address'] ?? ''),
              ]),
              _sectionCard('PROFESSIONAL INFORMATION', [
                _infoRow(Icons.school_outlined, 'Education', data['education'] ?? ''),
                _infoRow(Icons.badge_outlined, 'Role', _roleLabel(role)),
                _infoRow(Icons.calendar_today_outlined, 'Joined On', createdAt),
              ]),
              if (role == 'trainer')
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('batches')
                      .where('trainerId', isEqualTo: uid)
                      .snapshots(),
                  builder: (context, batchSnap) {
                    final batchNames = batchSnap.hasData
                        ? batchSnap.data!.docs
                        .map((d) => (d.data() as Map<String, dynamic>)['batchName']?.toString() ?? '')
                        .where((n) => n.isNotEmpty)
                        .toList()
                        : <String>[];

                    return _sectionCard('ASSIGNED BATCH(ES)', [
                      if (batchNames.isEmpty)
                        _infoRow(Icons.class_outlined, 'Batch', 'No batch assigned yet')
                      else
                        for (final name in batchNames) _infoRow(Icons.class_outlined, 'Batch', name),
                    ]);
                  },
                ),
              const LoginOptionsCard(),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.orange[700], size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Tap the edit icon above to update your details. Email and Role changes need your Admin.',
                        style: TextStyle(fontSize: 12, color: Colors.orange[800]),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ))),
    );
  }
}