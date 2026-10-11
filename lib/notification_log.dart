import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import 'at_risk_logic.dart';
import 'current_user.dart';

/// Simulated notification log. Koi asli SMS/WhatsApp nahi jaata, sirf
/// 'notifications' collection me record banta hai.

const String kSimulatedStatus = 'Simulated (not sent)';
const String kSignOff = '- Vistas';

enum NotificationType { feeDue, absentAlert, batchAlert, adminSummary, riskAlert }

extension NotificationTypeInfo on NotificationType {
  /// Firestore me save hone wali value
  String get id => switch (this) {
        NotificationType.feeDue => 'fee_due',
        NotificationType.absentAlert => 'absent_alert',
        NotificationType.batchAlert => 'batch_alert',
        NotificationType.adminSummary => 'admin_summary',
        NotificationType.riskAlert => 'risk_alert',
      };

  String get label => switch (this) {
        NotificationType.feeDue => 'Fee reminder',
        NotificationType.absentAlert => 'Absent alert',
        NotificationType.batchAlert => 'Batch alert',
        NotificationType.adminSummary => 'Daily summary',
        NotificationType.riskAlert => 'Risk alert',
      };

  /// Fee reminder SMS se, baaki WhatsApp se
  String get channel => this == NotificationType.feeDue ? 'SMS' : 'WhatsApp';
}

NotificationType? notificationTypeFromId(String id) {
  for (final t in NotificationType.values) {
    if (t.id == id) return t;
  }
  return null;
}

String _s(dynamic v) => (v ?? '').toString().trim();

final NumberFormat _inr = NumberFormat('#,##,##0', 'en_IN');

/// SMS me ₹ ki dikkat se bachne ke liye "Rs. 12,000"
String rupees(num v) => 'Rs. ${_inr.format(v.round())}';

String dayKey(DateTime d) => DateFormat('yyyyMMdd').format(d);

String _prettyDate(DateTime d) => DateFormat('dd MMM yyyy').format(d);

/// "9876543221" -> "98XXXXXX21"; pehle 2 aur aakhri 2 digit dikhte hain
String maskPhone(String phone) {
  var digits = phone.replaceAll(RegExp(r'\D'), '');
  if (digits.length > 10) digits = digits.substring(digits.length - 10);
  if (digits.length < 4) return 'XXXX';
  return '${digits.substring(0, 2)}${'X' * (digits.length - 4)}${digits.substring(digits.length - 2)}';
}

/// Doc id me sirf letters, digits aur '-'
String _idPart(String s) {
  final cleaned = s.trim().replaceAll(RegExp(r'[^A-Za-z0-9-]+'), '-');
  return cleaned.isEmpty ? 'none' : cleaned;
}

/// Message text ka chhota hash (8 hex). Web aur Android dono par same aata
/// hai, isliye String.hashCode use nahi kiya.
String shortHash(String text) {
  const mod = 4294967291; // 2^32 se chhota prime
  var h = 7;
  for (final c in text.trim().codeUnits) {
    h = (h * 31 + c) % mod;
  }
  return h.toRadixString(16).padLeft(8, '0');
}

/// Ek record jo likha jaana hai
class PendingNotification {
  final NotificationType type;
  final String traineeId;
  final String traineeName;
  final String phone;
  final String message;
  final String batch;
  final DateTime day;

  const PendingNotification({
    required this.type,
    required this.traineeId,
    required this.traineeName,
    required this.phone,
    required this.message,
    required this.batch,
    required this.day,
  });

  /// type_traineeId_yyyyMMdd. Batch alert me batch aur message hash bhi,
  /// taaki usi din alag message ja sake par same message dobara nahi.
  String get docId {
    final date = dayKey(day);
    if (type == NotificationType.batchAlert) {
      return '${type.id}_${_idPart(batch)}_${_idPart(traineeId)}_${date}_${shortHash(message)}';
    }
    return '${type.id}_${_idPart(traineeId)}_$date';
  }
}

/// Banne wale records + kitne trainees guardian phone na hone se chhoote
class NotificationBatch {
  final List<PendingNotification> items;
  final int noPhone;
  const NotificationBatch(this.items, this.noPhone);
}

String _traineeIdOf(Map<String, dynamic> s) => _s(s['traineeId']).isNotEmpty ? _s(s['traineeId']) : _s(s['id']);

String _nameOf(Map<String, dynamic> s) => _s(s['name']).isEmpty ? 'your ward' : _s(s['name']);

/// Jin students ke liye [messageFor] message de (null = chhodo), unke records.
/// Guardian phone na ho to trainee chhoot jaata hai aur [NotificationBatch.noPhone] me ginta hai.
NotificationBatch _forStudents(
  Iterable<Map<String, dynamic>> students,
  NotificationType type,
  DateTime day,
  String? Function(Map<String, dynamic> s) messageFor,
) {
  final items = <PendingNotification>[];
  var noPhone = 0;
  for (final s in students) {
    final message = messageFor(s);
    if (message == null) continue;
    final phone = _s(s['guardianPhone']);
    if (phone.replaceAll(RegExp(r'\D'), '').length < 4) {
      noPhone++;
      continue;
    }
    items.add(PendingNotification(
      type: type,
      traineeId: _traineeIdOf(s),
      traineeName: _s(s['name']),
      phone: phone,
      message: message,
      batch: _s(s['batch']),
      day: day,
    ));
  }
  return NotificationBatch(items, noPhone);
}

double _pendingFee(Map<String, dynamic> s) {
  final total = toAmount(s['totalFee']);
  final pending = s['feePending'] == null ? total - toAmount(s['feePaid']) : toAmount(s['feePending']);
  return pending < 0 ? 0 : pending;
}

