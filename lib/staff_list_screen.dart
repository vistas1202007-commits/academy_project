import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'edit_profile_screen.dart';
import 'app_colors.dart';
import 'responsive.dart';

class StaffListScreen extends StatelessWidget {
  const StaffListScreen({super.key});

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

  Future<void> _confirmToggleActive(BuildContext context, String uid, bool currentlyActive, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text(currentlyActive ? 'Deactivate Account?' : 'Activate Account?'),
        content: Text(
          currentlyActive
              ? '$name will no longer be able to log in until reactivated. Continue?'
              : '$name will be able to log in again. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancel', style: TextStyle(color: Colors.grey[700])),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: currentlyActive ? Colors.grey[700] : AppColors.appPrimary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(
              currentlyActive ? 'Deactivate' : 'Activate',
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await _toggleActive(context, uid, currentlyActive);
    }
  }

  Future<void> _toggleActive(BuildContext context, String uid, bool currentlyActive) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'isActive': !currentlyActive,
      });
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(currentlyActive ? 'Account deactivated.' : 'Account activated.'),
            backgroundColor: AppColors.appPrimary,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update account status. Please try again.')),
        );
      }
    }
  }

  Future<void> _confirmDelete(BuildContext context, String uid, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Delete Staff Account?'),
        content: Text(
          "This will permanently remove $name's profile and immediately block their access to the app. "
              "Their underlying login account may still need to be removed separately by a developer. "
              "This action cannot be undone. Continue?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancel', style: TextStyle(color: Colors.grey[700])),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[700],
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).delete();
      if (context.mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("$name's profile deleted."), backgroundColor: AppColors.appPrimary),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to delete. Please try again.')),
        );
      }
    }
  }

  Future<void> _sendPasswordReset(BuildContext context, String email) async {
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Password reset link sent to $email'),
            backgroundColor: AppColors.appPrimary,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to send reset link. Please try again.')),
        );
      }
    }
  }

  void _showDetail(BuildContext context, String uid, Map<String, dynamic> data) {
    final isActive = data['isActive'] ?? true;
    final isSelf = uid == FirebaseAuth.instance.currentUser?.uid;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data['name'] ?? 'Unnamed',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.appPrimary),
                ),
                const SizedBox(height: 4),
                Text(
                  _roleLabel(data['role'] ?? '-'),
                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                ),
                const Divider(height: 24),
                _detailRow(Icons.email_outlined, 'Email', data['email'] ?? '-'),
                _detailRow(Icons.phone_outlined, 'Phone', data['phone'] ?? '-'),
                _detailRow(Icons.school_outlined, 'Education', data['education'] ?? '-'),
                _detailRow(Icons.location_on_outlined, 'Address', data['address'] ?? '-'),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => EditProfileScreen(
                            uid: uid,
                            currentData: data,
                            // Apni profile pe role badalne ka option nahi
                            isAdminEditingOther: !isSelf,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.edit_outlined, color: AppColors.appPrimary),
                    label: const Text('Edit Details', style: TextStyle(color: AppColors.appPrimary)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.appPrimary),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: OutlinedButton.icon(
                    onPressed: () => _sendPasswordReset(context, data['email'] ?? ''),
                    icon: const Icon(Icons.lock_reset_outlined, color: AppColors.appPrimary),
                    label: const Text('Send Password Reset Email', style: TextStyle(color: AppColors.appPrimary)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.appPrimary),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                // Admin apna khud ka account deactivate nahi kar sakta
                if (!isSelf) ...[
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton.icon(
                    onPressed: () => _confirmToggleActive(context, uid, isActive, data['name'] ?? 'This staff member'),
                    icon: Icon(isActive ? Icons.block_outlined : Icons.check_circle_outline, color: Colors.white),
                    label: Text(
                      isActive ? 'Deactivate Account' : 'Activate Account',
                      style: const TextStyle(color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isActive ? Colors.grey[700] : AppColors.appPrimary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                ],
                if (!isSelf) ...[
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: OutlinedButton.icon(
                      onPressed: () => _confirmDelete(context, uid, data['name'] ?? 'This staff member'),
                      icon: Icon(Icons.delete_outline, color: Colors.red[700]),
                      label: Text('Delete Account', style: TextStyle(color: Colors.red[700])),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.red[700]!),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 6),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.appPrimary, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                Text(value.isEmpty ? '-' : value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.appBackground,
      appBar: AppBar(
        backgroundColor: AppColors.appPrimary,
        elevation: 0,
        title: const Text('Staff Accounts'),
      ),
      body: ContentWidth(maxWidth: 900, child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator(color: AppColors.appPrimary));
          }
          final docs = snapshot.data!.docs;
          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.badge_outlined, size: 56, color: Colors.grey[350]),
                  const SizedBox(height: 12),
                  Text('No staff accounts yet.', style: TextStyle(color: Colors.grey[600])),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;
              final isActive = data['isActive'] ?? true;
              final rawName = (data['name'] ?? '').toString().trim();
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
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
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  onTap: () => _showDetail(context, doc.id, data),
                  leading: CircleAvatar(
                    backgroundColor: AppColors.appPrimary.withValues(alpha: 0.12),
                    child: Text(
                      rawName.isNotEmpty ? rawName[0].toUpperCase() : '?',
                      style: const TextStyle(color: AppColors.appPrimary, fontWeight: FontWeight.bold),
                    ),
                  ),
                  title: Text(data['name'] ?? 'Unnamed', style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(
                    '${data['email'] ?? '-'}\n${_roleLabel(data['role'] ?? '-')}',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                  isThreeLine: true,
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: (isActive ? AppColors.appPrimary : Colors.red).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      isActive ? 'ACTIVE' : 'INACTIVE',
                      style: TextStyle(
                        color: isActive ? AppColors.appPrimary : Colors.red,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      )),
    );
  }
}