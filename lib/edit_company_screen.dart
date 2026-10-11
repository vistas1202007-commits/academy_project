import 'package:flutter/material.dart';
import 'friendly_error.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'app_colors.dart';
import 'current_user.dart';
import 'recycle_bin_screen.dart';
import 'soft_delete.dart';
import 'responsive.dart';
import 'ui_kit.dart';

class EditCompanyScreen extends StatefulWidget {
  final String companyId;
  final Map<String, dynamic> currentData;

  const EditCompanyScreen({super.key, required this.companyId, required this.currentData});

  @override
  State<EditCompanyScreen> createState() => _EditCompanyScreenState();
}

class _EditCompanyScreenState extends State<EditCompanyScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _companyNameController;
  late TextEditingController _contactPersonController;
  late TextEditingController _contactNumberController;
  late TextEditingController _locationController;
  bool _isSaving = false;

  /// Recycle Bin me bhejna sirf Admin ka kaam
  late final Future<String> _role = currentUserRole();

  @override
  void initState() {
    super.initState();
    final data = widget.currentData;
    _companyNameController = TextEditingController(text: data['companyName'] ?? '');
    _contactPersonController = TextEditingController(text: data['contactPerson'] ?? '');
    _contactNumberController = TextEditingController(text: data['contactNumber'] ?? '');
    _locationController = TextEditingController(text: data['location'] ?? '');
  }

  Future<void> _updateCompany() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      await FirebaseFirestore.instance.collection('companies').doc(widget.companyId).update({
        'companyName': _companyNameController.text.trim(),
        'contactPerson': _contactPersonController.text.trim(),
        'contactNumber': _contactNumberController.text.trim(),
        'location': _locationController.text.trim(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Company updated successfully'), backgroundColor: AppColors.appPrimary),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      debugPrint('Update company failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _confirmDelete() async {
    final name = _companyNameController.text.trim();
    if (!await confirmMoveToBin(context, name.isEmpty ? 'This company' : name)) return;
    try {
      await softDelete(FirebaseFirestore.instance.collection('companies').doc(widget.companyId));
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Company moved to Recycle Bin.'), backgroundColor: AppColors.appPrimary),
        );
      }
    } catch (e) {
      debugPrint('Delete company failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
      }
    }
  }

  InputDecoration _decoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: AppColors.appPrimary),
      filled: true,
      fillColor: AppColors.appBackground,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.appPrimary, width: 1.5),
      ),
    );
  }

  @override
  void dispose() {
    _companyNameController.dispose();
    _contactPersonController.dispose();
    _contactNumberController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.appBackground,
      appBar: AppBar(flexibleSpace: const AppBarRibbon(), backgroundColor: AppColors.appPrimary, title: const Text('Edit Company')),
      body: PageWash(child: ContentWidth(maxWidth: 640, child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _companyNameController,
                decoration: _decoration('Company Name', Icons.business_outlined),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _contactPersonController,
                decoration: _decoration('Contact Person Name', Icons.person_outline),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _contactNumberController,
                keyboardType: TextInputType.phone,
                decoration: _decoration('Contact Number (optional)', Icons.phone_outlined),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _locationController,
                decoration: _decoration('Location (optional)', Icons.location_on_outlined),
              ),
              const SizedBox(height: 26),
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _updateCompany,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.appPrimary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: _isSaving
                      ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                      : const Text('Update Company', style: TextStyle(color: Colors.white, fontSize: 16)),
                ),
              ),
              FutureBuilder<String>(
                future: _role,
                builder: (context, roleSnap) {
                  if (roleSnap.data != 'admin') return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: SizedBox(
                      height: 50,
                      child: OutlinedButton.icon(
                        onPressed: _confirmDelete,
                        icon: Icon(Icons.delete_outline, color: Colors.red[700]),
                        label: Text('Delete Company', style: TextStyle(color: Colors.red[700])),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: Colors.red[700]!),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ))),
    );
  }
}