/// Joined/Ongoing trainees jinki fees baaki hai
NotificationBatch feeReminders(Iterable<Map<String, dynamic>> students, DateTime now) =>
    _forStudents(students, NotificationType.feeDue, now, (s) {
      if (!isActiveTrainee(_s(s['status']))) return null;
      final pending = _pendingFee(s);
      if (pending <= 0) return null;
      return 'Dear Parent, a fee of ${rupees(pending)} is pending for ${_nameOf(s)} (${_traineeIdOf(s)}). '
          'Please pay at the centre at your earliest convenience. $kSignOff';
    });

/// Kal ki attendance me jo absent the
NotificationBatch absentAlerts(
  Iterable<Map<String, dynamic>> students,
  Iterable<AttendanceDay> days,
  DateTime now,
) {
  final yesterday = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 1));
  final absent = <String>{};
  for (final day in days) {
    final d = day.date;
    if (d.year != yesterday.year || d.month != yesterday.month || d.day != yesterday.day) continue;
    day.statusMap.forEach((id, status) {
      if (status.toLowerCase() == 'absent') absent.add(id);
    });
  }
  return _forStudents(students, NotificationType.absentAlert, now, (s) {
    if (!absent.contains(_s(s['id']))) return null;
    return 'Dear Parent, ${_nameOf(s)} (${_traineeIdOf(s)}) was absent on ${_prettyDate(yesterday)}. '
        'Please make sure they attend regularly. $kSignOff';
  });
}

/// Ek batch ke Joined/Ongoing trainees ke guardians ko admin ka message
NotificationBatch batchAlerts(Iterable<Map<String, dynamic>> students, String batch, String text, DateTime now) {
  final message = 'Dear Parent, update for batch $batch: ${text.trim()} $kSignOff';
  return _forStudents(students, NotificationType.batchAlert, now, (s) {
    if (_s(s['batch']) != batch || !isActiveTrainee(_s(s['status']))) return null;
    return message;
  });
}

/// At-Risk screen se ek High-risk trainee ka alert
NotificationBatch riskAlert(Map<String, dynamic> student, List<String> reasons, DateTime now) =>
    _forStudents([student], NotificationType.riskAlert, now, (s) {
      final why = reasons.isEmpty ? '' : ' (${reasons.join(', ')})';
      return 'Dear Parent, ${_nameOf(s)} (${_traineeIdOf(s)}) needs extra support$why. '
          'Please contact the centre at your earliest convenience. $kSignOff';
    });

/// Admin ke liye aaj ka summary
PendingNotification dailySummary(
  Iterable<Map<String, dynamic>> students,
  Iterable<AttendanceDay> days,
  Iterable<Map<String, dynamic>> enquiries,
  DateTime now,
) {
  bool isToday(DateTime d) => d.year == now.year && d.month == now.month && d.day == now.day;

  var records = 0, present = 0;
  for (final day in days) {
    if (!isToday(day.date)) continue;
    day.statusMap.forEach((_, status) {
      records++;
      if (isPresent(status)) present++;
    });
  }

  var newEnquiries = 0;
  for (final e in enquiries) {
    final when = e['enquiryDate'] ?? e['createdAt'];
    if (when is Timestamp && isToday(when.toDate())) newEnquiries++;
  }

  double pending = 0;
  var pendingCount = 0;
  for (final s in students) {
    final p = _pendingFee(s);
    if (p > 0) {
      pending += p;
      pendingCount++;
    }
  }

  final attendance = records == 0
      ? 'no attendance marked yet'
      : 'attendance ${(present * 100 / records).round()}% ($present/$records)';
  return PendingNotification(
    type: NotificationType.adminSummary,
    traineeId: 'all',
    traineeName: '',
    phone: '',
    message: 'Daily summary for ${_prettyDate(now)}: $attendance, '
        '$newEnquiries new ${newEnquiries == 1 ? 'enquiry' : 'enquiries'}, '
        '${rupees(pending)} fees pending from $pendingCount ${pendingCount == 1 ? 'trainee' : 'trainees'}.',
    batch: '',
    day: now,
  );
}

class LogResult {
  final int logged;
  final int skipped;
  const LogResult(this.logged, this.skipped);
}

/// Har record transaction se likhta hai: doc pehle se ho to chhod deta hai
/// (duplicate nahi banta), warna naya record.
Future<LogResult> logNotifications(List<PendingNotification> items) async {
  final db = FirebaseFirestore.instance;
  final stamp = await creatorStamp();
  var logged = 0, skipped = 0;
  for (final n in items) {
    final ref = db.collection('notifications').doc(n.docId);
    final created = await db.runTransaction<bool>((tx) async {
      final existing = await tx.get(ref);
      if (existing.exists) return false;
      tx.set(ref, {
        'type': n.type.id,
        'channel': n.type.channel,
        'traineeId': n.type == NotificationType.adminSummary ? '' : n.traineeId,
        'traineeName': n.traineeName,
        'recipient': n.type == NotificationType.adminSummary ? 'Admin' : maskPhone(n.phone),
        'message': n.message,
        'status': kSimulatedStatus,
        'batch': n.batch,
        ...stamp,
        'createdAt': FieldValue.serverTimestamp(),
      });
      return true;
    });
    if (created) {
      logged++;
    } else {
      skipped++;
    }
  }
  return LogResult(logged, skipped);
}

/// Bulk ke baad dikhane wala message
String logResultMessage(LogResult r, {int noPhone = 0}) {
  if (r.logged == 0 && r.skipped > 0 && noPhone == 0) return 'Already logged today.';
  final parts = <String>['Logged ${r.logged}'];
  if (r.skipped > 0) parts.add('skipped ${r.skipped} (already logged today)');
  if (noPhone > 0) parts.add('$noPhone without guardian phone');
  return '${parts.join(', ')}.';
}
