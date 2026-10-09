import 'dart:async';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'analytics_export.dart';
import 'app_colors.dart';

/// Admin-only analytics. Students, enquiries, attendance aur placements ke
/// plain streams aate hain; date filter aur saari calculation client-side.
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

/// [asOf]: trend ke 12 mahine is date pe khatam hote hain (default aaj)
_Stats _compute(List<QueryDocumentSnapshot> docs, {DateTime? asOf}) {
  final s = _Stats();
  final now = DateTime.now();
  final end = asOf ?? now;
  for (var i = 11; i >= 0; i--) {
    s.months.add(DateTime(end.year, end.month - i, 1));
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
// Date filter
// ---------------------------------------------------------------------------

enum _RangePreset { all, last30, last90, custom }

const _presetLabels = {
  _RangePreset.all: 'All time',
  _RangePreset.last30: 'Last 30 days',
  _RangePreset.last90: 'Last 90 days',
  _RangePreset.custom: 'Custom',
};

class _DateFilter {
  final _RangePreset preset;

  /// [start, end) din ki shuruaat se. Dono null = All time
  final DateTime? start;
  final DateTime? end;
  const _DateFilter._(this.preset, this.start, this.end);

  static const all = _DateFilter._(_RangePreset.all, null, null);

  /// Aaj samet pichhle [days] din
  factory _DateFilter.lastDays(_RangePreset preset, int days) {
    final now = DateTime.now();
    return _DateFilter._(
      preset,
      DateTime(now.year, now.month, now.day - (days - 1)),
      DateTime(now.year, now.month, now.day + 1),
    );
  }

  factory _DateFilter.custom(DateTimeRange r) => _DateFilter._(
        _RangePreset.custom,
        DateTime(r.start.year, r.start.month, r.start.day),
        DateTime(r.end.year, r.end.month, r.end.day + 1),
      );

  bool get isAll => start == null;

  /// Range ka aakhri din (null = All time)
  DateTime? get lastDay => end == null ? null : DateTime(end!.year, end!.month, end!.day - 1);

  /// All time me sab; range me jis doc ki date nahi hai wo bahar
  bool contains(DateTime? d) {
    if (isAll) return true;
    if (d == null) return false;
    return !d.isBefore(start!) && d.isBefore(end!);
  }

  String get description {
    if (isAll) return 'All time';
    final f = DateFormat('d MMM yyyy');
    return '${f.format(start!)} – ${f.format(lastDay!)}';
  }
}

// ---------------------------------------------------------------------------
// F3 data
// ---------------------------------------------------------------------------

const _placedStatuses = {'Joined', 'Selected', 'Self-Employed'};
const _inTrainingOrDone = {'Joined', 'Ongoing', 'Completed'};

/// Itne din se kam attendance wale trainees chronic list me nahi aate
const _minDaysForAbsentee = 5;
const _attendanceThreshold = 75.0;

class _FunnelStep {
  final String label;
  final int count;

  /// Pichhle step ka kitna % (pehle step ke liye null)
  final String? pctOfPrev;
  const _FunnelStep(this.label, this.count, this.pctOfPrev);
}

class _BatchFee {
  final String batch;
  final double collected;
  final double pending;
  const _BatchFee(this.batch, this.collected, this.pending);
  double get total => collected + pending;
}

class _Absentee {
  final String name;
  final String batch;
  final double pct;
  final int days;
  const _Absentee(this.name, this.batch, this.pct, this.days);
}

class _Analytics {
  late _Stats stats;
  String conversion = '--';

  List<_FunnelStep> funnel = [];

  double feeCollected = 0;
  double feePending = 0;
  List<_BatchFee> feeBatches = [];

  /// Batch -> present % (0-100)
  List<MapEntry<String, double>> batchAttendance = [];
  List<_Absentee> absentees = [];

  int placed = 0;
  String placementPct = '--';
  double? avgSalary;
  double? medianSalary;
  int salaryCount = 0;
  List<MapEntry<String, int>> employmentTypes = [];
  List<MapEntry<String, int>> topCompanies = [];
}

Map<String, dynamic>? _data(QueryDocumentSnapshot doc) {
  final raw = doc.data();
  return raw is Map<String, dynamic> ? raw : null;
}

/// Number ya number-wali string; kuch na mile to 0
double _num(dynamic v) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v.replaceAll(RegExp(r'[^0-9.\-]'), '')) ?? 0;
  return 0;
}

