import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'app_colors.dart';

/// Admin-only analytics. Saara data ek students stream (aur conversion ke liye
/// enquiries stream) se aata hai, calculation client-side hoti hai.
class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  late final Future<bool> _isAdminFuture = _checkAdmin();

  Future<bool> _checkAdmin() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return false;
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      return (doc.data()?['role'] ?? '').toString() == 'admin';
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Analytics'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: FutureBuilder<bool>(
        future: _isAdminFuture,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator(color: AppColors.primary));
          }
          if (snap.data != true) return const _AccessDenied();
          return const _AnalyticsBody();
        },
      ),
    );
  }
}

class _AccessDenied extends StatelessWidget {
  const _AccessDenied();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock_outline, size: 56, color: AppColors.textMuted),
            SizedBox(height: 12),
            Text(
              'Access denied',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textDark),
            ),
            SizedBox(height: 6),
            Text(
              'Analytics sirf Admin dekh sakte hain.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Data
// ---------------------------------------------------------------------------

class _Stats {
  int total = 0;
  int active = 0;
  int completed = 0;
  int dropped = 0;

  /// Pichhle 12 mahine (purane se naya), har mahine ka pehla din
  final List<DateTime> months = [];
  final List<int> monthCounts = List.filled(12, 0);

  final Map<String, int> courses = {};
  final Map<String, int> genders = {};
  final Map<String, int> ageGroups = {'18-20': 0, '21-23': 0, '24-26': 0, '27+': 0};

  /// Top 10 villages, sorted
  List<MapEntry<String, int>> villages = [];
}

DateTime? _toDate(dynamic v) {
  if (v is Timestamp) return v.toDate();
  if (v is DateTime) return v;
  return null;
}

String _str(dynamic v) => (v ?? '').toString().trim();

String _titleCase(String s) => s
    .split(RegExp(r'\s+'))
    .where((w) => w.isNotEmpty)
    .map((w) => w[0].toUpperCase() + w.substring(1).toLowerCase())
    .join(' ');

_Stats _compute(List<QueryDocumentSnapshot> docs) {
  final s = _Stats();
  final now = DateTime.now();
  for (var i = 11; i >= 0; i--) {
    s.months.add(DateTime(now.year, now.month - i, 1));
  }
  final firstKey = s.months.first.year * 12 + s.months.first.month;

  final villageCounts = <String, int>{};

  for (final doc in docs) {
    final raw = doc.data();
    if (raw is! Map<String, dynamic>) continue;
    final d = raw;
    s.total++;

    final status = _str(d['status']);
    if (status == 'Joined' || status == 'Ongoing') s.active++;
    if (status == 'Completed') s.completed++;
    if (status == 'Dropped') s.dropped++;

    final adm = _toDate(d['admissionDate']);
    if (adm != null) {
      final idx = adm.year * 12 + adm.month - firstKey;
      if (idx >= 0 && idx < 12) s.monthCounts[idx]++;
    }

    final course = _str(d['course']);
    final courseKey = course.isEmpty ? 'Unknown' : course;
    s.courses[courseKey] = (s.courses[courseKey] ?? 0) + 1;

    final gender = _str(d['gender']);
    final genderKey = (gender == 'Male' || gender == 'Female') ? gender : 'Other';
    s.genders[genderKey] = (s.genders[genderKey] ?? 0) + 1;

    final dob = _toDate(d['dob']);
    if (dob != null) {
      var age = now.year - dob.year;
      if (now.month < dob.month || (now.month == dob.month && now.day < dob.day)) age--;
      String? group;
      if (age >= 27) {
        group = '27+';
      } else if (age >= 24) {
        group = '24-26';
      } else if (age >= 21) {
        group = '21-23';
      } else if (age >= 18) {
        group = '18-20';
      }
      if (group != null) s.ageGroups[group] = s.ageGroups[group]! + 1;
    }

    final village = _str(d['village']).toLowerCase();
    if (village.isNotEmpty) villageCounts[village] = (villageCounts[village] ?? 0) + 1;
  }

  s.villages = (villageCounts.entries.toList()..sort((a, b) => b.value.compareTo(a.value)))
      .take(10)
      .map((e) => MapEntry(_titleCase(e.key), e.value))
      .toList();
  return s;
}

// ---------------------------------------------------------------------------
// Colors: sirf green aur gold ke shades
// ---------------------------------------------------------------------------

/// t = 0 -> green, t = 1 -> gold
Color _shade(double t) => Color.lerp(AppColors.primary, AppColors.accent, t)!;

Color _seriesColor(int i, int count) => count <= 1 ? AppColors.primary : _shade(i / (count - 1));

/// Y-axis ke liye ~4 saaf steps
double _niceInterval(int maxValue) => math.max(1, (maxValue / 4).ceil()).toDouble();

// ---------------------------------------------------------------------------
// UI
// ---------------------------------------------------------------------------

class _AnalyticsBody extends StatelessWidget {
  const _AnalyticsBody();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('students').snapshots(),
      builder: (context, studentSnap) {
        if (studentSnap.hasError) {
          return const Center(
            child: Text('Data load nahi ho paya', style: TextStyle(color: AppColors.textMuted)),
          );
        }
        if (!studentSnap.hasData) {
          return const Center(child: CircularProgressIndicator(color: AppColors.primary));
        }
        final stats = _compute(studentSnap.data!.docs);

        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collection('enquiries').snapshots(),
                  builder: (context, enquirySnap) {
                    String conversion = '--';
                    final enquiries = enquirySnap.data?.docs;
                    if (enquiries != null && enquiries.isNotEmpty) {
                      final registered = enquiries.where((e) {
                        final data = e.data();
                        return data is Map<String, dynamic> && _str(data['status']) == 'Registered';
                      }).length;
                      conversion = '${(registered * 100 / enquiries.length).toStringAsFixed(1)}%';
                    }
                    return _KpiGrid(stats: stats, conversion: conversion);
                  },
                ),
                const SizedBox(height: 16),
                _ChartCard(
                  title: 'Enrollment Trend (pichhle 12 mahine)',
                  hasData: stats.monthCounts.any((c) => c > 0),
                  child: _EnrollmentLineChart(stats: stats),
                ),
                _ChartCard(
                  title: 'Course-wise Trainees',
                  hasData: stats.total > 0,
                  child: _SimpleBarChart(
                    entries: (stats.courses.entries.toList()..sort((a, b) => b.value.compareTo(a.value))),
                  ),
                ),
                _ChartCard(
                  title: 'Gender Split',
                  hasData: stats.total > 0,
                  child: _GenderDonut(stats: stats),
                ),
                _ChartCard(
                  title: 'Age Groups',
                  hasData: stats.ageGroups.values.any((c) => c > 0),
                  child: _SimpleBarChart(entries: stats.ageGroups.entries.toList()),
                ),
                _ChartCard(
                  title: 'Top 10 Villages',
                  hasData: stats.villages.isNotEmpty,
                  height: null,
                  child: _VillageBars(entries: stats.villages),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _KpiGrid extends StatelessWidget {
  final _Stats stats;
  final String conversion;
  const _KpiGrid({required this.stats, required this.conversion});

  @override
  Widget build(BuildContext context) {
    final dropoutPct = stats.total == 0 ? '--' : '${(stats.dropped * 100 / stats.total).toStringAsFixed(1)}%';
    final cards = [
      _KpiCard(icon: Icons.groups_outlined, label: 'Total Trainees', value: '${stats.total}', color: AppColors.primary),
      _KpiCard(icon: Icons.play_circle_outline, label: 'Active', value: '${stats.active}', color: _shade(0.35)),
      _KpiCard(icon: Icons.verified_outlined, label: 'Completed', value: '${stats.completed}', color: _shade(0.7)),
      _KpiCard(
        icon: Icons.person_off_outlined,
        label: 'Dropped',
        value: '${stats.dropped}',
        subtitle: 'Dropout $dropoutPct',
        color: AppColors.accent,
      ),
      _KpiCard(
        icon: Icons.trending_up,
        label: 'Enquiry → Registered',
        value: conversion,
        color: AppColors.primary,
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 600 ? 3 : 2;
        const spacing = 12.0;
        final width = (constraints.maxWidth - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [for (final c in cards) SizedBox(width: width, child: c)],
        );
      },
    );
  }
}

class _KpiCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String? subtitle;
  final Color color;
  const _KpiCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 26),
            const SizedBox(height: 10),
            Text(
              value,
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, color: AppColors.textDark),
            ),
            Text(
              subtitle ?? '',
              style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChartCard extends StatelessWidget {
  final String title;
  final bool hasData;
  final Widget child;

  /// null = child apni height khud le
  final double? height;
  const _ChartCard({
    required this.title,
    required this.hasData,
    required this.child,
    this.height = 220,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textDark),
            ),
            const SizedBox(height: 16),
            if (!hasData)
              const SizedBox(height: 160, child: _EmptyChart())
            else if (height != null)
              SizedBox(height: height, child: child)
            else
              child,
          ],
        ),
      ),
    );
  }
}

