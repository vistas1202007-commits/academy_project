import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'student_profile_screen.dart';
import 'app_colors.dart';
import 'soft_delete.dart';
import 'responsive.dart';
import 'ui_kit.dart';

class FeesReportScreen extends StatefulWidget {
  const FeesReportScreen({super.key});

  @override
  State<FeesReportScreen> createState() => _FeesReportScreenState();
}

class _FeesReportScreenState extends State<FeesReportScreen> {
  String _searchQuery = '';
  String _filter = 'All'; // All | Pending | Fully Paid

  final List<String> _filterOptions = ['All', 'Pending', 'Fully Paid'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.appBackground,
      appBar: AppBar(
        flexibleSpace: const AppBarRibbon(),
        backgroundColor: AppColors.appPrimary,
        elevation: 0,
        title: const Text('Fees Report'),
      ),
      body: PageWash(child: ContentWidth(maxWidth: 1100, child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('students')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Something went wrong.'));
          }
          if (!snapshot.hasData) {
            return const AppLoader();
          }

          final allDocs = liveDocsOf(snapshot.data!);

          double totalCollected = 0;
          double totalPending = 0;
          for (final doc in allDocs) {
            final data = doc.data() as Map<String, dynamic>;
            totalCollected += (data['feePaid'] ?? 0).toDouble();
            final total = (data['totalFee'] ?? 0).toDouble();
            final paid = (data['feePaid'] ?? 0).toDouble();
            final pending = (data['feePending'] ?? (total - paid)).toDouble();
            if (pending > 0) totalPending += pending;
          }

          final filteredDocs = allDocs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final name = (data['name'] ?? '').toString().toLowerCase();
            final traineeId = (data['traineeId'] ?? '').toString().toLowerCase();
            final matchesSearch = name.contains(_searchQuery) || traineeId.contains(_searchQuery);

            final total = (data['totalFee'] ?? 0).toDouble();
            final paid = (data['feePaid'] ?? 0).toDouble();
            final pending = (data['feePending'] ?? (total - paid)).toDouble();
            final isFullyPaid = total > 0 && pending <= 0;

            bool matchesFilter = true;
            if (_filter == 'Pending') matchesFilter = pending > 0;
            if (_filter == 'Fully Paid') matchesFilter = isFullyPaid;

            return matchesSearch && matchesFilter;
          }).toList();

          return Column(
            children: [
              // ---- Summary cards ----
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.appPrimary.withValues(alpha: 0.08),
                          borderRadius: AppCard.radius,
                          border: Border.all(color: AppColors.appPrimary.withValues(alpha: 0.25), width: 0.5),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.check_circle_outline, color: AppColors.appPrimary, size: 20),
                            const SizedBox(height: 8),
                            Text(
                              '₹${totalCollected.toStringAsFixed(0)}',
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.appPrimary),
                            ),
                            const SizedBox(height: 2),
                            Text('Total Collected', style: TextStyle(fontSize: 11, color: Colors.grey[700])),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.warning.withValues(alpha: 0.12),
                          borderRadius: AppCard.radius,
                          border: Border.all(color: AppColors.warning.withValues(alpha: 0.25), width: 0.5),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.pending_outlined, color: AppColors.warning.withAlpha(230), size: 20),
                            const SizedBox(height: 8),
                            Text(
                              '₹${totalPending.toStringAsFixed(0)}',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.warning.withAlpha(230)),
                            ),
                            const SizedBox(height: 2),
                            Text('Total Pending', style: TextStyle(fontSize: 11, color: Colors.grey[700])),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ---- Search ----
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: TextField(
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value.toLowerCase();
                    });
                  },
                  decoration: InputDecoration(
                    hintText: 'Search by name or Trainee ID',
                    prefixIcon: Icon(Icons.search, color: AppColors.appPrimary),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),

              // ---- Filter chips ----
              SizedBox(
                height: 40,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
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
              const SizedBox(height: 8),

              // ---- List ----
              Expanded(
                child: filteredDocs.isEmpty
                    ? EmptyState(icon: Icons.receipt_long_outlined, message: allDocs.isEmpty ? 'No trainees found.' : 'No matching records.')
                    : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  itemCount: filteredDocs.length,
                  itemBuilder: (context, index) {
                    final doc = filteredDocs[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final total = (data['totalFee'] ?? 0).toDouble();
                    final paid = (data['feePaid'] ?? 0).toDouble();
                    final pending = (data['feePending'] ?? (total - paid)).toDouble();
                    final isFullyPaid = total > 0 && pending <= 0;
                    final traineeId = (data['traineeId'] ?? '').toString();

                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: AppCard.decoration,
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        leading: CircleAvatar(
                          backgroundColor: AppColors.appPrimary.withValues(alpha: 0.12),
                          child: Text(
                            (data['name'] ?? '?').toString().isNotEmpty
                                ? data['name'][0].toUpperCase()
                                : '?',
                            style: const TextStyle(color: AppColors.appPrimary, fontWeight: FontWeight.bold),
                          ),
                        ),
                        title: Text(
                          data['name'] ?? 'Unnamed',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          traineeId.isNotEmpty
                              ? '$traineeId  -  ${data['batch'] ?? '-'}'
                              : '${data['course'] ?? '-'}  -  ${data['batch'] ?? '-'}',
                          style: TextStyle(color: Colors.grey[600], fontSize: 12),
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              isFullyPaid ? 'Paid' : '₹${pending.clamp(0, double.infinity).toStringAsFixed(0)}',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                                color: isFullyPaid ? AppColors.success : AppColors.warning.withAlpha(230),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              isFullyPaid ? 'Fully Paid' : 'Pending',
                              style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                            ),
                          ],
                        ),
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => StudentProfileScreen(studentId: doc.id),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ))),
    );
  }
}