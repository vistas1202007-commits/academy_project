import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'admin_gate.dart';
import 'app_colors.dart';
import 'at_risk_logic.dart';
import 'at_risk_screen.dart';
import 'responsive.dart';
import 'soft_delete.dart';
import 'ui_kit.dart';

// ---------------------------------------------------------------------------
// Data and answers (pure functions, no AI; all counted client-side)
// ---------------------------------------------------------------------------

/// All data, loaded once
class AskDataSet {
  final List<Map<String, dynamic>> students;
  final List<AttendanceDay> attendance;
  final List<Map<String, dynamic>> placements;
  final List<Map<String, dynamic>> enquiries;
  final DateTime loadedAt;
  const AskDataSet({
    required this.students,
    required this.attendance,
    required this.placements,
    required this.enquiries,
    required this.loadedAt,
  });

  bool get isEmpty => students.isEmpty && attendance.isEmpty && placements.isEmpty && enquiries.isEmpty;
}

/// Answer shown in the card: one-line summary + small table
class Answer {
  final String summary;
  final List<String> columns;
  final List<List<String>> rows;
  const Answer(this.summary, [this.columns = const [], this.rows = const []]);
}

class Question {
  final String label;
  final IconData icon;
  final Answer Function(AskDataSet data) answer;
  const Question(this.label, this.icon, this.answer);
}

final List<Question> kQuestions = [
  const Question('How many trainees are at risk?', Icons.warning_amber_outlined, answerAtRisk),
  const Question('Which batch has the highest dropout %?', Icons.trending_down, answerBatchDropout),
  const Question('Which batch has the lowest attendance?', Icons.event_busy_outlined, answerBatchAttendance),
  const Question('Total fees collected vs pending?', Icons.currency_rupee, answerFees),
  const Question('Course-wise placement %?', Icons.work_outline, answerCoursePlacement),
  const Question('Course-wise average salary?', Icons.payments_outlined, answerCourseSalary),
  const Question('Which village has the most dropouts?', Icons.location_on_outlined, answerVillageDropout),
  const Question('Enquiry to registration conversion %?', Icons.swap_horiz, answerConversion),
  const Question('Top 5 hiring companies?', Icons.business_outlined, answerTopCompanies),
  const Question('How many trainees have no attendance record?', Icons.person_off_outlined, answerNoAttendance),
];

/// Villages with fewer trainees than this are skipped in village dropout (so 1/1 doesn't show 100%)
const int kMinVillageTrainees = 3;

/// "Salary" below this (e.g. the 1 from "1.5 LPA") is treated as a bad parse and skipped
const int kMinMonthlySalary = 1000;

String _s(dynamic v) => (v ?? '').toString().trim();

String _pct(num part, num whole) => whole == 0 ? '0%' : '${(part * 100 / whole).round()}%';

final NumberFormat _inr = NumberFormat('#,##,##0', 'en_IN');
String _money(num v) => '₹${_inr.format(v.round())}';

String _titleCase(String s) => s
    .split(RegExp(r'\s+'))
    .where((w) => w.isNotEmpty)
    .map((w) => w[0].toUpperCase() + w.substring(1).toLowerCase())
    .join(' ');

/// First number in the salary text ("12,000/month" -> 12000); null if none
int? parseSalary(dynamic v) {
  if (v is num) return v.round();
  final match = RegExp(r'\d[\d,]*').firstMatch(_s(v));
  if (match == null) return null;
  return int.tryParse(match.group(0)!.replaceAll(',', ''));
}

/// Total and matching counts within a group
class _Ratio {
  int part = 0;
  int total = 0;
  double get value => total == 0 ? 0 : part / total;
}

