import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'admin_gate.dart';
import 'app_colors.dart';
import 'at_risk_logic.dart';
import 'responsive.dart';
import 'student_profile_screen.dart';

/// Students docs ko plain maps me badalta hai; har map me 'id' = doc id
List<Map<String, dynamic>> studentMapsFrom(QuerySnapshot<Map<String, dynamic>> snap) =>
    snap.docs.map((d) => {...d.data(), 'id': d.id}).toList();

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

  Future<List<TraineeRisk>> _load() async {
    final db = FirebaseFirestore.instance;
    final results = await Future.wait([
      db.collection('students').get(),
      db.collection('attendance').get(),
    ]);
    return assessTrainees(studentMapsFrom(results[0]), attendanceDaysFrom(results[1]), DateTime.now());
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
            text: 'Data load nahi ho paaya. Internet check karke dobara try karein.',
            onRetry: _refresh,
          );
        }
        final list = snap.data!;
        if (list.isEmpty) {
          return _Message(
            icon: Icons.groups_outlined,
            text: 'Abhi koi Joined/Ongoing trainee nahi hai.',
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
              return _RiskRow(risk: list[i - 1]);
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
            'Pichhle $kRiskWindowDays din ki attendance aur fees ke hisaab se. High = 60+, Medium = 30-59.',
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
  const _RiskRow({required this.risk});

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
