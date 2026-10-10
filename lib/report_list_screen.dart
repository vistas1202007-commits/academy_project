import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'add_report_screen.dart';
import 'app_colors.dart';

class ReportListScreen extends StatefulWidget {
  const ReportListScreen({super.key});

  @override
  State<ReportListScreen> createState() => _ReportListScreenState();
}

class _ReportListScreenState extends State<ReportListScreen> {
  bool _isAdmin = false;
  String _currentUserRole = 'mobilizer';
  bool _roleLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadRole();
  }

  Future<void> _loadRole() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      setState(() => _roleLoaded = true);
      return;
    }
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final role = (doc.data()?['role'] ?? '').toString();
      setState(() {
        _currentUserRole = role.isNotEmpty ? role : 'mobilizer';
        _isAdmin = role == 'admin';
        _roleLoaded = true;
      });
    } catch (_) {
      setState(() => _roleLoaded = true);
    }
  }

  Future<void> _confirmDelete(BuildContext context, String reportId, String title) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Delete Report?'),
        content: Text('This will permanently delete "$title". This action cannot be undone. Continue?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancel', style: TextStyle(color: Colors.grey[700])),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[700],
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      // Read the attachment list first, so we know which files to remove from Storage
      final doc = await FirebaseFirestore.instance.collection('reports').doc(reportId).get();
      final attachments = (doc.data()?['attachments'] as List?) ?? [];

      // Delete the report itself
      await FirebaseFirestore.instance.collection('reports').doc(reportId).delete();

      // Then clean up its files from Storage
      for (final att in attachments) {
        final storagePath = (att as Map)['storagePath'];
        if (storagePath != null) {
          try {
            await FirebaseStorage.instance.ref(storagePath).delete();
          } catch (_) {
            // Ignore - file may already be gone
          }
        }
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('"$title" deleted.'), backgroundColor: AppColors.appPrimary),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to delete. Please try again.')),
        );
      }
    }
  }

  Future<void> _openAttachment(String? url) async {
    if (url == null) return;
    final uri = Uri.parse(url);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open document.')),
        );
      }
    }
  }

  Future<void> _confirmDeleteAttachment(
      BuildContext sheetContext,
      String reportId,
      Map<String, dynamic> attachment,
      ) async {
    final confirm = await showDialog<bool>(
      context: sheetContext,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Delete Attachment?'),
        content: Text('Delete "${attachment['name'] ?? 'this document'}"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancel', style: TextStyle(color: Colors.grey[700])),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[700],
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final storagePath = attachment['storagePath'];
      if (storagePath != null) {
        try {
          await FirebaseStorage.instance.ref(storagePath).delete();
        } catch (_) {
          // Ignore - file may already be gone
        }
      }

      await FirebaseFirestore.instance.collection('reports').doc(reportId).update({
        'attachments': FieldValue.arrayRemove([attachment]),
      });

      if (sheetContext.mounted) {
        Navigator.of(sheetContext).pop(); // close the bottom sheet
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Attachment deleted.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to delete attachment.')),
        );
      }
    }
  }

  void _showDetail(BuildContext context, String reportId, Map<String, dynamic> data) {
    final reportDate = data['reportDate'] != null
        ? DateFormat('dd MMM yyyy').format((data['reportDate'] as Timestamp).toDate())
        : '-';

    final attachments = ((data['attachments'] as List?) ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data['title'] ?? 'Untitled',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.appPrimary),
                ),
                const SizedBox(height: 4),
                Text('Report Date: $reportDate', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                const Divider(height: 24),
                Text(data['description'] ?? '-', style: const TextStyle(fontSize: 14)),
                const SizedBox(height: 8),
                Text(
                  'Added by: ${data['createdByEmail'] ?? '-'}',
                  style: TextStyle(color: Colors.grey[500], fontSize: 11),
                ),
                if (attachments.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  Text(
                    'ATTACHMENTS',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey[600],
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...attachments.map((att) {
                    final isPdf = att['type'] == 'pdf';
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Icon(
                            isPdf ? Icons.picture_as_pdf_outlined : Icons.image_outlined,
                            color: isPdf ? Colors.red[400] : Colors.blue[400],
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: InkWell(
                              onTap: () => _openAttachment(att['url']),
                              child: Text(
                                att['name'] ?? 'Document',
                                style: const TextStyle(
                                  fontSize: 13,
                                  decoration: TextDecoration.underline,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          if (_isAdmin)
                            IconButton(
                              icon: Icon(Icons.delete_outline, size: 18, color: Colors.red[700]),
                              onPressed: () => _confirmDeleteAttachment(sheetContext, reportId, att),
                            ),
                        ],
                      ),
                    );
                  }),
                ],
                if (_isAdmin) ...[
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.of(context).pop();
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => AddReportScreen(
                                  currentUserRole: _currentUserRole,
                                  reportId: reportId,
                                  currentData: data,
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.edit_outlined, color: AppColors.appPrimary),
                          label: const Text('Edit', style: TextStyle(color: AppColors.appPrimary)),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppColors.appPrimary),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.of(context).pop();
                            _confirmDelete(context, reportId, data['title'] ?? 'this report');
                          },
                          icon: Icon(Icons.delete_outline, color: Colors.red[700]),
                          label: Text('Delete', style: TextStyle(color: Colors.red[700])),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: Colors.red[700]!),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_roleLoaded) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppColors.appPrimary)),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.appBackground,
      appBar: AppBar(
        backgroundColor: AppColors.appPrimary,
        elevation: 0,
        title: const Text('Reports'),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.appPrimary,
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => AddReportScreen(currentUserRole: _currentUserRole),
            ),
          );
        },
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('reports')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Something went wrong.'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator(color: AppColors.appPrimary));
          }

          final docs = snapshot.data!.docs;

          if (docs.isEmpty) {
            return Center(
              child: Text('No reports yet.', style: TextStyle(color: Colors.grey[600])),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;
              final reportDate = data['reportDate'] != null
                  ? DateFormat('dd MMM yyyy').format((data['reportDate'] as Timestamp).toDate())
                  : '-';
              final attachmentCount = ((data['attachments'] as List?) ?? []).length;

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
                    child: const Icon(Icons.description_outlined, color: AppColors.appPrimary),
                  ),
                  title: Text(
                    data['title'] ?? 'Untitled',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    reportDate,
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                  trailing: attachmentCount > 0
                      ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.attach_file, size: 16, color: Colors.grey[500]),
                      const SizedBox(width: 2),
                      Text(
                        '$attachmentCount',
                        style: TextStyle(color: Colors.grey[500], fontSize: 12),
                      ),
                    ],
                  )
                      : null,
                ),
              );
            },
          );
        },
      ),
    );
  }
}