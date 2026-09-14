import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'course_data.dart';

class EditPlacementScreen extends StatefulWidget {
  final String placementId;
  final Map<String, dynamic> currentData;

  const EditPlacementScreen({super.key, required this.placementId, required this.currentData});

  @override
  State<EditPlacementScreen> createState() => _EditPlacementScreenState();
}

class _EditPlacementScreenState extends State<EditPlacementScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _studentNameController;
  late TextEditingController _traineeIdController;
  late TextEditingController _contactPersonController;
  late TextEditingController _jobLocationController;
  late TextEditingController _jobPostController;
  late TextEditingController _salaryController;
  late TextEditingController _companyNameController;

  String? _selectedCourse;
  DateTime? _joiningDate;
  late String _foodProvided;
  late String _employmentType;
  late String _status;
  bool _isSaving = false;

  static const Color primaryGreen = Color(0xFF1B6B4A);

  final List<String> _foodOptions = ['Yes', 'No'];
  final List<String> _employmentOptions = ['Salaried', 'Waged', 'Self-employed'];
  final List<String> _statusOptions = [
    'Not Placed',
    'Interview Scheduled',
    'Selected',
    'Joined',
    'Rejected',
    'Self-Employed',
    'Not Joined',
  ];

  @override
  void initState() {
    super.initState();
    final data = widget.currentData;
    _studentNameController = TextEditingController(text: data['studentName'] ?? '');
    _traineeIdController = TextEditingController(text: data['traineeId'] ?? '');
    _contactPersonController = TextEditingController(text: data['contactPersonName'] ?? '');
    _jobLocationController = TextEditingController(text: data['jobLocation'] ?? '');
    _jobPostController = TextEditingController(text: data['jobPost'] ?? '');
    _salaryController = TextEditingController(text: data['salary'] ?? '');
    _companyNameController = TextEditingController(text: data['companyName'] ?? '');

    final existingCourse = (data['course'] ?? '').toString();
    _selectedCourse = existingCourse.isNotEmpty ? existingCourse : null;

    _foodProvided = _foodOptions.contains(data['foodProvided']) ? data['foodProvided'] : 'No';
    _employmentType = _employmentOptions.contains(data['employmentType']) ? data['employmentType'] : 'Salaried';
    _status = _statusOptions.contains(data['status']) ? data['status'] : 'Not Placed';
    _joiningDate = data['joiningDate'] != null ? (data['joiningDate'] as Timestamp).toDate() : null;
  }

  Future<void> _pickJoiningDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _joiningDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(colorScheme: const ColorScheme.light(primary: primaryGreen)),
          child: child!,
        );
      },
    );
    if (picked != null) setState(() => _joiningDate = picked);
  }

  Future<void> _updatePlacement() async {
    if (!_formKey.currentState!.validate()) return;
    if (_joiningDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a joining date')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      await FirebaseFirestore.instance.collection('placements').doc(widget.placementId).update({
        'studentName': _studentNameController.text.trim(),
        'traineeId': _traineeIdController.text.trim(),
        'course': _selectedCourse ?? '',
        'contactPersonName': _contactPersonController.text.trim(),
        'jobLocation': _jobLocationController.text.trim(),
        'jobPost': _jobPostController.text.trim(),
        'salary': _salaryController.text.trim(),
        'foodProvided': _foodProvided,
        'companyName': _companyNameController.text.trim(),
        'joiningDate': Timestamp.fromDate(_joiningDate!),
        'employmentType': _employmentType,
        'status': _status,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Placement updated successfully!'), backgroundColor: primaryGreen),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to update: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _confirmDelete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Delete Placement Record?'),
        content: const Text('This action cannot be undone. Continue?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red[700]),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await FirebaseFirestore.instance.collection('placements').doc(widget.placementId).delete();
      if (mounted) {
        Navigator.of(context).pop();
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Placement record deleted.'), backgroundColor: primaryGreen),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to delete: $e')));
      }
    }
  }

  InputDecoration _decoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: primaryGreen),
      filled: true,
      fillColor: const Color(0xFFF5F7F5),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: primaryGreen, width: 1.5),
      ),
    );
  }

  @override
  void dispose() {
    _studentNameController.dispose();
    _traineeIdController.dispose();
    _contactPersonController.dispose();
    _jobLocationController.dispose();
    _jobPostController.dispose();
    _salaryController.dispose();
    _companyNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F5),
      appBar: AppBar(backgroundColor: primaryGreen, title: const Text('Edit Placement')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            TextFormField(
              controller: _studentNameController,
              decoration: _decoration('Trainee Name', Icons.person_outline),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _traineeIdController,
              decoration: _decoration('Trainee ID', Icons.badge_outlined),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              initialValue: _selectedCourse,
              isExpanded: true,
              decoration: _decoration('Course', Icons.school_outlined),
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
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _companyNameController,
              decoration: _decoration('Company Name', Icons.business_outlined),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _contactPersonController,
              decoration: _decoration('Contact Person Name', Icons.contact_page_outlined),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _jobLocationController,
              decoration: _decoration('Job Location', Icons.location_on_outlined),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _jobPostController,
              decoration: _decoration('Job Post / Designation', Icons.work_outline),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _salaryController,
              keyboardType: TextInputType.number,
              decoration: _decoration('Salary', Icons.currency_rupee_outlined),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              initialValue: _foodProvided,
              decoration: _decoration('Food Provided', Icons.restaurant_outlined),
              items: _foodOptions.map((f) => DropdownMenuItem(value: f, child: Text(f))).toList(),
              onChanged: (v) => setState(() => _foodProvided = v!),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              initialValue: _employmentType,
              decoration: _decoration('Employment Type', Icons.work_outline),
              items: _employmentOptions.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: (v) => setState(() => _employmentType = v!),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              initialValue: _status,
              decoration: _decoration('Placement Status', Icons.flag_outlined),
              items: _statusOptions.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
              onChanged: (v) => setState(() => _status = v!),
            ),
            const SizedBox(height: 14),
            InkWell(
              onTap: _pickJoiningDate,
              borderRadius: BorderRadius.circular(10),
              child: InputDecorator(
                decoration: _decoration('Joining Date', Icons.calendar_today_outlined),
                child: Text(_joiningDate == null
                    ? 'Select date'
                    : '${_joiningDate!.day}/${_joiningDate!.month}/${_joiningDate!.year}'),
              ),
            ),
            const SizedBox(height: 26),
            SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _updatePlacement,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryGreen,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: _isSaving
                    ? const SizedBox(
                    height: 22, width: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                    : const Text('Update Placement', style: TextStyle(color: Colors.white, fontSize: 16)),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 50,
              child: OutlinedButton.icon(
                onPressed: _confirmDelete,
                icon: Icon(Icons.delete_outline, color: Colors.red[700]),
                label: Text('Delete Placement', style: TextStyle(color: Colors.red[700])),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Colors.red[700]!),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