class _EmptyChart extends StatelessWidget {
  const _EmptyChart();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.bar_chart_outlined, size: 40, color: AppColors.textMuted),
          SizedBox(height: 8),
          Text('Data aate hi chart dikhega', style: TextStyle(color: AppColors.textMuted)),
        ],
      ),
    );
  }
}

const _axisStyle = TextStyle(fontSize: 11, color: AppColors.textMuted);

AxisTitles get _noTitles => const AxisTitles(sideTitles: SideTitles(showTitles: false));

AxisTitles _leftCountTitles(double interval) => AxisTitles(
      sideTitles: SideTitles(
        showTitles: true,
        reservedSize: 32,
        interval: interval,
        getTitlesWidget: (value, meta) {
          if (value != value.roundToDouble()) return const SizedBox.shrink();
          return Text(value.toInt().toString(), style: _axisStyle);
        },
      ),
    );

FlGridData _grid(double interval) => FlGridData(
      drawVerticalLine: false,
      horizontalInterval: interval,
      getDrawingHorizontalLine: (_) => FlLine(
        color: AppColors.textMuted.withValues(alpha: 0.15),
        strokeWidth: 1,
      ),
    );

class _EnrollmentLineChart extends StatelessWidget {
  final _Stats stats;
  const _EnrollmentLineChart({required this.stats});

