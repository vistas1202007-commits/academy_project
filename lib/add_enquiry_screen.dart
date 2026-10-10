import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'course_data.dart';
import 'app_colors.dart';

class AddEnquiryScreen extends StatefulWidget {
  final String currentUserRole;
  const AddEnquiryScreen({super.key, required this.currentUserRole});

  @override
  State<AddEnquiryScreen> createState() => _AddEnquiryScreenState();
}

class _AddEnquiryScreenState extends State<AddEnquiryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _mobileController = TextEditingController();
  final _addressController = TextEditingController();
  final _remarksController = TextEditingController();
  DateTime _enquiryDate = DateTime.now();
  String _followUpStatus = 'New';
  String? _selectedCourse;
  bool _isSaving = false;
  String _errorMessage = '';

  final List<String> _statusOptions = ['New', 'Follow-up', 'Registered', 'Not Interested'];

  Future<void> _pickEnquiryDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _enquiryDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(primary: AppColors.appPrimary),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _enquiryDate = picked);
    }
  }

  Future<void> _saveEnquiry() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
      _errorMessage = '';
    });

    try {
      final mobile = _mobileController.text.trim();
      // Enquiries aur students dono me same number check karo
      final results = await Future.wait([
        FirebaseFirestore.instance
            .collection('enquiries')
            .where('mobile', isEqualTo: mobile)
            .limit(1)
            .get(),
        FirebaseFirestore.instance
            .collection('students')
            .where('phone', isEqualTo: mobile)
            .limit(1)
            .get(),
      ]);
      final enquiryMatch = results[0];
      final studentMatch = results[1];

      String? existingName;
      String source = '';
      if (studentMatch.docs.isNotEmpty) {
        existingName = (studentMatch.docs.first.data()['name'] ?? 'a trainee').toString();
        source = 'Student';
      } else if (enquiryMatch.docs.isNotEmpty) {
        existingName =
            (enquiryMatch.docs.first.data()['traineeName'] ?? 'a trainee').toString();
        source = 'Enquiry';
      }

      if (existingName != null && mounted) {
        final proceed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            title: const Text('Duplicate Mobile Number'),
            content: Text('Ye number pehle se hai: $existingName ($source)'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text('Cancel', style: TextStyle(color: Colors.grey[700])),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.appPrimary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Phir bhi save karo', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
        if (proceed != true) {
          setState(() => _isSaving = false);
          return;
        }
      }

      await FirebaseFirestore.instance.collection('enquiries').add({
        'traineeName': _nameController.text.trim(),
        'mobile': _mobileController.text.trim(),
        'address': _addressController.text.trim(),
        'courseInterested': _selectedCourse ?? '',
        'enquiryDate': Timestamp.fromDate(_enquiryDate),
        'followUpStatus': _followUpStatus,
        'remarks': _remarksController.text.trim(),
        'createdBy': FirebaseAuth.instance.currentUser?.uid,
        'createdByEmail': FirebaseAuth.instance.currentUser?.email,
        'createdByRole': widget.currentUserRole,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Enquiry saved successfully!'),
            backgroundColor: AppColors.appPrimary,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to save enquiry. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
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
  void dispose() {
    _nameController.dispose();
    _mobileController.dispose();
    _addressController.dispose();
    _remarksController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.appBackground,
      appBar: AppBar(
        backgroundColor: AppColors.appPrimary,
        elevation: 0,
        title: const Text('New Enquiry'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            TextFormField(
              controller: _nameController,
              decoration: _inputStyle('Trainee Name', Icons.person_outline),
              validator: (v) =>
              (v == null || v.trim().isEmpty) ? 'Please enter a name' : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _mobileController,
              keyboardType: TextInputType.phone,
              decoration: _inputStyle('Mobile Number', Icons.phone_outlined),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Please enter a mobile number';
                if (v.trim().length != 10) return 'Mobile number must be 10 digits';
                return null;
              },
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _addressController,
              maxLines: 2,
              decoration: _inputStyle('Address', Icons.location_on_outlined),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              initialValue: _selectedCourse,
              isExpanded: true,
              decoration: _inputStyle('Course Interested', Icons.school_outlined),
              hint: const Text('Select Course'),
              items: kCourseOptions
                  .map((c) => DropdownMenuItem(
                value: c['value'],
                child: Text(
                  c['label']!,
                  overflow: TextOverflow.ellipsis,
                ),
              ))
                  .toList(),
              onChanged: (v) => setState(() => _selectedCourse = v),
              validator: (v) => (v == null || v.isEmpty) ? 'Please select a course' : null,
            ),
            const SizedBox(height: 14),
            InkWell(
              onTap: _pickEnquiryDate,
              borderRadius: BorderRadius.circular(10),
              child: InputDecorator(
                decoration: _inputStyle('Enquiry Date', Icons.calendar_today_outlined),
                child: Text(
                  '${_enquiryDate.day}/${_enquiryDate.month}/${_enquiryDate.year}',
                ),
              ),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              initialValue: _followUpStatus,
              decoration: _inputStyle('Follow-up Status', Icons.flag_outlined),
              items: _statusOptions
                  .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                  .toList(),
              onChanged: (v) => setState(() => _followUpStatus = v!),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _remarksController,
              maxLines: 3,
              decoration: _inputStyle('Remarks (optional)', Icons.notes_outlined),
            ),
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
                onPressed: _isSaving ? null : _saveEnquiry,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.appPrimary,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
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
                  'Save Enquiry',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}