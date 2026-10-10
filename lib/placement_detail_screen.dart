import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'edit_placement_screen.dart';
import 'app_colors.dart';
import 'responsive.dart';

class PlacementDetailScreen extends StatelessWidget {
  final String placementId;
  final Map<String, dynamic> data;

  const PlacementDetailScreen({super.key, required this.placementId, required this.data});

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.appPrimary, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                const SizedBox(height: 2),
                Text(
                  value.isEmpty ? '-' : value,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final joiningDate = data['joiningDate'] != null
        ? DateFormat('dd MMM yyyy').format((data['joiningDate'] as Timestamp).toDate())
        : '-';

    return Scaffold(
      backgroundColor: AppColors.appBackground,
      appBar: AppBar(
        backgroundColor: AppColors.appPrimary,
        elevation: 0,
        title: const Text('Placement Details'),
      ),
      body: ContentWidth(maxWidth: 1100, child: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.appPrimary,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data['studentName'] ?? 'Unnamed',
                      style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        (data['status'] ?? 'Not Placed').toString(),
                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4)),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _infoRow(Icons.badge_outlined, 'Trainee ID', data['traineeId'] ?? ''),
                    _infoRow(Icons.school_outlined, 'Course', data['course'] ?? ''),
                    _infoRow(Icons.business_outlined, 'Company', data['companyName'] ?? ''),
                    _infoRow(Icons.contact_page_outlined, 'Contact Person', data['contactPersonName'] ?? ''),
                    _infoRow(Icons.location_on_outlined, 'Job Location', data['jobLocation'] ?? ''),
                    _infoRow(Icons.work_outline, 'Job Post', data['jobPost'] ?? ''),
                    _infoRow(Icons.currency_rupee_outlined, 'Salary', data['salary'] ?? ''),
                    _infoRow(Icons.restaurant_outlined, 'Food Provided', data['foodProvided'] ?? ''),
                    _infoRow(Icons.badge_outlined, 'Employment Type', data['employmentType'] ?? ''),
                    _infoRow(Icons.calendar_today_outlined, 'Joining Date', joiningDate),
                  ],
                ),
              ),
              const SizedBox(height: 70),
            ],
          ),
          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: SizedBox(
              height: 50,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => EditPlacementScreen(placementId: placementId, currentData: data),
                    ),
                  );
                },
                icon: const Icon(Icons.edit_outlined, color: Colors.white),
                label: const Text('Edit Placement', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.appAccent,
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ),
        ],
      )),
    );
  }
}