Answer answerAtRisk(AskDataSet d) {
  final list = assessTrainees(d.students, d.attendance, DateTime.now());
  if (list.isEmpty) return const Answer('No active (Joined/Ongoing) trainees yet.');
  final counts = {for (final l in RiskLevel.values) l: 0};
  for (final t in list) {
    counts[t.result.level] = counts[t.result.level]! + 1;
  }
  final atRisk = counts[RiskLevel.high]! + counts[RiskLevel.medium]!;
  return Answer(
    '$atRisk of ${list.length} active trainees are at risk '
    '(High ${counts[RiskLevel.high]}, Medium ${counts[RiskLevel.medium]}).',
    ['Level', 'Trainees'],
    [for (final l in RiskLevel.values) [l.label, '${counts[l]}']],
  );
}

Map<String, _Ratio> _dropoutBy(List<Map<String, dynamic>> students, String Function(Map<String, dynamic>) key) {
  final map = <String, _Ratio>{};
  for (final s in students) {
    final k = key(s);
    if (k.isEmpty) continue;
    final r = map.putIfAbsent(k, _Ratio.new);
    r.total++;
    if (_s(s['status']) == 'Dropped') r.part++;
  }
  return map;
}

List<MapEntry<String, _Ratio>> _sortedDesc(Map<String, _Ratio> map) => map.entries.toList()
  ..sort((a, b) {
    final c = b.value.value.compareTo(a.value.value);
    return c != 0 ? c : b.value.total.compareTo(a.value.total);
  });

Answer answerBatchDropout(AskDataSet d) {
  final sorted = _sortedDesc(_dropoutBy(d.students, (s) => _s(s['batch'])));
  if (sorted.isEmpty) return const Answer('No trainee has a batch set.');
  final top = sorted.first;
  if (top.value.part == 0) return const Answer('No dropouts in any batch yet.');
  return Answer(
    '${top.key} has the highest dropout: ${_pct(top.value.part, top.value.total)} '
    '(${top.value.part}/${top.value.total}).',
    ['Batch', 'Dropped', 'Total', 'Dropout %'],
    [
      for (final e in sorted.take(5))
        [e.key, '${e.value.part}', '${e.value.total}', _pct(e.value.part, e.value.total)],
    ],
  );
}

Answer answerBatchAttendance(AskDataSet d) {
  final map = <String, _Ratio>{};
  for (final day in d.attendance) {
    if (day.batchName.isEmpty) continue;
    final r = map.putIfAbsent(day.batchName, _Ratio.new);
    day.statusMap.forEach((_, status) {
      r.total++;
      if (isPresent(status)) r.part++;
    });
  }
  map.removeWhere((_, r) => r.total == 0);
  if (map.isEmpty) return const Answer('No attendance has been marked yet.');
  final sorted = map.entries.toList()..sort((a, b) => a.value.value.compareTo(b.value.value));
  final low = sorted.first;
  return Answer(
    '${low.key} has the lowest attendance: ${_pct(low.value.part, low.value.total)} present (all records).',
    ['Batch', 'Present', 'Records', 'Present %'],
    [
      for (final e in sorted.take(5))
        [e.key, '${e.value.part}', '${e.value.total}', _pct(e.value.part, e.value.total)],
    ],
  );
}

Answer answerFees(AskDataSet d) {
  double total = 0, paid = 0, pending = 0;
  var pendingCount = 0;
  for (final s in d.students) {
    final t = toAmount(s['totalFee']);
    final p = toAmount(s['feePaid']);
    var due = s['feePending'] == null ? t - p : toAmount(s['feePending']);
    if (due < 0) due = 0;
    total += t;
    paid += p;
    pending += due;
    if (due > 0) pendingCount++;
  }
  if (total == 0 && paid == 0) return const Answer('No fee entries yet.');
  return Answer(
    '${_money(paid)} collected, ${_money(pending)} pending ($pendingCount trainees with dues).',
    ['', 'Amount'],
    [
      ['Total Fee', _money(total)],
      ['Collected', '${_money(paid)}  (${_pct(paid, total)})'],
      ['Pending', '${_money(pending)}  (${_pct(pending, total)})'],
    ],
  );
}

