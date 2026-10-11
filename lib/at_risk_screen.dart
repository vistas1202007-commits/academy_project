import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'admin_gate.dart';
import 'app_colors.dart';
import 'soft_delete.dart';
import 'at_risk_logic.dart';
import 'friendly_error.dart';
import 'notification_log.dart';
import 'responsive.dart';
import 'student_profile_screen.dart';

/// Students docs ko plain maps me badalta hai; har map me 'id' = doc id
List<Map<String, dynamic>> studentMapsFrom(QuerySnapshot<Map<String, dynamic>> snap) =>
    snap.docs.map((d) => {...d.data(), 'id': d.id}).toList();

/// [studentMapsFrom] jaisa, par Recycle Bin wale trainees ke bina
List<Map<String, dynamic>> liveStudentMapsFrom(QuerySnapshot<Map<String, dynamic>> snap) =>
    studentMapsFrom(snap).where(isLive).toList();

/// Live trainees ke doc id, [liveAttendance] ke liye
Set<String> idsOf(Iterable<Map<String, dynamic>> students) => {for (final s in students) s['id'] as String};

/// Attendance docs se [AttendanceDay]; bina date wale docs chhod deta hai
List<AttendanceDay> attendanceDaysFrom(QuerySnapshot<Map<String, dynamic>> snap) {
  final days = <AttendanceDay>[];
  for (final doc in snap.docs) {
    final data = doc.data();
    final date = data['date'];
    final raw = data['statusMap'];
    if (date is! Timestamp || raw is! Map) continue;
    days.add(AttendanceDay(
      date.toDate(),
      raw.map((k, v) => MapEntry(k.toString(), (v ?? '').toString())),
      batchName: (data['batchName'] ?? '').toString().trim(),
    ));
  }
  return days;
}

Color riskColor(RiskLevel level) => switch (level) {
      RiskLevel.high => AppColors.danger,
      RiskLevel.medium => AppColors.warning,
      RiskLevel.low => AppColors.success,
    };

/// Admin-only: Joined/Ongoing trainees ka risk score, sabse zyada pehle
class AtRiskScreen extends StatelessWidget {
  const AtRiskScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.appBackground,
      appBar: AppBar(
        title: const Text('At-Risk Trainees'),
        backgroundColor: AppColors.appPrimary,
        foregroundColor: Colors.white,
      ),
      body: const ContentWidth(
        maxWidth: 900,
        child: AdminGate(screenName: 'At-Risk Trainees', child: _AtRiskBody()),
      ),
    );
  }
}

class _AtRiskBody extends StatefulWidget {
  const _AtRiskBody();

  @override
  State<_AtRiskBody> createState() => _AtRiskBodyState();
}

class _AtRiskBodyState extends State<_AtRiskBody> {
  late Future<List<TraineeRisk>> _future = _load();

  /// Guardian alert ke liye poora student data (doc id se)
  Map<String, Map<String, dynamic>> _studentsById = {};
  final Set<String> _notifying = {};

  Future<List<TraineeRisk>> _load() async {
    final db = FirebaseFirestore.instance;
    final results = await Future.wait([
      db.collection('students').get(),
      db.collection('attendance').get(),
    ]);
    final students = liveStudentMapsFrom(results[0]);
    _studentsById = {for (final s in students) s['id'] as String: s};
    return assessTrainees(students, liveAttendance(attendanceDaysFrom(results[1]), idsOf(students)), DateTime.now());
  }

