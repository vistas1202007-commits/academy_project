/// All the at-risk scoring math. No Flutter or Firestore here, only
/// plain data, so [scoreTrainee] can later be swapped for an ML model
/// while the other screens keep working unchanged.
library;

/// How many days of past attendance to look at
const int kRiskWindowDays = 28;

enum RiskLevel { high, medium, low }

extension RiskLevelLabel on RiskLevel {
  String get label => switch (this) {
        RiskLevel.high => 'High',
        RiskLevel.medium => 'Medium',
        RiskLevel.low => 'Low',
      };
}

/// One day's attendance: each student's (doc id) status
class AttendanceDay {
  final DateTime date;
  final Map<String, String> statusMap;
  final String batchName;
  const AttendanceDay(this.date, this.statusMap, {this.batchName = ''});
}

bool isPresent(String status) => status.toLowerCase() == 'present';

/// A trainee's record count and present count within the window
class AttendanceTally {
  int records = 0;
  int present = 0;

  /// 0-100; null if there are no records
  double? get percent => records == 0 ? null : present * 100 / records;
}

class RiskInput {
  final String status;
  final double totalFee;
  final double feePending;
  final AttendanceTally attendance;
  const RiskInput({
    required this.status,
    required this.totalFee,
    required this.feePending,
    required this.attendance,
  });
}

class RiskResult {
  final int score;
  final RiskLevel level;

  /// Reasons, e.g. "Attendance 54%", "Fees 70% pending"
  final List<String> reasons;
  const RiskResult(this.score, this.level, this.reasons);
}

/// Scoring rules:
/// attendance <60% = +60, else <75% = +40; fees pending >50% = +25;
/// fewer than 5 records in the window = +10; status Joined = +5.
RiskResult scoreTrainee(RiskInput input) {
  var score = 0;
  final reasons = <String>[];

  final pct = input.attendance.percent;
  if (pct != null) {
    if (pct < 60) {
      score += 60;
    } else if (pct < 75) {
      score += 40;
    }
    if (pct < 75) reasons.add('Attendance ${pct.round()}%');
  }

  if (input.totalFee > 0) {
    final pendingPct = input.feePending * 100 / input.totalFee;
    if (pendingPct > 50) {
      score += 25;
      reasons.add('Fees ${pendingPct.round()}% pending');
    }
  }

  final records = input.attendance.records;
  if (records < 5) {
    score += 10;
    reasons.add(records == 0 ? 'No attendance in $kRiskWindowDays days' : 'Only $records attendance records');
  }

  if (input.status == 'Joined') {
    score += 5;
    reasons.add('Status Joined');
  }

  return RiskResult(score, levelFor(score), reasons);
}

RiskLevel levelFor(int score) {
  if (score >= 60) return RiskLevel.high;
  if (score >= 30) return RiskLevel.medium;
  return RiskLevel.low;
}

/// Risk is computed only for trainees with these statuses
bool isActiveTrainee(String status) => status == 'Joined' || status == 'Ongoing';

/// Records from the last [kRiskWindowDays] days before [now], keyed by student doc id
Map<String, AttendanceTally> tallyAttendance(Iterable<AttendanceDay> days, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  final from = today.subtract(const Duration(days: kRiskWindowDays - 1));
  final to = today.add(const Duration(days: 1));
  final tallies = <String, AttendanceTally>{};
  for (final day in days) {
    if (day.date.isBefore(from) || !day.date.isBefore(to)) continue;
    day.statusMap.forEach((studentId, status) {
      final t = tallies.putIfAbsent(studentId, AttendanceTally.new);
      t.records++;
      if (isPresent(status)) t.present++;
    });
  }
  return tallies;
}

/// One trainee's risk, for display in the list
class TraineeRisk {
  final String id;
  final String name;
  final String batch;
  final RiskResult result;
  const TraineeRisk(this.id, this.name, this.batch, this.result);
}

/// List of Joined/Ongoing trainees from students (each map has 'id' = doc id)
/// and attendance, highest score first
List<TraineeRisk> assessTrainees(
  Iterable<Map<String, dynamic>> students,
  Iterable<AttendanceDay> days,
  DateTime now,
) {
  final tallies = tallyAttendance(days, now);
  final list = <TraineeRisk>[];
  for (final s in students) {
    final status = (s['status'] ?? '').toString().trim();
    if (!isActiveTrainee(status)) continue;
    final id = (s['id'] ?? '').toString();
    final total = toAmount(s['totalFee']);
    final paid = toAmount(s['feePaid']);
    final pending = s['feePending'] == null ? total - paid : toAmount(s['feePending']);
    final result = scoreTrainee(RiskInput(
      status: status,
      totalFee: total,
      feePending: pending < 0 ? 0 : pending,
      attendance: tallies[id] ?? AttendanceTally(),
    ));
    final name = (s['name'] ?? '').toString().trim();
    list.add(TraineeRisk(id, name.isEmpty ? 'Unnamed' : name, (s['batch'] ?? '').toString().trim(), result));
  }
  list.sort((a, b) {
    final byScore = b.result.score.compareTo(a.result.score);
    return byScore != 0 ? byScore : a.name.toLowerCase().compareTo(b.name.toLowerCase());
  });
  return list;
}

/// Turns a number or text like "12,000" into a number; 0 if it can't
double toAmount(dynamic v) {
  if (v is num) return v.toDouble();
  return double.tryParse((v ?? '').toString().replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0;
}