Answer answerCoursePlacement(AskDataSet d) {
  final traineesByCourse = <String, int>{};
  final courseOfTrainee = <String, String>{};
  for (final s in d.students) {
    final course = _s(s['course']);
    if (course.isEmpty) continue;
    traineesByCourse[course] = (traineesByCourse[course] ?? 0) + 1;
    final tid = _s(s['traineeId']);
    if (tid.isNotEmpty) courseOfTrainee[tid] = course;
  }
  if (traineesByCourse.isEmpty) return const Answer('No trainee has a course set.');

  // Two placements of the same trainee count as one
  final placed = <String, Set<String>>{};
  for (final p in d.placements) {
    final tid = _s(p['traineeId']);
    final key = tid.isNotEmpty ? tid : _s(p['studentName']).toLowerCase();
    if (key.isEmpty) continue;
    final course = _s(p['course']).isNotEmpty ? _s(p['course']) : (courseOfTrainee[tid] ?? '');
    if (!traineesByCourse.containsKey(course)) continue;
    placed.putIfAbsent(course, () => {}).add(key);
  }

  final rows = traineesByCourse.entries.map((e) {
    final n = placed[e.key]?.length ?? 0;
    return (course: e.key, trainees: e.value, placed: n > e.value ? e.value : n);
  }).toList()
    ..sort((a, b) => (b.placed / b.trainees).compareTo(a.placed / a.trainees));

  final totalPlaced = rows.fold<int>(0, (s, r) => s + r.placed);
  final totalTrainees = rows.fold<int>(0, (s, r) => s + r.trainees);
  return Answer(
    'Overall placement ${_pct(totalPlaced, totalTrainees)} ($totalPlaced/$totalTrainees); '
    'highest is ${rows.first.course} (${_pct(rows.first.placed, rows.first.trainees)}).',
    ['Course', 'Trainees', 'Placed', 'Placement %'],
    [for (final r in rows) [r.course, '${r.trainees}', '${r.placed}', _pct(r.placed, r.trainees)]],
  );
}

Answer answerCourseSalary(AskDataSet d) {
  final sums = <String, List<int>>{};
  var skipped = 0;
  for (final p in d.placements) {
    final salary = parseSalary(p['salary']);
    if (salary == null || salary < kMinMonthlySalary) {
      skipped++;
      continue;
    }
    final course = _s(p['course']).isEmpty ? 'Unknown' : _s(p['course']);
    sums.putIfAbsent(course, () => []).add(salary);
  }
  if (sums.isEmpty) return const Answer('No placement has a numeric salary.');
  final rows = sums.entries
      .map((e) => (course: e.key, count: e.value.length, avg: e.value.reduce((a, b) => a + b) / e.value.length))
      .toList()
    ..sort((a, b) => b.avg.compareTo(a.avg));
  final top = rows.first;
  return Answer(
    '${top.course} has the highest average salary: ${_money(top.avg)}'
    '${skipped > 0 ? ' ($skipped placements skipped, no clear salary)' : ''}.',
    ['Course', 'Placements', 'Avg Salary'],
    [for (final r in rows) [r.course, '${r.count}', _money(r.avg)]],
  );
}

Answer answerVillageDropout(AskDataSet d) {
  final map = _dropoutBy(d.students, (s) => _s(s['village']).toLowerCase())
    ..removeWhere((_, r) => r.total < kMinVillageTrainees);
  final sorted = _sortedDesc(map);
  if (sorted.isEmpty) {
    return const Answer('No village has $kMinVillageTrainees or more trainees.');
  }
  final top = sorted.first;
  if (top.value.part == 0) return const Answer('No dropouts from any village yet.');
  return Answer(
    '${_titleCase(top.key)} has the most dropouts: ${_pct(top.value.part, top.value.total)} '
    '(${top.value.part}/${top.value.total}). Only villages with $kMinVillageTrainees+ trainees.',
    ['Village', 'Dropped', 'Total', 'Dropout %'],
    [
      for (final e in sorted.take(5))
        [_titleCase(e.key), '${e.value.part}', '${e.value.total}', _pct(e.value.part, e.value.total)],
    ],
  );
}

