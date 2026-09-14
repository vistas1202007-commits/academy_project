import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'course_data.dart';

class AddBatchScreen extends StatefulWidget {
  const AddBatchScreen({super.key});

  @override
  State<AddBatchScreen> createState() => _AddBatchScreenState();
}

class _AddBatchScreenState extends State<AddBatchScreen> {
  final _formKey = GlobalKey<FormState>();

  final _batchNameController = TextEditingController();
  final _timingController = TextEditingController();

  String? _selectedCourse;
  String? _selectedTrainerId;
  String? _selectedTrainerName;

  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now().add(const Duration(days: 90));
  bool _isSaving = false;
  String _errorMessage = '';

  static const Color primaryGreen = Color(0xFF1B6B4A);
  static const Color accentGold = Color(0xFFD4AF37);

  Future<void> _pickDate({required bool isStart}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? _startDate : _endDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(primary: primaryGreen),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
      });
    }
  }

  Future<void> _saveBatch() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedTrainerId == null) {
      setState(() {
        _errorMessage = 'Please select a trainer for this batch.';
      });
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = '';
    });

    try {
      await FirebaseFirestore.instance.collection('batches').add({
        'batchName': _batchNameController.text.trim(),
        'course': _selectedCourse ?? '',
        'trainerId': _selectedTrainerId,
        'trainerName': _selectedTrainerName,
        'timing': _timingController.text.trim(),
        'startDate': Timestamp.fromDate(_startDate),
        'endDate': Timestamp.fromDate(_endDate),
        'status': 'active',
        'studentCount': 0,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Batch created successfully!'),
            backgroundColor: primaryGreen,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to save batch. Please try again.';
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
      prefixIcon: Icon(icon, color: primaryGreen),
      filled: true,
      fillColor: const Color(0xFFF5F7F5),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: primaryGreen, width: 1.5),
      ),
    );
  }

  @override
  void dispose() {
    _batchNameController.dispose();
    _timingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F5),
      appBar: AppBar(
        backgroundColor: primaryGreen,
        elevation: 0,
        title: const Text('Create Batch'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            TextFormField(
              controller: _batchNameController,
              decoration: _inputStyle('Batch Name (e.g. Morning-A 2026)', Icons.class_outlined),
              validator: (v) =>
              (v == null || v.trim().isEmpty) ? 'Please enter a batch name' : null,
            ),
            const SizedBox(height: 14),
            // Course is now picked from the same real course list used on
            // the Enquiry and Placement forms (kCourseOptions), instead of
            // the old hardcoded dummy list (Beauty & Wellness, Plumbing,
            // etc.) that didn't match what the institute actually runs.
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
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .where('role', isEqualTo: 'trainer')
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const LinearProgressIndicator(color: primaryGreen);
                }
                final trainers = snapshot.data!.docs;
                if (trainers.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange[50],
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      'No trainer accounts found. Add a trainer via "Add Staff" first.',
                      style: TextStyle(fontSize: 12, color: Colors.orange),
                    ),
                  );
                }
                return DropdownButtonFormField<String>(
                  initialValue: _selectedTrainerId,
                  decoration: _inputStyle('Assign Trainer', Icons.person_outline),
                  items: trainers.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    return DropdownMenuItem(
                      value: doc.id,
                      child: Text(data['name'] ?? 'Unnamed'),
                    );
                  }).toList(),
                  onChanged: (value) {
                    final selectedDoc = trainers.firstWhere((doc) => doc.id == value);
                    final data = selectedDoc.data() as Map<String, dynamic>;
                    setState(() {
                      _selectedTrainerId = value;
                      _selectedTrainerName = data['name'];
                    });
                  },
                  validator: (v) => v == null ? 'Please select a trainer' : null,
                );
              },
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _timingController,
              decoration: _inputStyle('Timing (e.g. 9 AM - 12 PM)', Icons.access_time_outlined),
            ),
            const SizedBox(height: 14),
            InkWell(
              onTap: () => _pickDate(isStart: true),
              borderRadius: BorderRadius.circular(10),
              child: InputDecorator(
                decoration: _inputStyle('Start Date', Icons.calendar_today_outlined),
                child: Text('${_startDate.day}/${_startDate.month}/${_startDate.year}'),
              ),
            ),
            const SizedBox(height: 14),
            InkWell(
              onTap: () => _pickDate(isStart: false),
              borderRadius: BorderRadius.circular(10),
              child: InputDecorator(
                decoration: _inputStyle('End Date', Icons.event_outlined),
                child: Text('${_endDate.day}/${_endDate.month}/${_endDate.year}'),
              ),
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
                onPressed: _isSaving ? null : _saveBatch,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryGreen,
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
                  'Save Batch',
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