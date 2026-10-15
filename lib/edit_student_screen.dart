import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'live_query.dart';
import 'course_data.dart';
import 'app_colors.dart';
import 'responsive.dart';
import 'ui_kit.dart';

class EditStudentScreen extends StatefulWidget {
  final String studentId;
  final Map<String, dynamic> currentData;

  const EditStudentScreen({
    super.key,
    required this.studentId,
    required this.currentData,
  });

  @override
  State<EditStudentScreen> createState() => _EditStudentScreenState();
}

class _EditStudentScreenState extends State<EditStudentScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _emailController;
  late TextEditingController _guardianNameController;
  late TextEditingController _guardianPhoneController;
  late TextEditingController _villageController;
  late TextEditingController _tehsilController;
  late TextEditingController _totalFeeController;
  late TextEditingController _feePaidController;
  late String _status;

  String? _selectedBatch;
  String? _selectedCourse;
  String? _selectedGender;
  DateTime? _dob;
  final List<String> _genderOptions = ['Male', 'Female', 'Other'];

  bool _isSaving = false;
  String _errorMessage = '';

  final List<String> _statusOptions = ['Registered', 'Joined', 'Ongoing', 'Completed', 'Dropped'];

  @override
  void initState() {
    super.initState();
    final data = widget.currentData;
    _nameController = TextEditingController(text: data['name'] ?? '');
    _phoneController = TextEditingController(text: data['phone'] ?? '');
    _emailController = TextEditingController(text: data['email'] ?? '');
    _guardianNameController = TextEditingController(text: data['guardianName'] ?? '');
    _guardianPhoneController = TextEditingController(text: data['guardianPhone'] ?? '');
    _villageController = TextEditingController(text: (data['village'] ?? '').toString());
    _tehsilController = TextEditingController(text: (data['tehsil'] ?? '').toString());
    final existingCourse = (data['course'] ?? '').toString();
    _selectedCourse = existingCourse.isNotEmpty ? existingCourse : null;
    if (data['dob'] is Timestamp) _dob = (data['dob'] as Timestamp).toDate();
    _totalFeeController = TextEditingController(
      text: (data['totalFee'] ?? 0).toString() == '0.0'
          ? '0'
          : (data['totalFee'] ?? 0).toString(),
    );
    _feePaidController = TextEditingController(
      text: (data['feePaid'] ?? 0).toString() == '0.0'
          ? '0'
          : (data['feePaid'] ?? 0).toString(),
    );
    _status = (data['status'] ?? 'Registered').toString();
    if (!_statusOptions.contains(_status)) {
      _status = 'Registered';
    }
    final existingBatch = (data['batch'] ?? '').toString();
    _selectedBatch = existingBatch.isNotEmpty ? existingBatch : null;
    final existingGender = (data['gender'] ?? '').toString();
    _selectedGender = _genderOptions.contains(existingGender) ? existingGender : null;
  }

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dob ?? DateTime(now.year - 18, now.month, now.day),
      firstDate: DateTime(1950),
      lastDate: now,
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
      setState(() => _dob = picked);
    }
  }

  Future<void> _updateStudent() async {
    if (!_formKey.currentState!.validate()) return;

    final totalFee = double.tryParse(_totalFeeController.text.trim()) ?? 0;
    final feePaid = double.tryParse(_feePaidController.text.trim()) ?? 0;

    if (feePaid > totalFee) {
      setState(() {
        _errorMessage = 'Fee Paid cannot be more than Total Fee.';
      });
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = '';
    });

    try {
      final feePending = totalFee - feePaid;

      await FirebaseFirestore.instance.collection('students').doc(widget.studentId).update({
        'name': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'email': _emailController.text.trim(),
        'gender': _selectedGender ?? '',
        'dob': _dob != null ? Timestamp.fromDate(_dob!) : null,
        'village': _villageController.text.trim(),
        'tehsil': _tehsilController.text.trim(),
        'guardianName': _guardianNameController.text.trim(),
        'guardianPhone': _guardianPhoneController.text.trim(),
        'course': _selectedCourse ?? '',
        'batch': _selectedBatch ?? '',
        'status': _status,
        'totalFee': totalFee,
        'feePaid': feePaid,
        'feePending': feePending,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Trainee updated successfully!'),
            backgroundColor: AppColors.appPrimary,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to update trainee. Please try again.';
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

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 8),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: AppColors.appPrimary,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  Widget _buildBatchDropdown() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('batches')
          .orderBy('batchName')
          .liveSnapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return InputDecorator(
            decoration: _inputStyle('Batch', Icons.class_outlined),
            child: const Text('Loading batches...'),
          );
        }

        final batchNames = snapshot.data!.docs
            .map((d) => (d.data() as Map<String, dynamic>)['batchName'] as String?)
            .whereType<String>()
            .where((name) => name.trim().isNotEmpty)
            .toSet()
            .toList()
          ..sort();

        // If this trainee's saved batch doesn't match any real batch
        // (old mismatched data), still show it so the dropdown doesn't
        // crash, and so it's easy to spot and fix right here.
        if (_selectedBatch != null && !batchNames.contains(_selectedBatch)) {
          batchNames.insert(0, _selectedBatch!);
        }

        if (batchNames.isEmpty) {
          return InputDecorator(
            decoration: _inputStyle('Batch', Icons.class_outlined),
            child: Text(
              'No batches created yet. Add a batch first.',
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
            ),
          );
        }

        return DropdownButtonFormField<String>(
          initialValue: _selectedBatch,
          decoration: _inputStyle('Batch', Icons.class_outlined),
          hint: const Text('Select Batch'),
          items: batchNames
              .map((name) => DropdownMenuItem(value: name, child: Text(name)))
              .toList(),
          onChanged: (v) => setState(() => _selectedBatch = v),
          validator: (v) => (v == null || v.isEmpty) ? 'Please select a batch' : null,
        );
      },
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _guardianNameController.dispose();
    _guardianPhoneController.dispose();
    _villageController.dispose();
    _tehsilController.dispose();
    _totalFeeController.dispose();
    _feePaidController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final traineeId = (widget.currentData['traineeId'] ?? '').toString();

    return Scaffold(
      backgroundColor: AppColors.appBackground,
      appBar: AppBar(
        flexibleSpace: const AppBarRibbon(),
        backgroundColor: AppColors.appPrimary,
        elevation: 0,
        title: const Text('Edit Trainee'),
      ),
      body: PageWash(child: ContentWidth(maxWidth: 640, child: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (traineeId.isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.appPrimary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.badge_outlined, color: AppColors.appPrimary, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'Trainee ID: $traineeId',
                      style: const TextStyle(
                          color: AppColors.appPrimary, fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                  ],
                ),
              ),
            _sectionTitle('PERSONAL INFORMATION'),
            TextFormField(
              controller: _nameController,
              decoration: _inputStyle('Full Name', Icons.person_outline),
              validator: (v) =>
              (v == null || v.trim().isEmpty) ? 'Please enter the trainee\'s name' : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: _inputStyle('Phone Number', Icons.phone_outlined),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Please enter a phone number';
                if (v.trim().length != 10) return 'Phone number must be 10 digits';
                return null;
              },
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: _inputStyle('Email (optional)', Icons.email_outlined),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              initialValue: _selectedGender,
              decoration: _inputStyle('Gender', Icons.wc_outlined),
              hint: const Text('Select Gender'),
              items: _genderOptions
                  .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                  .toList(),
              onChanged: (v) => setState(() => _selectedGender = v),
              validator: (v) => (v == null || v.isEmpty) ? 'Please select a gender' : null,
            ),
            const SizedBox(height: 14),
            InkWell(
              onTap: _pickDob,
              borderRadius: BorderRadius.circular(10),
              child: InputDecorator(
                decoration: _inputStyle('Date of Birth', Icons.cake_outlined),
                child: Text(
                  _dob == null ? 'Select Date of Birth' : '${_dob!.day}/${_dob!.month}/${_dob!.year}',
                  style: _dob == null ? TextStyle(color: Colors.grey[600]) : null,
                ),
              ),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _villageController,
              decoration: _inputStyle('Village', Icons.home_outlined),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _tehsilController,
              decoration: _inputStyle('Tehsil', Icons.location_city_outlined),
            ),
            const SizedBox(height: 20),
            _sectionTitle('GUARDIAN INFORMATION'),
            TextFormField(
              controller: _guardianNameController,
              decoration: _inputStyle('Guardian Name', Icons.family_restroom_outlined),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _guardianPhoneController,
              keyboardType: TextInputType.phone,
              decoration: _inputStyle('Guardian Phone', Icons.phone_outlined),
            ),
            const SizedBox(height: 20),
            _sectionTitle('TRAINING INFORMATION'),
            Builder(
              builder: (context) {
                // Also show an old course value (not in the list) so the dropdown doesn't crash
                final options = [...kCourseOptions];
                if (_selectedCourse != null &&
                    !options.any((c) => c['value'] == _selectedCourse)) {
                  options.insert(0, {'value': _selectedCourse!, 'label': _selectedCourse!});
                }
                return DropdownButtonFormField<String>(
                  initialValue: _selectedCourse,
                  isExpanded: true,
                  decoration: _inputStyle('Course', Icons.school_outlined),
                  hint: const Text('Select Course'),
                  items: options
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
                );
              },
            ),
            const SizedBox(height: 14),
            _buildBatchDropdown(),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              initialValue: _status,
              decoration: _inputStyle('Trainee Status', Icons.flag_outlined),
              items: _statusOptions
                  .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                  .toList(),
              onChanged: (v) => setState(() => _status = v!),
            ),
            const SizedBox(height: 20),
            _sectionTitle('FEES'),
            TextFormField(
              controller: _totalFeeController,
              keyboardType: TextInputType.number,
              decoration: _inputStyle('Total Course Fee (₹)', Icons.receipt_long_outlined),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _feePaidController,
              keyboardType: TextInputType.number,
              decoration: _inputStyle('Fee Paid So Far (₹)', Icons.currency_rupee_outlined),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 10),
            Builder(
              builder: (context) {
                final total = double.tryParse(_totalFeeController.text.trim()) ?? 0;
                final paid = double.tryParse(_feePaidController.text.trim()) ?? 0;
                final pending = total - paid;
                final isFullyPaid = total > 0 && pending <= 0;
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: (isFullyPaid ? AppColors.success : AppColors.warning).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    'Pending: ₹${pending.clamp(0, double.infinity).toStringAsFixed(0)}'
                        '${isFullyPaid ? ' • Fully Paid ✓' : ''}',
                    style: TextStyle(
                      color: isFullyPaid ? AppColors.success : AppColors.warning.withAlpha(230),
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                );
              },
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
                onPressed: _isSaving ? null : _updateStudent,
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
                  'Update Trainee',
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
      ))),
    );
  }
}