/// "₹15,000/month" -> 15000. Commas hata ke pehla digits ka group; na mile to null
int? _parseSalary(dynamic v) {
  final match = RegExp(r'\d+').firstMatch(_str(v).replaceAll(',', ''));
  final value = match == null ? null : int.tryParse(match.group(0)!);
  return (value == null || value <= 0) ? null : value;
}

/// [whole] 0 ho to "--", divide-by-zero nahi
String _pct(num part, num whole, {bool cap = false}) {
  if (whole <= 0) return '--';
  var p = part * 100 / whole;
  if (cap) p = math.min(p, 100);
  return '${p.toStringAsFixed(1)}%';
}

final _inr = NumberFormat.decimalPattern('en_IN');
String _money(num v) => '₹${_inr.format(v.round())}';

List<MapEntry<String, int>> _sortedDesc(Map<String, int> m) =>
    m.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

/// Lists null = abhi load ho rahi hain (khaali maan ke chalte hain)
_Analytics _computeAll({
  required List<QueryDocumentSnapshot> students,
  required List<QueryDocumentSnapshot>? enquiries,
  required List<QueryDocumentSnapshot>? attendance,
  required List<QueryDocumentSnapshot>? placements,
  required _DateFilter filter,
}) {
  final a = _Analytics();

  // F2: wahi _compute, bas filtered students ke saath
  final studentsInRange =
      students.where((d) => filter.contains(_toDate(_data(d)?['admissionDate']))).toList();
  a.stats = _compute(studentsInRange, asOf: filter.lastDay);
  final stu = studentsInRange.map(_data).whereType<Map<String, dynamic>>().toList();

  final enq = (enquiries ?? const <QueryDocumentSnapshot>[])
      .map(_data)
      .whereType<Map<String, dynamic>>()
      .where((e) => filter.contains(_toDate(e['enquiryDate'])))
      .toList();
  final registeredEnquiries = enq.where((e) => _str(e['status']) == 'Registered').length;
  a.conversion = _pct(registeredEnquiries, enq.length);

  // Placements
  final placedIds = <String>{};
  final salaries = <int>[];
  final empTypes = <String, int>{};
  final companies = <String, int>{};
  for (final doc in placements ?? const <QueryDocumentSnapshot>[]) {
    final p = _data(doc);
    if (p == null || !filter.contains(_toDate(p['createdAt']))) continue;
    if (!_placedStatuses.contains(_str(p['status']))) continue;

    final tid = _str(p['traineeId']);
    placedIds.add(tid.isEmpty ? 'doc:${doc.id}' : tid);

    final salary = _parseSalary(p['salary']);
    if (salary != null) salaries.add(salary);

    final type = _str(p['employmentType']);
    final typeKey = type.isEmpty ? 'Unknown' : _titleCase(type);
    empTypes[typeKey] = (empTypes[typeKey] ?? 0) + 1;

    final company = _str(p['companyName']).toLowerCase();
    if (company.isNotEmpty) companies[company] = (companies[company] ?? 0) + 1;
  }
  a.placed = placedIds.length;
  a.placementPct = _pct(a.placed, a.stats.completed, cap: true);
  a.salaryCount = salaries.length;
  if (salaries.isNotEmpty) {
    salaries.sort();
    final n = salaries.length;
    a.avgSalary = salaries.reduce((x, y) => x + y) / n;
    a.medianSalary = n.isOdd ? salaries[n ~/ 2].toDouble() : (salaries[n ~/ 2 - 1] + salaries[n ~/ 2]) / 2;
  }
  a.employmentTypes = _sortedDesc(empTypes);
  a.topCompanies = _sortedDesc(companies).take(10).map((e) => MapEntry(_titleCase(e.key), e.value)).toList();

  // Funnel
  final counts = [
    enq.length,
    stu.length,
    stu.where((s) => _inTrainingOrDone.contains(_str(s['status']))).length,
    a.stats.completed,
    a.placed,
  ];
  const labels = ['Enquiry', 'Registered', 'Joined / Ongoing / Completed', 'Completed', 'Placed'];
  a.funnel = [
    for (var i = 0; i < counts.length; i++)
      _FunnelStep(
        labels[i],
        counts[i],
        // Placed ka % Placement % jaisa hi 100 pe cap
        i == 0 ? null : _pct(counts[i], counts[i - 1], cap: i == counts.length - 1),
      ),
  ];

  // Fees
  final feeByBatch = <String, List<double>>{};
  for (final s in stu) {
    final total = _num(s['totalFee']);
    final paid = math.max(0.0, _num(s['feePaid']));
    final pending = math.max(0.0, s['feePending'] != null ? _num(s['feePending']) : total - paid);
    final batch = _str(s['batch']).isEmpty ? 'No Batch' : _str(s['batch']);
    final sums = feeByBatch.putIfAbsent(batch, () => [0, 0]);
    sums[0] += paid;
    sums[1] += pending;
    a.feeCollected += paid;
    a.feePending += pending;
  }
  a.feeBatches = [for (final e in feeByBatch.entries) _BatchFee(e.key, e.value[0], e.value[1])]
    ..sort((x, y) => x.batch.compareTo(y.batch));

  // Attendance: statusMap me studentDocId -> present / absent / leave
  final batchPresent = <String, int>{};
  final batchMarked = <String, int>{};
  final stuPresent = <String, int>{};
  final stuMarked = <String, int>{};
  for (final doc in attendance ?? const <QueryDocumentSnapshot>[]) {
    final d = _data(doc);
    if (d == null || !filter.contains(_toDate(d['date']))) continue;
    final statusMap = d['statusMap'];
    if (statusMap is! Map) continue;
    var batch = _str(d['batchName']);
    if (batch.isEmpty) batch = _str(d['batchId']);
    if (batch.isEmpty) batch = 'Unknown';
    statusMap.forEach((studentId, value) {
      final status = _str(value);
      if (status != 'present' && status != 'absent' && status != 'leave') return;
      final id = studentId.toString();
      final present = status == 'present' ? 1 : 0;
      batchMarked[batch] = (batchMarked[batch] ?? 0) + 1;
      batchPresent[batch] = (batchPresent[batch] ?? 0) + present;
      stuMarked[id] = (stuMarked[id] ?? 0) + 1;
      stuPresent[id] = (stuPresent[id] ?? 0) + present;
    });
  }
  a.batchAttendance = [
    for (final e in batchMarked.entries) MapEntry(e.key, (batchPresent[e.key] ?? 0) * 100 / e.value),
  ]..sort((x, y) => x.key.compareTo(y.key));

  // Naam/batch saare students se (filter attendance date pe laga hai, admission pe nahi)
  final studentById = {for (final d in students) d.id: _data(d)};
  final absentees = <_Absentee>[];
  stuMarked.forEach((id, marked) {
    final s = studentById[id];
    if (s == null || marked < _minDaysForAbsentee) return;
    final name = _str(s['name']);
    absentees.add(_Absentee(
      name.isEmpty ? 'Unknown' : name,
      _str(s['batch']).isEmpty ? '-' : _str(s['batch']),
      (stuPresent[id] ?? 0) * 100 / marked,
      marked,
    ));
  });
  absentees.sort((x, y) {
    final byPct = x.pct.compareTo(y.pct);
    return byPct != 0 ? byPct : x.name.compareTo(y.name);
  });
  a.absentees = absentees.take(10).toList();

  return a;
}

