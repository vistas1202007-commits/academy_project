import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'course_data.dart';
import 'current_user.dart';
import 'app_colors.dart';

class AddStudentScreen extends StatefulWidget {
  const AddStudentScreen({super.key});

  @override
  State<AddStudentScreen> createState() => _AddStudentScreenState();
}

class _AddStudentScreenState extends State<AddStudentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _guardianNameController = TextEditingController();
  final _guardianPhoneController = TextEditingController();
  final _totalFeeController = TextEditingController();
  final _feePaidController = TextEditingController();
  final _villageController = TextEditingController();
  final _tehsilController = TextEditingController();

  DateTime _admissionDate = DateTime.now();
  DateTime? _dob;
  bool _isSaving = false;
  String _errorMessage = '';
  String _status = 'Registered';

  // Course is now picked from the same real course list used on the
  // Enquiry and Placement forms (kCourseOptions), instead of a plain
  // free-text field with no suggestions at all.
  String? _selectedCourse;

  // Batch is selected from a live dropdown (Firestore 'batches'
  // collection) instead of free-typed text, so it can never mismatch the
  // batchName a Trainer's dashboard looks for.
  String? _selectedBatch;

  // Gender wasn't collected anywhere in this form before, so it never
  // reached Firestore even though the profile screen expects it.
  String? _selectedGender;
  final List<String> _genderOptions = ['Male', 'Female', 'Other'];

  final List<String> _statusOptions = ['Registered', 'Joined', 'Ongoing', 'Completed', 'Dropped'];

  Future<void> _pickAdmissionDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _admissionDate,
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
      setState(() {
        _admissionDate = picked;
      });
    }
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

  Future<String> _generateTraineeId() async {
    final year = DateTime.now().year;
    final counterRef =
    FirebaseFirestore.instance.collection('counters').doc('traineeId_$year');

    final newNumber = await FirebaseFirestore.instance.runTransaction<int>((transaction) async {
      final snapshot = await transaction.get(counterRef);
      int currentCount = 0;
      if (snapshot.exists) {
        final data = snapshot.data() as Map<String, dynamic>;
        currentCount = (data['count'] ?? 0) as int;
      }
      final nextCount = currentCount + 1;
      transaction.set(counterRef, {
        'count': nextCount,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return nextCount;
    });

    final paddedNumber = newNumber.toString().padLeft(4, '0');
    return 'VIS-$year-$paddedNumber';
  }

  Future<void> _saveStudent() async {
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
      final traineeId = await _generateTraineeId();
      final feePending = totalFee - feePaid;
      final stamp = await creatorStamp();

      await FirebaseFirestore.instance.collection('students').add({
        'traineeId': traineeId,
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
        'admissionDate': Timestamp.fromDate(_admissionDate),
        'status': _status,
        'totalFee': totalFee,
        'feePaid': feePaid,
        'feePending': feePending,
        ...stamp,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Trainee added successfully! ID: $traineeId'),
            backgroundColor: AppColors.appPrimary,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to save trainee. Please try again.';
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

  // Builds the Batch dropdown live from the 'batches' collection.
  Widget _buildBatchDropdown() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('batches')
          .orderBy('batchName')
          .snapshots(),
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
    _totalFeeController.dispose();
    _feePaidController.dispose();
    _villageController.dispose();
    _tehsilController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.appBackground,
      appBar: AppBar(
        backgroundColor: AppColors.appPrimary,
        elevation: 0,
        title: const Text('Add Trainee'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
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
            DropdownButtonFormField<String>(
              initialValue: _selectedCourse,
              isExpanded: true,
              decoration: _inputStyle('Course', Icons.school_outlined),
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
            _buildBatchDropdown(),
            const SizedBox(height: 14),
            InkWell(
              onTap: _pickAdmissionDate,
              borderRadius: BorderRadius.circular(10),
              child: InputDecorator(
                decoration: _inputStyle('Admission Date', Icons.calendar_today_outlined),
                child: Text(
                  '${_admissionDate.day}/${_admissionDate.month}/${_admissionDate.year}',
                ),
              ),
            ),
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
                onPressed: _isSaving ? null : _saveStudent,
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
                  'Save Trainee',
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
      ),
    );
  }
}