import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'add_enquiry_screen.dart';
import 'current_user.dart';
import 'app_colors.dart';
import 'responsive.dart';

class EnquiryListScreen extends StatefulWidget {
  final List<String>? filterStatuses;
  final String? screenTitle;

  const EnquiryListScreen({
    super.key,
    this.filterStatuses,
    this.screenTitle,
  });

  @override
  State<EnquiryListScreen> createState() => _EnquiryListScreenState();
}

class _EnquiryListScreenState extends State<EnquiryListScreen> {
  String _filter = 'All';
  final List<String> _filterOptions = ['All', 'New', 'Follow-up', 'Registered', 'Not Interested'];

  Color _statusColor(String status) {
    switch (status) {
      case 'Registered':
        return AppColors.appPrimary;
      case 'Follow-up':
        return AppColors.teal;
      case 'Not Interested':
        return Colors.grey;
      default:
        return AppColors.appAccent;
    }
  }

  Future<String> _generateTraineeId() async {
    final year = DateTime.now().year;
    final counterRef = FirebaseFirestore.instance
        .collection('counters')
        .doc('traineeId_$year');

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

  /// Looks up the current signed-in user's role from Firestore, so the "+"
  /// button here can tag any enquiry it creates with the correct
  /// createdByRole — the same tag add_enquiry_screen.dart now requires.
  Future<String> _fetchCurrentUserRole() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return 'mobilizer';
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final role = (doc.data()?['role'] ?? '').toString();
      return role.isNotEmpty ? role : 'mobilizer';
    } catch (_) {
      return 'mobilizer';
    }
  }

  Future<void> _convertToRegistration(BuildContext context, String enquiryId, Map<String, dynamic> data) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Convert to Registration?'),
        content: Text(
          'This will create a new Trainee record for "${data['traineeName'] ?? ''}" and generate a Trainee ID. Continue?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.appPrimary),
            child: const Text('Convert', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final traineeId = await _generateTraineeId();
      final stamp = await creatorStamp();

      final studentRef = await FirebaseFirestore.instance.collection('students').add({
        'traineeId': traineeId,
        'name': data['traineeName'] ?? '',
        'phone': data['mobile'] ?? '',
        'email': '',
        'guardianName': '',
        'guardianPhone': '',
        'course': data['courseInterested'] ?? '',
        'batch': '',
        'admissionDate': Timestamp.now(),
        'status': 'Registered',
        ...stamp,
        'createdAt': FieldValue.serverTimestamp(),
      });

      await FirebaseFirestore.instance.collection('enquiries').doc(enquiryId).update({
        'followUpStatus': 'Registered',
        'convertedTraineeId': traineeId,
        'convertedStudentDocId': studentRef.id,
        'convertedAt': FieldValue.serverTimestamp(),
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Registered successfully! Trainee ID: $traineeId'),
            backgroundColor: AppColors.appPrimary,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to convert: $e')),
        );
      }
    }
  }

  void _showDetail(BuildContext context, String enquiryId, Map<String, dynamic> data) {
    String selectedStatus = (data['followUpStatus'] ?? 'New').toString();
    final remarksController = TextEditingController(text: data['remarks'] ?? '');
    final enquiryDate = data['enquiryDate'] != null
        ? DateFormat('dd MMM yyyy').format((data['enquiryDate'] as Timestamp).toDate())
        : '-';
    final alreadyRegistered = selectedStatus == 'Registered';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data['traineeName'] ?? 'Unnamed',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.appPrimary),
                    ),
                    const SizedBox(height: 4),
                    Text('Enquiry Date: $enquiryDate', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                    const Divider(height: 24),
                    Text('Mobile: ${data['mobile'] ?? '-'}', style: const TextStyle(fontSize: 14)),
                    const SizedBox(height: 4),
                    Text('Course: ${data['courseInterested'] ?? '-'}', style: const TextStyle(fontSize: 14)),
                    const SizedBox(height: 4),
                    Text('Address: ${data['address'] ?? '-'}', style: const TextStyle(fontSize: 14)),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: selectedStatus,
                      decoration: InputDecoration(
                        labelText: 'Follow-up Status',
                        prefixIcon: const Icon(Icons.flag_outlined, color: AppColors.appPrimary),
                        filled: true,
                        fillColor: AppColors.appBackground,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      items: ['New', 'Follow-up', 'Registered', 'Not Interested']
                          .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                          .toList(),
                      onChanged: (v) => setModalState(() => selectedStatus = v!),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: remarksController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: 'Remarks / Follow-up Notes',
                        prefixIcon: const Icon(Icons.notes_outlined, color: AppColors.appPrimary),
                        filled: true,
                        fillColor: AppColors.appBackground,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: ElevatedButton(
                        onPressed: () async {
                          if (selectedStatus == 'Registered' && !alreadyRegistered) {
                            // Selecting "Registered" here must actually create the
                            // trainee too, not just relabel the enquiry - otherwise
                            // the enquiry says Registered but no student ever gets created.
                            await FirebaseFirestore.instance.collection('enquiries').doc(enquiryId).update({
                              'remarks': remarksController.text.trim(),
                            });
                            if (context.mounted) {
                              Navigator.of(context).pop();
                            }
                            await _convertToRegistration(context, enquiryId, data);
                            return;
                          }
                          await FirebaseFirestore.instance.collection('enquiries').doc(enquiryId).update({
                            'followUpStatus': selectedStatus,
                            'remarks': remarksController.text.trim(),
                          });
                          if (context.mounted) {
                            Navigator.of(context).pop();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Enquiry updated'), backgroundColor: AppColors.appPrimary),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.appPrimary,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Text('Save Update', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                      ),
                    ),
                    if (!alreadyRegistered) ...[
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        height: 46,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.of(context).pop();
                            _convertToRegistration(context, enquiryId, data);
                          },
                          icon: const Icon(Icons.person_add_alt_1_outlined, color: AppColors.appAccent),
                          label: const Text('Convert to Registration', style: TextStyle(color: AppColors.appAccent)),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppColors.appAccent),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                    ] else ...[
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.appPrimary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Already registered. Trainee ID: ${data['convertedTraineeId'] ?? '-'}',
                          style: const TextStyle(color: AppColors.appPrimary, fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Sab roles (Mobilizer bhi) saari enquiries dekhte hain.
    final query = FirebaseFirestore.instance
        .collection('enquiries')
        .orderBy('createdAt', descending: true);

    return Scaffold(
      backgroundColor: AppColors.appBackground,
      appBar: AppBar(
        backgroundColor: AppColors.appPrimary,
        elevation: 0,
        title: Text(widget.screenTitle ?? 'Enquiries'),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.appAccent,
        onPressed: () async {
          // Fetch the current user's role first so the enquiry this button
          // creates is correctly tagged (Admin-created vs Mobilizer-created)
          // — that tag is what lets a Mobilizer's "My Enquiries" card also
          // include enquiries an Admin added.
          final role = await _fetchCurrentUserRole();
          if (context.mounted) {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (context) => AddEnquiryScreen(currentUserRole: role)),
            );
          }
        },
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: ContentWidth(maxWidth: 900, child: Column(
        children: [
          // Only show the quick-filter chips when this screen isn't already
          // locked to a specific set of statuses via filterStatuses.
          if (widget.filterStatuses == null)
            SizedBox(
              height: 44,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemCount: _filterOptions.length,
                separatorBuilder: (context, index) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final option = _filterOptions[index];
                  final isSelected = _filter == option;
                  return ChoiceChip(
                    label: Text(option),
                    selected: isSelected,
                    selectedColor: AppColors.appPrimary,
                    backgroundColor: Colors.white,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : Colors.black87,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                    onSelected: (_) => setState(() => _filter = option),
                  );
                },
              ),
            ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: query.snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator(color: AppColors.appPrimary));
                }

                var docs = snapshot.data!.docs;

                if (widget.filterStatuses != null) {
                  docs = docs.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    return widget.filterStatuses!.contains(data['followUpStatus'] ?? 'New');
                  }).toList();
                } else if (_filter != 'All') {
                  docs = docs.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    return (data['followUpStatus'] ?? 'New') == _filter;
                  }).toList();
                }

                if (docs.isEmpty) {
                  return Center(
                    child: Text('No enquiries found.', style: TextStyle(color: Colors.grey[600])),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final status = (data['followUpStatus'] ?? 'New').toString();
                    final rawName = (data['traineeName'] ?? '').toString().trim();

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
                        title: Text(
                          data['traineeName'] ?? 'Unnamed',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          '${data['courseInterested'] ?? '-'}  -  ${data['mobile'] ?? '-'}',
                          style: TextStyle(color: Colors.grey[600], fontSize: 12),
                        ),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: _statusColor(status).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            status.toUpperCase(),
                            style: TextStyle(
                              color: _statusColor(status),
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      )),
    );
  }
}