/// Excel ki sheets, wahi numbers jo screen pe hain
List<ExportSheet> _exportSheets(_Analytics a, _DateFilter filter) {
  final s = a.stats;
  double round1(double v) => (v * 10).round() / 10;
  return [
    ExportSheet('Overview', [
      ['Metric', 'Value'],
      ['Date range', filter.description],
      ['Generated on', DateFormat('d MMM yyyy, HH:mm').format(DateTime.now())],
      ['Total Trainees', s.total],
      ['Active', s.active],
      ['Completed', s.completed],
      ['Dropped', s.dropped],
      ['Dropout %', _pct(s.dropped, s.total)],
      ['Enquiry → Registered', a.conversion],
      ['Fees Collected', a.feeCollected.round()],
      ['Fees Pending', a.feePending.round()],
      ['Collection %', _pct(a.feeCollected, a.feeCollected + a.feePending)],
      ['Placed', a.placed],
      ['Placement % (Placed / Completed)', a.placementPct],
      ['Average Salary', a.avgSalary?.round()],
      ['Median Salary', a.medianSalary?.round()],
    ]),
    ExportSheet('Funnel', [
      ['Step', 'Count', '% of previous step'],
      for (final f in a.funnel) [f.label, f.count, f.pctOfPrev ?? ''],
    ]),
    ExportSheet('Fees by Batch', [
      ['Batch', 'Collected', 'Pending', 'Total', 'Collection %'],
      for (final b in a.feeBatches)
        [b.batch, b.collected.round(), b.pending.round(), b.total.round(), _pct(b.collected, b.total)],
      [
        'Total',
        a.feeCollected.round(),
        a.feePending.round(),
        (a.feeCollected + a.feePending).round(),
        _pct(a.feeCollected, a.feeCollected + a.feePending),
      ],
    ]),
    ExportSheet('Attendance by Batch', [
      ['Batch', 'Present %'],
      for (final e in a.batchAttendance) [e.key, round1(e.value)],
    ]),
    ExportSheet('Chronic Absentees', [
      ['#', 'Name', 'Batch', 'Present %', 'Days marked'],
      for (var i = 0; i < a.absentees.length; i++)
        [i + 1, a.absentees[i].name, a.absentees[i].batch, round1(a.absentees[i].pct), a.absentees[i].days],
    ]),
    ExportSheet('Employment Type', [
      ['Type', 'Count'],
      for (final e in a.employmentTypes) [e.key, e.value],
    ]),
    ExportSheet('Top Companies', [
      ['Company', 'Placements'],
      for (final e in a.topCompanies) [e.key, e.value],
    ]),
  ];
}

