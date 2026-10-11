import 'package:flutter/material.dart';
import 'friendly_error.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'app_colors.dart';
import 'responsive.dart';
import 'ui_kit.dart';

class EditBatchScreen extends StatefulWidget {
  final String batchId;
  const EditBatchScreen({super.key, required this.batchId});

  @override
  State<EditBatchScreen> createState() => _EditBatchScreenState();
}

class _EditBatchScreenState extends State<EditBatchScreen> {
  String? _selectedTrainerId;
  bool _isSaving = false;
  bool _loaded = false;
  late Map<String, dynamic> _batchData;

  Future<void> _saveTrainer() async {
    if (_selectedTrainerId == null) return;
    setState(() => _isSaving = true);
    try {
      final trainerDoc = await FirebaseFirestore.instance.collection('users').doc(_selectedTrainerId).get();
      final trainerName = (trainerDoc.data() as Map<String, dynamic>?)?['name'] ?? '';
      await FirebaseFirestore.instance.collection('batches').doc(widget.batchId).update({
        'trainerId': _selectedTrainerId,
        'trainerName': trainerName,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Trainer updated successfully!'), backgroundColor: AppColors.appPrimary),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      debugPrint('Update batch failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.appBackground,
      appBar: AppBar(flexibleSpace: const AppBarRibbon(), backgroundColor: AppColors.appPrimary, title: const Text('Edit Batch — Trainer')),
      body: PageWash(child: ContentWidth(maxWidth: 640, child: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('batches').doc(widget.batchId).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator(color: AppColors.appPrimary));
          }
          if (!_loaded) {
            _batchData = snapshot.data!.data() as Map<String, dynamic>;
            _selectedTrainerId = (_batchData['trainerId'] ?? '').toString().isNotEmpty
                ? _batchData['trainerId']
                : null;
            _loaded = true;
          }
          return Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Batch: ${_batchData['batchName'] ?? '-'}',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collection('users').where('role', isEqualTo: 'trainer').snapshots(),
                  builder: (context, trainerSnap) {
                    if (!trainerSnap.hasData) {
                      return const LinearProgressIndicator(color: AppColors.appPrimary);
                    }
                    final trainers = trainerSnap.data!.docs;
                    return DropdownButtonFormField<String>(
                      initialValue: _selectedTrainerId,
                      decoration: InputDecoration(
                        labelText: 'Assign Trainer',
                        prefixIcon: const Icon(Icons.person_outline, color: AppColors.appPrimary),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      items: trainers.map((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        return DropdownMenuItem(value: doc.id, child: Text(data['name'] ?? 'Unnamed'));
                      }).toList(),
                      onChanged: (v) => setState(() => _selectedTrainerId = v),
                    );
                  },
                ),
                const SizedBox(height: 26),
                SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    onPressed: (_isSaving || _selectedTrainerId == null) ? null : _saveTrainer,
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.appPrimary),
                    child: _isSaving
                        ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(color: Colors.white))
                        : const Text('Save Trainer', style: TextStyle(color: Colors.white, fontSize: 16)),
                  ),
                ),
              ],
            ),
          );
        },
      ))),
    );
  }
}