  @override
  Widget build(BuildContext context) {
    final maxCount = stats.monthCounts.reduce(math.max);
    final interval = _niceInterval(maxCount);
    final fmt = DateFormat('MMM');
    return LineChart(
      LineChartData(
        minX: 0,
        maxX: 11,
        minY: 0,
        maxY: (maxCount / interval).ceil() * interval + interval,
        gridData: _grid(interval),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: _noTitles,
          rightTitles: _noTitles,
          leftTitles: _leftCountTitles(interval),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 26,
              interval: 1,
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                if (i < 0 || i > 11 || value != i.toDouble()) return const SizedBox.shrink();
                // Phone pe bheed na ho isliye har doosra mahina
                final narrow = meta.parentAxisSize < 420;
                if (narrow && i.isOdd) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(fmt.format(stats.months[i]), style: _axisStyle),
                );
              },
            ),
          ),
        ),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => AppColors.primary,
            getTooltipItems: (spots) => spots
                .map((s) => LineTooltipItem(
                      '${DateFormat('MMM yyyy').format(stats.months[s.x.toInt()])}\n${s.y.toInt()}',
                      const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                    ))
                .toList(),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: [
              for (var i = 0; i < 12; i++) FlSpot(i.toDouble(), stats.monthCounts[i].toDouble()),
            ],
            isCurved: true,
            preventCurveOverShooting: true,
            color: AppColors.primary,
            barWidth: 3,
            dotData: FlDotData(
              getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(
                radius: 3.5,
                color: AppColors.accent,
                strokeWidth: 1.5,
                strokeColor: AppColors.primary,
              ),
            ),
            belowBarData: BarAreaData(
              show: true,
              color: AppColors.primary.withValues(alpha: 0.12),
            ),
          ),
        ],
      ),
    );
  }
}

