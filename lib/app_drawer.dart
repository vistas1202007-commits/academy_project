import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'app_colors.dart';
import 'brand.dart';
import 'nav_items.dart';

class AppDrawer extends StatefulWidget {
  final String name;
  final String roleLabel;
  const AppDrawer({super.key, required this.name, required this.roleLabel});

  @override
  State<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer> {
  // Role check hone tak sirf sabke liye wale items
  String _role = '';

  @override
  void initState() {
    super.initState();
    _checkRole();
  }

  Future<void> _checkRole() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final role = (doc.data()?['role'] ?? '').toString();
      if (mounted) setState(() => _role = role);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 50, 20, 20),
            color: AppColors.appPrimary,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Image.asset(BrandAssets.logoCircle, height: 56, width: 56),
                const SizedBox(height: 12),
                Text(
                  widget.name,
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.roleLabel,
                  style: const TextStyle(color: AppColors.aurora, fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                for (final item in navItemsFor(_role))
                  ListTile(
                    leading: Icon(item.icon, color: AppColors.appPrimary),
                    title: Text(item.label),
                    onTap: () {
                      Navigator.of(context).pop();
                      if (item.builder != null) Navigator.of(context).push(item.route());
                    },
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('Logout', style: TextStyle(color: Colors.red)),
            onTap: () => confirmLogout(context),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}
