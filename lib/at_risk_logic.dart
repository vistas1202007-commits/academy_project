/// At-risk scoring ka saara hisaab. Isme Flutter ya Firestore kuch nahi,
/// sirf plain data aata hai, taaki baad me [scoreTrainee] ko ML model se
/// badla ja sake aur baaki screens waise hi chalti rahein.
library;

/// Kitne din pichhe tak ki attendance dekhni hai
const int kRiskWindowDays = 28;

enum RiskLevel { high, medium, low }

extension RiskLevelLabel on RiskLevel {
  String get label => switch (this) {
        RiskLevel.high => 'High',
        RiskLevel.medium => 'Medium',
        RiskLevel.low => 'Low',
      };
}

/// Ek din ki attendance: kis student (doc id) ka kya status tha
class AttendanceDay {
  final DateTime date;
  final Map<String, String> statusMap;
  final String batchName;
  const AttendanceDay(this.date, this.statusMap, {this.batchName = ''});
}

bool isPresent(String status) => status.toLowerCase() == 'present';

/// Window me ek trainee ke kitne record aur kitne present
class AttendanceTally {
  int records = 0;
  int present = 0;

  /// 0-100; koi record nahi to null
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

  /// Kaaran, jaise "Attendance 54%", "Fees 70% pending"
  final List<String> reasons;
  const RiskResult(this.score, this.level, this.reasons);
}

/// Score ke rules:
/// attendance <60% = +60, warna <75% = +40; fees pending >50% = +25;
/// window me 5 se kam record = +10; status Joined = +5.
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

/// Sirf in status wale trainees ka risk nikalta hai
bool isActiveTrainee(String status) => status == 'Joined' || status == 'Ongoing';

/// [now] se pichhle [kRiskWindowDays] din ke records, student doc id ke hisaab se
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

/// Ek trainee ka risk, list me dikhane ke liye
class TraineeRisk {
  final String id;
  final String name;
  final String batch;
  final RiskResult result;
  const TraineeRisk(this.id, this.name, this.batch, this.result);
}

/// Students (har map me 'id' = doc id) aur attendance se Joined/Ongoing
/// trainees ki list, sabse zyada score pehle
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

/// Number ya "12,000" jaisa text, dono ko number banata hai; na bane to 0
double toAmount(dynamic v) {
  if (v is num) return v.toDouble();
  return double.tryParse((v ?? '').toString().replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0;
}