Answer answerConversion(AskDataSet d) {
  if (d.enquiries.isEmpty) return const Answer('No enquiries yet.');
  final converted = d.enquiries
      .where((e) => _s(e['convertedTraineeId']).isNotEmpty || _s(e['followUpStatus']) == 'Registered')
      .length;
  return Answer(
    '$converted of ${d.enquiries.length} enquiries registered: ${_pct(converted, d.enquiries.length)} conversion.',
    ['', 'Count'],
    [
      ['Enquiries', '${d.enquiries.length}'],
      ['Registered', '$converted'],
      ['Not yet', '${d.enquiries.length - converted}'],
    ],
  );
}

Answer answerTopCompanies(AskDataSet d) {
  final counts = <String, int>{};
  final names = <String, String>{};
  for (final p in d.placements) {
    final name = _s(p['companyName']);
    if (name.isEmpty) continue;
    final key = name.toLowerCase();
    names.putIfAbsent(key, () => name);
    counts[key] = (counts[key] ?? 0) + 1;
  }
  if (counts.isEmpty) return const Answer('No placements yet.');
  final sorted = counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
  final top = sorted.first;
  return Answer(
    '${names[top.key]} hired the most trainees (${top.value}).',
    ['#', 'Company', 'Hires'],
    [
      for (var i = 0; i < sorted.length && i < 5; i++)
        ['${i + 1}', names[sorted[i].key]!, '${sorted[i].value}'],
    ],
  );
}

Answer answerNoAttendance(AskDataSet d) {
  final seen = <String>{};
  for (final day in d.attendance) {
    seen.addAll(day.statusMap.keys);
  }
  final active = d.students.where((s) => isActiveTrainee(_s(s['status']))).toList();
  if (active.isEmpty) return const Answer('No active (Joined/Ongoing) trainees yet.');
  final missing = active.where((s) => !seen.contains(_s(s['id']))).toList()
    ..sort((a, b) => _s(a['name']).toLowerCase().compareTo(_s(b['name']).toLowerCase()));
  if (missing.isEmpty) return Answer('All ${active.length} active trainees have an attendance record.');
  const shown = 10;
  return Answer(
    '${missing.length} of ${active.length} active trainees have no attendance record'
    '${missing.length > shown ? ' (showing first $shown)' : ''}.',
    ['Name', 'Batch'],
    [
      for (final s in missing.take(shown))
        [_s(s['name']).isEmpty ? 'Unnamed' : _s(s['name']), _s(s['batch']).isEmpty ? '-' : _s(s['batch'])],
    ],
  );
}

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

/// Admin-only: 10 fixed questions; tap a chip to get the answer from the data
class AskDataScreen extends StatelessWidget {
  const AskDataScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.appBackground,
      appBar: AppBar(
        flexibleSpace: const AppBarRibbon(),
        title: const Text('Ask Your Data'),
        backgroundColor: AppColors.appPrimary,
        foregroundColor: Colors.white,
      ),
      body: PageWash(child: const ContentWidth(
        maxWidth: 900,
        child: AdminGate(screenName: 'Ask Your Data', child: _AskBody()),
      )),
    );
  }
}

class _AskBody extends StatefulWidget {
  const _AskBody();

  @override
  State<_AskBody> createState() => _AskBodyState();
}

class _AskBodyState extends State<_AskBody> {
  late Future<AskDataSet> _future = _load();
  int? _selected;

  Future<AskDataSet> _load() async {
    final db = FirebaseFirestore.instance;
    final results = await Future.wait([
      db.collection('students').get(),
      db.collection('attendance').get(),
      db.collection('placements').get(),
      db.collection('enquiries').get(),
    ]);
    // Records in the Recycle Bin are not counted in any answer
    final students = liveStudentMapsFrom(results[0]);
    final binnedIds = deletedTraineeIds(results[0].docs.map((d) => d.data()));
    return AskDataSet(
      students: students,
      attendance: liveAttendance(attendanceDaysFrom(results[1]), idsOf(students)),
      placements: results[2].docs.map((d) => d.data()).where((p) => isCountablePlacement(p, binnedIds)).toList(),
      enquiries: results[3].docs.map((d) => d.data()).where(isLive).toList(),
      loadedAt: DateTime.now(),
    );
  }