/// Vertical bar chart: course aur age groups dono ke liye
class _SimpleBarChart extends StatelessWidget {
  final List<MapEntry<String, int>> entries;
  const _SimpleBarChart({required this.entries});

  @override
  Widget build(BuildContext context) {
    final maxCount = entries.map((e) => e.value).fold(0, math.max);
    final interval = _niceInterval(maxCount);
    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        minY: 0,
        maxY: (maxCount / interval).ceil() * interval + interval,
        gridData: _grid(interval),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: _noTitles,
          rightTitles: _noTitles,
          leftTitles: _leftCountTitles(interval),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                if (i < 0 || i >= entries.length) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    entries[i].key,
                    style: _axisStyle,
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              },
            ),
          ),
        ),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => AppColors.primary,
            getTooltipItem: (group, groupIndex, rod, rodIndex) => BarTooltipItem(
              '${entries[group.x].key}\n${rod.toY.toInt()}',
              const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
            ),
          ),
        ),
        barGroups: [
          for (var i = 0; i < entries.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: entries[i].value.toDouble(),
                  color: _seriesColor(i, entries.length),
                  width: 22,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _GenderDonut extends StatelessWidget {
  final _Stats stats;
  const _GenderDonut({required this.stats});

  static const _order = ['Male', 'Female', 'Other'];

  Color _colorFor(String g) {
    switch (g) {
      case 'Male':
        return AppColors.primary;
      case 'Female':
        return AppColors.accent;
      default:
        return AppColors.primary.withValues(alpha: 0.4);
    }
  }

  @override
  Widget build(BuildContext context) {
    final entries = _order
        .where((g) => (stats.genders[g] ?? 0) > 0)
        .map((g) => MapEntry(g, stats.genders[g]!))
        .toList();
    return Row(
      children: [
        Expanded(
          child: Stack(
            alignment: Alignment.center,
            children: [
              PieChart(
                PieChartData(
                  centerSpaceRadius: 52,
                  sectionsSpace: 2,
                  sections: [
                    for (final e in entries)
                      PieChartSectionData(
                        value: e.value.toDouble(),
                        color: _colorFor(e.key),
                        radius: 34,
                        showTitle: false,
                      ),
                  ],
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${stats.total}',
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textDark),
                  ),
                  const Text('Total', style: _axisStyle),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final e in entries)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(color: _colorFor(e.key), shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${e.key}  ${e.value} (${(e.value * 100 / stats.total).toStringAsFixed(0)}%)',
                      style: const TextStyle(fontSize: 13, color: AppColors.textDark),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// Horizontal bars taaki lambe village naam bhi poore padhe ja sakein
class _VillageBars extends StatelessWidget {
  final List<MapEntry<String, int>> entries;
  const _VillageBars({required this.entries});

  @override
  Widget build(BuildContext context) {
    final maxCount = entries.first.value;
    return Column(
      children: [
        for (var i = 0; i < entries.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(
              children: [
                SizedBox(
                  width: 110,
                  child: Text(
                    entries[i].key,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, color: AppColors.textDark),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) => Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        height: 18,
                        width: math.max(4, constraints.maxWidth * entries[i].value / maxCount),
                        decoration: BoxDecoration(
                          color: _seriesColor(i, entries.length),
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 32,
                  child: Text(
                    '${entries[i].value}',
                    textAlign: TextAlign.right,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textDark),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