  /// High-risk trainee ke guardian ke liye simulated alert
  Future<void> _notify(TraineeRisk risk) async {
    final student = _studentsById[risk.id];
    if (student == null) return;
    setState(() => _notifying.add(risk.id));
    String message;
    var error = false;
    try {
      final batch = riskAlert(student, risk.result.reasons, DateTime.now());
      if (batch.items.isEmpty) {
        message = 'No guardian phone on record for ${risk.name}.';
        error = true;
      } else {
        final result = await logNotifications(batch.items);
        message = result.logged > 0 ? 'Risk alert logged (simulated).' : 'Already logged today.';
      }
    } catch (e) {
      debugPrint('Risk alert failed: $e');
      message = friendlyError(e);
      error = true;
    }
    if (!mounted) return;
    setState(() => _notifying.remove(risk.id));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: error ? AppColors.danger : AppColors.appPrimary),
    );
  }

  Future<void> _refresh() async {
    final next = _load();
    setState(() => _future = next);
    try {
      await next;
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<TraineeRisk>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator(color: AppColors.appPrimary));
        }
        if (snap.hasError) {
          return _Message(
            icon: Icons.cloud_off_outlined,
            text: 'Could not load data. Check your internet connection and try again.',
            onRetry: _refresh,
          );
        }
        final list = snap.data!;
        if (list.isEmpty) {
          return _Message(
            icon: Icons.groups_outlined,
            text: 'No active (Joined/Ongoing) trainees yet.',
            onRetry: _refresh,
          );
        }
        final counts = {for (final l in RiskLevel.values) l: 0};
        for (final t in list) {
          counts[t.result.level] = counts[t.result.level]! + 1;
        }
        return RefreshIndicator(
          color: AppColors.appPrimary,
          onRefresh: _refresh,
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            itemCount: list.length + 1,
            itemBuilder: (context, i) {
              if (i == 0) return _header(counts);
              final risk = list[i - 1];
              return _RiskRow(
                risk: risk,
                notifying: _notifying.contains(risk.id),
                onNotify: risk.result.level == RiskLevel.high ? () => _notify(risk) : null,
              );
            },
          ),
        );
      },
    );
  }

  Widget _header(Map<RiskLevel, int> counts) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              for (final level in RiskLevel.values) ...[
                if (level != RiskLevel.high) const SizedBox(width: 10),
                Expanded(child: _CountCard(level: level, count: counts[level]!)),
              ],
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'Based on attendance and fees in the last $kRiskWindowDays days. High = 60+, Medium = 30-59.',
            style: TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

class _CountCard extends StatelessWidget {
  final RiskLevel level;
  final int count;
  const _CountCard({required this.level, required this.count});

  @override
  Widget build(BuildContext context) {
    final color = riskColor(level);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Text(
            '$count',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: color),
          ),
          const SizedBox(height: 2),
          Text(
            level.label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

class _RiskRow extends StatelessWidget {
  final TraineeRisk risk;

  /// Sirf High-risk rows ke liye; null = button nahi
  final VoidCallback? onNotify;
  final bool notifying;
  const _RiskRow({required this.risk, this.onNotify, this.notifying = false});

  @override
  Widget build(BuildContext context) {
    final r = risk.result;
    final color = riskColor(r.level);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (context) => StudentProfileScreen(studentId: risk.id)),
          ),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        risk.name,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textDark),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        risk.batch.isEmpty ? 'No batch' : risk.batch,
                        style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                      ),
                      if (r.reasons.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          r.reasons.join(', '),
                          style: const TextStyle(fontSize: 12.5, color: AppColors.textDark),
                        ),
                      ],
                      if (onNotify != null) ...[
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: notifying ? null : onNotify,
                          icon: notifying
                              ? const SizedBox(
                                  height: 14,
                                  width: 14,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.appPrimary),
                                )
                              : const Icon(Icons.notifications_active_outlined, size: 16),
                          label: const Text('Notify guardian (simulated)'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.appPrimary,
                            side: const BorderSide(color: AppColors.border),
                            visualDensity: VisualDensity.compact,
                            textStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${r.score}',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: color),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        r.level.label,
                        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: color),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  final IconData icon;
  final String text;
  final VoidCallback onRetry;
  const _Message({required this.icon, required this.text, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 52, color: AppColors.textMuted),
            const SizedBox(height: 12),
            Text(text, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textMuted)),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh'),
              style: TextButton.styleFrom(foregroundColor: AppColors.appPrimary),
            ),
          ],
        ),
      ),
    );
  }
}