  void _refresh() => setState(() => _future = _load());

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AskDataSet>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const AppLoader();
        }
        if (snap.hasError) {
          return _CenterMessage(
            icon: Icons.cloud_off_outlined,
            text: 'Could not load data. Check your internet connection and try again.',
            onRefresh: _refresh,
          );
        }
        final data = snap.data!;
        if (data.isEmpty) {
          return _CenterMessage(
            icon: Icons.inbox_outlined,
            text: 'No data yet. Answers will appear once trainees, attendance or placements are added.',
            onRefresh: _refresh,
          );
        }
        final selected = _selected;
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${data.students.length} trainees, ${data.placements.length} placements, '
                    '${data.enquiries.length} enquiries  ·  ${DateFormat('hh:mm a').format(data.loadedAt)}',
                    style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                  ),
                ),
                TextButton.icon(
                  onPressed: _refresh,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Refresh'),
                  style: TextButton.styleFrom(foregroundColor: AppColors.appPrimary),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var i = 0; i < kQuestions.length; i++)
                  ChoiceChip(
                    selected: _selected == i,
                    onSelected: (_) => setState(() => _selected = i),
                    avatar: Icon(
                      kQuestions[i].icon,
                      size: 16,
                      color: _selected == i ? Colors.white : AppColors.appPrimary,
                    ),
                    label: Text(kQuestions[i].label),
                    showCheckmark: false,
                    labelStyle: TextStyle(
                      fontSize: 13,
                      color: _selected == i ? Colors.white : AppColors.textDark,
                    ),
                    selectedColor: AppColors.appPrimary,
                    backgroundColor: AppColors.surface,
                    side: BorderSide(color: _selected == i ? AppColors.appPrimary : AppColors.border),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            if (selected == null)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  'Select a question above.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textMuted),
                ),
              )
            else
              _AnswerCard(question: kQuestions[selected], answer: kQuestions[selected].answer(data)),
          ],
        );
      },
    );
  }
}

class _AnswerCard extends StatelessWidget {
  final Question question;
  final Answer answer;
  const _AnswerCard({required this.question, required this.answer});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppCard.decoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(question.icon, size: 18, color: AppColors.appAccent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  question.label,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textMuted),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            answer.summary,
            style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600, color: AppColors.textDark),
          ),
          if (answer.rows.isNotEmpty) ...[
            const SizedBox(height: 14),
            _AnswerTable(columns: answer.columns, rows: answer.rows),
          ],
        ],
      ),
    );
  }
}

class _AnswerTable extends StatelessWidget {
  final List<String> columns;
  final List<List<String>> rows;
  const _AnswerTable({required this.columns, required this.rows});

  @override
  Widget build(BuildContext context) {
    TableRow row(List<String> cells, {bool header = false}) => TableRow(
          decoration: header ? const BoxDecoration(color: AppColors.appBackground) : null,
          children: [
            for (var i = 0; i < cells.length; i++)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                child: Text(
                  cells[i],
                  textAlign: i == 0 ? TextAlign.left : TextAlign.right,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: header ? FontWeight.w600 : FontWeight.w400,
                    color: header ? AppColors.appPrimary : AppColors.textDark,
                  ),
                ),
              ),
          ],
        );

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Table(
        border: const TableBorder(horizontalInside: BorderSide(color: AppColors.border)),
        columnWidths: const {0: FlexColumnWidth(2)},
        defaultColumnWidth: const FlexColumnWidth(1),
        children: [
          row(columns, header: true),
          for (final r in rows) row(r),
        ],
      ),
    );
  }
}

class _CenterMessage extends StatelessWidget {
  final IconData icon;
  final String text;
  final VoidCallback onRefresh;
  const _CenterMessage({required this.icon, required this.text, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return EmptyState(icon: icon, message: text, actionLabel: 'Refresh', onAction: onRefresh);
  }
}