// ---------------------------------------------------------------------------
// UI
// ---------------------------------------------------------------------------

class _AnalyticsBody extends StatefulWidget {
  const _AnalyticsBody();

  @override
  State<_AnalyticsBody> createState() => _AnalyticsBodyState();
}

class _AnalyticsBodyState extends State<_AnalyticsBody> {
  static const _collections = ['students', 'enquiries', 'attendance', 'placements'];

  /// Collection -> latest docs (key na ho = abhi load ho raha hai)
  final _docs = <String, List<QueryDocumentSnapshot>>{};
  final _errors = <String>{};
  final _subs = <StreamSubscription<QuerySnapshot>>[];

  _DateFilter _filter = _DateFilter.all;
  _Analytics? _analytics;
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    for (final c in _collections) {
      _subs.add(FirebaseFirestore.instance.collection(c).snapshots().listen(
        (snap) {
          _docs[c] = snap.docs;
          _errors.remove(c);
          _recompute();
        },
        onError: (Object _) {
          if (mounted) setState(() => _errors.add(c));
        },
      ));
    }
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    super.dispose();
  }

  void _recompute() {
    if (!mounted) return;
    final students = _docs['students'];
    setState(() {
      _analytics = students == null
          ? null
          : _computeAll(
              students: students,
              enquiries: _docs['enquiries'],
              attendance: _docs['attendance'],
              placements: _docs['placements'],
              filter: _filter,
            );
    });
  }

  Future<void> _selectPreset(_RangePreset preset) async {
    _DateFilter next;
    switch (preset) {
      case _RangePreset.all:
        next = _DateFilter.all;
      case _RangePreset.last30:
        next = _DateFilter.lastDays(preset, 30);
      case _RangePreset.last90:
        next = _DateFilter.lastDays(preset, 90);
      case _RangePreset.custom:
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final current = _filter.isAll ? null : DateTimeRange(start: _filter.start!, end: _filter.lastDay!);
        final picked = await showDateRangePicker(
          context: context,
          firstDate: DateTime(2015),
          lastDate: today,
          initialDateRange: current != null && !current.end.isAfter(today) ? current : null,
          builder: (context, child) => Theme(
            data: Theme.of(context).copyWith(
              colorScheme: const ColorScheme.light(primary: AppColors.primary, secondary: AppColors.accent),
            ),
            child: child!,
          ),
        );
        if (picked == null) return;
        next = _DateFilter.custom(picked);
    }
    _filter = next;
    _recompute();
  }

  bool _ready(String c) => _docs.containsKey(c);

  Future<void> _export() async {
    final a = _analytics;
    if (a == null) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _exporting = true);
    try {
      final stamp = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
      await saveSheetsAsXlsx('vti_analytics_$stamp', _exportSheets(a, _filter));
      messenger.showSnackBar(const SnackBar(
        content: Text('Excel Downloads me save ho gaya'),
        backgroundColor: AppColors.success,
      ));
    } catch (e) {
      messenger.showSnackBar(SnackBar(
        content: Text('Export nahi ho paya: $e'),
        backgroundColor: AppColors.danger,
      ));
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  /// [needs] ke collections load na hue hon to loader/error card, warna [build]
  List<Widget> _gated(String title, List<String> needs, List<Widget> Function() build) {
    if (needs.any(_errors.contains)) {
      return [
        _ChartCard(
          title: title,
          hasData: true,
          height: 100,
          child: const Center(
            child: Text('Data load nahi ho paya', style: TextStyle(color: AppColors.textMuted)),
          ),
        ),
      ];
    }
    if (!needs.every(_ready)) {
      return [
        _ChartCard(
          title: title,
          hasData: true,
          height: 100,
          child: const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        ),
      ];
    }
    return build();
  }

  @override
  Widget build(BuildContext context) {
    if (_errors.contains('students')) {
      return const Center(
        child: Text('Data load nahi ho paya', style: TextStyle(color: AppColors.textMuted)),
      );
    }
    final a = _analytics;
    if (a == null) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }
    final stats = a.stats;
    final allReady = _collections.every(_ready);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _FilterBar(
              filter: _filter,
              onSelect: _selectPreset,
              exporting: _exporting,
              onExport: allReady && !_exporting ? _export : null,
            ),
            const SizedBox(height: 16),
            _KpiGrid(stats: stats, conversion: _ready('enquiries') ? a.conversion : '--'),
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

            const _SectionTitle('Funnel'),
            ..._gated('Enquiry → Placement Funnel', ['enquiries', 'placements'], () => [
                  _ChartCard(
                    title: 'Enquiry → Placement Funnel',
                    hasData: a.funnel.any((f) => f.count > 0),
                    height: null,
                    child: _FunnelBars(steps: a.funnel),
                  ),
                ]),

            const _SectionTitle('Fees'),
            _KpiWrap(cards: [
              _KpiCard(
                icon: Icons.account_balance_wallet_outlined,
                label: 'Total Collected',
                value: _money(a.feeCollected),
                color: AppColors.primary,
              ),
              _KpiCard(
                icon: Icons.hourglass_bottom,
                label: 'Total Pending',
                value: _money(a.feePending),
                color: AppColors.accent,
              ),
              _KpiCard(
                icon: Icons.percent,
                label: 'Collection %',
                value: _pct(a.feeCollected, a.feeCollected + a.feePending),
                color: _shade(0.35),
              ),
            ]),
            const SizedBox(height: 16),
            _ChartCard(
              title: 'Batch-wise Collected vs Pending',
              hasData: a.feeBatches.any((b) => b.total > 0),
              height: null,
              child: _FeeStackedBars(batches: a.feeBatches),
            ),

            const _SectionTitle('Attendance'),
            ..._gated('Attendance', ['attendance'], () => [
                  _ChartCard(
                    title: 'Batch-wise Average Present %',
                    hasData: a.batchAttendance.isNotEmpty,
                    height: null,
                    child: _AttendanceBars(entries: a.batchAttendance),
                  ),
                  _ChartCard(
                    title: 'Chronic Absentees (sabse kam present %)',
                    hasData: a.absentees.isNotEmpty,
                    height: null,
                    child: _AbsenteeList(absentees: a.absentees),
                  ),
                ]),

            const _SectionTitle('Placement'),
            ..._gated('Placement', ['placements'], () => [
                  _KpiWrap(cards: [
                    _KpiCard(
                      icon: Icons.work_outline,
                      label: 'Placement %',
                      value: a.placementPct,
                      subtitle: '${a.placed} placed / ${stats.completed} completed',
                      color: AppColors.primary,
                    ),
                    _KpiCard(
                      icon: Icons.payments_outlined,
                      label: 'Average Salary',
                      value: a.avgSalary == null ? '--' : _money(a.avgSalary!),
                      subtitle: '${a.salaryCount} salaries',
                      color: _shade(0.35),
                    ),
                    _KpiCard(
                      icon: Icons.stacked_line_chart,
                      label: 'Median Salary',
                      value: a.medianSalary == null ? '--' : _money(a.medianSalary!),
                      color: AppColors.accent,
                    ),
                  ]),
                  const SizedBox(height: 16),
                  _ChartCard(
                    title: 'Employment Type',
                    hasData: a.employmentTypes.isNotEmpty,
                    child: _CountDonut(entries: a.employmentTypes, centerLabel: 'Placed'),
                  ),
                  _ChartCard(
                    title: 'Top 10 Companies',
                    hasData: a.topCompanies.isNotEmpty,
                    height: null,
                    child: _VillageBars(entries: a.topCompanies),
                  ),
                ]),
          ],
        ),
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  final _DateFilter filter;
  final ValueChanged<_RangePreset> onSelect;
  final bool exporting;
  final VoidCallback? onExport;
  const _FilterBar({
    required this.filter,
    required this.onSelect,
    required this.exporting,
    required this.onExport,
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
            Row(
              children: [
                const Icon(Icons.date_range, color: AppColors.primary),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Date Range',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textDark),
                  ),
                ),
                FilledButton.icon(
                  onPressed: onExport,
                  style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
                  icon: exporting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                        )
                      : const Icon(Icons.download, size: 18),
                  label: const Text('Export Excel'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final p in _RangePreset.values)
                  ChoiceChip(
                    label: Text(_presetLabels[p]!),
                    selected: filter.preset == p,
                    showCheckmark: false,
                    selectedColor: AppColors.primary,
                    labelStyle: TextStyle(color: filter.preset == p ? Colors.white : AppColors.textDark),
                    onSelected: (_) => onSelect(p),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(filter.description, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 12),
      child: Text(
        text,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary),
      ),
    );
  }
}

