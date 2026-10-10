import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'app_colors.dart';
import 'responsive.dart';

class EditProfileScreen extends StatefulWidget {
  final String uid;
  final Map<String, dynamic> currentData;
  // true when an Admin is editing someone else's profile from Staff List —
  // shows the Role field and uses "Edit Staff Details" as the title.
  final bool isAdminEditingOther;

  const EditProfileScreen({
    super.key,
    required this.uid,
    required this.currentData,
    this.isAdminEditingOther = false,
  });

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _addressController;
  late TextEditingController _educationController;
  late String _role;
  bool _isSaving = false;
  String _errorMessage = '';

  final List<String> _roleOptions = ['admin', 'trainer', 'placementOfficer', 'mobilizer'];

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

  @override
  void initState() {
    super.initState();
    final data = widget.currentData;
    _nameController = TextEditingController(text: (data['name'] ?? '').toString());
    _phoneController = TextEditingController(text: (data['phone'] ?? '').toString());
    _addressController = TextEditingController(text: (data['address'] ?? '').toString());
    _educationController = TextEditingController(text: (data['education'] ?? '').toString());
    _role = (data['role'] ?? 'trainer').toString();
    if (!_roleOptions.contains(_role)) _role = 'trainer';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _educationController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
      _errorMessage = '';
    });

    try {
      final updateData = <String, dynamic>{
        'name': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'address': _addressController.text.trim(),
        'education': _educationController.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      };
      // Role is only editable when an Admin is updating someone else's
      // profile — a user should never be able to change their own role.
      if (widget.isAdminEditingOther) {
        updateData['role'] = _role;
      }

      await FirebaseFirestore.instance.collection('users').doc(widget.uid).update(updateData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully!'),
            backgroundColor: AppColors.appPrimary,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to update profile. Please try again.';
      });
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  InputDecoration _inputStyle(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: Colors.grey[600]),
      prefixIcon: Icon(icon, color: AppColors.appPrimary),
      filled: true,
      fillColor: AppColors.appBackground,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.appPrimary, width: 1.5),
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
        title: Text(widget.isAdminEditingOther ? 'Edit Staff Details' : 'Edit My Profile'),
      ),
      body: ContentWidth(maxWidth: 640, child: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            TextFormField(
              controller: _nameController,
              decoration: _inputStyle('Full Name', Icons.person_outline),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter a name' : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: _inputStyle('Phone Number', Icons.phone_outlined),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return null; // optional
                if (v.trim().length != 10) return 'Phone number must be 10 digits';
                return null;
              },
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _addressController,
              decoration: _inputStyle('Address', Icons.location_on_outlined),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _educationController,
              decoration: _inputStyle('Education', Icons.school_outlined),
            ),
            if (widget.isAdminEditingOther) ...[
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                initialValue: _role,
                decoration: _inputStyle('Role', Icons.badge_outlined),
                items: _roleOptions
                    .map((r) => DropdownMenuItem(value: r, child: Text(_roleLabel(r))))
                    .toList(),
                onChanged: (v) => setState(() => _role = v ?? _role),
              ),
            ],
            if (!widget.isAdminEditingOther) ...[
              const SizedBox(height: 14),
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
                        'Email and Role cannot be changed here. Contact your Admin for those.',
                        style: TextStyle(fontSize: 12, color: Colors.orange[800]),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (_errorMessage.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _errorMessage,
                  style: TextStyle(color: Colors.red[700], fontSize: 13),
                ),
              ),
            ],
            const SizedBox(height: 28),
            SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.appPrimary,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: _isSaving
                    ? const SizedBox(
                  height: 22,
                  width: 22,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2.5,
                  ),
                )
                    : const Text(
                  'Save Changes',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      )),
    );
  }
}