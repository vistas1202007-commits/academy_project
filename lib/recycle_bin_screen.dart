import 'package:cloud_firestore/cloud_firestore.dart';
import 'live_query.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'admin_gate.dart';
import 'app_colors.dart';
import 'responsive.dart';
import 'soft_delete.dart';
import 'ui_kit.dart';

/// One tab: which collection, the tab name and how the row title is built
class _BinTab {
  final String collection;
  final String label;
  final IconData icon;
  final String Function(Map<String, dynamic> data) titleOf;
  const _BinTab(this.collection, this.label, this.icon, this.titleOf);
}

String _s(dynamic v) => (v ?? '').toString().trim();

String _join(List<String> parts) {
  final list = parts.where((p) => p.isNotEmpty).toList();
  return list.isEmpty ? 'Unnamed' : list.join(' · ');
}

/// Shared dialog for Delete buttons; true = move to the Recycle Bin
Future<bool> confirmMoveToBin(BuildContext context, String name) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      title: const Text('Move to Recycle Bin?'),
      content: Text('$name will be moved to the Recycle Bin. An Admin can restore it from there.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.danger,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: const Text('Move to Bin', style: TextStyle(color: Colors.white)),
        ),
      ],
    ),
  );
  return ok == true;
}

final List<_BinTab> _tabs = [
  _BinTab('students', 'Trainees', Icons.school_outlined, (d) => _join([_s(d['name']), _s(d['traineeId'])])),
  _BinTab('enquiries', 'Enquiries', Icons.support_agent_outlined, (d) => _join([_s(d['traineeName']), _s(d['mobile'])])),
  _BinTab('placements', 'Placements', Icons.work_outline, (d) => _join([_s(d['studentName']), _s(d['companyName'])])),
  _BinTab('companies', 'Companies', Icons.business_outlined, (d) => _join([_s(d['companyName']), _s(d['location'])])),
];

class RecycleBinScreen extends StatelessWidget {
  const RecycleBinScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: _tabs.length,
      child: Scaffold(
        backgroundColor: AppColors.appBackground,
        appBar: AppBar(
          flexibleSpace: const AppBarRibbon(),
          title: const Text('Recycle Bin'),
          backgroundColor: AppColors.appPrimary,
          foregroundColor: Colors.white,
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            indicatorColor: AppColors.aurora,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: [for (final t in _tabs) Tab(text: t.label)],
          ),
        ),
        body: PageWash(child: ContentWidth(
          maxWidth: 900,
          child: AdminGate(
            screenName: 'Recycle Bin',
            child: TabBarView(children: [for (final t in _tabs) _BinList(tab: t)]),
          ),
        )),
      ),
    );
  }
}

class _BinList extends StatelessWidget {
  final _BinTab tab;
  const _BinList({required this.tab});

  Future<bool> _confirm(BuildContext context, String title, String message, String action, Color color) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: color,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(action, style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    return ok == true;
  }

  void _snack(BuildContext context, String message, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: error ? AppColors.danger : AppColors.appPrimary),
    );
  }

  Future<void> _restore(BuildContext context, DocumentReference ref, String title) async {
    if (!await _confirm(context, 'Restore?', '"$title" will be restored exactly as it was.', 'Restore',
        AppColors.appPrimary)) {
      return;
    }
    try {
      await restoreFromBin(ref);
      if (context.mounted) _snack(context, '"$title" restored.');
    } catch (_) {
      if (context.mounted) _snack(context, 'Could not restore. Please try again.', error: true);
    }
  }

  Future<void> _purge(BuildContext context, DocumentReference ref, String title) async {
    if (!await _confirm(context, 'Delete forever?',
        '"$title" will be permanently deleted. This action cannot be undone. Continue?', 'Delete forever',
        AppColors.danger)) {
      return;
    }
    try {
      await ref.delete();
      if (context.mounted) _snack(context, '"$title" deleted forever.');
    } catch (_) {
      if (context.mounted) _snack(context, 'Could not delete. Please try again.', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      // Whole collection; deleted ones are filtered client-side (no index)
      stream: FirebaseFirestore.instance.collection(tab.collection).liveSnapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          return const EmptyState(icon: Icons.cloud_off_outlined, message: 'Could not load data. Please try again.');
        }
        if (!snap.hasData) {
          return const AppLoader();
        }
        final docs = snap.data!.docs.where((d) => !isLive(d.data())).toList()
          ..sort((a, b) {
            final ta = a.data()['deletedAt'];
            final tb = b.data()['deletedAt'];
            final da = ta is Timestamp ? ta.toDate() : DateTime(0);
            final db = tb is Timestamp ? tb.toDate() : DateTime(0);
            return db.compareTo(da);
          });

        if (docs.isEmpty) {
          return EmptyState(icon: tab.icon, message: 'No deleted ${tab.label.toLowerCase()}.');
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, i) {
            final doc = docs[i];
            final data = doc.data();
            final title = tab.titleOf(data);
            final at = data['deletedAt'];
            final when = at is Timestamp ? DateFormat('dd MMM yyyy, hh:mm a').format(at.toDate()) : 'Just now';
            return Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
              decoration: AppCard.decoration,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(tab.icon, color: AppColors.appPrimary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(title,
                                style: const TextStyle(
                                    fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textDark)),
                            const SizedBox(height: 2),
                            Text('Deleted $when',
                                style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  // Buttons on a separate line below so it fits on phone too
                  Align(
                    alignment: Alignment.centerRight,
                    child: Wrap(
                      children: [
                        TextButton.icon(
                          onPressed: () => _restore(context, doc.reference, title),
                          icon: const Icon(Icons.restore, size: 18, color: AppColors.appPrimary),
                          label: const Text('Restore', style: TextStyle(color: AppColors.appPrimary)),
                        ),
                        TextButton.icon(
                          onPressed: () => _purge(context, doc.reference, title),
                          icon: const Icon(Icons.delete_forever_outlined, size: 18, color: AppColors.danger),
                          label: const Text('Delete forever', style: TextStyle(color: AppColors.danger)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