/// _KpiGrid jaisa hi layout, kisi bhi cards ke liye
class _KpiWrap extends StatelessWidget {
  final List<Widget> cards;
  const _KpiWrap({required this.cards});

  @override
  Widget build(BuildContext context) {
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

// ---------------------------------------------------------------------------
// F3 widgets
// ---------------------------------------------------------------------------

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, color: AppColors.textDark),
          ),
        ),
      ],
    );
  }
}

/// Har step ka bar sabse bade step ke hisaab se
class _FunnelBars extends StatelessWidget {
  final List<_FunnelStep> steps;
  const _FunnelBars({required this.steps});

  @override
  Widget build(BuildContext context) {
    final maxCount = steps.map((s) => s.count).fold(0, math.max);
    return Column(
      children: [
        for (var i = 0; i < steps.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        steps[i].label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13, color: AppColors.textDark),
                      ),
                    ),
                    Text(
                      '${steps[i].count}',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textDark),
                    ),
                    if (steps[i].pctOfPrev != null)
                      SizedBox(
                        width: 120,
                        child: Text(
                          '${steps[i].pctOfPrev} pichhle se',
                          textAlign: TextAlign.right,
                          style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                LayoutBuilder(
                  builder: (context, constraints) => Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      height: 22,
                      width: maxCount == 0 || steps[i].count == 0
                          ? 0
                          : math.max(4, constraints.maxWidth * steps[i].count / maxCount),
                      decoration: BoxDecoration(
                        color: _seriesColor(i, steps.length),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Har batch ka ek bar: hara hissa Collected, gold hissa Pending
class _FeeStackedBars extends StatelessWidget {
  final List<_BatchFee> batches;
  const _FeeStackedBars({required this.batches});

  @override
  Widget build(BuildContext context) {
    final maxTotal = batches.map((b) => b.total).fold(0.0, math.max);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Wrap(
          spacing: 16,
          children: [
            _LegendDot(color: AppColors.primary, label: 'Collected'),
            _LegendDot(color: AppColors.accent, label: 'Pending'),
          ],
        ),
        const SizedBox(height: 8),
        for (final b in batches)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        b.batch,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textDark),
                      ),
                    ),
                    Text(
                      '${_money(b.collected)} / ${_money(b.pending)}',
                      style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                LayoutBuilder(
                  builder: (context, constraints) {
                    if (maxTotal <= 0 || b.total <= 0) return const SizedBox(height: 18);
                    final width = math.max(4.0, constraints.maxWidth * b.total / maxTotal);
                    return Align(
                      alignment: Alignment.centerLeft,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(height: 18, width: width * b.collected / b.total, color: AppColors.primary),
                            Container(height: 18, width: width * b.pending / b.total, color: AppColors.accent),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// 0-100 scale; 75% se neeche gold bar aur laal text
class _AttendanceBars extends StatelessWidget {
  final List<MapEntry<String, double>> entries;
  const _AttendanceBars({required this.entries});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final e in entries)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(
              children: [
                SizedBox(
                  width: 110,
                  child: Text(
                    e.key,
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
                        width: math.max(4, constraints.maxWidth * e.value.clamp(0, 100) / 100),
                        decoration: BoxDecoration(
                          color: e.value < _attendanceThreshold ? AppColors.accent : AppColors.primary,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 52,
                  child: Text(
                    '${e.value.toStringAsFixed(1)}%',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: e.value < _attendanceThreshold ? AppColors.danger : AppColors.textDark,
                    ),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 6),
        Text(
          '${_attendanceThreshold.toInt()}% se neeche wale batch gold me',
          style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
        ),
      ],
    );
  }
}

class _AbsenteeList extends StatelessWidget {
  final List<_Absentee> absentees;
  const _AbsenteeList({required this.absentees});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < absentees.length; i++) ...[
          if (i > 0) Divider(height: 1, color: AppColors.textMuted.withValues(alpha: 0.15)),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                SizedBox(
                  width: 28,
                  child: Text('${i + 1}.', style: const TextStyle(fontSize: 13, color: AppColors.textMuted)),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        absentees[i].name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textDark),
                      ),
                      Text(
                        '${absentees[i].batch} · ${absentees[i].days} din mark',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${absentees[i].pct.toStringAsFixed(1)}%',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: absentees[i].pct < _attendanceThreshold ? AppColors.danger : AppColors.textDark,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// Generic donut + legend (employment type ke liye)
class _CountDonut extends StatelessWidget {
  final List<MapEntry<String, int>> entries;
  final String centerLabel;
  const _CountDonut({required this.entries, required this.centerLabel});

  @override
  Widget build(BuildContext context) {
    final total = entries.fold(0, (acc, e) => acc + e.value);
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
                    for (var i = 0; i < entries.length; i++)
                      PieChartSectionData(
                        value: entries[i].value.toDouble(),
                        color: _seriesColor(i, entries.length),
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
                    '$total',
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textDark),
                  ),
                  Text(centerLabel, style: _axisStyle),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < entries.length; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: _LegendDot(
                    color: _seriesColor(i, entries.length),
                    label: '${entries[i].key}  ${entries[i].value} (${_pct(entries[i].value, total)})',
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
